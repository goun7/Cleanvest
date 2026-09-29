# MEV ve Front-Run Koruması — Akademik Araştırma (2025-2026)

**Tarih:** 2026-09-29
**Amaç:** Cleanvest'in front-run / race kalkanı olan `orderCommitmentRoot` (Merkle taahhüt) tasarımının güncel MEV literatüründeki yerini belirlemek.
**Aranan kaynaklar:** arXiv (export.arxiv.org API + abs sayfaları), cs.CR, cs.GT, q-fin.TR.
**Doğrulama yöntemi:** Her kaynak arXiv API'sinden ve doğrudan `arxiv.org/abs/<id>` sayfasından fetch edilerek teyit edildi.

## Özet

2025-2026 MEV araştırmasında üç eğilim öne çıkıyor: (1) **Savunma, "gizleme"den "kurallı gecikme"ye kayıyor** — özel/şifreli mempool'ların neyi gizlemesi gerektiği artık **tam karakterize edilmiş** durumda (sandwich için "boyut alt-sınırı" kritik, "üst sınırı" irrelevant); (2) **saldırı otomatikleşiyor** — otonom çok-ajan sistemleri yeni MEV varyantlarını keşfedip zincirler arası taşıyabiliyor; bu, savunmayı statik kurallara bırakmamayı zorunlu kılıyor; (3) **front-running direnci için resmi bir tanım** ortaya çıktı — bir kontratın tek başına "front-run dirençli" olamayacağı, **dürüst kullanıcıların nasıl etkileştiğine** bağlı olduğu kanıtlandı. Cleanvest'in `T_BATCH_MS = 400ms` batch netting + `orderCommitmentRoot` mimarisi, eğilim (1) ve (3) ile aynı yöndedir: batch öncesi emirleri taahhüt altına alarak, sıralama adaletsizliğini sıfır-zamanlı sömürüden uzaklaştırır.

## İncelenen Kaynaklar (fetch ile doğrulandı)

### 1. How Much Must a Private Mempool Hide? Exact Leakage Thresholds for Sandwich Attacks
- **Yazarlar:** Tingyi Lin, Jiazhuo Li, Ruoran Lai
- **Yıl / Yer:** 2026 / Accepted to NeurIPS 2026 (arXiv:2609.31379)
- **URL:** https://arxiv.org/abs/2609.31379
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** Özel/şifreli mempool'ların sandwich'i önlemek için **tam olarak ne kadar gizlemesi gerektiğini** hesaplar. Fee-free constant-product AMM (Uniswap v2) için cevap: sandwich kârlılığını yalnızca **sızıntılan boyutun en küçük tutarlı değeri** belirler; en büyük uygulanabilir front-run hem pointwise, hem beklenen, hem worst-case kâr için optimaldir ve **kapalı formda** garantili kâr verir. Sonuç: bir gizlilik katmanı, her tutarlı boyutta kârsız sandwich'i garantilemek istiyorsa boyut hakkında **belirli bir eşiğin üstünde bir alt sınır dışında her şeyi** açıklayabilir; aralığın üst ucu **ilgili değildir**. Yön de gizliyse, hiçbir non-contingent ilk bacak her iki yönü de front-runleyemez.
- **Cleanvest ile ilgisi:** Cleanvest emirleri batch içinde **tamamen off-chain** toplar ve yalnızca kökü zincire yazar; emrin bireysel boyutu zincirde görünmez. Bu makale, bu tasarımın sandwich için **ne kadar değerli** olduğunu tam olarak karakterize ediyor: "alt sınır gizliliği" sağlanır.

