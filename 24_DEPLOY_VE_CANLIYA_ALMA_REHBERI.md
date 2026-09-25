# 24 — DEPLOY VE CANLIYA ALMA REHBERİ (HITL minimum)

**Tarih:** 2026-09-25
**Amaç:** Kalan 3.6 puanlık operasyonel kısmı **insan için 5 dakikalık** copy-paste
adımlara indirmek. Her adımın doğrulama komutu vardır.

**Önkoşul:** Kod tarafı 100/100 — `forge test` 122/122 rc=0, deploy simülasyonu temiz.

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

## ADIM 3 — İlk $3k Tohumu ile $100k Cap'i Aç (1 dakika)

Bu adım **sadece owner** yapar. `$3k` seed, junior %3 invariant'ı sağlar ve
`$100k` tvlCap'i açar (soğuk başlama kilidi).

```bash
# DIKKAT: seedJunior CleanUSD'dedir (CleanFXVault'ta DEGIL) - cUSD adresini kullanin
cast send $CUSD_ADDR "seedJunior(uint256)" 3000 \
  --value 3000000000000000000000 \
  --rpc-url "$BASE_RPC_URL" \
  --private-key "$OWNER_PK"
```

**Doğrulama:**
```bash
# juniorReserve >= 3% TVL invariant (CleanUSD adresi; BPS birimi: 300 = %3.00)
cast call $CUSD_ADDR "juniorCoverageBps()(uint256)" --rpc-url "$BASE_RPC_URL"
# >= 300 OLMALI (300 bps = %3.00)

# tvlCap acildi mi?
cast call $CUSD_ADDR "tvlCap()(uint256)" --rpc-url "$BASE_RPC_URL"
# >= 100000000000000000000000 ($100k) OLMALI
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

Tier "Optimize" modu Aave utilization feed'ine ihtiyaç duyar. **İnsan kararı:**
Chainlink veya Aave V3 base-rate oracle adresini `ReserveManager`'a girin.
Bu adım ATLANABİLİR — Tier 0/1/2 tüm fonksiyonelliği sağlar, sadece dinamik
yeniden dengeleme olmadan çalışır.

```bash
cast send $RESERVE_ADDR "setOptimizeFeed(address)" $FEED_ADDR \
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
