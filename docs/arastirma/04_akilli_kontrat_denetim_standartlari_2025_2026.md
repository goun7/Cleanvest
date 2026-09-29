# Akıllı Kontrat Denetim Standartları — Akademik Araştırma (2025-2026)

**Tarih:** 2026-09-29
**Amaç:** Cleanvest'in test/denetim yaklaşımını (239 forge + 19 Rust testi) 2025-2026 akıllı kontrat güvenliği ve denetim standartları ile karşılaştırmak; neyin yeterli olduğunu ve neyin yetersiz kaldığını dürüstçe belirlemek.
**Aranan kaynaklar:** arXiv (export.arxiv.org API + abs sayfaları), cs.CR, cs.SE.
**Doğrulama yöntemi:** Her kaynak arXiv API'sinden ve doğrudan `arxiv.org/abs/<id>` sayfasından fetch edilerek teyit edildi.

## Özet

2025-2026'da akıllı kontrat denetimi alanında üç şey netleşti: (1) **On-chain/off-chain tutarlılık yeni bir birincil zafiyet sınıfıdır** — köprüler, RWA tokenizasyonu ve fiat-backed stablecoin'ler gibi "zincir-üstü ve zincir-dışı temsil eşitliğine" dayanan uygulamalarda, iş mantığı tutarsızlıkları bu eşitliği bozar; bu, Cleanvest'in **off-chain Merkle üreticisi + on-chain settlement** mimarisinin **tam** risk sınıfıdır. (2) **Off-chain emir defteri + on-chain kesinleştirme mimarilerinde "atomicity gap"** yeni sistematik bir zafiyet olarak tanımlandı (Polymarket vakası); bu da yine Cleanvest mimarisinin aynısıdır. (3) **İmza tekrar (signature replay)** yaygınlığı ölçüldü: Ethereum'da imza kullanan kontratların **%19.63'ü** bu zafiyeti taşımaktadır. Birlikte değerlendirildiğinde: Cleanvest'in testleri birim/doğruluk testidir ve **bu yeni sınıfları kapsamaz** — bu doküman, aralıkları net olarak belirler.

## İncelenen Kaynaklar (fetch ile doğrulandı)

