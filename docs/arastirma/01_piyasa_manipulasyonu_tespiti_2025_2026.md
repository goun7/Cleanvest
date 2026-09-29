# Piyasa Manipülasyonu Tespiti — Akademik Araştırma (2025-2026)

**Tarih:** 2026-09-29
**Amaç:** Cleanvest'in "sıfır manipülasyon" iddiasının akademik zeminini güncel (2025-2026) makalelerle ortaya koymak.
**Aranan kaynaklar:** arXiv (export.arxiv.org API + doğrudan `arxiv.org/abs/<id>` sayfaları); `abs:"market manipulation"`, `abs:"wash trading"`, `abs:"spoofing"` sorguları — q-fin.TR, q-fin.ST, q-fin.RM, cs.CR, cs.AI, cs.LG, cs.HC kategorilerinde, gönderim tarihine göre azalan sıralamada.
**Doğrulama yöntemi:** Her kaynak hem arXiv API'sinden hem de doğrudan `arxiv.org/abs/<id>` sayfasından fetch edilerek teyit edildi.

## Özet

2025-2026'da kripto piyasa manipülasyonu araştırması belirgin bir dönüm noktası yaşıyor: (1) wash trading ve pump-and-dump artık tek tek cüzdanlardan ziyade **yapısal, hizmet olarak satın alınabilir (Manipulation-as-a-Service)** bir endüstri olarak inceleniyor; (2) **birleşimsel/çok-boyutlu** (complexity measures, multifraktal, davranışsal iz) tespit yöntemleri, tekil kural-tabanlı eşiklerin yerini alıyor; (3) manipülasyon tespiti yalnızca fiyat verisinde değil, **işlem sayısı/hacim orantısızlığı** gibi örtük kanallarda aranıyor; (4) sömürü, borsa arayüzünü atlayıp doğrudan blockchain ile etkileşime giren otomasyonlara kayıyor. Cleanvest için doğrudan sonuç: manipülasyon tespiti "bir kural" değil, **sürekli, çok-sinyalli bir denetim kategorisidir** ve zincir-üstü taahhüt (Merkle kökü) ancak off-chain davranışsal denetimle birleştiğinde anlamlı olur.

## İncelenen Kaynaklar (fetch ile doğrulandı)

