# 33 — PQHaven ↔ Cleanvest USDC Köprüsü: Solidity İmza Raporu (RAPOR MODU)

**Tarih:** 2026-09-27 · **Mod:** ⚠️ **RAPOR — KOD YAZILMADI** (lead onayı bekleniyor)
**Amaç:** Köprü için gerekli Solidity arayüz **imzalarını** çıkartmak; değişiklik
önermek değil, **mevcut durumu** ve **gereken ekleri** netleştirmek.

---

## 1. Mevcut Köprü Ayağı: `ReserveManager.depositReserve`

```solidity
function depositReserve(uint256 amount) external onlyOwner nonReentrant {
    require(amount > 0, "Miktar 0 olamaz");
    idleBalance += amount;   // ← SADECE accounting
}
```

**İmza:** `depositReserve(uint256)` → `()`, `onlyOwner`, `nonReentrant`

### 🔴 Engel 1 — Fon akışı YOK (accounting-only)

`depositReserve` **`usdc.transferFrom` çağırmıyor**. Yani:

- Çağıran (owner) `amount` kadar USDC approve etse bile **hiç USDC gelmiyor**
- `idleBalance` sadece bir **sayı** — destekleyen token bakiyesi değil
- `supplyToAave` ise **`usdc.transfer(aavePool, amount)`** yapıyor (L141) —
  bu fonksiyonların toplamı tutarsız: `supplyToAave`, `idleBalance`'a
  güvenir ama `idleBalance` gerçek USDC ile değil, keyfi sayı ile beslenir

**Test kanıtı (mevcut):** `test/ReserveManager.t.sol:28-30` —
`usdc.mint(address(reserve), 100_000 ether)` **önce reserve'a USDC basıyor**,
sonra `depositReserve(100_000 ether)` **sadece sayıyı** artırıyor. Yani test,
fon akışını **taklit ediyor** — gerçek USDC hareketi `depositReserve`'de değil,
mock'un `mint`'inde oluyor.

> **Bu bir bug mıdır?** Mevcut tasarım için **hayır** — ReserveManager,
> CleanFXVault'un reserve katmanını **model** olarak tutar (Tier hesabı için),
> gerçek fon hareketini **Aave entegrasyonu** (`supplyToAave`) yapar. Ama
> **PQHaven köprüsü için EVET** — guard'ın doğruladığı **gerçek USDC**
> akışının bir yerde `transfer`/`transferFrom` olması şart.

### 🔴 Engel 2 — `onlyOwner` (PQHaven treasury EOA çağıramaz)

`depositReserve` `onlyOwner`. PQHaven treasury'si (`UNPUMP_TREASURY_EOA`) bir
**EOA** — Cleanvest deployer'ından **farklı bir adres**. Köprü için:

- **Seçenek A (önerilen):** treasury USDC'yi **Cleanvest owner EOA'ya** transfer
  eder (guard'ın aradığı `Transfer(treasury → cleanvest-owner)` event'i budur),
  sonra owner `depositReserve` çağırır. **Sıfır sözleşme değişikliği.**
- **Seçenek B:** `depositReserve`'i yeni bir `depositReserveFrom` fonksiyonu
  ile `transferFrom` yapsaydık, treasury approve + çağrı yapabilirdi — ama
  **sözleşme değişikliği** ve yeni güvenlik yüzeyi.

### 🟡 Engel 3 — Desimal uyumsuzluğu (USDC 6 vs scUSD 18)

| Katman | Birim | Kanıt |
|---|---|---|
| PQHaven guard | **USDC 6-desimal** (`amount_usd * 1e6`) | `mainnet_verify.py:155` |
| ReserveManager | **`ether` = 18-desimal** | `TIER1_THRESHOLD = 250_000 ether` (L39) |
| CleanUSD seed | **18-desimal** | `Bootstrap.s.sol:35` `3_000 ether` |
| Test MockUSDC | **18-desimal** (standart ERC20) | `test/ReserveManager.t.sol:353` |

**Köprü fonksiyonu (yazılmadı, imza önerisi):** gerçek USDC 6-desimal kabul
edip ReserveManager'ın 18-desimal dünyasına **çevirmeli**:

```solidity
// ÖNERILEN IMZA (YAZILMADI — onay bekliyor)
function depositReserveUSDC(uint256 usdcAmount6) external onlyOwner nonReentrant {
    require(usdcAmount6 > 0, "Sifir olamaz");
    // 6-desimal USDC -> 18-desimal reserve birimi (1e12 ile carp)
    uint256 amount18 = usdcAmount6 * 1e12;
    require(usdc.transferFrom(msg.sender, address(this), usdcAmount6), "USDC transfer fail");
    idleBalance += amount18;
}
```

**Çevrim riski (onay için):** `usdcAmount6 * 1e12` — USDC max supply ~$1e12 →
`1e12 * 1e12 = 1e24` < `type(uint256).max ≈ 1.15e77`. **Taşma yok.**

---

## 2. Guard'ın Beklediği Event (köprünün doğrulama noktası)

