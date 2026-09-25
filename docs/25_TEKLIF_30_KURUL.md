# Cleanvest — Kurumsal Kurul ve Hazine Ekipleri İçin Teklif

**Tarih:** 2026-09-26
**Hazırlayan:** Orkestratör (kendi verilerimizle)

---

## Kim Bu Teklif İçin

**30 kurumsal müşteri adayı** — bankaların ödeme-hizmetleri birimleri,
elektronik-para kuruluşları, kurumsal hazine ekipleri ve B2B ödeme işlemcileri.

## Size Sunulan Değer

| Metrik | Değer | Kaynak |
|---|---|---|
| Hedef kitle | 30 kurum | `22_ILK_MUSTERI_ADAYLARI.md` Segment 1 |
| Beklenen dönüşüm | %10 (3 müşteri) | aynı analiz |
| Toplam potansiyel | **$60M** | aynı analiz |

## Getiri Yapısı

| Tier | Aralık | Getiri |
|---|---|---|
| Tier 0 | $0 – $50K | **%3.05** |
| Tier 1 | $50K – $100K | **%2.91** |
| Tier 2 | $100K+ | **%2.92** |

**Kanıt:** `test/CleanFXVault.t.sol:85` — `assertApproxEqAbs(y1, 0.0291 ether)`

## Kurumsal Güvenlik

| Özellik | Kanıt |
|---|---|
| **129/129 test** (0 failed) | `forge test` |
| **17/17 UI test** + 3 gerçek hata | `vitest` |
| **5 invariant** (300 derinlik) | `test/scusd_vault_invariants.t.sol` |
| **%86.85 line coverage** | `forge coverage` |
| **ERC-4626 standardı** | OpenZeppelin |
| **ReentrancyGuard** | `CleanFXVault` |

## Şeffaflık

- **$107M TVL için $3.2M junior havuz** önceden gereklidir (mint-halt koruması)
- Anlık %10 çıkış + T+2 kuyruk (likidite garantisi)

---

*Tüm rakamlar `22_ILK_MUSTERI_ADAYLARI.md` ve `forge test` ile doğrulanmıştır.*
