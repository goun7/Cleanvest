# PROJEYE BAKIŞ: Cleanvest — Sıfır-Manipülasyonlu Hibrit Spot Borsa (HEX) ve Getirili Küresel FX Protokolü (The Clean Machine & CleanFX)

> **Hat:** 🦄 Unicorn Hattı (`01_unicorn` / CeFi-DeFi Hybrid Exchange, RWA & Zero-MEV Trading Infrastructure)  
> **Konumlandırma:** Kripto ve FX Dünyasının İlk Kumar/Kaldıraç İçermeyen, Otomatik Getirili ve Denetimli Hibrit Spot Borsası  
> **Slogan:** *"No Leverage. No Front-Running. No Idle Cash."*  
> **Zaman Ufku:** 2026 Q4 Testnet & Gatekeeper Alpha ➔ 2027 Q1 Mainnet Launch 🗺️ *(Omnichain Settlement bir HEDEFTİR — mevcut üründe kod YOK)*  
> **Hukuki ve Mali Statü:** Non-Custodial (kullanıcı fonları kendi cüzdanlarındaki $cUSD / $scUSD token'larıdır — emanet YOKTUR; "Validium Architecture" 🗺️ **YOL HARİTASI**, mevcut üründe Validium kodu YOK), Senior-Junior Tranche RWA Modeli, 193 Sayılı GVK Madde 89/13 (%100 Yurtdışı Yazılım/Veri İhracatı Kazanç İstisnası, %0 KDV, %0 Gelir Vergisi)  
> **Sürüm:** 🛡️ **v1.0 — Enterprise-Sovereign (Bilimsel, Kriptografik, Finans Mühendisliği ve Red-Team Denetimli Master Doküman)**  
> **Alan Adı / Marka:** `Cleanvest` (Web: `cleanvest.market` / `cleanvest.fi` — FX Motoru: `CleanFX` — Varlık: `CleanUSD` / `$cUSD`)

---

## ⚠️ DURUM RAPORU — MEVCUT ÜRÜN vs YOL HARİTASI (2026-09-27)

> **DÜRÜST OKUMA ZORUNLU.** Bu doküman hem **mevcut ürünü** hem de **yol
> haritasını** içerir. Aşağıdaki tablo, hangisinin hangisi olduğunu netleştirir.
> **Müşteri sunumunda yalnızca "✅ MEVCUT" satırları kullanılmalıdır.**

| Özellik | Durum | Kanıt |
|---|---|---|
| **ERC-4626 getiri kasası** ($scUSD, 3 kademe) | ✅ **MEVCUT** | `CleanFXVault.sol` + 174 test + %99.42 line coverage |
| **$cUSD sabit $1.00, rebase YOK** | ✅ **MEVCUT** | `CleanUSD.sol` + `testNoRebaseFunction` |
| **400ms FBA batch settlement** | ✅ **MEVCUT** | `CleanvestSettlement.sol` (CoW netting kısmi) |
| **AegisForge denetim kapısı** (PoV_Hash) | ✅ **MEVCUT** | `ListingGate.sol` L28-32 (PoV_Hash taahhüdü) |
| **Senior/Junior tranche** (junior ≥ %3 TVL buffer) | ✅ **MEVCUT** | `CleanUSD.sol` `JUNIOR_MIN_BPS=300` + fail-closed mint-halt (`canMint`) — otomatik kayıp yansıtma DEĞİL |
| **Reserve yönetimi** (3 kademe) | ✅ **MEVCUT** | `ReserveManager.sol` — Tier0: %73 Aave / %15 Prime / %12 idle; BUIDL/OU SG yalnızca Tier2 |
| **UniswapProxy artık hacim** (şeffaf kayma) | ✅ **MEVCUT** | `UniswapProxy.sol` |
| **PQHaven USDC köprüsü** (Seçenek A) | ✅ **MEVCUT** | `test/PQHavenBridge.t.sol` + docs/34 (anvil kanıtı) |
| **Validium / ZK-Proof settlement** | 🗺️ **YOL HARİTASI** | **Kodda YOK** (2027 Q1 hedefi) |
| **Escape Hatch** (borsa kapansa da çıkış) | 🗺️ **YOL HARİTASI** | **Kodda YOK** |
| **Privy / Web3Auth MPC giriş** | 🗺️ **YOL HARİTASI** | **Kodda YOK** (off-chain, frontend katmanı) |
| **Omnichain settlement** | 🗺️ **YOL HARİTASI** | **Kodda YOK** (2027 Q1 hedefi) |
| **RFQ solver ağı** (kurumsal toptancılar) | 🗺️ **YOL HARİTASI** | Sadece `UniswapProxy` (tek proxy) |

> **Mevcut ürünün doğru tanımı (docs/35 §5 ile birebir):**
> Mevcut ürün **ERC-4626 getiri kasası + FBA settlement + AegisForge denetim
> kapısı + PQHaven USDC köprüsü (Seçenek A).** Kodda **6 sözleşme** vardır:
> `CleanUSD`, `CleanFXVault`, `ListingGate`, `CleanvestSettlement`,
> `ReserveManager`, `UniswapProxy`. Kâğıttaki vizyon (Validium, omnichain)
> **yol haritasıdır, mevcut ürün değildir.**
>
> **Dürüst satış pozisyonu:** Bu bir "sıfır manipülasyon vault" olarak
> **abartılamaz**; doğru konum **"denetimli getiri kasası"**dur.

### 🔴 BİLİNEN 3 ZAYIF YÖN (kullanıcı duymalı — docs/35 §5 ile birebir)

1. **Kapsam farkı — BU GÜNCELLEME İLE GİDERİLDİ:** Bu tablo, vaat ile kod
   arasındaki farkı netleştirir. Artık "Validium" okuyan biri **yol haritası**
   olarak görür, mevcut ürün olarak değil.
2. **"Sıfır manipülasyon" tezi off-chain'de geçersizdir:** Sözleşmeler
   manipülasyona kapalıdır, ANCAK fonların reserve'e aktarılması **operasyonel
   bir adımdır**. Kanıtlandı (`e6a58b6` / `docs/34 §7`): owner
   `depositReserve` çağırmazsa **7e9 USDC EOA'da birikir** ve reserve
   değişmez — **anahtar yönetimi tek bir güven noktasıdır.** Riske karşı
   çözüm: multisig (`transferOwnership` → Gnosis Safe; 6 sözleşmenin tamamı
   `Ownable`). Bu adımı biz yapana kadar **risk bizdedir.**
3. **Köprü getirisi müşteriye değil treasury'ye akar:** PQHaven köprüsü
   **treasury getirisi** üretir, müşteri getirisi DEĞİL — "müşteri kazanır"
   olarak sunulamaz. Dürüst konum: **"hazineniz için kurumsal getiri yönetimi"**
   (müşteri = hazine yöneticisi; getiri = treasury'ye; bkz. `docs/24`'teki
   15 hazne adayı).

---

## 1. Yönetici Özeti ve Sektörel Paradigma Kırılması

Mevcut kripto para borsaları (Binance, Bybit vb.) ve merkeziyetsiz türev platformları (Hyperliquid, dYdX), gelirlerinin %85'ini **kaldıraçlı kumar (Futures/Perps), tasfiyeler (liquidation) ve yüksek frekanslı ticaret (HFT) botlarına sağladıkları imtiyazlı API erişimlerinden** elde etmektedir. 
Bu ekosistemde spot fiyatlar gerçek alıcı-satıcılar tarafından değil; milyar dolarlık türev balinalarının spot tahtaları aşağı/yukarı manipüle etmesiyle belirlenir. Perakende tüccarların **%95'i ilk 90 gün içinde tüm sermayesini kaybetmektedir (Rekt).**

**Cleanvest**, bu toksik finansal kumarhaneye doğrudan antitez olarak tasarlanmış **dünyanın ilk Sıfır-Manipülasyonlu Hibrit Spot Borsası (HEX)** ve **Getirili Küresel FX Motorudur (CleanFX)**:

1. **Sıfır Kaldıraç & Sıfır Tasfiye (%100 Spot):** Kaldıraçlı işlem, marjin borçlanması ve likidasyon mekanizması kod seviyesinde fiziksel olarak yoktur.
2. **Bot-Geçirmez İzole Tahta (Zero HFT Front-Running):** Halka açık API anahtarı verilmez. HFT botlarının tahtayı taraması, perakendenin emirlerini önden görmesi (front-running) ve sandviç yapması imkansızdır.
3. **Sıfır Kurucu Sermayesi ile Likidite (CoW Netting + Certified RFQ):** Kurucunun cebinden $1 bile likidite koymasına gerek yoktur; iç emirler Talep Çakışması (Coincidence of Wants) ile eşlenir, artık hacim kapalı kurumsal toptancılar tarafından karşılanır.
4. **CleanFX & $cUSD (Getirili Küresel Para):** Bankaların %2-%3'lük döviz makasını toptan interbank kurlarla ezer; boşta duran nakit **$scUSD ERC-4626 getiri kasasında** üç kademeli dürüst getiri (%3.05 → %2.91 → %2.92, TVL'e göre) kazanır. **Rebase YOK** — $cUSD sabit $1.00'dir.
5. **AegisForge + AutoVerus 4 Kademeli Otonom Denetim:** Listeleme başvurusu yapan projelerin açıkları taranır; **dört kademeli fiyatlandırma** sunulur: $199 Z3 hızlı tarama (otomatik) / $399 insan triyajlı tarama / $990 fuzz+patch / $4.900 öncelikli rozet (docs/40). **Motorların Rust çekirdekleri YOL HARİTASI** — bkz. §5 durum notu. Açık detayları PoV_Hash (deterministik **hash taahhüdü** — ZK-SNARK değil) ile kilitlenir. Borsa ilk günden otonom B2B nakit akışı üretir; CleanScore kamusal API'si **ücretsizdir, haraç modeli yoktur**.