### 1. SmartMemory: Detecting On-chain-off-chain Communication Inconsistency for Smart Contract via Memory-based Agent
- **Yazarlar:** Zeqin Liao, Yuhong Nan, Henglong Liang, Zixu Gao, Lianyu Hu, Yuqiang Sun, Zhijie Zhong, Xiaoyu Ma, Zibin Zheng, Yang Liu
- **Yıl / Yer:** 2026 / arXiv preprint (cs.SE, cs.CR) — 2026-09-28
- **URL:** https://arxiv.org/abs/2609.34983
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** On-chain/off-chain iletişim (OFC) gerektiren uygulamalarda (cross-chain köprüler, RWA tokenizasyonu, **fiat-backed stablecoin'ler**) güvenlik olaylarının arttığını; önceki çalışmaların OFC zafiyet kategorilerini ayrı ayrı ele aldığını ve bilinen örüntü dışındakilerin **kaçırıldığını** belirtir. **OFC tutarsızlığını (OFCI)** bir kök neden olarak tanımlar: iş mantığı hatasından kaynaklanır ve zincir-üstü ile zincir-dışı varlık temsilleri arasındaki **eşitliği bozarak** tutarsızlık yaratır. SmartMemory, OFC uygulamalarını canonical iş-semantic temsiline eşleyen ve memory-based agent ile zafiyet bilgisini transfer eden ilk framework'tür. **48 DApp / 81 OFCI'lik ilk gerçek-dünya OFCI verisetini** kurar; %80.68 kesinlik, %87.65 hatırlama. 325 gerçek OFC uygulamasında **36 daha önce bilinmeyen OFCI** tespit etti — hepsi ilgili taraflarca onaylanmış ve düzeltilmiştir.
- **Cleanvest ile ilgisi:** **En yüksek riskli sınıf.** Cleanvest, off-chain Rust Merkle üreticisi ile on-chain `CleanvestSettlement.verifyMerkleProof` arasında byte-byte eşitlik iddia eder (cross-check testi ile kanıtlanır). OFCI sınıfı tam olarak burada ortaya çıkabilir: Rust'ın `hash_pair` sıralaması, `abi.encode` paketlemesi, double-leaf kuralı ile Solidity'nin `_buildLayer`'ı arasındaki **herhangi bir** sapma, güvenli görünen ama aslında yanlış olan bir taahhüt yaratır. Cross-check testi (`test/MerkleCrossCheck.t.sol`, `test/SignedMerkle.t.sol`) bu boşluğu kapatır — makale, **neden** zorunlu olduğunu açıklar.

### 2. Ghost-Filled Orders: Detecting and Testing Atomicity Violations in Non-Custodial Prediction Markets
- **Yazarlar:** Zhiyang Chen, Fan Long, Zhendong Su
- **Yıl / Yer:** 2026 / arXiv preprint (cs.CR) — 2026-09-15
- **URL:** https://arxiv.org/abs/2609.17902
- **Doğrulama:** web_fetch ile okundu — 2026-09-29 (hem API hem abs sayfası)
- **İçerik (okunan özet):** **Off-chain emir yönetimi + on-chain kesinleştirme** mimarisini inceler (kullanıcı fonları cüzdanında tutulur, imzalı emirler off-chain emir defterine gönderilir). Bu mimarenin bir **atomicity gap** yarattığını kanıtlar: bir emir off-chain kabul/match edildiğinde geçerli olabilir ama on-chain kesinleştirme işlemi çalışmadan **önce geçersiz hale gelebilir** ("ghost filled orders"). Polymarket vakasıyla gösterir: düşürülen (reverted) **1.8 milyon işlem** üzerinden, 12 Ağustos 2025–22 Mayıs 2026 dokuz aylık dönemde saldırganların piyasa sonucunu veya fiyat hareketini gördükten sonra **elverişsiz emirleri geçersiz kılabildiğini** ve bu gecikmenin istismar edilebildiğini ölçer. Ek üç piyasanın **hepsinin** aynı saldırı sınıfına açık olduğunu bulur; bir tasarım doğrudan saldırgan kârı sağlar. Bulgular üç projeye bildirilmiştir.
- **Cleanvest ile ilgisi:** Cleanvest mimarisi ile **birebir aynı yapı**: imzalı emirler off-chain toplanır, batch on-chain kesinleştirilir. Makalenin bulgusu, batch gecikmesi (400ms) içinde saldırganların emirlerini **bilinçli olarak geçersizleştirebileceği** bir saldırı yüzeyini tanımlar. Cleanvest'in koruması: imzalı emirler **kullanıcı tarafından imzalandığı için** operatör yaprağı değiştiremez; ancak **batch'e alındıktan sonra emir iptal etme** akışının tasarımı bu makaleye göre dikkatle modellenmelidir.

### 3. One Signature, Multiple Payments: Demystifying and Detecting Signature Replay Vulnerabilities in Smart Contracts
- **Yazarlar:** Zexu Wang, Jiachi Chen, Zewei Lin, Wenqing Chen, Kaiwen Ning, Jianxing Yu, Yuming Feng, Yu Zhang, Weizhe Zhang, Zibin Zheng
- **Yıl / Yer:** 2025 (gönderim) / **Accepted at ICSE 2026**
- **URL:** https://arxiv.org/abs/2511.09134
- **Doğrulama:** web_fetch ile okundu — 2026-09-29 (hem API hem abs sayfası)
- **İçerik (okunan özet):** **Signature Replay Vulnerability (SRV)**'yi tanımlar ve ilk ampirik çalışmayı yapar: **37 blockchain güvenlik şirketinin 1.419 denetim raporundan 108'inde** ayrıntılı SRV tanımları bulur ve **5 SRV türü** sınıflandırır. LASiR adlı otomatik dedektör, LLM destekli statik taint analizi + sembolik execution ile imza-tekrar davranışını tespit eder. Dört zincirde (Ethereum, BSC, Polygon, Arbitrum) 918.964 kontrattan seçilen 15.383 imza-doğrulamalı kontrat üzerinde: **Ethereum'da imza kullanan kontratların %19.63'ü SRV içermektedir**; etkilenen kontratlarda **$4.76 milyon** aktif varlık bulunmaktadır. LASiR F1 = %87.90.
- **Cleanvest ile ilgisi:** Cleanvest'in Merkle yapraklarında **nonce** alanı bulunur (`keccak256(abi.encode(amount, user, nonce))`) — bu, SRV'nin temel önlemidir. Ancak nonce **tek-seferlik kullanım (one-time use)** denetimi zincir-üstünde **yapılmaz**: `verifySignedOrder` bir yaprağı aynı kök altında ikinci kez doğrulamayı engellemez. **Önemli sonuç:** kanıtın yeniden oynatılması (replay) batch düzeyinde `batchSettled` ile sınırlıdır; bireysel emir seviyesinde replay koruması operasyonel bir sorundur. Bu, `README`'de dürüstçe "sınır" olarak belirtilmelidir.

### 4. EchoFuzz: Empowering Smart Contract Fuzzing with Large Language Models
- **Yazarlar:** Juanen Li, Peng Qian, Guanyan Li, Rui Wang, Peixin Wang, Zhiqing Tang, Fuchen Ma, Yuanliang Chen, Lun Zhang
- **Yıl / Yer:** 2026 / Accepted by ICSE'2026
- **URL:** https://arxiv.org/abs/2609.14475
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** LLM destekli akıllı kontrat fuzzing framework'ü; "Vulnerable Function Call Sequences" (VFCS) — hatayı ortaya çıkaran minimal, davranışı koruyan yürütme yolları — kavramını tanıtır. Zincir-kılavuzlu LLM yaklaşımıyla kontrat-spesifik VFCS adayları üretir ve gerçek-zamanlı geri-besleme ile fuzzer'ı örtülmemiş dallara yönlendirir. Son teknolojiyi **%29 daha yüksek dal kapsama** ve **%62 daha fazla zafiyet tespiti** ile geçer; gerçek kontratlarda **37 daha önce bilinmeyen zafiyet** bulur.
- **Cleanvest ile ilgisi:** Cleanvest'in `Fuzz.t.sol` ve invariant testleri (`scusd_vault_invariants.t.sol`) klasik fuzzing'dir; LLM destekli diziselleştirme ve dal kapsama **yoktur**. Bu, test kapsamının sınırlarını gösterir.

### 5. On Identifying Sound Conditions for Frontrunning Resistance
- **Yazarlar:** Sebastian Holler, Anna Piscitelli, Jannik Albrecht, Stephan Dübler, Ghassan Karame, Clara Schneidewind
- **Yıl / Yer:** 2026 / Accepted for CCS 2026
- **URL:** https://arxiv.org/abs/2609.11535
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** Akıllı kontratlar için **ilk resmi front-running güvenlik açığı tanımını** verir (bkz. `02_mev_ve_front_run_koruma_2025_2026.md`). Denetim standartları açısından kritik bulgusu: **287 akıllı kontrat denetiminde**, önde gelen denetçilerin raporladığı **393 güvenlik açığının %55'i** en son detection criteria'nın **kapsamı dışındadır** — mevcut dinamik tespit yöntemleri temelde yetersizdir. Prototip ile denetlenmiş gerçek kontratlarda daha önce bilinmeyen iki Ethereum zafiyeti bulunur.
- **Cleanvest ile ilgisi:** "Denetim geçti" güvenlik anlamına gelmez. **%55** gibi bir oran, denetim araçlarının sadece bilinen örüntüleri yakaladığını gösterir. Cleanvest, bu yüzden araç-tabanlı denetim iddiası yerine **iki-bağımsız-uygulama cross-check'i** (Rust ↔ Solidity byte-byte kök eşitliği) kullanır — bu, tek bir araçla yakalanamayan sapmaları yakalar.

## Cleanvest'e Uygulanabilirlik

**Mevcut test/denetim varlıkları ve güncel standartlarla karşılaştırma:**
| Cleanvest varlığı | Karşılık geldiği standart | Yeterli mi? |
|---|---|---|
| 239 forge testi (birim + fuzz + invariant) | Klasik fuzzing + invariant checking | Kısmen — LLM-guided fuzzing (#4) yok |
| 19 Rust testi (Merkle + imza) | Çift-uygulama doğrulaması | Evet — bu, #5'in önerdiği "farklı gösterim" çapraz-doğrulamasıdır |
| Rust↔Solidity cross-check (byte-byte kök) | OFCI/off-chain-on-chain tutarlılık (#1) | Bu sınıf için **güçlü** bir kontrol |
| ReentrancyGuard | Reentrancy sınıfı (#3'de birincil) | Evet |
| Chainlink harici oracle | Oracle manipülasyon (#3) | Evet |

**Literatürün işaret ettiği AÇIK ARALIKLAR (dürüst):**
1. **OFCI sınıfı (#1):** cross-check kök eşitliği kanıtlanmıştır, ancak **kök üretimi ile batch içeriğinin eşleşmesi** (batchId/totalVolume/clearingPrice bağlanması) `executeBatchSettlement`'ta `keccak256(abi.encode(batchId, orderCommitmentRoot, clearingPrice, totalVolume))` ile bir commitment scheme olarak mevcuttur — bu, OFCI'nin bir kısmına karşı koruma sağlar.
2. **Atomicity gap (#2):** "ghost filled orders" — emir batch'e alındıktan sonra kullanıcının bilinçli iptali/iptal penceresi tasarımı **mevcut kontratta modellenmemiştir**. Bu, işlem ve risk mekanizması tasarımında açık bir yönelmdir.
3. **SRV / bireysel replay (#3):** nonce alanı mevcuttur ama **zincir-üstü kullanılmış-nonce takibi yoktur**. Ethereum'da bu sınıf imza kullanan kontratların **%19.63'ünde** bulunur. DÜRÜST SINIR olarak belirtilmelidir.
4. **LLM-guided fuzzing (#4):** mevcut değil; kapsam ölçümü `lcov.info` ile mevcuttur ama dal kapsarma optimizasyonu yapılmamıştır.

## Boşluklar / Açık Sorular

- #1 (SmartMemory) ve #2 (Ghost-Filled Orders) 2026 **preprint**'leridir; henüz hakemli yayınlanmamıştır (ICSE'26 vb.'ye gönderim belirtilmemiştir). Bulgular önemli olmakla birlikte, kesinlikleri için hakemli sürümleri takip edilmelidir.
- #3'ün **%19.63** oranı "imza kullanan Ethereum kontratları" içindir; Cleanvest'in mimarisine doğrudan transfer edilemez (Cleanvest'te imza yaprak üzerinde, ödeme fonksiyonunda değildir) — oran bir **büyüklük düzeni** göstergesidir.
- Hiçbir makale, Cleanvest'in kullandığı **çift-yapraklı (double-leaf) Merkle + EIP-191 yaprak imzası** spesifik kombinasyonunu doğrudan denetlememiştir; bu doküman, bileşenleri birleştirirken bu kombinasyonun **bağımsız bir güvenlik değerlendirmesine** ihtiyaç duyduğunu not eder.
