# DEPLOY.md — Locksley Protocol Mainnet Deployment Guide

**Chain:** Robinhood Chain | Chain ID: 4663
**RPC:** https://rpc.mainnet.chain.robinhood.com
**Explorer:** https://robinhoodchain.blockscout.com

---

## Overview — James's $300 Bootstrap Plan

```
$100 CASHCAT-ETH LP   → stake in GRAZE vault → earn FLETCH
$100 FLETCH-ETH LP    → stake in YEW vault → earn YEW
$100 YEW-ETH LP       → seeds YEW price + provides initial YEW liquidity
```

**FLETCH seed price:** James puts 2,000 FLETCH + £78 ($100) ETH in FLETCH-ETH LP → price £0.039 (~$0.05)
**YEW seed price:** James seeds YEW-ETH LP with $100 → YEW price discovered at ~$0.05 (put less YEW = higher price)

---

## On-Chain Addresses (Confirmed on Robinhood Chain)

| Asset | Address |
|-------|---------|
| WETH | `0x0bd7d308f8e1639fab988df18a8011f41eacad73` |
| CASHCAT | `0x020bfc650a365f8bb26819deaabf3e21291018b4` |
| JUGGERNAUT | `0xd7321801caae694090694ff55a9323139f043b88` |
| CASHCAT-ETH LP | `0xa70fc67c9f69da90b63a0e4c05d229954574e313` |
| JUGGERNAUT-ETH LP | `0x588b0785f50063260003b7790c42f1ef74902746` |
| Uniswap V2 Factory | `0x1f7d7550b1b028f7571e69a784071f0205fd2efa` |
| Uniswap V2 Router | `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D` |

**Deployer address:** `0xdE4cbE36aF237CDe0Bcd630E3C38357d5a32602d`

**NOTE:** Router may return empty code via `eth_getCode`. Use the factory `getPair()` for pair lookups. Router is confirmed active via on-chain transactions.

---

## Tokenomics (Confirmed)

| | FLETCH | YEW |
|---|---|---|
| Max supply | 1,000,000,000 (1bn) | 1,000,000,000 (1bn) |
| Initial supply | 0 (all via emission) | 0 (all via emission) |
| Emission rate | 0.5/block | 0.05/block |
| Halving | 50% every 30 days | 50% every 30 days |
| Emission schedule | Locked in contract | Locked in contract |

---

## Deployment Steps

### Step 1 — Fund Your Deployer Wallet

Send ETH to: `0xdE4cbE36aF237CDe0Bcd630E3C38357d5a32602d`

**Recommended:** Coinbase → buy ETH → Orbiter Finance bridge → Robinhood Chain.
**Minimum needed:** ~0.01 ETH for all deployments + ~£200 for LP seeds.

---

### Step 2 — Get Current Block Number

