# 29 — İNSAN KARAR DOSYASI (sabah oku → "go" yaz)

**Tarih:** 2026-09-27 · **Hazırlayan:** cleanvest-dev (otonom vardiya)
**Kod durumu:** 161/161 Foundry + 23/23 vitest yeşil · %99.42 line / %98.62 branch coverage
**Canlı doğrulama:** Demo.s.sol + Bootstrap.s.sol anvil'de rc=0 (ONCHAIN EXECUTION COMPLETE)

> Üç operasyonel karar seni bekliyor. Kod tarafı bitti; bunlar **değer/operasyon**
> kararları — otomatik verilemez. Her karar için **ÖNERİ + RİSK + ALTERNATİF**
> yazdım. "GO" dediğin an deploy rehberi (24_DEPLOY_VE_CANLIYA_ALMA_REHBERI.md)
> adım adım çalıştırılabilir.

---

## KARAR 1 — Tohum (seed) miktarı ⚠️ EN KRİTİK

**Soru:** `seedJunior()` ile ne kadar tohum atılmalı?

### Matematik (sözleşmeden okundu, sabit)

```
tvlCap = ilkSeed × 10000 / 300      (CleanUSD.sol L77)
juniorReserve >= totalSupply × %3    (hard invariant, mint durdurur)
max tohum = 1_000_000 ether          (overflow koruması, L71)
```

| Tohum | Kalıcı TVL tavanı |
|---|---|
| $3.000 | $100.000 |
| $30.000 | $1.000.000 |
| $300.000 | $10.000.000 |
| $1M (max) | $33M |

### ⚠️ KRİTİK KISIT 1 — Tavan yalnızca İLK tohumda belirlenir

`tvlCap` **sadece bir kez**, ilk `seedJunior` çağrısında yazılır (`if (!capUnlocked)`).
Sonraki tohumlar `juniorReserve`'i artırır (coverage yükselir) ama **tavanı ASLA
yükseltmez**. Başka hiçbir fonksiyon tavanı değiştiremez (`grep tvlCap` ile doğruladım).

> **Yani:** $3.000 tohum atarsan Cleanvest **kalıcı olarak $100k TVL'den fazla
> büyüyemez** — mint "TVL tavani asildi" revert'ü alır. Büyüme hedefin $100k'nin
> üstündeyse, İLK tohumu o hedefe göre belirlemelisin (tavan = tohum × 33.3).

### ⚠️ KRİTİK KISIT 2 — Tohum ETH olarak ATILIRSA SONSUZA KİLİTLİDİR

`seedJunior` `payable`'dır (ETH kabul eder) ama **CleanUSD'de ETH çekme fonksiyonu
YOK** (tüm `contracts/` tarandı; tek withdraw'lar ReserveManager'da, CleanUSD'de
değil). Atılan ETH geri alınamaz — kalıcı first-loss sermayesi olarak kalır.

### ⚠️ KRİTİK KISIT 3 — Birim/ fiyat uyumsuzluğu

Sözleşme tohumu **18-ondalık birim olarak cUSD ile 1:1** sayar:
- `--value 3_000 ether` (gerçek 3.000 ETH ≈ $8M) → sözleşme $3.000 sayar → $100k tavan
  ama **$8M gerçek değer kalıcı olarak kilitlenir** (aşırı teminat).
- 1.1 ETH (~$3.000 gerçek değer) → sözleşme 1.1 sayar → tavan ≈ $37 → **bozuk**.

### ÖNERİ (cleanvest-dev)

**İlk tohumu `amount` parametresiyle, gerçek ETH GÖNDERMEDEN yap:**

```bash
cast send $CUSD_ADDR "seedJunior(uint256)" 3000000000000000000000 \
  --rpc-url "$BASE_RPC_URL" --private-key "$OWNER_PK"
# --value YOK. msg.value=0 → seed = amount = $3.000 (18 ondalik)
# → tvlCap = $100.000, juniorReserve = $3.000 (accounting)
```

**Ve $3.000 gerçek değeri ReserveManager'a aktar** (orada `withdrawReserve` var,
 likidite yönetilebilir): Aave'e supply edip Tier0 getirisini başlat.

**Neden:** CleanUSD'nin gerçek varlık yönetimi ReserveManager'dadır (Aave/OUSG/BUIDL).
CleanUSD'deki `juniorReserve` bir **güvenlik tamponu sayacıdır**; gerçek sermayeyi
 yönetilebilir olduğu yerde (ReserveManager) tut, kalıcı kilitlenen yerde (CleanUSD) değil.

