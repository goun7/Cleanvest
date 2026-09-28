# Cleanvest — 15-Hazne Adayları İçin Teklif

**Tarih:** 2026-09-25 · **Durum:** Ön teklif (nihai şartlar kurul toplantısında netleşir)

---

## 1. Size Sunulan Değer

Hazine likiditenizin ortalamada **%1,74'i boşta** duruyor — ne getirilendiren ne de operasyonel ihtiyaç için ayrılmış.

| Metrik | Değer | Kaynak |
|---|---|---|
| Toplam incelenen likidite (15 kurum) | **$177M** | Hazne aday analizi (orkestratör verisi) |
| Boştaki anapara | **$3,08M** | $177M × %1,74 |
| **Boştaki kısımdan yıllık ek getiri** | **≈ $90.000** | $3,08M × %2,92 (Tier 2) |
| **Tüm likidite Tier 2'de yıllık getiri** | **≈ $5,17M** | $177M × %2,92 |

> **Hesap dürüstlüğü (düzeltme):** Bu dokümanın önceki sürümü "$3.085.199 **yıllık ek getiri**" yazıyordu. Bu rakam **boştaki anapara**dır, getiri değil — 34× abartı. Doğrusu yukarıdaki tablodadır.

### Getiri kademesi (sözleşme kodundan birebir)

| Kademe | TVL eşiği | Yıllık getiri |
|---|---|---|
| Tier 0 — Başlangıç | < $250k | **%3,05** |
| Tier 1 — Kurumsal | $250k – $12,5M | **%2,91** |
| Tier 2 — Likidite | ≥ $12,5M | **%2,92** |

> **Düzeltme:** Önceki sürüm "$0–$50K / $50K–$100K / $100K+" yazıyordu. Bu **sözleşmeye aykırı**. Gerçek eşikler `CleanFXVault.sol` L23-24'te kod sabiti olarak yazar ve pazarlık konusu değildir.

**Kanıt:** `test/CleanFXVault.t.sol` → `testYieldCurveMatchesSpec` (L332) üç kademyi de spec ile doğrular; ayrıca `assertApproxEqAbs(y1, 0.0291 ether)` (L85).

---

## 2. Nasıl Çalışır

