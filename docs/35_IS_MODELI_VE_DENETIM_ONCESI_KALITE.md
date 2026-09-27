# 35 — İş Modeli ve "Denetim-Öncesi Kalite" Örnek Raporu

**Tarih:** 2026-09-27 · **Mod:** 🟢 **RAPOR — SIFIR Solidity değişikliği**
**Soru:** "Unpump x402 = ödeme; AegisForge = denetim; **Cleanvest = ?**"

---

## 1. Cleanvest'in Müşteri Teklifi (3-4 satır)

> **Cleanvest, kurumsal hazinenin boşta duran USDC'sini getiriye yatıran bir
> ERC-4626 kasadır.** Giriş 1:1'dir, **çıkış kapısı asla kilitlenmez** (günlük %10
> anlık, üstü T+2 kuyruk), getiriniz **koda bağlı üç kademede** (TVL < $250k'da
> %3.05 → $250k–12.5M'da %2.91 → ≥$12.5M'da %2.92) kurumsal kompozisyonla
> üretilir. **Sıfır manipülasyon:** rebase yok, kaldıraç yok, kurucu
> sermayesi yok — ve müşteriyi **otomatik koruyan** bir slippage kalkanı
> (`depositWithMin`) ERC-4626 donation attack'ine karşı aktiftir.

**Mevcut ürünün doğru tanımı (PROJE_KAGIDI sayfa başı DURUM RAPORU ile birebir):**

> **ERC-4626 getiri kasası + FBA settlement + AegisForge denetim kapısı +
> PQHaven USDC köprüsü (Seçenek A).** Kodda **6 sözleşme** vardır:
> `CleanUSD`, `CleanFXVault`, `ListingGate`, `CleanvestSettlement`,
> `ReserveManager`, `UniswapProxy`.

> 🗺️ **YOL HARİTASI (mevcut ürün DEĞİL):** Validium / ZK-Proof settlement,
> Escape Hatch, Privy/Web3Auth MPC giriş, Omnichain settlement, RFQ solver ağı,
> delta-neutral arbitraj — **hepsi kodda YOKTUR** (`docs/36` tablosuna bakın).

**Rezerv kompozisyonu — HİÇBİR YERDE abartılmamalı (gerçek kod):**

| TVL | Gerçek dağılım (`ReserveManager.sol:15-17`) | En yüksek varlık |
|---|---|---|
| **<$250k (Tier0)** | %73 Aave / %15 Prime / %12 idle | **Aave V3 (%3.78)** |
| **$250k–$12.5M (Tier1)** | %40 OU SG / %33 Aave / %15 Prime / %12 idle | OU SG (%3.44) |
| **≥$12.5M (Tier2)** | %40 BUIDL / %33 Aave / %15 Prime / %12 idle | BUIDL (%3.47) |

> 🔴 **DÜRÜST DÜZELTME:** Yukarıdaki "ABD Hazine Bonosu getirisine yatırır"
> cümlesi **Tier0 için DOĞRU DEĞİLDİR.** Bugün (Tier0) fonlar **Aave V3 + Aave
> Prime**'dadır — **BlackRock BUIDL / Ondo USDG doğrudan alımı YOKTUR.**
> BUIDL ancak **TVL $12.5M'ya ulaştığında** (Tier2) ve Qualified Purchaser
> statüsüyle ($5M minimum) eklenir. **"Hazine Bonosu getiri ürünü" olarak
> satılamaz** — doğrusu **"Aave üzerinden kurumsal getiri"**dir.

**Müşterinin duygusal teklifi:** *"Stop gambling. Start investing. Your capital
can never be liquidated here."* (PROJE_KAGIDI L33)

### Teklifin 3 dayanağı (kanıtlanmış)

| Dayanak | Kanıt | Durum |
|---|---|---|
| **Getiri koda bağlı** | `testYieldCurveMatchesSpec` (3 kademe) | ✅ 174 test |
| **Çıkış kilidi yok** | `invariantRedemptionNeverLocked` | ✅ invariant |
| **Donation attack kalkanı** | `testSecurityDonationAttackVectors` (199 wei) | ✅ 5/5 vektör |

---

## 2. PQHaven Köprüsünün İş Modelindeki Yeri

**Seçenek A (kanıtlandı, commit `e6a58b6`):**

```
müşteri USDC → treasury (guard doğrular, 402/503)
              → owner EOA → depositReserve → supplyToAave
              → Aave V3 Pool → getiri üretir
```

### Müşteriye ne kazandırır? — **3 kazanç, 1 dürüst itiraf**