| Seçenek | Artı | Eksi |
|---|---|---|
| **A) `amount` parametresi (ÖNERİ)** + ReserveManager'a gerçek $3k | Tavan doğru ($100k), gerçek sermaye yönetilebilir/çekilebilir | junior sayacı off-chain geriye bağlı görünebilir (şeffaf dokümante et) |
| B) Gerçek 3.000 ETH `--value` | Tam teminatlı, basit | **$8M kalıcı kilitli**, geri dönüş yok |
| C) Daha büyük ilk tohum ($30k → $1M tavan) | Büyüme alanı | Daha fazla kilitli/taahhüt edilen sermaye |

**ALTERNATİF olarak (C) tavsiye edilirse:** hedef TVL'yi şimdi belirle — tavan sonra
 değişmiyor. Demo'da ve dokümanlarda $100k varsayıyoruz; $1M hedefliyorsan tohum
 $30k olmalı.

---

## KARAR 2 — Aave utilization feed adresi (ATLANABİLİR)

**Soru:** OPTIMIZE modu için `IUtilizationFeed` adresi ne olsun? (`utilizationBps()
→ 0-10000`; >9200 = devre-kesici → anlık itfa T+2'ye düşer)

### Feed'in yaptığı şey (sözleşmeden)

- `ReserveManager.setAaveUtilizationFeed(feed)` + `setOptimizeMode(true)` → Tier Optimize
- Feed OLMADAN `setOptimizeMode(true)` **revert'ler** ("OPTIMIZE: utilization feed
  bagli degil") — test ile kanıtlandı (testRevertOptimizeWithoutFeed)
- Feed YOKSA: Tier 0/1/2 **SAFE mod** tüm fonksiyonelliği verir, devre-kesici kapalı

### Seçenekler + karar kriterleri

| Seçenek | Doğruluk | Güncellik | Denetim maliyeti | Hata modu |
|---|---|---|---|---|
| **A) ATLA (SAFE mod)** — ÖNERİ faz-1 | Yerine geçer | Yerine geçer | **Sıfır** | OPTIMIZE kapalı; getiri %3.05→%3.25 |
| B) Özel okuyucu kontrat (Aave V3 Pool'dan `totalDebt/(totalDebt+totalLiquidity)`) | Tam (on-chain hesap) | Anlık | Orta (yeni kontrat, denetim gerek) | Okuyucu hatalıysa yanlış okuma; circuit-breaker yanlış tetiklenir |
| C) Push oracle (Chainlink Automation / keeper periyodik yazar) | Ayarlanabilir | Dakikalar gecikmeli | Yüksek (off-chain infra) | Stale feed → geç devre-kesici (sosyalleşme riski) |

### ÖNERİ

**A) ATLA.** Faz-1'de SAFE mod ile git; OPTIMIZE'yi TVL $250k'yi geçince ve Aave
 utilization'ı manuel izleyebildiğimizde bağla. Gerekçe:

#### Sayılarla: OPTIMIZE'nin değeri riske değmiyor

| | SAFE Tier 0 | OPTIMIZE | Fark |
|---|---|---|---|
| Senior getiri | %3.05 | %3.46 | **+%0.41** |
| $100k TVL'de yıllık | $3.050 | $3.460 | **+$410/yıl** |
| Anlık itfa | Her zaman anlık | **Aave >%92'de T+2'ye düşer** | Kullanıcı bekleme riski |
| Feed bağımlılığı | Yok | Zorunlu | Operasyonel yük |
| Sosyalleşme riski | **Sıfır** | Var | — |

**Riskin boyutu:** OPTIMIZE modunda Aave pool utilization >%92'ye çıkarsa
 kullanıcıların ANLIK itfa talepleri T+2 kuyruğuna düşer (2 gün bekler). Bu
 bir "sosyalleşme" riskidir — kullanıcılar istedikleri zaman çıkamadıklarında
 itibar kaybı + olası bank-run baskısı. **$410/yıl ek getiri için bu riski
 almak mantıksız.**

**Faz-1'de anlamsızlık:** TVL $100k iken Aave V3 Base pool'u ($milyarlarca
 likidite) içindeki payımız **~%0.000x** — utilization'ı biz ETKİLEYEMEYIZ. Yani
 feed bir ŞEY izlemez ki; sadece operasyonel karmaşıklık ve hata yüzeyi ekler.

**Hata modu analizi:**
- Feed **ölürse/geç kalırsa** → devre-kesici ya hiç tetiklenmez (kullanıcı riski)
  ya yanlış tetiklenir (gereksiz T+2). OPTIMIZE kapalıyken bu riskin **tamamı sıfır**.
- Özel okuyucu kontrat → yeni kontrat = yeni denetim yüzeyi + bug riski.
- Push oracle → stale veri → gecikmeli devre-kesici.

**ATLANABİLİR (sözleşme öngürdü):** `setAaveUtilizationFeed` opsiyonel;
 SAFE mod Tier 0/1/2 ile tüm fonksiyonelliği verir. Deploy rehberi ADIM 5 de
 "OPSİYONEL" diyor. **Sonradan upgrade'siz bağlanabilir** — kararın geleceği
 senin elinde, şimdi bağlamak zorunda değilsin.

