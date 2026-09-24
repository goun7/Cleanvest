# CLEANVEST: CLEANFX VE $cUSD REZERV RİSK İZOLASYONU (v1.0)

> **Kapsam:** Getirili Stablecoin Mimarisi, Senior/Junior Tranche Şelalesi, Hafta Sonu Likidite Tamponu ve İflas Yalıtımı (Bankruptcy-Remote)

---

## 1. CleanFX: Küresel Banka Makası Kırıcı Mekanizma

Geleneksel bankacılık ve sokak döviz büroları, bireysel müşterilerin döviz işlemlerinden **%1.5 – %3.5 oranında kur makası (spread)** keser. 
CleanFX, kriptografik toptan likidite raylarını kullanarak bu makası **%0.10'un altına** indirir:

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                             CLEANFX KÜRESEL DÖVİZ ENTEGRASYONU                              │
│                                                                                             │
│  [Kullanıcı: 100.000 TL Yatırır] ──► [CleanFX Toptan İnterbank Havuzu]                      │
│                                                   │                                         │
│                                                   ▼ (Kur: 34.02 TL / Piyasa Kuru)          │
│  ┌───────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 1. ANLIK VE SIFIR SÜRTÜNMELİ TAKAS                                                    │  │
│  │ - Banka kuru: 35.10 TL (Kullanıcı 2.849 USD alırdı - $151 Kayıp!)                    │  │
│  │ - CleanFX kuru: 34.05 TL (Kullanıcı 2.936 USD karşılığı $cUSD alır).                 │  │
│  │ - Kullanıcı kapıdan girerken $87 kâr eder!                                           │  │
│  └───────────────────────────────────┬───────────────────────────────────────────────────┘  │
│                                      │                                                      │
│                                      ▼                                                      │
│  ┌───────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 2. VADESİZ HESAPTA FAİZ ÇARKI (THE IDLE YIELD FLYWHEEL)                               │  │
│  │ - Kullanıcı işlem yapmadığı sürece bu 2.936 $cUSD, cüzdanında saniyelik rebase ile    │  │
│  │   yıllık %4.80 ABD Hazine Bonosu faizi üretir.                                        │  │
│  └───────────────────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Senior / Junior Dilim Şelalesi (First-Loss Capital)

Terra/Luna, Celsius veya SVB krizlerinde görüldüğü üzere; getiri üreten tek bir bileşen çöktüğünde tüm sistem domino taşı gibi yıkılmaktadır.
$cUSD, kurumsal yapılandırılmış finansın (Structured Finance) en gelişmiş kalkanını kullanır:

### 2.1. Sermaye Hiyerarşisi
1. **Senior Tranche (%100 Kullanıcı $cUSD Bakiyeleri):**
   * Öncelik Sırası: **1. Derece Öncelikli (En Üst Sırada).**
   * Nominal Değer: Daima $1.00 USD sabit.
   * Risk Maruziyeti: **%0**.
2. **Junior Tranche (First-Loss Reserve / İlk Zarar Fonu):**
   * Öncelik Sırası: **2. Derece (Kayıp Emici).**
   * Fon Kaynağı: Cleanvest borsa komisyonlarından biriken hazine rezervi + yüksek getiri (%8-%12) talep eden profesyonel risk sermayesi.

### 2.2. Zarar Emme Formülü
Rezerv portföyünde beklenmedik bir temerrüt veya gecikme ($\text{Loss}$) oluşursa:
$$\text{Eğer } \text{Loss} \le \text{JuniorReserve} \implies \Delta P_{\text{Senior}} = 0$$
Tüm kayıp Junior havuzundan düşülür. Normal kullanıcının 1 $cUSD'sine tek bir sent bile yansımaz.

---

## 3. Rezerv Kompozisyonu ve Hafta Sonu Likidite Tamponu

TradFi piyasaları cuma akşamı kapanıp pazartesi sabahı açılırken kripto 7/24 çalışır. Hafta sonu büyük çekim taleplerini karşılamak için dinamik sepet uygulanır:

| Varlık Sınıfı | Payı | Sağlayıcı / Saklama | Likidite & Risk Profili |
|---|---|---|---|
| **Kısa Vadeli ABD Hazine Bonosu** | **%75** | BlackRock BUIDL & Ondo USDY (BNY Mellon Saklamalı) | Sıfır kredi riski, yıllık %5.10 getiri. 24/7 on-chain transfer edilebilir. |
| **Delta-Neutral Basis Arbitrajı** | **%15** | Ethena benzeri merkeziyetsiz türev fonlama marjini | Piyasa yönünden bağımsız pozitif fonlama faizi (%8-%15 APY). |
| **Anlık Nakit Tamponu** | **%10** | Aave / Compound Spot USDC | **Hafta sonu ve tatil günleri anlık itfa (instant redemption) garantisi.** |

* **Hafta Sonu Dinamiği:** Pazar gecesi $5M çekim gelse bile ilk %10'luk anlık nakit tamponu talebi anında karşılar. Pazartesi sabahı geleneksel bankacılık açıldığında rezervler otomatik dengelenir (Auto-Rebalancing).
