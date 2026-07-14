# DEPLOY.md — Locksley Protocol Mainnet Deployment Guide

**Chain:** Robinhood Chain | Chain ID: 4663 | RPC: https://rpc.mainnet.chain.robinhood.com

---

## Prerequisites

- MetaMask or wallet with ETH on Robinhood Chain for gas
- Remix IDE (https://remix.ethereum.org)
- RPC for_chain: https://rpc.mainnet.chain.robinhood.com
- Chain ID: 4663
- Block Explorer: https://robinhoodchain.blockscout.com

---

## On-Chain Addresses (Confirmed)

| Asset | Address |
|-------|---------|
| WETH | `0x0bd7d308f8e1639fab988df18a8011f41eacad73` |
| CASHCAT | `0x020bfc650a365f8bb26819deaabf3e21291018b4` |
| JUGGERNAUT | `0xd7321801caae694090694ff55a9323139f043b88` |
| CASHCAT-ETH LP | `0xa70fc67c9f69da90b63a0e4c05d229954574e313` |
| JUGGERNAUT-ETH LP | `0x588b0785f50063260003b7790c42f1ef74902746` |
| Uniswap V2 Factory | `0x1f7d7550b1b028f7571e69a784071f0205fd2efa` |
| Uniswap V2 Router | `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D` |

**NOTE:** The Uniswap V2 Router at `0x7a250d...` may return empty code via eth_getCode — use the factory for pair lookups. The router address is confirmed active via on-chain transactions.

---

## Deployment Steps

### Step 1 — Deploy FLETCH.sol

**File:** `src/FLETCH.sol`

**Constructor args:**
- `_owner` — your wallet address (the account deploying)

**After deploy:** Copy the FLETCH contract address

---

### Step 2 — Deploy YEW.sol

**File:** `src/YEW.sol`

**Constructor args:**
- `initialOwner` — your wallet address

**Important:** YEW supply = 10,000,000 × 10^18 (fixed forever). All tokens go to `initialOwner` — this is the community treasury. Treat this address carefully.

**After deploy:** Copy the YEW contract address

---

### Step 3 — Create YEW/ETH LP on Uniswap V2

**⚠️ Do this BEFORE deploying GRAZEMasterChef — the chef needs the YEW/ETH LP address.**

1. Go to https://robinhoodchain.blockscout.com or your wallet's DEX interface
2. Navigate to the Uniswap V2 interface (or use the RVNDEX frontend)
3. Add initial liquidity:
   - **Token A:** ETH (native) — seed with ~$50-100 worth
   - **Token B:** YEW — seed with ~$50-100 worth of YEW tokens
4. This creates the YEW/ETH LP pair and sets the initial price
5. **Save the LP pair address** — you'll need it for GRAZEMasterChef

**Note:** To get the YEW/ETH LP address, either:
- Read it from the `PairCreated` event emitted by the factory, OR
- Use `getPair(YEW, WETH)` on the factory contract

---

### Step 4 — Deploy GRAZEMasterChef.sol

**File:** `src/GRAZEMasterChef.sol`

**Constructor args (in order):**
1. `_fletch` — FLETCH contract address
2. `_lpToken` — CASHCAT-ETH LP address: `0xa70fc67c9f69da90b63a0e4c05d229954574e313` (or JUGGERNAUT-ETH LP for second vault)
3. `_yew` — YEW contract address
4. `_yewEthLP` — YEW/ETH LP pair address (from Step 3)
5. `_owner` — your wallet address
6. `_teamWallet` — your wallet address (or multisig later)
7. `_protocolLPOwner` — your wallet address (or a separate POA address)
8. `_startBlock` — current block number + a few blocks for buffer (use blockNumber from RPC)

**To get current block number:**
```bash
curl -s -X POST https://rpc.mainnet.chain.robinhood.com \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

Add ~10 blocks to the result for `_startBlock`.

**After deploy:**
- Copy GRAZEMasterChef address
- Call `fletch.setVault(chefAddress, true)` to authorize the chef to mint FLETCH
- Verify on block explorer

---

### Step 5 — Authorize Chef to Mint FLETCH

After deploying GRAZEMasterChef, you need to call `setVault()` on the FLETCH contract:

**In Remix:**
1. Select FLETCH contract
2. Call `setVault`
3. Arg 1: GRAZEMasterChef address
4. Arg 2: `true`

---

## Verifying on Block Explorer

1. Go to https://robinhoodchain.blockscout.com
2. Search your contract addresses
3. Verify:
   - FLETCH: has `setVault` function called by owner
   - YEW: has 10M total supply
   - GRAZEMasterChef: `fletchPerBlock()` returns 1e18
   - GRAZEMasterChef: `teamWallet()` returns your address

---

## Gas

Gas price on Robinhood Chain is very low (~50 Gwei equivalent). Deployment should cost < $1 in ETH.

---

## Post-Deployment Checklist

- [ ] FLETCH deployed and chef authorised
- [ ] YEW deployed with 10M supply
- [ ] YEW/ETH LP created and seeded with $100
- [ ] GRAZEMasterChef deployed for CASHCAT-ETH vault
- [ ] Deploy second GRAZEMasterChef for JUGGERNAUT-ETH if desired
- [ ] Update website with all contract addresses
- [ ] Set up monitoring for chef contract (FLETCH minting, fee collection)
