# Cross-Chain Yield-Bearing Stablecoin

## 1. Project overview

This project is a cross-chain yield-bearing stablecoin built with Solidity, Foundry, OpenZeppelin, and Chainlink CCIP.

The protocol is designed to evolve incrementally:

1. Accept stablecoin collateral.
2. Mint xUSD as a claim token.
3. Earn yield through a simple strategy.
4. Allow xUSD holders to redeem their proportional share of the underlying assets.
5. Eventually support xUSD transfers across chains through Chainlink CCIP.

The architecture is intentionally conservative in v1. The first version focuses on correct accounting, safe mint and redeem behavior, simple yield accrual, and testability.

Project principles agreed by the team:

- Security and correctness come before code brevity.
- Unfamiliar Solidity, Foundry, and CCIP concepts should be explained before code is generated.
- Do not generate entire contracts unless explicitly requested.
- Prefer small incremental implementations.
- Write tests before or alongside implementation.
- Use Foundry for unit, integration, fuzz, and invariant testing.
- Follow Checks-Effects-Interactions where applicable.
- Follow OpenZeppelin patterns where appropriate.
- Never hardcode private keys or secrets.
- Do not use mainnet funds during development.
- Clearly identify assumptions and security risks.
- When using Chainlink CCIP, explain each important component.
- When writing deployment scripts, explain the script before providing the code.

---

## 2. Development phases

The project is structured in phases so the architecture remains easy to reason about and test.

### Phase 1: Single-chain stablecoin

Included:

- Mock USDC collateral
- xUSD ERC-20
- StablecoinVault
- Deposit flow
- Redemption flow
- Foundry unit tests

### Phase 2: Yield accounting

Included:

- Mock yield strategy
- Yield simulation
- Exchange-rate accounting
- Yield-related tests

### Phase 3: Advanced validation

Included:

- Fuzz testing
- Invariant testing
- Edge-case testing
- Security review

### Phase 4: Cross-chain

Included:

- Chainlink CCIP integration
- Cross-chain xUSD handling
- Cross-chain accounting model
- CCIP-specific testing

### Phase 5: Real yield strategy

Included:

- Replace the mock strategy with a real yield-generating strategy

This document describes the current architecture for v1 and then notes the future CCIP architecture without adding new design decisions beyond what is already agreed.

---

## 3. V1 scope and explicit non-goals

### V1 scope

V1 is intentionally minimal and boring by design.

Included:

- One blockchain
- Mock USDC collateral
- Restricted xUSD ERC-20
- StablecoinVault
- Mock yield strategy
- Yield simulation
- Share-based accounting
- Foundry tests

### Explicit non-goals for v1

The following are intentionally out of scope for v1:

- CCIP
- Governance
- Upgradeability
- Multiple collateral types
- Real yield protocols
- Oracle infrastructure
- Mainnet deployment
- Idle reserve management
- Advanced strategy selection
- Multi-chain bridge logic

### Design constraint

The v1 system is a single-chain, single-collateral vault model. The purpose is to validate the economic model and the accounting logic before the protocol expands.

---

## 4. Contract architecture

The current project architecture consists of four core pieces.

### 4.1 Mock USDC collateral

Purpose:

- Provide the accepted stablecoin asset used as collateral
- Serve as the user-facing deposit asset
- Represent the underlying asset that is managed by the vault and strategy

This is a mock token used for v1 only. It is not a project-owned contract; it is a test or mock stablecoin used to simulate the accepted collateral.

Responsibilities:

- Hold balances for users
- Allow transfers to the vault and strategy
- Support approval flows needed for deposit behavior

### 4.2 xUSD

Purpose:

- Represent the user’s claim on the vault’s underlying assets
- Be transferable and fungible
- Track ownership of the claim in a simple ERC-20 form

This token is not the collateral itself. It is a claim token that represents a proportional share of the vault’s total assets.

Responsibilities:

- Track supply and balances
- Allow transfer between users
- Restrict minting and burning to the vault

### 4.3 StablecoinVault

Purpose:

- Accept collateral from users
- Track total managed assets
- Mint xUSD when users deposit
- Burn xUSD when users redeem
- Account for yield
- Coordinate withdrawals from the strategy

This is the central accounting and custody contract in v1.

Responsibilities:

- Receive user collateral
- Deposit collateral to the strategy immediately
- Maintain the accounting state of the vault
- Compute the exchange rate
- Mint and burn xUSD
- Return collateral on redemption

### 4.4 SimpleYieldStrategy

Purpose:

- Hold the collateral that has been deployed for yield generation
- Simulate yield in v1
- Report the current strategy value back to the vault

This is a mock yield strategy used to model yield accrual without a real yield protocol.

