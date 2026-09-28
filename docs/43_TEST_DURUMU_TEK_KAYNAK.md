# TEST DURUMU — Tek Kaynak (Single Source of Truth)

**Son guncelleme:** 2026-09-26 · **Olcum:** taze calistirildi

> **Bu doküman TEK KAYNAKTIR.** Tum diger dokumanlar test sayilarini
> BURADAN alir. Stale (eski) sayilarin tekrarlanmesini onler.
>
> **Guncelleme kurali:** Her yeni test eklendiginde SADECE bu dosya
> guncellenir. Kopya sayilar diger dokumanlarda kalcivil eder.

---

## Taze Olculen Degerler

```bash
forge test          # Foundry
cd web && npx vitest run   # UI (frontend)
```

| Metrik | Deger | Kaynak |
|---|---|---|
| **Foundry testleri** | **187 passed, 0 failed** | `forge test` |
| **UI testleri (vitest)** | **28 passed, 0 failed** | `cd web && npx vitest run` |
| **Test suite sayisi** | 11 (forge) | `forge test` |
| **Invariant testleri** | 5 + 2 fuzz (256 runs) | `test/scusd_vault_invariants.t.sol` |
| **Line coverage** | **%96.97** (416/429) | `forge coverage --report lcov` |
| **Branch coverage** | **%96.75** (149/154) | `forge coverage --report lcov` |
| **Sozlesme sayisi** | **7** | `contracts/*.sol` |
| **TODO / placeholder** | **0** (kodda) | `audit_code_quality` |

---

## Acik Dal Analizi (kalan 2 — dead-by-design)

| Dosya:Satir | Dal | Neden ulasilamaz |
|---|---|---|
| `CleanUSD.sol:103` | `canMintAfter` false | L101 `canMint()` once calisir; ayni formul |
| `ListingGate.sol:220` | enum disi | ABI dekoderi zaten reddeder (defense-in-depth) |

**Bu 2 dal KASITLI tasarimdir, teknik borc DEGILDIR.**

---

## Guvenlik Test Ozeti (detay: docs/41)

- **ERC-4626 saldiri yuzu:** 7 test (inflation, share-price manipulation,
  donation, approve race, rounding, 2 fuzz)
- **Kuyruk-miktari binding:** `testRevertQueueAmountExceeded` (BULGU-1)
- **Reentrancy:** `CleanUSD` mint+burn `nonReentrant`
- **Enum-disi kademe:** raw calldata testi (BULGU-3)

---

## DURUST SINIR

**3. PARTI DENETIM GEREKLIDIR.** Yukaridaki tum kanitlar dahilidir
(manuel inceleme + test). Bagimsiz bir guvenlik firmasinn denetimi
bunlarin **YERINE GECMEZ**. Buyuk mevduat oncesi alinmalidir.

---

## Guncelleme Gecmisi

| Tarih | Foundry | Vitest | Not |
|---|---|---|---|
| 2026-09-26 | 187 | 28 | full-stack exit integration testi eklendi |
| 2026-09-26 | 186 | 28 | ErrorBoundary testleri (24 -> 28 vitest) |
| 2026-09-26 | 186 | 24 | 2 fuzz invariant eklendi |
| 2026-09-26 | 184 | 24 | risk paneli testi |
| 2026-09-25 | 153 | 21 | onceki durum |