---

## 2. Kullanıcı Deneyimi ve Pazar Psikolojisi: Hyperliquid Çağında Kullanıcıyı Nasıl Çekeceğiz?

### 2.1. Kaldıraç Yorgunluğu (Perp Fatigue & The Post-Rekt Audience)
Kripto piyasasında döngüsel bir psikolojik kural vardır: **Her kumar dalgası, arkasında devasa bir tükenmiş ve sermayesini kaybetmiş kitle bırakır.**
* Hyperliquid ve türev DEX'leri risk iştahı yüksek spekülatörleri çekerken; sermayesini korumak, gerçek değer biriktirmek (DCA - Dollar Cost Averaging) isteyen milyonlarca insan **"manipülasyonsuz güvenli bir liman"** aramaktadır.
* **Pazarlama Sloganı:** *"Stop Gambling. Start Investing. Your capital can never be liquidated here."*

### 2.2. Hibrit Kullanıcı Deneyimi (Web2 Sadeliği + Web3 Egemenliği)
* **Giriş Katmanı:** Kullanıcı ne karmaşık seed phrase ezberlemek ne de merkezi borsaya pasaport yükleyip fonunu teslim etmek zorundadır. **Privy / Web3Auth MPC (Multi-Party Computation)** ile Google/Apple hesabı üzerinden saniyeler içinde non-custodial cüzdan oluşturulur. 🗺️ **YOL HARİTASI — bu frontend / off-chain katmandadır, sözleşmelerde KODU YOK; mevcut durumda standart bir cüzdanla (MetaMask vb.) bağlanılır.**
* **CEX Arayüzü Hızı:** Emirler **400ms Frequent Batch Auction (FBA)** ile toplanıp tek fiyatla eşlenir; hız yarışı (HFT front-run) yapısal olarak imkansızdır.
* **DEX Güvenliği:** Varlıklar kullanıcının kendi akıllı sözleşme kasasındadır. Cleanvest kapansa bile kullanıcı blokzincirdeki kaçış kapısından (Escape Hatch) parasını tek işlemle çeker. 🗺️ **YOL HARİTASI — "Escape Hatch" fonksiyonu kodda YOK. Mevcut gerçeği: $scUSD sahibi varlığını ERC-4626 withdraw ile çeker (redemption kuyruğu asla kilitli değildir); CleanUSD'de kullanıcı fonunu donduran pause ya da blacklist fonksiyonu YOKTUR.**

