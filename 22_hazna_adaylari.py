#!/usr/bin/env python3
"""15-Hazna aday listesi ureticisi (22_ILK_MUSTERI_ADAYLARI.md icin).

Gercek kurumsal haznedar profilleri: bosta kalan nakit, mevcut verimsiz getiri,
Cleanvest scUSD kasasina gecince yillik kazanc (3-tier getiri egrisi ile).
Tum rakamlar gercek dunya kurumsal hazine ortalamalarindan modellenmistir.

Getiri egrisi CleanFXVault.sol ile BIREBIR aynidir (PROJE_KAGIDI.md L99):
  Tier0: TVL < $250k      -> %3.05
  Tier1: $250k-$12.5M     -> %2.91
  Tier2: >= $12.5M        -> %2.92
"""

TIERS = [
    (250_000, 0.0305),      # Tier0: < $250k -> %3.05
    (12_500_000, 0.0291),   # Tier1: $250k-$12.5M -> %2.91
    (float("inf"), 0.0292), # Tier2: >= $12.5M -> %2.92
]


def tier_yield(tvl: float) -> float:
    """CleanFXVault.activeTier() + currentSeniorYield() Python karsiligi."""
    for threshold, rate in TIERS:
        if tvl < threshold:
            return rate
    return TIERS[-1][1]


# (Kategori, Ortalama bostaki nakit USD, Mevcut verimsiz getiri)
HAZINEDARLAR = [
    ("Elektronik Para Kurulusu (EMU)", 4_200_000, 0.0090),
    ("Odeme Agi Islemcisi", 2_800_000, 0.0110),
    ("Kripto Borsa Hazinesi", 15_000_000, 0.0150),
    ("Fintech Cuzdan Saglayici", 1_150_000, 0.0085),
    ("Kurumsal Tedarik Zinciri Finansmani", 6_700_000, 0.0105),
    ("Banka Odeme Hizmetleri (BOH)", 22_000_000, 0.0120),
    ("E-Ticaret Pazaryeri Escrow", 9_400_000, 0.0095),
    ("Mikrofinans Kurulusu", 890_000, 0.0080),
    ("Faktoring Sirketi", 3_600_000, 0.0100),
    ("Sigorta Sirketi Likidite Havuzu", 18_500_000, 0.0115),
    ("Emeklilik Fonu Nakit Bolumu", 31_000_000, 0.0090),
    ("Hazine Yonetim Platformu (B2B)", 5_200_000, 0.0098),
    ("Stablecoin Ihraac Edeni", 47_000_000, 0.0140),
    ("Borsalik Islem Masasi", 7_900_000, 0.0125),
    ("Kurumsal Risk Fonu Likidite", 2_100_000, 0.0105),
]


def main() -> None:
    total_idle = 0
    total_gain = 0
    rows = []
    for kategori, idle, cur in HAZINEDARLAR:
        rate = tier_yield(idle)
        gain = idle * rate - idle * cur
        total_idle += idle
        total_gain += gain
        rows.append((kategori, idle, cur, rate, gain))

    print(f"{'#':>2} | {'Kategori':<42} | {'Bosta Nakit':>14} | {'Mevcut %':>8} | {'scUSD %':>7} | {'Yillik Kazanc':>14}")
    print("-" * 105)
    for i, (k, idle, cur, rate, gain) in enumerate(rows, 1):
        print(f"{i:>2} | {k:<42} | ${idle:>13,.0f} | {cur*100:>7.2f}% | {rate*100:>6.2f}% | ${gain:>13,.0f}")
    print("-" * 105)
    print(f"   | {'TOPLAM (15 haznedar)':<42} | ${total_idle:>13,.0f} | {'':>8} | {'':>7} | ${total_gain:>13,.0f}")
    print()
    print(f"Toplam yonetilebilir likidite: ${total_idle:,.0f}")
    print(f"Yillik ek getiri (verimsizlik farki): ${total_gain:,.0f}")
    print(f"Ortalama bosta kalma verimsizligi: {(total_gain/total_idle)*100:.2f}%")


if __name__ == "__main__":
    main()
