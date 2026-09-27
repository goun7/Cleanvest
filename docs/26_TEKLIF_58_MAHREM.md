# Cleanvest — Gizlilik-Duyarlı Müşteriler İçin Teklif

**Tarih:** 2026-09-26
**Hazırlayan:** Orkestratör (kendi verilerimizle)

---

## Kim Bu Teklif İçin

**58 müşteri adayı** — gizlilik-duyarlı kurumsal müşteriler: offshore yapılar,
aile ofisleri, yüksek-net-değerli bireylerin yöneticileri, mahrem veri taşıyan
ödeme kuruluşları.

## Size Sunulan Değer

| Metrik | Değer | Kaynak |
|---|---|---|
| Hedef kitle | 58 kurum/birey | `22_ILK_MUSTERI_ADAYLARI.md` Segment 2 |
| Beklenen dönüşüm | %10 (6 müşteri) | aynı analiz |
| Toplam potansiyel | **$2.4M** | aynı analiz |

## Gizlilik İçin Neden Cleanvest

- **Spot borsa, sıfır manipülasyon** — fiyat akışı şeffaf
- **ERC-4626 standardı** — tanınmış, denetlenebilir protokol
- **ReentrancyGuard + Ownable** — yetkisiz erişim yok
- **Çıkışlar ASLA kilitlenmez** — anlık %10 + T+2 kuyruk

## Getiri Yapısı

| Tier | Aralık | Getiri |
|---|---|---|
| Tier 0 | < $250K | **%3.05** |
| Tier 1 | $250K – $12.5M | **%2.91** |
| Tier 2 | ≥ $12.5M | **%2.92** |

**Kanıt:** `test/CleanFXVault.t.sol:85` — spec ile birebir

## Güvenlik Kanıtları

| Özellik | Kanıt |
|---|---|
| **186/186 test** (0 failed) | `forge test` |
| **5 invariant + 2 fuzz** (256 runs derinlik) | `test/scusd_vault_invariants.t.sol` |
| **%96.97 line / %96.75 branch coverage** | `forge coverage --report lcov` |

## Şeffaflık

**$107M TVL için $3.2M junior havuz** önceden gereklidir (mint-halt koruması).

---

*Tüm rakamlar `22_ILK_MUSTERI_ADAYLARI.md`, `forge test` ve `contracts/CleanFXVault.sol` L23-24 ile doğrulanmıştır.*