Responsibilities:

- Receive collateral from the vault
- Track strategy value
- Simulate yield increases
- Return collateral to the vault when withdrawal is requested

---

## 5. Responsibilities of each contract

### StablecoinVault responsibilities

- Accept mock USDC deposits from users
- Immediately transfer deposited collateral to the strategy
- Maintain totalAssets and xUSD totalSupply
- Calculate the current exchange rate
- Mint xUSD to users on deposit
- Burn xUSD from users on redemption
- Withdraw collateral from the strategy when users redeem
- Return collateral to users
- Enforce the basic access rules for v1
- Maintain the protocol’s accounting integrity

### xUSD responsibilities

- Track total token supply
- Track user balances
- Support transfers between users
- Restrict minting and burning to the vault
- Represent the share-like claim held by users

### SimpleYieldStrategy responsibilities

- Receive collateral from vault
- Track its current value
- Apply yield simulation
- Return collateral to the vault on withdrawal
- Keep the vault’s accounting simple and isolated

### Mock USDC responsibilities

- Allow deposits and transfers
- Provide collateral for xUSD minting and redemption
- Behave like the collateral asset used in v1

---

## 6. Accounting model

The v1 protocol uses a share-based accounting model. xUSD functions as a claim token, not as a literal balance of collateral.

The core rule is:

- xUSD represents a proportional claim on the vault’s underlying assets
- as yield accrues, the underlying value of the vault increases
- the xUSD supply does not increase automatically when yield is earned
- the value per xUSD increases as the exchange rate increases

This means the system is economically similar to a vault token or share model.

### Derived values

- totalAssets = vault-held collateral + strategy value
- exchangeRate = totalAssets × 1e18 / xUSD totalSupply
- userClaimValue = user xUSD balance × exchangeRate / 1e18

### Important interpretation

The xUSD supply is not a count of stablecoins. It is the count of claim shares. The value per claim is determined by the exchange rate.

---

## 7. totalAssets

For v1, totalAssets is defined as:

- totalAssets = vault-held collateral + strategy value

This is the authoritative definition in the current architecture.

### Meaning

The vault can own collateral in two places:

- in the vault itself as currently held collateral
- in the strategy as deployed collateral

The protocol treats both as part of the full asset base backing xUSD.

### v1 rule

Deposits are immediately deployed to the strategy. This means the vault does not keep an idle reserve in v1.

Therefore, after a standard deposit:

- vault-held collateral is zero
- strategy value increases by the deposited amount
- totalAssets increases by the same amount

This design simplifies the accounting model and keeps v1 behavior easy to reason about.

---

## 8. xUSD share model

xUSD is modeled as a restricted ERC20 share token.

Key rules:

- xUSD is mintable only by the vault
- xUSD is burnable only by the vault
- users can transfer xUSD normally as ERC-20 balances
- the token represents a proportional claim on totalAssets

### Share semantics

When a user deposits collateral:

- the vault computes the number of xUSD shares to mint
- the user receives xUSD in exchange for the deposited collateral

When a user redeems:

- the vault burns xUSD from the user
- the vault returns the proportional collateral value from the underlying assets

The xUSD supply represents the total number of claim shares currently outstanding.

---

## 9. Exchange-rate calculation

The exchange rate is defined as:

- exchangeRate = totalAssets × 1e18 / xUSD totalSupply

This uses 1e18 scaling to avoid decimals and preserve precise fixed-point accounting.

### Zero-supply behavior

If xUSD totalSupply is zero, the exchange rate is reinitialized to 1e18.

This ensures that the first deposit starts from a clean and predictable baseline.

### Why the rate matters

- Deposits use the current exchange rate to compute the number of xUSD shares to mint.
- Redemptions use the current exchange rate to compute how much collateral to return.
- Yield accrual increases totalAssets without increasing xUSD totalSupply, which raises the exchange rate.

### Formula examples

If totalAssets = 1000 and totalSupply = 1000, then:

- exchangeRate = 1000 × 1e18 / 1000 = 1e18

If totalAssets later increases to 1300 while totalSupply remains 1000:

- exchangeRate = 1300 × 1e18 / 1000 = 1.3e18

This means each xUSD claim is now worth more underlying collateral.

---

## 10. Deposit flow

The deposit flow is intentionally simple in v1.

### Process

1. User approves mock USDC to the vault.
2. User calls deposit with a stablecoin amount.
3. Vault receives the USDC from the user.
4. Vault immediately transfers the deposited collateral into the strategy.
5. Vault computes the xUSD shares to mint using the current exchange rate.
6. Vault calls xUSD mint for the user.
7. User receives xUSD.

### Deposit share calculation

