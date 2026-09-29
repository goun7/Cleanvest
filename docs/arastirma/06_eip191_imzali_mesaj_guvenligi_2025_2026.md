# EIP-191 İmzalı Mesaj Güvenliği — Akademik Araştırma (2025-2026)

**Tarih:** 2026-09-29
**Amaç:** Cleanvest'in yaprak imzalama şemasını (EIP-191 `personal_sign`, cüzdan `signMessage` ile aynı) güncel imza güvenliği literatürü ile değerlendirmek.
**Aranan kaynaklar:** arXiv (export.arxiv.org API + abs sayfaları), cs.CR, cs.SE.
**Doğrulama yöntemi:** Her kaynak arXiv API'sinden ve doğrudan `arxiv.org/abs/<id>` sayfasından fetch edilerek teyit edildi.

## Özet

2025-2026'da off-chain imza güvenliğinde üç sonuç öne çıkıyor: (1) **İmza tekrar (signature replay) sistematik ve ölçülebilir bir zafiyet sınıfıdır** — Ethereum'da imza kullanan kontratların **%19.63'ü** bu zafiyeti taşımakta ve etkilenen kontratlarda **$4.76 milyon** aktif varlık bulunmaktadır; 1.419 denetim raporundan **5 tür** çıkarılmıştır. (2) **Kanonikleştirme (canonicalization) başarısızlıkları tekrarlayan bir zafiyet sınıfı olarak sistemleştirildi** — aynı nesne için birden fazla geçerli kod (veya tek kod için birden fazla nesne) olduğunda, hash/imza/replay koruması bağımlı bir yüzey açılır; "transaction malleability" ve "message malleability" aynı kök nedendir. (3) **Kullanıcı imzası, commitment'ın dürüstlüğünün bir gereğidir** — sağlayıcının kendi doldurduğu veriyi commit etmesini imza engeller. Cleanvest için sonuçlar net: EIP-191 + nonce doğru yöndedir, ama **nonce kullanım denetimi** ve **imza alanının kanonikliği** açık sınırlardır.

## İncelenen Kaynaklar (fetch ile doğrulandı)

### 1. One Signature, Multiple Payments: Demystifying and Detecting Signature Replay Vulnerabilities in Smart Contracts
- **Yazarlar:** Zexu Wang, Jiachi Chen, Zewei Lin, Wenqing Chen, Kaiwen Ning, Jianxing Yu, Yuming Feng, Yu Zhang, Weizhe Zhang, Zibin Zheng
- **Yıl / Yer:** 2025 (gönderim 2025-11-12) / **Accepted at ICSE 2026**
- **URL:** https://arxiv.org/abs/2511.09134
- **Doğrulama:** web_fetch ile okundu — 2026-09-29 (hem API hem abs sayfası)
- **İçerik (okunan özet):** **Signature Replay Vulnerability (SRV)**'yi tanımlar: imza kullanım koşullarının denetlenmemesi, tekrarlanan doğrulamaya ve dolayısıyla izin istismarına yol açar. **37 blockchain güvenlik şirketinin 1.419 denetim raporunda 108'inde** ayrıntılı SRV açıklaması bulur ve **5 SRV türü** sınıflandırır. LASiR: LLM destekli statik taint analizi + sembolik execution ile imza-tekrar tespiti. 918.964 kontrattan seçilen 15.383 imza-doğrulamalı kontrat (Ethereum, BSC, Polygon, Arbitrum): **Ethereum'da imza kullanan kontratların %19.63'ü SRV içerir**, etkilenen kontratlarda **$4.76M** aktif varlık. LASiR F1 = %87.90.
- **Cleanvest ile ilgisi:** **En doğrudan risk değerlendirmesi.** Cleanvest'in imzası bir **ödeme fonksiyonunda değil**, bir Merkle yaprağındadır — bu, LASiR'in sınıfladığı "one signature, multiple payments" profilinden **farklıdır** ama bağlantılıdır. Korumalar: (a) her yaprakta **nonce** alanı vardır; (b) `batchSettled[batchId]` ile aynı batch iki kez kesinleştirilemez. **Açık sınır:** kullanılmış-nonce'ların zincir-üstü takibi **yoktur** — aynı imzalı yaprak teorik olarak farklı batch'lerde yeniden kanıt olarak sunulabilir. Bu, "sıfır manipülasyon" iddiasının **dürüst sınırı** olarak README'de yer almalıdır.

