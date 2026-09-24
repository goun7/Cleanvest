# PROJEYE BAKIŞ: Cleanvest — Sıfır-Manipülasyonlu Hibrit Spot Borsa (HEX) ve Getirili Küresel FX Protokolü (The Clean Machine & CleanFX)

> **Hat:** 🦄 Unicorn Hattı (`01_unicorn` / CeFi-DeFi Hybrid Exchange, RWA & Zero-MEV Trading Infrastructure)  
> **Konumlandırma:** Kripto ve FX Dünyasının İlk Kumar/Kaldıraç İçermeyen, Otomatik Getirili ve Denetimli Hibrit Spot Borsası  
> **Slogan:** *"No Leverage. No Front-Running. No Idle Cash."*  
> **Zaman Ufku:** 2026 Q4 Testnet & Gatekeeper Alpha ➔ 2027 Q1 Mainnet Launch (Omnichain Settlement)  
> **Hukuki ve Mali Statü:** Non-Custodial Validium Architecture (Kullanıcı Fon Emaneti Yoktur), Senior-Junior Tranche RWA Modeli, 193 Sayılı GVK Madde 89/13 (%100 Yurtdışı Yazılım/Veri İhracatı Kazanç İstisnası, %0 KDV, %0 Gelir Vergisi)  
> **Sürüm:** 🛡️ **v1.0 — Enterprise-Sovereign (Bilimsel, Kriptografik, Finans Mühendisliği ve Red-Team Denetimli Master Doküman)**  
> **Alan Adı / Marka:** `Cleanvest` (Web: `cleanvest.market` / `cleanvest.fi` — FX Motoru: `CleanFX` — Varlık: `CleanUSD` / `$cUSD`)

---

## 1. Yönetici Özeti ve Sektörel Paradigma Kırılması

Mevcut kripto para borsaları (Binance, Bybit vb.) ve merkeziyetsiz türev platformları (Hyperliquid, dYdX), gelirlerinin %85'ini **kaldıraçlı kumar (Futures/Perps), tasfiyeler (liquidation) ve yüksek frekanslı ticaret (HFT) botlarına sağladıkları imtiyazlı API erişimlerinden** elde etmektedir. 
Bu ekosistemde spot fiyatlar gerçek alıcı-satıcılar tarafından değil; milyar dolarlık türev balinalarının spot tahtaları aşağı/yukarı manipüle etmesiyle belirlenir. Perakende tüccarların **%95'i ilk 90 gün içinde tüm sermayesini kaybetmektedir (Rekt).**

**Cleanvest**, bu toksik finansal kumarhaneye doğrudan antitez olarak tasarlanmış **dünyanın ilk Sıfır-Manipülasyonlu Hibrit Spot Borsası (HEX)** ve **Getirili Küresel FX Motorudur (CleanFX)**:

1. **Sıfır Kaldıraç & Sıfır Tasfiye (%100 Spot):** Kaldıraçlı işlem, marjin borçlanması ve likidasyon mekanizması kod seviyesinde fiziksel olarak yoktur.
2. **Bot-Geçirmez İzole Tahta (Zero HFT Front-Running):** Halka açık API anahtarı verilmez. HFT botlarının tahtayı taraması, perakendenin emirlerini önden görmesi (front-running) ve sandviç yapması imkansızdır.
3. **Sıfır Kurucu Sermayesi ile Likidite (CoW Netting + Certified RFQ):** Kurucunun cebinden $1 bile likidite koymasına gerek yoktur; iç emirler Talep Çakışması (Coincidence of Wants) ile eşlenir, artık hacim kapalı kurumsal toptancılar tarafından karşılanır.
4. **CleanFX & $cUSD (Getirili Küresel Para):** Bankaların %2-%3'lük döviz makasını toptan interbank kurlarla ezer; cüzdanda boş duran nakite **otomatik yıllık %4.8 ABD Hazine Bonosu faizi** kazandırır.
5. **AegisForge + AutoVerus 4 Kademeli Otonom Denetim:** Listeleme başvurusu yapan projelerin açıkları taranır; açık tespit edildiğinde detaylar bedava verilmez, **$4.900'lık kriptografik zafiyet kanıtı (PoV) ve düzeltme paketi** satılarak borsa daha ilk günden otonom B2B nakit akışı üretir.

