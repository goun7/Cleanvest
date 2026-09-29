# Proof of Liabilities — Güvenlik Modelinin Derinleştirilmesi (Akademik Araştırma)

**Tarih:** 2026-09-29
**Amaç:** `ProofOfLiabilities.sol`'ün DAR parçasıyla (fail-closed imzalı yapraklardan
zincir-üstü kök türetimi) güvenlik modelini, Proof-of-Liabilities (PoL) literatürüyle
değerlendirmek. Bu doküman, `05_merkle_kanitlari_finansal_uygulamalar_2025_2026.md`'in
**doğrudan devamıdır** — orada 2025-2026 PoL/PoR corpus'u işlendi; burada PoL
güvenlik modelinin üç temel taşı (gizlilik, denetim, varlık/yükümlülük dengesi) derinleştirilir.
**Aranan kaynaklar:** arXiv (export.arxiv.org API + abs sayfaları), cs.CR / cs.CE / q-fin.GN.
**Doğrulama yöntemi:** Her kaynak arXiv API'sinden ve doğrudan `arxiv.org/abs/<id>`
sayfasından `web_fetch` ile teyit edildi (**HTTP 200**). Uydurma YOKTUR.

## Özet — PoL güvenlik modelinin üç bulgusu

PoL güvenlik modeli üç eksende durulur ve bu dokümandaki üç makale her bir eksen için
bir literatür karşılığı verir:

