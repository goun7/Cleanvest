# Merkle Kanıtları ve Finansal Uygulamalar — Akademik Araştırma (2025-2026)

**Tarih:** 2026-09-29
**Amaç:** Cleanvest'in `orderCommitmentRoot` (imzalı Merkle ağacı) tasarımını güncel (2025-2026) finansal Merkle-proof literatürü ile değerlendirmek.
**Aranan kaynaklar:** arXiv (export.arxiv.org API + abs sayfaları), cs.CR, cs.CE.
**Doğrulama yöntemi:** Her kaynak arXiv API'sinden ve doğrudan `arxiv.org/abs/<id>` sayfasından fetch edilerek teyit edildi.

## Özet

2025-2026'da proof-of-reserves / proof-of-liabilities alanında üç gelişme Cleanvest için doğrudan ilgili: (1) **Kullanıcı-tarafı doğrulama zorluğu** literatürün merkezine geçti — Merkle-tree tabanlı kanıtların "herkes tarafından doğrulanabilir" iddiası pratikte **gerçeklemiyor**; kullanıcılar gerçekte doğrulayamadığı için katılım düşük ve şeffaflık zayıflıyor. Buna karşılık **katmanlı (layered)** tasarımlar öneriliyor: hafif kullanıcı-tarafı kontrol + denetçi-seviyesi kriptografik doğrulama. (2) **Collusion'a karşı dayanıklılık bir gereklilik haline geldi** — mevcut şemalar sağlayıcı + kullanıcı işbirliğine dayanamaz; çözüm, commit edilen vektörün yalnızca **kullanıcının imzaladığı** değerleri içermesidir. (3) **EIP-712 tabanlı snapshot kimlik doğrulaması** tokenize edilmiş gerçek-varlık (RWA) ürünleri için oluşmakta olan bir standarttır. Birlikte değerlendirildiğinde, Cleanvest'in **imzalı yaprak + bağımsız CLI ile yeniden hesaplanabilir kanıt** yaklaşımı, (1) ve (2)'nin önerdiği yöndedir.

## İncelenen Kaynaklar (fetch ile doğrulandı)

### 1. LPOR: A Layered Proof of Reserves Framework for Usable and Publicly Auditable Solvency Verification
- **Yazarlar:** Donggoo Kim, Rajesh Upadhayaya, Milosz Bator, Tao Le
- **Yıl / Yer:** 2026 / Proc. 2026 IEEE International Conference on Blockchain and Cryptocurrency (ICBC), Brisbane, Australia, 2026 (DOI: 10.1109/ICBC67748.2026.11575531)
- **URL:** https://arxiv.org/abs/2606.08211
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** Proof of Reserves'ün merkezî sorununu ele alır: mevcut yaklaşımlar — **Merkle-tree tabanlı kanıtlar dahil** — günlük kullanıcılar için **pratikte doğrulanması zor** olduğu için sınırlı katılım ve zayıflamış şeffaflık yaratmaktadır. **LPOR** adlı katmanlı, kullanılabilirlik-odaklı PoR framework'ü tanımlar: hafif **kullanıcı-tarafı kontrolleri** ile **denetçi-seviyesi kriptografik doğrulamayı** birbirinden ayırır; teknik-olmayan kullanıcıların inclusion'ı doğrulamasını ve toplam yükümlülükleri **herkesin yeniden hesaplayabilmesini** minimal sürtünmeyle sağlar. Doğrulama bariyerlerini düşürerek kullanıcı katılımını ve **atkı (omission) tespit olasılığını** önemli ölçüde artırdığını öne sürer. Çok-milyon-kullanicili ölçekte ölçeklenebilirlik ve atkı tespit edilebilirliğini değerlendirir.
- **Cleanvest ile ilgisi:** **En doğrudan ilgili makale.** "Kök herkes tarafından doğrulanabilir" iddiasının pratikte **gerçeklemediği** gerçeği, Cleanvest'in bağımsız `cleanvest verify proof.json` CLI'ını **zorunlu** kılar: doğrulama, kullanıcıya bırakılamaz; **bağımsız, komut satırından çalışabilen, ağ bağlantısı gerektirmeyen** bir araç olmalıdır. LPOR'un "katmanlı" fikri de uygulanabilir: yaprak doğrulama (hafif, herkes) ↔ kök rebuild (ağır, denetçi).

