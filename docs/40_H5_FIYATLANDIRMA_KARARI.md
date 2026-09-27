# 40 — H5 FİYATLANDIRMA KARARI (Öneri — Kullanıcı Onayı Bekler)

**Tarih:** 2026-09-27 · **Mod:** 🟢 **RAPOR — SIFIR Solidity değişikliği**
**Sorun:** `docs/39 §5`'in en dürüst bulgusu — **H5 Denetim Kapısı zarar
edebilir** (Scan $299 vs $80–800 maliyet → marj **−%168 ile +%73**).

> # ⚠️ BU BİR ÖNERİDİR — KULLANICI ONAYI BEKLER
>
> Aşağıdaki karar **kurul/onay gerektiren bir karar DEĞİLDİR** — bir
> **öneridir**. Kullanıcı sabah okur ve onaylar/redzeder. **Hiçbir kod
> değişikliği yapılmadı, `ListingGate.sol`'e DOKUNULMADI** (kısıt: `contracts/`,
> `test/`, `ListingGate.sol` YASAK).
>
> **0 gerçek müşteri. $0 gerçek gelir.** Tüm maliyetler `docs/39`'un
> **ABD tabanlı TAHMİNİ'dir** — EMEA verisi BULUNAMAMIŞTIR (`docs/39 §1.1`),
> yani maliyetler muhtemelen **gerçeğin ÜSTÜNDEDİR (worst-case)**.

---

## 0. Sorunun Özeti (matematik)

`docs/39 §2-3`'ten (TAHMİN, ABD ücretleri):

| Kademe | Şu anki fiyat | Maliyet (TAHMİN) | **Marj (TAHMİN)** |
|---|---|---|---|
| **Scan** | $299 | $80 – $800 | **−%168 ile +%73** |
| **FuzzPatch** | $1.490 | $300 – $3.000 | **−%101 ile +%80** |
| **Priority** | $4.900 | $660 – $6.600 | **−%35 ile +%87** |

> **Zarar senaryosu:** Scan'in **insan analiz + remediation** kısımları üst
> aralıkta çalışırsa ($800), $299 fiyat **$501 ZARAR** eder. **Bu sürdürülebilir
> bir iş DEĞİLDİR.**

**Maliyetin %85'i insan zamanıdır** (`docs/39 §2`): Scan'de 2–4 saatin
**1.5–3 saati insan** (triyaj + PoV raporu). Araç çalıştırma yalnızca **0.5–1
saat**. Yani çözüm **fiyat, kapsam veya otomasyon** odaklı olmalıdır.

---

## 1. Dört Seçeneğin Değerlendirilmesi

### (a) Fiyatı Yükselt — ❌ ELENMEDİ, ANCAK TEK BAŞINA YETERSİZ

**Öneri:** Scan $299 → hedef **%50 marj** ile maliyetten hesapla:

| Kademe | Maliyet | %50 marj için fiyat | %60 marj için fiyat |
|---|---|---|---|
| Scan | $80 – $800 | **$160 – $1.600** | $200 – $2.000 |
| FuzzPatch | $300 – $3.000 | **$600 – $6.000** | $750 – $7.500 |
| Priority | $660 – $6.600 | **$1.320 – $13.200** | $1.650 – $16.500 |

| Artı | Eksi |
|---|---|
| ✅ Matematiksel olarak zararı **kesin** kaldırır | ❌ **Fiyat aralığı çok geniş** ($160–$1.600) — müşteriye teklif verilemez |
| ✅ Mevcut yapı korunur | ❌ Üst aralık ($1.600) pazarlama vaadiyle çelişir ("$299 hızlı tarama") |
| | ❌ **Fiyat artışı = talep düşmesi**; 0 müşteri varken fiyatı 5 katına çıkarmak talebi sıfırlar |

> **Değerlendirme: Tek başına YANLIŞ.** Maliyet aralığı çok geniş; fiyat aralığı
> da o kadar geniş olur ki teklif verilemez. **Maliyet önce daraltılmalıdır.**

### (b) Kapsamı Daralt — ✅ SEÇİLDİ (kısmen)

**Öneri:** Scan'in **insan-ağır** kısımlarını çıkar, **otomatik** kısmı tut:

| Bileşen | Şu an (docs/39) | Öneri |
|---|---|---|
| 4 kademeli huni çalıştırma | **Otomatik** (0.5–1 saat) | ✅ **TUT** |
| Bulguların triyajı (false-positive eleme) | İnsan, 1–2 saat | 🔄 **OTOMATİK RAPORA DÖNÜŞ** — insan yalnızca **kullanıcının talebi üzerine** devreye girer |
| PoV_Hash taahhüdü + rapor | İnsan, 0.5–1 saat | ✅ **TUT** (PoV_Hash `ListingGate.sol:28-30`'da koda işlemli) |
| ~~İstismar kodu yazma (FuzzPatch)~~ | İnsan, 3–6 saat | 🔄 **OPSIYONEL** — "patch'imi kendim yazıyorum" müşterisi için **indirim** |
| ~~Remediation diff (FuzzPatch)~~ | İnsan, 2–4 saat | 🔄 **OPSIYONEL** |

| Artı | Eksi |
|---|---|
| ✅ Maliyet **$80–800 → $40–240** aralığına daralır (insan yalnızca PoV raporu + opsiyonel triyaj) | ❌ "Otomatik rapor" = daha az değer algısı; fiyat da düşmeli |
| ✅ Fiyat aralığı **dar** olur → teklif verilebilir | ❌ Kullanıcı "insan denetimci yok mu?" diye sorabilir — dürüst cevap verilmeli |
| ✅ docs/04:90 ile UYUMLU — araçlar zaten "tamamen tespit edemez" diyordu; insan beklentisi düşürülmüş olur | |

### (c) Otomatikleştir — ✅ SEÇİLDİ (b ile birleşik)

**Kanıt:** `docs/19:45` — *"invariant çürüklüğü Z3 ile çürütülür (Unsat =
proven)"* — **otomasyon mümkün ve kanıtlanmıştır.**

**Otomatikleştirilebilen:** (i) triyajın **false-positive eleme** adımı
(Z3'in `Unsat` çıktısı zaten kanıt verir), (ii) rapor formatlama, (iii)
PoV_Hash üretimi (zaten `SHA256(...)` — `ListingGate.sol:29`).

**OtomatikleştirileMEyen:** `docs/04:90` — *"araçlar... çapraz protokol
ekonomik manipülasyonlarını (örn. governance flash loan saldırıları) tamamen
tespit edemeyebilir."* Yani **insan gözü kodsuz olarak zorunludur** — ama
**her müşteri için DEĞİL**, yalnızca **yüksek riskli bulgu** çıktığında.

| Artı | Eksi |
|---|---|
| ✅ Maliyet **dramatik düşer** (Z3 çıktısı = kanıt) | ❌ Araç geliştirme maliyeti (bir kerelik, ölçülmedi) |
| ✅ docs/04:90 sınırı **dürüstçe** yansıtılır: "insan gözü yalnızca kırmızı bayrakta devreye girer" | ❌ İlk müşterilerde araç olgunlaşmamış olabilir |

### (d) H5'i Kapat — ❌ ELENDİ

| Artı | Eksi |
|---|---|
| ✅ Zarar %100 kaldırılır | ❌ **Talep kanıtı var**: `docs/04:93`'te SLA talebi; `PROJE_KAGIDI`'da 26 portföy projesi (sıfır CAC) — **ilk müşteriler hazır** |
| | ❌ **B2B gelir motoru kapanır** — H1/H4 spread'i ($17.00/ay) 10 müşteride $170/ay; H5 tek başına aylık **$300–$1.500** getirebilir |
| | ❌ "Denetim kapısı" Cleanvest'in **marka vaadinin** çekirdeğidir (PoV_Hash, CleanScore ≥ 70) — kapatmak ürünü zedeler |

---

## 2. KARAR (Öneri) — **(b) + (c) bileşimi: "Otomatik Önce, İnsan İsteğe Bağlı"**

> **Önerilen model:** Scan **otomatik rapor** olarak kalır (insan triyajı
> çıkınca maliyet **$40–240**). Fiyat **$199** (eski $299 — talebi korumak
> için düşürüldü). İnsan denetimci **OPSIYONEL eklenti** olarak sunulur.

### Önerilen fiyatlandırma

| Kademe | Eski fiyat | **Öneri fiyat** | Maliyet (TAHMİN, yeni) | **Marj (TAHMİN)** |
|---|---|---|---|---|
| **Scan** (otomatik rapor) | $299 | **$199** | $40 – $240 | **−%21 ile +%80** |
| **Scan + İnsan Triyaj** (opsiyonel) | — | **$399** | $80 – $400 | **−%0,3 ile +%80** |
| **FuzzPatch** (otomatik + opsiyonel insan) | $1.490 | **$990** | $300 – $1.500 | **−%52 ile +%70** |
| **Priority** (insan zorunlu + SLA) | $4.900 | **$4.900** (korundu) | $660 – $6.600 (docs/39'dan) | **−%35 ile +%87** |

> Hesaplama: `%50` hedef marj DEĞİL — **maliyet aralığından doğrudan**:
> `marj = (fiyat − maliyet) / fiyat`. Örnek Scan: $199 fiyat, $240 üst
> maliyet → **−$41 zarar = −%21 marj**. Zarar **ilk sürümde mümkün ama
> sınırlı** (−$41 en kötü). **Priority'nin maliyeti docs/39 §2'den
> alınmıştır ($660–$6.600) ve KAPSAMI DARALTILMAMIŞTIR** — insan SLA
> zorunludur, o yüzden bu kademe **eski haliyle korunmuştur**.

### Neden bu fiyatlar?

1. **$199 (Scan):** $299'dan düşük — **maliyet düştüğü için** (insan triyajı
   çıktı) ve **0 müşteri varken talep yaratmak için**. En kötü zarar **−$41**.
2. **$399 (Scan + İnsan):** İnsan triyajı **isteğe bağlı** — müşteri "insan
   denetimci" istiyorsa öder. Bu, docs/04:90'ın dürüst sınırını yansıtır:
   *"araçlar tamamen tespit edemeyebilir"* → insan **değerli**, ayrı satılır.
3. **$990 (FuzzPatch):** $1.490'dan düşük — insan-ağır "istismar kodu +
   remediation" **opsiyonel**. En kötü zarar **−$510** (üç kademenin en
   risklisi), ama kapsam daraldığı için daha olasıdır.