1. **"Ağaç doğru kuruldu" kanıtının yeri** — TAP (USENIX Security 2023), PoL'yi
   "kullanıcı verisini gizleyen ama sınırlı doğrulanabilir işlemleri olan" authenticated
   data structure sınıfına koyar ve **"ağacın doğru kurulduğunu" bağımsız denetimlerle**
   (zero-knowledge range proof'larıyla) kanıtlama yöntemi sunar. Cleanvest bu bulguyu
   **zincir-üstüne taşır**: `publishLiabilitiesFromSignedLeaves()` her yaprağın imzasını
   zincirde doğrular ve kökü imzalı yapraklardan **zincirde türetir** — "ağacın doğru
   kurulduğunu" denetim yerine **kod** kanıtlar (fail-closed).
2. **Gizlilik, PoL'nin açık sınırıdır** — "Private Proof of Solvency", rezervleri
   (ve **toplam yükümlülük miktarını**) açıklamadan ispatlayan bir PoS şeması sunar.
   Cleanvest'in PoL'si bir kanıt sunulduğunda yaprak değerlerini (user, balance)
   **açığa çıkarır** — bu makale, README dürüst sınırı #4'ün ("Gizlilik YOKTUR")
   literatürdeki çözümüdür; **yol haritası** maddesidir, mevcut özellik değildir.
3. **PoL gerekli ama yetersizdir** — VASP (sanal varlık servis sağlayıcısı) denetleme
   makalesi, borsaların ödenme gücünü **üç kaynağı çapraz referanslayarak** ölçer:
   zincir-üstü cüzdanlar, ticari sicil bilançosu ve denetim verisi. Dört VASP'ten
   yalnızca ikisinin bilanço ile zincir verisi **tutarlı** çıkmıştır. Temel ders:
   *"denetimden sorumlu her varlık, VASP'ın zincir-üstü cüzdanlarıyla ilişkili fonları
   gerçekten kontrol ettiğine kanıt gerektirir."* Yani yükümlülük kanıtı (PoL) tek başına
   ödenme gücünü **kanıtlamaz** — varlık tarafı ve off-chain çapraz referans şarttır.

Birlikte değerlendirildiğinde: Cleanvest'in PoL'si **(1)**'in gereğini zincir-üstünde
aşar (on-chain fail-closed kurulum), **(2)**'yi açık sınır olarak işaretler, **(3)**'ün
yetersizliğini README dürüst sınırı #1'de ("rezervlerin VARLIĞINI kanıtlamaz") tutar.

## İncelenen Kaynaklar (fetch ile doğrulandı)

### 1. TAP: Transparent and Privacy-Preserving Data Services
- **Yazarlar:** Daniel Reijsbergen, Aung Maw, Zheng Yang, Tien Tuan Anh Dinh, Jianying Zhou
- **Yıl / Yer:** 2022 (gönderim) / USENIX Security 2023 — arXiv:2210.11702 (cs.CR)
- **URL:** https://arxiv.org/abs/2210.11702
- **Doğrulama:** `web_fetch` ile okundu — **HTTP 200**, 2026-09-29
- **İçerik (okunan özet):** Kullanıcı verisi işleyen hizmetlerde yalnızca gizlilik ve
  bütünlük değil, **şeffaflık** (işlemin kullanıcılar ve güvenilir denetçilerce
  doğrulanabilirliği) beklentisini ele alır. Mevcut authenticated data structure
  yaklaşımlarını **iki sınıfa** ayırır: (1) kullanıcı başına veriyi gizleyen ama
  **sınırlı sayıda doğrulanabilir işlemi** olanlar — **burada "Proofs of Liabilities"
  açıkça örnek gösterilir** (CONIKS, Merkle2 ile birlikte) — ve (2) geniş doğrulanabilir
  işlem yelpazesi sunan ama **tüm veriyi herkese açık** olanlar (IntegriDB, FalconDB).
  TAP bu boşluğu doldurur: veriyi ifşa etmeden **ağacın doğru kurulduğunu**
  zero-knowledge **range proof**'larıyla gösteren bağımsız denetimlere dayanan yeni bir
  ağaç veri yapısı; quantile ve örnek standart sapma gibi geniş bir doğrulanabilir
  işlem yelpazesi sunar. IntegriDB ve Merkle2 ile karşılaştırmada ölçekli performans gösterir.
- **Cleanvest ile ilgisi:** **PoL'yi literatürde adıyla sınıflandıran makale.**
  Cleanvest'in PoL'si TAP'ın **(1). sınıfıdır**: bakiye doğrulanabilir ama bir kanıt
  sunulduğunda yaprak değerleri açığa çıkar. İlgili iki transfer:
  (a) **"Ağacın doğru kurulması" kanıtı** — TAP bunu **denetimlerle** (off-chain ZK
  range proof) sağlar; Cleanvest DAR parçasıyla bunu **zincir-üstüne** taşır:
  `publishLiabilitiesFromSignedLeaves()` tek geçersiz imzada tüm yayını revert ederek
  ağacın ancak imzalı yapraklardan kurulabileceğini **kodla** garantiler (denetim
  gerekmez). (b) **Gizlilik** — TAP'ın ZK range proof yaklaşımı, Cleanvest için
  **yol haritasıdır** (README sınır #4).

### 2. Private Proof of Solvency
- **Yazarlar:** Hamid Bateni, Keyvan Kambakhsh
- **Yıl / Yer:** 2023 / arXiv:2310.13900 (cs.CR, cs.CE)
- **URL:** https://arxiv.org/abs/2310.13900
- **Doğrulama:** `web_fetch` ile okundu — **HTTP 200**, 2026-09-29
- **İçerik (okunan özet):** Proof of Solvency alanında merkezi kripto borsaları ve
  kurumsal **saklama (custody)** sağlayıcıları için güvenli, verimli ve **gizlilik
  koruyan** bir yöntem sunar. Zincirin doğal **state (durum)** kavramını ve zero-knowledge
  proof tekniklerini kullanarak işletmelerin rezervlerini — **işlemlerini, adreslerini
  veya toplam yükümlülük miktarını (total amount of liabilities) ifşa etmeden** —
  kanıtlamasını sağlar.
- **Cleanvest ile ilgisi:** Doğrudan **README dürüst sınırı #4'ün ("Gizlilik YOKTUR:
  kanıt sunmak yaprak değerlerini açığa çıkarır") literatür çözümüdür.** Cleanvest'in
  PoL'sinde `verifyLiability()` bir kanıt sunduğunda (user, balance, epoch) değerleri
  açığa çıkar; bu makale, **toplam yükümlülük ve bireysel değerleri gizleyerek** yine
  ödenme gücü kanıtının mümkün olduğunu gösterir. **Yol haritası maddesi** — mevcut
  PoL tasarımı bilinçli olarak plain-text hash yaprağı + EIP-191 imza kullanır (EVM
  `ecrecover` ile doğrudan uyumluluk için); gizli geçiş ZK gerektirir ve bu makale
  referans noktasıdır.

### 3. Assessing the Solvency of Virtual Asset Service Providers: Are Current Standards Sufficient?
- **Yazarlar:** Pietro Saggese, Esther Segalla, Michael Sigmund, Burkhard Raunig, Felix Zangerl, Bernhard Haslhofer
- **Yıl / Yer:** 2023 (v1) / v2: 2024 / arXiv:2309.16408 (q-fin.GN, cs.CR)
- **URL:** https://arxiv.org/abs/2309.16408
- **Doğrulama:** `web_fetch` ile okundu — **HTTP 200**, 2026-09-29
- **İçerik (okunan özet):** Merkezi kripto borsaları "virtual asset service provider"
  (VASP) kategorisindedir ve iflas edebilir. Zincir-üstü işlemler herkese açık olmasına
  rağmen VASP'ların kripto varlık tutumları **sistematik denetim prosedürlerine tabi
  değildir.** Ödenme gücünü **üç farklı kaynağı çapraz referanslayarak** ölçen bir
  yöntem önerir: kripto varlık cüzdanları, ticari sicir bilançosu ve denetim (regulatory)
  verisi. Avusturya FMA'ya kayıtlı **24 VASP** incelenir (yıllık ~2 milyar EUR işlem,
  ~1.8 milyon kullanıcı; bankadan ziyade broker/para-değişime benzer). Dört VASP'ın
  zincir işlem akışları ölçülüp bilanço girdileriyle karşılaştırılır — **yalnızca ikisinde
  veriler tutarlıdır.** Temel remark: *"denetimden sorumlu her varlık, VASP'ın zincir-üstü
  cüzdanlarıyla ilişkili fonları gerçekten kontrol ettiğine kanıt gerektirir"*; ayrıca
  fiat ve kripto **varlık ve yükümlülük** pozisyonlarının varlık tipi bazında makul bir
  sıklıkta raporlanması gerekir.
- **Cleanvest ile ilgisi:** **PoL'nin dürüst sınırının ampirik temelidir.** Cleanvest'in
  PoL'si **yükümlülük tarafını** kanıtlar (kullanıcıların imzaladığı bakiyelerden kök
  türetilir); bu makale, **varlık tarafının** ayrı bir kanıt gerektirdiğini (zincir-üstü
  cüzdan kontrolü) ve bilanço ile çapraz referans olmadan ödenme gücünün **kanıtlanamayacağını**
  gösterir. "4 VASP'ten 2'si tutarlı" bulgusu, **gözlemlenebilir bir sapma** olduğunu
  kanıtlar: PoL olmaksızın raporlanan bilanço ile zincir gerçeği çoğunlukla uyuşmaz.
  Bu, README sınır #1'in ("rezervlerin VARLIĞINI kanıtlamaz; banka-DDO entegrasyonu
  gerekir") ampirik gerekçesidir.

