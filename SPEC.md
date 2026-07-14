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
1. GRAZE — CASHCAT-ETH LP (Noxa) — Featured vault
2. GRAZE — FLETCH-ETH LP (own LP)
3. GRAZE — JUGGERNAUT-ETH LP (Noxa)
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
1. Verify FLETCH and YEW token names available on Robinhood Chain
2. Write Litepaper
3. Write Solidity contracts (FLETCH, YEW, GRAZE vault)
4. Test on Robinhood testnet
5. Deploy via Remix
6. Build frontend
7. Host frontend on Netlify
8. Socials setup (Twitter, Discord, Telegram)
9. Seed LP (community or tiny seed)
10. Launch