### 1. Meme Coin Factories: Uncovering Large-Scale Manipulations on pump.fun
- **Yazarlar:** Nicolas Szwajcok, Taro Tsuchiya, Enze Liu, Kyle Soska, Mathias Payer, Nicolas Christin
- **Yıl / Yer:** 2026 / Proceedings of the 2026 ACM SIGSAC Conference on Computer and Communications Security (CCS'26)
- **URL:** https://arxiv.org/abs/2609.10246
- **Doğrulama:** web_fetch ile okundu — 2026-09-29 (hem API hem abs sayfası)
- **İçerik (okunan özet):** Son iki yılda launchpad'lerde oluşturulan **15 milyon coin'i** analiz ediyor. Beş manipülasyon sınıfı tanımlıyor: (1) wash trading, (2) creator address obfuscation, (3) coordinated sell, (4) copycat coins, (5) social media manipulation. Stratejik aktörlerin platform arayüzünü atladığını ve manipülasyonları doğrudan blockchain ile yüksek otomasyonla yaptığını; ayrıca **"Market-Manipulation-as-a-Service" (MMaaS)** adında, teknik uzmanlık gerektirmeden manipülasyon sağlayan üçüncü-parti araçların varlığını ortaya koyuyor.
- **Cleanvest ile ilgisi:** Manipülasyon artık "içeriden biri" değil, **dışarıdan satın alınabilen bir hizmet**. Bu, Cleanvest'in kendi operatörlerini denetlemesinin yetmeyeceği anlamına gelir — manipülasyon karşıtı tasarım, kullanıcı tarafında da çalışmalı (imzalı emirler, kullanıcı onayı).

### 2. Detecting unusual trading patterns on cryptocurrency exchanges by means of complexity measures
- **Yazarlar:** Jakub Zwydak, Marcin Wątorek, Jarosław Kwapień, Stanisław Drożdż
- **Yıl / Yer:** 2026 / Entropy 2026, 28(7), 804 (DOI: 10.3390/e28070804)
- **URL:** https://arxiv.org/abs/2607.13916
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** BTC, ETH, XRP'nin Binance, Bitget, KuCoin, Kraken'deki 1 Nisan–30 Haziran 2025 verisinde log-getiri, hacim ve işlem sayısı üzerinden kuyruk dağılımları, otokorelasyon, multifraktal özellikler, approximate entropy ve detrended çapraz-korelasyon ölçüyor. **Bitget'te BTC ve ETH için Mayıs 2025 ortasından itibaren belirgin bir anomali** buluyor: işlem sayısı keskin artarken hacim veya getiri dalgalanması orantılı artmıyor — düşük hacimli sayısız işlem, zayıf otokorelasyon, azalmış multifraktal organizasyon. Yazarlar bunun yapay işlem sayısıyla tutarlı olduğunu, ancak **wash trading kanıtı olmadığını** açıkça belirtiyor (önemli bir dürüstlük örneği).
- **Cleanvest ile ilgisi:** "İşlem sayısı ↑ ama hacim = sabit" ayrımı, Cleanvest'in batch settlement'ında **doğrudan tespit edilebilir bir imzadır**: executeBatchSettlement'in `totalVolume`'u, çözülen işlem sayısıyla orantısızsa aynı analizi zincir-üstü veriden kurmak mümkündür. Bu, gerçek bir denetim hook'u noktasıdır.

### 3. ManiScope: LLM-Assisted Visual Analytics of Cryptocurrency Manipulation Risk
- **Yazarlar:** Xiaolin Wen, Feng Liang, Yuanye Ma, Qishuang Fu, Zhengyu Sun, Feng Zhu, Can Liu, Yong Wang
- **Yıl / Yer:** 2026 / arXiv preprint (cs.HC)
- **URL:** https://arxiv.org/abs/2607.11451
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** Wash trading gibi işlem-tabanlı manipülasyon riskini analiz eden LLM destekli görsel analiz sistemi. Token dağılımı, holder ilişkileri, holder davranışları, fiyat dinamiği ve şüpheli işlem örüntülerini eşgüdümlü görünümlerde sunar; LLM'u "tepkili asistan" değil, kullanıcının hipotezlerini çıkaran **co-analyst** olarak konumlandırır. 12 deneyimli kripto uygulayıcısıyla kullanıcı çalışması yapılmıştır.
- **Cleanvest ile ilgisi:** Manipülasyon denetiminin nihai tüketicisi **insandır**; araç, kanıtı insanın yargısına sunar. Bu, Cleanvest'in "insan kararı" felsefesiyle uyumlu — otomatik tespit, insanı ikame etmez.

### 4. MELT: A Behavioral Trace Dataset for High-Risk Memecoin Launch Detection
- **Yazarlar:** Sihao Hu, Selim Furkan Tekin, Yichang Xu, Ling Liu
- **Yıl / Yer:** 2026 / arXiv preprint (cs.CR, cs.LG) — ilk gönderim 2026-02-13
- **URL:** https://arxiv.org/abs/2602.13480
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** Solana'da 41.000+ memecoin launch'ını 200M+ işlemle **davranışsal izlere** (swap, wash trade, transfer, mint) ayırır. Bundle-trace verisi aynı varlığın kontrol ettiği hesapları bağlar ve ortalama **%36.5 token arzının koordine hesaplarda** olduğunu ortaya koyar. 122 davranışsal öznitelik ve risk etiketiyle gözetimli öğrenmeyi mümkün kılar.
- **Cleanvest ile ilgisi:** "Koordineli hesapların arzdaki yoğunlaşması" ölçümü, Cleanvest'in listeleme kapısı (ListingGate) için somut bir risk metriği olarak kullanılabilir.

### 5. DeFiFusion: Combining Transaction Events with Smart Contracts to Detect Price Manipulation Attacks
- **Yazarlar:** Rui Cao, Shaojing Fan, Liming Fang, Yuchan Liu, Yingying Jiao, Zhenguang Liu
- **Yıl / Yer:** 2026 / arXiv preprint (cs.CR)
- **URL:** https://arxiv.org/abs/2609.11008
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** Price Manipulation Attack (PMA) tespiti için **çift-modal** bir framework: işlem olayları ile akıllı kontrat semantiğini tek bir boruda birleştirir. Temel içgörü: PMA'nın kötülüğü yalnızca işlem davranışından veya yalnızca kontrat mantığından çıkmaz — **ikisinin etkileşiminden** doğar. 225 PMA vakasının 222'sini hatırlar, %96.10 kesinlikle.
- **Cleanvest ile ilgisi:** Temel içgörü Cleanvest için kritik: "sıfır manipülasyon" iddiası yalnızca kontrat kodu (on-chain) incelenerek **kanıtlanamaz** — işlem davranışı ile birlikte değerlendirilmelidir. Bu, off-chain Merkle üreticisi + on-chain doğrulama mimarisinin neden bir arada olması gerektiğini açıklar.

### 6. Velocity- and Regime-Aware Detection of Intraday Options Market Manipulation, with Explainable Attribution
- **Yazarlar:** Alex Chen, Maria Hybinette
- **Yıl / Yer:** 2026 / arXiv preprint (q-fin.TR; cs.LG; q-fin.ST) — 5 Ağustos 2026
- **URL:** https://arxiv.org/abs/2608.05373
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** Intraday manipülasyonun neden zor tespit edildiğini açıklar: iz kısa sürelidir, milyonlarca quote içinde gömülüdür ve sıradan volatiliteye istatistiksel olarak benzer. Detektörler yüksek recall'e yalnızca o kadar çok günü "şüpheli" işaretleyerek ulaşır ki precision çöker ve "hiçbir regülatörün harekete geçemeyeceği" uyarılar üretir. Çözüm: manipülasyonun piyasa durumunun **seviyesinde değil hızı**nda (velocity) görünen bir "pump-and-crash" dinamik imzası bırakması. Dakika-seviyeli, zamanca katı bölünmüş bir tespit boru hattı (smoothed state velocity: endeks opsiyonları için Delta hızı, hisseler için fiyat hızı); her uyarı SHAP attribution ile açıklanır; test periyodu tamamen out-of-sample ve tüm eşikler değerlendirmeden ÖNCE sabitlenir. Kilitli Indian BANKNIFTY testinde düz autoencoder, regülatörün tanımladığı 10 manipülasyon gününün 10'unu bulur; ancak closed-world varsayımı altında precision ~%25'te kalır. HMM ile rejim koşullaması bir "eğitici negatif sonuç" verir (recall'i precision'a satar). Aynı dinamik ABD hisselerine (SEC v. Patel) transfer olur — imzanın **şekli** geçer, hızın **büyüklüğü** olmaz. Pump-reversal şekil skoru AUC 0.91 (ARQQ) / 0.81 (ACY). Onaylanmamış uyarıların SHAP attribution profili, regülatör günleriyle 0.99 kosinüs benzerliği taşır; yazarlar precision tavanının "detektör hatasından ziyade eksik yaptırım etiketleriyle" tutarlı olduğunu belirtir.
- **Cleanvest ile ilgisi:** Cleanvest'in **risk skoru = inceleme sinyali, kanıt değildir** tasarımını doğrular: precision/recall dengesi gerçek bir constraint'tir ve eşiklerin değerlendirmeden önce sabitlenmesi bir disiplindir. Hız-hassasiyetli imza, Cleanvest'in batch'ler arası `volumePerTx` değişimine dayanan sinyaliyle aynı felsefeyi paylaşır (seviye değil, değişim hızı).

### 7. A Clustering-Based Framework for Identifying Suspicious Trading Patterns in Capital Market
- **Yazarlar:** Asif Zaman, Romona Magdalene Sarkar, Sabiha Khair Ohi, Iftekharul Mobin
- **Yıl / Yer:** 2026 / IEEE QPAIN 2026 (2nd Int. Conference on Quantum Photonics, Artificial Intelligence & Networking) — arXiv preprint (cs.AI; cs.LG), 5 Temmuz 2026
- **URL:** https://arxiv.org/abs/2607.04184
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** Gözetimsiz K-Means++ kümeleme tabanlı bir fraud-detection araç seti; 2012–2024'e ait ~1 milyon finansal işlem üzerinde. Sonuç: işlemlerin **%2.02'si şüpheli** işaretlenir ve bunların **%51.10'u spoofing**, %0.10'u pump-and-dump, %0.55'i insider trading, %1.43'ü fake breakout, %46.83'ü ise sınıflandırılamamıştır. Ground truth olmamasına rağmen model Silhouette Score 0.561 ile doğrulanır.
- **Cleanvest ile ilgisi:** **Spoofing tespiti** için somut 2026 çerçevesi — bu doc'un "Boşluklar" bölümünde not edilen spoofing literatür boşluğunu doldurur. Ayrıca iki ders: (1) ground truth eksikliğinde bile **kümeleme + uzman heuristic eşikleri** çalışan bir yaklaşımdır (Cleanvest'in sabit-kodlu eşikleriyle paralel); (2) işaretlenenlerin **%46.83'ünün sınıflandırılamaması**, otomatik tespitin sınırlarını dürüstçe kabul etmenin gerçek bir örneğidir.