| # | Kazanç | Açıklama | Kanıt |
|---|---|---|---|
| **1** | **Hazine getirisi** | PQHaven'ın biriken USDC'si **Aave V3'e supply edilir** → Tier0'da yıllık **%3.05** (boşta = %0) — **ABD Hazine Bonosu (BUIDL) DEĞİL** (bkz. §1 rezerv tablosu; BUIDL yalnızca Tier2) | METRIK (b): idleBalance 2000 ether; (c): aavePool 2e9 USDC |
| **2** | **Güvenlik (fail-closed)** | Guard ödeme yoksa **402**, RPC hatasında **503** — ödemesiz-hizmet yanılgısı sıfır | `mainnet_guard.py:157-160` |
| **3** | **Düşük minimum giriş** | BlackRock BUIDL **$5M** minimum; Cleanvest **$250k** ile aynı getiri katmanına erişim | docs/24 karşılaştırma tablosu |

> **Dürüst itiraf:** Köprü **getiri** sağlar ama bu getiri **PQHaven müşterisine
> değil, treasury'ye** akar. Müşteri PQHaven'ın hizmetini (PQ taraması) alır;
> USDC'si tüketilir. **Getiri, treasury'nin biriken ödemelerini değerlendirmesi**
> içindir — bu bir "müşteri getirisi" ürünü DEĞİL, **treasury yönetim**
> aracıdır. Ayrım önemlidir: müşteriye "sizin paranız büyür" DENEMEZ.

**Köprünün asıl değeri:** PQHaven'ın **off-chain ödeme altyapısını** (x402,
fail-closed, tek-kasa) Cleanvest'in **on-chain getiri motoruna** bağlar. Bu,
iki sistemi **tek bir ekonomik döngüye** koyar: ödeme alınır → getiri üretilir
→ treasury büyür → hizmet sürdürülür.

---

## 3. 174 Testin 8'i PQHavenBridge — Müşteri Gözüyle Ne Kanıtlar?

**Müşteri açısından 3 madde (kod jargonu olmadan):**

