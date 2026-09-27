# Cleanvest — Müşteri Onboarding Rehberi

**Tarih:** 2026-09-25 · **Sürüm:** v1.0 · **Durum:** Canlı demo hazır (anvil), mainnet HITL bekleniyor

---

## Hızlı Başlangıç

Müşteri ürünü **tek komutla** görebilir (anvil gerekir):

```bash
# 1. anvil başlat (yerel test ağı, hesaplar unlock)
anvil --port 8545 --block-time 2 --host 127.0.0.1 \
  --mnemonic "test test test test test test test test test test test junk"

# 2. Demo'yu çalıştır
#    ÖNEMLİ: PRIVATE_KEY env ZORUNLU (anvil varsayılan anahtarı)
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge script script/Demo.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --unlocked
```

**Çıktı:** `=== ONCHAIN EXECUTION COMPLETE & SUCCESSFUL ===` (rc=0)

> **`--unlocked` bayrağı:** Alice'in işlemleri için gerekli (anvil tüm hesapları unlock eder). Yoksa `No associated wallet` hatası alınır.

Demo 6 adımı gerçek işlemlerle gösterir: deploy → $100K yatırım → 1 yıl getiri → anlık %10 çıkış → T+2 kalan → junior ≥%3 invariant.

---

## Adım Adım Ürün Akışı

### Adım 1 — cUSD Yatırın
Müşteri `cUSD` (sabit $1.00, rebase yok) ile girer. Onay sonrası vault'a yatırır:

```solidity
// Slippage kalkanı: minShares = beklenen payın %99.5'i
uint256 expected = vault.convertToShares(100_000 ether);
uint256 minShares = (expected * 9950) / 10000;
vault.depositWithMin(100_000 ether, alice, minShares);
```

> **Neden minShares?** ERC-4626 enflasyon saldırısına karşı aktif koruma ([güvenlik notu](#güvenlik)).

### Adım 2 — scUSD Alırsınız
Vault `scUSD` (ERC-4626 payı) basar. Her `scUSD` = arkasındaki `cUSD` + birikmiş getiri.

### Adım 3 — Getiri Otomatik Birikir
Getiri kademelere göre kod sabitidir, manuel müdahale yok:

| Kademe | TVL eşiği | Yıllık getiri |
|---|---|---|
| Tier 0 | < $250k | **%3,05** |
| Tier 1 | $250k – $12,5M | **%2,91** |
| Tier 2 | ≥ $12,5M | **%2,92** |

Kaynak: `CleanFXVault.sol` L23-24 (eşikler), L79-85 (getiri sabitleri).

### Adım 4 — Anlık Çıkış (%10 kota)
Günlük TVL'nin %10'u anlık çekilebilir, kuyruk yok:

```solidity
vault.redeemWithMin(shares, alice, alice, minAssets);
```

### Adım 5 — T+2 Kuyruk (kalan)
Kotayı aşan kısım 2 gün sonra:

```solidity
vault.requestRedemption(20_000 ether); // T+2 kuyruğa alınır
```

> **Önemli:** Çıkışlar **ASLA kilitlenmez**. Yalnızca yeni mint durur (`CleanUSD.sol` L104 `burn` kilitlenmez).

### Adım 6 — Junior Güvenliği
Her an `juniorReserve ≥ TVL × %3` invariant'ı çalışır. İhlalde mint durur, çıkış devam eder.

---

## Fiyatlandırma (AegisForge ile)

| Paket | Fiyat | İçerik |
|---|---|---|
| **Scan** | **$199** | Otomatik rapor: 4 kademeli huni + PoV_Hash raporu |
| **Scan + İnsan Triyaj** | **$399** | Scan + insan uzman incelemesi (opsiyonel) |
| **FuzzPatch** | **$990** | Scan + 10k metamorfik fuzz + remediation diff |
| **Priority** | **$4.900** | Tümü + formal assurance + SLA + öncelikli destek |

Listeleme zorunludur: `ListingGate.upgradeAuditTier` (`ListingGate.sol` L208) ile doğrulanır.

---

## SLA ve Destek Penceresi

| Kalemler | Taahhüt |
|---|---|
| **Öncelikli yanıt** | Priority paketi: 4 saat (iş günü) |
| **Standart yanıt** | Scan/FuzzPatch: 24 saat |
| **Kritik güvenlik** | Tüm paketler: 1 saat (24/7) |
| **Remediation diff** | Pro/Max: 48 saat |
| **Formal assurance** | Max: 30 gün |

**Kapsam:** Akıllı sözleşme doğrulaması. **Kapsam dışı:** piyasa riski, oracle arızası (bkz. [risk dokümanı](28_RISKE_KARSI_UYARILAR.md)).

---

## Güvenlik

| Koruma | Kanıt |
|---|---|
| Enflasyon saldırısı kalkanı | `depositWithMin` / `redeemWithMin` |
| Junior ≥ %3 (mint-halt) | `CleanUSD.sol` L46, L90 |
| Çıkışlar asla kilitlenmez | `CleanUSD.sol` L104 |
| Sıfır manipülasyon | FBA eşleştirme, RFQ netting, Chainlink oracle |
| **186/186 Foundry testi** | `forge test` |
| **24/24 UI testi** | `pnpm vitest run` |
| **5 invariant** (300 derinlik) | `test/scusd_vault_invariants.t.sol` |

### Bulunan ve Düzeltilen 5 Gerçek Hata
Her biri commit kanıtıyla: anti-collusion overflow · ListingGate score-lookup sıfır · `seedJunior` erişim kontrolü · slippage overflow · çift floor.

---

## Onboarding Kontrol Listesi

- [ ] anvil demo çalıştırıldı (`SUCCESSFUL`, rc=0)
- [ ] Uygun paket seçildi (Scan / Scan+İnsan / FuzzPatch / Priority)
- [ ] TVL ve kademe eşleştirildi
- [ ] AegisForge denetimi tamamlandı
- [ ] Junior havuz yatırıldı (bizim tarafımızdan)
- [ ] Çıkış kapısı test edildi (anlık %10 + T+2)
- [ ] Risk dokümanı okundu ve imzalandı

---

## İletişim

> Bu doküman onboarding rehberidir. Nihai şartlar kurul toplantısında netleşir.

**Bağımsız doğrulama:** `export PATH="$HOME/.foundry/bin:$PATH" && forge test` — 186/186 sonucu herkes üretebilir.
