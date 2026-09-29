# Piyasa Manipülasyonu Tespiti — Akademik Araştırma (2025-2026)

**Tarih:** 2026-09-29
**Amaç:** Cleanvest'in "sıfır manipülasyon" iddiasının akademik zeminini güncel (2025-2026) makalelerle ortaya koymak.
**Aranan kaynaklar:** arXiv (export.arxiv.org API + doğrudan abs sayfaları), q-fin.TR, q-fin.ST, cs.CR kategorileri.
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

## Cleanvest'e Uygulanabilirlik

**Doğrudan desteklenen yönler:**
- İmzalı emir Merkle ağacı (EIP-191 + leaf hash), manipülasyon-as-a-service dünyasında **kullanıcı rızasını zincire taşır**: operatör doldursa bile yaprak geçersiz imzayla kabul edilmez (Rust `build_signed` fail-closed).
- Batch'te `totalVolume`'un işlem sayısıyla orantısızlığı (kaynak #2'nin yöntemi) zincir-üstü ham veriden hesaplanabilir bir denetim sinyalidir.
- Çift-modal gereklilik (kaynak #5): Cleanvest'in iddiası kod + davranış birlikte değerlendirilerek ancak geçerli olur.

**Şu an eksik / eklenmesi gerekenler (dürüst):**
- Cleanvest'in kendisinde **otomatik wash-trade tespiti yoktur** — akademik yöntemler (complexity measures, davranışsal iz) birer **yol haritası** sunar, kodda implemente edilmemiştir.
- Kaynak #2'nin bulgusu **kanıt değil şüphe** üretir; yazarların kendi uyarısıdır. Cleanvest de benzer bir ayrımı belirtmek zorundadır.

## Boşluklar / Açık Sorular

- **Spoofing/layering** için 2025-2026 crypto-özel akademik makale aramamız dar sonuç döndürdü (`spoofing` + `financial market` sorgusu cs.CR'de 0 sonuç); bu alandaki güncel literatür daha çok geleneksel piyasa microyapısında (q-fin.TR) ve case-law'da yoğunlaşmaktadır. Eksiklik dürüstçe kaydedilmiştir.
- Tespit yöntemlerinin çoğu **post-hoc ölçüm**dır; "önleme" ile "tespit etme" arasındaki fark tasarım açısından büyüktür (önleme için bkz. `02_mev_ve_front_run_koruma_2025_2026.md`).