---

## 2. Kullanıcı Deneyimi ve Pazar Psikolojisi: Hyperliquid Çağında Kullanıcıyı Nasıl Çekeceğiz?

### 2.1. Kaldıraç Yorgunluğu (Perp Fatigue & The Post-Rekt Audience)
Kripto piyasasında döngüsel bir psikolojik kural vardır: **Her kumar dalgası, arkasında devasa bir tükenmiş ve sermayesini kaybetmiş kitle bırakır.**
* Hyperliquid ve türev DEX'leri risk iştahı yüksek spekülatörleri çekerken; sermayesini korumak, gerçek değer biriktirmek (DCA - Dollar Cost Averaging) isteyen milyonlarca insan **"manipülasyonsuz güvenli bir liman"** aramaktadır.
* **Pazarlama Sloganı:** *"Stop Gambling. Start Investing. Your capital can never be liquidated here."*

### 2.2. Hibrit Kullanıcı Deneyimi (Web2 Sadeliği + Web3 Egemenliği)
* **Giriş Katmanı:** Kullanıcı ne karmaşık seed phrase ezberlemek ne de merkezi borsaya pasaport yükleyip fonunu teslim etmek zorundadır. **Privy / Web3Auth MPC (Multi-Party Computation)** ile Google/Apple hesabı üzerinden saniyeler içinde non-custodial cüzdan oluşturulur.
* **CEX Arayüzü Hızı:** İşlemler off-chain eşleme motorunda 10 milisaniyede gerçekleşir; tıklama anında emir gerçekleşir.
* **DEX Güvenliği:** Varlıklar kullanıcının kendi akıllı sözleşme kasasındadır. Cleanvest kapansa bile kullanıcı blokzincirdeki kaçış kapısından (Escape Hatch) parasını tek işlemle çeker.

---

## 3. Sıfır Sermaye ile Piyasa Yapımı Mimarisi (CoW Netting + RFQ Solvers)

Cleanvest, kurucunun kasasında tek kuruş market maker sermayesi olmadan kurumsal derinlik sunar:

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                               CLEANVEST SIFIR SERMAYELİ HİBRİT TAKAS MOTORU (HEX)                           │
│                                                                                                             │
│  [Perakende Yatırımcı A: 10 ETH Alış Emri]               [Perakende Yatırımcı B: 10 ETH Satış Emri]         │
│                      │                                                              │                       │
│                      ▼                                                              ▼                       │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 1. KORUMALI OFF-CHAIN EMİR DEFTERİ (SHIELDED INTENT ORDERBOOK)                                        │  │
│  │ - Emirler halka açık mempool'a DÜŞMEZ! (MEV botları göremez, kopyalayamaz).                           │  │
│  │ - Dışarıya API Key verilmez; HFT botları tahtayı manipüle edemez.                                     │  │
│  └───────────────────────────────────┬───────────────────────────────────────────────────────────────────┘  │
│                                      │                                                                      │
│                                      ▼                                                                      │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 2. TALEP ÇAKIŞMASI MOTORU (COINCIDENCE OF WANTS - CoW BATCH NETTING)                                  │  │
│  │ - Her 500 milisaniyede bir iç emirleri tarar: A'nın alımı ile B'nin satışı DOĞRUDAN P2P EŞLEŞİR!     │  │
│  │ - SIFIR LİKİDİTE HAVUZU GEREKİR! Kurucu $1 bile sermaye koymaz.                                      │  │
│  │ - Fiyat tam orta piyasa (Mid-Market) fiyatından sıfır kayma (Zero Slippage) ile kesişir.             │  │
│  └───────────────────────────────────┬───────────────────────────────────────────────────────────────────┘  │
│                                      │ (İçeride Eşleşmeyen Artık Hacim Varsa)                               │
│                                      ▼                                                                      │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 3. SERTİFİKALI KAPALI RFQ ÇÖZÜCÜ AĞI (CERTIFIED INSTITUTIONAL SOLVERS)                                │  │
│  │ - Eşleşmeyen emirler dışarı sızdırılmaz; borsanın onayladığı kurumsal toptancılara kapalı             │  │
│  │   RFQ (Request for Quote) sinyali gönderilir.                                                         │  │
│  │ - Toptancılar en dar marjla emri doldurmak için rekabet eder. En iyi fiyatı veren emri alır.          │  │
│  │ - Toptancı kendi sermayesini kullanır; borsa yine sıfır sermaye riski taşır!                          │  │
│  └───────────────────────────────────┬───────────────────────────────────────────────────────────────────┘  │
│                                      │ (İşlem Tamamlandığında)                                              │
│                                      ▼                                                                      │
│  ┌───────────────────────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 4. ON-CHAIN ATOMİK VE ZK-KANITLI TAKAS (VALIDIUM STATE SETTLEMENT)                                    │  │
│  │ - Bakiye değişimleri toplu ZK-Proof (Stark/SNARK) ile blokzincirdeki akıllı sözleşme kasasına yazılır.│  │
│  │ - Borsa asla fonları tutmaz; %100 Non-Custodial uzlaşma gerçekleşir.                                  │  │
│  └───────────────────────────────────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. CleanFX ve $cUSD: Boşta Duran Paraya ABD Tahvil Faizi Veren Küresel FX Rayı

