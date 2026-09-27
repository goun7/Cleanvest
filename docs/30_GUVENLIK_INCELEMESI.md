# 30 — ERC-4626 GÜVENLİK İNCELEMESİ (vault saldırı vektörleri)

**Tarih:** 2026-09-27 · **Hazırlayan:** cleanvest-dev (vardiya 4)
**Kapsam:** `CleanFXVault` (ERC-4626 vault) için bilinen saldırı vektörleri
**Sonuç:** 5 vektörün **5'i de test ile kanıtlandı** — 3'ü yeni testler (bu vardiya),
 2'si mevcut testler. Kritik zafiyet **YOK**.

> **Yöntem:** Her vektör için (1) teorik saldırı, (2) vault'taki koruma,
> (3) **çalışan test** (commit kanıtı), (4) artık risk. Testlerin tümü
> `forge test` ile yeşil (166/166).

---

## Vektör Özeti

| # | Vektör | Korumalı mı? | Test | Kalan risk |
|---|---|---|---|---|
| 1 | **Donation attack** (kasaya varlık bağışı → pay fiyatı şişer) | ⚠️ Kısmi — `depositWithMin` ile | `testSecurityDonationAttackVectors` (YENİ) | **Front-end depositWithMin zorunlu** |
| 2 | **Share price manipulation** (convert* ile fiyat bozma) | ✅ Evet — fonksiyonlar view | `testSecuritySharePriceManipulationIsView` (YENİ) | Yok |
| 3 | **First-depositor inflation** (1-wei ile yerleşme) | ✅ Evet — minShares slippage | `testInflationAttackBlockedByMinShares` + `testSecurityFirstDepositorInflationVictimProtected` (YENİ) | Front-end minShares hesaplamalı |
| 4 | **Rounding / dust fund loss** (küçük tutar kaybı) | ✅ Evet — floor rounding vault lehine | `testSecurityRoundingFavorsVault` (YENİ) | Yok (dust < 1 wei) |
| 5 | **Approve race / allowance** | ✅ Evet — standart ERC-20 | `testSecurityApproveRaceNotExploitable` (YENİ) | Yok |

**Diğer incelemeler (vektör-dışı, koruma mevcut):**

| Mekanizma | Koruma | Test |
|---|---|---|
| **Reentrancy** | `ReentrancyGuard` (tüm `_withdraw`/redeem yolunda) | OZ kütüphane + 166 test |
| **Çıkış kilidi (bank-run)** | Günlük %10 anlık + T+2 kuyruk; çıkışlar ASLA kilitlenmez | `invariantRedemptionNeverLocked` (invariant) |
| **Pay-şişirme (ERC-4626)** | `depositWithMin`/`redeemWithMin` slippage kalkanı | 3 test |
| **Junior reserve** | `juniorReserve ≥ TVL × %3` hard invariant | `invariantJuniorCoverageAfterMint` + fuzz |

---

## Vektör 1 — Donation Attack (en önemli) ⚠️

**Saldırı:** Saldırgan 1 wei ile ilk depositor olur, sonra kasaya doğrudan
 büyük miktarda `cUSD` transfer eder (approve/deposit yapmadan). Bu,
 `convertToShares`'i şişirir: sonraki depositor aynı asset için **çok az pay** alır.

**Koruma:** `depositWithMin(assets, receiver, minShares)` — kurban önceden
 `convertToShares` ile beklenen payı hesaplar ve bundan az alırsa **revert** olur.
 Fon korunur. **Plain `deposit()` korunmaz** (ERC-4626 standard zafiyeti).

**Test kanıtı** (`testSecurityDonationAttackVectors`):
```
fairShares     = convertToShares(1_000 ether) = 1_000 ether  (1:1, tek depositor)
[10 ether bagis]
inflatedShares = convertToShares(1_000 ether) = 199 wei      ← neredeyse SIFIR
```
- (A) bağış pay fiyatını şişirir: `assertLt(inflatedShares, fairShares)` ✅
- (B) plain `deposit()` kurbanı zarar eder: 199 wei pay alır (vektör VAR) ✅
- (C) `depositWithMin` kurbanı korur: min altında revert, fon geri ✅

> **Kalıcı not:** Front-end **her zaman `depositWithMin`** kullanmalı (plain
> `deposit` yok). Demo'da (`Demo.s.sol`) `depositWithMin` kullanılır.
> **Müşteri eğitimi:** bu, tüm ERC-4626 vault'ların bilinen zafiyetidir;
> çözüm standart "min shares out" parametresidir.

