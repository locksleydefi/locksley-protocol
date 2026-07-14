# LOCKSLEY PROTOCOL — Deployment Guide (Remix IDE)

This guide walks you through deploying the Locksley Protocol contracts to Robinhood Chain
using [Remix IDE](https://remix.ethereum.org) (browser-based, no install needed).

---

## STEP 0 — Prerequisites

1. **MetaMask** installed with Robinhood Chain network configured
   - Network Name: Robinhood Chain
   - RPC URL: `https://api.rvndex.com/rpc` (or use public Robinhood RPC)
   - Chain ID: `1700084674` (verify this)
   - Symbol: `RHOC`
   - Block Explorer: `https://explorer.rvndex.com`

2. **Robinhood RHOC** for gas — get some from a faucet or bridge

3. **OpenZeppelin imports** — Remix will fetch these automatically from npm

---

## STEP 1 — Create a new Remix workspace

1. Go to [remix.ethereum.org](https://remix.ethereum.org)
2. Click **File** → **New File** → name it `FLETCH.sol`
3. Repeat for `YEW.sol` and `GRAZEMasterChef.sol`
4. Copy-paste the contract code into each file

---

## STEP 2 — Compile contracts

For each file, in Remix left panel → **Solidity Compiler** → **Compile**:

1. `FLETCH.sol` — set Compiler to `0.8.20`
2. `YEW.sol` — set Compiler to `0.8.20`
3. `GRAZEMasterChef.sol` — set Compiler to `0.8.20`

✅ Green tick = compiled successfully

---

## STEP 3 — Deploy FLETCH (first!)

In Remix left panel → **Deploy & Run Transactions**:

- **Environment:** Select **Injected Provider** → connect MetaMask
- **Contract:** Select `FLETCH`
- **Deploy** button — MetaMask will ask you to confirm (this is YOUR wallet, so YOU are owner)

### After deploying FLETCH:
1. Copy the **FLETCH contract address** from Remix (click the contract in "Deployed Contracts")
2. You'll use this when deploying GRAZEVault

---

## STEP 4 — Deploy YEW Treasury

- **Contract:** Select `YEW`
- **Deploy** — MetaMask confirmation

Copy the **YEW contract address**.

---

## STEP 5 — Authorize GRAZE MasterChef in FLETCH

Before deploying the vault, FLETCH needs to know the MasterChef is allowed to mint:

1. In Remix "Deployed Contracts" — click on **FLETCH**
2. Find `setVault` — enter:
   - `vault`: your GRAZEMasterChef address (deploy next, or deploy first and come back)
   - `allowed`: `true`
3. Click **transact** → MetaMask confirmation

---

## STEP 6 — Deploy GRAZEMasterChef

- **Contract:** Select `GRAZEMasterChef`
- **Deploy** with constructor args:
  - `_fletch`: Your FLETCH contract address
  - `_lpToken`: Address of the LP token (see LP addresses below)
  - `_yewTreasury`: Your YEW treasury address
  - `_owner`: Your wallet address (or a multisig — recommended for production)
  - `_startBlock`: Block number when emissions start (e.g. `block.number + 100`)

### LP Token Addresses

| Pair | Address |
|------|---------|
| CASHCAT-ETH LP | `0xa70fc67c9f69da90b63a0e4c05d229954574e313` |
| JUGGERNAUT-ETH LP | `0x588b0785f50063260003b7790c42f1ef74902746` |

---

## STEP 7 — Post-Deployment Checklist

After all 3 contracts are deployed, in this order:

### 7a. Fund the MasterChef with LP tokens (optional — for testing)
- Transfer some LP tokens to the MasterChef address manually for testing

### 7b. Set FLETCH per block reward rate
- In GRAZEMasterChef → `setFletchPerBlock`
- Example: `1e18` = 1 FLETCH per block (default)
- Formula: `X * 1e18` = X FLETCH per block

### 7c. Verify contracts on block explorer
- Go to Robinhood Block Explorer
- Verify each contract (Source code → Paste in Remix compiled ABI)

---

## Contract Interaction Cheat Sheet

Once deployed, interact via Remix "Deployed Contracts" panel:

| Action | Contract | Function |
|--------|----------|----------|
| Deposit LP | GRAZEMasterChef | `deposit(uint256 amount)` |
| Withdraw | GRAZEMasterChef | `withdraw(uint256 shares)` |
| Harvest FLETCH | GRAZEMasterChef | `harvest()` |
| Check pending FLETCH | GRAZEMasterChef | `pendingFLETCH(address user)` |
| Set FLETCH per block | GRAZEMasterChef | `setFletchPerBlock(uint256 rate)` |
| Mint FLETCH (owner) | FLETCH | `ownerMint(address to, uint256 amount)` |
| Authorize vault | FLETCH | `setVault(address vault, bool allowed)` |
| Sweep tokens | YEW | `sweepToken(IERC20 token, address to)` |

---

## Testing Checklist (testnet first!)

- [ ] Deploy to Robinhood **testnet** first (same steps, different RPC)
- [ ] Deposit 1 LP token → check shares minted
- [ ] Wait several blocks → call `pendingFLETCH(yourAddress)` → should be > 0
- [ ] Call `harvest()` → check FLETCH appears in your wallet
- [ ] Call `withdraw()` → LP returns, shares burned
- [ ] Check YEW treasury received performance fees (10%)

---

## Production Checklist

- [ ] Verify contracts on block explorer
- [ ] Transfer ownership to a multisig (Gnosis Safe)
- [ ] Set a reasonable reward rate (not too high — sustainability matters)
- [ ] Announce on socials with contract addresses
- [ ] Frontend connects to these verified addresses

---

## Vault Architecture Notes

```
User deposits LP
       ↓
GRAZEMasterChef locks LP and records shares (1:1)
       ↓
Blocks pass → rewards accrue (fletchPerBlock × blocks)
  10% → YEW Treasury (performance fee, auto-transferred)
  90% → stakers (via accFLETCHPerShare accounting)
       ↓
harvest() → mints FLETCH to user
       ↓
withdraw() → LP returns, shares burned
```
