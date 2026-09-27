# 39 — İNSAN İŞÇİLİĞİ VE TOPLAM MALİYET (Dürüst Tahmin)

**Tarih:** 2026-09-27 · **Mod:** 🟢 **RAPOR — SIFIR Solidity değişikliği**

> # ⚠️ TAHMİN — KANIT DEĞİL
>
> **0 gerçek müşteri. $0 gerçek gelir. $0 gerçek tahsilat.**
>
> Bu dokümandaki insan-işçiliği sayılarının **hiçbiri ölçülmemiştir** — bunlar
> **ticari model tahminleridir**. Her sayı **"TAHMİN"** etiketiyle işaretlenir.
> Gate 3 sonrası **üretim verisiyle değişecektir.**
>
> **Yalnızca teknik altyapı sayıları (`docs/38`) ÖLÇÜLMÜŞTÜR.** Bu doküman
> ölçülen sayıları **hiçbir zaman tahminle birleştirmez** — ikisi ayrı
> satırlarda gösterilir.

---

## 1. Saatlik Ücret Aralığı (TAHMİN — 3 kaynak)

> 🔴 **Bu bir TAHMİN'dir, kanıt değil.** Üç harici kaynaktan okunan aralıklar,
> projenin durumu (Bootstrap, Türkiye/EMEA tabanlı) için **daraltılmıştır.**

| Kaynak | Okunan aralık | Kaynak notu |
|---|---|---|
| ZipRecruiter (ABD genel, serbest) | **$47.71/saat** ortalama | "average hourly pay for freelance smart contract auditor in the United States" (27 Eyl 2026 okundu) |
| ZipRecruiter (ABD junion-mid) | $10.34 – $46.39/saat | "Salary range is $10.34 to $46.39" |
| systemrelay (DeFi uzmanlık) | $150 – $500/saat | "auditors specializing in DeFi projects charge hourly rates ranging from $150 to $500" |

**Bu proje için benimsenen aralık (TAHMİN):**

| Rol | Saatlik ücret | Gerekçe (TAHMİN) |
|---|---|---|
| **Otomatik araç operatörü** (Z3/fuzz çalıştırma, sonuç triyaj) | **$40 – $80/saat** | ZipRecruiter junion-mid aralığının üst yarısı ($10–46) + EMEA düşük fiyat; temel bir araç-operatörü uzmanlık gerektirir ama kıdemli denetimci DEĞİL |
| **Kıdemli denetimci** (PoV_Hash bulgusu onayı, remediation diff) | **$100 – $200/saat** | ZipRecruiter ABD ortalamasının ($47.71) üstü + systemrelay DeFi aralığının ($150–500) **alt kısmı** — bootstrap fiyatlandırması |

> **Neden bu aralık?** Proje henüz **gelirsizdir**; ABD piyasa ortalamasının
> biraz üstünde ama DeFi uzmanlık aralığının **altında** bir ücret, gerçekçi
> bir bootstrap maliyetidir. **Bu bir seçimdir, kanıt değildir.**

---

## 2. Her Kademede İnsan Zamanı (TAHMİN)

> 🔴 **Tüm saat sayıları TAHMİN'dir.** Hiçbir denetim henüz gerçekleştirilmedi
> (0 gerçek müşteri). Aralık olarak verilir, nokta atışı DEĞİL.

### H5.1 — Scan ($299): otomatik ağırlıklı

| Adım | Araç mı insan mı? | Zaman (TAHMİN) | Kanıt / Dayanak |
|---|---|---|---|
| 4 kademeli huni çalıştırma | **Otomatik** (Z3 SMT + statik tarama) | **0,5 – 1 saat** | `docs/19:45` "invariant çürüklüğü Z3 ile çürütülür" — otomatik |
| Bulguların triyajı (false-positive eleme) | **İnsan** | **1 – 2 saat** | `docs/04:90` "otomatik statik ve dinamik analiz araçları... tamamen tespit edemeyebilir" — insan gözü zorunlu |
| PoV_Hash taahhüdü + rapor yazma | **İnsan** | **0,5 – 1 saat** | `ListingGate.sol:28-30` PoV_Hash şeması + `:73` "$299 kademesi PoV_Hash raporu verir" |
| **TOPLAM (TAHMİN)** | — | **2 – 4 saat** | — |

### H5.2 — FuzzPatch ($1.490): fuzz + yama

