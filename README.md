# Cleanvest — Sıfır Manipülasyonlu Spot Borsa + CleanFX

**EVM sözleşme + frontend katmanı tamamlandı** · **imzalı Merkle emir taahhüdü + bağımsız kanıt CLI'ı MEVCUT** · CleanAudit **denetim motoru YOL HARİTASI** (üretici kod yok — bkz. kapsam notu) · Test: **286 forge + 24 Rust, 0 failed** · Akademik araştırma: [`docs/arastirma/`](docs/arastirma/) (33 doğrulanmış makale) · TODO/placeholder sıfır

> 🔢 **Sayıların üretimi:** README'e giren her sayı [`scripts/readme_stats.py`](scripts/readme_stats.py) tarafından koddan üretilir — elle girilmez. Çalıştırma: `python3 scripts/readme_stats.py`

Cleanvest, %100 spot (kaldıraç yok), bot-geçirmez FBA eşleştirme ve getirili stabilcoin
($cUSD/$scUSD) sunan bir kripto ekosistemidir. Bu depo **sözleşme katmanını** içerir.

---

## 30 Saniyede Cleanvest

```bash
# 1. Araclar (https://getfoundry.sh) + alt moduller
git submodule update --init --recursive

# 2. Testler — 0 failed olmali (286 forge + 19 Rust)
export PATH="$HOME/.foundry/bin:$PATH"
forge test                              # Solidity: 286 passed, 0 failed
cargo test --manifest-path merkle/Cargo.toml   # Rust Merkle: 19 passed

# 3. Yerel ag (anvil, anahtar GEREKMEZ)
make anvil                              # ayri terminalde
make deploy-anvil                       # 7 sozlesme + adresler deploy-out/addresses.json

# 4. Kanit zinciri — uc bagimsiz uygulama (cast/Rust/Solidity)
bash scripts/proof_demo.sh              # "OZDES" ile bitmeli

# 5. Bagimsiz kanit dogrulayici (offline, operatore guvenmeden)
cargo run --release --features proof --example verify_cli -- proof.json
```

