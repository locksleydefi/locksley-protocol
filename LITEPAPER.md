# LOCKSLEY PROTOCOL
## GRAZE — Yield Aggregator on Robinhood Chain
**Version 1.0 | July 2026**

---

## Abstract

LOCKSLEY PROTOCOL is a decentralised yield aggregator built on Robinhood Chain. GRAZE, the flagship vault product, allows liquidity providers to stake LP tokens and automatically earn optimised yield through FLETCH token rewards. A portion of all yield harvested flows into the YEW treasury, creating a compounding feedback loop that grows the protocol's value backing. No VCs. No pre-mine. Fair launch.

---

## 1. What is LOCKSLEY?

LOCKSLEY is a community-built DeFi protocol designed to make yield farming accessible and sustainable on Robinhood Chain. We believe the best protocols are built *for* the community, not sold to them.

The protocol operates as a set of autonomous vault contracts. Users deposit liquidity provider (LP) tokens into GRAZE vaults and earn FLETCH rewards proportional to their share of the vault. A 10% performance fee is applied on harvest and routed to the YEW treasury.

**The core loop:**

```
Deposit LP → Earn FLETCH → Fee flows to YEW → FLETCH becomes more valuable
```

---

## 2. The Problem

Yield farming on Robinhood Chain offers attractive returns — but comes with friction:

- **Gas costs:** Every swap, stake, and claim costs gas. Small farmers lose more in fees than they earn.
- **Manual tracking:** APRs fluctuate constantly. Positions need rebalancing to stay optimised.
- **Impermanent loss:** Providing liquidity is risky. Without a compounding strategy, gains erode.
- **Rug risk:** Many protocols take investor money and disappear. Trust requires transparency.

---

## 3. The Solution: GRAZE

GRAZE vaults solve these problems by aggregating user deposits into a single smart vault strategy:

1. **Deposits are pooled.** Gas costs are shared across all participants.
2. **Yield is auto-compounded.** Rewards are harvested and reinvested automatically.
3. **FLETCH accumulates.** Users earn more the longer they stay.
4. **The YEW treasury grows.** A percentage of all yield protects the protocol's long-term value.

---

## 4. How GRAZE Works

### Depositing

1. User acquires LP tokens (e.g., CASHCAT-ETH or JUGGERNAUT-ETH) on a Robinhood Chain DEX such as RVNDEX or JUGGERNUT Swap.
2. User connects a Web3 wallet (MetaMask, Robinhood Wallet) to the GRAZE frontend.
3. User deposits LP tokens into the chosen vault.
4. The vault immediately stakes the LP tokens in the underlying MasterChef pool.
5. FLETCH rewards begin accruing in real time.

### Earning

- FLETCH rewards are distributed per block, proportional to the user's share of the vault.
- Rewards compound automatically — users do not need to manually claim and restake.
- APR is displayed on the vault dashboard and updates as the reward rate changes.

### Withdrawing

- User initiates a withdrawal from the vault.
- A 0.5% withdrawal fee is applied to discourage rapid exits and flash-loan attacks.
- The vault unstakes the corresponding LP tokens and returns them to the user.
- FLETCH rewards are included in the withdrawal or can be claimed separately.

---

## 5. Tokenomics

### FLETCH — Reward Token

FLETCH is the protocol's reward token. It is minted by the vault contracts as yield is harvested and distributed to stakers.

- **Token type:** ERC-20 (Robinhood Chain)
- **Total supply:** Uncapped — inflationary by design to fund continuous yield
- **Emission:** Vault contracts mint FLETCH per block based on vault allocation
- **Purpose:** Incentivise LP providers to stake and secure protocol liquidity
- **Value accrual:** Each FLETCH represents a claim on the YEW treasury

### YEW — Treasury Token

YEW is the protocol's treasury token. It accumulates value through performance fees and provides long-term backing for FLETCH.

- **Token type:** ERC-20 (Robinhood Chain)
- **Total supply:** 10,000,000 (fixed)
- **Distribution:** 100% to the YEW treasury (community owned, no team allocation)
- **Value accrual:** 10% of all harvested yield is routed to YEW on every harvest
- **Purpose:** Back FLETCH value, fund protocol development, reward long-term stakers

### Fee Summary

| Fee Type | Rate | Destination |
|---|---|---|
| Performance fee | 10% | YEW Treasury |
| Withdrawal fee | 0.5% | GRAZE vault |
| Management fee | 0% | — |