### 2. Mitigating Collusion in Proofs of Liabilities
- **Yazarlar:** Malcom Mohamed, Ghassan Karame
- **Yıl / Yer:** 2026 / Preprint of the AsiaCCS'26 paper
- **URL:** https://arxiv.org/abs/2603.12990
- **Doğrulama:** web_fetch ile okundu — 2026-09-29 (hem API hem abs sayfası)
- **İçerik (okunan özet):** Mevcut Proof-of-Liability şemalarının **sağlayıcının mevcut bir kullanıcı ile işbirliği yaptığı** gerçekçi senaryoya dayanamadığını belirtir. "Permissioned PoL" modeli ve **Permissioned Vector Commitment (PVC)** ilkel önerilir: **commit edilen vektör yalnızca kullanıcıların açıkça imzaladığı değerleri içerebilir**. KZG commitment'ların homomorfik özellikleri + BLS imzaları ile verimli bir yapı; daha güçlü güvenliğe rağmen sunucu performansında **10×'e kadar** iyileştirme.
- **Cleanvest ile ilgisi:** Cleanvest'in yaprak imza şeması bu makalenin **gereksinimini doğrudan karşılar**: `SignedMerkleTree::build_signed` **önce her imzayı doğrular**, tek bir geçersiz imza tüm kurulumu reddeder (fail-closed). Yani kök, yalnızca kullanıcıların imzaladığı yaprakları içerebilir. Farklılık: Cleanvest EIP-191 ECDSA + keccak kullanır (KZG+BLS değil) — aynı güvenlik amacı, farklı kriptografi; ECDSA seçimi EVM'de `ecrecover` precompile ile **doğrudan** uyumluluk avantajı taşır.

### 3. RWA-PoB: A Credential-Based Proof-of-Backing Framework for Tokenized U.S. Treasury Products
- **Yazarlar:** Rischan Mafrur, Gun Gun Febrianza, Sean Foley
- **Yıl / Yer:** 2026 / arXiv preprint (cs.CE, cs.CR)
- **URL:** https://arxiv.org/abs/2608.25269
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** PoR'ın sayısal yeterlilik gösterdiğini ama **off-chain varlıkların yasal uygunluğu, yükümlülüksüzlüğü (unencumbered), tutarlı değerlemesi veya yeterli likiditesini** kanıtlamadığını belirtir. **EIP-712** tabanlı kanonik snapshot (rezerv, yükümlülük, likidite, politika bilgisi içeren) üzerine kurulu credential-based proof-of-backing framework'ü; beş yetkili kurumsal rol onaylar. Backing Coverage Ratio (BCR) ve Redemption Liquidity Coverage (RLC) ile değerlendirme; Solidity prototipi policy controller'ı ERC-20'e bağlar. USDY-kalibreli yükümlülüklerle değerlendirmede, basit aggregate-PoR baseline'ı geçerli durumda issuance'a izin verirken RWA-PoB **BCR %96.3408** ile yükümlülüklü-varlık (encumbered) durumunu **reddeder** (%105 eşiğin altında). Likidite stresinde post-request RLC **%39.9999**'a düşünce redemption'ı "queued" olarak sınıflandırır. **Dürüst sınır:** framework kurumsal iddiaların **atfı ve bütünlüğünü** doğrular ama off-chain varlıkların varlığını, sahipliğini veya durumunu **bağımsız olarak kanıtlamaz**. Kod/test/veri/çoğullama script'leri https://github.com/rischanlab/PoB 'da.
- **Cleanvest ile ilgisi:** CleanUSD (fiat-backed stablecoin) için **yol haritası**. EIP-712/EIP-191 tabanlı **snapshot imzası** yaklaşımı, Cleanvest'in yaprak imza şemasıyla aynı kriptografik familyadadır. Önemli ders: **kanıt, "varlık var" demez** — "iddia edilen kişi bunu imzaladı" der. Cleanvest de aynı şekilde `orderCommitmentRoot` ile "bu emirler taahhüt edildi" der, "emirler meşru" demez. Bu sınır README'de belirtilmelidir.