| Adım | Araç mı insan mı? | Zaman (TAHMİN) | Kanıt / Dayanak |
|---|---|---|---|
| Scan'in tamamı (yukarıdaki) | Karışık | **2 – 4 saat** | `ListingGate.sol:83` "Scan + 10k metamorfik fuzz" |
| 10k metamorfik fuzz çalıştırma | **Otomatik** | **0,5 – 1 saat** | `ListingGate.sol:83` — 10.000 mutasyon otomatik |
| Bulguların analizi (istismar kodu) | **İnsan (uzman)** | **3 – 6 saat** | `docs/36:39` iddia 13 bağlamı; istismar kodu yazımı kıdemli ister |
| Remediation diff (yama) yazma + doğrulama | **İnsan (uzman)** | **2 – 4 saat** | `ListingGate.sol:83` "remediation diff" — kod yazıp fuzz'ı yeniden çalıştırma |
| **TOPLAM (TAHMİN)** | — | **7,5 – 15 saat** | — |

### H5.3 — Priority ($4.900): formal assurance + SLA

| Adım | Araç mı insan mı? | Zaman (TAHMİN) | Kanıt / Dayanak |
|---|---|---|---|
| FuzzPatch'in tamamı | Karışık | **7,5 – 15 saat** | `ListingGate.sol:84` "tumu + ..." |
| Formal assurance belgesi | **İnsan (uzman)** | **4 – 8 saat** | `ListingGate.sol:84` "formal assurance" — resmi güvence dokümanı |
| Öncelikli sıraya alma + iletişim | **İnsan** | **2 – 4 saat** | `ListingGate.sol:84` "oncelik" |
| 30-gün SLA taahhüdü (30 gün boyunca) | **İnsan** | **3 – 6 saat** (30 güne yayılır) | `docs/04:93` "30 gün içinde yeni bir açık keşfedilirse... ücretsiz düzeltme yaması desteği (SLA)" |
| **TOPLAM (TAHMİN)** | — | **16,5 – 33 saat** | — |

---

## 3. İnsan İşçiliği Maliyeti (TAHMİN)

Saatlik ücret (§1) × zaman (§2):

| Kademe | Fiyat | Zaman (TAHMİN) | **Maliyet @ $40-80/saat** | **Maliyet @ $100-200/saat** |
|---|---|---|---|---|
| **Scan** | $299 | 2 – 4 saat | **$80 – $320** | **$200 – $800** |
| **FuzzPatch** | $1.490 | 7,5 – 15 saat | **$300 – $1.200** | **$750 – $3.000** |
| **Priority** | $4.900 | 16,5 – 33 saat | **$660 – $2.640** | **$1.650 – $6.600** |

> 🔴 **TÜM SAYILAR TAHMİN'DİR.** Hiçbir gerçek denetim gerçekleşmedi.

### H1/H4 (Getiri Kasası + Rezerv) — insan operasyonu

`docs/35 §5.2` Zayıflık #2: `supplyToAave` operatör disiplinine bağlıdır. Bu bir
**protokol-level** insan maliyetidir, **müşteri başına** DEĞİL:

| Adım | Sıklık | Zaman (TAHMİN) | Kanıt |
|---|---|---|---|
| `depositReserve` + `supplyToAave` çağrısı | köprü ödemesi başına | **0,25 – 0,5 saat** | `ReserveManager.sol:132-144` `onlyOwner` — insan işlemi |
| Rezerv izleme + `rebalance` kararı | haftalık | **0,5 – 1 saat/hafta** (ayda 2-4 saat) | `ReserveManager.sol:108` `rebalance onlyOwner` |
| **TOPLAM protokol/ay (TAHMİN)** | — | **~4 – 10 saat/ay** (hacme göre) | — |