---

## 6. Vaults

### GRAZE — CASHCAT-ETH LP Vault
**Status:** Live (MVP)
**LP Pair:** CASHCAT / ETH
**LP Address:** `0xa70fc67c9f69da90b63a0e4c05d229954574e313`
**Pool alloc:** 50 FLETCH per block

### GRAZE — JUGGERNAUT-ETH LP Vault
**Status:** Live (MVP)
**LP Pair:** JUGGERNAUT / ETH
**LP Address:** `0x588b0785f50063260003b7790c42f1ef74902746`
**Pool alloc:** 50 FLETCH per block

### THE GLADE — Multi-Vault Aggregator
**Status:** Planned
**Description:** Cross-vault optimisation strategy. Automatically rotates capital between the highest-yielding GRAZE vaults.

### GRAZE — FLETCH-ETH LP Vault
**Status:** Planned
**Description:** LP FLETCH with ETH to earn a share of all protocol yield in a single position.

---

## 7. Security

LOCKSLEY is built with security as the primary constraint:

- **Battle-tested contracts:** GRAZE is based on the SushiSwap MasterChef V1 contract pattern, one of the most audited DeFi primitives in existence (audited by OpenZeppelin, Quantstamp, and independent researchers).
- **OpenZeppelin standards:** All tokens use OpenZeppelin's ERC-20 implementation.
- **No admin keys post-launch:** Once deployed, the owner role is transferred to a timelock or renounced.
- **Transparent and on-chain:** All vault logic, reward calculations, and fee flows are verifiable on-chain.
- **Self-custodial:** Users never lose custody of their assets. Withdraw anytime.

---

## 8. Governance

LOCKSLEY is a community protocol. No team tokens. No investor allocation. No governance token at launch — decisions are made through informal community consensus on Discord and Telegram, with smart contract changes proposed via public GitHub.

As the protocol matures, governance will transition to YEW holders, who will vote on:
- New vault proposals
- Fee parameter adjustments
- Treasury grant distributions
- Protocol upgrade management

---

## 9. Roadmap

### Phase 1 — MVP Launch ✅
- [x] GRAZE MasterChef contract (SushiSwap V1 pattern)
- [x] FLETCH reward token
- [x] YEW treasury token
- [x] CASHCAT-ETH LP vault
- [x] JUGGERNAUT-ETH LP vault
- [x] Website and frontend
- [ ] Fair launch (no pre-mine, no VC allocation)

### Phase 2 — Growth
- [ ] THE GLADE multi-vault aggregator
- [ ] FLETCH-ETH LP vault
- [ ] Additional LP pair vaults (community proposals)
- [ ] Community marketing and liquidity incentives

### Phase 3 — Decentralisation
- [ ] YEW governance activation
- [ ] Timelock contract for upgrades
- [ ] Multi-sig treasury management
- [ ] Grants programme (funded by YEW treasury)

---

## 10. FAQ

**Is this a fork of SushiSwap?**
Yes — GRAZE uses the SushiSwap MasterChef V1 contract pattern as its vault foundation. This is intentional. The MasterChef is one of the most battle-tested contracts in DeFi. Our innovations are the FLETCH/YEW tokenomics, the fee model, and the community-first distribution.

**Why is FLETCH inflationary?**
Inflationary rewards are how yield protocols attract liquidity. Unlike governance tokens that may not have intrinsic value accrual, FLETCH value is backed by YEW treasury accumulation. As the treasury grows, the value of each FLETCH increases.

**What protects FLETCH from becoming worthless?**
The 10% performance fee flowing to YEW creates a compounding feedback loop. As yield is harvested, both FLETCH holders and the YEW treasury benefit. The treasury acts as a value reserve.

**Are my funds safe?**
You retain full custody of your LP tokens at all times. You can withdraw from the vault at any time. The contracts are open-source and verified on-chain.

**Who runs this?**
LOCKSLEY is a community project with no team allocation, no VC investors, and no pre-mined tokens. The contracts are autonomous once deployed.

---

## 11. Links

- **Website:** https://locksleyfi.com (coming soon)
- **Twitter:** https://x.com/locksleyfi
- **Telegram:** https://t.me/locksleyfi
- **GitHub:** https://github.com/locksleydefi/locksley-protocol

---

*LOCKSLEY PROTOCOL — DeFi Farming on Robinhood Chain.*
*FLETCH. EARN. YEW. GOVERN.*