```bash
curl -s -X POST https://rpc.mainnet.chain.robinhood.com \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

Add ~20 blocks to the result for `_startBlock`.

---

### Step 3 — Deploy FLETCH.sol

**File:** `src/FLETCH.sol`
**Compiler:** Solidity 0.8.x (via-ir = true)

**Constructor args:**
1. `_owner` — your deployer address

**After deploy:** Copy FLETCH contract address.

---

### Step 4 — Deploy YEW.sol

**File:** `src/YEW.sol`
**Compiler:** Solidity 0.8.x (via-ir = true)

**Constructor args:**
1. `initialOwner` — your deployer address

**After deploy:** Copy YEW contract address.

---

### Step 5 — Create FLETCH-ETH LP (sets FLETCH price)

1. Go to Uniswap on Robinhood Chain (or use direct contract calls)
2. Add liquidity to FLETCH/WETH pair:
   - **ETH:** ~£78 (~$100)
   - **FLETCH:** 2,000 FLETCH tokens
3. This creates the FLETCH-ETH LP and sets FLETCH price = £78/2,000 = **£0.039** (~$0.05)
4. Save the LP pair address (from `PairCreated` event or factory `getPair(FLETCH, WETH)`)

---

### Step 6 — Deploy YEWVaultChef.sol (YEW vault)

**File:** `src/YEWVaultChef.sol`
**Compiler:** Solidity 0.8.x (via-ir = true)

**Constructor args (in order):**
1. `_yew` — YEW contract address
2. `_fletchEthLP` — FLETCH-ETH LP address (from Step 5)
3. `_owner` — your deployer address
4. `_startBlock` — current block + 20

**Emission:** 0.05 YEW/block, halved 50% every 30 days (hard-coded, locked).

**After deploy:** Call `yew.setMinter(chefAddress, true)` on YEW contract.

---

### Step 7 — Create YEW-ETH LP (seeds YEW price)

1. Add liquidity to YEW/WETH pair:
   - **ETH:** ~£78 (~$100)
   - **YEW:** small amount (e.g. 1,000 YEW for £0.078 seed = higher price, or more for lower price)
2. Save the LP pair address.

---

### Step 8 — Deploy GRAZEMasterChef.sol (GRAZE vault)

**File:** `src/GRAZEMasterChef.sol`
**Compiler:** Solidity 0.8.x (via-ir = true)

**Constructor args (in order):**
1. `_fletch` — FLETCH contract address
2. `_lpToken` — `0xa70fc67c9f69da90b63a0e4c05d229954574e313` (CASHCAT-ETH LP)
3. `_yew` — YEW contract address
4. `_yewEthLP` — YEW-ETH LP address (from Step 7)
5. `_owner` — your deployer address
6. `_teamWallet` — your deployer address (or multisig)
7. `_protocolLPOwner` — your deployer address
8. `_startBlock` — current block + 20

**Emission:** 0.5 FLETCH/block, halved 50% every 30 days (hard-coded, locked).

---

### Step 9 — Authorize Chefs to Mint Tokens

**In Remix — Authorize GRAZEMasterChef to mint FLETCH:**
1. Select FLETCH contract
2. Under "Contract" → "At address" → paste GRAZEMasterChef address
3. Call `setVault(yourChefAddress, true)`

**In Remix — Authorize YEWVaultChef to mint YEW:**
1. Select YEW contract
2. Under "Contract" → "At address" → paste YEWVaultChef address
3. Call `setMinter(yourChefAddress, true)`

---

### Step 10 — Create CASHCAT-ETH LP (James's GRAZE stake)

1. Go to DEX on Robinhood Chain
2. Add liquidity to CASHCAT/WETH pair:
   - **ETH:** ~£78 (~$100)
   - **CASHCAT:** ~£78 worth (buy with ETH first or use existing)
3. Save the LP pair address (already known: `0xa70fc67c9f69da90b63a0e4c05d229954574e313`)

---

### Step 11 — Deploy GRAZEMasterChef for CASHCAT Vault

Already done in Step 8 (CASHCAT-ETH LP = GRAZEMasterChef's `_lpToken`).

**Verify:**
- Call `fletchPerBlock()` → should return `500000000000000000` (0.5 × 10^18)
- Call `startBlock()` → should be your chosen start block
- Call `poolLength()` → should return `1`

---

### Step 12 — Update Website with Contract Addresses

Update `index.html`:
- GRAZEMasterChef address
- YEWVaultChef address
- FLETCH address
- YEW address
- LP addresses

---

## Post-Deployment Checklist

- [ ] ETH on deployer wallet (Robinhood Chain)
- [ ] FLETCH deployed → address: ___________
- [ ] YEW deployed → address: ___________
- [ ] FLETCH-ETH LP created → address: ___________ (FLETCH price seeded)
- [ ] YEW-ETH LP created → address: ___________ (YEW price seeded)
- [ ] YEWVaultChef deployed → address: ___________
- [ ] YEWVaultChef authorised on YEW contract
- [ ] GRAZEMasterChef deployed → address: ___________
- [ ] GRAZEMasterChef authorised on FLETCH contract
- [ ] CASHCAT-ETH LP created → address: `0xa70fc67c9f69da90b63a0e4c05d229954574e313`
- [ ] Website updated with all addresses
- [ ] Website deployed to Netlify
- [ ] Twitter launch (@locksleyfi)

---

## Gas Estimate

Gas on Robinhood Chain is low. Total deployment cost (4 contracts): < 0.005 ETH (< ~$10 at ETH=$2000).

---

## Verification Commands

```bash
# Check block number
curl -s -X POST https://rpc.mainnet.chain.robinhood.com \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Check FLETCH total supply (should be 0 at deploy, then grows)
cast call FLETCH_ADDRESS "totalSupply()(uint256)" --rpc-url https://rpc.mainnet.chain.robinhood.com

# Check YEW total supply (should be 0 at deploy)
cast call YEW_ADDRESS "totalSupply()(uint256)" --rpc-url https://rpc.mainnet.chain.robinhood.com

# Check FLETCH per block
cast call GRAZE_ADDRESS "fletchPerBlock()(uint256)" --rpc-url https://rpc.mainnet.chain.robinhood.com

# Check YEW per block
cast call YEW_VAULT_ADDRESS "yewPerBlock()(uint256)" --rpc-url https://rpc.mainnet.chain.robinhood.com
```
