# LOCKSLEY PROTOCOL — Product Spec v2

**Last updated:** 2026-07-14
**Status:** Contracts written, 22/22 tests passing. Ready to deploy.
**Renamed from:** Sherwood Protocol (July 14, 2026)

---

## Brand
| | |
|---|---|
| **Protocol** | LOCKSLEY |
| **Staking Vault 1** | GRAZE — stake CASHCAT-ETH LP → earn FLETCH |
| **Staking Vault 2** | YEW VAULT — stake FLETCH-ETH LP → earn YEW |
| **Reward Token** | FLETCH — 1bn max, earn from GRAZE |
| **Treasury Token** | YEW — 1bn max, earn from YEW vault |
| **Future** | THE GLADE — multi-vault aggregation |

**Twitter:** @locksleyfi
**GitHub:** github.com/locksleydefi/locksley-protocol

---

## The Model

**James's insight:** FLETCH has utility (needed to earn YEW in the YEW vault), so holders have reason not to sell. This is how CRV→CVX and FXS→Frax work — staking demand = price support. YEW is bought automatically by the protocol (50% of every GRAZE harvest).

---

## Tokenomics

### FLETCH
- **Type:** ERC-20, mintable by authorised vaults only
- **Max supply:** 1,000,000,000 (1 billion)
- **Initial supply:** 0 (all via emission)
- **Emission:** 0.5/block, halved 50% every 30 days
- **Schedule:** LOCKED in GRAZEMasterChef contract code — owner CANNOT change
- **Utility:** Stake CASHCAT-ETH LP → earn FLETCH. Stake FLETCH-ETH LP → earn YEW.

### YEW
- **Type:** ERC-20, mintable by authorised YEWVaultChef only
- **Max supply:** 1,000,000,000 (1 billion)
- **Initial supply:** 0 (all via emission)
- **Emission:** 0.05/block (10× less than FLETCH), halved 50% every 30 days
- **Schedule:** LOCKED in YEWVaultChef contract code — owner CANNOT change
- **Value driver:** 50% of all GRAZE performance fees swap for YEW on every harvest

### Emission Schedule
| Epoch | Days | FLETCH/block | YEW/block | FLETCH/30d |
|---|---|---|---|---|
| 0 | 1–30 | 0.500 | 0.050 | 12,960,000 |
| 1 | 31–60 | 0.250 | 0.025 | 6,480,000 |
| 2 | 61–90 | 0.125 | 0.013 | 3,240,000 |
| 3 | 91–120 | 0.063 | 0.006 | 1,620,000 |
| 4+ | 121+ | halving continues | → | → |

Year 1 total: 85.32M FLETCH (8.5% of 1bn), 8.53M YEW (0.85% of 1bn).

---

## Two-Vault Architecture

### Vault 1 — GRAZE
- **Stake:** CASHCAT-ETH LP (`0xa70fc67c9f69da90b63a0e4c05d229954574e313`)
- **Earn:** FLETCH at 0.5/block, halved every 30 days
- **Fees:**
  - Performance fee: 10% (on FLETCH harvest)
  - Withdrawal fee: 0.5% (on LP withdrawal)
- **Fee split (on LP):**
  - 50% → swap for YEW → add to YEW-ETH LP (treasury buy pressure)
  - 25% → send ETH to team wallet
  - 25% → add as CASHCAT-ETH LP → protocol-owned address
- **Contract:** GRAZEMasterChef.sol

### Vault 2 — YEW VAULT
- **Stake:** FLETCH-ETH LP (create after FLETCH deploy)
- **Earn:** YEW at 0.05/block, halved every 30 days
- **No performance fee** (YEW is the treasury asset — keep it scarce)
- **Contract:** YEWVaultChef.sol

---

## Fee Model (LP-Based — James's Fix)

Fees are taken in **LP tokens** (CASHCAT-ETH), not in FLETCH.

**Why?** If fees were taken in FLETCH, the protocol would be selling FLETCH on every harvest → FLETCH price dumps → GRAZE APR looks high but is worthless. Taking fees in LP avoids this circular dependency.

