# LOCKSLEY PROTOCOL — Product Spec

**Last updated:** 2026-07-14 (renamed from Sherwood Protocol)

## Brand
- **Protocol:** LOCKSLEY
- **Staking Product:** GRAZE
- **Reward Token:** FLETCH
- **Treasury:** YEW
- **Future Vaults:** THE GLADE

## Core Product
Yield aggregator / LP staking protocol on Robinhood Chain.

Users deposit LP tokens → earn FLETCH rewards → FLETCH has value from fee accumulation in YEW treasury.

## Fee Model
- Performance fee: 10% on harvested yield
- Withdrawal fee: 0.5% (discourages rapid exits)
- Management fee: $0

## Tokenomics
- FLETCH: ERC20, minted by vault contract only
- Total supply: uncapped (inflationary rewards model)
- Value backed by YEW treasury accumulation

## Vaults (MVP)
1. GRAZE — CASHCAT-ETH LP — `0xa70fc67c9f69da90b63a0e4c05d229954574e313`
2. GRAZE — FLETCH-ETH LP — TBD (create FLETCH-ETH pool on DEX after deployment)
3. GRAZE — JUGGERNAUT-ETH LP — `0x588b0785f50063260003b7790c42f1ef74902746`
4. THE GLADE — VEX-ETH LP (Virtuals V2) — Coming soon

## Tech Stack
- Contracts: Solidity (OpenZeppelin)
- Frontend: HTML/CSS/JS (MVP), React (future)
- Deploy target: Remix IDE + MetaMask
- Chain: Robinhood Chain (EVM)

## Design Language
- 2020 DeFi era aesthetic (Yearn, Beefy, Pickle)
- Dark forest theme: #0a0f0a background, #c9a227 gold accents
- Neon green for positive numbers (#39ff14)
- Space Mono for numbers/headers, Rajdhani for body
- Forest/locksley visual identity throughout

## Next Steps
- [x] Write Solidity contracts (FLETCH, YEW, GRAZEMasterChef)
- [x] Build frontend (HTML/CSS/JS MVP)
- [ ] Verify FLETCH and YEW token names available on Robinhood Chain
- [ ] Test on Robinhood testnet
- [ ] Deploy via Remix
- [ ] Host frontend on Netlify
- [x] Write Litepaper
- [ ] Socials setup (Twitter, Discord, Telegram)
- [ ] Seed LP (community or tiny seed)
- [ ] Launch
