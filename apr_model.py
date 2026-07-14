#!/usr/bin/env python3
"""
Locksley Protocol — GRAZE Vault APR Model

Emission: 0.5 FLETCH/block. Halved 50% every 30 days.
Robinhood Chain: ~10 blocks/sec = 864,000 blocks/day = 315M blocks/year
"""
import math

GBP_TO_USD = 1.27

# ── Emission constants ────────────────────────────────────────────────────────
BPD = 864_000   # blocks per day
BPY = 315_000_000  # blocks per year (315M)

# Epoch 0 (days 1-30): 0.5 FLETCH/block
# Epoch 1 (days 31-365): 0.25 FLETCH/block
EPOCH0 = 30 * BPD * 0.5    # 12,960,000 FLETCH
EPOCH1 = 335 * BPD * 0.25  # 72,360,000 FLETCH
YEAR1_TOTAL = EPOCH0 + EPOCH1  # 85,320,000 FLETCH

print(f"Year 1 total FLETCH (halved at day 30): {YEAR1_TOTAL:,}")
print(f"  Epoch 0 (days 1-30):   {int(EPOCH0):>12,} FLETCH  [0.5/block]")
print(f"  Epoch 1 (days 31-365): {int(EPOCH1):>12,} FLETCH  [0.25/block]")
print()

# ── Helper: APR at full rate ───────────────────────────────────────────────────
def apr_full(price_gbp, tvl_gbp):
    fpy = 0.5 * BPY           # 157.5M FLETCH/year at full rate
    return (fpy * price_gbp * GBP_TO_USD) / (tvl_gbp * GBP_TO_USD)

# ── Helper: APR year-1 blended (halving accounted) ───────────────────────────
def apr_y1(price_gbp, tvl_gbp):
    return (YEAR1_TOTAL * price_gbp * GBP_TO_USD) / (tvl_gbp * GBP_TO_USD)

# ── Helper: USD value of year-1 FLETCH emissions ────────────────────────────────
def y1_usd(price_gbp):
    return YEAR1_TOTAL * price_gbp * GBP_TO_USD

# ── APR TABLE: FLETCH price vs CASHCAT TVL ─────────────────────────────────────
print("=" * 90)
print("GRAZE VAULT  |  APR by CASHCAT TVL and FLETCH Price  |  Year 1 (blended)")
print("=" * 90)
print()

tvls = [100, 1_000, 10_000, 50_000, 100_000, 250_000, 500_000, 1_000_000]

# FLETCH price scenarios (seeded via James's $100 FLETCH-ETH LP)
# $100 ETH / n FLETCH in LP = price per FLETCH
#   10,000 FLETCH in LP → price = $100/10,000 = $0.01 = £0.0078
#   20,000 FLETCH in LP → price = $100/20,000 = $0.005 = £0.0039
#    5,000 FLETCH in LP → price = $100/5,000  = $0.02 = £0.0157
#    2,000 FLETCH in LP → price = $100/2,000  = $0.05 = £0.039
#    1,000 FLETCH in LP → price = $100/1,000  = $0.10 = £0.079
scenarios = [
    (0.005, "£0.005  (¢0.4)"),
    (0.010, "£0.010  (¢0.8)"),
    (0.020, "£0.020  (1.6p)"),
    (0.050, "£0.050  (4p)  — RECOMMENDED SEED"),
    (0.100, "£0.100  (8p)"),
    (0.200, "£0.200  (16p)"),
]

hdr = f"{'FLETCH Price':<30}" + "".join(f"{'£'+str(t):>12}" for t in tvls)
print(hdr)
print("-" * 90)
for price, label in scenarios:
    row = f"{label:<30}"
    for tvl in tvls:
        a = apr_y1(price, tvl) * 100
        row += f"{a:>11.1f}%"
    print(row)

print()
print("^ Numbers in table = Year 1 blended APR (accounting for day-30 halving)")
print()

