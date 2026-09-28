# Test Rehberi — Cleanvest

**Son güncelleme:** 2026-09-27 (cleanvest-dev) · **Beklenen:** 166/166 Foundry + 23/23 vitest

> İnsanın deploy'dan önce **kendisi koşup doğrulayabileceği** komutlar. Her
> komutun beklenen çıktısı `# →` ile işaretli. Hepsi ~1 dakikada biter.

## 0. Önkoşul — Foundry PATH'te DEĞİL

```bash
cd "/home/gokun/projects/Yeni Fikirler/oncu_fikirler_havuzu_2026/26_Cleanvest_Sifir_Manipulasyonlu_Spot_Borsa_Ve_CleanFX"
export PATH="$HOME/.foundry/bin:$PATH"   # forge/cast/anvil burada, PATH'te degil
```

---

## 1. Foundry — 166/166 (sözleşmeler, ~15 saniye)

```bash
forge test
```

**Beklenen çıktı:**

```
Ran 9 test suites in ...: 166 tests passed, 0 failed, 0 skipped (166 total tests)
```

> **Doğrulama:** `0 failed` görmelisin. Aksi halde deploy'a GİTME — geri dön ve
> hatayı incele (bkn. RED FLAGS, docs/29).

### Ayrıntılı / tek suite

```bash
forge test -vvv                          # tüm trace'ler ile
forge test --match-contract CleanUSD     # tek kontrat
forge test --match-test testMint         # tek test
gas raporu: forge test --gas-report
```

---

## 2. Vitest — 23/23 (web katmanı, ~10 saniye)

> ⚠️ **Tuzak:** vitest **mutlaka `web/` içinden** çalıştırılmalı. Repo kökünden
> `npx vitest` çalıştırılırsa `lib/` altındaki 217 vendored OpenZeppelin/forge-std
> hardhat testini toplar ve **"164 FAILED"** false alarm'ı üretir. Bu yapısal
> bir durum: jsdom+vitest yalnızca `web/node_modules`'tadır.

```bash
cd web && npx vitest run
```

**Beklenen çıktı:**

```
Test Files  3 passed (3)
     Tests  23 passed (23)
```

`web/vitest.config.mts` zaten `lib/`, `out/`, `cache/`, `dist/`, `.git/` exclude
 ile korumalıdır — yine de `cd web` şarttır.

---

## 3. Coverage — %99.42 line / %98.62 branch (6 sözleşme)

```bash
forge coverage --report lcov
```

**Beklenen (en anlamlı özet):**

| Sözleşme | Line | Branch |
|---|---|---|
| CleanFXVault | 100% | 100% |
| CleanUSD | 94.44% | 92.31% |
| CleanvestSettlement | 100% | 100% |
| ListingGate | 100% | 96.43% |
| ReserveManager | 100% | 100% |
| UniswapProxy | 100% | 100% |
| **TOPLAM** | **%99.42** | **%98.62** |

> **Not:** `forge coverage` `script/*.s.sol`'i %0 sayıp genel rakamı düşürür
> (deploy araçları iş mantığı içermez). Yukarıdaki sayılar **6 sözleşme** içindir.
> Kalan 2 açık dal (CleanUSD:102, ListingGate:214) **dead-by-design**
> defense-in-depth katmanlarıdır — test ile ulaşılması yapısal olarak imkansız.

---

## 4. Suite'ler — ne test eder?

| Dosya | Test | Kapsam |
|---|---|---|
| `CleanFXVault.t.sol` | 33 | ERC-4626 vault: getiri eğrisi, T+2 kuyruk, anlık kota, optimize feed, **5 güvenlik testi** |
| `CleanUSD.t.sol` | 16 | Mint/burn, junior %3 invariant, tvlCap, seedJunior erişim kontrolü |
| `CleanvestSettlement.t.sol` | 21 | Budish FBA settlement, emir eşleşme, HEX borsa |
| `Fuzz.t.sol` | 10 | Fuzz testleri (tamsayı taşma, sınırlar) |
| `Integration.t.sol` | 8 | Uçtan uca entegrasyon (vault ↔ cUSD ↔ reserve) |
| `ListingGate.t.sol` | 33 | CleanAudit audit tier, kadir, enum decoder savunması |
| `ReserveManager.t.sol` | 31 | Aave/OUSG/BUIDL katmanı, tier geçişleri, devre-kesici |
| `scusd_vault_invariants.t.sol` | 1 | **5 invariant × 300 derinlik** fuzz (actor-based; tek test, içerde 5 özellik) |
| `UniswapProxy.t.sol` | 13 | Swap proxy, slippage, router katmanı |
| **Toplam** | **166** | |

Vitest (web): 3 dosya / 23 test — UI bileşenleri + **erişilebilirlik** dahil.

---

## 5. Canlı anvil doğrulaması (deploy simülasyonu)

Gerçek deploy yapmadan tüm stack'i anvil'de çalıştır — bkz.
 [docs/29_INSAN_KARARLARI.md](../docs/29_INSAN_KARARLARI.md) →
 **"EK — İNSANIN KENDİ ANVİL DOĞRULAMASI"** (Deploy → Bootstrap → `cast balance = 0`
 → müşteri demosu, 5 dakika).

```bash
anvil --port 8545 --block-time 2 --host 127.0.0.1 &     # ayrı terminal
export RPC=http://127.0.0.1:8545
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge script script/Bootstrap.s.sol --rpc-url $RPC --broadcast --unlocked
# → "HAZIR: mint acik, cap $100k, junior %3" rc=0
cast balance $CUSD_ADDR --rpc-url $RPC
# → 0   ← ETH kilitlenmedi (önceki --value yöntemi 3000 ETH'yi sonsuza kilitlerdi)
```

---

## Kanıt protokolü (her doğrulamada)

```
IDDIA:  [yapılan iş]
KANIT:  [yukarıdaki komut]
RC:     0
COMMIT: [git hash]
```

---

## İlgili dokümanlar

- [docs/29_INSAN_KARARLARI.md](../docs/29_INSAN_KARARLARI.md) — 3 insan kararı + RED FLAGS + anvil EK
- [../24_DEPLOY_VE_CANLIYA_ALMA_REHBERI.md](../24_DEPLOY_VE_CANLIYA_ALMA_REHBERI.md) — 5 adım deploy
- [../README.md](../README.md) — hızlı başlangıç (5 adım)
