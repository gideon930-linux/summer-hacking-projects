#!/usr/bin/env bash
# =============================================================================
# git-push.sh — Automated Git workflow helper
# Repo: gideon930-linux/summer-hacking-projects
#
# Usage:
#   ./git-push.sh "Your commit message"
#   ./git-push.sh                        # prompts for a message interactively
#
# What it does:
#   1. Verifies you are inside a Git repository
#   2. Shows the current working-tree status
#   3. Stages all changes (git add -A)
#   4. Commits with the provided or prompted message
#   5. Resolves the correct remote branch name (handles main/master mismatches)
#   6. Pushes to origin, with helpful guidance on common errors
# =============================================================================

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
die()     { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

# ── 1. Confirm we are inside a Git repo ───────────────────────────────────────
if ! git rev-parse --git-dir &>/dev/null; then
    die "Not inside a Git repository. Navigate to your project root and try again."
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
info "Repository root: ${BOLD}${REPO_ROOT}${RESET}"

# ── 2. Show working-tree status ───────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Git Status ──────────────────────────────────────────────${RESET}"
git status --short
echo -e "${BOLD}────────────────────────────────────────────────────────────${RESET}"
echo ""

# Bail early if there is nothing to commit
if git diff --quiet && git diff --cached --quiet && \
   [ -z "$(git ls-files --others --exclude-standard)" ]; then
    success "Working tree is clean — nothing to commit."
    exit 0
fi

# ── 3. Resolve commit message ─────────────────────────────────────────────────
COMMIT_MSG="${1:-}"

if [ -z "$COMMIT_MSG" ]; then
    echo -e "${YELLOW}Enter a commit message (cannot be empty):${RESET}"
    read -r COMMIT_MSG
    if [ -z "$COMMIT_MSG" ]; then
        die "Commit message cannot be empty. Aborting."
    fi
fi

# Warn about suspiciously short messages
if [ "${#COMMIT_MSG}" -lt 5 ]; then
    warn "Commit message is very short ('${COMMIT_MSG}'). Consider something more descriptive."
    echo -e "${YELLOW}Continue anyway? [y/N]:${RESET} \c"
    read -r CONFIRM
    [[ "$CONFIRM" =~ ^[Yy]$ ]] || die "Aborted by user."
fi

# ── 4. Stage all changes ──────────────────────────────────────────────────────
info "Staging all changes (git add -A) ..."
git add -A
success "All changes staged."

# ── 5. Commit ─────────────────────────────────────────────────────────────────
info "Committing: \"${COMMIT_MSG}\""
if ! git commit -m "$COMMIT_MSG"; then
    die "git commit failed. Check the output above."
fi
success "Commit created."

# ── 6. Resolve the correct remote branch ─────────────────────────────────────
LOCAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)
info "Local branch: ${BOLD}${LOCAL_BRANCH}${RESET}"

# Fetch remote HEAD so we know what the remote default branch is called
REMOTE="origin"
REMOTE_DEFAULT=""

# Try to read the remote's HEAD ref (works even without a full fetch)
if git ls-remote --symref "$REMOTE" HEAD &>/dev/null; then
    REMOTE_HEAD_LINE=$(git ls-remote --symref "$REMOTE" HEAD 2>/dev/null | grep "^ref:" || true)
    if [ -n "$REMOTE_HEAD_LINE" ]; then
        REMOTE_DEFAULT=$(echo "$REMOTE_HEAD_LINE" | sed 's|ref: refs/heads/||; s|\s.*||')
    fi
fi

# Fall back: if the remote has an explicit main or master branch, prefer main
if [ -z "$REMOTE_DEFAULT" ]; then
    if git ls-remote --exit-code "$REMOTE" "refs/heads/main" &>/dev/null; then
        REMOTE_DEFAULT="main"
    elif git ls-remote --exit-code "$REMOTE" "refs/heads/master" &>/dev/null; then
        REMOTE_DEFAULT="master"
    else
        REMOTE_DEFAULT="$LOCAL_BRANCH"
    fi
fi

info "Remote default branch: ${BOLD}${REMOTE_DEFAULT}${RESET}"