### 4.1. Bankaların Kur Makasını Kıran Döviz Geçidi (CleanFX)
Geleneksel bankalarda döviz makası (Spread) %2.0 – %3.5 seviyesindedir. Kullanıcı $10.000 döviz aldığında kapıdan girerken $250 zarar eder.
* **CleanFX:** Kullanıcı yerel para birimini (USD, EUR, GBP, TRY, BRL vb.) banka transferi veya yerel ödeme rayıyla yatırır.
* Sistem toptan kurumsal bankalararası (Interbank) döviz kurunu uygular; makas **%0.10'un altına iner.**
* Kullanıcı tek tıkla dövizini **`CleanUSD` ($cUSD)** varlığına dönüştürür.

### 4.2. Boşta Duran Nakit Devrimi (The Yield-Bearing Cash Machine)
Kullanıcı işlem yapmasa, parası vadesiz hesapta boş dursa bile:
* Tether veya bankalar kullanıcının parası üzerinden kazandığı faizi cebe atarken;
* **Cleanvest, $cUSD tutan her cüzdana yıllık %4.8 ABD Hazine Bonosu faizini saniyelik rebase ile otomatik yansıtır!**
* Kullanıcının 10.000 $cUSD'si yıl sonunda hiçbir işlem yapmadan **10.480 $cUSD** olur.

### 4.3. Çok Katmanlı Risk İzolasyonu ve İflas Kalkanı (First-Loss Capital)
Terra/Luna veya Celsius facialarının tekrarlanmaması için **Kıdemli-Ast Dilim Mimarisi (Senior-Junior Tranche Waterfall)** zorunludur:

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                CleanUSD ($cUSD) ÇOK KATMANLI RİSK İZOLASYONU                                │
│                                                                                                             │
│  [KULLANICI VARLIKLARI: $cUSD BAKİYELERİ] ──► %100 KIDEMLİ DİLİM (SENIOR TRANCHE)                           │
│  - Asla kredi veya getiri riski almaz. Daima 1:1 USD sabittir.                                              │
│  - 7/24 anında çekilebilir (Instant Liquidity).                                                             │
│                                                                                                             │
│  ─────────────────────────────────────────────────────────────────────────────────────────────────────────  │
│                                                                                                             │
│  [KAYIP EMİCİ PROTOKOL TAMPONU: FIRST-LOSS RESERVE (JUNIOR TRANCHE)]                                        │
│  - Borsa komisyonlarından biriken protokol rezervi + yüksek getiri arayan kurumsal staker sermayesi.        │
│  - EĞER BİR REZERVDE %2 KAYIP YAŞANIRSA:                                                                    │
│    * Bu zarar doğrudan Junior Dilim tarafından %100 absorbe edilir (First-Loss Capital).                    │
│    * Kıdemli kullanıcının 1 $cUSD'sine tek bir sent bile zarar yansımaz!                                    │
│                                                                                                             │
│  ─────────────────────────────────────────────────────────────────────────────────────────────────────────  │
│                                                                                                             │
│  [SIFIR KREDİ RİSKLİ KURUMSAL REZERV DAĞILIMI (BANKRUPTCY-REMOTE)]:                                         │
│  - %75: BlackRock BUIDL ve Ondo USDY (ABD Hazine Bonoları BNY Mellon kasasındadır; şirket iflasından muaf). │
│  - %15: Delta-Neutral Vadeli Fonlama Arbitrajı (Merkeziyetsiz türev borsalarında marjin).                 │
│  - %10: Anlık Nakit Çıkış Tamponu (Aave / Curve Spot USDC).                                                │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. B2B Otonom Güvenlik Kapısı: AegisForge + AutoVerus Entegrasyonu

