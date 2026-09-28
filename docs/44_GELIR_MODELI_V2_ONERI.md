# 44 — GELIR MODELI v2: Komisyon + Referans + CleanAudit
**Tarih:** 2026-09-26 · **Durum:** ONERI (kod YOK) · **Onay bekliyor**

---

## 1. Piyasa Arastirmasi (2026-09-26 taze)

### HyperLiquid (en populer perp DEX, referansimiz)

| Tier | Hacim | Taker | Maker |
|---|---|---|---|
| Wood (0) | $0 | **%0.045** | %0.015 |
| Bronze | >$5M | %0.040 | %0.012 |
| Silver | >$25M | %0.035 | %0.008 |
| Gold | >$100M | %0.030 | %0.004 |
| Platinum | >$500M | %0.028 | **%0.000** |

**Onemli:**
- **Referral odulleri: ilk $1M hacim** icin gecerli
- **Referral indirimleri: ilk $25M hacim** icin
- **Spot hacmi, tier'a 2x katki** yapar (spot'u tesvik eder!)

### Akademik (yeni, bu oturumda dogrulandi)

**arXiv:2609.11614 — "Deep Learning of Robust Market Making under Regime-Switching
Order Flow" (Moret & Lillo, 10 Eyl 2026)**
- Klasik piyasa yapici modelleri (Avellaneda-Stoikov, GLFT) **negatif PnL**
  veriyor gercek mikroyapida - cunku order flow **stationary degil**
- **Rejim degisimi** ana sorun; cozmek icin Deep RL + Bayesian change-point filter
- **Cleanvest'e etkisi:** Otonom piyasa yapici agent'i "basit" olamaz;
  rejim tespiti SART. Mevcut FBA (400ms batch) bundan **etkilenmez** cunku
  batch netting yapay zeka gerektirmez.

**arXiv:2609.13715 — "Event-Time Order-Flow Memory" (Angstmann & Gebbie, JSTAT)**
- Isaret (trade sign) **long-memory** ozelligi: event-time'da
- **Karekok etki kanunu**: operational-time'da
- **Cleanvest'e etkisi:** Batch netting bu iki etkiyi **natural olarak azaltir**
  (400ms icinde sinyaller birbirini iptal eder). Bu FBA'nin teorik avantaji.

---

## 2. ONERI: Uc Kademeli Komisyon Modeli

### Kademeler (HyperLiquid'e gore UST, kullaniciyi cekmek icin)

