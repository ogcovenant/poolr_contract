# Poolr

> **Module:** `poolr::poolr`  
> **Purpose:** Crowdfund and escrow USDC on Sui, with voting-driven release or refunds.

This README is written for *any developer* who will read, integrate, or audit the Poolr smart contract — whether you're a Move newbie or an experienced Sui integrator. It focuses on plain language, examples, and the exact steps you'll perform when interacting with the contract.

---

## Quick summary (one minute)
- Create a pool with a `target_amount` in USDC and a deadline (in days).
- Pools are **PRIVATE** or **PUBLIC**. Private pools require the initiator to add contributors; public pools let anyone join while the pool is `OPEN`.
- Contributors deposit USDC into an internal escrow. Each contribution assigns voting power proportional to the contribution amount vs the pool target.
- When the pool hits the target, initiator requests release → contributors vote (`YES`/`NO`). If quorum and majority pass, funds go to `recipient`. Otherwise, refunds are enabled and contributors can claim their share.

---

## Prerequisites
- Familiarity with Sui and Move module basics.
- `USDC` Move type available in your environment (module `usdc::usdc::USDC`).
- Sui toolchain and your preferred SDK (Sui JS, Sui Rust) for building transactions.

---

## Units & Money handling — important
- **Everything uses the integer representation used by your `USDC` token.** Confirm whether `USDC` in your repo uses 6 decimals (common) or another scale. `target_amount`, `contributed_amount`, and `threshold_contribution` are plain `u64` values **in USDC base units** (not human-readable dollars). Always convert values when presenting them on the UI.

Example: if USDC has 6 decimals, `1 USDC = 1_000_000` in the contract.

---

## Quickstart — common steps (developer-friendly)
These are the exact *conceptual* steps you’ll implement in your scripts or front-end; replace `...` with real values.

1. **Create pool** (initiator):
   - Call `create_pool(ctx, title, description, recipient, target_amount, voting_threshold, threshold_contribution, deadline_days, visibility, clock)`.
   - After success: you hold a `PoolInitiatorCap` and a `Pool` resource exists with `status = OPEN`.

2. **Add or join contributors**
   - Private pool: initiator calls `add_contributor_to_pool(&mut pool, user_addr, &pool_initiator_cap)` for each allowed contributor.
   - Public pool: each user calls `join_pool(ctx, &mut pool)` while `status == OPEN`.

3. **Start funding** (initiator):
   - Call `initialize_pool_funding(&mut pool, &pool_initiator_cap)` → `status = FUNDING`.

4. **Contribute** (contributors):
   - Send `Coin<USDC>` into `contribute_to_pool(coin, &mut pool, ctx, &clock)`.
   - Contract converts the coin to escrow balance, updates `contributed_amount`, and assigns voting power.

5. **Request release** (initiator):
   - When `contributed_amount >= target_amount`, call `request_pool_release(&mut pool, &pool_initiator_cap)` → `status = VOTING`.

6. **Vote** (contributors):
   - Call `vote(&mut pool, "YES"|"NO", &ctx)` while `status == VOTING`. Users’ entire voting power is consumed on vote.

7. **Execute** (initiator):
   - Call `release_pool_funds(&mut pool, &pool_initiator_cap, &mut ctx)`.
   - Preconditions: total votes must meet `voting_threshold%` of the absolute `TOTAL_VOTING_POWER` constant.
   - If OK and `yes_votes > no_votes` → funds transferred to `recipient` and `status = RELEASED`.
   - Else `status = REJECTED` and refunds are initiated.

8. **Refunds**
   - Initiator calls `initialize_pool_refund(&mut pool, &pool_initiator_cap)` to move `status = REFUNDING`.
   - Contributors call `claim_pool_refund(&mut pool, ctx)` to withdraw their recorded contribution share.

---

## API Reference (short, exact)
Each entry lists the function name, important params, and quick preconditions.

- `create_pool(ctx, title, description, recipient, target_amount, voting_threshold, threshold_contribution, deadline, visibility, clock)`
  - Preconditions: `target_amount > 0`, `deadline > 0` (in days)
  - Result: `Pool` resource created, `PoolInitiatorCap` transferred to caller.

- `add_contributor_to_pool(&mut pool, user_address, &pool_initiator_cap)`
  - Preconditions: `pool.visibility == PRIVATE`, `pool.status == OPEN`, call must provide valid cap that matches the pool.

- `join_pool(ctx, &mut pool)`
  - Preconditions: `pool.visibility == PUBLIC`, `pool.status == OPEN`.

- `initialize_pool_funding(&mut pool, &pool_initiator_cap)`
  - Preconditions: cap matches pool, `pool.status == OPEN`.

- `contribute_to_pool(coin<USDC>, &mut pool, ctx, &clock)`
  - Preconditions: `pool.status == FUNDING`, before deadline, caller must be contributor.

- `request_pool_release(&mut pool, &pool_initiator_cap)`
  - Preconditions: `pool.status == FUNDED`.

- `vote(&mut pool, choice: String, &ctx)`
  - Preconditions: `pool.status == VOTING`, caller must be in `voters` table. Choice must be `"YES"` or `"NO"`.

- `release_pool_funds(&mut pool, &pool_initiator_cap, &mut ctx)`
  - Preconditions: `pool.status == VOTING`, `pool.total_votes >= threshold`.

- `initialize_pool_refund(&mut pool, &pool_initiator_cap)`
  - Preconditions: `pool.status == REJECTED`.

- `claim_pool_refund(&mut pool, ctx)`
  - Preconditions: caller must have `contribution > 0` in `pool.contributors`.

---

## Example flows (pseudo-code you can drop into your SDK)

**Create Pool (pseudo)**
```text
// On-chain call (initiator account)
create_pool(txCtx, "Park Bench Restoration", "Restore the bench in the park", recipientAddr, 100_000_000, 50, Some(10_000_000), 30, "PUBLIC", clock)
```
Meaning: target = 100 USDC if USDC uses 6 decimals, voting_threshold = 50%.

**Contribute (pseudo)**
```text
// Contributor constructs a Coin<USDC> for 25 USDC (25_000_000) and sends
contribute_to_pool(coin25USDC, pool, txCtx, clock)
```

**Vote (pseudo)**
```text
vote(pool, "YES", txCtx)
```

**Claim refund (pseudo)**
```text
claim_pool_refund(pool, txCtx)
```

---

## Events you should listen for (for indexing & UI)
- `PoolCreatedEvent` — record pool metadata and `pool_id`.
- `ContributionAddedEvent` — update contributor balances & UI confirmations.
- `PoolFundingInitialisedEvent`, `PoolReleaseRequestEvent`, `PoolVotedEvent`, `PoolReleasedEvent`, `PoolRefundClaimed` — use to update UI state transitions.

---

## Common pitfalls & gotchas (developer notes)
- **Decimal confusion:** always check USDC’s decimals. Convert to/from UI values when presenting amounts.
- **Voting power rounding:** voting power is computed with integer math and may not sum exactly to `TOTAL_VOTING_POWER` — that's expected; choose how you display percentages.
- **Claim event bug:** earlier code emissions placed the refunded amount **after** zeroing contributions. The README’s doc version includes a note to capture refund amount before zeroing — make sure code does that.
- **Concurrency & race conditions:** two simultaneous contributions could attempt to push the pool over its target — frontends should handle `ETargetAmountReached` and show a helpful message.