# CLEANVEST: JUNIOR FİNANSMAN MATEMATİĞİ, SOĞUK-BAŞLAMA LİKİDİTESİ VE FAZ-1 MÜŞTERİ GERÇEĞİ (v1.0)

> **Kapsam:** Antigravity Ajanı'nın "3 Kör Nokta" eleştirisine mimari + finansal mühendislik yanıtı  
> **Önceki Doküman:** `08_MASTER_SARTNAME_DENETIMI_VE_KRITIK_YANITLAR.md`  
> **Kabul Edilen Düzeltmeler:** (1) rebase tamamen silindi → sabit $cUSD + $scUSD ERC-4626 kasası, (2) FBA süresi 400ms sabitlendi.

---

## 0. Özet Karar Tablosu

| Kör Nokta | Hükmüm | Yeni Bulgu |
|---|---|---|
| **Junior'i kim fonlayacak?** | ✅ **Getirisi kendini finanse ediyor** — ama PRİNCİPAL + TVL ölçeklenmesi governance gerektirir | 3%'lik Junior, blended 4.08%'den **%9.9 getiri** üretir (senior'dan sadece 0.18 puan fedakârlık). Eski planımız junior için **%29.75** ima ediyordu → 5.5% figürü uydurmaydı |
| **İlk likidite / çözücü eksikliği** | ✅ **Doğru, kabul** — soğuk başlamada Uniswap kayması var | + içten keşfettiğim ek çatışma: **anti-collusion bound ε, soğuk başlamada kendi büyük emirlerimizi reddediyor** |
| **Somut müşteri listesi var mı?** | ❌ **HAYIR, yok** | Ama gerçek listemiz var: **kendi portföyümüz** (Unpump, Tamga, KÖK + 26 projelik havuz). Önce onları denetleriz → kamu kanıtı → dış müşteri |

---

## 1. Junior Getirisi Kendini Finanse Ediyor (Soruyu Yeniden Çerçeveleme)

Antigravity'nin sorusu "Junior'i kim fonlayacak?" — ama bu soru **getiri** ile **anapara** arasındaki kritik farkı gizliyor. İkisini ayırınca tablo değişir.

### 1.1 Dilim Aritmetiği: Junior Getirisi Ek Sübvansiyon İstemiyor

Reserve toplam TVL $T$ üzerinde blended getiri $R$ üretsin. Junior oranı $j$ iken:

$$(1-j)\,r_{\text{senior}} + j\,r_{\text{junior}} = R$$

**Düzeltilmiş reserve (örnek):** BUIDL %75 → %40, anlık likit %10 → %35, delta-neutral %15 (toplam %90; kalan %10 nakit tampon — aşağıdaki zamanla-değişen kompozisyon için bkz. §1.4). Cömert varsayımla:

$$R_{\text{blended}} = 0{,}75 \times 3{,}5\% + 0{,}15 \times 8\% + 0{,}10 \times 2{,}5\% = 2{,}63 + 1{,}20 + 0{,}25 = \mathbf{4{,}08\%}$$

**Junior $j = 3\%$, hedef junior getirisi $r_j = 10\%$:**

$$r_{\text{senior}} = \frac{R - j \cdot r_j}{1-j} = \frac{0{,}0408 - 0{,}03 \times 0{,}10}{0{,}97} = \frac{0{,}0378}{0{,}97} = \mathbf{3{,}90\%}$$

**Sonuç:** Senior sadece **4.08% → 3.90%** (0.18 puan) fedakârlıkla Junior'a **%9.9** getiri akar. Junior staker'larına 8-12% ödemek için hazineden tek kuruş çıkması gerekmez — **kaldıraçlı dilim yapısı getiriyi kendi üretir.**

| $r_j$ hedefi | $r_{\text{senior}}$ (blended 4.08%) |
|---|---|
| %8 | %3.96 |
| %10 | %3.90 |
| %12 | %3.84 |

### 1.2 💥 Adli Bulgu: Eski Sayılarımız İçinden Çıkmadı (5.5% Uydurmaydı)

Eski plana aynı formülü uygulayalım: $R = 5{,}5\%$, senior %4.75, $j = 3\%$:

$$0{,}055 = 0{,}97 \times 0{,}0475 + 0{,}03 \times r_j \;\Longrightarrow\; r_j = \frac{0{,}008925}{0{,}03} = \mathbf{29{,}75\%}$$

**Eski planımız, Hazine Bonosu teminatlı bir junior dilime %29.75 getiri ima ediyordu — matematiksel olarak absürt.** Bu, 5.5%/4.75% figürlerinin türetilmediğinin, yerinden uydurulduğunun **kanıtıdır.** Düzeltilmiş sayılarla %10 junior getirisi içten tutarlıdır.

### 1.3 ⚠️ Asıl Soru: PRİNCİPAL, Getiri Değil

Getiri sorununu çözdük. Ama junior **anaparası** ($3 \times$ TVL/100) lock'lanmalı ve **TVL büyüdükçe ölçeklenmeli.** İki gerçek kısıt:

1. **Sermaye Yeterlilik Sıralaması:** Junior, senior basılmadan ÖNCE var olmalı. $cUSD mint'leri, junior kapsama oranı düştüğünde durmalı.
2. **Dinamik Açık:** TVL $100k → $1M'a çıkarsa junior $3k → $30k'a çıkmak zorunda. Hazineden sürekli top-up, exchange komisyonları (Faz 3) olmadan imkansız.

**✅ Çözüm: TVL-Kapılı Mint (Hard Invariant)**