### 8. Early Rug Pull Warning for BSC Meme Tokens via Multi-Granularity Wash-Trading Pattern Profiling
- **Yazarlar:** Dingding Cao, Bianbian Jiao, Jingzong Yang, Yujing Zhong, Wei Yang
- **Yıl / Yer:** 2026 / arXiv preprint (cs.AI; cs.CR; cs.LG) — 14 Mart 2026
- **URL:** https://arxiv.org/abs/2603.13830
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** BSC meme token'leri için uçtan-uca rug-pull erken-uyarı çerçevesi (veri etiketleme → wash-trading öznitelik modelleme → risk tahmini → hata analizi). **Üç wash-trading örüntüsü** etrafında 12 token-seviyesi davranışsal öznitelik: **Self** (kendi-kendine), **Matched** (eşleşmiş) ve **Circular** (döngüsel) — işlem-, adres- ve akış-seviyesi sinyalleri tekil risk vektöründe birleştirir. Zayıf gözetim altında Random Forest, Logistic Regression'ı geçer: AUC=0.9098, PR-AUC=0.9185, F1=0.7429. Ablation: işlem-seviyesi öznitelikler ana performans sürücüsü (çıkarılınca PR-AUC −0.1843), adres-seviyesi öznitelikler istikrarlı tamamlayıcıdır. Ortalama **Lead Time 3.81 saat**. Hata profili (FP=1, FN=8) sonucu yazarlar sistemi "yüksek-recall otomatik alarm motoru" olarak değil, **yüksek-precision bir ELEK** olarak konumlandırır.
- **Cleanvest ile ilgisi:** Wash tradingin **üç yapısının** (Self / Matched / Circular) sınıflandırılması, Cleanvest'in `roundTrip` (A→B→A) sinyaliyle doğrudan örtüşür — "Matched" ve "Circular" örüntüleri zincir-üstü işlem çiftlerinden okunabilir. Daha da önemlisi: **"yüksek-precision eleme, otomatik alarm değil"** sonucu, Cleanvest'in `detectionEnforced` ile risk>70 reddetmesine rağmen nihai yargıyı insanda bırakmasının akademik doğrulamasıdır (bkz. `docs/29_INSAN_KARARLARI.md`).

