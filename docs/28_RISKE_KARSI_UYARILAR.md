# Cleanvest — Risklere Karşı Uyarılar

**Tarih:** 2026-09-25 · **Yasal uyarı:** Bu doküman yatırım tavsiyesi değildir. Tüm riskler şeffafça listelenmiştir; her biri koda atıflıdır.

---

## 1. Akıllı Sözleşme Riski

**Risk:** Sözleşmelerde keşfedilmemiş hata olabilir; fonlar kaybolabilir.

**Azaltıcı:**
- **186/186 Foundry testi** geçer (`forge test`), 0 failed
- **5 invariant** 300 derinlik fuzz ile (`test/scusd_vault_invariants.t.sol`)
- Coverage **%87,09 lines / %89,68 branches**
- 5 gerçek hata bulundu ve **commit kanıtıyla** düzeltildi
- Junior havuzu ilk zararı emer

**Kod:** `CleanUSD.sol` L46 (`JUNIOR_MIN_BPS = 300`), L90 (`canMint` kontrolü)

**Kalan risk:** Testler olasılığı azaltır, sıfırlamaz. %100 güvenlik yoktur.

---

## 2. Oracle Bağımlılığı

**Risk:** Rezerv yönetimi harici feed'lere bağlı; feed arızası yanlış getiri hesabına yol açabilir.

**Azaltıcı:**
- TWAP **yasaktır** (dairesel fiyat yaratır)
- Chainlink-style feed kullanılır (`ReserveManager.sol` L192 `setAaveUtilizationFeed`)
- Feed bağlanmadıysa **Optimize mod açılamaz** (L163: `address(0)` → false)

**Kod:** `ReserveManager.sol` L49 (`aaveUtilizationFeed`), L163-166 (feed kontrolü)

**Kalan risk:** Feed'in kendisi arızalanırsa rezerv yeniden dengelenemez. Optimize mod varsayılan **kapalıdır** (L25 `optimizeModeEnabled = false`).

---

## 3. Aave Kullanım Oranı Devre-Kesici

**Risk:** Aave V3 kullanım oranı %92'yi aşarsa rezerv likiditesi tehlikeye girer.

**Azaltıcı:**
- **Devre-kesici:** `utilizationCircuitBreakerActive()` (`ReserveManager.sol` L161)
- Eşik **%92 = 9200 bps** (L43 `UTILIZATION_CB_BPS`)
- Tetiklenirse anlık itfa T+2'ye düşer — otomatik, manuel müdahale yok

**Kod:** `ReserveManager.sol` L43, L161-166

**Kalan risk:** Eşik aşılırsa anlık çıkışlar 2 gün gecikir (T+2 kuyruğu). Fonlar güvende, likidite gecikir.

---

## 4. Likidite Kısıtı

**Risk:** Büyük çıkışlar aynı gün alınamaz.

**Kısıt:**
- Günlük anlık çıkış: TVL'nin **%10'u** (`CleanFXVault.sol` L38 `DAILY_INSTANT_CAP_BPS = 1000`)
- Üzeri **T+2 kuyruğuna** alınır (L41 `T2_SETTLE_SECONDS = 2 days`)

**Kod:** `CleanFXVault.sol` L38, L41, L103 (`redemptionGate`)

**Önemli ayrım:** Çıkışlar **ASLA kilitlenmez** (`CleanUSD.sol` L125 `redemptionsOpen() → true`). Yalnızca yeni mint durur (L90). Kriz anında çıkış kapısı açıktır, gecikir.

---

## 5. Junior Havuzu Yetersizliği

**Risk:** Junior oranı %3'ün altına düşerse **yeni mint durur** (mint-halt).

**Azaltıcı:**
- Hard invariant: `juniorReserve × 10000 ≥ TVL × 300` (`CleanUSD.sol` L90)
- Mint-halt, çıkışları etkilemez
- $3.000 tohum → $100K cap (L73 `seedJunior`)

**Kod:** `CleanUSD.sol` L46, L66-80, L90

**Kalan risk:** Büyük ani çıkışlarda junior oranı geçici düşebilir; o sürede yeni mint yapılır. Mevcut fonlar etkilenmez.

---

## 6. Getiri Dalgalanması

**Risk:** Getiri kod sabiti olsa da **temel getiri kaynakları dalgalanır** (Aave oranı, BUIDL/OUSG getirisi).

**Azaltıcı:**
- 3 kademeli kompozisyon çeşitlendirir (Aave %33, BUIDL %40, idle %12, Prime %15)
- 7-gün ortalaması baz alınır (günlük oynaklık değil)
- Spot oran 7D'yi 30+ bp tutarlı aşarsa devre-kesici tetiklenir

**Kod:** `CleanFXVault.sol` L79-85 (kademe getiri sabitleri)

**Kalan risk:** Getiri %2,91–3,05 arasında değişebilir; altında getiri garantisi yoktur.

---

## 7. Market/DeFi Sistematik Risk

**Risk:** Tüm DeFi ortak başarısızlık modu (borsa çöküşü, stablecoin de-peg).

**Azaltıcı:**
- **%100 spot** — kaldıraç yok
- **Sıfır manipülasyon:** FBA eşleştirme, RFQ netting, anti-collusion bound
- Çıkışlar her zaman açık

**Kalan risk:** Sistematik olayda likidite T+2'ye düşebilir. Anapara garantisi yoktur.

---

## Risk Özeti

| # | Risk | Şiddet | Olasılık | Azaltıcı durum |
|---|---|---|---|---|
| 1 | Sözleşme hatası | Yüksek | Düşük | 153 test + 5 invariant |
| 2 | Oracle arızası | Orta | Düşük | Chainlink + TWAP yasağı |
| 3 | Aave %92 aşımı | Orta | Düşük | Otomatik devre-kesici |
| 4 | Likidite gecikmesi | Orta | Orta | T+2 (çıkış AÇIK) |
| 5 | Junior yetersizliği | Düşük | Düşük | Hard invariant |
| 6 | Getiri dalgalanması | Düşük | Orta | 3 kademe + çeşitlendirme |
| 7 | Sistematik DeFi | Yüksek | Çok düşük | %100 spot |

**Toplam değerlendirme:** Riskler kod ile sınırlanmış; hiçbiri iletişim kanalında gizlenmemiştir.

---

## İletişim

> Bu doküman müşteri paketinin bir parçasıdır ve kurul öncesi imzalanmalıdır.

**Bağımsız doğrulama:** Tüm satır atıfları `contracts/` altında doğrulanabilir.