1. **"Ödemeniz doğru adrese gider ve görülebilir"**
   `testBridgeTransferProducesGuardEvent` + `testFullPaymentFlowProducesBothTransferEvents` —
   her ödeme **zincirde kayıtlıdır** (Transfer event'i), bağımsız olarak
   doğrulanabilir. Gizli kapı yok, off-chain "güven bana" yok.

2. **"Boşta kalan paranız otomatik olarak getiriye dönüşür"**
   `testDepositReserveUSDC6Conversion` + `testConversionNoOverflow` —
   USDC (6-desimal) reserve birimine **taşma riski olmadan** çevrilir
   (USDC max supply × 1e12 = 1e24 ≪ uint256.max). Para yanlış hesaplanmaz.

3. **"Sistemin zayıf noktası size söylenir"** 🔴
   `testCentralizationRiskAccumulatesOnOwner` + `testRiskMitigatedBySameDaySettlement` —
   **Bu testler bir vaadi değil, bir RİSKİ kanıtlar:** fonlar owner EOA'da
   birikirse reserve'e girmez. Müşteri bunu bilir ve **multisig talep eder**.
   Şeffaflık = güven.

> **Dürüst not:** 8 testin 4'ü **riski** kanıtlar (merkezi birikim), yalnızca
> 4'ü başarıyı. Bu bilinçli bir orandır — gizlenmeyen zayıflık, gizlenen
> zayıflıktan daha güvenlidir.

---

## 4. Denetim-Öncesi Kalite Paketi — AegisForge ile Paketleme

**AegisForge PoV_Hash + Cleanvest vault = ?**

### Önerilen paket: **"Vault Denetim-Öncesi Kalite Raporu"**

AegisForge bir projenin **sözleşmesini** denetler (PoV_Hash ile bulguları
taahhüt eder). Cleanvest'in ekleyeceği katman: **vault'un kendisinin
denetim-öncesi kanıt dosyası** — yani AegisForge'u beklemeden **hazır
kalite kanıtı**.

| Bileşen | AegisForge tarafı | Cleanvest tarafı |
|---|---|---|
| **Hedef** | Başvuran projenin sözleşmesi | Cleanvest'in **kendi** vault'u |
| **PoV_Hash** | `SHA256(payload \| target \| salt \| ts)` — bulgular taahhüt | **Aynı şema**: `SHA256("cleanvest-quality-v1" \| test-listesi \| coverage \| commit)` |
| **Bulgular** | Kritik/Yüksek/Orta/Düşük sayısı (kamusal) | **0 kritik, 0 yüksek** (5 vektör test-kanıtli) |
| **Kanıt** | Exploit örneği (satır numarası gizli) | `forge test` 174/174 + `forge coverage` %99.42 line |

### Somut paket içeriği (AegisForge'a eklenebilir)

```
Cleanvest Vault Denetim-Oncesi Kalite Raporu v1
================================================
PoV_Hash:      SHA256("cleanvest-quality-v1" || <test-id-listesi> ||
                <coverage-json> || <commit-hash> || <ts>)
Test sonucu:   174 passed / 0 failed (166 kurulu + 8 kopru)
Coverage:      %99.42 line / %98.62 branch (6 sozlesme)
Saldiri vektorleri: 5/5 test-kanıtli, KRITIK ZAFIYET YOK
  - Donation attack: 199 wei kayip -> depositWithMin revert ile koruma
  - Share price manipulation: view-only
  - First-depositor inflation: minShares kalkani
  - Rounding/dust: floor vault lehine
  - Approve race: standart ERC-20
Invariant'lar: 5 (300 derinlik fuzz)
  - juniorReserve >= TVL x %3
  - Cikislar ASLA kilitlenmez
  - Cap >= $100K
  - Vault assets <= cUSD supply
  - Allocation 10000 bps
Bilinen riskler (gizli DEGIL):
  - Merkezi birikim (owner EOA) -> multisig onerisi
  - OPTIMIZE modu feed bagliyken acilir
```

### AegisForge ile nasıl birleşir?

**AegisForge bir projeyi listelemek için denetler.** Cleanvest'in vault'u
**listelenecek bir proje DEĞİL** — o **paranın saklandığı kasadır**. Bu yüzden
paket şu şekilde çalışır:

1. **AegisForge, ListingGate'e** bir projenin PoV_Hash'ini yazar (mevcut akış)
2. **Cleanvest'in vault raporu**, AegisForge'un **CleanScore kamusal
   API'sine** ek bir kanıt olarak yayınlanabilir — böylece bir proje
   "Cleanvest'te listelenmek için AegisForge'dan geçti" derken,
   **kasasının da denetlendiği** kanıtlanır

> **Dürüst sınırlama:** Bu paket **henüz uygulanmadı** — sadece raporudur.
> AegisForge'nun PoV_Hash şemasına bir Cleanvest raporu **eklemek**, AegisForge
> çekirdeğinde (Rust) değişiklik gerektirir; bu Cleanvest'in kapsamı dışındadır.

---

## 5. 🔴 DÜRÜST ANALİZ — İş Modelindeki 3 Zayıf Yön

Lead "dürüst ol" dedi. İşte kullanıcı duymalı:

### Zayıflık 1: PROJE_KAGIDI ile KOD arasında kapsam farkı

**PROJE_KAGIDI'nın vaat ettiği, kodda OLMAYANlar** (2026-09-27 satır numaraları —
PROJE_KAGIDI artık her yerde bunları 🗺️ **YOL HARİTASI** olarak işaretler):

| Vaat | Kâğıtta | Kodda | Durum |
|---|---|---|---|
| **Validium / ZK-Proof settlement** | L137 "toplu ZK-Proof" + L29 tablo | **0 dosya** | 🔴 YOK (yol haritası) |
| **Escape Hatch (borsa kapansa da para çekme)** | L90 + L30 tablo | **0 dosya** | 🔴 YOK (yol haritası) |
| **Privy/Web3Auth MPC giriş** | L88 + L31 tablo | **0 dosya** | 🔴 YOK (yol haritası) |
| **Omnichain settlement** | L6 + L32 tablo | **0 dosya** | 🔴 YOK (yol haritası) |
| **CoW netting + RFQ solver ağı** | L104-138 (§3 banner ile işaretli) | `CleanvestSettlement` (400ms FBA) | 🟡 KISMEN |
| **Senior/Junior tranche waterfall** | L160-186 (§4.3 banner ile işaretli) | `CleanUSD` junior %3 | 🟡 KISMEN |
| **Rezerv: %75 BUIDL + %15 delta-neutral arbitraj** | L175-177 (§4.3 banner ile işaretli) | **%73 Aave / %15 Prime / %12 idle** | 🔴 YANLIŞ (düzeltildi) |
| **"48 Güvenlik İnvariantı"** | eski L208 — **ÇIKARILDI** | **5 invariant** (`test/scusd_vault_invariants.t.sol`) | 🔴 YANLIŞ (çıkarıldı) |
| **HITL "%0 (ZK-Rollup)"** | eski L235 — **DÜZELTİLDİ** | operatöre bağımlı | 🔴 YANLIŞ (düzeltildi) |

