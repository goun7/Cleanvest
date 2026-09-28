# Cleanvest — Sıfır Manipülasyonlu Spot Borsa + CleanFX

**Sözleşme + frontend katmanı tamamlandı** · Test/coverage sayıları için tek kaynak: [`docs/43_TEST_DURUMU_TEK_KAYNAK.md`](docs/43_TEST_DURUMU_TEK_KAYNAK.md) (taze: 187 Foundry + 28 vitest · 7 sözleşme) · TODO/placeholder sıfır

> 🔢 **Sayıların üretimi:** README'e giren her sayı [`scripts/readme_stats.py`](scripts/readme_stats.py) tarafından koddan üretilir — elle girilmez. Çalıştırma: `python3 scripts/readme_stats.py`

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
| [`CleanUSD`](contracts/CleanUSD.sol) | $1.00 sabit ödeme stabilcoini. **Rebase yok**; junior reserve ≥ TVL×%3 hard invariant | 16 |
| [`CleanFXVault`](contracts/CleanFXVault.sol) | ERC-4626 getiri kasası; 3 kademeli reserve, T+2 itfa kuyruğu, utilization devre-kesici | 33 |
| [`ListingGate`](contracts/ListingGate.sol) | AegisForge denetimi zorunlu; AuditTier ($199/$399/$990/$4.900), CleanScore kamusal API | 36 |
| [`CleanvestSettlement`](contracts/CleanvestSettlement.sol) | 400ms Budish FBA; orderCommitmentRoot, boyut-farklı anti-collusion, **commitment scheme** ile batch bütünlüğü | 21 |
| [`ReserveManager`](contracts/ReserveManager.sol) | 3 kademeli reserve dağılımı; SAFE mod %12 idle, OPTIMIZE feed kilidi | 31 |
| [`UniswapProxy`](contracts/UniswapProxy.sol) | Artık hacim yönlendirme; **kayma gizlenmez**, UI'da şeffaf | 13 |
| [Integration](test/Integration.t.sol) | 7 sözleşmenin birlikte çalışması; uçtan uca senaryolar | 9 |

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
~/.foundry/bin/forge test                          # 187/187 Foundry
cd web && npx vitest run && cd ..                  # 28/28 vitest (erisilebilirlik dahil)
~/.foundry/bin/forge coverage --report lcov        # 7 sozlesme (sayilar scripts/readme_stats.py ile taze)
#    Sayilar elle YAZILMAZ: python3 scripts/readme_stats.py ile koddan uretilir
```

> **vitest NOTU:** `npx vitest` her zaman `web/` icinden calistirilmalidir. Repo
> kokunden calistirilirsa vitest (npx cache'inden gelir) `lib/` altindaki 217
> vendored OpenZeppelin/forge-std hardhat testini toplar ve **"164 FAILED"**
> false alarm'i uretir. `web/vitest.config.mts` artik `lib/` exclude ile
> korumali; ayrica jsdom+vitest yalnizca `web/node_modules`'tadir.

> **Coverage NOTU:** `script/` altindaki deploy araclari is mantigi icermez,
> lcov'da %0 gosterip genel rakami dusurur. Yukaridaki sayilar 7 SOZLESME icin.
> Coverage yuzdeleri `scripts/readme_stats.py` ile degil `forge coverage` ile
> okunur (README'de sabit yuzde YAZILMAZ — stale olur; her calistirmada taze).
> Kalan acik dallar belgelenmis dead-by-design defense-in-depth
> katmanlaridir (test ile ulasilamaz).

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
5. **Kullanıcıyı otomatik koruyan vault** — tüm depozitler **`depositWithMin`** ile
   (plain `deposit()` önyüzde **yok**). ERC-4626 donation attack'ine karşı aktif
   slippage kalkanı: müşteri beklenenin az payını alırsa işlem revert, fonu geri
   döner. 5 saldırı vektörü test-kanıtli — [docs/30](docs/30_GUVENLIK_INCELEMESI.md)

> **SATIŞ NOKTASI:** "Kullanıcıyı otomatik koruyan vault" — donation attack
> sektörde bilinen bir ERC-4626 zafiyetidir (Cream/Sonne/Resupply). Bizim
> vault'umuz bunu **testlerle kanıtlamış** korumayla yönetir: saldırı durumunda
> işlem revert olur, müşterinin fonu kaybolmaz. Plain `deposit()` yok.

> **ZORUNLU KURAL (front-end için):** Müşteri depozitleri **her zaman
> `depositWithMin(assets, receiver, minShares)`** ile yapılmalı; önyüzde plain
> `deposit()` **çağrısı yoktur**. `minShares` arka planda `convertToShares` ile
> hesaplanır (kullanıcı manuel slippage girmez). Test karşılığı: bağış saldırısı
> altında 1_000 cUSD plain `deposit()` ile **199 wei** pay alırken `depositWithMin`
> aynı işlemi **revert** edip fonu eksiksiz geri döndürür
> (`testSecurityDonationAttackVectors`). Detay: [docs/30 "Kalıcı Teknik
> Gereksinim"](docs/30_GUVENLIK_INCELEMESI.md).

## Bu Oturumda Düzeltilen Üretim Bug'ları

Denetim turları yapmadan "bitti" denseydi bunlar canlıda patlardı:

1. Utilization devre-kesici CleanFXVault'a **bağlanmamıştı** (TODO kalmış)
2. ListingGate score lookup **her zaman 0** döndürüyordu (timestamp hash uyumsuzluğu)
3. Batch settlement proof **5 bayt ile geçiyordu** (artık commitment scheme)
4. UniswapProxy **sahte swap** yapıyordu (artık gerçek `exactInputSingle`)

> ## ⚠️ DÜRÜST TEKNİK DÜZELTME — "Merkle inclusion kanıtı" DEĞİL
>
> `CleanvestSettlement.executeBatchSettlement`'taki `proof` parametresi
> **bir Merkle inclusion (yaprak bulundu) kanıtı DEĞİLDİR.**
>
> **Kodun gerçek yaptığı** (`CleanvestSettlement.sol:143-147`):
> ```solidity
> bytes32 expectedProof = keccak256(
>     abi.encode(batchId, batch.orderCommitmentRoot, batch.clearingPrice, batch.totalVolume)
> );
> require(proof.length == 32, "Kanit 32 bayt olmali");
> require(bytes32(proof) == expectedProof, "Kanit batch ile uyumsuz");
> ```
> Yani `proof`, batch'in **kendi 4 alanının keccak256 özetidir** — bir
> **commitment scheme** (taahhüt şeması): yalnızca bu batch'i bilen solver
> bu özeti üretebilir.
>
> **Gerçek bir Merkle inclusion kanıtından farkı:** Merkle kanıtı, bir
> yaprağın ağaç kökünde bulunduğunu kanıtlamak için **kardeş düğüm yolunu**
> (sibling path) sunar ve `orderCommitmentRoot`'a karşı doğrulanır. Burada
> ise `proof`, `orderCommitmentRoot`'a karşı değil, batch'in özetine eşit
> olarak doğrulanır; **hiçbir yaprak/kardeş düğüm içermez**. 32 bayt,
> tek yapraklı bir ağaç dışında inclusion kanıtı olamaz.
>
> **Bu bir güvenlik açığı mı?** Başka bir deyişle — **hayır, kasıtlı**.
> Sözleşmenin amacı **batch bütünlüğüdür** (solver ancak kendi gönderdiği
> batch'i kanıtlayabilir), yaprak bazlı inclusion doğrulaması değildir.
> Kodun kendi yorumu (L139-142) buna **"commitment scheme"** der ve
> doğrudur. `orderCommitmentRoot`'un boş olmaması zorunluluğu (L134) ayrı
> bir front-run/race kalkanıdır.
>
> **Müşteriye sunumda:** "batch bütünlük kanıtı" denir, **"Merkle inclusion
> kanıtı"** denmez. Daha güçlü bir garanti istenirse, gerçek Merkle yol
> doğrulaması **YOL HARİTASI**'dır (yaprak imzaları + kardeş yolu).

> ## 🔴 GÜVENLİK AÇIĞI — off-chain Merkle üreticisi YOK
>
> **Kanıt (2026-09-28, salt-okuma denetimi):** `orderCommitmentRoot`'un
> tanımı `ICleanvestSettlement.sol:11`'de *"kullanıcı emir taahhüdü Merkle
> kökü"*dür. **Bu kökü üreten kod var mı?**
>
> Kardeş proje `07_Temporit_DeFi_Metamorfik_Yaris_Durumu_Avcısı/`
> (README kapsam notu: "AegisForge denetim motorunun Rust çekirdeği
> içindedir") tarandı:
> ```
> $ find . -type f | grep -v .git/      →  crates/aegisforge/examples/probe.rs
> $ grep -rln "erkle" --include="*.rs" .  →  (çıktı YOK)
> ```
> **Tüm projede TEK bir Rust dosyası** var (`probe.rs`, 42 satır). O da
> `aegisforge::stage1_smt` / `aegisforge::target` modüllerine atıfta
> bulunur — ama **crate'in kütüphane kaynağı (`lib.rs`, `src/`) ve
> `Cargo.toml` YOK**, yani `probe.rs` derlenemez bile. **Hiçbir Merkle
> ağacı, hiçbir emir-taahhüdü kök üreticisi mevcut DEĞİL.**
>
> **Güvenlik sonucu:** `CleanvestSettlement.sol:134` yalnızca
> `orderCommitmentRoot != bytes32(0)` kontrol eder. **Kökü üreten kimse
> olmadığı için** zincire **herhangi sıfır-olmayan değer yazılabilir** —
> kökün gerçekten kullanıcı emirlerini temsil ettiğini doğrulayacak hiçbir
> bileşen yok. Front-run/race kalkanı, `bytes32(0)` doldurma dışında
> **uygulanmamış** durumdadır.
>
> **Dürüst etiket:** `orderCommitmentRoot` şu an **simüle/manuel** değer
> alır — `ICleanvestSettlement.sol:11`'in "Merkle kökü" tanımı bir
> **tasarım niyetidir, uygulanmamıştır.** Üretim öncesi: (1) gerçek
> Merkle ağacı + kök üreticisi yazılmalı, (2) kök yaprak imzalarıyla
> bağlanmalı, (3) test batch'leri gerçek kökle üretilmeli.

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