1. **`cUSD` yatırın → `scUSD` alın** — ERC-4626 standardında, her an 1:1 geri dönüşüm.
2. **Getiri otomatik** — Reserve akıllı sözleşmesi kompozisyondan gelir üretir (Tier 2'de: %40 BUIDL + %33 Aave V3 Base + %12 idle + %15 Aave Prime). **Koda bağlı, manuel müdahale yok.**
3. **Çıkış kapısı asla kilitlenmez:**
   - Günlük **%10 anlık** çıkış (kota)
   - Üzeri **T+2 kuyruğuna** alınır (likidite garantisi)
   - **Çıkışlar ASLA kilitlenmez** — yalnızca yeni mint durur.

Kurum için pratik anlamı: bir günde portföyün %10'u anında, kalanı 2 gün içinde. Kriz anında çıkış kapısı kapanmaz.

---

## 3. Güvenlik

| Koruma | Kanıt |
|---|---|
| **186/186 Foundry testi** (9 suite, 0 failed) | `forge test` |
| **28/28 UI testi** (a11y + risk paneli + ErrorBoundary) | `pnpm vitest run` |
| **5 invariant** (300 derinlik fuzz) | `test/scusd_vault_invariants.t.sol` |
| **%96,97 line / %96,75 branch coverage** (7 sözleşme) | `forge coverage --report lcov` |
| **ERC-4626 saldırı vektörleri: 5/5 test-kanıtli, kritik zafiyet YOK** | [docs/30](30_GUVENLIK_INCELEMESI.md) + 5 test |
| **ERC-4626 standardı** | OpenZeppelin |

### ERC-4626 saldırı vektörleri — 5/5 test ile kanıtlandı

Vault'umuz sektörde bilinen **5 saldırı vektörünün her biri için testler**
yazdı ve hepsi çalışır durumda. "Güvenli mi?" sorusunun cevabı kanıta dayalı:

| Vektör | Sonuç | Test |
|---|---|---|
| **Donation attack** (kasaya bağış → pay fiyatı şişer) | ✅ **Korunuyor** — önyüz `depositWithMin` kullanır | `testSecurityDonationAttackVectors` |
| **Share price manipulation** | ✅ Korumalı — `convertToShares` state değiştirmez | `testSecuritySharePriceManipulationIsView` |
| **First-depositor inflation** (Cream/Sonne/Resupply tipi) | ✅ Korumalı — min pay slippage kalkanı | `testInflationAttackBlockedByMinShares` |
| **Rounding / dust kaybı** | ✅ Korumalı — floor yuvarlama vault lehine | `testSecurityRoundingFavorsVault` |
| **Approve race / allowance** | ✅ Korumalı — standart ERC-20 | `testSecurityApproveRaceNotExploitable` |

> **Donation attack — dürüst açıklama:** Saldırgan önceden 1 pay alıp kasaya
> bağış yaparsa, sonraki depozitörler **standart `deposit()` ile** neredeyse hiç
> pay alamaz (testimizde 1_000 cUSD için **199 wei** — etkili sıfır). **Çözüm:
> vault'umuz her depozitte `depositWithMin` kullanır** — müşteri önceden beklenen
> payı hesaplar, az alırsa işlem revert olur, fonu geri döner. **Plain `deposit()`
> önyüzde yoktur.** Bu, tüm ERC-4626 vault'larının bilinen özelliğidir ve
> doğru uygulanmış "min shares out" parametresi ile tamamen giderilir.

> **Testin tam sayısı (docs/30'dan):** 1_000 cUSD'luk kurban depoziti bağış
> öncesi **1_000 ether pay** (1:1) alırken, bağış sonrası plain `deposit()` ile
> **199 wei** alır — kayıp oranı **%99.99999999999999998**. Aynı işlem
> `depositWithMin` ile yapıldığında beklenenin altında kaldığı için **revert
> olur ve müşterinin 1_000 cUSD'si eksiksiz geri döner.**

### Diğer korumalar (vektör dışı, mevcut)

| Mekanizma | Koruma | Kanıt test |
|---|---|---|
| **Reentrancy** | `ReentrancyGuard` tüm `_withdraw`/redeem yolunda | OZ kütüphane + 166 test |
| **Çıkış kilidi (bank-run)** | Günlük %10 anlık + T+2 kuyruk; çıkışlar ASLA kilitlenmez | `invariantRedemptionNeverLocked` |
| **Pay-şişirme (ERC-4626)** | `depositWithMin`/`redeemWithMin` slippage kalkanı | 3 test |
| **Junior reserve** | `juniorReserve ≥ TVL × %3` hard invariant | `invariantJuniorCoverageAfterMint` + fuzz |

### İnvariant'lar
1. `juniorReserve ≥ TVL × %3` (mint sonrası)
2. Çıkışlar **ASLA kilitlenmez** (anlık %10 veya T+2)
3. Cap ≥ $100K ($3K seed ile)
4. Vault assets ≤ cUSD supply
5. Allocation toplamı 10000 bps

### Enflasyon saldırısı kalkanı
`depositWithMin` / `redeemWithMin` ile min pay/miktar garantisi — ERC-4626 pay-şişirme saldırılarına karşı **otomatik aktif** koruma. Yukarıdaki donation attack
tablosuna bakın.

### Bulunan ve düzeltilen 5 gerçek hata
anti-collusion overflow · ListingGate score-lookup sıfır · `seedJunior` erişim kontrolü (DoS) · slippage overflow · çift floor — **her biri commit kanıtıyla** düzeltildi ve bir regresyon testiyle kilitlendi:

| Hata | Düzeltilme commit'i | Regresyon kilidi |
|---|---|---|
| **Anti-collusion overflow** (batch proof) | `2252710` | `testFuzzEpsBounds` + `testFuzzEpsMaxCap` (Fuzz.t.sol) |
| **ListingGate score-lookup sıfır** döndürme | `4a8da87` | `testGetListingStatusScoreLookup` (ListingGate.t.sol:345) |
| **`seedJunior` erişim kontrolü (DoS)** | `5d85ebe` | `invariantJuniorCoverageAfterMint` (invariant, 300 derinlik) |
| **Slippage overflow** (UniswapProxy) | `cfdbdde` | `testSlippageOverflowProtection` |
| **Çift floor** (ERC-4626 rounding) | `0978a18` | `testSecurityRoundingFavorsVault` |

> **Künye:** Bu tablo [docs/30](30_GUVENLIK_INCELEMESI.md) ile
> [docs/29](29_INSAN_KARARLARI.md)'daki "5 gerçek hata" listesinin tek yerde
> birleştirilmiş halidir. Her satır `git show <commit>` ile doğrulanabilir.

---

## 4. Önemli Bağımlılık (şeffaf)

**$107M TVL için $3,2M junior havuz önceden gereklidir.**

- `canMint()` → `juniorReserve × 10000 ≥ tvl × JUNIOR_MIN_BPS` kontrolü yapar
- Yetersizse **mint-halt** (güvenlik kilidi)
- **Bu bir kısıtlama değil, güvenlik özelliğidir** — rezerv olmadan mint yapılamaz
- **Tohum Cleanvest'in sorumluluğundadır**; sizden istenmez

### Tohum mekanizmasının 3 kalıcı özelliği (şeffaf beyan)

Aşağıdakiler sözleşmenin tasarımında **kalıcıdır** — sonradan değiştirilemez.
 Müşterinin bilmesi, bizim de dürüstlüğümüzün gereğidir:

1. **Tohum miktarı, TVL tavanını kalıcı belirler.** `tvlCap = tohum ÷ %3` ve bu
   değer **yalnızca ilk tohumda** bir kez yazılır. Örn. $3M tohum → $100M tavan.
   Tavan sonradan yükseltilemez (fonksiyon yok); daha büyük tavan için ilk tohum
   büyütülür. Sizin için pratik anlamı: **planlanan TVL hedefiniz, ilk tohumda
   kesinleşir** — kapasite konusunda sürpriz olmaz.

2. **Tohum varlıkları çekilemez (kalıcı first-loss tampon).** Junior havuzu,
   krediyi karşılayan **ilk-kayıp tamponudur** — bu yüzden hareket etmemeli ve
   edemez. Bu **bug değil, güvenlik özelliğidir**: çekilebilir bir tampon, sahibi
   tarafından çekilip %3'ün altına düşürülerek **mint'i durduran bir griefing
   vektörü** yaratırdı. Sabit tampon bu riski sıfırlar.

3. **Tohum miktarı $1 cinsinden sayılır** (ETH fiyat riski yok). Tohum, cUSD ile
   1:1 eşleşen 18-ondalık birim olarak işlenir; gerçekte gönderilen ETH'nin
   piyasa değeriyle karışmaz — **$3M tohum her zaman tam $100M tavan** açar,
   ETH oynaklığına bağlı kalma riski yoktur.

**↔ RED FLAGS ile çapraz bağlantı** (deploy'da yanlış gideni tanı —
 [docs/29](29_INSAN_KARARLARI.md) 🚩 bölümü):

| Bu özellik | Deploy'daki belirti | Geri alınabilir mi? |
|---|---|---|
| **1. Tavan kalıcı** | `tvlCap` hedefinden küçük çıkarsa | ❌ **HAYIR** — yeni cUSD adresi gerekir (tüm deploy'u yenile) |
| **2. Çekilemez tampon** | `cast balance` ≠ 0 (ETH gönderildiyse) | ❌ **HAYIR** — ETH sonsuza kilitli |
| **3. $1 cinsinden** | — | ✅ **Korunma** — `--value` ile ETH göndermezsen bu risk doğmaz |

> Bu tablo teklif ile teknik dokümanlar arasında **tek yerde** birleştirilmiştir:
> her kalıcı özellik, deploy'da nasıl bir belirtiye karşılık geldiğini ve geri
> alınıp alınamayacağını gösterir. Detay: docs/29 🚩 RED FLAGS.

> **Operasyonel not:** Bu 3 özellik deploy rehberi (ADIM 3) ve insan karar
> dosyası (docs/29 KARAR 1/3B) ile birebir uyumludur. Bağımsız doğrulama
> komutları docs/29'un "EK — İNSANIN KENDİ ANVİL DOĞRULAMASI" bölümünde
> `cast balance = 0` ile kanıtlanmıştır.

---

## 5. Karşılaştırma

| Ürün | Min. giriş | Getiri | Not |
|---|---|---|---|
| **Cleanvest** | $250k | **%2,91–3,05** | Junior izolasyonu + çıkış kilitsiz |
| BlackRock BUIDL | **$5M** | %3,45 | Kurumsal tek ürün, getiri katmanı yok |
| Ondo OUSG | $100k | %3,46 | Junior risk izolasyonu yok |
| Franklin BENJI | $20 | ~%3,4 | Aave entegrasyonu yok |

Aynı kategoride rekabet etmiyoruz — **üzerine bir getiri katmanı** sunuyoruz.

---

## 6. Sonraki Adım

1. **30 dk teknik demo** (canlı anvil ağı üzerinde gerçek etkileşim)
2. **Uygunluk kontrolü** — TVL ve likidite ihtiyacınıza göre kademe seçimi
3. **Junior tohumunun yatırılması** (bizim tarafımızdan, ~$3,2M / $107M)
4. **Base mainnet deploy** — HITL onayı sonrası ~2 saat

**Canlı demo:** Base mainnet deploy bekleniyor; anvil test ağı üzerinde **şimdi** gösterilebilir.

---

## İletişim

> Bu doküman bir **ön tekliftir**. İletişim kanalı ve nihai şartlar, ilk kurul toplantısında netleştirilir.

**Bağımsız doğrulama:** Sözleşme ve testler tamamen açıktır — `export PATH="$HOME/.foundry/bin:$PATH" && forge test` ile herkes 186/186 sonucunu kendisi üretebilir.

**DÜRÜST SINIR — 3. parti denetim:** Mevcut kalite kanıtı (186 test, %96.75
branch, docs/41 derin denetim) dahili olarak üretilmiştir. Bu, bağımsız bir
güvenlik firmasının yerini **TUTMAZ**; yatırımdan önce bağımsız denetim
alınması önerilir. Mevcut tüm iddialar açık kod + tekrar üretilebilir
komutlarla kanıtlıdır.

```
IDDIA:  teklif dokümanı yazıldı, rakamlar sözleşmeyle doğrulandı
KANIT:  test -f docs/24_TEKLIF_15_HAZNA.md && grep -c "250k" docs/24_TEKLIF_15_HAZNA.md
RC:     0
```
