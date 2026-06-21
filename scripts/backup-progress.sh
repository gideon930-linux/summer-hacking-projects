#!/usr/bin/env bash
# =============================================================================
# backup-progress.sh — Push localStorage tracker state to GitHub
#
# Usage:
#   ./backup-progress.sh                    # interactive: prompts for token
#   GITHUB_TOKEN=ghp_xxx ./backup-progress.sh  # non-interactive via env var
#
# What it does:
#   1. Accepts a raw JSON blob (your exported localStorage state) via stdin
#      or prompts you to paste it
#   2. Validates the JSON is parseable
#   3. Commits it as backups/progress-YYYY-MM-DDTHH-MM-SS.json on the
#      progress-backup branch of your summer-hacking-projects repo
#   4. Also updates backups/latest.json as a stable pointer to the newest save
#
# Generating the JSON to pipe in (run this in your browser console):
#   copy(localStorage.getItem('hackingTracker_v1'))
#   Then paste when prompted, or pipe it:
#   echo '<pasted-json>' | ./backup-progress.sh
# =============================================================================

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
die()     { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

# ── Config ────────────────────────────────────────────────────────────────────
REPO_OWNER="gideon930-linux"
REPO_NAME="summer-hacking-projects"
BRANCH="progress-backup"
BACKUP_DIR="backups"
STORAGE_KEY="hackingTracker_v1"
API_BASE="https://api.github.com"

# ── 1. Resolve GitHub token ───────────────────────────────────────────────────
TOKEN="${GITHUB_TOKEN:-}"

if [ -z "$TOKEN" ]; then
    # Try gh CLI first (already authenticated in the lab)
    if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
        TOKEN=$(gh auth token 2>/dev/null || true)
    fi
fi

if [ -z "$TOKEN" ]; then
    echo -e "${YELLOW}Enter your GitHub Personal Access Token (needs repo scope):${RESET}"
    echo    "  Create one at: https://github.com/settings/tokens/new"
    echo    "  Or set it with: export GITHUB_TOKEN=ghp_..."
    echo ""
    read -rsp "Token (hidden): " TOKEN
    echo ""
    [ -z "$TOKEN" ] && die "No token provided. Aborting."
fi

# ── 2. Read JSON state ────────────────────────────────────────────────────────
if [ -t 0 ]; then
    # Running interactively — prompt for paste
    echo ""
    echo -e "${BOLD}Paste your tracker state JSON below.${RESET}"
    echo    "  To get it: open browser console on the tracker page and run:"
    echo -e "    ${CYAN}copy(localStorage.getItem('${STORAGE_KEY}'))${RESET}"
    echo    "  Then paste here and press Enter, then Ctrl+D:"
    echo ""
    JSON_STATE=$(cat)
else
    # Piped input
    JSON_STATE=$(cat)
fi

[ -z "$JSON_STATE" ] && die "No JSON state provided."

# ── 3. Validate JSON ──────────────────────────────────────────────────────────
if command -v python3 &>/dev/null; then
    echo "$JSON_STATE" | python3 -c "import sys,json; json.load(sys.stdin)" \
        || die "Invalid JSON. Check that you copied the full value from localStorage."
    COMPLETED=$(echo "$JSON_STATE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
done = sum(1 for v in d.get('completed', {}).values() if v)
total_notes = len([v for v in d.get('notes', {}).values() if v.strip()])
print(f'completed={done} notes={total_notes}')
" 2>/dev/null || echo "completed=? notes=?")
    success "JSON is valid  ($COMPLETED)"
else
    warn "python3 not found — skipping JSON validation."
fi

# ── 4. Build filenames ────────────────────────────────────────────────────────
TIMESTAMP=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
DATED_FILE="${BACKUP_DIR}/progress-${TIMESTAMP}.json"
LATEST_FILE="${BACKUP_DIR}/latest.json"

# ── 5. Helper: upsert a file on the branch via GitHub API ────────────────────
gh_upsert() {
    local path="$1"
    local content_b64="$2"
    local message="$3"

    # Check if the file already exists on the branch (need its SHA to update)
    local existing_sha
    existing_sha=$(curl -sf \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        "${API_BASE}/repos/${REPO_OWNER}/${REPO_NAME}/contents/${path}?ref=${BRANCH}" \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('sha',''))" 2>/dev/null || echo "")

    local payload
    if [ -n "$existing_sha" ]; then
        payload=$(python3 -c "
import json, sys
print(json.dumps({
    'message': sys.argv[1],
    'content': sys.argv[2],
    'branch':  sys.argv[3],
    'sha':     sys.argv[4]
}))" "$message" "$content_b64" "$BRANCH" "$existing_sha")
    else
        payload=$(python3 -c "
import json, sys
print(json.dumps({
    'message': sys.argv[1],
    'content': sys.argv[2],
    'branch':  sys.argv[3]
}))" "$message" "$content_b64" "$BRANCH")
    fi

    local response
    response=$(curl -sf \
        -X PUT \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        -H "Content-Type: application/json" \
        "${API_BASE}/repos/${REPO_OWNER}/${REPO_NAME}/contents/${path}" \
        -d "$payload" 2>&1) || {
            echo "$response" >&2
            die "GitHub API request failed for ${path}."
        }

    echo "$response" | python3 -c "
import sys,json
d = json.load(sys.stdin)
print(d['commit']['html_url'])
" 2>/dev/null || true
}

# ── 6. Wrap JSON with metadata and encode ─────────────────────────────────────
ENRICHED=$(python3 -c "
import json, sys
state = json.loads(sys.argv[1])
done  = sum(1 for v in state.get('completed', {}).values() if v)
wrapper = {
    'meta': {
        'exported_at': sys.argv[2],
        'storage_key': sys.argv[3],
        'projects_completed': done
    },
    'state': state
}
print(json.dumps(wrapper, indent=2))
" "$JSON_STATE" "$TIMESTAMP" "$STORAGE_KEY")

CONTENT_B64=$(echo "$ENRICHED" | base64 | tr -d '\n')

# ── 7. Commit dated snapshot ──────────────────────────────────────────────────
info "Committing dated snapshot → ${DATED_FILE} ..."
COMMIT_URL=$(gh_upsert \
    "$DATED_FILE" \
    "$CONTENT_B64" \
    "backup: progress snapshot ${TIMESTAMP}")

success "Snapshot committed"
[ -n "$COMMIT_URL" ] && echo -e "  ${CYAN}${COMMIT_URL}${RESET}"

# ── 8. Update latest.json ─────────────────────────────────────────────────────
info "Updating latest.json pointer ..."
gh_upsert \
    "$LATEST_FILE" \
    "$CONTENT_B64" \
    "backup: update latest.json (${TIMESTAMP})" > /dev/null

success "latest.json updated"

# ── 9. Summary ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Backup complete ─────────────────────────────────────────${RESET}"
echo -e "  Branch  : ${CYAN}${BRANCH}${RESET}"
echo -e "  Snapshot: ${CYAN}${DATED_FILE}${RESET}"
echo -e "  Latest  : ${CYAN}${LATEST_FILE}${RESET}"
echo ""
echo    "To restore on a new machine:"
echo    "  1. Open the tracker in your browser"
echo    "  2. Open the browser console and run:"
echo -e "     ${CYAN}fetch('https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/progress-backup/${LATEST_FILE}')${RESET}"
echo    "       .then(r => r.json())"
echo    "       .then(d => { localStorage.setItem('${STORAGE_KEY}', JSON.stringify(d.state)); location.reload(); })"
echo ""