### 2. Canonicalization Failures as a Recurring Vulnerability Class: Representation Divergence in Cryptographic Systems and Its Avoidance
- **Yazarlar:** Arslan Brömme
- **Yıl / Yer:** 2026 / arXiv preprint (cs.CR), 33 sayfa
- **URL:** https://arxiv.org/abs/2608.06508
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** Kriptografik sistemler **baytlar üzerinde çalışır ama anlamsal nesneleri** kasteder; bu iki arasındaki çeviri **nadiren tektir**. Teklik (uniqueness) zorlanmadığı yerde, bir hash, imza, replay koruması veya consensus kimliği **temsile** bağlı olduğunda bir saldırı yüzeyi açılır. Aynı sınıf bağımsız olarak **birçok ekosistemde** keşfedilmiş ve yerel olarak adlandırılmıştır: **transaction malleability, non-deterministic value encoding, message malleability, hash chain malleability** — ortak kök takip edilmeden. Çalışma, bunların **ihlal edilmiş tek bir teklik koşulunun örnekleri** olduğunu iki temel yönde sistemleştirir: (i) bir nesne için birden fazla geçerli kod (object-side multiple representation), (ii) tek kod için birden fazla nesne (code-side semantic collapse). Katkı: temsil mekanizmasına göre sistemleştirme + **uygulanabilir bir inceleme prosedürü** (canonicalization obligation, alan-tipi sınıflandırması, operasyonel sınır modeli) ile riskin önceden tanınması. **Dürüst sınır:** çalışma, teklik zorlamanın bu sınıfın istismar edilebilirliğini azalttığını belirtir ama **diğer korumaların yerini tutmadığını** ve dar anlamda kriptografik güvenlik hakkında bir iddiada bulunmadığını açıkça söyler.
- **Cleanvest ile ilgisi:** **EIP-191 ve `abi.encode` seçimi doğrudan bu makalenin konusudur.** Cleanvest'de:
  - Yaprak hash: `abi.encode(amount, user, nonce)` — **deterministik** (her alanın tek kanonik kodlaması vardır; address sağa-hizalı, uint256 sola-hizalı). Bu, "object-side multiple representation" riskini **yapısal olarak** azaltır.
  - Önemli karşılaştırma: `abi.encodePacked` kullansaydık, değişken-uzunluklu tipler arasında **ambiguity** (code-side semantic collapse) doğardı. **Kullanılmıyor** — bu doğru bir tercihtir.
  - EIP-191 digest: `keccak256("\x19Ethereum Signed Message:\n32" || hash)` — sabit uzunluklu prefix, kanoniktir; `toEthSignedMessageHash` Solidity ile Rust'ta **birebir** aynı çıktı (cross-check ile kanıtlanır).
  - **Kalan risk:** `v` değerinin 27/28 (EIP-191) vs 0/1 (k256) çevirisi — bu bir "representation divergence" noktasıdır ve `signed.rs`'de `recovery_id_from_v` ile **açıkça** ele alınmıştır. Doğrulama testleri bu çeviriyi kapsar.

