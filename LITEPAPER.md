# LITEPAPER — Locksley Protocol v1.2

---

## Abstract

Locksley Protocol is a community-owned DeFi yield aggregator built on Robinhood Chain. Its flagship product, GRAZE, puts the "Meta" back in yield farming — earning yields from multiple protocols and returning them to liquidity providers, with a performance fee model that builds real protocol-owned liquidity.

Two tokens work in concert:
- **FLETCH** — the yield token. Earned by stakers in GRAZE vaults. Inflationary, minted on harvest.
- **YEW** — the treasury token. Represents ownership of the protocol's real assets. Its value is backed by YEW buy pressure and the YEW/ETH LP growing in the treasury with every harvest.

**Status:** Smart contracts deployed on Robinhood Chain. Fair launch in progress.

---

## The Problem

Robinhood Chain is underserved. Despite being an EVM-compatible chain with fast finality and near-zero gas fees, it lacks the DeFi infrastructure seen on Ethereum, Arbitrum, or Solana. Liquidity is fragmented. Yield opportunities are siloed. And most protocols are controlled by VCs and insiders — not the community.

The existing yield aggregators on Robinhood Chain:
- Pay no meaningful performance fees → no organic growth mechanism
- Have no real treasury → no price floor, no buy pressure
- Rent liquidity from LPs → can be displaced overnight

---

## The Solution: GRAZE

GRAZE is a SushiSwap MasterChef V1-inspired yield aggregator. Users stake their LP tokens and earn FLETCH rewards. The protocol collects a **10% performance fee** on every harvest — taken as LP, not as an worthless governance token. That LP is split three ways:

```
User harvests rewards worth 100 FLETCH
    ↓
90 FLETCH → User (90%)
10 FLETCH → Protocol (10% performance fee, valued in LP terms)
    ↓
LP is removed → CASHCAT + ETH
    ↓
Split three ways:
50% ETH → routed to buy YEW → added to YEW/ETH LP → YEW treasury ✅
25% ETH → sent to team wallet                                 ✅
25% CASHCAT + ETH → protocol-owned CASHCAT-ETH LP             ✅
```

This means:
- **YEW gets real buy pressure** on every harvest — price discovery is real
- **Protocol owns its own liquidity** — not renting from users
- **Team gets paid in ETH** — sustainable income without selling user value
- **FLETCH is not used as fee currency** — no dumping on a market that doesn't exist yet

---

## Fee Model

| Fee Type | Amount | Currency | Split | Destination |
|----------|--------|----------|-------|-------------|
| Performance Fee | 10% | LP (CASHCAT-ETH) | 50% / 25% / 25% | YEW buy / Team / Protocol LP |
| Withdrawal Fee | 0.5% | LP | same split | YEW buy / Team / Protocol LP |
| Deposit Fee | 0% | — | — | — |
| Management Fee | $0 | — | — | — |

**Benchmark:** Autofarm and Beefy standard vault model — 0% deposit, 0.5% withdrawal, 10% performance fee.

**Why LP instead of FLETCH?**
Performance fees taken in FLETCH require a FLETCH market to exist and have value before the protocol earns anything. By taking fees in the LP pair (which has immediate, real value from the AMM), the protocol earns meaningful revenue from day one. The LP is then decomposed into ETH + CASHCAT, and each portion is deployed productively.

---

## Tokenomics

### FLETCH — The Yield Token
- **Type:** ERC-20, mintable by authorised vaults only
- **Total Supply:** Unlimited (inflationary via rewards)
- **Distribution:** 100% to stakers via GRAZE vaults. No team allocation, no VC allocation, no pre-mine.
- **Utility:** Yield token. Stake LP → earn FLETCH.

### YEW — The Treasury Token
- **Type:** ERC-20, fixed supply
- **Total Supply:** 10,000,000 (10M)
- **Initial Distribution:** 100% to community treasury (Liquidity Bootstrap Pool)
- **Seed Price:** Set at launch by seeding YEW/ETH pool with $100
- **Utility:** Governance, fee capture, treasury ownership
- **Value Driver:** Every harvest buys YEW from the YEW/ETH LP, creating consistent buy pressure