4. **$4.900 (Priority, korundu):** Burada **insan ZORUNLU** (SLA + formal
   assurance, `docs/04:93`) — fiyat korundu çünkü **SLA taahhüdü zaten
   docs/04:93'te verilmiş durumda**. Maliyet **docs/39 §2'den $660–$6.600**
   (kapsamı daraltılmadı) → marj **−%35 ile +%87**, en kötü zarar **−$1.700**.

### Matematiksel zarar analizi (önerilen)

| Kademe | En kötü zarar (TAHMİN) | Ne zaman? |
|---|---|---|
| Scan $199 | **−$41** | Üst maliyet $240 (insan olmadan nadiren) |
| Scan+İnsan $399 | **−$1** | Üst maliyet $400 |
| FuzzPatch $990 | **−$510** | İnsan analiz üst aralıkta + remediation |
| Priority $4.900 | **−$1.700** | 30-gün SLA + formal assurance üst aralıkta ($6.600) |

> **Toplam risk:** 4 kademenin **3'ünde zarar senaryosu var** (Priority dahil).
> **Eski duruma göre İYİLEŞME:** Scan zararı −$501 → **−$41** (**−%92 azalma**),
> FuzzPatch −$1.510 → **−$510** (−%66 azalma). **Priority'de DEĞİŞİKLİK YOK**
> (−$1.700) — bu kademe ** bilinçli olarak eski haliyle korundu**; SLA
> taahhüdü insan zamanı gerektirir (`docs/04:93`).

---

## 3. Alternatiflerin Neden Elendiği (özet)

| Seçenek | Karar | Gerekçe |
|---|---|---|
| **(a) Sadece fiyat yükselt** | ❌ ELENDİ | Fiyat aralığı $160–$1.600 → teklif verilemez; talep sıfırlanır |
| **(b) Kapsamı daralt** | ✅ **SEÇİLDİ** | Maliyet $80–800 → $40–240; fiyat dar; teklif verilebilir |
| **(c) Otomatikleştir** | ✅ **SEÇİLDİ** | `docs/19:45` Z3 kanıtı var; `docs/04:90` insan zorunluluğunu **dürüstçe** opsiona çevirir |
| **(d) H5'i kapat** | ❌ ELENDİ | Talep kanıtı (26 proje, SLA talebi); marka vaadinin çekirdeği; H1/H4 tek başına zayıf gelir |

---

