# PQHaven x402 GUARD ↔ Cleanvest Uygunluk Analizi

**Tarih:** 2026-09-27 · **Tür:** Uygunluk analizi (kod YAZILMADI — sadece okuma)
**Soru:** Cleanvest'in ERC-4626 vault'u, PQHaven guard'ı ile konuşabilir mi?

## Kısa cevap

**Tekrarlanabilir bir entegrasyon mümkün — ama doğrudan "vault ↔ guard" bağlantısı
YANLIŞ mimaridir.** İki sistem farklı katmanlarda çalışır ve aralarındaki
doğal köprü **USDC (Base mainnet)**'dir, vault'un pay tokenı (scUSD) değildir.

## İki sistemin yerleşimi

| | PQHaven guard | Cleanvest |
|---|---|---|
| **Katman** | Off-chain ödeme doğrulama (FastAPI middleware) | On-chain DeFi protokolü |
| **Parasal birim** | USDC (EIP-20 transfer, Base mainnet) | cUSD → scUSD (ERC-4626 pay) |
| **Desimal** | 6 (USDC minor: `amount_usd * 1e6`) | 18 (vault: `1 USD = 1e18`, `1 ether` birim) |
| **Adres** | `USDC_CONTRACT = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | ReserveManager: `IERC20 usdc` (deploy'da girilir) |
| **Doğrulama** | `eth_getLogs` ile Transfer event arama (son 5000 blok) | Sözleşme invariant'ları (on-chain, 166 test) |
| **Mod** | Fail-closed 402/503 | Mint-halt + T+2 çıkış kuyruğu |

**Ortak zemin:** USDC, Base mainnet, EVM. **Ayrım:** guard USDC *transfer* arar,
Cleanvest USDC'yi *reserve* olarak yönetir.

## Guard nasıl çalışır (3 katman)

1. **`resolve_treasury()`** — import anında `UNPUMP_TREASURY_EOA`'yı çözer;
   yoksa **SystemExit** (servis ödeme-hedefsiz başlayamaz). Tek-kasa kuralı.
2. **`require_mainnet_payment()`** — `X-Payer-Address` header'ı alır,
   sandbox whitelist değilse zincirde transfer arar; yoksa **402**.
3. **`verify_mainnet_payment()`** — son 5000 blokta `Transfer(from,to,amount)`
   event'ini parçalı arar (publicnode 20000-sonuç limiti için chunk'lanmış),
   20 blok confirm bekler (reorg güvenliği).

**Not:** Guard'ın aradığı **plain USDC transfer**'dir — EIP-3009
`TransferWithAuthorization` **değil**. Sester middleware ise hem "exact-sester"
(EIP-191) hem "x402 exact" (EIP-3009) şemalarını tanır. Yani guard, sester'in
imza katmanından **bağımsız** çalışır: imzaya ek olarak *gerçek* transferi arar.

## Neden "vault ↔ guard" doğrudan bağlantısı yanlış

Guard, ödeme kanıtı olarak **USDC Transfer event'i** arar. Bu, fonksiyon
imzasına bakarsak:

```
find_transfer(from_addr, to_addr, amount_minor)
  → topics: [Transfer_topic, from, to], data: amount
```

Cleanvest'in scUSD pay tokenı bu role **uygun değildir**:
- scUSD bir **ERC-4626 pay**'idir; 1:1 USD değil, pay fiyatıdır
- `depositWithMin` ile mint edilir; düz transfer ödeme kanıtı oluşturmaz
- Guard `amount_usd * 1e6` (USDC 6-desimal) bekler; vault 18-desimaldır

**Sonuç:** Guard scUSD'yi ödeme olarak kabul edemez (ve etmemeli — pay fiyatı
dalgalanabilir). **Doğru köprü USDC'dir.**

## Doğru mimari (önerilen, uygulanmadı)

```
Müşteri ──USDC transfer──> Treasury EOA
                              │ (guard bunu doğrular, 402/503)
                              │
Cleanvest <──USDC reserve──> ReserveManager.usdc
   │                              │
   └── scUSD (ERC-4626 pay) ──────┘  (getiri katmanı, ödeme DEĞİL)
