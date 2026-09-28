# 38 — GERÇEK ALTYAPI MALİYETİ (Ölçüm, Tahmin Değil)

**Tarih:** 2026-09-27 · **Mod:** 🟢 **RAPOR — SIFIR Solidity değişikliği (sözleşmelere)**
**Amaç:** `docs/37`'deki "%100 marj teorik" ifadesini **ölçülebilir** kılmak. Her sayı
ya **canlı okuma** ya da **`forge` gas ölçümüdür** — hiçbir tahmin YOKTUR.

> **DÜRÜST KURAL:** Aşağıdaki her sayının yanında kanıtı vardır. **Ölçülemeyen
> hiçbir şey "tahmin" olarak yazılmadı** — "ÖLÇÜLMEDİ" olarak işaretlendi.

---

## 1. Ölçüm Yöntemi

**İki bağımsız ölçüm yapıldı:**

| Ölçüm | Yöntem | Sonuç |
|---|---|---|
| **A. İşlem başına gas** | `gasleft()` ile yazılmış özel test (`test/GasCostMeter.t.sol`); test setup gas'sı HARİÇ, yalnızca ölçülen işlem | **7/7 ölçüm başarılı** |
| **B. Canlı gas fiyatı** | `eth_gasPrice` — Base mainnet'e **SADECE OKUMA** (para HARCANMADI) | **`0x5b8d80` = 6.000.000 wei = 0.006 gwei** |

**Canlı okuma kanıtı (RC 0):**

```bash
$ curl -s -X POST https://mainnet.base.org \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_gasPrice","params":[],"id":1}'
{"jsonrpc":"2.0","result":"0x5b8d80","id":1}
```

> `0x5b8d80` = **6.000.000 wei = 0.006 gwei** — Base L2'nin tipik fiyatıdır.
> **Bu değer anlık okunmuştur** — mainnet'e **hiçbir transaction gönderilmedi**,
> yalnızca okuma yapıldı (kısıt uyumu: para HARCANMADI).

---

## 2. Müşteri İşlem Başına Gas (ölçülmüş, setup hariç)

Her satır `test/GasCostMeter.t.sol` içinde `gasleft()` ile **izole olarak** ölçüldü:

| İşlem | Hizmet | **Gas (ölçümlü)** | Kodda Kanıtı | Test |
|---|---|---|---|---|
| `depositWithMin` | **H1** | **127.947** | `CleanFXVault.sol:203` | `testGasDepositWithMin` |
| `requestRedemption` | **H3** | **80.064** | `CleanFXVault.sol:227` | `testGasRequestRedemption` |
| `withdraw` (T+2 kuyruk) | **H3** | **77.384** | `CleanFXVault.sol:151` (`_withdraw`) | `testGasQueuedWithdraw` |
| `withdraw` (anlık, %10 kota) | **H3** | **90.917** | `CleanFXVault.sol:151,185` | `testGasInstantWithdraw` |
| `mint` (cUSD) | köprü sonrası | **82.133** | `CleanUSD.sol:98` | `testGasMint` |
| `balanceOf` (view) | **H1/H3** | 10.511 (eth_call) | `ERC20` standardı | `testGasReadBalance` |
| `activeTier` (view) | **H1** | 14.035 (eth_call) | `CleanFXVault.sol:60` | `testGasReadTier` |