```python
# mainnet_verify.py:32-34
TRANSFER_TOPIC = keccak256("Transfer(address,address,uint256)")
# topics: [Transfer_topic, _addr_topic(from), _addr_topic(to)]
# data:    amount (uint256, 6-desimal minor)
```

**Köprü senaryosu (Seçenek A, sıfır kod değişikliği):**

```
PQHaven müşterisi --USDC--> Treasury EOA
                           │ guard: find_transfer(musteri, treasury, price*1e6) → 402/503
                           ▼
Cleanvest owner EOA <--USDC-- Treasury EOA   ← KÖPRÜ ADIMI (EOA→EOA transfer)
                           │ guard bunu da dogrulayabilir (ayni event formati)
                           ▼
owner: depositReserve(usdc18) → idleBalance += amount (accounting)
owner: supplyToAave(...)      → usdc.transfer(aavePool) GERÇEK fon hareketi
```

> **Kritik gözlem:** Guard **bir `from→to` çifti** arar. Köprü adımı
> `treasury → cleanvest-owner` USDC transferi, guard'ın event formatıyla
> **birebir uyumlu** — ek doğrulama gerektirmez.

---

## 3. `juniorCoverageBps` = 1.157e77 — Tasarım Açıklaması (korundu)

```solidity
// CleanUSD.sol:54-59
function juniorCoverageBps() public view returns (uint256) {
    uint256 tvl = totalSupply();
    if (tvl == 0) return type(uint256).max;   // ← L58: 1.157e77
    return (juniorReserve * 10000) / tvl;
}
```

**Açıklama (canlı anvil'de kanıtlandı, commit `1bfe352`):**

| Durum | `juniorCoverageBps` | Anlamı |
|---|---|---|
| Bootstrap sonrası (TVL=0) | **`1.157e77`** = `type(uint256).max` | ✅ **Tasarım** — "tohum var, mint henüz yok" → örtü sonsuz |
| 1.000 cUSD depozit sonrası | **`15000`** (%150) | ✅ Gerçek değer — junior $3.000 / TVL $1.000 |

**Bu bir bug DEĞİL.** "Örtü oranını göster" fonksiyonu, sıfıra bölmeden
kaçınmak için bilinçli olarak `type(uint256).max` döner. `canMint()` de
aynı şekilde TVL=0'da `true` döner (L50).

> **Dokümantasyon koruması:** `24_DEPLOY` L322-327'deki "panik yapmayın"
> notu bir önceki vardiyanın düzeltmesi — bu rapor **o notu koruyor**,
> değiştirmiyor. "<300 ise mint durur" kuralı yine geçerli; yalnızca TVL=0
> özel durumu `max uint` ile ifade edilir.

---

## 4. Değişiklik Önerileri (ONAY BEKLİYOR — HİÇBİRİ YAZILMADI)

| # | Değişiklik | Gerekli mi? | Risk | 166 test etkisi |
|---|---|---|---|---|
| **A** | **Hiçbir sözleşme değişikliği yok** — treasury→owner EOA transferi + mevcut `depositReserve` | ✅ **Önerilen** | Sıfır | **Yok** (166/166 aynı kalır) |
| **B** | Yeni `depositReserveUSDC(uint256)` — `transferFrom` + 6→18 desimal çevrim | Opsiyonel | Yeni güvenlik yüzeyi (approve, decimals varsayımı) | Yeni test gerekir; mevcut 166 **etkilenmez** |
| **C** | `depositReserve`'e `transferFrom` eklemek | ❌ **ÖNERİLMEZ** | Mevcut 166 testten 9'u (`ReserveManager.t.sol`) mock mint akışına bağlı — **kırılma riski** | **YÜKSEK** |

**Seçenek C neden kırar:** `testDepositAndWithdrawReserve` (L219) ve 6 test
daha, `depositReserve`'i **approve'suz** çağırır. `transferFrom` eklenirse
revert olur → **9 test kırmızı** → 166 hedefi bozulur.

---

## 5. Kanıt Protokolü

```
IDDIA:  PQHaven-Cleanvest USDC koprusu icin Solidity imza raporu cikartildi (KOD YAZILMADI)
KANIT:  contracts/ReserveManager.sol L205-208 + test/ReserveManager.t.sol L28-30, L219-236
        mainnet_verify.py L32-34, L155; mainnet_guard.py L48-79; CleanUSD.sol L54-59
RC:     0 (forge test baseline: 166/166 degismedi — hicbir kod degistirilmedi)
COMMIT: (yok — rapor modu, commit atilmadi)
```

**Onay sonrası yapılacaklar (sırayla):**
1. Lead "Seçenek A" derse → **sıfır kod**, sadece köprü dokümantasyonu
2. Lead "Seçenek B" derse → yeni fonksiyon + **yeni testler** (166 → 166+N,
   mevcut testler korunur) + `forge test` ile doğrula
3. Her durumda **166/166 korunacak** — lead bağımsız olarak tekrar koşacak