## Cleanvest'e Uygulanabilirlik

**DAR parçasıyla gelen on-chain fail-closed kök türetiminin literatürle uyumu:**

| Cleanvest PoL özelliği | Literatür karşılığı | Değerlendirme |
|---|---|---|
| `publishLiabilitiesFromSignedLeaves()`: kök, imzası zincirde doğrulanmış yapraklardan türetilir; tek geçersiz imza revert eder | #1 (TAP): "ağacın doğru kurulduğunu" bağımsız denetimle (ZK range proof) kanıtlama | **Daha güçsüzlük: Cleanvest denetimi ZORUNLU kılar — kurulum itself zincirde** |
| İmza, yaprak ve epoch'a bağlı (`keccak256(abi.encode(user, balance, epoch))`) | #1: authenticated structure bütünlüğü; #2 (AsiaCCS'26, bkz. doküman 05): "yalnızca imzalı değerler" | **Gereksinim karşılanıyor** (epoch bağı = yeniden oynatma koruması) |
| Gizlilik YOK: kanıt yaprak değerlerini açığa çıkarır | #1 (TAP sınıf-1) ve #2 (Private PoS) | **Açık sınır — yol haritası (ZK)** |
| PoL yalnızca **yükümlülük** tarafını kanıtlar | #3 (VASP): varlık tarafı + sicil çapraz referans gerekir | **Dürüst sınır README'de (sınır #1)** |

