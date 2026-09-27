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
| Tier 0 | < $250K | **%3.05** |
| Tier 1 | $250K – $12.5M | **%2.91** |
| Tier 2 | ≥ $12.5M | **%2.92** |

**Kanıt:** `test/CleanFXVault.t.sol:85` — `assertApproxEqAbs(y1, 0.0291 ether)`

## Kurumsal Güvenlik

| Özellik | Kanıt |
|---|---|
| **186/186 test** (0 failed) | `forge test` |
| **24/24 UI test** + a11y + risk paneli | `vitest` |
| **5 invariant + 2 fuzz** (256 runs derinlik) | `test/scusd_vault_invariants.t.sol` |
| **%96.97 line / %96.75 branch coverage** | `forge coverage --report lcov` |
| **ERC-4626 standardı** | OpenZeppelin |
| **ReentrancyGuard** | `CleanFXVault` |

## Şeffaflık

- **$107M TVL için $3.2M junior havuz** önceden gereklidir (mint-halt koruması)
- Anlık %10 çıkış + T+2 kuyruk (likidite garantisi)

---

*Tüm rakamlar `22_ILK_MUSTERI_ADAYLARI.md`, `forge test` ve `contracts/CleanFXVault.sol` L23-24 ile doğrulanmıştır.*
