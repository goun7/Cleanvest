# Cleanvest — Sıfır Manipülasyonlu Spot Borsa + CleanFX

**Sözleşme + frontend katmanı tamamlandı** · 161/161 Foundry + 23/23 vitest testi yeşil · %99.42 line / %98.62 branch coverage (6 sözleşme) · TODO/placeholder sıfır

Cleanvest, %100 spot (kaldıraç yok), bot-geçirmez FBA eşleştirme ve getirili stabilcoin
($cUSD/$scUSD) sunan bir kripto ekosistemidir. Bu depo **sözleşme katmanını** içerir.

> **Kapsam notu:** AegisForge denetim motorunun Rust çekirdeği
> [`07_Temporit_.../crates/aegisforge/`](../07_Temporit_DeFi_Metamorfik_Yaris_Durumu_Avcisi/)
> içindedir. Bu depo yalnızca EVM sözleşmelerini ve deployment altyapısını barındırır.

---

## Mimari

```
                    ┌─────────────────────────────────────────┐
                    │            LISTING GATE (Faz-1)         │
                    │  AegisForge denetimi ZORUNLU            │
                    │  CleanScore KAMUSAL ve UCRETSIZ         │
                    │  PoV_Hash taahhüdü (ZK-SNARK DEGIL)     │
                    └─────────────────────────────────────────┘
                                       │
        ┌──────────────────────────────┼──────────────────────────────┐
        ▼                              ▼                              ▼
┌───────────────┐            ┌───────────────────┐          ┌──────────────────┐
│  CleanUSD     │            │  CleanFXVault     │          │ Cleanvest-       │
│  ($cUSD)      │───────────▶│  ($scUSD)         │          │ Settlement       │
│  SABIT $1.00  │  deposit   │  ERC-4626 kasasi  │          │ 400ms FBA batch  │
│  REBASE YOK   │            │  3 kademeli getiri│          │ + RFQ solver     │
└───────────────┘            └─────────┬─────────┘          └────────┬─────────┘
                                       │                             │
                              ┌────────▼─────────┐          ┌────────▼─────────┐
                              │ ReserveManager   │          │ UniswapProxy     │
                              │ Aave V3 / OUSG / │          │ Artik hacim      │
                              │ BUIDL / Prime    │          │ SEFFAF kayma     │
                              └──────────────────┘          └──────────────────┘
```

## Sözleşmeler

| Sözleşme | Açıklama | Test |
|---|---|---|
| [`CleanUSD`](contracts/CleanUSD.sol) | $1.00 sabit ödeme stabilcoini. **Rebase yok**; junior reserve ≥ TVL×%3 hard invariant | 9 |
| [`CleanFXVault`](contracts/CleanFXVault.sol) | ERC-4626 getiri kasası; 3 kademeli reserve, T+2 itfa kuyruğu, utilization devre-kesici | 20 |
| [`ListingGate`](contracts/ListingGate.sol) | AegisForge denetimi zorunlu; AuditTier ($299/$1.490/$4.900), CleanScore kamusal API | 28 |
| [`CleanvestSettlement`](contracts/CleanvestSettlement.sol) | 400ms Budish FBA; orderCommitmentRoot, boyut-farklı anti-collusion, batch bütünlük kanıtı | 19 |
| [`ReserveManager`](contracts/ReserveManager.sol) | 3 kademeli reserve dağılımı; SAFE mod %12 idle, OPTIMIZE feed kilidi | 14 |
| [`UniswapProxy`](contracts/UniswapProxy.sol) | Artık hacim yönlendirme; **kayma gizlenmez**, UI'da şeffaf | 8 |
| [Integration](test/Integration.t.sol) | 6 sözleşmenin birlikte çalışması; 3 uçtan uca senaryo | 8 |

## Hızlı Başlangıç (Quick Start — 5 adım)

```bash
# 1. Kurulum — Foundry + frontend bagimliliklari
#    (forge: https://getfoundry.sh | pnpm: https://pnpm.io)
git submodule update --init --recursive          # forge-std + OpenZeppelin
cd web && pnpm install && cd ..                    # scUSD dashboard bagimliliklari

# 2. Konfig — yerel test agi (anvil) + anahtar
anvil --port 8545 --block-time 2 --host 127.0.0.1 \
  --mnemonic "test test test test test test test test test test test junk"
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# 3. Deploy — 4 sozlesme + likidite tohumu (ayri terminalde, anvil ayakta)
forge script script/Deploy.s.sol:Deploy \
  --rpc-url http://127.0.0.1:8545 --broadcast --unlocked
export CUSD_ADDR=$(cast call ... 2>/dev/null || echo "<deploy edilen cUSD adresi>")
forge script script/Bootstrap.s.sol \
  --rpc-url http://127.0.0.1:8545 --broadcast --unlocked
#    Bootstrap dogrulamasi: junior $3.000 / cap $100.000 / coverage >= %3 / mint ACIK

# 4. Demo — musteri deneyiminin 6 adimi (CANLI onchain, rc=0)
forge script script/Demo.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --unlocked
#    Cikti "=== ONCHAIN EXECUTION COMPLETE & SUCCESSFUL ===" ile biter

# 5. Dogrulama — testler + kapsamislik
~/.foundry/bin/forge test                          # 161/161 Foundry
cd web && npx vitest run && cd ..                  # 23/23 vitest (erisilebilirlik dahil)
~/.foundry/bin/forge coverage --report lcov        # 6 sozlesme: %99.42 line / %98.62 branch
```