# Detect a local/remote branch name mismatch (common refspec error)
TARGET_BRANCH="$LOCAL_BRANCH"
if [ "$LOCAL_BRANCH" != "$REMOTE_DEFAULT" ]; then
    warn "Local branch '${LOCAL_BRANCH}' differs from remote default '${REMOTE_DEFAULT}'."
    echo ""
    echo "  [1] Push local branch '${LOCAL_BRANCH}' as-is (creates a new remote branch)"
    echo "  [2] Rename local branch to '${REMOTE_DEFAULT}' then push"
    echo "  [3] Abort"
    echo ""
    echo -e "${YELLOW}Choose [1/2/3]:${RESET} \c"
    read -r BRANCH_CHOICE
    case "$BRANCH_CHOICE" in
        1)
            TARGET_BRANCH="$LOCAL_BRANCH"
            ;;
        2)
            info "Renaming branch '${LOCAL_BRANCH}' → '${REMOTE_DEFAULT}' ..."
            git branch -m "$LOCAL_BRANCH" "$REMOTE_DEFAULT"
            LOCAL_BRANCH="$REMOTE_DEFAULT"
            TARGET_BRANCH="$REMOTE_DEFAULT"
            success "Branch renamed."
            ;;
        *)
            die "Aborted by user."
            ;;
    esac
fi

# ── 7. Push ───────────────────────────────────────────────────────────────────
info "Pushing '${TARGET_BRANCH}' to ${REMOTE} ..."
echo ""

PUSH_OUTPUT=$(git push "$REMOTE" "${LOCAL_BRANCH}:${TARGET_BRANCH}" 2>&1) || {
    EXIT_CODE=$?
    echo "$PUSH_OUTPUT" >&2
    echo ""

    # ── Error pattern matching ────────────────────────────────────────────────

    # Rejected: non-fast-forward (remote has commits the local branch doesn't)
    if echo "$PUSH_OUTPUT" | grep -q "non-fast-forward\|fetch first\|rejected"; then
        echo -e "${RED}[FIX]${RESET}  Remote has changes not in your local branch."
        echo "       Run one of the following to reconcile:"
        echo ""
        echo "         git pull --rebase ${REMOTE} ${TARGET_BRANCH}   # rebase your commits on top"
        echo "         git pull --no-rebase ${REMOTE} ${TARGET_BRANCH} # merge strategy"
        echo ""
        echo "       Then re-run: ./git-push.sh"

    # Authentication failure
    elif echo "$PUSH_OUTPUT" | grep -qi "authentication\|permission denied\|403\|could not read"; then
        echo -e "${RED}[FIX]${RESET}  Authentication error. Check that:"
        echo "       • Your SSH key is added to the agent:  ssh-add ~/.ssh/id_ed25519"
        echo "       • Your remote URL uses SSH, not HTTPS: git remote -v"
        echo "       • GitHub has your public key:          https://github.com/settings/keys"

    # Refspec / branch does not exist on remote
    elif echo "$PUSH_OUTPUT" | grep -q "does not match any\|src refspec"; then
        echo -e "${RED}[FIX]${RESET}  Refspec error — the branch name likely doesn't exist locally."
        echo "       Current local branches:"
        git branch
        echo ""
        echo "       To create and push the branch explicitly:"
        echo "         git push --set-upstream ${REMOTE} ${TARGET_BRANCH}"

    # No upstream set
    elif echo "$PUSH_OUTPUT" | grep -q "no upstream\|set-upstream\|--set-upstream"; then
        echo -e "${YELLOW}[FIX]${RESET}  No upstream tracking set. Running with --set-upstream ..."
        git push --set-upstream "$REMOTE" "$TARGET_BRANCH" \
            && success "Pushed and upstream tracking set." \
            || die "Push with --set-upstream also failed. See output above."
        exit 0

    # Repository not found
    elif echo "$PUSH_OUTPUT" | grep -qi "repository not found\|not found"; then
        echo -e "${RED}[FIX]${RESET}  Remote repository not found. Verify your remote URL:"
        echo "         git remote -v"
        echo "       If the repo was renamed or moved, update it with:"
        echo "         git remote set-url origin <new-url>"

    else
        echo -e "${RED}[FIX]${RESET}  Unrecognised push error (exit code ${EXIT_CODE})."
        echo "       Review the output above and consult: https://git-scm.com/docs/git-push"
    fi

    exit "$EXIT_CODE"
}

echo "$PUSH_OUTPUT"
echo ""
success "Pushed successfully to ${BOLD}${REMOTE}/${TARGET_BRANCH}${RESET}."
echo ""
echo -e "${CYAN}Remote:${RESET} $(git remote get-url ${REMOTE})"
echo -e "${CYAN}Branch:${RESET} ${TARGET_BRANCH}"
echo -e "${CYAN}Commit:${RESET} $(git log -1 --oneline)"
echo ""