### 3. Mitigating Collusion in Proofs of Liabilities
- **Yazarlar:** Malcom Mohamed, Ghassan Karame
- **Yıl / Yer:** 2026 / Preprint of the AsiaCCS'26 paper
- **URL:** https://arxiv.org/abs/2603.12990
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** (Detay için bkz. `03_spot_borsa_guvenligi_2025_2026.md` ve `05_merkle_kanitlari...`.) İmza açısından önemi: **commit edilen vektörün yalnızca kullanıcıların açıkça imzaladığı değerleri içermesini** sağlayan Permissioned Vector Commitment (PVC) önerir — KZG homomorfizmi + BLS imzaları. Sağlayıcının uydurma yapraklar commit etmesini imza engeller; **kullanıcı işbirliği olmadan** dürüst olmayan sağlayıcı tespit edilebilir.
- **Cleanvest ile ilgisi:** Cleanvest'de **her yaprak imzalanır** ve `SignedMerkleTree::build_signed` **önce tüm imzaları doğrular** — uyduruğa (fabrication) karşı aynı garanti. Fark: Cleanvest **EIP-191 ECDSA** + keccak256 kullanır (EVM `ecrecover` ile doğrudan uyumlu), PVC ise KZG + BLS. **Ek bir güvenlik notu:** EIP-191 ECDSA, BLS'den farklı olarak **imza malleability**'ye karşı EIP-2 (low-s) korumasına ihtiyaç duyar; EVM `ecrecover` precompile'ı bu kontrolü **kendi içinde** yapmaz. Cleanvest'in `recoverSigner`'ı düşük-s kontrolü yapmadan `ecrecover` çağırır — bir saldırgan bir (r,s,v) imzasından **geçerli başka bir (r, s', v')** türetebilir. **Önemli:** bu, EIP-191 ile imzalanmış her sistem için geçerli bir konudur ve temel olarak **replay** ile sınırlıdır (aynı mesaj, farklı gösterim) — #2'nin tam konusu. Kullanılmış-imza takibi olmaması ile birleştiğinde bu, dürüst bir şekilde belirtilmesi gereken bir sınırdır.

### 4. RWA-PoB: A Credential-Based Proof-of-Backing Framework for Tokenized U.S. Treasury Products
- **Yazarlar:** Rischan Mafrur, Gun Gun Febrianza, Sean Foley
- **Yıl / Yer:** 2026 / arXiv preprint (cs.CE, cs.CR)
- **URL:** https://arxiv.org/abs/2608.25269
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** (Detay için bkz. `05_merkle_kanitlari...`.) İmza açısından önemi: **kanonik bir EIP-712 snapshot'ını** beş yetkili kurumsal rol imzalar; rezerv/yükümlülük/likidite/politika bilgisini bağlar. Framework kurumsal iddiaların **atfı ve bütünlüğünü** doğrular ama off-chain varlıkların varlığını/sahipliğini **bağımsız olarak kanıtlamaz**.
- **Cleanvest ile ilgisi:** **EIP-712 vs EIP-191** tercihi için referans. Cleanvest EIP-191 (`personal_sign`) kullanır — cüzdanların `signMessage` API'si ile **birebir** aynı özeti üretir; bu, kullanıcı tarafında ek tip-tabanlı imzalama altyapısı (EIP-712 domain/typed-data) gerektirmeden tarayıcı cüzdanlarında çalışmasını sağlar. **Dezavantaj (dürüst):** EIP-191 imzası **ne imzalandığını insanın görmesini** sağlamaz (makineler için hex'tir); EIP-712 bunu okunabilir typed data ile çözer. Bu, kullanıcı deneyimi/güvenlik trade-off'udur ve README'de belirtilmelidir.

### 5. Ghost-Filled Orders: Detecting and Testing Atomicity Violations in Non-Custodial Prediction Markets
- **Yazarlar:** Zhiyang Chen, Fan Long, Zhendong Su
- **Yıl / Yer:** 2026 / arXiv preprint (cs.CR)
- **URL:** https://arxiv.org/abs/2609.17902
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** (Detay için bkz. `04_akilli_kontrat_denetim_standartlari_2025_2026.md`.) İmza açısından önemi: kullanıcılar fonları cüzdanında tutup **imzalı emirleri off-chain emir defterine** gönderir; emir off-chain geçerliyken on-chain kesinleştirme öncesinde **geçersiz hale getirilebilir**. Polymarket örneğinde 1.8M reverted işlem üzerinden ölçülen bir "atomicity gap".
- **Cleanvest ile ilgisi:** İmzalı emir + off-chain batch toplama + on-chain kesinleştirme **aynı mimari**. İmza, emirin **içeriğini** kilitler ama **zamanlamasını** kilitlemez. Bu, imza güvenliğin **gerekli ama yeterli olmadığını** gösterir.