### 9. Fraud Detection in Cryptocurrency Markets with Spatio-Temporal Graph Neural Networks
- **Yazarlar:** Lidia Losavio, Luca Persia, Madan Sathe, Dimosthenis Pasadakis
- **Yıl / Yer:** 2026 / SDS2026 — IEEE Swiss Conference on Data Science and AI; arXiv preprint (cs.LG; cs.CE), 27 Nisan 2026
- **URL:** https://arxiv.org/abs/2604.24590
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** Mevcut tespit yöntemlerinin eksikliğini şöyle koyar: her varlığı (token) ve ilgili işlemleri **bağımsız** ele alırlar; oysa manipülasyon stratejileri nadiren izole olaylardır — **koordinasyon, tekrar ve ilgili varlıklar arası sık transfer** ile karakterizedir. İlişkisel yapı sinyalin ayrılmaz bir parçasıdır ve grafiklerle temsil edilebilir. Üç graf inşa yöntemi (agregat saatlik piyasa verisi); attention-tabanlı uzaysal toplama + temporal Transformer kodlamasını birleştiren birleşik spatio-temporal GNN. Üç yıldan fazla pump-and-dump şemasını içeren gerçek veri setinde değerlendirilir; standart ML baseline'larına karşı anlamlı iyileşme. "Öğrenilmiş piyasa bağlantısı, koordine manipülasyon şemalarını tespit etmede önemli kazançlar sağlar."
- **Cleanvest ile ilgisi:** "Manipülasyon izole değil, **koordine ve tekrarlıdır**" bulgusu Cleanvest'in çift-seviyesi (pair-level) sinyallerinin temelini doğrular: aynı adres çiftinin batch içindeki tekrarı (`pairFlooding`) ve hacim payı (`roundTrip`) tam da "tekrar ve koordinasyon"un ölçümüdür. Ayrıca Cleanvest'in tek-batch içi bakışına, **batch'ler arası** (cross-batch) koordinasyon analizi için bir yol haritası sunar (gelecek çalışma).