```

**Yani:** PQHaven **ödemesini** USDC ile alır (guard bunu doğrular).
Cleanvest'in rolü, treasury'nin **USDC'sini getiriye yatırması**dır — bu,
guard'dan tamamen bağımsız, sonradan eklenen bir katmandır.

**Mümkün senaryo (netleşmiş):**
1. Treasury EOA USDC alır → guard ödemeyi doğrular (mevcut akış, değişmez)
2. Treasury USDC'yi `ReserveManager.depositReserve()` ile reserve'a yatırır
3. Reserve Tier getiri üretir; `withdrawReserve()` ile geri çekilebilir

**Bu senaryoda guard'ın değişmesine gerek YOK** — treasury'nin USDC'sini
reserve'a yatırması off-chain bir operasyon kararıdır.

## Uygunluk değerlendirmesi

| Kriter | Durum |
|---|---|
| **Aynı zincir** (Base mainnet) | ✅ Evet — guard publicnode Base, Cleanvest Base hedefli |
| **Aynı token standardı** (ERC-20) | ✅ Evet — USDC her ikisinde de ERC-20 |
| **Aynı adres** (USDC contract) | ✅ Evet — `0x833589...` ReserveManager'a deploy'da girilir |
| **Desimal uyumu** | ⚠️ **Hayır** — guard 6, vault 18. **Dönüşüm katmanı gerekir** |
| **Ödeme kanıtı olarak vault pay** | ❌ **Hayır** — scUSD pay fiyatıdır, USDC transfer aranmaz |
| **Operasyonel entegrasyon** (reserve yatırma) | ✅ Evet — `depositReserve()` + `withdrawReserve()` |
| **Fail-closed felsefesi** | ✅ **Eşleşir** — guard 402/503, Cleanvest mint-halt |

**Önemli uyum:** İki sistem de **fail-closed** felsefesindedir:
- Guard: ödeme yoksa servis 402, RPC hatasında 503 (hizmet vermez)
- Cleanvest: junior <%3 ise **mint durur** (giriş kapanır, çıkış T+2 ile açık)

Bu, entegrasyon güvenliği için olumlu — hiçbir taraf "belki çalışır" demez.

## Teknik engeller (açık)

**Desimal uyumsuzluğu çözülebilir ama guard'da DEĞİL:**

Guard `amount_usd * 1e6` hesaplar (USDC 6-desimal). Cleanvest vault
`1 USD = 1e18` kullanır. Eğer reserve'a USDC yatırılıyorsa bu **doğal**
(USDC kendi 6-desimalıyla girer); ama scUSD getiri hesaplamasında
18-desimala çevrim gerekir. Bu, ReserveManager'ın sorumluluğundadır ve
mevcut sözleşme `IERC20 usdc` ile **USDC'yi native 6-desimal** alır.

**Yani engel yok** — USDC native biriminde kalır; 18-desimal yalnızca
vault *getiri yüzdesi* hesabında (`senior_bps * 1e14`) kullanılır.

## Güvenlik kesişimi (dikkat)

İki sistemin güvenlik modelleri birbirine **bağlı değildir** — bu iyi:

- **Guard'ı etkilemeyenler:** Cleanvest donation attack, junior invariant,
  T+2 kuyruk — bunlar ödeme doğrulamayı etkilemez
- **Cleanvest'i etkilemeyenler:** guard sandbox keys, daily quota,
  receipt HMAC zinciri — bunlar reserve'i etkilemez

**Tek ortak risk:** Treasury EOA'nın private key'i. Hem guard'ın ödeme
hedefi hem (eğer reserve'a yatırılıyorsa) reserve deposu **aynı anahtarı**
kullanırsa, tek nokta başarısı olur. Öneri: **ayrı anahtarlar** — guard
treasury'si USDC alır, **farklı** bir anahtar reserve'e yatırır.

## Sonuç

**Tekrarlanabilir entegrasyon: EVET — ama iki bağımsız katman olarak.**

1. PQHaven guard USDC ödemeyi doğrular (mevcut akış, değişmez)
2. Treasury USDC'yi Cleanvest ReserveManager'a **operasyonel olarak** yatırır
3. scUSD vault'u getiri üretir (pay fiyatı, ödeme kanıtı değil)

**Doğrudan vault ↔ guard entegrasyonu: HAYIR** — yanlış mimari. Guard USDC
transfer event'i arar; scUSD pay tokenı bu role uygun değildir (18-desimal +
pay fiyatı + `depositWithMin` mint akışı).

**Hiçbir kod yazılmadı.** Bu belge yalnızca uygunluk analizidir; uygulama
kararı insanındır.

## Kanıt protokolü

```
IDDIA:  PQHaven guard ile Cleanvest uygunluk analizi yapildi (kod YAZILMADI)
KANIT:  mainnet_guard.py + mainnet_verify.py + x402_servis.py okundu;
        sester/middleware.py + schemes.py incelendi; CleanUSD.sol + CleanFXVault.sol
        + ReserveManager.sol ile karsilastirildi; anvil'de deploy+bootstrap kosuldu
RC:     0
COMMIT: 1bfe352 (Cleanvest deploy rehberi canli anvil kaniti)
```