### 4. The Treasury Proof Ledger: A Cryptographic Framework for Accountable Bitcoin Treasuries
- **Yazarlar:** Jose E. Puente, Carlos Puente
- **Yıl / Yer:** 2025 (gönderim 2025-12-03) / arXiv preprint (cs.CR)
- **URL:** https://arxiv.org/abs/2512.03765
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** Bitcoin hazinelerini çok-alanlı (multi-domain) bir exposure vektörü olarak modeller; on-chain ve off-chain exposure'ları **conserved state machine** olarak temsil eder. TPL instance'ı **proof-of-reserves snapshot'ları, alanlar arası hareketler için proof-of-transit receipt'leri ve politika metadata'sı** kaydeder; izin-tabanlı **kısıtlı görünümler** sunar. Deployment-seviyesi güvenlik kavramları tanımlar: exposure soundness, policy completeness, **non-equivocation** (ikiyüzlülük yokluğu) ve privacy-compatible policy views. Standart PoR + proof-of-transit tekniklerini **Bitcoin üzerine anchor edilmiş hash-based commitment'lar** ile birleştirerek bu garantilerin pratik, kısıtlı biçimlerini elde etmeyi özetler. Sonuçlar **varlık-tipi** ifadelerdir: ekonomik ve yönetim varsayımları belirlendikten sonra hangi garantilerin elde edilebilir olduğunu gösterir; **hiçbir mevcut sistemin bunları zaten sağladığını iddia etmez**.
- **Cleanvest ile ilgisi:** **Non-equivocation** kavramı Cleanvest'in Merkle kökü için doğru isimdir: aynı batch için iki farklı kök yayınlanamaz (`batchSettled` ile çift-kesinleştirme koruması). "Varlık-tipi ifadeler" yaklaşımı (bu dokümanlarda kullanılan tarz) ile "kuruluş zaten bunu sağlıyor" iddiası arasındaki ayrım, Cleanvest'in dürüstlük standardıdır.

### 5. Applications Of Zero-Knowledge Proofs On Bitcoin
- **Yazarlar:** Yusuf Ozmiş
- **Yıl / Yer:** 2025 / arXiv preprint (cs.CR) — 2025-06-19
- **URL:** https://arxiv.org/abs/2507.21085
- **Doğrulama:** web_fetch ile okundu — 2026-09-29
- **İçerik (okunan özet):** zk-STARK tabanlı **Proof-of-Reserve** protokolü önerir: bir saklayıcı (custodian), adresleri veya gerçek bakiyeleri açıklamadan Bitcoin varlıklarının önceden tanımlanmış bir **Eşiğin (threshold) üstünde** olduğunu kanıtlayabilir. Ayrıca ZK Light Clients (STARK ile blok-header zinciri kanıtı) ve BitVM tabanlı gizlilik-koruyucu rollup'lar ele alır. Her durumda güvenlik, mevcut yaklaşımlarla karşılaştırılır ve **verimlilik-güven trade-off'ları** analiz edilir; ZK'nın güçlü yetenekler getirdiğini ama her uygulamanın dikkatli trade-off'lar gerektirdiğini belirtir.
- **Cleanvest ile ilgisi:** Merkle kanıtlarına **gizlilik** katmanın yolu: Cleanvest'in yaprakları (amount, user, nonce) plain-text hash'tir — bir kanıt sunulduğunda **değer açığa çıkar**. zk-STARK tabanlı bir geçiş, kanıtlayan kişiyi gizli tutar. **Yol haritası maddesi**, mevcut özellik değil; mevcut tasarımın neden gizlilik sunmadığını açıkça belirtmek için kullanılır.