**Flow:**
1. Harvest triggered → 10% of earned FLETCH claimed back as CASHCAT-ETH LP
2. LP removed → split into CASHCAT + ETH
3. ETH split: 50/25/25
4. 50% ETH swapped for YEW → added to YEW-ETH LP → treasury
5. 25% ETH → team wallet
6. 25% ETH + CASHCAT → re-added as CASHCAT-ETH LP → protocol-owned address

---

## James's Bootstrap Plan ($300)

| Seed | Amount | Purpose |
|---|---|---|
| CASHCAT-ETH LP | $100 | Stake in GRAZE → earn FLETCH |
| FLETCH-ETH LP | $100 | 2,000 FLETCH + £78 ETH → price £0.039 (~$0.05) |
| YEW-ETH LP | $100 | Seeds YEW price, provides initial YEW liquidity |

**FLETCH seed price:** $100 ETH / 2,000 FLETCH = £0.039/FLETCH = ~$0.05

**Day 1 APR at £100 CASHCAT TVL, FLETCH £0.039:**
- Year 1 blended APR: ~3,300,000% (astronomical at tiny TVL)
- This is the degen magnet — early degens get maximum rewards

**At £100k CASHCAT TVL, FLETCH £0.039:**
- Year 1 APR: ~3,300% — still very competitive
- APR compresses naturally as TVL grows (healthy tokenomics)

---

## Smart Contracts

| Contract | File | Status |
|---|---|---|
| FLETCH | src/FLETCH.sol | ✅ Written, tested |
| YEW | src/YEW.sol | ✅ Written, tested |
| GRAZEMasterChef | src/GRAZEMasterChef.sol | ✅ Written, tested |
| YEWVaultChef | src/YEWVaultChef.sol | ✅ Written, tested |

**Compiler:** Solidity 0.8.x with `via_ir = true`
**Framework:** Foundry (forge test, forge build)
**Tests:** 22/22 passing

---

## On-Chain Addresses (Robinhood Chain)

| Asset | Address |
|---|---|
| WETH | `0x0bd7d308f8e1639fab988df18a8011f41eacad73` |
| CASHCAT | `0x020bfc650a365f8bb26819deaabf3e21291018b4` |
| CASHCAT-ETH LP | `0xa70fc67c9f69da90b63a0e4c05d229954574e313` |
| Uniswap V2 Factory | `0x1f7d7550b1b028f7571e69a784071f0205fd2efa` |
| Uniswap V2 Router | `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D` |
| **Deployer** | `0xdE4cbE36aF237CDe0Bcd630E3C38357d5a32602d` |

**RPC:** https://rpc.mainnet.chain.robinhood.com | **Chain ID:** 4663

---

## Design Language
- **Aesthetic:** 2020 DeFi forest theme — dark greens (#0a0f0a), gold (#c9a227), neon green (#39ff14)
- **Fonts:** Space Mono (headers/numbers), Rajdhani (body)
- **Identity:** "Locksley" = Robin Hood's real name. Forest/nature theme. Honest, no-VC branding.
- **Tone:** Fair launch, community-owned, transparent emissions

---

## What's NOT in Scope for Phase 1
- No JUGGERNAUT vault (Phase 2 or community vote)
- No auto-compounding (THE GLADE Phase 2)
- No governance token (Phase 3)
- No cross-chain (Robinhood Chain only for now)

---

## Next Steps
- [x] Write all smart contracts
- [x] 22/22 Foundry tests passing
- [x] Design emission model (locked halving)
- [x] Build website with correct tokenomics
- [ ] Get ETH on Robinhood Chain (Coinbase → Orbiter bridge)
- [ ] Deploy FLETCH → get address
- [ ] Deploy YEW → get address
- [ ] Create FLETCH-ETH LP → seed with 2,000 FLETCH + $100 ETH
- [ ] Create YEW-ETH LP → seed with $100
- [ ] Deploy YEWVaultChef → authorise on YEW
- [ ] Deploy GRAZEMasterChef → authorise on FLETCH
- [ ] Create CASHCAT-ETH LP → stake $100 in GRAZE
- [ ] Update website with all deployed addresses
- [ ] Deploy website to Netlify
- [ ] Post Twitter launch thread (@locksleyfi)