The vault rounds down the share amount.

- sharesToMint = floor(amount × 1e18 / exchangeRate)

This is the agreed rounding rule for deposits.

### v1 deposit behavior

- There is no idle reserve in v1.
- All deposits are immediately deployed to the strategy.
- The vault’s held collateral balance is effectively zero after deposit, unless a separate internal action is introduced later.

### State impact

After a deposit:

- user xUSD balance increases
- totalAssets increases by the deposited amount
- xUSD totalSupply increases by the minted shares
- strategy value increases by the deposited amount
- exchangeRate is recalculated

---

## 11. Yield flow

Yield accrual is modeled as a simple increase in the strategy’s value.

### Process

1. The strategy earns yield or receives simulated return value.
2. The strategy value increases.
3. The strategy reports or exposes the new value to the vault.
4. The vault recalculates totalAssets.
5. The vault recalculates exchangeRate without changing xUSD totalSupply.

### Important property

Yield does not mint new xUSD.

It increases the value of each existing xUSD claim.

### v1 yield simulation

The yield strategy is mock-only. It simulates an increase in strategy value without a real yield source.

This keeps v1 focused on accounting correctness instead of protocol integration risk.

### Yield accounting rule

- totalAssets increases by the yield amount
- xUSD totalSupply stays unchanged
- exchangeRate increases because the same supply now backs a larger asset base

---

## 12. Redemption flow

Redemption in v1 is the inverse of deposit.

### Process

1. User calls redeem with a desired xUSD amount.
2. Vault checks the user has enough xUSD.
3. Vault burns the xUSD from the user.
4. Vault calculates the proportional underlying collateral value using the current exchange rate.
5. Vault withdraws that collateral value from the strategy.
6. Vault transfers the collateral back to the user.

### Redemption asset calculation

The vault rounds down the collateral output.

- collateralOut = floor(shares × exchangeRate / 1e18)

This is the agreed rounding rule for redemptions.

### v1 behavior

- Redemptions are proportional to the user’s claim on the vault.
- The vault returns the proportional share of the currently backed assets.
- No idle reserve exists in v1, so strategy withdrawals are essential for redemption.

### State impact

After redemption:

- user xUSD balance decreases
- xUSD totalSupply decreases
- strategy value decreases by the withdrawn value
- totalAssets decreases by the redeemed collateral value
- exchangeRate is recalculated

---

## 13. Zero-supply behavior

When xUSD totalSupply is zero, the protocol reinitializes the exchange rate at 1e18.

This decision is fixed for v1.

Why it matters:

- The first deposit should start from a known baseline.
- The protocol avoids division by zero and undefined behavior.
- The next deposit begins from a clean rate after a full redemption.

### Result

After a full redemption where all xUSD is burned:

- xUSD totalSupply == 0
- exchangeRate resets to 1e18

The next valid deposit uses that reinitialized value.

---

## 14. Strategy behavior

The SimpleYieldStrategy is intentionally simple.

### Strategy responsibilities

- Receive collateral from the vault
- Track the collateral value it holds
- Simulate yield accrual
- Return collateral back to the vault for redemption

### Strategy rules in v1

- Deposits are immediately sent to the strategy.
- There is no queue, no idle reserve, and no separate strategy selection.
- The strategy value is the current value of the collateral it holds, including accrued yield.
- Strategy withdrawals occur when the vault needs to pay out a redemption.

### Strategy independence

The strategy is not a governance mechanism. It is a simple accounting and value container for v1. The vault remains the central source of truth for accounting.

---

## 15. Access control

The v1 protocol is intentionally minimal and has no governance.

### Access control model

- xUSD minting is restricted to the vault
- xUSD burning is restricted to the vault
- the vault is the only contract that can change xUSD supply
- the strategy is only allowed to receive and return collateral under vault instructions
- there is no governance layer and no upgrade path in v1

### Access assumptions

- The system is designed to remain simple and auditable.
- The vault is the only privileged contract for accounting operations.
- There is no dynamic admin or role model in v1.

---

## 16. Core invariants

The protocol should always maintain the following invariants in v1.

### 16.1 Asset accounting

- totalAssets = vault-held collateral + strategy value

### 16.2 Exchange-rate rule

- if xUSD totalSupply > 0:
  - exchangeRate = totalAssets × 1e18 / xUSD totalSupply
- if xUSD totalSupply == 0:
  - exchangeRate = 1e18

### 16.3 Supply consistency

- xUSD totalSupply must equal the sum of all user balances

### 16.4 Solvency

- totalAssets must be sufficient to cover all claims represented by xUSD
- in a valid state:
  - xUSD totalSupply × exchangeRate / 1e18 <= totalAssets

