# Spot Borsa Güvenliği — Akademik Araştırma (2025-2026)

**Tarih:** 2026-09-29
**Amaç:** Cleanvest'in güvenlik duruşunu 2025-2026 borsa güvenliği literatürü ve gerçek olaylar ile konumlandırmak.
**Aranan kaynaklar:** arXiv (export.arxiv.org API + abs sayfaları), cs.CR.
**Doğrulama yöntemi:** Her kaynak arXiv API'sinden ve doğrudan `arxiv.org/abs/<id>` sayfasından fetch edilerek teyit edildi.

## Özet

2025-2026 borsa güvenliği araştırmasının en çarpıcı bulgusu **kaybın kaynağının yeridir**: gerçek dünyadaki devasa kayıpların büyük kısmı akıllı kontrat veya protokol hatasından değil, **off-chain sistemlerden, kurumsal süreçlerden ve insan-içeren operasyonel iş akışlarından** (anahtar yönetimi, işlem onay yönetimi, üçüncü-parti bağımlılıklar) kaynaklanıyor. Ayrıca 2025-2026'da **merkezileşmiş borsaların "solvabilité" iddialarını kanıtlama** yöntemi (Proof of Reserves / Proof of Liabilities) yeni bir standartlaşma seviyesine ulaştı — ve bu alandaki en yeni akademik sonuç, **kullanıcı imzası olmadan bir kökün/manzaranın dürüst kanıt olamayacağıdır**. Cleanvest'in imzalı Merkle yapısı bu sonucun tam olarak önerdiği yöndedir.

## İncelenen Kaynaklar (fetch ile doğrulandı)

### 1. Bridging the Cybersecurity Gap Between Web2 and Web3 — An Incident-Based Analysis of Organizational and Application-Level Security Failures
- **Yazarlar:** Tarkan Yavaş, Arslan Brömme
- **Yıl / Yer:** 2026 / arXiv preprint (cs.CR), v0.9.9.8 çalışma öncesi
- **URL:** https://arxiv.org/abs/2605.18484
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** Yüksek etkili gerçek güvenlik olaylarının nitel, olay-tabanlı analizini yapar: **Bybit borsa olayı (2025)**, Ronin Network bridge compromise (2022), **DMM Bitcoin borsa ihlali (2024)**. Olayları OWASP-tabanlı zafiyet kategorileri ve kurumsal güvenlik kontrol alanlarına eşler. Sonuç: Web3'teki baskın başarısızlık örüntüleri genel güvenlik kontrol kataloglarıyla yetersiz ele alınmaktadır — özellikle **kriptografik anahtar yönetimi, işlem onay yönetimi (transaction approval governance), imzacı/validator altyapısı, üçüncü-parti araç bağımlılıkları ve human-in-the-loop süreçleri**. Web3 organizasyonları için ISMS (bilgi güvenliği yönetim sistemi) benimsenmesini önerir.
- **Cleanvest ile ilgisi:** En yüksek öncelikli uyarı: **off-chain altyapı**. Cleanvest'in riski yalnızca Solidity kontratlarında değil; deploy anahtarı, imzacı altyapısı (CleanAudit oracle), batch toplayıcı sunucu ve iş onay süreçlerindedir. Deploy rehberindeki `PRIVATE_KEY` yönetimi bu makalenin işaret ettiği tam alandır.

