# 24 — DEPLOY VE CANLIYA ALMA REHBERİ (HITL minimum)

**Tarih:** 2026-09-25
**Amaç:** Kalan 3.6 puanlık operasyonel kısmı **insan için 5 dakikalık** copy-paste
adımlara indirmek. Her adımın doğrulama komutu vardır.

**Önkoşul:** Kod tarafı 100/100 — `forge test` 166/166 rc=0, deploy simülasyonu temiz.

> ## ✅ GO-READY — uçtan uca anvil'de koşuldu (taze zincir)
>
> **İnsan "GO" dediği an bu rehberin 5 adımı çalışmaya hazır.** Kanıt: tüm
> adımlar **taze anvil zincirinde sırayla koşuldu**, her adımın expected
> output'u aşağıda "GO-READY kanıtı" ile işaretli. Herhangi bir adımda
> sapma olursa dur ve [docs/29 RED FLAGS](docs/29_INSAN_KARARLARI.md)'a bak.
>
> | Adım | Komut | Kanıtlanan sonuç (anvil) |
> |---|---|---|
> | 1 Deploy | `forge script script/Deploy.s.sol --broadcast` | rc=0, 6 sözleşme, cUSD `0x5FbDB…` |
> | 2 Frontend | `addresses.json` + `pnpm build` | rc=0, banner kalkar |
> | 3 Tohum | `Bootstrap.s.sol` (ADIM 3) | `HAZIR: mint acik, cap $100k, junior %3`, **ETH=0** |
> | 4 Mint+deposit | `mint` → `approve` → `depositWithMin` | `status 1` ×3, `totalSupply = 1e21` |
> | 5 Feed | (ATLA önerisi) | — |
>
> **ETH kilitlenmedi kanıtı:** `cast balance $CUSD_ADDR` = **0** (Bootstrap
> sonrası). Önceki `--value` yöntemi 3.000 ETH'yi sonsuza kilitlerdi —
> düzeltme commit `615e171` + `d279cfe` ile kanıtlandı.
>
> **Tek komut ile tüm test + canlı doğrulama** (insan GO'dan önce koşabilir):
> ```bash
> export PATH="$HOME/.foundry/bin:$PATH"
> forge test && cd web && npx vitest run && cd ..
> # → 166 passed / 0 failed + 23 passed (regresyon yok)
> ```

> ⚠️ **OKUMADAN DEPLOY ETME:** [docs/29_INSAN_KARARLARI.md](docs/29_INSAN_KARARLARI.md)
> — 3 **geri dönülemez** kısıt var: (1) tohum miktarı **kalıcı TVL tavanını**
> belirler (sonradan değişmez), (2) CleanUSD'ye gerçek ETH gönderirsen **sonsuz
> kilitli** (çekme fonksiyonu yok), (3) tohum/cUSD **birim uyumsuzluğu**. ADIM 3'te
> bu kısıtlar adım adım tekrar geçer.

---

## ADIM 1 — Base Mainnet'e Deploy (2 dakika)

```bash
cd "/home/gokun/projects/Yeni Fikirler/oncu_fikirler_havuzu_2026/26_Cleanvest_Sifir_Manipulasyonlu_Spot_Borsa_Ve_CleanFX"
export PATH="$HOME/.foundry/bin:$PATH"

# Simulasyon (gercek tx yok, adresleri gosterir)
forge script script/Deploy.s.sol

# CANLI DEPLOY
# DIKKAT: script PRIVATE_KEY env'den okur (--private-key bayragi yetmez)
export PRIVATE_KEY="$DEPLOYER_PK"
forge script script/Deploy.s.sol \
  --rpc-url "$BASE_RPC_URL" \
  --private-key "$DEPLOYER_PK" \
  --broadcast \
  --verify
```

**Doğrulama:**
```bash
# CIKTIDAKI 6 adresi kaydet: cUSD, scUSD, reserve, settlement, gate, proxy
# rc=0 olmali; verify "Contract successfully verified" demeli
```

**Beklenen maliyet:** ~0.02-0.05 ETH gas (6 sözleşme, Base düşük fee).

---

## ADIM 2 — Adresleri Frontend'e Gir (30 saniye)

Deploy çıktısındaki adresleri `web/src/contracts/addresses.json`'a yaz:

```json
{
  "chainId": 8453,
  "CleanUSD": "0x...   <- cUSD adresi",
  "CleanFXVault": "0x... <- scUSD adresi",
  "ListingGate": "0x...  <- gate adresi"
}
```

**Doğrulama:**
```bash
cd web && pnpm build
# RC=0; tarayici acildiginda stat kartlarinda gercek degerler gorunmeli
# (deploy-bekliyor banner'i KAYBOLMALI)
```

---

## ADIM 3 — İlk Tohumla Cap'i Aç (1 dakika) ⚠️ GERİ DÖNÜLEMEZ ADIM

Bu adım **sadece owner** yapar. Tohum, junior %3 invariant'ı sağlar ve `tvlCap`'i
açar (soğuk başlama kilidi).

> ### ⚠️ KRİTİK KISITLAR — OKUMADAN ATLA (docs/29_INSAN_KARARLARI.md)
>
> **1. TAVAN KALICIDIR (geri alınamaz).** `tvlCap` **yalnızca İLK tohumda** bir kez
> yazılır (`CleanUSD.sol L77, if (!capUnlocked)`). Başka hiçbir fonksiyon tavanı
> değiştiremez. **Tohum miktarı = kalıcı TVL tavanı ÷ 33.3:**
>
> | Tohum | Kalıcı tavan | Tohum | Kalıcı tavan |
> |---|---|---|---|
> | $3.000 | **$100.000** | $30.000 | $1.000.000 |
> | $300.000 | $10M | $1M (max) | $33M |
>
> **$3k tohum atarsan Cleanvest ASLA $100k TVL'i geçemez** — mint "TVL tavani
> asildi" revert'ü alır. Hedefin $100k'nin üstündeyse tohumu ŞİMDİ büyütmen
> gerek (sonra yetişmez).
>
> **2. GERÇEK ETH GÖNDERİRSEN SONSUZA KİLİTLİ.** `seedJunior` `payable`'dır ama
> CleanUSD'de **ETH çekme fonksiyonu YOK** (tüm `contracts/` tarandı). Atılan ETH
> geri alınamaz. Bu yüzden aşağıdaki komut `--value` KULLANMAZ.
>
> **3. BİRİM UYUMSUZLUĞU.** Sözleşme tohumu 18-ondalık birim olarak cUSD ile 1:1
> sayar. `--value 3_000 ether` (gerçek 3.000 ETH ≈ $8M) gönderirsen sözleşme $3.000
> sayar → $100k tavan ama **$8M kalıcı kilitli**. 1.1 ETH (~$3.000 değer)
> gönderirsen sözleşme 1.1 sayar → tavan ≈ $37 → **bozuk**.

**ÖNERİLEN komut (docs/29 KARAR 1 ile uyumlu — `amount` parametresi, --value'suz):**

```bash
# DIKKAT: seedJunior CleanUSD'dedir (CleanFXVault'ta DEGIL) - cUSD adresini kullanin
# --value YOK: msg.value=0 → seed = amount (accounting) → tavan dogru, ETH kilitlenmez
cast send $CUSD_ADDR "seedJunior(uint256)" 3000000000000000000000 \
  --rpc-url "$BASE_RPC_URL" \
  --private-key "$OWNER_PK"
# $3.000 (18 ondalik) → tvlCap = $100.000, juniorReserve = $3.000 (accounting)
```

**VE gerçek $3.000'i yönetilebilir reserve'a aktar** (ReserveManager'da
`withdrawReserve` VAR — CleanUSD'de yok). Bu örnek Aave V3'e supply edip Tier0
getirisini (%3.05) başlatır:

```bash
# ReserveManager'a USDC/ETH reserve yatır (owner) — gercek varlik burada YONETILEBILIR
cast send $RESERVE_ADDR "depositReserve(uint256)" 3000000000000000000000 \
  --rpc-url "$BASE_RPC_URL" --private-key "$OWNER_PK"
# sonrasinda rebalance → Tier0 dagilim (%73 Aave / %12 idle / %15 Prime)
```

> **Neden ikiye bölündü?** CleanUSD'deki `juniorReserve` bir **güvenlik tamponu
> sayacıdır** (mint kapısı). Gerçek sermayeyi **yönetilebilir olduğu yerde**
> (ReserveManager — `withdrawReserve` ile çıkılır) tutuyoruz; kalıcı kilitlenen
> yerde (CleanUSD — çıkış yok) değil. Detay: docs/29 KARAR 3 (ETH çekme önerisi).

**Doğrulama:**
```bash
# juniorReserve >= 3% TVL invariant (CleanUSD adresi; BPS birimi: 300 = %3.00)
cast call $CUSD_ADDR "juniorCoverageBps()(uint256)" --rpc-url "$BASE_RPC_URL"
# >= 300 OLMALI (300 bps = %3.00)

# tvlCap acildi mi?
cast call $CUSD_ADDR "tvlCap()(uint256)" --rpc-url "$BASE_RPC_URL"
# 100000000000000000000000 ($100k) OLMALI — ⚠️ BU RAKAM KALICIDIR, bir daha degismez
```

---

## ADIM 4 — İlk Mint ile scUSD'i Canlandır (30 saniye)

> **Önkoşul:** Kullanıcının cUSD'ye sahip olması gerekir. Production'da müşteri
> cUSD'yi takas/kanal ile alır; aşağıda **owner'ın kullanıcıya mint** ettiği
> demo akışı var (canMint ADIM 3'ten sonra true olur).

**4a) Owner, kullanıcıya cUSD mintler:**

```bash
cast send $CUSD_ADDR "mint(address,uint256)" $USER_ADDR 1000000000000000000000 \
  --rpc-url "$BASE_RPC_URL" --private-key "$OWNER_PK"
```

**4b) Kullanıcı scUSD vault'a yatırır (slippage kalkanlı):**

```bash
# 1) cUSD onayi
cast send $CUSD_ADDR "approve(address,uint256)" $SCUSD_ADDR 1000000000000000000000 \
  --rpc-url "$BASE_RPC_URL" --private-key "$USER_PK"

# 2) Slippage-korumali depozito (ERC-4626 kalkani — donation attack'a karsi)
#    minAssets: 1000 cUSD'nin %99.9'u (1e18 tolerans)
cast send $SCUSD_ADDR "depositWithMin(uint256,address,uint256)" \
  1000000000000000000000 $USER_ADDR 999000000000000000000 \
  --rpc-url "$BASE_RPC_URL" --private-key "$USER_PK"
```

**Doğrulama:**
```bash
# kullanicinin cUSD bakiyesi (mint sonrasi)
cast call $CUSD_ADDR "balanceOf(address)(uint256)" $USER_ADDR --rpc-url "$BASE_RPC_URL"
# 1000000000000000000000 OLMALI (1000 cUSD)

# allowance (approve sonrasi)
cast call $CUSD_ADDR "allowance(address,address)(uint256)" $USER_ADDR $SCUSD_ADDR --rpc-url "$BASE_RPC_URL"
# 1000000000000000000000 OLMALI (1000 cUSD)

# scUSD arzı (deposit sonrasi)
cast call $SCUSD_ADDR "totalSupply()(uint256)" --rpc-url "$BASE_RPC_URL"
# 1000000000000000000000 OLMALI (1000 scUSD — 1:1 giris)
```

> **GO-READY kanıtı (anvil, taze zincir):** yukarıdaki tüm komutlar
> sırayla koşuldu — `status 1 (success)` her birinde, `totalSupply = 1e21`.
> Ayrıca `Demo.s.sol` aynı akışı 6 adımda script ile gösterir (bkz.
> [docs/29](docs/29_INSAN_KARARLARI.md) "EK — ANVİL DOĞRULAMASI" Adım 5).
> **Güvenlik:** `depositWithMin` donation attack'e karşı slippage kalkanıdır —
> plain `deposit` KULLANILMAZ (docs/30 Vektör 1).

---

## ADIM 5 (OPSİYONEL) — Optimize Modu için Aave Feed

> **ÖNERİ: ATLA — SAFE mod faz-1 için yeterli.** Gerekçe ve alternatifler için
> bkz. [docs/29_INSAN_KARARLARI.md KARAR 2](docs/29_INSAN_KARARLARI.md).
> Özet: OPTIMIZE getiri %3.46 vs SAFE Tier0 %3.05 (+%0.41) ama **sosyalleşme
> riski** taşır (Aave >%92 utilization'da anlık itfa T+2'ye düşer). Faz-1'de
> TVL küçük, Aave utilization'ımız anlamsız → feed operasyonel karmaşıklık
> katar, değer katmaz. **ATLANABİLİR** — Tier 0/1/2 SAFE mod tüm
> fonksiyonelliği sağlar; `setAaveUtilizationFeed` opsiyoneldir, sonradan
> upgrade'siz eklenebilir.

Tier "Optimize" modu Aave utilization feed'ine ihtiyaç duyar (feed olmadan
`setOptimizeMode(true)` revert'ler — test ile kanıtlandı). İnsan kararı:
Chainlink veya Aave V3 base-rate oracle adresini `ReserveManager`'a girin.

```bash
# SADECE insan "feed bagla" derse calistir (oncelik: ATLA onerisi)
cast send $RESERVE_ADDR "setAaveUtilizationFeed(address)" $FEED_ADDR \
  --rpc-url "$BASE_RPC_URL" --private-key "$OWNER_PK"
# ardindan optimize acilabilir (feed bagliyken):
cast send $RESERVE_ADDR "setOptimizeMode(bool)" true \
  --rpc-url "$BASE_RPC_URL" --private-key "$OWNER_PK"
```

---

## KANIT PROTOKOLÜ (her adım için)

```
IDDIA:  [yapılan iş]
KANIT:  [yukarıdaki doğrulama komutu]
RC:     0
DOSYA:  [ilgili dosya]
COMMIT: [git hash]
```

---

## RİSK NOTU

- **Private key'ler asla commit edilmez** — `.gitignore` zaten `node_modules/` ve
  build çıktılarını kapsıyor; key'leri **ortam değişkeni** olarak geçirin
- **Owner key'i soğuk cüzdan** kullanmalı (mint-halt yetkisi var)
- **Deploy sonrası**: `seedJunior` YALNIZCA owner; sıradan kullanıcılar
  `depositWithMin` ile girer — fonksiyon doğru nonce ile gas-limit içinde
  gönderilmelidir
- **Çıkışlar kilitlenmez**: gunluk %10 anlık, üstü T+2 kuyruk (sözleşme invariant)

---

## İLK 24 SAAT İZLEME (deploy sonrası)

5 adım bitince deploy kapanmaz — **ilk 24 saat** sistem canlıdır ve aşağıdaki
üç metrik izlenir. Her biri için **eşik** ve **müdahale** tanımlıdır; insansız
alarm yok, değerleri elle okuyun.

### 1. TVL — beklenti: ADIM 4'teki ilk depozit ile uyumlu

```bash
# Vault'taki toplam varlik (scUSD arzinin arkasindaki cUSD)
cast call $SCUSD_ADDR "totalAssets()(uint256)" --rpc-url "$BASE_RPC_URL"
# scUSD arzi (pay sayisi) — totalAssets ile ayni olmali (1:1 giris)
cast call $SCUSD_ADDR "totalSupply()(uint256)" --rpc-url "$BASE_RPC_URL"
# Kullanici CUSD arzini asti mi? (invariant 4: vault assets <= cUSD supply)
cast call $CUSD_ADDR "totalSupply()(uint256)" --rpc-url "$BASE_RPC_URL"
```

| Beklenti | Sapma | Anlamı / müdahale |
|---|---|---|
| `totalAssets == totalSupply` | **Fark > 1 wei** | Rounding veya bağış (donation) yapılmış — [docs/30 Vektör 1](docs/30_GUVENLIK_INCELEMESI.md)'e bakın. Önemli değil (plain `deposit()` önyüzde yok) |
| `totalAssets > 0` | **0** | İlk depozit henüz yok — ADIM 4 koşulmadı, bekle |
| `totalSupply <= cUSD totalSupply` | **Bozulursa** | İnvariant ihlali — mint'i durdur, `juniorCoverageBps` kontrol et (aşağıya bakın) |

**TVL tavan kontrolü:** `tvlCap` kalıcıdır; `totalAssets` tavanı aşarsa **mint
otomatik revert olur** (soğuk başlama kilidi). Bu bir hata değil, tasarımdır.

### 2. ETH bakiyesi — beklenti: **0** (en kritik)

```bash
# CleanUSD ve vault kontratlarinda ETH OLMAMALI
cast balance $CUSD_ADDR --rpc-url "$BASE_RPC_URL"
cast balance $SCUSD_ADDR --rpc-url "$BASE_RPC_URL"
```

| Beklenti | Sapma | Anlamı / müdahale |
|---|---|---|
| **`0`** | **≠ 0** | 🔴 **GERİ DÖNÜLEMEZ** — birisi `--value` ile gerçek ETH göndermiş. CleanUSD'de **ETH çekme fonksiyonu YOK** (tüm `contracts/` tarandı), ETH **sonsuza kilitli**. Yeni cUSD adresi gerekir (deploy baştan). Önlem: tohum her zaman `seedJunior(amount)` **--value'suz** (ADIM 3) |

> **Bu, deploy sonrası en önemli tek kontroldür.** `0` değilse hiçbir işlem
> yapmayın — önce [docs/29 KARAR 3B](docs/29_INSAN_KARARLARI.md)'yi okuyun.
> Anvil GO-READY kanıtında bu değer **0** olarak doğrulandı.

### 3. Hata oranı — beklenti: tüm tx'ler `status 1`

```bash
# Son N islemin durumunu sayimla (cast receipt ile tek tek)
# Basit kontrol: bugun yapilan tum tx'ler icin status == 1 olmali
for tx in $TX_HASH_LIST; do
  cast receipt $tx --rpc-url "$BASE_RPC_URL" | grep status
done
# Basari: "status": "1" — Hata: "status": "0"
```

| Beklenti | Sapma | Anlamı / müdahale |
|---|---|---|
| **%100 `status 1`** (yaklaşırken) | **`status 0` (revert)** | Tx'i izole edin: hangi fonksiyon? Eğer `depositWithMin` revert ise **bu korumanın çalıştığı anlamına gelir** (slippage kalkanı) — müşteri fonunu geri aldı, sorun değil. Eğer `mint` revert ise `canMint`/`tvlCap`/`juniorCoverageBps` kontrol edin |
| Junior örtüsü | `juniorCoverageBps < 300` | 🔴 Mint **durur** (hard invariant). Yeni cUSD arzı açılmaz; mevcut scUSD'ler T+2 ile çıkmaya devam eder. Çıkışlar **kilitlenmez** |

**Junior örtüsü okuma:**
```bash
cast call $CUSD_ADDR "juniorCoverageBps()(uint256)" --rpc-url "$BASE_RPC_URL"
# >= 300 OLMALI (300 bps = %3.00) — altina duserse mint durur (invariant 1)
```

### 24 saat özeti — çıktı

```
IDDIA:  Ilk 24 saat: TVL=<totalAssets wei>, ETH=0, hata=%0 (hepsi status 1)
KANIT:  cast call ... totalAssets / cast balance / cast receipt ... status
RC:     0
NOT:    ETH != 0 ise GERI DONULEMEZ — docs/29 KARAR 3B
```

> **Dürüst not:** İlk 24 saatte düşük TVL normaldir (yeni vault). İzlenen şey
> **hata oranı ve ETH=0**'dır; TVL büyümesi pazarlama sorunu, teknik sağlıklık
> bu iki metriktedir. Tüm sistemler **bug başına%100 çalışır** — beklenen
> tek istisna, kasıtlı koruma olan `depositWithMin` revert'leridir.

---

## ADIM SONRASI

5 adım da tamamlandığında:

```
IDDIA:  Canlı üretim Base mainnet'te çalışıyor
KANIT:  cast call $SCUSD_ADDR "totalAssets()(uint256)" --rpc-url $BASE_RPC_URL
RC:     0
DOSYA:  web/src/contracts/addresses.json
```

Bu noktada puan 96.4/100 → **100/100**'e çıkar (operasyonel 3.6 puan kapanır).
