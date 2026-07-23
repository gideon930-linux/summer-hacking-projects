# Ethernaut Level 6: Delegation

## 1. Executive Summary

The Delegation challenge demonstrates the security risks associated with Solidity's low-level delegatecall opcode when combined with an unhandled fallback function. The goal was to claim ownership of the target Delegation contract by leveraging state manipulation through execution context delegation.

---

## Key Concepts
1. delegatecall vs callIn Solidity, low-level calls behave differently regarding execution context:

     Feature                     call               delegatecall
Code Executed From          Target Contract        Target Contract
Storage Modified            Target Contract        Calling Contract
msg.sender                  Calling Contract       Original Caller
msg.value                   Passed Value           Original Value

---

When Contract A invokes delegatecall on Contract B, Contract B's code runs, but it directly reads and mutates Contract A's storage layout.

## 2. Storage Layout Alignment:

Solidity assigns state variables to fixed 32-byte storage slots sequentially starting from slot 
- Delegate Contract:
	Slot 0: address public owner;
- Delegation Contract:
	Slot 0: address public owner;
	Slot 1: Delegate public delegate;
	
Because both contracts share owner at storage slot 0, any function in Delegate that modifies slot 0 will overwrite slot 0 in Delegation when executed via delegatecall.

## Root Cause Analysis:
1. Open Fallback Function: The Delegation contract implements a generic fallback function that forwards all incoming call data (msg.data) to the Delegate contract via delegatecall.
2. Unchecked Context Execution: The target Delegate contract includes a function pwn() which sets owner = msg.sender.
3. Storage Collision / Overwrite: When pwn() is executed within the context of Delegation, the assignment owner = msg.sender updates Slot 0 of Delegation, successfully hijacking contract ownership.

## Defensive Remediation
To prevent delegatecall-based state hijacking in production smart contracts:
 - Avoid Arbitrary Delegation: Never pass untrusted or user-controlled msg.data directly into a delegatecall.
 - State Variable Alignment: When using proxy patterns (e.g., ERC-1967), ensure storage slots are explicitly isolated or managed using       				
   standard implementation patterns like UUPS (Universal Upgradeable Proxy Standard) or Transparent Proxies.
 - Access Controls: Restrict fallback and delegation logic so that administrative functions cannot be called by unauthorized accounts.