### 16.5 Claim value

- user xUSD balance × exchangeRate / 1e18 = that user’s proportional claim on the vault

### 16.6 No unbacked minting

- xUSD can only be minted through a valid deposit flow through the vault
- xUSD can only be burned through a valid redemption flow through the vault

### 16.7 Yield integrity

- yield accrual increases totalAssets without changing xUSD totalSupply
- the exchange rate rises accordingly

### 16.8 Zero-supply reset

- after a full redemption, xUSD totalSupply is zero and exchangeRate resets to 1e18

---

## 17. Rounding rules

The v1 design fixes the following rounding behavior.

### Deposits

- Deposit share calculation rounds down.
- sharesToMint = floor(amount × 1e18 / exchangeRate)

### Redemptions

- Redemption asset calculation rounds down.
- collateralOut = floor(shares × exchangeRate / 1e18)

### Purpose of rounding down

This rule keeps the system conservative and prevents overpayment in both directions.

It also ensures the protocol does not create value by rounding upward during deposit or redemption.

### Important implication

Tiny amounts that do not produce at least one whole share or whole collateral unit may be truncated to zero if the math produces a value below 1.

This must be explicitly handled in tests and specification before implementation.

---

## 18. Security principles

The v1 architecture is intentionally simple, but it still needs strong security discipline.

### Principal security rules

- Prioritize security and correctness over code brevity.
- Follow Checks-Effects-Interactions where applicable.
- Keep the protocol simple and easy to reason about.
- Avoid hidden mint or burn paths.
- Do not allow arbitrary minting outside the vault.
- Ensure yield accrual cannot silently inflate or distort the xUSD accounting model.
- Never hardcode private keys or secrets.
- Never deploy or test on mainnet funds.
- Clearly identify risks and assumptions before implementation.

### v1-specific risks

- Reentrancy in token transfers or state transitions
- Incorrect share math or rounding logic
- Incorrect strategy accounting
- Under-collateralization caused by invalid state transitions
- Stale exchange rate usage
- Zero-supply edge cases
- Inconsistent vault and strategy accounting

### Security posture

The protocol is intentionally limited so that the accounting model is easy to audit and test. The design avoids unnecessary complexity and therefore reduces the number of attack paths in v1.

---

## 19. Testing strategy

The project explicitly uses Foundry for testing.

The test strategy covers:

- Unit tests for deposits and redemptions
- Yield accounting tests
- Invariant tests for totalAssets and supply behavior
- Rounding and edge-case validation
- Reversion tests for invalid states
- State-consistency tests after each major transition

### Testing priorities in v1

1. Deposit flow correctness
2. Redemption flow correctness
3. Yield accrual accounting
4. Exchange-rate calculation
5. xUSD supply consistency
6. Zero-supply reset behavior
7. Edge cases with rounding and very small amounts
8. Paused or invalid-state reverts if the vault includes a pause state

### Testing philosophy

The protocol should test behavior as users experience it: deposit, mint, yield, redeem, and claim value consistency. The tests should validate the actual protocol behavior, not mocked assumptions.

---

## 20. Future CCIP architecture

The current project is designed to add cross-chain capability later through Chainlink CCIP.

### Future architecture direction

The planned future design is:

- The same xUSD economic model remains the same on each chain
- Cross-chain transfers are handled through CCIP message flows
- The vault remains the canonical accounting layer on each chain
- Cross-chain xUSD movement is introduced as a separate future layer rather than part of v1

### Critical future rule

CCIP is not part of v1 and should not be mixed into the initial vault or strategy design.

### Future CCIP principles

- Cross-chain logic should be separate from the core vault accounting layer
- Source and destination accounting should be explicitly validated
- Message authenticity and anti-replay rules must be respected
- Cross-chain transfers should be designed to preserve the underlying economic model of xUSD

### Future design intent

The future architecture should keep the core economic model intact while adding cross-chain messaging as a separate, clearly defined layer. That keeps the v1 logic simple and testable.

---

## 21. Summary of the current architecture

The current v1 protocol is a single-chain, single-collateral vault token architecture.

Users deposit mock USDC into the vault, the vault immediately sends the collateral to a mock yield strategy, the vault mints xUSD to the user, and the system uses a share-based exchange rate to track the value of the underlying claim.

Yield accrues by increasing the strategy value. The xUSD supply does not change, but the exchange rate increases. Redemptions burn xUSD and return the proportional underlying collateral value.

This keeps the protocol mathematically coherent, conservative, and straightforward to test before introducing CCIP or more advanced features.

It is intentionally minimal, but it is sufficient to validate the core architecture and the economic model that will later support cross-chain yield-bearing xUSD.