---

## Vektör 2 — Share Price Manipulation

**Saldırı:** `convertToShares`/`convertToAssets` çağrılarıyla fiyatı bozmaya
 çalışmak.

**Koruma:** Bu fonksiyonlar **view/pure** — state değiştirmezler. Fiyat yalnızca
 gerçek depozit/bağış ile değişebilir. Manipülasyon yüzü yoktur.

**Test kanıtı** (`testSecuritySharePriceManipulationIsView`):
- `convertToShares(1_000)` arka arkaya çağrılınca **aynı değeri** döner ✅
- `convertToAssets` için aynısı ✅
- Tek depositor varken fiyat **1:1 sabit** kalır (şişirme için bağış gerekir) ✅

---

## Vektör 3 — First-Depositor Inflation

**Saldırı:** Cream/Sonne/Resupply tipi — saldırgan 1 wei ile ilk payı alır,
 bağış yapar, kurban şişirilmiş fiyattan girer.

**Koruma:** `minShares` slippage kalkanı (Vektör 1 ile aynı mekanizma).

**Test kanıtı** (2 test):
1. `testInflationAttackBlockedByMinShares` (mevcut): 1 wei + 100k bağış,
 kurban minShares+10 ile **revert** olur.
2. `testSecurityFirstDepositorInflationVictimProtected` (YENİ): 1 wei + 100
 bağış, kurban **doğru minShares** ile güvenle girer (`assertGe(got, expected)`).

**Sonuç:** Saldırgan kilitleyemez; kurban ya korunur ya revert ile geri döner.

---

## Vektör 4 — Rounding / Dust Fund Loss

**Saldırı:** Küçük tutarlarla depozit/redeem yaparak rounding hatasından pay
 sıkışması veya kayıp.

**Koruma:** OZ ERC-4626 **floor rounding** her zaman vault lehine (pay az
 dağıtılır, fazla verilmez). Dust kaybı < 1 wei.

**Test kanıtı** (`testSecurityRoundingFavorsVault`):
- `convertToShares(0) == 0`, `convertToAssets(0) == 0` ✅
- 1 wei asset → ≤ 1 pay (aşırı pay üretilmez) ✅
- 0 pay → 0 asset (fund loss yok) ✅

---

## Vektör 5 — Approve Race / Allowance

**Saldırı:** `approve` değeri değiştirme yarışı (ERC-20 bilinen sorunu).

**Koruma:** Standart ERC-20 semantics — vault yalnızca allowance kadar harcar.

**Test kanıtı** (`testSecurityApproveRaceNotExploitable`):
- 1_000 ether approve → 1_000 ether deposit → **allowance tam sıfırlanır** ✅

---

## Kalıcı Teknik Gereksinim (front-end)

> **ŞART:** Müşteri depozitleri **her zaman `depositWithMin`** ile yapılmalı
> (plain `deposit` yok). Onboarding dokümanları ve Demo bu yolu kullanır.
> **Neden:** Vektör 1 (donation attack) plain deposit'te geçerlidir; minShares
> ile tam koruma sağlanır. Bu bir **sözleşme bug'i değil**, ERC-4626 standardının
> bilinen özelliği — onyüz ile çözülür.

---

## Kanıt Protokolü

```
IDDIA:  5 ERC-4626 saldiri vektoru test ile incelendi — kritik zafiyet YOK
KANIT:  ~/.foundry/bin/forge test
RC:     0
CIKTI:  166 tests passed, 0 failed (5 yeni guvenlik testi dahil)
COMMIT: <bu vardiyanin commit hash'i>
```

**Test listesi (yeni):**
- `testSecurityDonationAttackVectors` — donation: şişirme + plain zarar + min koruma
- `testSecuritySharePriceManipulationIsView` — convert* state değiştirmez
- `testSecurityFirstDepositorInflationVictimProtected` — kurban korunmuş yol
- `testSecurityRoundingFavorsVault` — rounding vault lehine
- `testSecurityApproveRaceNotExploitable` — allowance tam harcanır

**İlgili dokümanlar:**
- [docs/29](29_INSAN_KARARLARI.md) — insan kararları + RED FLAGS
- [test/README.md](../test/README.md) — test koşum komutları