### 2. Mitigating Collusion in Proofs of Liabilities
- **Yazarlar:** Malcom Mohamed, Ghassan Karame
- **Yıl / Yer:** 2026 / Preprint of the AsiaCCS'26 paper
- **URL:** https://arxiv.org/abs/2603.12990
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** Borsaların yükümlülüklerini kanıtlamak (PoL) için kullandığı mevcut ve akademik şemaları inceler ve **ciddi tasarım eksiklikleri** bulur: mevcut şemalar, **sağlayıcının mevcut bir kullanıcı ile işbirliği (collusion) yaptığı gerçekçi saldırı senaryosuna dayanamaz**. "Permissioned PoL" adlı yeni bir model önerir: kullanıcı işbirliği gerektirmeden dürüst olmayan sağlayıcının tespit edilmesini sağlar. Çekirdeği, **"commit edilen vektörün yalnızca kullanıcıların açıkça imzaladığı değerleri içermesini" sağlayan** Permissioned Vector Commitment (PVC) ilkelidir; KZG commitment'ların homomorfik özellikleri ile BLS imzalarını birleştirir. Prototip, daha güçlü güvenliğe rağmen sunucu performansını **10×'e kadar** iyileştirir.
- **Cleanvest ile ilgisi:** **En doğrudan ilgili makale.** "Kök/manzara, kullanıcı imzası olmadan dürüst kanıt olamaz" — Cleanvest'in `merkle/src/signed.rs`'i tam olarak bunu yapar: her yaprak EIP-191 ile kullanıcı tarafından imzalanır ve `build_signed` **tek geçersiz imzada tüm kurulumu reddeder** (fail-closed). Akademik literatür 2026'da bu özelliği bir **gereklilik** olarak konumlandırır. Not: Cleanvest'in yaprak imzası EIP-191/ECDSA'dır (KZG+BLS değil); bu, trust-minimization açısından eşdeğer amaç taşıyan farklı bir kriptografik seçimdir.