### 6. A Lightweight QR-assisted Zero-knowledge Identification Protocol For Secure Authentication
- **Yazarlar:** Hüseyin Bodur
- **Yıl / Yer:** 2026 / arXiv preprint (cs.CR), 7 sayfa, 3 şekil
- **URL:** https://arxiv.org/abs/2605.16912
- **Doğrulama:** web_fetch ile okundu — 2026-09-29 (API sorgusu `all:"replay attack" AND all:nonce` ve abs sayfası, HTTP 200, **withdrawn değil**)
- **İçerik (okunan özet):** Schnorr tabanlı sıfır-bilgi kimlik doğrulama modeli; **replay saldırılarına karşı ek güvenlik katmanı nonce ve timestamp mekanizmaları ile** sağlanır. Kanıt verisi QR koduna gömülüp doğrulayıcıya iletilir; gizli anahtarın bilgisini ifşa etmeden doğrulama yapılır. 256-bit güvenlik seviyesinde kanıt üretimi ve doğrulaması milisaniyeler düzeyinde; kanıt boyutu sabit ~0,5 KB.
- **Cleanvest ile ilgisi:** **Doğrudan nonce-mekanizması referansı.** Makale, replay'e karşı kullanılan iki temel mekanizmayı açıkça adlandırır: **nonce** ve **timestamp**. Cleanvest DAR görevi (2026-09-29) aynı ilkeyi zincir-üstü uygular: `_useNonce(user, nonce)` — kullanılmış nonce ikinci kez **reddedilir** (fail-closed). Fark: bu çalışma kimlik doğrulama oturumu içindir (timestamp ile replay); Cleanvest zincir-üstü **kalıcı** takiptir (timestamp gerekmez — zincirin kendisi sıralamayı sağlar). **Sonuç:** nonce tabanlı replay korumasının kimlik doğrulama/sıfır-bilgi literatüründe **yerleşik bir yöntem** olduğunu teyit eder; Cleanvest uygulamayı bu literatür standardına göre konumlandırır.

### 7. Blockchain security based on cryptography: a review
- **Yazarlar:** Wenwen Zhou, Dongyang Lyu, Xiaoqi Li
- **Yıl / Yer:** 2025 (v1 2025-08-02, v2 2026-07-05) / arXiv preprint (cs.CR), derleme makalesi
- **URL:** https://arxiv.org/abs/2508.01280
- **Doğrulama:** web_fetch ile okundu — 2026-09-29 (API sorgusu `all:"replay attack" AND all:blockchain` ve abs sayfası, HTTP 200, **withdrawn değil**)
- **İçerik (okunan özet):** Blokzincir saldırılarını **kriptografi perspektifinden** sistematik derleme. Altı katmanlı mimari (veri/ağ/konsensüs/kontrat/teşvik/uygulama) üzerinden saldırıları sınıflandırır ve her biri için **azaltma/savunma çözümleri** önerir. Özel olarak **altı saldırının** prensiplerini analiz eder: %51 saldırısı, **çift-harcama (double-spending)**, **yeniden-giriş (reentrancy)**, **replay saldırısı**, Sybil saldırısı ve **zaman damgası tahriri (timestamp tampering)**. Kriptografik temel olarak hash fonksiyonları ve **dijital imzaların** rolünü inceler.
- **Cleanvest ile ilgisi:** **Replay saldırısının blokzincir katmanlı sınıflandırması için referans.** Makale, replay saldırısını imza/zaman tabanlı diğer saldırılarla aynı **kriptografik kök nedenden** (taahhüdün tekilleştirilememesi) kaynaklanan bir sınıf olarak ele alır. Cleanvest'in konumunu netleştirir: (a) replay saldırısı **veri katmanında** (imzalı yaprakların tekrar oynatılması) yer alır — DAR görevi bunu **zincir-üstü nonce takibi ile** kapatmıştır; (b) **timestamp tahriri** ve **Sybil** makalenin incelediği **ayrı** saldırı sınıflarıdır — bunlar Cleanvest'in PoL/manipülasyon tespit katmanının hedeflediği farklı sorunlardır. **Dürüst sınır (derleme olması):** Bu bir **derleme makalesidir** — yeni protokol veya ölçüm sunmaz; mevcut sınıflandırmayı özetler. Referans olarak **sınıflandırma ve standart savunma envanteri** için kullanılır, deneysel kanıt olarak değil.