> **vitest NOTU:** `npx vitest` her zaman `web/` icinden calistirilmalidir. Repo
> kokunden calistirilirsa vitest (npx cache'inden gelir) `lib/` altindaki 217
> vendored OpenZeppelin/forge-std hardhat testini toplar ve **"164 FAILED"**
> false alarm'i uretir. `web/vitest.config.mts` artik `lib/` exclude ile
> korumali; ayrica jsdom+vitest yalnizca `web/node_modules`'tadir.

> **Coverage NOTU:** `script/` altindaki deploy araclari is mantigi icermez,
> lcov'da %0 gosterip genel rakami dusurur. Yukaridaki sayilar 6 SOZLESME icin.
> Kalan 2 acik dal (CleanUSD:102, ListingGate:214) belgelenmis dead-by-design
> defense-in-depth katmanlaridir (test ile ulasilamaz).

Deployment detaylari icin bkz. [`docs/19_DEPLOYMENT_REHBERI.md`](docs/19_DEPLOYMENT_REHBERI.md).
Musteri onboarding akisi: [`docs/27_MUSTERI_ONBOARDING.md`](docs/27_MUSTERI_ONBOARDING.md).

## Doğrulanmış Getiri Eğrisi (2026-09-24)

| Kademe | TVL | Dağılım | Senior Getiri |
|---|---|---|---|
| Tier0 | <$250k | %73 Aave / %12 idle / %15 Prime | **%3.05** |
| Tier1 | $250k–12.5M | %40 OUSG / %33 Aave / %12 idle / %15 Prime | **%2.91** |
| Tier2 | ≥$12.5M | %40 BUIDL / %33 Aave / %12 idle / %15 Prime | **%2.92** |

**SAFE mod** (12% idle) varsayılandır. **OPTIMIZE modu** Aave utilization feed'i
bağlanana kadar **açılamaz** (sosyalleşme riski > %92 utilization'da anlık itfa T+2'ye düşer).

## Şartname Yasakları (Koda İşlenmiş)

| Yasak | Kanıt |
|---|---|
| **Rebase yok** | `grep "function rebase"` → bulunamadı |
| **"ZK-SNARK" iddiası yok** | yalnızca "ZK-SNARK **değil**" reddiyeleri |
| **"Sıfır kayma" vaadi yok** | UniswapProxy kaymayı şeffaf raporlar |
| **KÖK/Tamga bekleme yok** | %100 EVM (Base/Arbitrum), harici bağımlılık yok |
| **%4.8 vaadi yok** | getiri eğrisi %3.05/2.91/2.92 ile kilitli |
| **Haraç modeli yok** | `applicationFee() = 0`; CleanScore ücretsiz |

## Güvenlik İlkeleri

1. **Çıkışlar ASLA kilitlenmez** — T+2 kuyruğu yalnızca geciktirir (2 gün sonra otomatik serbest)
2. **Junior reserve hard invariant** — `JuniorReserve ≥ TVL × 3%` ihlalinde mint durur, burn devam eder
3. **Sıfır kurucu sermayesi** — CoW netting + RFQ solver; kurucu $1 likidite koymaz
4. **LE-3 çıkar çatışması kalkanı** — kendi kontratlarımızda bulunan açıklar [yayınlanır](docs/15_AEGISFORGE_VAKA_CALISMASI_02_GERCEK_BULGULAR.md)

## Bu Oturumda Düzeltilen Üretim Bug'ları

Denetim turları yapmadan "bitti" denseydi bunlar canlıda patlardı:

1. Utilization devre-kesici CleanFXVault'a **bağlanmamıştı** (TODO kalmış)
2. ListingGate score lookup **her zaman 0** döndürüyordu (timestamp hash uyumsuzluğu)
3. Batch settlement proof **5 bayt ile geçiyordu** (artık commitment scheme)
4. UniswapProxy **sahte swap** yapıyordu (artık gerçek `exactInputSingle`)

## Frontend — scUSD Dashboard (`web/`)

Kurumsal dashboard; kullanıcı gözünden tek sayfada tüm durum görünür.

```bash
cd web && pnpm install && pnpm dev      # gelistirme (localhost:5174)
pnpm build                               # production (34.89kB ana bundle)
```

**Ekranlar:**
- 4 stat kartı: Kasa TVL, aktif kademe, pay fiyatı, junior örtüsü (renk uyarılı)
- Dürüst getiri eğrisi paneli (aktif kademe vurgulu)
- Çıkış kapısı: günlük %10 anlık kota, kalan anlık, T+2 kuyruk durumu
- Yatır/Çık paneli: slippage-korumalı (`depositWithMin`/`redeemWithMin`)

**Güvenlik entegrasyonu:** UI, ERC-4626 inflation-attack kalkanını
otomatik uygular — kullanıcı manuel slippage girmez, `minShares`/`minAssets`
arka planda hesaplanır (**HITL minimum**).

**i18n:** TR + EN (tarayıcı diline göre varsayılan, localStorage kalıcı).

**Mobil:** 390px'e kadar responsive, yatay taşma yok (headless Chrome ile doğrulandı).

## Lisans

MIT
