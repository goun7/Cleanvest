# CLEANVEST: RATIFIED DESIGN RECORD v1.1 — KİLİTLENMİŞ KARARLAR VE AÇIK KALAN 3 LOOSE-END

> **Durum:** ✅ **ONAYLANDI (RATIFIED)** — Antigravity ajanı ve kullanıcı ile karşılıklı onaylanmıştır.  
> **Önceki Çelişen Dokümanlar:** `PROJE_KAGIDI.md` §4.2/§7, `03_...` §1/§2/§3, `07_...` İllüzyon-2/İllüzyon-3, `08_...`, `09_...` — bu doküman **önceliğe sahiptir**, çelişen tüm maddiler geçersizdir.

---

## 0. Ratified Blueprint (Tek Bakışta)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        CLEANVEST $cUSD — RATIFIED v1.1                        │
│                                                                              │
│  [YATIRIMCI $100 GİRER] ──► VARLIK TARAFLI RESERVE (100%)                     │
│    ├─ %40  BUIDL (gerçek getiri ~%3.5, iş-günü itfa)                          │
│    ├─ %10  Delta-neutral basis (%8 farazi)                                    │
│    └─ %50  ANLIK USDC TAMPOU (akıllı sözleşmede, 7/24)  ← soğuk başlama       │
│                                                                              │
│  [KURUCU: $3.000 AYRI JUNIOR ANAPARASI] ──► FIRST-LOSS DİLİMİ                 │
│    └─ Toplam teminat = $103 (her $100 cUSD için %3 fazla teminat)             │
│                                                                              │
│  [HARD INVARIANT: JuniorReserve ≥ TVL × %3]                                  │
│    ├─ Sağlanmazsa → YENİ cUSD MİNT'İ KİLİTLİ                                 │
│    └─ ÇEKİMLER (redemption) ASLA KİLİTLİ DEĞİL                                │
│                                                                              │
│  [GETİRİLER] Senior %3.35 (soğuk) → %3.84 (olgun)  |  Junior ~%10            │
│  [$cUSD] Sabit $1.00, REBASE YOK. Yield yalnızca $scUSD ERC-4626 kasasında.  │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 1. Kilitlenen 4 Karar + Mimari Teyit

### KARAR 1: Likit Tampon Dış Sermaye İstemiyor (Kullanıcı Kararı)
**Onaylandı.** %35-%45'lik anlık USDC kompozisyonu, yatırımcıların yatırdığı anaparanın **varlık tarafında** tutulur — kurucunun cebinden çıkmaz.

**Mimari teyit (neden bu doğru):** Soğuk-başlama kompozisyonunda %40-50'lik likit tampon, **ampirik hafta-sonu run talebiyle (48 saatte arzın %30-50'si) aynı magnitüdde.** Önceki %10'luk tampon bu talebin 3-5 kat altındaydı; %40'lık tampon merkezi senaryoyu karşılıyor. **İşte "dış sermaye gerekmiyor" yanıtının matematiksel sebebi bu:** tampon, reserve'in içinde büyüdüğü için run talebiyle birlikte otomatik ölçeklenir. Kurucu $0 ek sermaye koymadan %40 tampon, $100k TVL'de $40k-50k anlık likidite demektir.

### KARAR 2: Junior Anapara Modeli (B + C Kombini)
**Onaylandı.** Kurucu/hazineden yalnızca **$3.000 tohum**; sözleşmeye hard invariant yazılır.

**Teyit — kapasite aritmetiği tutarlı:**
$$\text{Maks TVL (tohum kapasite)} = \frac{\$3.000}{0{,}03} = \mathbf{\$100.000}$$
Yani $3.000 tohum, tam %3 kapsamada **tam $100k TVL'ye kadar** yeter. Kullanıcının "$100.000'ı aşmak istediğinde" eşiği bu yüzden tam $100k'da — **aritmetik içten tutarlıdır.**

**Teyit — first-loss yapısı doğru kuruldu:** Junior, 100%'lik reserve'in **içinden değil, ayrı $3.000'dan** oluşur. Her $100 cUSD için teminat $103 → senior **%3 fazla teminatlı (over-collateralized).** Bu, structured finance'in doğru okunuşudur.

**Teyit — büyüme yolu:** $100k'yı aşan her $1 TVL, $0.03 ek junior gerektirir. Üç kaynak: (1) dış junior staker'lar @ ~%10 kaldıraçlı getiri, (2) Faz-3 borsa komisyonları, (3) mevcut junior'un getirisinin reinvesti. Kurucu riski **$3.000 ile sınırlanmıştır.**

### KARAR 3: Boyut-Farkında Anti-Collusion ε + Emir Tavanı
**Onaylandı.** $\epsilon(\Delta Q) = 0{,}15\% + \kappa \cdot \Delta Q / L_{\text{onchain}}$; soğuk başlamada emir başına **$5.000 tavan.** Artık Uniswap v3'ün doğal kayması kendi büyük emirlerimizi haksız reddetmeyecek.

