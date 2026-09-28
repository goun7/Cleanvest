# Cleanvest — Sıfır Manipülasyonlu Spot Borsa + CleanFX

**EVM sözleşme + frontend katmanı tamamlandı** · CleanAudit **denetim motoru YOL HARİTASI** (üretici kod yok — bkz. kapsam notu) · Test/coverage sayıları için tek kaynak: [`docs/43_TEST_DURUMU_TEK_KAYNAK.md`](docs/43_TEST_DURUMU_TEK_KAYNAK.md) (taze: 239 Foundry + 28 vitest · 7 sözleşme) · TODO/placeholder sıfır

> 🔢 **Sayıların üretimi:** README'e giren her sayı [`scripts/readme_stats.py`](scripts/readme_stats.py) tarafından koddan üretilir — elle girilmez. Çalıştırma: `python3 scripts/readme_stats.py`

Cleanvest, %100 spot (kaldıraç yok), bot-geçirmez FBA eşleştirme ve getirili stabilcoin
($cUSD/$scUSD) sunan bir kripto ekosistemidir. Bu depo **sözleşme katmanını** içerir.

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
~/.foundry/bin/forge test                          # 239/239 Foundry
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
> **Hâlâ YOL HARİTASI (kalan adımlar):** (1) canlı solver entegrasyonu —
> üretici `executeBatchSettlement`'a henüz bağlı değil; (2) üretim anahtar
> yönetimi. İkisi de insan kararıdır.
>
> **Müşteriye sunumda:** "emir taahhüdü Merkle kökü **üretilir, kullanıcı
> imzasıyla bağlanır ve zincirde doğrulanır**" denir. Bu, güvenlik açığı
> belgesinin 2. adımının tamamlanmasıdır — **3. adım (canlı entegrasyon)
> opsiyoneldir, güvenlik için zorunlu DEĞİL**.

> Merkle ağacı + kök üreticisi yazılmalı, (2) kök yaprak imzalarıyla
> bağlanmalı, (3) test batch'leri gerçek kökle üretilmeli.

> **Testlerin durumu ("239 passed" rozeti nasıl okunmalı):**
> Eski 21 `CleanvestSettlement` testi `orderCommitmentRoot` için eski
> **sabit değeri** (`keccak256("merkle-orders-1")`) hâlâ kullanır
> (`test/CleanvestSettlement.t.sol:16`) — bu testler **commitment-scheme
> bütünlüğünü** test etmeye devam eder. **Yeni 11 Merkle + 1 çapraz kök +
> 12 imza testi** gerçek ağaç kurulumunu, proof üretimini, **yanlış proof
> reddini**, **kullanıcı imzalarını ve yanlış imza/signer reddini** kapsar.
> Rozet artık "batch settlement + **imzalı** Merkle emir taahhüdü
> test-kanıtlı"dır.
> Yani testler **gerçek kullanıcı emirlerinden Merkle ağacı kurmaz** —
> sabit bir string'in özetini kök olarak kabul eder. Sonuç: testler
> `executeBatchSettlement`'ın **kendi iç tutarlılığını** (commitment-scheme
> eşleşmesi, sıfır-kök reddi, anti-collusion, FBA kilidi) doğru doğrular,
> ama **"kullanıcı emirleri köke gerçekten bağlı mı?" sorusunu
> test-kanıtlı yapmaz** — çünkü üretici olmadığı için bağlanacak şey yok.
>
> **"Test-kanıtlı" satış noktası bu açıdan zayıflar:** batch settlement'in
> güvenliği test ile doğrulanmıştır, ama **emir taahhüdü zinciri
> doğrulanmamıştır.** Rozet yanlış anlaşılmasın — bu notu taşıyor.

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
