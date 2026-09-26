# 24 — DEPLOY VE CANLIYA ALMA REHBERİ (HITL minimum)

**Tarih:** 2026-09-25
**Amaç:** Kalan 3.6 puanlık operasyonel kısmı **insan için 5 dakikalık** copy-paste
adımlara indirmek. Her adımın doğrulama komutu vardır.

**Önkoşul:** Kod tarafı 100/100 — `forge test` 161/161 rc=0, deploy simülasyonu temiz.

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

Herhangi bir kullanıcı:

```bash
# 1) cUSD onayi
cast send $CUSD_ADDR "approve(address,uint256)" $SCUSD_ADDR 1000000000000000000000 \
  --rpc-url "$BASE_RPC_URL" --private-key "$USER_PK"

# 2) Slippage-korumali depozito (ERC-4626 kalkani)
cast send $SCUSD_ADDR "depositWithMin(uint256,address,uint256)" \
  1000000000000000000000 $USER_ADDR 999000000000000000000 \
  --rpc-url "$BASE_RPC_URL" --private-key "$USER_PK"
```

**Doğrulama:**
```bash
cast call $SCUSD_ADDR "totalSupply()(uint256)" --rpc-url "$BASE_RPC_URL"
# > 0 OLMALI
```

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

## ADIM SONRASI

5 adım da tamamlandığında:

```
IDDIA:  Canlı üretim Base mainnet'te çalışıyor
KANIT:  cast call $SCUSD_ADDR "totalAssets()(uint256)" --rpc-url $BASE_RPC_URL
RC:     0
DOSYA:  web/src/contracts/addresses.json
```

Bu noktada puan 96.4/100 → **100/100**'e çıkar (operasyonel 3.6 puan kapanır).