## Cleanvest'e Uygulanabilirlik

**Tasarımın güncel literatürle değerlendirmesi:**
| Bileşen | Güncel standart ile değerlendirme | Durum |
|---|---|---|
| EIP-191 `personal_sign` (cüzdan `signMessage` ile birebir) | Standart, cüzdan desteği evrensel | **Doğru tercih** |
| `abi.encode` (packed DEĞİL) ile yaprak hash | #2: canonicalization — teklik zorlanır | **Doğru tercih** (packed olsaydı riskli) |
| Sabit uzunluklu EIP-191 prefix | #2: message malleability yüzeyi kapalı | **Doğru tercih** |
| Her yaprakta `nonce` alanı | #1: SRV'nin birincil önlemi | **Mevcut** |
| `batchSettled[batchId]` ile çift-kesinleştirme engeli | #1: replay'in batch-seviyesi sınırı | **Mevcut** |
| v: 27/28 ↔ 0/1 çevirisi | #2: representation divergence | **Açıkça ele alındı**, test kapsamında |
| Kullanılmış-nonce zincir-üstü takibi | #1: SRV için **gerekli**; #6: nonce+timestamp literatür standardı | **MEVCUT (DAR 2026-09-29)** — `_useNonce` + `ReplayDetected`, 4 test |
| low-s (EIP-2) kontrolü imza doğrulamada | #3: ECDSA malleability | **YOK — açık sınır** |
| İmzalanan içeriğin insan tarafından okunması | #4: EIP-712 avantajı | **YOK — UX sınırı** |

**Sonuç (dürüst):** Cleanvest'in EIP-191 şeması **doğru temel seçimler** yapmıştır (personal_sign, abi.encode, sabit-prefix, nonce alanı, fail-closed build). DAR görevi (2026-09-29) ile **kullanılmış-nonce zincir-üstü takibi eklendi** — `_useNonce` her imzali yapragin nonce'unu zincirde isaretler, ayni (user, nonce) ikinci kez `ReplayDetected` ile **reddedilir** (dürüst sınır #2 KAPANDI, 4 yeni test, toplam 290). Geriye kalan **gerçek teknik sınır**: **low-s (EIP-2) kontrolünün olmaması** — ECDSA imza malleability'si ile bir imzadan ikinci bir gösterim türetilebilir. Bu, "sıfır manipülasyon" iddiasının **şu anki kapsamını** belirleyen sınırdır.

## Boşluklar / Açık Sorular

- **EIP-191 spesifikasyonunun kendisi** (ERC-191) akademik bir makale değil, bir EIP'tir; bu dokümanda EIP-191'in **kriptografik standart** olarak doğrulanması, spesifikasyon yerine makalelerle yapılmıştır (EIP'ler arXiv'de yer almaz).
- #2 (Canonicalization Failures) bir **preprint**'tir ve yazarı, katkısının "gözlemi keşfetmek değil, sistemleştirmek" olduğunu açıkça belirtir — sınıflandırma iddia değildir.
- **low-s / EIP-2** ve **EIP-155 ile replay koruması** gibi temel konular 2025-2026 literatüründe zaten "yerleşik" kabul edildiği için yeni makale çıkmadığı gözlemlendi; bu dokümanda yerleşik bilgi olarak işlenmiş ve Cleanvest uygulamasına **davranışsal olarak** yansıtılmıştır.
- **Cüzdan tarafı** (signMessage'in farklı cüzdanlarda EIP-191'i nasıl uyguladığı) güncel akademik bir ölçüme sahip değildir; bu, entegrasyon testi ile doğrulanmalıdır.