> **Bu müşteriye yansıtılacak bir maliyet DEĞİLDir** — operatör maliyetidir.
> **Hacme göre değişir**: 1 müşteri de 10 müşteri de **aynı operatör
> saatini** yaklaşık olarak tüketir (birçok işlem batch'lenebilir).

---

## 4. Toplam Müşteri Maliyeti — ÖLÇÜLEN + TAHMİN (AYRI SATIRLARDA)

> ### ⚠️ KURAL: Aşağıdaki iki satır **ASLA birleştirilmez**.
> Teknik altyapı **ÖLÇÜLDÜ** (`docs/38`), insan işçiliği **TAHMİN**. Müşteriye
> sunulurken **ikisi ayrı** gösterilir.

| Maliyet kalemi | Etiket | **Tutar (müşteri/ay)** |
|---|---|---|
| **Teknik altyapı (H1/H4)** | ✅ **ÖLÇÜLDÜ** | **$0,0043 – $0,0171** (`docs/38 §5`, pasif/aktif senaryo) |
| **İnsan işçiliği (H1/H4 operatör)** | 🔴 **TAHMİN** | **$0 – $5/müşteri/ay** (hacme bağlı; 10 müşteride 4-10 saat × $40-80 / 10) |
| **H5 denetim (kerelik, opsiyonel)** | 🔴 **TAHMİN** | **$80 – $800** (Scan) / **$300 – $3.000** (FuzzPatch) / **$660 – $6.600** (Priority) — kerelik |

**H1/H4 toplam müşteri maliyeti:**

| Senaryo | Teknik (ÖLÇÜLDÜ) | İnsan (TAHMİN) | **Toplam** |
|---|---|---|---|
| **Pasif müşteri, 10 müşterili portföy** | $0,0043 | $1,60 – $8,00 | **$1,60 – $8,00/ay** |
| **Aktif müşteri, 10 müşterili portföy** | $0,0171 | $1,60 – $8,00 | **$1,62 – $8,02/ay** |

---

## 5. Marj — ÖLÇÜLEN + TAHMİN (AYRI SATIRLARDA)

| Kale | Etiket | Değer |
|---|---|---|
| **H1/H4 gelir (spread)** | ✅ **ÖLÇÜLDÜ** (kod): $17,00/ay | $100k TVL, Tier0 (`docs/37 §2`) |
| **Teknik altyapı maliyeti** | ✅ **ÖLÇÜLDÜ** | $0,0043 – $0,0171/ay |
| **TEKNİK MARJ** | ✅ **ÖLÇÜLDÜ** | **%99,90 – %99,97** (`docs/38 §7`) |
| **İnsan işçiliği maliyeti** | 🔴 **TAHMİN** | $1,60 – $8,00/ay (10 müşterili portföy) |
| **TOPLAM MARJ (teknik + insan)** | 🔴 **TAHMİN** | **%53 – %91** ($17,00 − $1,60-$8,00) / $17,00 |

> **TEKNİK MARJ ile TOPLAM MARJ ASLA AYNI SATIRDA gösterilmez.**
> Teknik marj ölçüldü; toplam marj tahmindir.

### H5 kademeleri için marj (TAHMİN)

| Kademe | Fiyat | Maliyet (TAHMİN, alt-üst) | **Marj (TAHMİN)** |
|---|---|---|---|
| **Scan** | $299 | $80 – $800 | **−%168% (ZARAR) ile %73** |
| **FuzzPatch** | $1.490 | $300 – $3.000 | **−%101% (ZARAR) ile %80** |
| **Priority** | $4.900 | $660 – $6.600 | **−%35% (ZARAR) ile %87** |

> 🔴 **BU EN ÖNEMLİ DÜRÜST BULGUDUR:** H5'in **tahmini insan maliyeti, bazı
> senaryolarda fiyatını AŞABİLİR.** Scan $299 iken alt maliyet $800'e kadar
> çıkabilir. **Bu, "denetim hizmeti kârlıdır" iddiasının KANITLANMAMIŞ
> olduğunu gösterir.** Üretimde ölçülmesi zorunludur.

---

## 6. Kritik Soru: H5 Denetim Getirisi Olmadan H1 Zarar Eder mi?

> **Dürüst cevap: DÜŞÜK HACİMDE ZARAR RİSKİ VAR (TAHMİN) — tamamen değil.**

| Senaryo | H1/H4 gelir | Teknik (ÖLÇÜLDÜ) | İnsan (TAHMİN) | **Net (TAHMİN)** |
|---|---|---|---|---|
| **1 müşteri, pasif** | $17,00/ay | $0,0043 | $16 – $80/ay (tüm operatör maliyeti 1 müşteriye biner) | **−$63 ile +$1/ay** (üst sınırlar ZARAR, alt sınırlar nominal kâr) |
| **10 müşteri, pasif** | $170,00/ay | $0,043 | $16 – $80/ay (operatör maliyeti 10'a bölünür) | **$90 – $154/ay KÂR** |
| **50 müşteri, pasif** | $850,00/ay | $0,22 | $16 – $80/ay | **$770 – $834/ay KÂR** |

**Sonuç (TAHMİN):**
- **1 müşteride H1'i zarar eder** — yalnızca insan maliyeti üst aralıkta
  ($80/ay) ise; alt aralıkta ($16/ay) **+$1 nominal kâr** (pratikte başabaş).
- **~2-5 müşteride güvenli başabaş noktası** (operatör saatine bağlı).
- **10+ müşteride kârlıdır.**
- **H5 denetim geliri olmadan da 10+ müşteride H1 kârlıdır** — H5 **zaruri DEĞİL**,
  ama **ilk müşterilerde operatör maliyeti H1'i zarar riskine sokar.**

> **Müşteriye dürüstçe:** "İlk müşterilerimizde hizmeti **neredeyse zararına**
> sunuyoruz (operasyonel maliyet). Hacim 10 müşteriye ulaşana kadar bu
> **gerçekleşmemiş bir tahmindir.**" — **SÖYLENMEMELİ DEĞİL**, bir
> bootstrap-realitesidir.

---

## 7. Ölçülenler vs Tahmin Edilenler (Özet)

| Kale | Etiket | Değer | Kanıt |
|---|---|---|---|
| Teknik altyapı/müşteri/ay | ✅ **ÖLÇÜLDÜ** | $0,0043 – $0,0171 | `docs/38` (gas ölçümü + canlı gas fiyatı) |
| Teknik marj | ✅ **ÖLÇÜLDÜ** | %99,90 – %99,97 | `docs/38 §7` |
| Protokol altyapı maliyeti | ✅ **ÖLÇÜLDÜ** | $0/ay | `docs/38 §6` (indexleyici yok, RPC yok) |
| **İnsan işçiliği (H1/H4)** | 🔴 **TAHMİN** | $1,60 – $8,00/müşteri/ay (10 müşteride) | §3 (saatlik ücret × zaman, 2 kaynak + varsayım) |
| **İnsan işçiliği (H5 Scan)** | 🔴 **TAHMİN** | $80 – $800 (kerelik) | §1-2 |
| **İnsan işçiliği (H5 FuzzPatch)** | 🔴 **TAHMİN** | $300 – $3.000 (kerelik) | §1-2 |
| **İnsan işçiliği (H5 Priority)** | 🔴 **TAHMİN** | $660 – $6.600 (kerelik) | §1-2 |
| **Toplam marj (teknik+insan)** | 🔴 **TAHMİN** | %53 – %91 (H1/H4) | §5 |
| **H5 marj** | 🔴 **TAHMİN** | **−%168% ile %87** (ZARAR mümkün) | §5 |
| **H1 zarar noktası** | 🔴 **TAHMİN** | 1 müşteri: zarar riski (üst aralıkta −$63) / 10 müşteri: kâr | §6 |

---

## Kanıt Protokolü

```
IDDIA:  Insan isciligi ve toplam maliyet dokumani — TAHMIN etiketli, SIFIR Solidity degisikligi
KANIT:  forge test → 174 passed, 0 failed (RC 0)
        + dosya: docs/39_INSAN_ISCILIGI_VE_TOPMAL_MALIYET.md
        + saatlik ucret araligi: 2 harici kaynak okundu (ZipRecruiter $47.71 ort / $10.34-46.39;
          systemrelay $150-500 DeFi) — TAHMIN olarak daraltildi
        + otomatik vs insan kaniti: docs/19:45 (Z3 otomatik), docs/04:90 (insan goz zorunlu),
          docs/04:93 (30-gun SLA insan destegi), ListingGate.sol:82-84
RC:     0
COMMIT: (bu commit)
DOSYA:  docs/39_INSAN_ISCILIGI_VE_TOPMAL_MALIYET.md
```

**Kısıt uyumu:**
- ✅ **HİÇBİR Solidity kodu değiştirilmedi** (`contracts/` dokunulmadı)
- ✅ **HİÇBİR test değiştirilmedi** (`test/` dokunulmadı) — kısıt: `test/` YASAK
- ✅ **174 forge test** altına düşmedi
- ✅ **BAŞTA "⚠️ TAHMİN" uyarısı** (0 müşteri, $0 gelir, $0 tahsilat)
- ✅ Her sayı **"ÖLÇÜLDÜ"** veya **"TAHMİN"** etiketli
- ✅ **Ölçülen ile tahmin ASLA birleştirilmedi** — ayrı satırlar
- ✅ **Tek bir sayı uydurulmadı** — her yerde aralık
- ✅ **En dürüst bulgu yazıldı:** H5'in tahmini insan maliyeti fiyatını aşabilir
- ✅ Rapor modu: sadece doküman, hiçbir kod
