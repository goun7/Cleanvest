# Cleanvest — Haznedarlar İçin Teklif

**Tarih:** 2026-09-26
**Hazırlayan:** Orkestratör (kendi verilerimizle)

---

## Size Sunulan Değer

Likiditenizin **%1.74'ü ortalama boşta** kalıyor. Cleanvest bunu getiriye çevirir:

| Metrik | Değer | Kaynak |
|---|---|---|
| Toplam yönetilebilir likidite | **$177.440.000** | `22_hazne_adaylari.py` (15 kurum) |
| Yıllık ek getiri | **$3.085.199** | verimsizlik farkı |
| Ortalama boşta kalma | **%1.74** | aynı analiz |

## Getiri Yapısı

| Tier | Aralık | Getiri |
|---|---|---|
| Tier 0 | $0 – $50K | **%3.05** |
| Tier 1 | $50K – $100K | **%2.91** |
| Tier 2 | $100K+ | **%2.92** |

**Kanıt:** `test/CleanFXVault.t.sol:85` — `assertApproxEqAbs(y1, 0.0291 ether)`
`testYieldCurveMatchesSpec` ile spec ile birebir doğrulanıyor.

## Nasıl Çalışır

1. **cUSD yatırın** → **scUSD** alın (ERC-4626 standardı)
2. Getiri otomatik olarak 3 tier'e göre hesaplanır
3. **Anlık %10 çıkış** + **T+2 kuyruk** (likidite garantisi)

**Teknik:** `CleanFXVault` — `ERC4626, Ownable, ReentrancyGuard`
token sembolü `scUSD`, `test/scusd_vault_invariants.t.sol` ile 5 invariant.

## Güvenlik

| Korumalar | Kanıt |
|---|---|
| **129/129 test** (0 failed) | `forge test` |
| **17/17 UI test** + 3 gerçek hata düzeltildi | `vitest` |
| **5 invariant** (300 derinlik) | `test/scusd_vault_invariants.t.sol` |
| **%86.85 line coverage** | `forge coverage` |
| **ERC-4626 standardı** | OpenZeppelin |

### İnvariant'lar
1. `juniorReserve ≥ TVL × %3` (mint sonrası)
2. Çıkışlar **ASLA kilitlenmez** (anlık %10 veya T+2)
3. Cap ≥ $100K ($3K seed ile)
4. Vault assets ≤ cUSD supply
5. Allocation toplamı 10000 bps

## Önemli Bağımlılık (şeffaf)

**$107M TVL için $3.2M junior havuz önceden gereklidir.**

- `canMint()` fonksiyonu `juniorReserve × 10000 ≥ tvl × JUNIOR_MIN_BPS` kontrolü yapar
- Yetersizse **mint-halt** (güvenlik kilidi)
- **Bu bir kısıtlama değil, güvenlik özelliğidir** — rezerv olmadan mint yapılamaz

## iletişim

Detaylı demo ve teknik doküman için iletişime geçin.

---

*Bu teklif `22_hazne_adaylari.py` çıktısı ve `forge test` sonuçları ile
otomatik doğrulanmıştır. Tüm rakamlar kanıt komutlarıyla üretilmiştir.*