### 2. Slow and Steady: Preventing MEV with Verifiable Delays
- **Yazarlar:** Zeta Avarikioti, Dimitris Karakostas, Karl Kreder, Shreekara Shastry
- **Yıl / Yer:** 2026 / 10th International Workshop on Cryptocurrencies and Blockchain Technology (CBT 2026)
- **URL:** https://arxiv.org/abs/2608.13271
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** İşlem üretiminde **doğrulanabilir bir gecikme** zorlayarak MEV'yi önleyen bir savunma mekanizması: blok oluşturucusu, liveness'i bozmadan bir MEV fırsatının ortaya çıkmasına **reaksiyon veremez** hale gelir. Hem Byzantine hem de rasyonel katılımcı oyun-teorik modelinde pozitif sonuçlar; ayrıca bu savunma hattının **sınırlarını gösteren negatif sınırlar** da verir. Tarihsel MEV verisine dayanarak mekanizmanın mevcut MEV tehditlerinin çoğunu gerçekçi olarak önleyebileceğini öne sürer.
- **Cleanvest ile ilgisi:** Cleanvest'in `T_BATCH_MS = 400ms` batch gecikmesi aynı felsefenin **protokol-seviyesi bir uygulamasıdır**: emirler bir batch'e kilitlenir ve kök zincire yazıldıktan sonra yeniden sıralanamaz. Zamanlama, sıralama sömürüsünü yapısal olarak geciktürür.

### 3. On Identifying Sound Conditions for Frontrunning Resistance
- **Yazarlar:** Sebastian Holler, Anna Piscitelli, Jannik Albrecht, Stephan Dübler, Ghassan Karame, Clara Schneidewind
- **Yıl / Yer:** 2026 / Accepted for CCS 2026 (arXiv:2609.11535)
- **URL:** https://arxiv.org/abs/2609.11535
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** **İlk resmi front-running güvenlik açığı tanımını** ortaya koyar. Kritik içgörü: front-run direnci bir kontratın **tek başına** bir özelliği değildir; **dürüst kullanıcıların onunla nasıl etkileştiğine** bağlıdır. Büyük çaplı bir incelemede (287 akıllı kontrat denetimi) önde gelen denetçilerin raporladığı **393 güvenlik açığının %55'i** en son detection criteria'nın kapsamı **dışında**dır — mevcut dinamik tespit yaklaşımları temelde yetersizdir. Güvenli etkileşim koşulları sentezleyen bir algoritma + prototip ile denetlenmiş gerçek kontratlarda **daha önce bilinmeyen** iki Ethereum güvenlik açığı bulunur.
- **Cleanvest ile ilgisi:** Bu makale, "kontratı denetledik, front-run yok" denemeyeceğini kanıtlar: **kullanıcı etkileşim modeli** de doğrulanmalı. Cleanvest'in imzalı emir + nonce + batch kilit mimarisi, etkileşim koşullarını protokolde sabitler — bu, makalenin aradığı "sound conditions" yaklaşımıyla örtüşür.

### 4. EVAGE: Autonomous MEV Generation and Adaptation via Multi-Agent Harness
- **Yazarlar:** Yan Wen, Zichun Cai, Iliya Mirzaei, Xiaohua Cai, Mohammad Javad Amiri, Haoxian Chen, Chenyuan Wu
- **Yıl / Yer:** 2026 / arXiv preprint (cs.CR)
- **URL:** https://arxiv.org/abs/2609.27424
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** Uçtan uca MEV strateji üretimi ve adaptasyonu için **ilk tam otonom çok-ajan framework**. Ethereum, Base ve BSC'de 1.5M+ blok üzerinde değerlendirilir; Ethereum'da **5 yeni MEV varyantı** keşfeder (kârda 1.02×–15.97× artış), 11 stratejiyi CPMM'den CLMM ve Balancer V2'ye uyarlar ve Ethereum'dan Base/BSC'ye taşır — toplam LLM token maliyeti **$60'dan az**.
- **Cleanvest ile ilgisi:** Saldırı tarafının maliyeti **onlarca dolar**. Savunma bunun karşısında tek seferlik denetimle kalamaz; sürekli ve **protokol-içi** (invariant) olmalı. Cleanvest için somut risk: Base'de (hedef ağ) MEV otomasyonu ucuz ve aktiftir.