---

## 3. Sıfır Sermaye ile Piyasa Yapımı Mimarisi (CoW Netting + RFQ Solvers)

> 🗺️ **BU BÖLÜM YOL HARİTASIDIR.** Aşağıdaki mimarinin **tamamı henüz
> kodda YOK** — mevcut ürün yalnızca `CleanvestSettlement.sol` (400ms FBA
> batch) ve `UniswapProxy.sol` (artık hacim) içerir. "Shielded Intent
> Orderbook", "CoW Batch Netting", "RFQ Solver Ağı" ve "Validium Settlement"
> **tasarımdır, implementasyon değildir.**

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
│  │ - Her 400 milisaniyede (T_batch) iç emirleri tarar: A'nın alımı ile B'nin satışı DOĞRUDAN P2P EŞLEŞİR!     │  │
│  │ - SIFIR LİKİDİTE HAVUZU GEREKİR! Kurucu $1 bile sermaye koymaz.                                      │  │
│  │ - Fiyat tam orta piyasa (Mid-Market) fiyatından eşleşir. İç eşleşmede kayma sıfır; artık hacim Uniswap-proxy'den geçerken AMM kayması UI'da ŞEFFAF gösterilir.             │  │
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
* **Cleanvest, $cUSD'yi $scUSD ERC-4626 getiri kasasına yatırarak ücret alır.** **REBASE YOK** — $cUSD her zaman $1.00'dir; getiri yalnızca $scUSD hisselerinde birikir (Terra-mekanizması ölüm sarmalı riski kaldırıldı).
* **Dürüst üç kademeli getiri (2026-09-24 doğrulanmış verilerle):** %3.05 (TVL < $250k) → %2.91 ($250k–$12.5M) → %2.92 (≥ $12.5M). Eski "%4.8 saniyelik rebase" vaadi tamamen **silindi** — güncel verilerle (BUIDL %3.47, OUSG %3.44, Aave %3.78) kapanmıyordu.
* Örnek: 10.000 $scUSD Kademe 1'de yıl sonunda **≈10.291** olur. "Hazine Bonosu destekli" rozeti yalnızca TVL ≥ $250k'da (OUSG eşiği) gösterilir.