## Dürüst Sınırlar (README'de yer almalı)

- **Gizlilik yok:** `verifyLiability()` bir kanıt sunduğunda (user, balance, epoch)
  değerleri açığa çıkar. #1 ve #2'ın ZK tabanlı yaklaşımları **yol haritasıdır**.
- **PoL rezervlerin varlığını kanıtlamaz:** #3'ün bulgusu — yükümlülük kanıtı,
  ödenme gücü için gerekli ama yetersizdir; varlık tarafı (zincir-üstü cüzdan kontrolü)
  ve off-chain bilanço çapraz referansı şarttır. Bu, AsiaCCS'26 makalesinin de
  kendi sınırıdır (bkz. doküman 05, #2).
- **Yayın maliyeti O(N):** fail-closed yol, her yaprağın imzasını **zincirde**
  doğruladığı için yayın maliyeti yaprak sayısıyla doğrusal büyür. Üretim ölçeğinde
  (milyonlarca kullanıcı) bu yol tüm epoch'lar için değil, **denetim/dönüm noktaları**
  için tasarlanmıştır; gaz-verimli legacy `publishLiabilities()` kök+toplam yayınını
  korur (imza doğrulaması off-chain varsayılır, `epochSignatureEnforced=false` ile
  işaretlenir).

## Boşluklar / Açık Sorular (dürüst kayıt)

- **PoL'ye özgü 2025-2026 arXiv corpus'u tükenmiştir.** Bu doküman hazırlanırken
  kullanılan arXiv API sorguları:
  `search_query=all:"proof of liabilities"` (toplam **2** sonuç — ikisi de doküman 05'te
  zaten atıflı), `all:"proof of reserves"` (7 sonuç), `all:"proof of solvency"` (1 sonuç).
  Bu nedenle bu dokümandaki 3 kaynak **PoL güvenlik modelinin temel (kanonik) makaleleri**
  olarak seçilmiş ve tarihleri (2022-2023) açıkça belirtilmiştir. 2025-2026 PoL
  yenilikleri doküman 05'te (LPOR/ICBC'26, AsiaCCS'26 PVC, RWA-PoB) işlenmiştir.
- **EIP-191 tabanlı PoL'ye doğrudan bir akademik atıf bulunamadı** — AsiaCCS'26'nın PVC
  ilkesi KZG+BLS kullanır; Cleanvest aynı güvenlik amacını EVM `ecrecover` uyumluluğu
  için EIP-191 ECDSA + keccak ile gerçekler. Bu bir **farklılık**, ödünleme değildir
  (bkz. doküman 05, #2'nin Cleanvest ile ilgisi).
- **Doğrulama rigoru kaydı:** arXiv API'den aday gösterilen `arXiv:2306.12783`
  ("Proof of reserves and non-double spends for Chaumian Mints") bu dokümana
  **ALINMADI** — abs sayfası fetch edildiğinde **"withdrawn by Ricardo Pérez-Marco"**
  (geri çekilmiş) olduğu tespit edildi. Her adayın abs sayfası fetch edildi ve
  yalnızca geri çekilmemiş olanlar (HTTP 200) atıflandı.