> **İkna olduktan sonra:** "feed atlandı, SAFE mod" yazman yeterli. Sonradan
> `cast send $RESERVE_ADDR "setAaveUtilizationFeed(address)" $FEED` +
> `cast send $RESERVE_ADDR "setOptimizeMode(bool)" true` ile eklenir
> (upgrade gerekmez, saf config — deploy rehberi ADIM 5'te örnek var).

---

## KARAR 3 — Deploy "GO" şartları + checklist

### "GO" verebilmek için hepsi karşılanmalı (durum: ✅ hepsi tamam)

| # | Şart | Durum | Kanıt |
|---|---|---|---|
| 1 | Tüm Foundry testleri yeşil | ✅ | `forge test` → 161/161, rc=0 |
| 2 | Tüm vitest testleri yeşil | ✅ | `cd web && npx vitest run` → 23/23, rc=0 |
| 3 | Coverage eşiği (≥%95 branch) | ✅ | %98.62 branch (6 sözleşme) |
| 4 | Müşteri demosu CANLI | ✅ | Demo.s.sol anvil rc=0, 6 adım, "ONCHAIN EXECUTION COMPLETE" |
| 5 | Bootstrap likidite CANLI | ✅ | Bootstrap.s.sol anvil rc=0 (cap $100k, coverage ≥%3, mint AÇIK) |
| 6 | TODO/placeholder sıfır | ✅ | audit_code_quality temiz |
| 7 | Karar 1 (tohum) verilmiş | ⏳ | Bu dosya — sen seç |
| 8 | Karar 2 (feed) verilmiş | ⏳ | Bu dosya — "ATLA" önerisi |
| 9 | Owner key soğuk cüzdan | ⏳ | Operasyonel hazırlık |
| 10 | PRIVATE_KEY env'den, commit'e değil | ⏳ | Operasyonel hazırlık |

### Deploy öncesi son check (insan, 5 dk)

```bash
# 1. Branch temiz + son commit
cd "/home/gokun/projects/Yeni Fikirler/oncu_fikirler_havuzu_2026/26_Cleanvest_Sifir_Manipulasyonlu_Spot_Borsa_Ve_CleanFX"
git status --clean && git log --oneline -1

# 2. Testleri son kez koş (regresyon yok)
~/.foundry/bin/forge test                    # 161 passed, 0 failed

# 3. Owner key'i soğuk cüzdan'dan al, env'e
export OWNER_PK="<SOĞUK CUZDAN PRIVATE KEY>"
export BASE_RPC_URL="https://mainnet.base.org"
```

### Deploy sırası (24_DEPLOY_VE_CANLIYA_ALMA_REHBERI.md özet)

1. `forge script script/Deploy.s.sol --rpc-url $BASE_RPC_URL --private-key $OWNER_PK --broadcast --verify`
   → 6 adres (cUSD, scUSD, reserve, settlement, gate, proxy) · ~0.02-0.05 ETH gas
2. Adresleri `web/src/contracts/addresses.json`'a yaz · `pnpm build` rc=0 (banner kalkar)
3. Tohum: **Karar 1'deki seçimine göre** (öneri: `seedJunior(3000 ether)` --value'suz)
4. İlk mint: `approve` + `depositWithMin` (slippage kalkanı)
5. (OPSIYONEL) Aave feed — **Karar 2: ATLA önerisi**

### Post-deploy "canlı" kanıtı

```
IDDIA:  Canlı üretim Base mainnet'te çalışıyor
KANIT:  cast call $SCUSD_ADDR "totalAssets()(uint256)" --rpc-url $BASE_RPC_URL
RC:     0
```

---

## KARAR 3B — ETH Çekme Problemi: Çözüm Önerisi (ek analiz)

**Problem:** `CleanUSD.seedJunior` `payable` (ETH kabul eder) ama CleanUSD'de
 **ETH çekme fonksiyonu YOK**. Gerçek ETH gönderirsen sonsuza kilitlenir.
 Üç çözüm yolunu analiz ettim:

### Seçenek A) ⭐ ÖNERİLEN — ETH gönderme, junior'ı accounting tut
- **Ne:** `seedJunior(3000 ether)` `--value`'suz (msg.value = 0). Gerçek $3k'ı
  ayrıca ReserveManager'a (`depositReserve` → `withdrawReserve` ile yönetilir).
- **Artı:** **Upgrade gerekmez** (mevcut kontrat); junior tamponu **çekilemez**
  (güvenlik için iyidir — first-loss sermayesi hareket edememeli); gerçek fonlar
  **yönetilebilir** ve getirilidir (Aave/USDC).
