# Project Instructions

This project is a cross-chain yield-bearing stablecoin built with
Solidity, Foundry, OpenZeppelin and Chainlink CCIP.

Development principles:
- Prioritize security and correctness over code brevity.
- Explain unfamiliar Solidity, Foundry and CCIP concepts before generating code.
- Do not generate entire contracts unless explicitly requested.
- Prefer small incremental implementations.
- Write tests before or alongside implementation.
- Use Foundry for unit, integration, fuzz and invariant testing.
- Follow Checks-Effects-Interactions where applicable.
- Follow OpenZeppelin patterns where appropriate.
- Never hardcode private keys or secrets.
- Do not use mainnet funds during development.
- Clearly identify assumptions and potential security risks.
- When using Chainlink CCIP, explain what each important component does.
- When writing deployment scripts, explain the script before providing the code.