Cleanvest'te listelenmek isteyen her proje, portföyümüzdeki iki devrimsel motorun **4 Kademeli Güvenlik Hattından** geçer.

### 5.1. 4 Kademeli Purity Denetimi
1. **Katman 1 — Matematiksel Formel İspat ([13_AutoVerus](file:///home/gokun/projects/Yeni%20Fikirler/oncu_fikirler_havuzu_2026/13_AutoVerus_Rust_Formal_Dogrulama_Ve_ASIL_D_Kanit_Motoru/PROJE_KAGIDI.md)):** Z3 SMT çözücüsü sözleşmeyi sembolik olarak kanıtlar. (Sonsuz token basılabilir mi? Kullanıcı bakiyeleri harici bir fonksiyonla dondurulabilir mi?).
2. **Katman 2 — Metamorfik Yarış Durumu Fuzzing'i ([07_AegisForge](file:///home/gokun/projects/Yeni%20Fikirler/oncu_fikirler_havuzu_2026/07_AegisForge_DeFi_Metamorfik_Yaris_Durumu_Avcisi/PROJE_KAGIDI.md)):** Eşzamanlı blok içi işlemler, reentrancy ve flash loan manipülasyon testleri.
3. **Katman 3 — Tokenomics ve Likidite Sağlığı:** İlk 10 balina cüzdanının payı (%30'un altı zorunlu), likidite kilit kanıtı (Uncx/TeamFinance) ve vesting kilit takvimi.
4. **Katman 4 — Sinsi Kod ve Arka Kapı Avı:** `blacklist()`, `pause()`, gizli transfer vergisi (hidden fee) taraması.

### 5.2. Ticari Satış Modeli: Cryptographic Proof-of-Vulnerability (PoV)
Açık tespit edildiğinde geliştiriciye satır numarası **asla bedava söylenmez.**
* Sistem, açığı sömüren bir istismar kanıtı üretir ve bunun **kriptografik özet hash'ini ($PoV\_Hash$)** zincire basar.
* Başvuru sahibine şu otonom bildirim gider:
  > *"Sözleşmeniz Cleanvest'in 48 Güvenlik İnvariantından 3 tanesinde KRİTİK SEVİYEDE BAŞARISIZ oldu (Fon Kaybı Riski). $PoV\_Hash$ zincirde mühürlenmiştir. Listeleme başvurunuz durdurulmuştur. Açığın istismar kodunu, düzeltme yamasını (remediation patch) ve 'Cleanvest Verified' yeşil mührünü almak için Güvenlik Paketi Bedeli: $4.900."*
* Proje açığını kapatmak ve Cleanvest'in güvenli yatırımcı kitlesine erişmek için bu bedeli öder. Cleanvest, hacimden bağımsız olarak **otonom bir siber güvenlik şirketine (SaaS)** dönüşür.

---

## 6. Red Team vs. Blue Team: 6 Kritik Patlama Noktası ve Zırhlar

| # | Patlama Alanı | 💥 Red Team Exploit Senaryosu | 🛡️ Blue Team Kriptografik Zırhı |
|---|---|---|---|
| **1** | **Solver Gizli Anlaşması (Collusion)** | RFQ toptancıları anlaşarak kullanıcılara bilerek kötü fiyat verir ve aradaki farkı paylaşır. | **ZK-Fair Price Bounds:** Oracle fiyatından %0.15'ten fazla sapan hiçbir teklif borsa motoru tarafından kabul edilmez; işlem atomik olarak iptal edilir. |
| **2** | **$cUSD Depeg ve İtfa Gecikmesi** | ABD Hazine piyasalarında likidite sıkışır, BlackRock BUIDL itfası 24 saat gecikir; kullanıcılar bank run yapar. | **Senior/Junior Waterfall + %10 Anlık Nakit:** İlk %10 nakit Aave/USDC havuzundan anında ödenir; olası kayıplar Junior First-Loss rezervi tarafından karşılanır. |
| **3** | **Sığ Tahta (Cold-Start Gecikmesi)** | Yeni açılan paritelerde kullanıcı sayısı az olduğu için CoW eşleşmesi 30 saniye gecikebilir. | **Kademeli Zaman Aşımı (Dynamic Fallback):** 3 saniye içinde iç eşleşme olmazsa emir otomatik olarak onaylı RFQ toptancısına yönlendirilir; gecikme engellenir. |
| **4** | **Banka On-Ramp Bloke Riski** | Bankalar döviz transferi yapan CleanFX hesaplarını "kripto işlemi" gerekçesiyle dondurur. | **Lisanslı EMI ve P2P Stablecoin Ortaklıkları:** Fonlar doğrudan borsanın hesabına değil; lisanslı Electronic Money Institution (EMI) ortaklarına ve yerel P2P takas noktalarına akar. |
| **5** | **Regülasyon ve Menkul Kıymet Baskısı** | SEC veya MiCA, "bu borsa CEX'e benziyor, lisans almalısınız" der. | **Non-Custodial Validium Zırhı:** Borsa operatörünün kullanıcı cüzdanına erişimi teknik olarak imkansızdır; kod akıllı sözleşme üzerinde çalışır, emanet (custody) sıfırdır. |
| **6** | **Formal Doğrulama Yanılgısı (False Negatives)**| Akıllı sözleşmede AutoVerus'un invariant kurallarında tanımlanmamış sıra dışı bir mantık hatası kalır. | **Çift Motorlu Hibrit Analiz:** Z3 SMT çözücüsü sembolik olarak kanıtlarken; AegisForge 10.000 rastgele mutasyon testiyle (Mutation Testing) sözleşmeyi sarsar. |

---

## 7. Protokol Ekonomisi ve Ciro Projeksiyonu (12. Ay)

1. **Spot Takas Komisyonu:** Her başarılı işlemden **%0.08 protokol ücreti** (Sektör standardı %0.10'un altındadır).
2. **CleanFX Marjı:** Bankalararası toptan kurun üzerine eklenen **%0.10 mikro-marj** (Bankaların %2.5'luk kazığına kıyasla 25 kat daha ucuzdur).
3. **$cUSD Rezerv Yönetim Payı (Spread):** Rezervlerin ürettiği %5.5 faizin %4.75'i kullanıcıya verilir; **%0.75'i Cleanvest protokol hazinesine** kalır.
   * $100M TVL'de = **Yıllık $750.000 net pasif getiri.**
4. **B2B Güvenlik Denetim Geliri:** Günde 2 projeye açık düzeltme paketi satışı:
   * $2 \times \$4.900 \times 30 = \mathbf{\$294.000 / \text{aylık net B2B ciro}}$.
5. **Toplam Finansal Hedef (12. Ay):** Günlük $15M spot ve FX hacmi + 100M $cUSD TVL + B2B Denetim = **Aylık $1.200.000+ Net Nakit Akışı.**
6. **HITL Seviyesi:** **%0 (Tamamen Otonom Hibrit Akıllı Sözleşmeler ve ZK-Rollup).**