### 10. TraderBench: How Robust Are AI Agents in Adversarial Capital Markets?
- **Yazarlar:** Xiaochuang Yuan, Hui Xu, Silvia Xu, Cui Zou, Jing Xiong
- **Yıl / Yer:** 2026 / arXiv preprint (cs.AI) — 27 Şubat 2026; Agents in the Wild Workshop, ICLR 2026
- **URL:** https://arxiv.org/abs/2603.00285
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** Finansta AI ajanlarını değerlendirmek için benchmark. İki zorluğa çözüm: statik benchmarklar pahalı uzman etiketlemesi ister ve gerçek dinamik ticaret kararlarını kaçırır; LLM-tabanlı judge'lar ise alan-özel görevlerde kontrolsüz varyans yaratır. TraderBench, uzman-doğrulanmış statik görevleri (bilgi erişimi, analitik akıl yürütme) ve **yalnızca realize edilmiş performansla** (Sharpe oranı, getiri, drawdown) skorlanan adversarial ticaret simülasyonlarını birleştirir — judge varyansını tamamen eler. İki yeni parçadan biri: **dört aşamalı piyasa-manipülasyon dönüşümüyle** kripto ticareti. 13 model (8B açık-kaynaktan frontier'e) ~50 görevde sınanır: (1) 13 modelin 8'i kripto'da ~33 puan alır ve adversarial koşullar arasında **<1 puan** değişim gösterir → sabit, uyarlanamayan stratejiler; (2) extended thinking bilgi erişiminde +26 puan yardım eder ama ticarete **sıfır** etki yapar.
- **Cleanvest ile ilgisi:** "**Dört aşamalı manipülasyon dönüşümü**", Cleanvest'in kendi **tahrir (evasion) testleri** için bir metodolojidir: bir tespit katmanı, manipülasyonun giderek artan/şiddetlenen biçimlerine karşı sınavdan geçirilmelidir (`testEvasionVolumeMaskedStillCaught` bu felsefenin ilk adımıdır). Ayrıca manipülasyonun otomatik ajanlarca yapılması (kaynak #1'in "Manipulation-as-a-Service" bulgusu) durumunda piyasa katılımcılarının ne kadar hazırlıksız olduğu quantifiye edilmiştir.

## Cleanvest'e Uygulanabilirlik

**Doğrudan desteklenen yönler:**
- İmzalı emir Merkle ağacı (EIP-191 + leaf hash), manipülasyon-as-a-service dünyasında **kullanıcı rızasını zincire taşır**: operatör doldursa bile yaprak geçersiz imzayla kabul edilmez (Rust `build_signed` fail-closed).
- Batch'te `totalVolume`'un işlem sayısıyla orantısızlığı (kaynak #2'nin yöntemi) zincir-üstü ham veriden hesaplanabilir bir denetim sinyalidir.
- Çift-modal gereklilik (kaynak #5): Cleanvest'in iddiası kod + davranış birlikte değerlendirilerek ancak geçerli olur.

**Şu an eksik / eklenmesi gerekenler (dürüst):**
- **Zincir-üstü tespim KATMANI artık var** (2026-09-29, `contracts/ManipulationDetector.sol` + `test/AntiManipulation.t.sol`): kaynak #2 (hacim/işlem düşüşü), #7 (spoofing sınıflandırma), #8 (wash-trading örüntüleri) ve #9 (koordinasyon/tekrar)dan beslenen **üç sinyal** zincir-üstü veriden hesaplanır — round-trip payı, çift seli, hacim/işlem düşüşü → 0–100 **risk skoru**. **Ancak bu bir HEURİSTİKTİR, manipülasyon KANITI değildir**; kaynak #2'nin kendi uyarısı ve kaynak #6'nın precision tavanı (~%25) bulgusu, yüksek skorun "inceleme gerektiren sinyal" olarak kalmasını gerekli kılar. Batch'ler-arası (cross-batch) koordinasyon analizi (kaynak #9) hâlâ implemente EDİLMEMİŞTİR — gelecek çalışmadır.
- Kaynak #2'nin bulgusu **kanıt değil şüphe** üretir; yazarların kendi uyarısıdır. Cleanvest de benzer bir ayrımı belirtmek zorundadır.

## Boşluklar / Açık Sorular

- **Spoofing/layering** için bu doc'un ilk sürümünde crypto-özel akademik makale aramamız dar sonuç döndürmüştü; 2026-09-29 güncellemesinde **kaynak #7** (arXiv:2607.04184) bu boşluğu kısmen doldurdu — ~1M işlemde şüphelilerin **%51.10'unu spoofing** olarak sınıflandırıyor. Ancak hâlâ **sermaye-piyasası** (crypto değil) odaklıdır ve crypto-özel spoofing/layering literatürü geleneksel piyasa microyapısı (q-fin.TR) ve case-law'da yoğunlaşmaya devam etmektedir. Eksiklik dürüstçe kaydedilmiştir.
- Tespit yöntemlerinin çoğu **post-hoc ölçüm**dır; "önleme" ile "tespit etme" arasındaki fark tasarım açısından büyüktür (önleme için bkz. `02_mev_ve_front_run_koruma_2025_2026.md`).