## Cleanvest'e Uygulanabilirlik

**Tasarımın güncel literatürle uyumu:**
| Cleanvest özelliği | Güncel literatür karşılığı | Değerlendirme |
|---|---|---|
| Her yaprak EIP-191 ile kullanıcı imzalı, fail-closed build | #2: "commit edilen vektör yalnızca imzalı değerleri içermeli" | **Gereksinim karşılanıyor** |
| Bağımsız CLI ile kör/yeniden hesaplanabilir kanıt (`cleanvest verify`) | #1: katmanlı doğrulama; kullanıcı-tarafı bariyeri düşürme | **Bu sefer CLI ile sağlanıyor** |
| Rust ↔ Solidity byte-byte kök eşitliği | #1: doğrulama bariyeri; #2: collusion dayanıklılığı | **İki bağımsız uygulama** = daha güçlü kanıt |
| Çift-yapraklı ağaç (tek kalan kendisiyle eşleşir) | Standart Bitcoin/Ethereum Merkle yapısından farklı | **Spesifikasyon belgelenmeli** (aşağıda) |
| `batchSettled` ile non-equivocation | #4: non-equivocation güvenlik kavramı | **Gereksinim karşılanıyor** |

**Cleanvest Merkle spesifikasyonu (açık belgelik için):**
- Yaprak: `keccak256(abi.encode(amount, user, nonce))` — (uint256, address, uint256), 96 bayt.
- İç düğüm: `keccak256(abi.encode(a, b))` — her zaman **iki** 32-baytlık eleman.
- **Tek kalan yaprak kopyalanmaz; `keccak256(abi.encode(leaf, leaf))` ile kendisiyle eşleşir** (çift-yaprak kuralı).
- Bu, **domain separation** anlamına gelir: yaprak ve iç-düğüm hash'leri **farklı uzunluklardadır** (96 vs 64 bayt), dolayısıyla bir iç-düğüm bir yaprak gibi taklit edilemez — bu, standart "second-preimage" saldırısına karşı **yapısal** bir koruma sağlar.

**Dürüst sınırlar (README'de yer almalı):**
- **Gizlilik yok:** kanıt, yaprak değerlerini (amount, user, nonce) açığa çıkarır. zk-STARK (#5) çözümü **yol haritasında**.
- **PoR/PoL değildir:** `orderCommitmentRoot` emir taahhüdüdür; **rezerv/yükümlülük kanıtı değildir** (#1, #2, #3'nin alanı).
- **Bireysel replay koruması yok:** nonce alanı mevcut ama zincir-üstü kullanılmış-nonce takibi yoktur (bkz. `04_akilli_kontrat_denetim_standartlari_2025_2026.md`).
- **Doğrulama bariyeri:** CLI var, ama **kullanıcının gerçekte kanıt talep etmesi** bir organizasyonel/ürün meselesidir — kod ile çözülemez (#1'in bulgusu).

## Boşluklar / Açık Sorular

- **Çift-yapraklı (double-leaf) Merkle** kuralı için **2025-2026 doğrudan bir akademik referans bulamadık**; bu, iyi bilinen bir Merkle varyantıdır (Bitcoin-style "duplicate the last node") ama alana özgü güncel bir atıfımız yok. Bu eksiklik dürüstçe kaydedilmiştir; güvenlik değerlendirmesi **davranışsal olarak** (cross-check testleri ile) yapılmıştır.
- #3'ün `BCR %96.3408` / `RLC %39.9999` değerleri **sentetik rezerv senaryolarına** dayanır, gerçek rezerv verisi değildir.
- #1'in "kullanıcı katılımı artar" iddiası **diğer PoR sistemleri için** yapılan bir çıkarımdır; Cleanvest için emirik bir ölçüm değildir.