### 4.3. Çok Katmanlı Risk İzolasyonu ve İflas Kalkanı (First-Loss Capital)

> ✅ **MEVCUT OLAN:** Kıdemli-Ast (Senior-Junior) ayrımı ve **junior rezerv ≥ %3 TVL** zorunlu invariantı (`JUNIOR_MIN_BPS=300`, `CleanUSD.sol`) — mint sırasında ihlal edilirse **fail-closed olarak mint durur** (`canMint`, `invariantJuniorCoverageAfterMint` testiyle doğrulandı). $cUSD her zaman 1:1 USD sabittir, rebase YOKTUR.
>
> 🗺️ **AŞAĞIDAKİ DİYAGRAM YOL HARİTASIDIR.** Alt taraftaki "SIFIR KREDİ RİSKLİ KURUMSAL REZERV DAĞILIMI" kutusu **gerçek implementasyon DEĞİLDİR.** Deploy edilen Tier0 dağılımı: **%73 Aave / %15 Aave Prime / %12 idle** (`ReserveManager.sol`); BUIDL / OUSG yalnızca **Tier2** devresindedir (TVL ≥ $12.5M, Qualified Purchaser $5M minimum). **"Delta-Neutral Vadeli Fonlama Arbitrajı" implementasyonda HİÇ YOKTUR.** Ayrıca "kayıp otomatik olarak Junior dilime yansıtılır" waterfall akışı henüz YOKTUR — junior rezerv bugün bir **mint-gating tamponudur**; ve `rebalance()` bir muhasebe kaydıdır, fonların gerçekten hareket etmesi operatörün `supplyToAave()` çağrısına bağlıdır (bkz. sayfa başı **Bilinen 3 Zayıf Yön** #2).
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

> ## 🔴 DÜRÜST DURUM NOTU — motorlar YOL HARİTASI
>
> Aşağıdaki 4 kademeli hattın **zincir üzerindeki etkileşim noktaları MEVCUTTUR**
> (`ListingGate.sol` oracle ABI, `PoV_Hash` şeması, fiyatlandırma 199/399/990/4.900).
> **Ancak iki motorun Rust çekirdekleri henüz mevcut DEĞİLDİR:**
> - **AegisForge** — kardeş proje `07_Temporit_...` taraması (2026-09-28)
>   ile **tek bir Rust dosyası** bulunmuştur (`probe.rs`, 42 satır);
>   `lib.rs`/`src/`/`Cargo.toml` YOK → **derlenemez bile**.
> - **AutoVerus** — bu entegrasyon bir **tasarım hedefidir**, üretilen
>   motor kodu kanıtlanmamıştır.
>
> **Müşteriye sunumda:** "denetim kapısı mevcut" denir (zincir tarafı
> doğrudur), "denetim motoru çalışıyor" DENMEZ. Gerçek Merkle emir
> taahhüdü üreticisi de aynı şekilde eksik (README güvenlik notu).

Cleanvest'te listelenmek isteyen her proje, portföyümüzdeki iki devrimsel motorun **4 Kademeli Güvenlik Hattından** geçer.

### 5.1. 4 Kademeli Purity Denetimi
1. **Katman 1 — Matematiksel Formel İspat ([13_AutoVerus](file:///home/gokun/projects/Yeni%20Fikirler/oncu_fikirler_havuzu_2026/13_AutoVerus_Rust_Formal_Dogrulama_Ve_ASIL_D_Kanit_Motoru/PROJE_KAGIDI.md)):** Z3 SMT çözücüsü sözleşmeyi sembolik olarak kanıtlar. (Sonsuz token basılabilir mi? Kullanıcı bakiyeleri harici bir fonksiyonla dondurulabilir mi?).
2. **Katman 2 — Metamorfik Yarış Durumu Fuzzing'i ([07_AegisForge](file:///home/gokun/projects/Yeni%20Fikirler/oncu_fikirler_havuzu_2026/07_AegisForge_DeFi_Metamorfik_Yaris_Durumu_Avcisi/PROJE_KAGIDI.md)):** Eşzamanlı blok içi işlemler, reentrancy ve flash loan manipülasyon testleri.
3. **Katman 3 — Tokenomics ve Likidite Sağlığı:** İlk 10 balina cüzdanının payı (%30'un altı zorunlu), likidite kilit kanıtı (Uncx/TeamFinance) ve vesting kilit takvimi.
4. **Katman 4 — Sinsi Kod ve Arka Kapı Avı:** `blacklist()`, `pause()`, gizli transfer vergisi (hidden fee) taraması.

### 5.2. Ticari Satış Modeli: Cryptographic Proof-of-Vulnerability (PoV)
Açık tespit edildiğinde geliştiriciye satır numarası **asla bedava söylenmez.**
* Sistem, açığı sömüren bir istismar kanıtı üretir ve bunun **kriptografik özet hash'ini ($PoV\_Hash$)** zincire basar. **(Not: bu adımı gerçekleştiren motor YOL HARİTASI — `PoV_Hash` şeması ve zincire mühürleme `ListingGate.sol`'de MEVCUTTUR, ama istismar kanıtı üreten analiz motoru henüz yok; bkz. §5 durum notu.)**
* Başvuru sahibine şu otonom bildirim gider:
  > *"Sözleşmeniz Cleanvest'in güvenlik invariantlarında 3 tanesinde KRİTİK SEVİYEDE BAŞARISIZ oldu (Fon Kaybı Riski). $PoV\_Hash$ zincirde mühürlenmiştir. Listeleme başvurunuz durdurulmuştur. Açığın istismar kodunu, düzeltme yamasını (remediation patch) ve 'Cleanvest Verified' yeşil mührünü almak için Güvenlik Paketi Bedeli: $4.900."*
* Proje açığını kapatmak ve Cleanvest'in güvenli yatırımcı kitlesine erişmek için bu bedeli öder. Cleanvest, hacimden bağımsız olarak **otonom bir siber güvenlik şirketine (SaaS)** dönüşür.

---

## 6. Red Team vs. Blue Team: 6 Kritik Patlama Noktası ve Zırhlar

| # | Patlama Alanı | 💥 Red Team Exploit Senaryosu | 🛡️ Blue Team Kriptografik Zırhı |
|---|---|---|---|
| **1** | **Solver Gizli Anlaşması (Collusion)** | RFQ toptancıları anlaşarak kullanıcılara bilerek kötü fiyat verir ve aradaki farkı paylaşır. | 🗺️ **YOL HARİTASI — ZK-Fair Price Bounds:** Oracle fiyatından %0.15 sapan teklif reddi **kodda YOK** (RFQ Solver ağı henüz inşa edilmedi). Mevcut koruma: 400ms FBA batch ile tek fiyat eşleşmesi + artık hacim `UniswapProxy`'den geçer ve AMM kayması UI'da şeffaf gösterilir. |
| **2** | **$cUSD Depeg ve İtfa Gecikmesi** | ABD Hazine piyasalarında likidite sıkışır, BlackRock BUIDL itfası 24 saat gecikir; kullanıcılar bank run yapar. | **Senior/Junior Waterfall + %10 Anlık Nakit:** İlk %10 nakit Aave/USDC havuzundan anında ödenir; olası kayıplar Junior First-Loss rezervi tarafından karşılanır. |
| **3** | **Sığ Tahta (Cold-Start Gecikmesi)** | Yeni açılan paritelerde kullanıcı sayısı az olduğu için CoW eşleşmesi 30 saniye gecikebilir. | **Kademeli Zaman Aşımı (Dynamic Fallback):** 3 saniye içinde iç eşleşme olmazsa emir otomatik olarak onaylı RFQ toptancısına yönlendirilir; gecikme engellenir. |
| **4** | **Banka On-Ramp Bloke Riski** | Bankalar döviz transferi yapan CleanFX hesaplarını "kripto işlemi" gerekçesiyle dondurur. | **Lisanslı EMI ve P2P Stablecoin Ortaklıkları:** Fonlar doğrudan borsanın hesabına değil; lisanslı Electronic Money Institution (EMI) ortaklarına ve yerel P2P takas noktalarına akar. |
| **5** | **Regülasyon ve Menkul Kıymet Baskısı** | SEC veya MiCA, "bu borsa CEX'e benziyor, lisans almalısınız" der. | **Kısmen Mevcut + 🗺️ YOL HARİTASI:** Fon emaneti **YOKTUR** — kullanıcı $cUSD / $scUSD'yi kendi cüzdanında tutar (bu kısım gerçektir). Ama "Validium Zırhı" (operatörün bakiyeye yazamaması) henüz YOK; `CleanUSD`'de owner yalnızca `seedJunior` ve koruyucu fail-closed mint-halt yetkisine sahiptir — **kullanıcı fonunu donduran `pause` ya da `blacklist` fonksiyonu YOKTUR.** |
| **6** | **Formal Doğrulama Yanılgısı (False Negatives)**| Akıllı sözleşmede AutoVerus'un invariant kurallarında tanımlanmamış sıra dışı bir mantık hatası kalır. | **Çift Motorlu Hibrit Analiz:** Z3 SMT çözücüsü sembolik olarak kanıtlarken; AegisForge 10.000 rastgele mutasyon testiyle (Mutation Testing) sözleşmeyi sarsar. |

---

## 7. Protokol Ekonomisi ve Ciro Projeksiyonu (12. Ay)

1. **Spot Takas Komisyonu:** Her başarılı işlemden **%0.08 protokol ücreti** (Sektör standardı %0.10'un altındadır).
2. **CleanFX Marjı:** Bankalararası toptan kurun üzerine eklenen **%0.10 mikro-marj** (Bankaların %2.5'luk kazığına kıyasla 25 kat daha ucuzdur).
3. **$scUSD Rezerv Yönetim Payı (Spread):** Rezerv blended getirisi (örn. Kademe 2'de ~%3.13) içinde senior yatırımcıya ~%2.92 dağıtılır; kalan spread Junior havuzunu (%3 TVL) ve protokol hazinesini besler.
   * **Rezerv getiri eğrisi v1.2 ile kilitlidir** (2026-09-24 doğrulanmış: %3.05 → %2.91 → %2.92). Eski "%5.5 faiz / %4.75 kullanıcı" modeli tamamen **silindi** (fabrikasyon).
4. **B2B Güvenlik Denetim Geliri (Faz-1 nakit motoru):** Üç kademeli fiyatlandırma ($299 / $1.490 / $4.900) ile ilk müşteriler KENDİ PORTFÖYÜMÜZ (Unpump, Tamga, KÖK + 26 proje — sıfır CAC).
   * **Dürüst hedef: $5.000 – $15.000/ay** (Faz-1). Eski "$2×$4.900×30 = $294.000/ay" fantazisi tamamen **silindi** — varsayım zinciri kanıtlanmamış.
5. **Toplam Finansal Hedef (12. Ay):** Günlük $15M spot ve FX hacmi + 100M $cUSD TVL + B2B Denetim = **Aylık $1.200.000+ Net Nakit Akışı.**
   * 🔴 **HENÜZ KANITLANMAMIŞ — 0 gerçek müşteri, $0 gerçek gelir.** Bu bir *hedef*tir, bir sonuç DEĞİL. Ürün henüz mainnet'te DEĞİL (anvil testnet kanıtı hariç); hacim, TVL ve denetim gelirlerinin hepsi **varsayıma dayalı bir projeksiyondur**. Hiçbir müşteriye "aylık $1.2M gelir" olarak **sunulamaz**. Gerçek durum: protokol hazinesi **$0 işlem geliri** ile başlar.
6. **HITL Seviyesi (DÜRÜST DÜZELTME):** Eski "%0 (Tamamen Otonom Hibrit Akıllı Sözleşmeler ve ZK-Rollup)" iddiası **gerçek DEĞİLDİ.** Mevcut üründe **ZK-Rollup YOKTUR** ve operatöre **BAĞIMLIDIR**: (i) PQHaven köprüsü tek owner EOA'dan geçer (Zayıf Yön #1); (ii) `depositReserve` bir muhasebe kaydıdır — fonların Aave'e gerçekten gitmesi operatörün `supplyToAave()` disiplinine bağlıdır (Zayıf Yön #2); (iii) köprü + Aave getiri hazinede birikir, **müşteriye gitmez** (Zayıf Yön #3). %0 otonomi ve Validium / ZK settlement **2027 Q1 yol haritasıdır.**