$$\text{mintGate}: \quad \frac{\text{JuniorReserve}}{\text{TVL}} \ge j_{\min} = 3\% \;\; \text{değilse} \;\; \text{cUSD mint'i durur}$$

**Çıkışlar ASLA kapatılmaz** (yalnızca girişi kapatırız; çıkış kapılamak güveni öldürür). Bu korumayı vaat değil, **koda işlenmiş zorunlu kural** yapar. Sonuç: $cUSD TVL'i, mevcut junior'ı aşan büyümeyi otomatik reddeder — "korumasız büyüme" imkansızlaşır.

### 1.4 Zamanla Değişen Reserve Kompozisyonu (Verki ↔ Likidite Diyali)

| Aşama | Likit | Delta-Neutral | BUIDL | $R_{\text{blended}}$ | $r_{\text{senior}}$ (jun %3 @ %10) |
|---|---|---|---|---|---|
| **Soğuk başlama** (itibar yok) | %40 | %10 | %50 | %3.55 | **%3.35** |
| **Olgun** (jun > %3, geçmiş var) | %15 | %15 | %70 | %4.03 | **%3.84** |

**⚠️ Pazarlama Gerçekliği:** Vaadimiz %4.80'dı. Dürüst yol: **%3.35 → %3.84'lik açıkça yayınlanan bir eğri.** Bu, "risksiz %4.80" vaadinden düşük — ama Terra-mekanizmasından ( §2.3, doc-08) kaynaklanan ölüm sarmalından tamamen korur.

### 1.5 💡 Kritik Yeniden Çerçeveleme: Junior SOLVANS'ı Kapsar, LİKİDİTEYİ Değil

Antigravity'nin "%3 junior ilk zararı karşılar" çerçevesi **yanlış riske kalibre edilmiş:**

| Risk | Büyüklük | Kim Kapsar? |
|---|---|---|
| **Solvans (kredi/faiz)** — BUIDL duration ~3-6 ay; +200bp şok → bucket'ın ~%0.5-1'i → **TVL'in ~%0.4-0.75'i** | küçük | **Junior (var.)** |
| **Likidite (Pazar akşamı run)** — ampirik talep 48 saatte arzın %30-50'si | **büyük** | **Anlık nakit tamponu — Junior DEĞİL** |

**Sebep:** Pazar günü BUIDL satamazsın (iş günü 2:30 PM ET wire kuralı, rwa.xyz ile doğrulandı). Junior anaparası bir Pazar itfa kuyruğunu **çözemez.** Öyleyse:

> **Lansmanın bağlayıcı kısıtı junior değil, likit tampon oranıdır — ve likit tampon, reserve kompozisyonunun içindedir, yani yatırımcıların kendi sermayesiyle finanse edilir; ek risk sermayesi GEREKMEZ.**

**Bu, Antigravity'nin "$15k-$30k nereden?" sorusunu küçültür:** $500k TVL'de junior $15k gerekir, ama $100k TVL'de yalnızca **$3k** — ve TVL-kapı, büyümeyi mevcut junior'a göre otomatik sınırlar. Finansman ihtiyacı, lansmanın büyüklüğüne bağlıdır ve mint-kapı onu güvenli tutar.

---

## 2. Soğuk-Başlama Likiditesi: Kabul + İçten Keşfedilen Ek Çatışma

### 2.1 Kabul: Uniswap Kayması Gerçek

RFQ çözücüler $10k/gün hacimli yeni bir borsaya gelmez (`07_...` İllüzyon-1'de zaten itiraf). Soğuk başlamada artık $\Delta Q$ Uniswap v3'e düşer ve **kullanıcı normal AMM kayması yaşar.** "Sıfır kayma" vaadi bu pencerede yanlıştır (doc-08 §1.2 ile uyumlu).

**✅ Mitigasyonlar:**
1. **Batch-Aralığı Netting:** Artık imbalance $\Delta Q$'yu hemen Uniswap'a yönlendirmek yerine, ardışık batch'ler boyunca yön-netleştir. Batch-1 +5 ETH alım imbalance'ı + Batch-2 −3 ETH → 3 ETH Uniswap routing tasarrufu. Kaymayı büyük emirlerde doğrusal-orantılı düşürür.
2. **Önceden-Ticari Şeffaflık:** İşlem öncesi quoter üzerinden beklenen kayma kullanıcıya gösterilir. "Sıfır kayma" değil, **"iç eşleşmede sıfır; dış rotada %X (açıkça gösterildi)"** dürüst sözleşme.
3. **DEX Agregasyon:** Uniswap v3 → en iyi fiyat için çok-DEX rotlama (1inch tarzı).

### 2.2 💥 Yeni Bulgu: Anti-Collusion Bound Kendi Büyük Emirlerimizi Reddediyor

`02_...` §3'teki kural: $P_{\text{best}} > P_{\text{Oracle}} \times (1+\epsilon) \Rightarrow$ REDDET, $\epsilon = 0{,}15\%$.

**Soğuk başlamada bu tetiklenir:** Uniswap v3'ün doğal kayması, büyük bir emirde kolayca %0.15'i aşar. Kendi güvenlik vanamız **kronik olarak büyük emirleri reddeder.**

**✅ Çözüm: Boyut-Farkında ε + Soğuk-Başlama Emir Tavanı**

$$\epsilon_{\text{bound}}(\Delta Q) = \epsilon_0 + \kappa \cdot \frac{\Delta Q}{L_{\text{onchain}}}, \qquad \epsilon_0 = 0{,}15\%$$

$\epsilon$, emir boyutunun mevcut zincir-üstu likiditeye oranıyla ölçeklenir; büyük emirler daha geniş bound, küçük emirler dar. Ayrıca soğuk-başlama döneminde **maksimum emir boyutu tavanı** (örn. eşik altı hacimde emir başına $5k) — $\epsilon$'ı aşan hiçbir emir girmez. Faz 3'te hacim gelince tavan kalkar.

---

## 3. Faz-1 Müşteri Listesi: DÜRÜST CEVAP HAYIR — Ama Somut Plan Var

### 3.1 Gerçek: Somut Dış Müşteri Listem YOK

Antigravity soruyu keskin sordu: *"$15k-$30k junior sermayesini Faz-1 CleanAudit satışlarından toplayacak müşteri listen hazır mı?"*

**Cevabım: HAYIR.** Ve nedenini de sayalım:
- İtibarsız, kamu geçmişi olmayan bir güvenlik CLI'sını VC destekli DeFi projelerine satmak (onlar zaten CertiK/OpenZeppelin ile çalışıyor) → dönüşüm **çok düşük**.
- `04_...` §3'ün "günde 20 başvuru, %10 dönüşüm, ~$300k/ay" figürü **fantazi** (doc-08 §3.2'de kanıtlandı).

**Gerçekçi huni matematiği (kademeli fiyatla):**

| Katman | Fiyat | $15k İçin Gerekli Satış | Gerçekçilik |
|---|---|---|---|
| Hızlı Z3 tarama | $299 | 50 müşteri | ❌ Yeni tool için çok soğuk satış |
| Fuzzing + yama | $1.490 | 10 müşteri | ⚠️ Zor ama mümkün |
| Kurumsal paket | $4.900 | 3 müşteri | ❌ İtibar gerekiyor, yok |

**Sonuç:** $15k-$30k, dış müşterilerden Faz-1'de **güvenilir şekilde üretilemez.** CleanScore kamu API'si itibar inşa eder ama bu **3-6 ay** alır — ki bu, Faz-2 $cUSD lansman takvimiyle çatışır.

### 3.2 ✅ Gerçek Liste: Önce Kendi Portföyümüz

Master şartname **beş projeyi**, portföy havuzu **26 projeyi** listeler. Hepsi akıllı sözleşme içerir ve hepsi denetime ihtiyaç duyar:

> **CleanAudit'un ilk müşterileri: Unpump.cash, Tamga Protocol, KÖK Network ve portföydeki diğer projelerdir.**

- **Anında, sıfır CAC, sıfır satış döngüsü.** Kardeş projelerin sözleşmelerini tarar, bulguları raporlar, yamaları uygularız.
- **Kamu Kanıtı Üretir:** Her iç denetim, dış müşteri için **görünebilir, doğrulanabilir, isimlendirilmiş bir vaka çalışması** olur. "Unpump.cash'i taradık, 3 kritik bulduk, kapattık" — satış buna benzer, hayali bir demoya değil.
- **Şeffaflık Notu:** Bu **dış nakit geliri değildir** (iç maliyet tahsisidir). Ama itibar varlığını inşa eder ve dış satışların önkoşuludur. Antigravity'e dürüstçe böyle sunarım.

### 3.3 Karar Zorlayıcı Fork (Kullanıcı Seçmeli)

$cUSD lansmanında junior zorunluluğu kritik yoldaysa, üç dürüst seçenek var:

| Seçenek | Ne Demek | Sonuç |
|---|---|---|
| **A. $cUSD'yı Faz 3'e kaydır** | Borsa + $cUSD birlikte; junior, Faz-1/2 B2B + iç denetim geliriyle toplanır | En güvenli; "getiri vaadi" 6 ay gecikir |
| **B. TVL-kapı + küçük lansman** | $100k TVL'de sadece $3k junior; mint-kapı büyümeyi junior'la sınırlar | Hızlı; ama düşük TVL'de likidite ince kalır |
| **C. Kurucu tohum junior'ı** | Kurucu $3k-$9k koyar (yaklaşık sunucu bütçesinin 3-6 katı, $1k bütçenin ötesinde) | Hızlı; kurucu risk sermayesi |

**Benim önerim: B + C kombine** — kurucu küçük bir tohum junior'ı + TVL-kapı, böylece lansman GÜVENLİ bir küçük ölçekte olur ve junior, junior-getirisi (%9.9) ve exchange komisyonları (Faz 3) ile organik büyür. **A**, yalnızca "düşük getiri vaadi" pazarlama için kabul edilemezse.

---

## 4. Antigravity'ye Geri Soru

> Senin "%85 En İyilenmiş" notunda junior'ı %3 TVL sabit maliyet gibi işledin. Ama §1.5'in sonucu şu: **junior solvans riskini (küçük: ~%0.4-0.75 TVL) kapsar; bağlayıcı lansman riski likidite tamponudur ve o reserve kompozisyonunun içinde, yatırımcıların kendi sermayesiyle finanse edilir.**
>
> Öyleyse sorum: **Likit tampon oranı için de mi dış sermaye talep ediyorsun, yoksa %35-%45 likit kompozisyonun yatırımcı sermayesiyle finanse edilebileceğini kabul mü ediyorsun?** Eğer ikincisi, Fonlanmamış Anapara sorunu yalnızca junior'ın $3k-$9k tohumuna iner — ki bu §3.3 Seçenek B/C ile kapanır.

---

*Bu doküman `09_...` olarak arşivlendi. `08_...` ile birlikte master şartname revizyon talebine eklenmelidir.*