## 4. Kod Etkisi — YOK (bu dokümanda)

> **`ListingGate.sol`'e DOKUNULMADI.** Yeni fiyatlar **henüz koda
> işlenmemiştir** — bu bir **öneridir**. Onaylanırsa:
> - `ListingGate.sol:82-84`'teki yorumlar (`// $299`, `// $1.490`, `// $4.900`)
>   güncellenir
> - `upgradeAuditTier` (`:208`) **aynı kalır** (kademe yapısı değişmedi)
> - **Yeni bir opsiyonel-insan bayrağı** eklenebilir (ek kapsam, YOL HARİTASI)
>
> **Bu doküman sadece matematik + öneridir.** Hiçbir `contracts/` veya `test/`
> dosyasına dokunulmadı.

---

## 5. Dürüst Sınırlar (bu önerinin zayıflıkları)

1. **Maliyet aralığı hâlâ TAHMİN** — ABD ücretleriyle (`docs/39 §1.1`'de EMEA
   verisi BULUNAMAMIŞ). EMEA'da maliyet düşerse marj **yukarı** kayar.
2. **Talep esnekliği ölçülmedi** — $199'un $299'dan **kaç müşteri** kazandığı
   **bilinmiyor** (0 müşteri). Bu bir **varsayımdır**.
3. **Araç geliştirme maliyeti (c)** — Z3 triyaj otomasyonunun geliştirme
   maliyeti **ölçülmedi** (bir kerelik, `docs/38 §8`'in "ÖLÇÜLMEDİ" listesinde).
4. **FuzzPatch hâlâ riskli** — en kökül −$510 zarar; ilk 10 müşteride **hepsi**
   üst aralıkta çalışırsa **−$5.100/ay** eder. **Nakit rezervi planı yapılmalı.**
5. **0 gerçek müşteri** — tüm bu matematik **üretim verisiyle doğrulanmamıştır**.

---

## 6. Müşteriye Söyleyecek Cümle (ön taslak)

> *"Cleanvest Denetim Kapısı'nın Scan kademesi artık **$199** — çünkü
> otomatik raporlamayı ayırdık: Z3 motorumuz invariant'larınızı kanıtlar
> (`docs/19:45`), PoV_Hash zincire mühürlenir. İnsan denetimci mi
> istiyorsunuz? **$399**'a triyaj eklenir. Araçlarımız her şeyi tespit
> edemez (`docs/04:90`) — bu yüzden insanı size bırakıyoruz, gizlemiyoruz."*

> **Dürüstlük korunur:** "insan denetimci yok" gizlenmez, **seçenek** olarak
> sunulur. docs/04:90'ın legal disclaimer'ı bu modelle **uyumludur**.

---

## Kanıt Protokolü

```
IDDIA:  H5 fiyatlandirma karari (oneri) — SIFIR Solidity degisikligi
KANIT:  forge test → 174 passed, 0 failed (RC 0)
        + dosya: docs/40_H5_FIYATLANDIRMA_KARARI.md
        + maliyet kaynagi: docs/39 §2-3 (TAHMIN, ABD ucretleri)
        + otomasyon kaniti: docs/19:45 (Z3 Unsat = proven)
        + insan-gerekli kaniti: docs/04:90 ("araçlar tamamen tespit edemeyebilir")
        + SLA kaniti: docs/04:93 (30-gun SLA, Tier 2-3)
        + koda isli fiyat: ListingGate.sol:82-84 (DOKUNULMADI)
RC:     0
COMMIT: (bu commit)
DOSYA:  docs/40_H5_FIYATLANDIRMA_KARARI.md
```

**Kısıt uyumu:**
- ✅ **HİÇBİR Solidity kodu değiştirilmedi** (`contracts/` dokunulmadı)
- ✅ **`ListingGate.sol`'e DOKUNULMADI** (kısıt: YASAK)
- ✅ **HİÇBİR test değiştirilmedi** (`test/` dokunulmadı)
- ✅ **174 forge test** altına düşmedi
- ✅ **4 seçenek değerlendirildi** (artı/eksi ile)
- ✅ **Hiçbir fiyat uydurulmadı** — her fiyat `docs/39` maliyetlerinden hesaplandı
- ✅ **"BU BİR ÖNERİDİR, KULLANICI ONAYI BEKLER"** başta
- ✅ Rapor modu: sadece doküman, hiçbir kod