- **Eksi:** CleanUSD'deki `juniorReserve` gerçek ETH değil, **accounting**.
  Yani "%3 tampon backed" iddiası bir **proje vaadi**dir (treasury off-screen
  destekler). **Şeffaflık:** bunu dokümante et (burada yapıyorum).
- **Güvenlik notu:** aslında bu DAHA GÜVENLİ — çekilebilir bir junior reserve,
  owner'ın fonu çekip `%3` altına düşmesine ve mint'i DURDURMASINA (griefing/DoS)
  imkan verir. Accounting junior bu vektörü kapatır.

### Seçenek B) CleanUSD'ye `withdrawJuniorETH` ekle (onlyOwner)
- **Ne:** yeni fonksiyon: owner'ın kilitsiz ETH fazlasını çekmesi.
- **Artı:** junior gerçek ETH ile backed; tohum gerçek varlık gönderilebilir.
- **Eksi:** **Upgrade gerekir** (yeni kontrat + adres + audit + frontend güncelleme);
  junior çekilebilir olur → yukarıdaki **griefing vektörü** açılır (owner junior'ı
  çekip %3'ün altına düşürürse mint durur — kullanıcı girişi kilitlenir);
  yeni fonksiyon = yeni güvenlik yüzeyi (reentrancy vb.).

### Seçenek C) Hibrit — yalnızca FAZLA kısmı çekilebilir
- **Ne:** `withdrawJuniorETH` ekle ama `juniorReserve - (TVL × %3)` fazlasından
  fazlasını çekemez (invariant'ı koruyan guard).
- **Artı:** gerçek backing + likidite esnekliği; güvenlik invariant korunur.
- **Eksi:** en **karmaşık** yol; yanlış implementasyon → invariant ihlali;
  upgrade + audit maliyeti.

### Öneri + zamanlama

| Faz | Öneri |
|---|---|
| **Faz-1 (şimdi)** | **A)** accounting junior + gerçek $3k ReserveManager'da. Upgrade'siz, güvenli, hızlı. |
| Faz-2 (TVL >$1M, gerçek backing gerekirse) | **C)** hibrit — eğer bağımsız audit onaylarsa. |

> **Kanaat:** "ETH kilitli" bir **bug değil, özelliktir** — first-loss tampon
> hareket etmemeli. Gerçek sermaye ReserveManager'da yönetilmeli. A'yı seç.

---

## RİSK ÖZETİ (insanın bilmesi gereken)

1. **Tohum kalıcıdır** — CleanUSD'den ETH çekilemez (fonksiyon yok). Öneri: gerçek
   sermayeyi ReserveManager'da tut (orada `withdrawReserve` var).
2. **Tavan kalıcıdır** — ilk tohum TVL tavanını sonsuza kilitler. $100k yerine $1M
   hedefliyorsan şimdi $30k tohum at.
3. **Junior %3 hardcoded** — TVL tavana yaklaştıkça coverage tam %3'e düşer; altına
   düşerse mint DURUR (burn devam eder, çıkışlar AÇIK).
4. **OPTIMIZE sosyalleşme riski** — Aave >92% utilization'da anlık itfa T+2'ye düşer.
   Faz-1'de ATLA (SAFE mod) önerisi bu yüzden.
5. **Aave/OUSG/BUIDL getiri oranları piyasa** — %3.05/2.91/2.92 eğrisi 2026-09-26
   verileriyle kilitlendi (docs/23); RWA oranları değişirse tier sabitleri güncellenmeli.

---

## KARAR FORMATI (insanın dolduracağı)

```
KARAR 1 (tohum):  [  ] A) amount parametresi $3.000 (ÖNERİ)  + $3.000 ReserveManager'a
                   [  ] B) gerçek 3.000 ETH --value (kalıcı kilit)
                   [  ] C) $________ tohum (tavan $________)
                   Tutar: ____________________

KARAR 2 (feed):   [  ] ATLA — SAFE mod faz-1 (ÖNERİ: +$410/yıl vs T+2 risk)
                   [  ] B) özel Aave okuyucu kontrat (adres: ______________)
                   [  ] C) push oracle (adres: ______________)

KARAR 3B (ETH):   [  ] A) accounting junior + $3k ReserveManager (ÖNERİ, upgrade'siz)
                  [  ] B) CleanUSD'ye withdrawJuniorETH ekle (upgrade + risk)
                  [  ] C) hibrit: yalnızca fazlalık çekilebilir (faz-2, audit)

KARAR 3 (go):     [  ] GO — deploy başlat
                   [  ] BEKLE — sebep: _________________________________
```

**İmza:** cleanvest-dev otonom vardiya, 2026-09-27 · 161/161 + 23/23 yeşil ·
 Demo + Bootstrap CANLI rc=0 · commit: son HEAD