### KARAR 4: Sıfır-CAC İç Ekosistem Müşteri Stratejisi
**Onaylandı.** İlk müşteriler: **Unpump.cash, Tamga Protocol, KÖK Network + 26 projelik portföy.** Dışarıda tanınmayan bir araçla soğuk satış yerine, kendi sözleşmelerimiz taranıp bulgular kapatılır → **görünebilir canlı vaka çalışması.**

---

## 2. Önceki Çelişkilerin Artık Çözüldüğü Yerler

| Önceki Çelişki | Çözüm | Durum |
|---|---|---|
| Rebase'li $cUSD ( Terra-mekanizması riski) | $cUSD sabit $1.00, rebase **tamamen silindi**; yield yalnızca `$scUSD` ERC-4626 | ✅ |
| Negatif spread (−1.47 puan) | Gerçek blended ( %3.55 soğuk / %4.03 olgun) + dürüst getiri eğrisi | ✅ |
| Junior lansmanda $0 | $3.000 tohum + hard mint-kapı | ✅ |
| "%5.10 BUIDL getiri" ( uydurma) | Gerçek %3.5 (rwa.xyz doğrulaması) | ✅ |
| "Sıfır kayma" yanılgısı | İç eşleşmede sıfır; dış rotada **açıklanan** kayma | ✅ |
| 10ms vs 500ms latans | **T_batch = 400ms sabit**; UI batch kapanışını dürüst gösterir | ✅ |
| Dairesel oracle ( Uniswap TWAP) | **Bağımsız oracle (Chainlink Base)**, TWAP yalnızca çapraz-kontrol | ✅ |
| Kendi-kendini-vuran ε freni | Boyut-farkında ε + $5k emir tavanı | ✅ |
| $294k/ay B2B fantazisi | İç portföy önce ( sıfır CAC) → kamu kanıtı → dış satış | ✅ |

---

## 3. ⚠️ Açık Kalan 3 Loose-End (Kodlamadan Önce Kapatılmalı)

Kararlar kilitlendi ama üç teknik detay **henüz tanımlanmamış.** Bunlar mimari olarak benim sorumluluğumda:

### LE-1: Redemption Katmanı Hâlâ Yazılmadı (En Önemlisi)
%40'lık tampon merkezi run senaryosunu karşılıyor — **ama kuyruğun %50+ kuyruk ucunu değil.** Açıkça kodlanmış şeffaf katman şart:

$$\text{Çekim} \le \underbrace{\text{buffer}\%}_{\text{ANLIK}} \;\; \text{üstü} \;\; \underbrace{\text{T+1 / T+2}}_{\text{şeffaf, sözleşmede}}$$

**Bu bir kusur değil, özelliktir** — ama **sözleşmede yazılı ve kullanıcıya önceden bildirilmiş** olmalı. Aksi halde "7/24 anında" vaadi, run anında gizli kapıya dönüşür ve güveni öldürür (doc-08 §2.6'nın çözümü budur).

### LE-2: $5.000 Emir Tavanının Kaldırma Tetiği Tanımlanmadı
Soğuk-başlama tavanı kalıcı olursa, borsa büyüse bile **kendi büyümemizi boğar.** Açık lift-trigger şart:

> **Önerilen tetik:** 30-günlük hacim > $250k **VEYA** ≥ 2 canlı RFQ çözücü → tavan otomatik $5k → $25k'ya, sonra kaldırılır.

### LE-3: İç Denetimin Çıkar-Çatışması İçin Bağımsız Doğrulama Şart
Kendi portföyümüzü kendimiz denetlemek **çatışma yaratır:** "Kendi projemizi taradık, tertemiz" dış dünyada inandırıcı değildir.

**İtibar, temiz skordan DEĞIL, açıklanan bulgudan gelir.** Vaka çalışması şunu içermeli:
1. **Gerçek kritik bulguları ve CVE-benzeri kayıtları yayınla** ( Unpump'da 3 kritik bulundu)
2. **Açık düzeltme diff'leri** + AutoVerus Z3 ispatıyla kapatıldığını kanıtla
3. **Düzeltmenin üçüncü-taraf re-verification'ı** ( CleanAudit dış bir doğrulayıcı veya kamu bug-bounty ile)

"Temiz" değil, **"bulduk, yayınladık, kapattık, kanıtladık"** dış müşteri için güvenilir vaka çalışmasıdır.

---

## 4. Sıradaki İnfaz Adımları (Mimar Sırası)

1. **LE-1 redemption katmanını** `$scUSD` vault sözleşmesine uygula ( en kritik)
2. **LE-2 lift-trigger** parametrelerini FBA motoruna config olarak yaz
3. **LE-3 denetim şablonunu** CleanAudit'a uygula → Unpump.cash üzerinde **ilk kamu denetimini** çalıştır
4. `08_...` ve `09_...`'daki master-şartname revizyon taleplerini ( E1/E2/E3 + `orderCommitmentRoot`) resmi olarak ilet

---

*Bu doküman **RATIFIED v1.1** olarak kanonik karar kaydıdır. Bundan sonraki tüm Cleanvest geliştirmesi bu dokümana göre yapılacaktır.*
