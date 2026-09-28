# GAS OPTIMIZASYON ANALIZI — Cleanvest (2026-09-26)

**Olcum araci:** `forge test --gas-report` (taze olculdu)
**Kapsam:** 7 sozlesme, 186 test
**Yontem:** En pahali fonksiyonlar tespit edildi, optimizasyon onerileri
yazildi. **HICBIRI uygulanmedi** — once olcum, sonra karar.

---

## 1. En Pahali 5 Fonksiyon (gercek olcum)

| Fonksiyon | Min | Avg | Median | Max | Cagri |
|---|---|---|---|---|---|
| `withdraw` (CleanFXVault) | 46.143 | **70.284** | 74.301 | 89.410 | 20 |
| `withdrawFromVault` (Handler) | 29.353 | 43.301 | 31.853 | 112.512 | 2.853 |
| `withdrawFromAave` (ReserveManager) | 29.562 | 38.962 | 32.842 | 60.605 | 4 |
| `upgradeAuditTier` (ListingGate) | 21.963 | 40.346 | 43.095 | 54.222 | 12 |
| `withdrawReserve` (ReserveManager) | 29.519 | 32.051 | 31.753 | 34.882 | 3 |

---

## 2. Analiz: Neden Pahalilar?

### `withdraw` (70.284 avg) — EN PAHALI

**Sebebi (kod analizi):**
1. ERC-4626 `_withdraw` override — `queuedRedemptionAmount` kontrolu
2. `dailyRedemptions` update + queue dal kontrolu
3. USDC `transfer` (external call, ~50k gas)
4. OZ v5 `_update` hook + event emit

**Optimize edilebilir mi?** KISMEN:
- `queuedRedemptionAmount` mapping okuma SLOAD ~2.100 gas — **optimize edilmez**
  (güvenlik gereği, BULGU-1'in çözümü)
- External USDC transfer ~50k — **optimize edilemez** (zorunlu)
- **Sonuc:** ~10k gas azaltma potansiyeli var ama güvenlik/zaman dengesi
  uygun degil. **DEGISIKLIK ONERILMEZ.**

### `withdrawFromVault` (43.301 avg)

Handler test fonksiyonu — **uretilen kod degil**, test altyapisi.
Optimize edilmesi anlamsiz (test hizi etkilemez).

### `upgradeAuditTier` (40.346 avg)

**Sebebi:** Enum kontrolu + tier event + audit state update.
**Sonuc:** Makul; **optimize edilmez** (her cagri 1 kez yapilir).

---

## 3. Optimizasyon Onerileri (DEGERLENDIRILDI)

| Oneri | Kazanim | Risk | Karar |
|---|---|---|---|
| `immutable` yerine `constant` (tier threshold) | ~200 gas/cagri | Yok | 🔴 **Zaten constant** |
| Storage packing (juniorReserve + tvlCap) | ~2.100 gas | Yüksek (upgrade riski) | 🔴 **RED - güvenlik > 2k gas** |
| Custom errors yerine string revert | ~50 gas/revert | Düsük | 🟡 **100+ revert var, kucuk kazanim** |
| ERC-4626 hooks kaldirma | ~5k gas | **GÜVENLIK RISKI** | 🔴 **RED - kesinlikle hayir** |
| Batch multiple withdraw | Tek seferde N cikis | UI karmaşası | 🟡 **v2 yol haritasi** |

---

## 4. DÜRÜST SONUC

**Optimizasyon YAPILMADI.** Sebebi:

1. **Güvenlik > Gas:** En pahali fonksiyon `withdraw` tam olarak
   güvenlik katmanini tasiyor (BULGU-1 çözümü). 10k gas icin güvenlik
   azaltma dogru degil.
2. **Base network gas dusuk:** Base'te 70k gas ~$0.01-0.05 maliyet.
   Kullanici icin Ihmal edilebilir.
3. **Yanlis optimizasyon = bug riski:** "Erken optimizasyon koktur"
   (Knuth). Mevcut kod 186 test ile kanitlanmis; degisim riski
   kazanimi asar.

**Sonuc:** Gas profili TURUM icin makul; DEGISIKLIK YAPILMADI.

---

## 5. Olcum Yontemi (tekrarlanabilir)

```bash
export PATH="$HOME/.foundry/bin:$PATH"
forge test --gas-report > /tmp/gas.txt 2>&1
grep -E "^\| [a-z]" /tmp/gas.txt
```

**Not:** Invariant handler tablosu (`CleanFXVault deposit 3194 calls`)
test altyapisidir; gercek fonksiyon gas maliyetleri ustteki tabloda.

---

## 6. Kapasite Raporu

- **Maksimum tek islem:** 112.512 gas (`withdrawFromVault` edge case)
- **Tipik kullanici cikisi:** ~70.284 gas
- **Base block gas limiti:** 30M (yaklasik %0.2'i)

**Sonuc:** Hicbir fonksiyon blok limitine yakin degil; kapasite sorunu YOK.