### 5. There Will Be Spam: Characterizing State-Invariant Transactions and Speculative MEV
- **Yazarlar:** Vabuk Pahari, Johnnatan Messias, Christof Ferreira Torres
- **Yıl / Yer:** 2026 / arXiv preprint (cs.CR)
- **URL:** https://arxiv.org/abs/2607.24172
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** State-invariant transaction (sonuç durumunu yalnızca fee'den etkileyen işlem) kavramını tanımlar; Ethereum, Optimism ve Base'de **1.4 milyar** böyle işlem bulur. Ethereum işlemlerinin yalnızca %2.6'sı state-invariant iken **Optimism'de %24, Base'de %37**'dir. **Speculative MEV**, Optimism'de bunların %57'sinin, Base'de **%68**'inin baskın kaynağıdır. Ayrıca Ethereum'da address-poisoning kampanyaları state-invariant işlemlerin %53'ünü oluşturur.
- **Cleanvest ile ilgisi:** Cleanvest hedef ağ olarak **Base**'i planlar (bkz. `addresses.json`/deploy rehberi). Bu makale, Base'de zincir kaynaklarının ~üçte birinin speculative MEV kaynaklı olduğunu gösterir — batch settlement tasarımı bu spam trafiğini **doğrudan hedef almaz**, ancak gas maliyeti ve mempool davranışı modellenirken dikkate alınmalıdır.

### 6. When AI Agents Meet MEV: Cross-Chain Arbitrage in the Agentic Economy
- **Yazarlar:** Wei Ye, Jingyan Xu, Yuanhong Wu
- **Yıl / Yer:** 2026 / 7th International Conference on Mathematical Research for Blockchain Economy (MARBLE 2026)
- **URL:** https://arxiv.org/abs/2609.17897
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** Otonom AI agent'larının searcher olduğu çapraz-zincir arbitrajı inceler. Ethereum/Arbitrum/Base'de 23.000 Uniswap V3 swap olayı ile: Ethereum–Arbitrum fiyat aralığı 10sn çözünürlükte ortalama **%0.044**, Arbitrum–Base **%0.013**. Uyarlamalı yol-seçimi algoritması standart baseline'leri ortalama **%11** geçer; **orantılı rastgeleleştirme MEV maruziyetini %50'den fazla azaltır** ve yalnızca mütevazı kâr kaybı doğurur.
- **Cleanvest ile ilgisi:** "Rastgeleleştirme MEV maruziyetini yarıya indirir" — Cleanvest'in batch içinde **deterministik olmayan bir çözme sırası** (commit-then-reveal tarzı) için ampirik bir motivasyon sağlar (henüz implemente edilmemiştir; yol haritası maddesi).

## Cleanvest'e Uygulanabilirlik

**Mevcut tasarımın güncel literatürle uyumu (desteklenen):**
| Cleanvest özelliği | Literatür karşılığı | Durum |
|---|---|---|
| `orderCommitmentRoot` (Merkle taahhüt, batch öncesi) | Gizli mempool'un "alt-sınır gizliliği" (#1) | Implemente edildi |
| `T_BATCH_MS = 400ms` batch gecikmesi | Doğrulanabilir gecikme savunması (#2) | Implemente edildi (off-chain toplayıcı) |
| İmzalı emir + nonce, batch'e kilitli | Front-run direnci = etkileşim koşulu (#3) | Implemente edildi |
| Zincir-üstü kök, bireysel boyut görünmez | Sandwich için kritik sızıntı (#1) | Implemente edildi |

**Literatürün önerdiği ama Cleanvest'de OLMAYANlar (dürüst sınır):**
- **Doğrulanabilir gecikme** (#2) yalnızca off-chain 400ms'dir; **zincir-üstü** kriptografik bir gecikme/commit-reveal yoktur.
- **Batch-içi çözme sırası rastgeleleştirilmesi** (#6'nın bulgusu) — deterministik solver sırası varsayılır.
- **MEV ölçüm/dashboard'u** yoktur (#5'in bulguları izlenmiyor).
- Bu maddelerin hiçbiri iddia edilmemiştir; `README`'de "yol haritası" olarak kalmalıdır.

## Boşluklar / Açık Sorular

- Makale #1'in tam karakterizasyonu **fee-free constant-product AMM** içindir; Cleanvest batch settlement'i bir AMM değildir (uniform clearing price + RFQ solver). Sonuçlar **niteliksel** olarak transfer edilir, tam sayısal eşleşme beklenmemelidir.
- #6'nın "%50 MEV azalması" bulgusu cross-chain arbitraj bağlamındadır; Cleanvest'in tek-zincir batch'i için aynı oran geçerli değildir.
- Cleanvest'de batch'ler arası **kuyruk mimarisi** (örn. batch sınırında bekleyen emirlerin front-run edilmesi) ayrı bir saldırı yüzeyidir ve güncel makalelerde doğrudan ele alınmamıştır.