### YEW/ETH LP — The Treasury Asset
The YEW treasury does not hold YEW tokens — it holds YEW/ETH LP tokens. The ETH portion accumulates with every harvest as the team sells its 25% cut and as the protocol buys YEW. The YEW side grows as protocol fees are routed to buy YEW.

Over time the LP becomes more valuable, creating a genuine price floor and yield opportunity for YEW stakers.

---

## GRAZE Vault Mechanics

### How It Works

1. **User deposits LP tokens** (e.g., CASHCAT-ETH or JUGGERNAUT-ETH) into a GRAZE vault
2. **FLETCH rewards accrue** per block, proportional to the user's share of the pool
3. **On harvest:** User claims FLETCH. 10% of the reward (valued in LP terms) is taken as a performance fee, split three ways.
4. **On withdrawal:** 0.5% withdrawal fee, same three-way split.
5. **APRs compress over time** as more users stake — normal and expected. Early movers earn more.

### Fee Processing Detail

When a fee is collected (performance or withdrawal):

1. **Remove liquidity:** The fee LP is removed from CASHCAT-ETH, yielding CASHCAT tokens + ETH
2. **Split:** ETH is divided 50% / 25% / 25%
3. **YEW buy:** 50% ETH is swapped for YEW via DEX, then added as YEW/ETH LP → sent to YEW treasury
4. **Team payment:** 25% ETH sent directly to team wallet
5. **Protocol LP:** 25% ETH + equivalent CASHCAT → added as CASHCAT-ETH LP → protocol-owned address

### Security Considerations
- No admin keys that can withdraw user funds
- Performance fees go through AMM — transparent and on-chain verifiable
- Emergency LP withdrawal function exists for edge cases only
- Try-catch around AMM calls prevents reverts from blocking withdrawals

---

## Roadmap

### Phase 1 ✅ — GRAZE (Current)
- [x] Smart contracts (MasterChef V1 pattern, LP-based fee model)
- [x] GRAZE vault (CASHCAT-ETH, JUGGERNAUT-ETH)
- [x] FLETCH reward token
- [x] YEW treasury token
- [x] Performance fee → 50% YEW buy / 25% team / 25% protocol LP
- [ ] Mainnet deployment (RPC confirmed)
- [ ] Fair launch (Pump.fun)
- [ ] Seed YEW/ETH LP with $100

### Phase 2 — THE GLADE
- Multi-vault aggregation
- Auto-compounding vaults
- Additional LP pairs (RvnDEX native pairs)

### Phase 3 — Governance
- Decentralised governance (Timelock + Multisig)
- Community-controlled fee parameters
- Protocol-owned liquidity (POL)

---

## FAQ

**Q: Why does the team get paid in ETH rather than FLETCH or YEW?**
A: ETH is the most liquid asset on any chain. The team can convert ETH to whatever it needs. Paying the team in FLETCH would require selling FLETCH on an illiquid market at launch — bad for price. Paying in YEW would dilute treasury. ETH is neutral and immediately useful.

**Q: What backs YEW's value?**
A: Two things: (1) The YEW/ETH LP in the treasury grows with every harvest as protocol fees buy YEW. (2) The team and early investors have skin in the game — the YEW/ETH LP is seeded at launch with real capital. As GRAZE TVL grows, more harvests → more YEW buys → higher YEW price.

**Q: Why does the protocol own its own LP?**
A: Most yield aggregators rent liquidity from LPs — if LPs leave, the protocol's yield source disappears. Protocol-owned LP (POL) means GRAZE has its own independent liquidity that can't be taken away. The 25% protocol LP cut builds this over time.

**Q: What's the difference between FLETCH and YEW?**
A: FLETCH is an inflationary yield token — you earn it by staking. YEW is a fixed-supply ownership token — it represents your share of the treasury and governance rights. Think FLETCH = stock, YEW = ownership.

**Q: What happens when CASHCAT or JUGGERNAUT tokens dump?**
A: GRAZE earns rewards in FLETCH regardless of the underlying token price. If the LP pair loses value, stakers' FLETCH APR may look high in token terms but low in USD terms — same as any yield farm. The protocol's 25% protocol LP cut means the team also loses when tokens dump — team and protocol are aligned with stakers.

---

*Locksley Protocol. Built by the community, for the community. No VCs. No pre-mine. No shortcuts.*