**Hepsi bu kadar.** Yukaridakilerin hepsi `anvil`'dedir — **CANLI DEĞİLDİR**. Canlı
deploy için bkz. [Deploy](#deploy-canlı-için-insan-kararı-gerekir).

> **Kapsam notu (DÜRÜST):** CleanAudit denetim motorunun Rust çekirdeği
> **bu deponun parçası DEĞİLDİR** — ayrı bir projede olması amaçlanmıştır:
> [`07_Temporit_.../`](../07_Temporit_DeFi_Metamorfik_Yaris_Durumu_Avcısı/).
> **Ancak kanıtlanmıştır ki o proje de bu motoru içermiyor:** tarama
> (2026-09-28) o depada yalnızca **tek bir Rust dosyası** bulmuştur
> (`crates/aegisforge/examples/probe.rs`, 42 satır) — `lib.rs`, `src/`
> ve `Cargo.toml` YOK, yani o dosya **derlenemez bile**.
>
> **Sonuç:** CleanAudit Rust çekirdeği **henüz mevcut DEĞİLDİR**. Bu depo
> yalnızca EVM sözleşmelerini, deployment altyapısını ve **zincir üzerinde
> çalışan** CleanAudit etkileşim noktalarını (`ListingGate` oracle ABI,
> `PoV_Hash` şeması) barındırır. "Denetim motoru" ifadesi satışta
> kullanılırsa **üretici kodun olmadığı** belirtilmelidir.

---

## Mimari

```
                    ┌─────────────────────────────────────────┐
                    │            LISTING GATE (Faz-1)         │
                    │  CleanAudit denetimi ZORUNLU            │
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

## "Sıfır Manipülasyon" Ne Demek? (Teknik Tanım)

"Sıfır manipülasyon" bir **pazarlama iddiası değil**, doğrulanabilir bir **teknik
özelliktir**. Üç katmanı vardır:

### 1. Emirlerin manipüle edilememesi (on-chain taahhüt)

Her batch'teki emirler bir **Merkle ağacında** toplanır ve kök
(`orderCommitmentRoot`) **zincir-üstünde** yayınlanır. Her yaprak:

```
leaf = keccak256(abi.encode(amount, user, nonce))
```

ve her yaprak **kullanıcı tarafından EIP-191 ile imzalanır**. Bu, operatörün
(ağacı kuran taraf) **kullanıcı imzalamadan yaprak dolduramayacağı** anlamına
gelir — akademik literatürde bu gereklilik 2026'da açıkça formüle edilmiştir
([`docs/arastirma/05`](docs/arastirma/05_merkle_kanitlari_finansal_uygulamalar_2025_2026.md),
[`docs/arastirma/03`](docs/arastirma/03_spot_borsa_guvenligi_2025_2026.md)).

### 2. Kanıtın bağımsız doğrulanması (bu oturumda eklendi)

**Üç bağımsız uygulama aynı sonucu verir:**

| Uygulama | İmza | Merkle kökü | Doğrulama |
|---|---|---|---|
| Foundry `cast` (C++) | üretir (EIP-191) | — | `ecrecover` |
| Rust (`cleanvest-merkle`) | üretir + doğrular | üretir + doğrular | CLI offline |
| Solidity (zincir-üstü) | doğrular (`verifySignedOrder`) | üretir (`computeRoot`) | `cast call` |

Kök **byte-byte özdeştir**. Çalıştırma: `bash scripts/proof_demo.sh`.

### 3. Front-run / sıralama sömürüsüne yapısal kalkan

- `T_BATCH_MS = 400ms` batch gecikmesi — emirler kilitlenir, sonradan sıralanamaz
- `nonce` her yaprakta — imza tekrar (replay) sınırlı
- `orderCommitmentRoot != bytes32(0)` zorunlu — boş taahhüt reddedilir
- `batchSettled[batchId]` — aynı batch iki kez kesinleşemez (non-equivocation)

### "Sıfır" NE DEĞİLDİR (dürüst sınırlar)

**Bu sınırlar iddianın parçası DEĞİLDİR:**

1. **Rezerv/yükümlülük kanıtı (PoR/PoL) DEĞİLDİR** — `orderCommitmentRoot`
   yalnızca **emir taahhüdüdür**. `$cUSD`'nin **yükümlülük tarafı** artık
   [`ProofOfLiabilities`](contracts/ProofOfLiabilities.sol) ile zincir-üstünde
   fail-closed taahhüt edilir (`publishLiabilitiesFromSignedLeaves`: kök,
   EIP-191 imzalı yapraklardan **zincirde** türetilir; imzasız yaprak
   uydurulamaz), ama **rezervlerin VARLIĞI** hâlâ kanıtlanamaz — banka-DDO
   entegrasyonu gerektirir (yol haritası; bkz.
   [`docs/arastirma/07`](docs/arastirma/07_proof_of_liabilities_derinlestirme.md)).
2. **İmza tekrar (replay) tam koruma DEĞİLDİR** — `nonce` alanı vardır ama
   zincir-üstü **kullanılmış-nonce takibi YOKTUR**. Batch seviyesinde
   `batchSettled` korur; yaprak seviyesinde yeniden oynatma operasyoneldir
   ([`docs/arastirma/06`](docs/arastirma/06_eip191_imzali_mesaj_guvenligi_2025_2026.md)).
3. **MEV'den tam bağışık DEĞİLDİR** — batch içi sıralama kilitlidir ama
   batch'ler arası kuyruk ve çözücü seçimi dışarıda kalır
   ([`docs/arastirma/02`](docs/arastirma/02_mev_ve_front_run_koruma_2025_2026.md)).
4. **Gizlilik YOKTUR** — kanıt sunmak yaprak değerlerini (amount, user, nonce)
   açığa çıkarır. zk-STARK tabanlı geçiş yol haritasıdır.
5. **"Manipülasyon tespit etmez"** — wash-trade/complexity-measure tabanlı
   tespit **koddan yoktur**; akademik yöntemler yol haritası sunar
   ([`docs/arastirma/01`](docs/arastirma/01_piyasa_manipulasyonu_tespiti_2025_2026.md)).

**Müşteriye sunumda:** "emir taahhüdü **üretilir, kullanıcı imzasıyla bağlanır
ve üç bağımsız uygulama tarafından kanıtlanır**" denir. "Para istismar
edilemez" veya "kanıt her şeyi kapsar" DENMEZ.

## Sözleşmeler

| Sözleşme | Açıklama | Test |
|---|---|---|
| [`CleanUSD`](contracts/CleanUSD.sol) | $1.00 sabit ödeme stabilcoini. **Rebase yok**; junior reserve ≥ TVL×%3 hard invariant | 16 |
| [`CleanFXVault`](contracts/CleanFXVault.sol) | ERC-4626 getiri kasası; 3 kademeli reserve, T+2 itfa kuyruğu, utilization devre-kesici | 33 |
| [`ListingGate`](contracts/ListingGate.sol) | CleanAudit denetimi zorunlu; AuditTier ($199/$399/$990/$4.900), CleanScore kamusal API | 36 |
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
~/.foundry/bin/forge test                          # 242/242 Foundry
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

## Deploy: Canlı İçin İNSAN KARARI Gerekir

**Mevcut durum: her şey `anvil`'dedir (chainId 31337). CANLI DEĞİLDİR.**

Canlı deploy **tek komutla** yapılabilir haldedir — ama **kasıtlı olarak bir
insan kararı gerektirir**. `script/Deploy.s.sol` içindeki **mainnet guard**
üç şeyi kontrol eder:

| Koşul | Eksikse |
|---|---|
| `PRIVATE_KEY` çevre değişkeni | **REDDER**: `CANLI AG: PRIVATE_KEY ZORUNLU` |
| Anahtar anvil test anahtarı DEĞİL | **REDDER**: `anvil test anahtari YASAK` |
| `DEPLOY_CONFIRM=yes` (açık insan onayı) | **REDDER**: `DEPLOY_CONFIRM=yes gerekiyor` |

Guard yalnızca `chainId != 31337` (canlı ağ) olduğunda devreye girer; `anvil`'de
engelleme yoktur.

### Canlı deploy (insan tarafından)

```bash
# 1. Anahtar ve RPC hazirla (insan karari — otomatik DEGIL)
export PRIVATE_KEY=0x...                           # deploy cuzdani
export RPC_URL=https://mainnet.base.org             # hedef ag
export DEPLOY_CONFIRM=yes                           # ACIK onay

# 2. Tek komut (guard once kontrol eder, sonra deploy eder)
make deploy-live

# 3. Etherscan dogrulama (otomatik)
export ETHERSCAN_API_KEY=...
make verify
```

### Gas tahmini (anvil'de olculmustur)

| Sözleşme | Deploy gazi |
|---|---|
| CleanUSD | 1.774.360 |
| CleanFXVault | 3.246.497 |
| ReserveManager | 1.863.390 |
| CleanvestSettlement | 2.831.276 |
| ListingGate | 2.813.238 |
| UniswapProxy | 1.331.591 |
| ReferralLedger | 1.298.344 |
| **Toplam (7 sözleşme)** | **≈ 15.160.000** |

`forge`'un kendi tahmini (batch genel giderleri dahil): **≈ 19.190.000 gas**.
Base'de 1 gwei'da bu ≈ **0.019 ETH** (~$30–60, fiyata göre). **Para harcanmadı** —
tüm ölçümler `anvil`'de yapılmıştır.

> **NEDEN insan kararı?** Bu oturumda `PRIVATE_KEY` kullanıcı tarafından
> **sağlanmadı** ve sisteme **girilmedi**. Canlı deploy, (1) üretim anahtarının
> güvenli yönetimini, (2) hedef ağın seçimini ve (3) gerçek maliyetin
> kabulünü içerir — bunlar **insana aittir**, otonom ajanın yapmamı gereken
> işler. Akademik araştırma da bu noktayı doğruluyor: Web3'teki baskın kayıp
> örüntüleri **anahtar yönetimi ve insan-içeren süreçlerden** kaynaklanıyor
> ([`docs/arastirma/03`](docs/arastirma/03_spot_borsa_guvenligi_2025_2026.md)).

## Bağımsız Kanıt CLI'ı (`cleanvest verify`)

"Operatör bana bu kanıtı verdi" diyen bir kullanıcı, **operatöre güvenmeden**
üç şeyi doğrulayabilir:

```bash
# Derle (opsiyonel `proof` ozelligi ile)
cargo build --release --manifest-path merkle/Cargo.toml --features proof --examples

# Dogrula (offline — ag baglantisi YOK)
merkle/target/release/examples/verify_cli proof.json
```

**Çıktı (geçerli kanıt):**
```
[GECTI] 1/3 Yaprak yeniden hesaplandi (emir alanlarindan)
        leaf    = 0xf9d9fd57...
[GECTI] 2/3 EIP-191 imza gecerli (imzalayan = kullanici)
[GECTI] 3/3 Merkle inclusion gecerli (yaprak kokte)
KANIT GECTI — kullanici imzasi -> yaprak -> kok zinciri dogrulandi.
```

**Üç adımın anlamı:**
1. **Yaprak yeniden hesaplanır** — `keccak256(abi.encode(amount, user, nonce))`
   JSON'daki emir alanlarından baştan üretilir; operatörün "bu yaprak"
   demesine gerek yoktur.
2. **İmza doğrulanır** — EIP-191 `ecrecover(leaf, sig) == user`. Operatör
   yaprağı dolduramaz.
3. **Merkle inclusion** — `verify(leaf, proof_bytes, root)`. Yaprak kökte.

**Kanıt üretmek (demo/test için):**
```bash
cargo run --release --features proof --example prove_cli -- \
    --orders orders.json --index 1 --out proof.json
```

> **Dürüst sınır:** bu araç **kriptografik** doğrulama yapar; **zincir-üstü**
> durumu bilmez. JSON'daki `root` operatörün iddiasıdır — **kanıtı**
> zincirden okumak için: `cast call $SETTLEMENT "orderCommitmentRoot()(bytes32)"`.
> `proof_bytes` alanı, zincir-üstü `verifySignedOrder`'a **aynı bayt dizisi**
> olarak verilebilir (birebir uyumlu).

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
> doğrulaması **MEVCUT** (kullanıcı imzaları + kardeş yolu).

> ## ✅ GÜVENLİK AÇIĞI KAPANDI — off-chain Merkle üreticisi MEVCUT
>
> **Durum (2026-09-28):** `orderCommitmentRoot` artık **gerçek Merkle
> köküdür** — güvenlik açığı kapatıldı (öncesi: `keccak256("merkle-orders-1")`
> sabiti, kökü üreten kimse yoktu, zincire sıfır-olmayan her değer
> yazılabilirdi).
>
> **Mevcut bileşenler:**
> - **Rust üretici** — `merkle/` (crate `cleanvest-merkle`):
>   `MerkleTree::build()` çift-yapraklı ağaç kurar (tek kalan yaprak
>   kendisiyle eşleştirilir), `.root()` → `orderCommitmentRoot`,
>   `.prove(i)` → sibling path üretir. Keccak = EVM ile birebir
>   (`tiny-keccak`, known-vector'lerle doğrulandı).
> - **Zincir doğrulama** — `CleanvestSettlement.verifyMerkleProof(leaf,
>   proof, root)` ve `leafHash(amount, user, nonce)` +
>   `computeRoot(leaves)` referansı.
> - **Çapraz kanıt** — Rust `merkle/examples/cross_check.rs` ve Solidity
>   `test/MerkleCrossCheck.t.sol` **aynı emirlerle aynı kökü** üretir:
>   `0x21e195d1eed3d788d369d7a3e5ec2e8f56b8c9c6113b5a6baf48b848e5c73518`.
> - **Testler** — 11 yeni test: ağaç kur, proof üret, zincirde doğrula,
>   **yanlış proof REDDEDİLİR**, yanlış kök REDDEDİLİR, gerçek kök ile
>   batch settlement çalışır (`testExecuteBatchWithRealMerkleRoot`).
>
> **✅ YAPRAK İMZALARI MEVCUT (2026-09-28, tam kapanma):** her yaprak
> artık **kullanıcı tarafından imzalanır** — EIP-191 personal_sign
> (`signMessage` ile cüzdan uyumlu). İmza, ağaçtan **bağımsız** doğrulanır:
> - **Rust** — `merkle/src/signed.rs`: `SignedLeaf`, `build_signed()`
>   (önce tüm imzaları doğrular, tek geçersiz hepsini reddeder — fail-closed),
>   `prove_signed(i)` (Merkle path + imza), `verify_signed()` (tam kanıt zinciri)
> - **Solidity** — `verifyLeafSignature(leaf, sig, signer)` (ecrecover),
>   `recoverSigner`, `verifySignedOrder(...)` — **hem imza hem Merkle**
> - **Çapraz kanıt** — Rust'ın ürettiği imza Solidity `ecrecover` ile
>   **aynı adresi** geri kazanır (`testRustSignatureVerifiesOnChain` PASS)
> - **Testler** — 12 yeni: **yanlış imza REDDEDİLİR**, **yanlış signer
>   REDDEDİLİR**, doğru imza + doğru proof PASS, geçerli imza + yanlış proof
>   REDDEDİLİR
>
> **✅ BAĞIMSIZ KANIT CLI'I MEVCUT (2026-09-29):** kanıt artık `proof.json`
> olarak **operatöre güvenmeden** doğrulanabilir:
> - `merkle/src/proof.rs` — `ProofJson` formatı + tam doğrulama
> - `merkle/examples/verify_cli.rs` — `cleanvest verify proof.json` (offline)
> - `merkle/examples/prove_cli.rs` — kanıt üretici (test/demo)
> - `scripts/proof_demo.sh` — **üçlü çapraz doğrulama**: cast (C++) imzalar,
>   Rust kök üretir, Solidity zincir-üstü doğrular. Kök **özdeş**:
>   `0x5c040168e9a86021da45500a7a60a06ba8619e5ddd0841f23a179b3f8888127d`
> - **Testler** — 5 yeni Rust + 3 yeni Solidity testi (toplam 242 forge + 24 Rust)
>
> **Hâlâ YOL HARİTASI (kalan adımlar):** (1) canlı solver entegrasyonu —
> üretici `executeBatchSettlement`'a henüz bağlı değil; (2) üretim anahtar
> yönetimi; (3) kullanılmış-nonce zincir-üstü takibi (replay koruması);
> (4) zk-STARK tabanlı gizlilik. İlk ikisi **insan kararıdır**.
>
> **Müşteriye sunumda:** "emir taahhüdü Merkle kökü **üretilir, kullanıcı
> imzasıyla bağlanır ve üç bağımsız uygulama tarafından kanıtlanır**" denir. Bu,
> güvenlik açığı belgesinin 2. adımının tamamlanmasıdır — **3. adım (canlı
> entegrasyon) opsiyoneldir, güvenlik için zorunlu DEĞİL**.

> Merkle ağacı + kök üreticisi yazılmalı, (2) kök yaprak imzalarıyla
> bağlanmalı, (3) test batch'leri gerçek kökle üretilmeli.

> **Testlerin durumu ("242 passed" rozeti nasıl okunmalı):**
> Eski 21 `CleanvestSettlement` testi `orderCommitmentRoot` için eski
> **sabit değeri** (`keccak256("merkle-orders-1")`) hâlâ kullanır
> (`test/CleanvestSettlement.t.sol:16`) — bu testler **commitment-scheme
> bütünlüğünü** test etmeye devam eder. **Yeni 11 Merkle + 1 çapraz kök +
> 12 imza + 3 CLI çapraz doğrulama testi** gerçek ağaç kurulumunu, proof
> üretimini, **yanlış proof reddini**, **kullanıcı imzalarını**, **üçlü
> cast/Rust/Solidity özdeşliğini** ve **yanlış imza/signer reddini** kapsar.
> Rozet artık "batch settlement + **imzalı** Merkle emir taahhüdü
> test-kanıtlı"dır.
>
> **Kalan dürüst boşluk:** testler `executeBatchSettlement`'ın **üretici
> solver bağlantısını** (gerçek batch'lerin canlı akışı) kapsamaz — o
> entegrasyon henüz yok ve **insan kararıdır**. Rust tarafındaki 24 test
> (`cargo test --features proof`) tam kanıt zincirisini birim seviyede
> doğrular.

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

## Akademik Araştırma (2025-2026, güncel)

Her iddia güncel akademik literatürle desteklenir. Tüm kaynaklar `web_fetch` ile
**doğrulanmış**, gerçek arXiv makaleleridir — **uydurma yoktur**.

| Konu | Belge | Öne çıkan bulgu |
|---|---|---|
| Piyasa manipülasyonu tespiti | [`docs/arastirma/01`](docs/arastirma/01_piyasa_manipulasyonu_tespiti_2025_2026.md) | "Manipulation-as-a-Service" endüstrisi (CCS'26, pump.fun) |
| MEV / front-run koruma | [`docs/arastirma/02`](docs/arastirma/02_mev_ve_front_run_koruma_2025_2026.md) | Sandwich için "alt-sınır gizliliği" yeterli (NeurIPS 2026) |
| Spot borsa güvenliği | [`docs/arastirma/03`](docs/arastirma/03_spot_borsa_guvenligi_2025_2026.md) | Kayıpların kaynağı **off-chain** (Bybit 2025 analizi) |
| Kontrat denetim standartları | [`docs/arastirma/04`](docs/arastirma/04_akilli_kontrat_denetim_standartlari_2025_2026.md) | On-chain/off-chain tutarsızlık yeni zafiyet sınıfı |
| Merkle kanıtları (finansal) | [`docs/arastirma/05`](docs/arastirma/05_merkle_kanitlari_finansal_uygulamalar_2025_2026.md) | Kök dürüst kanıt değildir — **kullanıcı imzası gerekir** (AsiaCCS'26) |
| EIP-191 imza güvenliği | [`docs/arastirma/06`](docs/arastirma/06_eip191_imzali_mesaj_guvenligi_2025_2026.md) | Ethereum'da imza kullanan kontratların **%19.63'ü** replay zafiyetli (ICSE 2026) |
| Proof of Liabilities (derinleştirme) | [`docs/arastirma/07`](docs/arastirma/07_proof_of_liabilities_derinlestirme.md) | PoL "ağacın doğru kurulduğu" kanıtını **zincire taşır**; PoL tek başına ödenme gücü **kanıtlamaz** (TAP/USENIX'23, VASP denetim) |

**En doğrudan ilgili bulgu:** "Mitigating Collusion in Proofs of Liabilities"
(AsiaCCS 2026), **commit edilen vektörün yalnızca kullanıcıların imzaladığı
değerleri içermesini** bir gereklilik olarak öne sürer — Cleanvest bu gereksinimi
sadece imzalı yapraklarla değil, **zincir-üstü fail-closed kök türetimiyle**
karşılar: `ProofOfLiabilities.publishLiabilitiesFromSignedLeaves()` her yaprağın
EIP-191 imzasını zincirde doğrular, kökü imzalı yapraklardan zincirde hesaplar ve
tek geçersiz imzada tüm yayını revert eder — operatör kökü seçemez, imzasız yaprak
uyduramaz. Detay: [`docs/arastirma/05`](docs/arastirma/05_merkle_kanitlari_finansal_uygulamalar_2025_2026.md),
[`docs/arastirma/07`](docs/arastirma/07_proof_of_liabilities_derinlestirme.md).

## Lisans

MIT