# ── After 1st halving (Month 2+) ───────────────────────────────────────────────
print("=" * 90)
print("GRAZE VAULT  |  APR after 1st Halving  |  Rate: 0.25 FLETCH/block")
print("=" * 90)
print()
print(hdr)
print("-" * 90)
for price, label in scenarios:
    row = f"{label:<30}"
    for tvl in tvls:
        a = apr_full(price/2, tvl) * 100   # rate halved = price_effective/2
        row += f"{a:>11.1f}%"
    print(row)

print()

# ── James's bootstrap scenarios ────────────────────────────────────────────────
print("=" * 90)
print("JAMES'S BOOTSTRAP  |  GRAZE Vault with CASHCAT-ETH LP")
print("=" * 90)
print()
print(f"{'FLETCH Price':<18} {'CASHCAT TVL':>12}  {'Yr1 APR':>9}  {'Yr1 FLETCH Earned':>18}  {'$/yr on deposit':>15}")
print("-" * 90)

scenarios_j = [
    (0.005, 100,   "£100 seed (James)"),
    (0.010, 100,   "£100 seed (James)"),
    (0.050, 100,   "£100 seed (James)"),
    (0.050, 1_000, "£1k — early adopter"),
    (0.050, 10_000,"£10k — growing"),
    (0.050, 50_000,"£50k — decent traction"),
    (0.050, 100_000,"£100k — target month 1"),
    (0.100, 100_000,"£100k — target month 1"),
    (0.050, 250_000,"£250k — healthy"),
    (0.050, 500_000,"£500k — strong"),
    (0.100, 500_000,"£500k — strong"),
    (0.050, 1_000_000,"£1M — institutional"),
    (0.100, 1_000_000,"£1M — institutional"),
]

for price, tvl, note in scenarios_j:
    a   = apr_y1(price, tvl) * 100
    f_y = YEAR1_TOTAL * (100 / (tvl * GBP_TO_USD))   # FLETCH per £100 deposited
    v_y = YEAR1_TOTAL * price * GBP_TO_USD * (100 / (tvl * GBP_TO_USD))  # USD/yr on £100
    print(f"£{price:<17.3f} {'£'+str(tvl):>12}  {a:>8.1f}%  {f_y:>17,.0f}  ${v_y:>14,.2f}  ({note})")

print()
print()

# ── Realistic model: FLETCH price £0.05 seeded ─────────────────────────────────
print("=" * 90)
print("RECOMMENDED: James seeds FLETCH-ETH LP with £78 ($100) ETH + 2,000 FLETCH")
print("FLETCH price = £78 / 2,000 = £0.039 (~$0.05) — conservative mid-market")
print("=" * 90)
print()

REC_PRICE = 0.039   # £/FLETCH if James seeds with 2,000 FLETCH
REC_USD   = REC_PRICE * GBP_TO_USD  # ~$0.05

print(f"FLETCH starting price: £{REC_PRICE:.3f} (${REC_USD:.4f})")
print(f"Year 1 FLETCH emissions: {YEAR1_TOTAL:,} FLETCH = ~${y1_usd(REC_PRICE)/1_000_000:.1f}M value emitted")
print()
print(f"{'CASHCAT TVL':>14}  {'Year 1 APR':>10}  {'Year 2 APR*':>11}  {'£/yr on £100':>14}  {'Yr1 FLETCH/£100':>17}")
print("-" * 90)

tvl_range = [100, 1_000, 10_000, 50_000, 100_000, 250_000, 500_000, 1_000_000]
for tvl in tvl_range:
    a1  = apr_y1(REC_PRICE, tvl) * 100
    a2  = apr_full(REC_PRICE, tvl) * 100  # year 2 = full second year at 0.25/block
    vy  = YEAR1_TOTAL * REC_PRICE * GBP_TO_USD * (100 / (tvl * GBP_TO_USD))
    fy  = YEAR1_TOTAL * (100 / (tvl * GBP_TO_USD))
    tstr = "£" + str(tvl)
    print(f"{tstr:>14}  {a1:>9.1f}%  {a2:>10.1f}%  £{vy:>13,.2f}  {fy:>16,.0f}")

