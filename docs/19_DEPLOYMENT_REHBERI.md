# Cleanvest Deployment Rehberi

**Tarih:** 2026-09-25  
**Durum:** 100/100 Foundry testi yeşil, deployment dry-run doğrulandı

---

## Hızlı Başlangıç

```bash
# Tüm adresleri ENV'den al (uydurma adres KULLANILMAZ)
export PRIVATE_KEY=0x...           # deploy cuzuani
export RPC_URL=https://mainnet.base.org

# Opsiyonel: production adresleri (bagli degilse address(0) ile deploy edilir,
# deploy sonrasi setX() ile baglanir)
export AAVE_POOL=0x...
export AAVE_PRIME_POOL=0x...
export CHAINLINK_FEED=0x...
export UNISWAP_ROUTER=0x...
export AEGISFORGE_ORACLE=0x...

# Dry-run (gas tahmini, broadcast YOK)
forge script script/Deploy.s.sol:Deploy

# Gercek deploy
forge script script/Deploy.s.sol:Deploy \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify
```

## Deploy Edilen 6 Sozlesme

| Sıra | Sözleşme | Adres (dry-run) | Bağlantı |
|---|---|---|---|
| 1 | CleanUSD | `0xc5f0...123A` | sabit $1.00, REBASE YOK |
| 2 | CleanFXVault | `0xd5a4...0f89` | asset = CleanUSD |
| 3 | ReserveManager | `0x2FC5...0e66` | Aave katmani |
| 4 | CleanvestSettlement | `0x26b4...ff0A` | HEX borsa |
| 5 | ListingGate | `0x6565...4d3D` | CleanAudit zorunlu |
| 6 | UniswapProxy | `0xFBa2...6989` | artık hacim |

## Deploy Sonrasi Adimlar

### 1. Founder Tohum (CleanUSD)

`seedJunior` ile $3.000 tohum → **$100.000 TVL tavanı** (3% junior invariant).

```solidity
// founder (owner)
cleanUSD.seedJunior{value: 3_000 ether}(0);
// tvlCap = 3000 * 10000 / 300 = 100.000
```

⚠️ **Bu, hard invariant'ı başlatır.** Bundan sonra:
- `mint()` yalnızca `juniorReserve * 10000 >= tvl * 300` iken çalışır
- `burn()` **asla** kilitlenmez

### 2. CleanAudit Oracle Baglama

```solidity
listingGate.setCleanAuditOracle(AEGISFORGE_ORACLE);
```

Bu olmadan **hiçbir proje** listelenemez (listing gate kapalı).

### 3. RFQ Solver Kaydetme (CleanvestSettlement)

```solidity
settlement.registerSolver(SOLVER_1);
// 2 solver -> LE-2 lift trigger: $5.000 emir tavani OTOMATIK kalkar
```

### 4. Chainlink Feed Baglama

```solidity
settlement.setChainlinkFeed(CHAINLINK_FEED);
reserve.setAaveUtilizationFeed(CHAINLINK_FEED);
```

⚠️ **OPTIMIZE modu** feed bagli degilken ACILAMAZ (SAFE mod varsayilan, %12 idle).

## Guvenlik Kontrol Listesi

- [x] **REBASE YOK** — CleanUSD'de rebase fonksiyonu yok
- [x] **"ZK-SNARK" iddia edilMIYOR** — PoV_Hash hash taahhududur
- [x] **"Sifir kayma" vaat edilMIYOR** — UniswapProxy kaymayi seffaf raporlar
- [x] **Cikislar ASLA kilitlenmez** — T+2 kuyrugu 2 gun sonra otomatik acilir
- [x] **Harc modeli YOK** — `applicationFee() = 0`, CleanScore ucretsiz
- [x] **Sifir kurucu sermayesi** — CoW netting + RFQ

## Test Komutlari

```bash
# Tum testler (100/100)
forge test

# Sadece entegrasyon
forge test --match-contract IntegrationTest

# Gas raporu
forge test --gas-report
```

## Sorun Giderme

### "Pool sifir olamaz"
Aave pool address(0) ile set edilemez. `AAVE_POOL` ENV degiskenini tanimlayin veya deploy sonrasi `reserve.setAavePool(...)` cagirin.

### "TVL-Kapili Degismez: Junior <%3, mint kilitli"
Founder tohumu yeterli degil. `seedJunior{value: X}(0)` ile X >= (hedef TVL * 0.03) verin.

### "Once requestRedemption ile kuyruga girin"
T+2 kuyrugu: once `vault.requestRedemption(amount)` cagirin, 2 gun bekleyin, sonra `withdraw()`. Bu **yanlis degil, dogru davranistir** — Solidity revert state'i geri alir.

### "OPTIMIZE: utilization feed bagli degil"
`reserve.setAaveUtilizationFeed(FEED)` ile Chainlink feed'i baglayin.