| Kademe | Taker | Maker | Sart | Amac |
|---|---|---|---|---|
| **0. Hosgeldin** | **%0** | **%0** | **ilk $10.000 islem** | Kullanici kazanma (sifir komisyon marketing) |
| **1. Standart** | **%0.035** | **%0.010** | $10K uzerinde | Ana gelir (HyperLiquid Wood'un altinda) |
| **2. Pro** | **%0.030** | **%0.005** | $1M+ hacim | Kurumsal cek |

### Neden bu oranlar?
- **Standart %0.035**: HyperLiquid Wood (%0.045) **ve** Bronze (%0.040) altinda
- **Maker %0.010**: Likidite saglayanlar odulendirilir (spot icin 2x katki)
- **0. Kademe %0**: "Sifir komisyon" pazarlamasi **gercek** olur (ilk $10K)

### Tahmini Gelir (orneklem)
- TVL $1M, gunluk devrim 20% = $200K gunluk hacim
- Ortalama %0.03 (0. kademe sonrasi) = **~$60/gun = ~$1.800/ay**
- TVL $10M durumunda: **~$600/gun = ~$18.000/ay**

> **DURUST SINIR:** Bu tahminler; gercek devrim hizi bilinmeden uretilmistir.
> Rakip bazli orneklem sadece bir referanstir, garanti DEGILDIR.

---

## 3. ONERI: Referans Sistemi (HyperLiquid modeli)

| Oge | Deger | Kaynak |
|---|---|---|
| **Referans odulu** | **%1.25** (bizde: sub-attempts) | HyperLiquid: ilk $1M icin |
| **Referans indirimi** | **%10 komisyon indirim** | HyperLiquid: ilk $25M icin |
| **Odul suresi** | **ilk $100K hacim** (kucuk basliyoruz) | Kendi secimimiz |

**Mantik:** Kullanici arkadasini cagirir -> arkadasinin **ilk $100K isleminden
%1.25 komisyon** referans sahibine gider. Arkadasi da **%10 komisyon indirimi**
kazanir. **Iki taraf da kazanir.**

---

## 4. CleanAudit Isim Degisimi (ONAYLANDI)

**AegisForge -> CleanAudit**

Kodda **27 dosyada** geciyor (contract'lar, test'ler, doc'lar, UI i18n).
Degisiklik plani:
1. `contracts/ListingGate.sol` L18 (modifier + event isimleri)
2. `contracts/interfaces/IListingGate.sol`
3. Test'ler ( ListingGate.t.sol vb.)
4. Doc'lar (27 dosya)
5. UI i18n + Test'ler

> **DURUST UYARI:** Isim degisikligi **100+ referans** gerektirir. Ayri bir
> commit olarak yapilmali; mevcut 187 test'in **tekrar gecmesi** sarttir.

---

## 5. Aşama 3: Tam Otonom Ajan Borsasi — Kapsam Analizi

**Soru:** "Tamamen otonom ajanlar tarafindan calisan bir borsa insa edemez miyiz?"

### Su an elimizde olan (FBA - otonom ZATEN)
- ✅ **Batch netting 400ms** — insan mudahalesi YOK
- ✅ **Uniform clearing price** — algoritmatik
- ✅ **Solver kaydi** — RFQ solver'lar otomatik
- ✅ **Anti-collusion** — koda gomulu
- ✅ **Cold-start cap** — otomatik acilis

### Olmasi gerekenler (ekstra 1-3 ay)

| Bilesen | Zorluk | Sure (tahmini) |
|---|---|---|
| **Otonom piyasa yapici agent** | YUKSEK (arXiv:2609.11614 rejim sorunu) | 4-6 hafta |
| **Rejim tespiti** (order flow) | YUKSEK | 3-4 hafta |
| **Katman-2 batch toplayici** | ORTA | 2-3 hafta |
| **Otomatik likidite rebalancing** | ORTA (ReserveManager var) | 1-2 hafta |
| **Monitoring/alerting agent** | DUSUK | 1 hafta |

### Buyuklukler (gercek disi DEGIL)
- **FBA settlement: TAMAMEN ONONOM ZATEN** (400ms batch + uniform price)
- **Getiri uretimi: TAMAMEN OTONOM** (ReserveManager SAFE mod)

> **SONUC:** Borsanin **%80'i halihazirda otonom**. Eksik olan sadece
> **piyasa yapici agent** (istege bagli - RFQ solver'lar su an dolduruyor).

### Sermaye Ihtiyaci (Aşama 3 icin)

| Bilesen | Maliyet |
|---|---|
| Junior seed (TVL $1M icin) | **$30.000** |
| Piyasa yapici likiditesi | $50-100K (opsiyonel) |
| Audit (CleanAudit Scan) | $199 |
| **Toplam minimum** | **~$30.200** |

> **DURUST:** $100K hedefiyle baslayabiliriz ama **$30K ile bile Aşama 1-2
> tamamlanir**. $2K ile **sadece test/demo seviyesinde** kaliriz.

---

## 6. Karar Beklenen Konular

1. **Komisyon oranlari** (yukaridaki tablo) onay?
2. **Referans odulu %1.25 + indirim %10** onay?
3. **CleanAudit** isim degisimi baslayalim mi?
4. **Komisyon kodu** eklensin mi? (CleanvestSettlement.sol degistirilecek -
   **yeni guvenlik test'leri SART**)

---

*Kaynaklar: HyperLiquid docs (fees, gitbook), arXiv:2609.11614,
arXiv:2609.13715, docs/40 (fiyatlandirma), kod analizi (2026-09-26).*