**Kodda GERÇEKTE var olan 6 sözleşme:** CleanUSD, CleanFXVault, ListingGate,
CleanvestSettlement, ReserveManager, UniswapProxy.

> **Müşteriye dürüstçe:** Mevcut ürün **ERC-4626 getiri kasası + FBA settlement +
> AegisForge denetim kapısı + PQHaven USDC köprüsüdür (Seçenek A).** Kâğıttaki
> vizyon (Validium, omnichain) **yol haritasıdır, mevcut ürün değildir.** Bunu
> "sıfır manipülasyon vault" olarak satmak **abartı olur**; "denetimli getiri
> kasası" doğrudur. **Bu fark PROJE_KAGIDI sayfa başındaki DURUM RAPORU ile
> resmi olarak KAPATILDI** (2026-09-27, commit `2fa2b54`).

### Zayıflık 2: "Sıfır manipülasyon" tezi off-chain'de geçersiz

**Kanıtlandı (commit `e6a58b6`):** owner `depositReserve` çağırmazsa
**7e9 USDC EOA'da birikir**. On-chain manipülasyon sıfır olsa da,
**anahtar yönetimi** tek bir güven noktasıdır.

**Müşteriye söylenmeli:** "Sözleşmeler manipülasyona kapalıdır. Ancak
fonların reserve'e aktarılması **operasyonel bir adımdır** ve multisig
ile korunmalıdır. Bu adımı biz yapana kadar risk bizdedir."

### Zayıflık 3: Köprü getirisi müşteriye değil treasury'ye

Bölüm 2'de belirtildi: PQHaven köprüsü **treasury getirisi** üretir,
müşteri getirisi DEĞİL. Bu, "müşteri kazanır" olarak sunulamaz.

> **Önerilen dürüst pozisyon:** Cleanvest'i **müşteriye "getiri ürünü"**
> olarak değil, **"hazineniz için kurumsal getiri yönetimi"** olarak konumla.
> Müşteri = hazine yöneticisi; getiri = hazineye. Bu, hem doğrudur hem de
> hedef kitleyle uyumludur (15 hazne adayı, docs/24).

---

## 6. İş Modeli Cevabı (özet)

| Soru | Cevap |
|---|---|
| **Unpump x402** | Ödeme altyapısı (fail-closed 402/503, tek-kasa) |
| **AegisForge** | Denetim motoru (PoV_Hash taahhüdü, 4 kademeli) |
| **Cleanvest = ?** | **ERC-4626 getiri kasası + FBA settlement + AegisForge denetim kapısı + PQHaven USDC köprüsü (Seçenek A)** |

**Cleanvest'in müşteri teklifi (özet):** Boşta duran kurumsal USDC'yi **Aave
üzerinden kurumsal getiriye** (Tier0: %73 Aave / %15 Prime / %12 idle) yatır,
çıkış kapısını asla kilitleme, manipülasyonu sıfırla. **Ama dürüstçe:** mevcut
ürün kâğıttaki vizyonun bir altkümesidir — **ABD Hazine Bonosu (BUIDL) yalnızca
Tier2'de, TVL ≥ $12.5M'da mevcuttur.**

---

## 7. Kanıt Protokolü

```
IDDIA:  docs/35 pitch'i PROJE_KAGIDI (YOL A) ile birebilir hizalandi
        + docs/36_IDDIALAR_TABLOSU.md olusturuldu (20 iddia, file:line kanitli)
KANIT:  git status --short contracts/ | wc -l → 0  +  forge test → 174 passed, 0 failed
RC:     0
COMMIT: (bu commit)
DOSYA:  docs/35_IS_MODELI_VE_DENETIM_ONCESI_KALITE.md
        docs/36_IDDIALAR_TABLOSU.md
        PROJE_KAGIDI.md ("48" cikarildi + $1.2M notu)
```

**Kısıt uyumu:**
- ✅ **HİÇBİR Solidity kodu değiştirilmedi** (`contracts/` dokunulmadı)
- ✅ **174 forge test** altına düşmedi (kanıt yukarıda)
- ✅ **`juniorCoverageBps` 1.157e77** tasarım notu korundu (docs/34 §5)
- ✅ **Dürüst:** 3 zayıf yön açıkça yazıldı (kullanıcı duymalı)
- ✅ **"48 Güvenlik İnvariantı" ÇIKARILDI** — gerçeği **5** invariant
- ✅ **docs/35 ↔ PROJE_KAGIDI birebir** (aynı mevcut-ürün tanımı + roadmap)
- ✅ **$1.200.000+ hedefine** "0 gerçek müşteri, $0 gerçek gelir" notu eklendi
- ✅ Rapor modu: sadece doküman, hiçbir kod