print()
print(f"* Year 2 APR: rate is still 0.25/block (not yet halved again). Halves again at day 60.")
print()

# ── FLETCH market cap and inflation ───────────────────────────────────────────
print("=" * 90)
print("FLETCH MARKET CAP & INFLATION  |  FLETCH price £0.039 (~$0.05)")
print("=" * 90)
print()
print(f"{'CASHCAT TVL':>14}  {'FLETCH MC':>14}  {'Yr1 Emmission':>14}  {'Inflation':>10}  {'Post-Yr1 Dilution':>18}")
print("-" * 90)

for tvl in [100_000, 250_000, 500_000, 1_000_000]:
    mc    = tvl / GBP_TO_USD * 3   # assume FLETCH MC = 3× CASHCAT TVL (rough benchmark)
    inf_pct = YEAR1_TOTAL / mc * 100
    tstr = f"£{tvl:,}"
    print(f"{tstr:>14}  ${mc/1e6:>12.2f}M  {YEAR1_TOTAL:>13,}  {inf_pct:>9.1f}%  {'≈ 1yr annual dilution':>17}")

print()
print("Note: MC estimate = 3× CASHCAT TVL. As TVL grows, same emission = lower % dilution.")
print()

# ── YEW vault ─────────────────────────────────────────────────────────────────
print("=" * 90)
print("YEW VAULT  |  FLETCH-ETH LP staked → earn YEW  |  0.05 YEW/block (10× less)")
print("=" * 90)
print()
YEW_BPY = 0.05 * BPY   # 15.75M YEW/year at full rate
YEW_Y1  = 0.05 * EPOCH0 + 0.025 * EPOCH1  # 8,532,000 YEW

yew_scenarios = [
    (0.005, "YEW £0.005"),
    (0.010, "YEW £0.010"),
    (0.020, "YEW £0.020"),
    (0.050, "YEW £0.050"),
    (0.100, "YEW £0.100"),
    (0.200, "YEW £0.200"),
]

hdr2 = f"{'YEW Price':<18}" + "".join(f"{'£'+str(t):>12}" for t in tvls)
print(hdr2)
print("-" * 90)
for price, label in yew_scenarios:
    row = f"{label:<18}"
    for tvl in tvls:
        a = (YEW_Y1 * price * GBP_TO_USD) / (tvl * GBP_TO_USD) * 100
        row += f"{a:>11.1f}%"
    print(row)

print()
print("YEW Year 1 emission: 8,532,000 YEW = 0.85% of 1bn max supply — very low inflation")
print()

# ── Key takeaways ───────────────────────────────────────────────────────────────
print("=" * 90)
print("KEY TAKEAWAYS")
print("=" * 90)
print("""
1. FLETCH PRICE is set by James's LP seed:
   $100 ETH / n FLETCH in LP = FLETCH price
   More FLETCH in LP = lower price = HIGHER APR (in % terms)
   Less FLETCH in LP = higher price = more premium, lower APR

2. RECOMMENDED SEED: £78 ($100) ETH + 2,000 FLETCH → price £0.039 (~$0.05)
   This gives FLETCH a ~$500k market cap at 10M circulating (reasonable for new farm)

3. With £100k CASHCAT TVL and £0.039 FLETCH:
   Year 1 APR ≈ 3,000%+  (blended, with halving)
   Year 2 APR ≈ 1,500%+  (rate still halved, no further halving until day 60)

4. As TVL grows:
   £100k TVL → APR compresses from 3,000% to 300% at £1M TVL
   This is NATURAL and healthy — early degens get the highest rewards

5. FLETCH Year 1 inflation: 85.32M FLETCH = 8.5% of 1bn max supply
   If FLETCH MC = £790k (3× £100k TVL × £0.039), that's 10.8× annual inflation
   → Price will find its level. High early APR attracts capital.

6. YEW vault earns 10× less YEW than GRAZE earns FLETCH (by design)
   YEW vault ≈ 10% of GRAZE APR (in the same TVL scenario)
""")
