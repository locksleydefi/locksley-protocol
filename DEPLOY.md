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
3. Repeat for `YEW.sol` and `GRAZEVault.sol`
4. Copy-paste the contract code into each file

---

## STEP 2 — Compile contracts

For each file, in Remix left panel → **Solidity Compiler** → **Compile**:

1. `FLETCH.sol` — set Compiler to `0.8.20`
2. `YEW.sol` — set Compiler to `0.8.20`
3. `GRAZEVault.sol` — set Compiler to `0.8.20`

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

## STEP 5 — Authorize GRAZE Vault in FLETCH

Before deploying the vault, FLETCH needs to know the vault is allowed to mint:

1. In Remix "Deployed Contracts" — click on **FLETCH**
2. Find `setVault` — enter:
   - `vault`: your GRAZEVault address (deploy next, or deploy vault first and come back)
   - `allowed`: `true`
3. Click **transact** → MetaMask confirmation

---

## STEP 6 — Deploy GRAZEVault

- **Contract:** Select `GRAZEVault`
- **Deploy** with constructor args:
  - `_stakingToken`: Address of the LP token (e.g. CASHCAT-ETH pair on Robinhood)
    - **⚠️ For MVP:** Use WETH-ETH pair or a test LP. Get LP address from the DEX.
  - `_fletch`: Your FLETCH contract address
  - `_yew`: Your YEW treasury address
  - `_owner`: Your wallet address (or a multisig — recommended for production)

Click **Deploy** → MetaMask confirmation.

---

## STEP 7 — Post-Deployment Checklist

After all 3 contracts are deployed, in this order:

### 7a. Fund the vault with FLETCH rewards (optional — for testing)
- Transfer some FLETCH to the vault address manually (for testing without minting)

### 7b. Set reward rate
- In GRAZEVault → `setRewardRate`
- Example: `3858024691358` = ~0.004 FLETCH per second ≈ 1 FLETCH per 3 days
- Formula: `1_000_000_000_000_000_000` (1 FLETCH) / 86400 (seconds/day) / 3 (days) = `3,858,024,691,358`

### 7c. Verify contracts on block explorer
- Go to Robinhood Block Explorer
- Verify each contract (Source code → Paste in Remix compiled ABI)

---

## Contract Interaction Cheat Sheet

Once deployed, interact via Remix "Deployed Contracts" panel:

| Action | Contract | Function |
|--------|----------|----------|
| Deposit LP | GRAZEVault | `deposit(uint256 amount)` |
| Withdraw | GRAZEVault | `withdraw(uint256 sharesToRedeem)` |
| Claim FLETCH | GRAZEVault | `claimFLETCH()` |
| Harvest rewards | GRAZEVault | `harvest()` |
| Check pending FLETCH | GRAZEVault | `pendingFLETCH(address user)` |
| Set reward rate | GRAZEVault | `setRewardRate(uint256 rate)` |
| Update fees | GRAZEVault | `setFees(uint256 perf, uint256 wdw)` |
| Mint FLETCH (owner) | FLETCH | `ownerMint(address to, uint256 amount)` |
| Authorize vault | FLETCH | `setVault(address vault, bool allowed)` |
| Sweep tokens | YEW | `sweepToken(IERC20 token, address to)` |

---

## Testing Checklist (testnet first!)

- [ ] Deploy to Robinhood **testnet** first (same steps, different RPC)
- [ ] Deposit 1 LP token → check shares minted
- [ ] Wait 1 minute → call `pendingFLETCH(yourAddress)` → should be > 0
- [ ] Call `harvest()` → check FLETCH appears in vault
- [ ] Call `claimFLETCH()` → FLETCH appears in your wallet
- [ ] Call `withdraw()` → LP returns, shares burned
- [ ] Check YEW treasury received fees

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
GRAZEVault.mint shares (1:1 after 0.5% fee)
       ↓
Vault accrues FLETCH rewards per second (rewardRate)
       ↓
harvest() → mints FLETCH to vault
  10% → YEW Treasury (performance fee)
  90% → stakers (via accFLETCHPerShare accounting)
       ↓
User claims FLETCH via claimFLETCH()
```