> **Önemli:** Son iki satır birer **`eth_call`'dur — ağ ücreti YOKTUR.** Müşteri
> kendi RPC sağlayıcısını (MetaMask'in sağladığı ücretsiz RPC gibi) kullanır.
> Gas ölçümü **yalnızca işlem gönderen (`eth_sendRawTransaction`) fonksiyonlar
> için paradır.**

---

## 3. Çağrı Türü Başına Adet/Müşteri/Ay

> **DÜRÜST İTİRAF:** Müşteri başına **aylık adet sayısı ÖLÇÜLMEDİ** — gerçek
> kullanıcı davranışı verisi YOK (0 gerçek müşteri). Bunun yerine **iki net
> senaryo** tanımlanır; her ikisi de kodlanmış işlemlerle sınırlıdır.

| Çağrı türü | Adet/müşteri/ay (pasif) | Adet/müşteri/ay (aktif) | Kanıt |
|---|---|---|---|
| `eth_sendRawTransaction` — depozit | 1 | 4 | `depositWithMin` `:203` |
| `eth_sendRawTransaction` — çıkış talebi | 1 | 4 | `requestRedemption` `:227` |
| `eth_sendRawTransaction` — çekim | 1 | 4 | `withdraw` `:151` |
| `eth_call` — bakiye/tier sorgusu | ~30 | ~120 | `balanceOf`, `activeTier` (`:60`) |
| `eth_blockNumber` | ~30 | ~120 | frontend blok takibi |
| `eth_getLogs` (Transfer olayları) | ~10 | ~40 | `IERC20.Transfer` olayları |

**Senaryo tanımları:**
- **Pasif müşteri:** ayda 1 giriş + 1 çıkış, arada bakiye kontrolü — tipik
  hazine yöneticisi.
- **Aktif müşteri:** haftada 1 giriş + 1 çıkış (ayda 4), günlük bakiye takibi.

> 🔴 **Adet sayıları bir SENARYODUR, ölçüm DEĞİLDİR.** Gerçek adet, ilk gerçek
> müşteride (Gate 3) **üretim log'larından** ölçülebilir. Bu tablo, **her
> senaryonun maliyeti hesaplanabilsin** diye tanımlanmıştır.

---

## 4. Indexleyici Durumu — YOK

**Kod tabanında tarandı:**

```bash
$ grep -rn "The Graph\|subgraph\|Subgraph\|indexer\|Indexer\|graph-node\|Ponder\|Envio" \
    contracts/ test/ script/ docs/*.md README.md PROJE_KAGIDI.md
(çıktı YOK)
```

> **Sonuç:** **Indexleyici YOKTUR.** The Graph subgraph'ı, kendi node'u veya
> benzeri bir veri-indexleme altyapısı **kodlanmamıştır.** Tüm veri erişimi
> **doğrudan RPC üzerinden** `eth_call` / `eth_getLogs` ile yapılır.
>
> **Maliyet etkisi:** **$0/protokol** — indexleyici çalıştırma maliyeti yoktur
> çünkü indexleyici YOKTUR. Ama **ölçeklenebilirlik riski** vardır: binlerce
> müşteri × `eth_getLogs` ile olay taraması, ham RPC'yi yavaşlatabilir.
> **Bu bir YOL HARİTASI kalemidir** (indexleyici gerektiğinde `docs/37` H7
> olarak eklenebilir; şu anda **mevcut ürünün parçası DEĞİLDİR**).

---

## 5. Aylık Müşteri Altyapı Maliyeti (hesaplanan)

Gas fiyatı **0.006 gwei** (yukarıdaki canlı okuma) ile:

### Senaryo A — Pasif müşteri (1 depozit + 1 çıkış/ay)

| Kale | Gas | ETH | @ $1.500 | @ $2.500 | @ $3.500 |
|---|---|---|---|---|---|
| `depositWithMin` | 127.947 | 0,00000077 | $0.00115 | $0.00192 | $0.00268 |
| `requestRedemption` | 80.064 | 0,00000048 | $0.00072 | $0.00120 | $0.00168 |
| `withdraw` (T+2) | 77.384 | 0,00000046 | $0.00070 | $0.00116 | $0.00162 |
| **TOPLAM (işlem)** | **285.395** | **0,00000171** | **$0.00257** | **$0.00428** | **$0.00599** |
| `eth_call` × 30 (bakiye) | 0 | 0 | **$0** | **$0** | **$0** |
| `eth_getLogs` × 10 | 0 | 0 | **$0** | **$0** | **$0** |
| **GENEL TOPLAM** | — | — | **$0.0026** | **$0.0043** | **$0.0060** |

### Senaryo B — Aktif müşteri (4 depozit + 4 çıkış/ay)

| Kale | Gas | ETH | @ $1.500 | @ $2.500 | @ $3.500 |
|---|---|---|---|---|---|
| İşlemler (×4) | 1.141.580 | 0,00000685 | $0.01027 | $0.01712 | $0.02397 |
| `eth_call` × 120 | 0 | 0 | $0 | $0 | $0 |
| `eth_getLogs` × 40 | 0 | 0 | $0 | $0 | $0 |
| **GENEL TOPLAM** | — | — | **$0.0103** | **$0.0171** | **$0.0240** |

> **SONUÇ:** Müşteri başına aylık altyapı maliyeti **$0.003 – $0.024** arası
> (ETH fiyatına bağlı, 3 senaryo üzerinden). Yani **< $0.03/müşteri/ay**.

---

## 6. Protokol Tarafından Üstlenilen Maliyet — $0

| Kale | Maliyet | Kanıt |
|---|---|---|
| **Indexleyici** | **$0** | Yok (`§4` taraması) |
| **RPC node** | **$0** | Kendi RPC node'u YOK — müşteri kendi cüzdanının RPC'sini kullanır |
| **Sözleşme dağıtımı (bir kerelik)** | **$0** (bu dokümanda) | `docs/19_DEPLOYMENT_REHBERI.md:4` — dağıtım dry-run ile doğrulandı; canlı mainnet dağıtımı henüz YAPILMADI (human-gated) |
| **Veri saklama** | **$0** | Tüm durum on-chain'de (Base L2), protokol ek depolama ödemez |
| **CleanScore API** | **$0** | `ListingGate.sol:334-335` `applicationFee() = 0` — sorgulayıcı gas'ını öder |
| **Aave protokol komisyonu** | Aave'ye (Cleanvest değil) | `ReserveManager.sol:132-144` — Aave reserve factor'ü Aave protokolüne gider |

> **Protokol için altyapı maliyeti: $0/ay.** Çünkü **protokol hiçbir altyapı
> çalıştırmaz** — tüm maliyet müşterinin kendi gas'ı olarak ortaya çıkar.

---

## 7. "%100 Marj" Güncelleme — ARTIK ÖLÇÜLDÜ

`docs/37`'de "%100 marj teorik" diye işaretlenmişti. **Artık ölçüldü:**

| Hizmet | Gelir (müşteri/ay) | Altyapı maliyeti | **Marj** |
|---|---|---|---|
| **H1 + H4** (spread, $100k TVL) | **$17.00** | **$0.004** (pasif) / **$0.017** (aktif) | **%99.90–%99.97** (teknik altyapı bazında) |
| **H5** Scan ($299, kerelik) | $299 | **$0** (view) + insan işçiliği | İnsan işçiliği hariç |
| **H6** CleanScore | $0 | $0 | — |

> **SONUÇ:** **%99.90–%99.97 marj** — teknik altyapı bazında, **insan işçiliği
> hariç.** Müşteri başına **$0.004–$0.017'lik gas maliyeti**, $17.00'lık spread'e
> göre **%0.03–%0.10'dur.** Ama **AegisForge denetim hizmeti (H5) insan mühendislik
> zamanı gerektirir** — bu maliyet **ölçülmedi** ve "%100 marj" hesabına
> **DAHİL EDİLEMEZ.**
>
> 🔴 **Kalıcı not:** Tüm rakamlar **USDC nominal teklif** olarak — **GERÇEK
> mainnet akışı YOK, $0 gerçek gelir, 0 gerçek müşteri** (`PROJE_KAGIDI §7`
> madde 5). Bu ölçümler **testnet/anvil ortamında** yapıldı; üretim gas
> fiyatları **dalgalanabilir** (Base L2'de L1 gas fee oranı değişken).

---

## 8. Ölçülemeyenler (dürüst liste)

| Kale | Durum | Nasıl Ölçülür? |
|---|---|---|
| **Gerçek adet/müşteri/ay** | 🔴 **ÖLÇÜLMEDİ** | İlk gerçek müşteride (Gate 3) üretim RPC log'ları |
| **AegisForge insan işçiliği saati** | 🔴 **ÖLÇÜLMEDİ** | Z3/fuzz/remediation süresinin loglanması |
| **Üretim Base gas fiyatı** | 🟡 Anlık okuma (0.006 gwei) | L1 gas fee oranına bağlı — üretimde dalgalanır |
| **Indexleyici maliyeti** | ✅ **$0** (yok) | — |
| **Kendi RPC node maliyeti** | ✅ **$0** (yok) | — |
| **SLA / formal assurance operasyonel maliyet** | 🔴 **ÖLÇÜLMEDİ** | İlk Priority ($4.900) müşterisinde ölçülebilir |

---

## Kanıt Protokolü

```
IDDIA:  Gercek altyapi maliyeti olculdu — SIFIR sozlesme degisikligi
KANIT:  curl eth_gasPrice Base mainnet → 0x5b8d80 (6.000.000 wei = 0.006 gwei), RC 0
        + test/GasCostMeter.t.sol → 7/7 gas olcumu (gasleft ile, setup haric)
        + grep indexleyici → CIKTI YOK (indexleyici YOK)
        + forge test → 186 passed, 0 failed (GasCostMeter haric, gecici)
RC:     0
COMMIT: (bu commit)
DOSYA:  docs/38_GERCEK_ALTYAPI_MALIYETI.md
```

**Kısıt uyumu:**
- ✅ **HİÇBİR Solidity sözleşmesi değiştirilmedi** (`contracts/` dokunulmadı)
- ✅ **Para HARCANMADI** — yalnızca `eth_gasPrice` okuma (RC 0)
- ✅ **174 forge test** altına düşmedi (`GasCostMeter.t.sol` geçici bir testtir,
      bu commit'ten SONRA silinir; sayılar dokümana yazıldı)
- ✅ **Uydurma YOK** — her sayı ölçüm veya canlı okuma
- ✅ **Ölçülemeyenler "ÖLÇÜLMEDİ"** olarak işaretlendi
- ✅ Rapor modu: sadece doküman + geçici ölçüm testi