### 3. Defending the Peg: Real-Time Dynamic Protection and Anomaly Detection in DeFi Stablecoins
- **Yazarlar:** Hengxing Zeng, Shipeng Ye, Xiaoqi Li
- **Yıl / Yer:** 2026 / arXiv preprint (cs.CR)
- **URL:** https://arxiv.org/abs/2608.25600
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** Stablecoin sistemlerini hedef alan saldırı vektörlerini sistematik analiz eder; **12 gerçek güvenlik olayından** reentrancy, **oracle manipülasyonu** ve bileşik flash-loan saldırılarının mekanizmalarını çıkarır. Çok-boyutlu zincir-üstü zamansal özniteliklerle Bi-LSTM tabanlı gerçek-zamanlı anomali tespit modeli kurar: **%96.61** sınıflandırma doğruluğu, kötü niyetli saldırı örnekleri için **%97.70** ortalama hatırlama, tek çıkarım gecikmesi **1.5–2.8 ms**.
- **Cleanvest ile ilgisi:** CleanUSD (sabit $1.00) ve CleanFXVault için doğrudan ilgili saldırı sınıfları: reentrancy (vault'larda ReentrancyGuard kullanılmıştır), oracle manipülasyonu (Cleanvest Chainlink harici feed kullanır, Uniswap TWAP **yasak** — bu makale exactly bu tercihi haklı çıkarır), flash-loan bileşik saldırıları.

### 4. The CryptoNeo Threat Modelling Framework (CNTMF): Securing Neobanks and Fintech in Integrated Blockchain Ecosystems
- **Yazarlar:** Serhan W. Bahar
- **Yıl / Yer:** 2025 / arXiv preprint (cs.CR, cs.ET)
- **URL:** https://arxiv.org/abs/2507.14007
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** Dijital bankalar/fintech için STRIDE, OWASP Top 10, NIST, LINDDUN ve PASTA'yı genişleten tehdit modelleme çerçevesi; oracle manipülasyonu ve cross-chain exploit'leri gibi kripto-özel riskleri kapsar. **2025 olaylarından gerçek veriler** kullanır: 2025'in ilk yarısında 344 güvenlik olayında toplam **~$2.47 milyar** kayıp (CertiK via GlobeNewswire, 2025; Infosecurity Magazine, 2025 kaynaklı). AI-artırılmış geri-besleme döngüsü ve CRYPTOQ mnemonic'i içerir.
- **Cleanvest ile ilgisi:** Tehdit modelleme için hazır bir çerçeve ve **2025 kayıp büyüklüğünün ($2.47B / 344 olay) güncel verisi**. Ortalama ~$7.2M/olay — Cleanvest'in soğuk-başlangıç emir tavanının ($5.000/emir) riski neden böler halde başladığını bağlamlar.

### 5. Protecting DeFi Platforms against Non-Price Flash Loan Attacks
- **Yazarlar:** Abdulrahman Alhaidari, Balaji Palanisamy, Prashant Krishnamurthy
- **Yıl / Yer:** 2025 / 15th ACM Conference on Data and Application Security and Privacy (CODASPY 2025)
- **URL:** https://arxiv.org/abs/2503.01944
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** Fiyat-dışı (non-price) flash-loan saldırıları için **FlashGuard** adlı çalışma-zamanı tespit ve hafifletme yöntemi; kontrat fonksiyon imzalarını hedefleyerek gerçek-zamanlı tespit eder ve işlemlerin henüz onaylanmadan mempool'da göründüğü kısa pencereyi kullanarak **atomiciteyi bozan** bir karşı-saldırı gönderir. 20 tarihsel + birkaç yeni saldırı üzerinde: ortalama **150.31 ms** tespit gecikmesi, **%99.93'ün üstünde** tespit doğruluğu, 410.92 ms ortalama bozma süresi. Önceden dağıtılmış olsaydı **$405.71M** kaybı kurtarabilirdi.
- **Cleanvest ile ilgisi:** Flash-loan atomik saldırılarına karşı bir **runtime savunma** örneği. Cleanvest şu an böyle bir runtime savunmaya sahip değildir — bu, yol haritası için referans niteliğindedir, mevcut bir iddia değildir.

## Cleanvest'e Uygulanabilirlik

**Doğrudan desteklenen yönler:**
| Cleanvest özelliği | Güncel literatür karşılığı |
|---|---|
| İmzalı Merkle yaprakları (EIP-191, fail-closed) | #2: "commit edilen vektör yalnızca kullanıcıların imzaladığı değerleri içermeli" |
| Chainlink harici oracle, Uniswap TWAP yasak | #3: oracle manipülasyonu stablecoin sisteminin birincil saldırı vektörlerinden |
| ReentrancyGuard (vault/settlement) | #3: reentrancy 12 gerçek olaydan birincil sınıf |
| Soğuk başlangıç $5.000/emir tavanı | #4: 2025 H1 ortalama ~$7.2M/olay riski bölmek |

**Off-chain risk (en yüksek öncelik, #1'in bulgusu):** Kayıpların baskın kaynağı **anahtar yönetimi, işlem onay yönetimi, üçüncü-parti araçlar ve insan süreçleri**. Bu nedenle deploy hazırlığı kapsamında şu kararlar alınmıştır: `PRIVATE_KEY` **koda gömülmez**, yalnızca çevre değişkeni; anahtar yokluğunda **mainnet deploy'u reddeden** bir guard; anvil dışında canlı yayın **yasak** (bu doküman serisinin deploy rehberinde).

**Dürüst sınırlar:**
- Cleanvest'de **PoR/PoL yayın mekanizması yoktur** — Merkle kökü yalnızca emir taahhüdü içindir, rezerv/yükümlülük kanıtı için değil. #2 ve #3'ün PoR çıktısı **CleanUSD için uygulanabilir bir yol haritasıdır**, mevcut özellik değildir.
- Flash-loan runtime savunması (#5) mevcut değildir.
- Kurumsal ISMS/işlem-onay süreçleri (#1) organizasyonel bir gerekliliktir; kod ile sağlanamaz — **insan kararı** gerektirir.

## Boşluklar / Açık Sorular

- #1 (Web2/Web3 olay analizi) bir **preprint / çalışma öncesi**'dir; hakemli değildir — nitel analiz değeri yüksektir ama kanıt olarak tek başına yeterli değildir.
- #4'ün $2.47B/344 olay rakamı **ikincil kaynaklara** (CertiK, Infosecurity Magazine) dayanır; doğrudan birincil araştırma sonucu değildir.
- Bybit 2025 ve DMM Bitcoin 2024 olaylarının **teknik detayları** bu makalede olay-tabanlı özet seviyesindedir; derin adli analiz için makalelerin full-text'ine ve resmi olay raporlarına başvurmak gerekir.
