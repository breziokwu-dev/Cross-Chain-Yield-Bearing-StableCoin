# Cross-Chain Yield-Bearing Stablecoin

A Solidity/Foundry project implementing an overcollateralized, yield-bearing stablecoin with a cross-chain transfer layer built around Chainlink CCIP.

## Overview

The system is built around four core components:

- **XUSD** — ERC20 stablecoin with restricted minting and burning.
- **StablecoinVault** — accepts mock USDC collateral, tracks shares and XUSD debt, and accounts for collateral deployed to the yield strategy.
- **SimpleYieldStrategy** — deterministic mock strategy used to simulate yield and losses during testing.
- **CrossChainBridge** — burns XUSD on the source chain and mints the corresponding amount on the destination chain through Chainlink CCIP, with trusted-remote validation and replay protection.

`MockCCIPRouter` and `MockUSDC` are test-only infrastructure used to exercise the system locally without relying on live infrastructure.

## Architecture

```text
                 ┌────────────────────┐
                 │      User          │
                 └─────────┬──────────┘
                           │ deposit USDC
                           ▼
                 ┌────────────────────┐
                 │  StablecoinVault   │
                 └──────┬───────┬─────┘
                        │       │
                 collateral    │ mint/burn XUSD
                        │       ▼
                        │  ┌──────────┐
                        │  │   XUSD   │
                        │  └────┬─────┘
                        │       │
                        ▼       │ cross-chain transfer
              ┌────────────────┐│
              │ Yield Strategy ││
              └────────────────┘│
                                ▼
                       ┌──────────────────┐
                       │ CrossChainBridge │
                       └────────┬─────────┘
                                │
                          Chainlink CCIP
                                │
                                ▼
                       Destination Bridge
                                │
                                ▼
                           Destination XUSD
```

## Vault Accounting

The vault uses share accounting rather than assigning a fixed number of assets to each deposit.

- `totalAssets` = assets held by the vault + assets reported by the strategy.
- Deposits receive shares based on the current asset/share exchange rate.
- Yield increases the value represented by existing shares without creating additional shares.
- Losses reduce the value represented by existing shares without changing total share supply.
- XUSD debt is tracked against the user's vault position.
- When total XUSD supply is zero, the exchange rate is reinitialized to `1e18`.

The design intentionally deploys deposited collateral to the strategy rather than maintaining an idle reserve.

## Cross-Chain Design

The bridge follows a burn-and-mint model:

1. A user initiates a transfer on the source chain.
2. The bridge burns the specified amount of XUSD from the sender.
3. A CCIP message is sent to the trusted destination bridge.
4. The destination bridge validates the router, source chain, source bridge, and replay status.
5. The destination bridge mints the same amount of XUSD to the recipient.

Trusted remote configuration is explicit, and processed CCIP message IDs are recorded to prevent replay.

## Security / Audit Coverage

Security is treated as a project-quality concern rather than the project's primary specialization. The repository includes tests covering:

- XUSD access control and supply behavior.
- Vault debt and collateral accounting.
- Share accounting through deposits, yield, losses, and liquidation.
- Donation/rounding edge cases.
- Cross-chain trusted-source validation.
- CCIP message replay protection.
- End-to-end source burn → CCIP delivery → destination mint supply conservation.
- Stateful invariant testing of vault accounting.

## Testing

Run the complete test suite with:

```bash
forge test -vv
```

The current suite includes unit, invariant, and economic audit tests.

Useful targeted commands:

```bash
forge test --match-contract StablecoinVaultTest -vv
forge test --match-contract StablecoinVaultEconomicAuditTest -vv
forge test --match-contract CrossChainBridgeTest -vv
```

## Project Status

The core vault, yield strategy, XUSD token, and CCIP bridge are implemented and covered by the current Foundry test suite.

Latest local full-suite verification:

```text
106 tests passed
0 failed
0 skipped
```

## Scope and Limitations

This is an educational/portfolio protocol implementation, not production-ready stablecoin infrastructure.

Notable limitations include:

- `MockUSDC` is intentionally unrestricted and exists only for testing.
- `SimpleYieldStrategy` is a deterministic mock strategy, not a production yield protocol.
- CCIP integration is tested with a mock router rather than live deployment infrastructure.
- No governance system is included.
- No upgradeability is included.
- Production deployment would require substantially more economic, integration, operational, and security review.

## Tooling

- Solidity
- Foundry / Forge
- OpenZeppelin Contracts
- Chainlink CCIP

## Repository

urlGitHub repositoryhttps://github.com/breziokwu-dev/Cross-Chain-Yield-Bearing-StableCoin
