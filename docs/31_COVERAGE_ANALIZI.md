# 31 — COVERAGE ANALİZİ: %99.42 → %100 (kalan %0.58 NEREDE?)

**Tarih:** 2026-09-27 · **Hazırlayan:** cleanvest-dev (vardiya 4)
**Ölçüm:** `forge coverage --report lcov` — lcov DA/BRDA parser ile
**Sonuç:** Kalan açıklığın **tümü matematiksel olarak ulaşılamaz** (dead-by-design
 defense-in-depth). %100'e test ile çıkılamaz — sebebi aşağıda ispatlandı.

---

## Mevcut durum (6 sözleşme)

| Sözleşme | Line | Branch |
|---|---|---|
| CleanFXVault | 79/79 = **100%** | 31/31 = **100%** |
| CleanUSD | 34/36 = 94.44% | 12/13 = 92.31% |
| CleanvestSettlement | 48/48 = **100%** | 28/28 = **100%** |
| ListingGate | 78/78 = **100%** | 27/28 = 96.43% |
| ReserveManager | 75/75 = **100%** | 32/32 = **100%** |
| UniswapProxy | 27/27 = **100%** | 13/13 = **100%** |
| **TOPLAM** | **341/343 = 99.42%** | **143/145 = 98.62%** |

> **Not:** `forge coverage` genel rakamı `script/*.s.sol`'in %0'ı yüzünden düşer.
> Yukarıdakiler **6 sözleşme** içindir (anlamlı metrik). 166 test ile ölçüldü.

---

## Kalan 2 açık nokta — İSPAT: ulaşılamaz

### 1. CleanUSD.sol L102-104 — `if (!canMintAfter(amount))` true dalı

```solidity
L98:  function mint(address to, uint256 amount) external {
L99:      require(canMint(), "TVL-Kapili Degismez: Junior <%3, mint kilitli");
L100:     require(totalSupply() + amount <= tvlCap, "TVL tavani asildi");
L102:     if (!canMintAfter(amount)) {        // ← branch: true dalı TAKEN=0
L103:         emit MintGateTriggered(...);     // ← LINE: kapsanmıyor
L104:         revert("Bu mint invariant'i ihlal eder");  // ← LINE: kapsanmıyor
L105:     }
```

**İSPAT (matematiksel):**

`canMintAfter(amount)` tanımı (L119-121):
```
canMintAfter ⟺ juniorReserve × 10000 ≥ (totalSupply + amount) × 300
```

`tvlCap` tanımı (ilk `seedJunior`, L77):
```
tvlCap = seed × 10000 / 300      (seed = o anki juniorReserve)
```

L100 geçtiyse: `totalSupply + amount ≤ tvlCap = seed × 10000 / 300`
⟹ `(totalSupply + amount) × 300 ≤ seed × 10000`

`seedJunior` juniorReserve'i **yalnızca artırır** (`juniorReserve += seed`),
 azaltan fonksiyon YOK ⟹ `juniorReserve ≥ seed` her zaman.

⟹ `(totalSupply + amount) × 300 ≤ seed × 10000 ≤ juniorReserve × 10000`
⟹ **`canMintAfter(amount)` her zaman TRUE** (L100 geçtiğinde)

⟹ `!canMintAfter(amount)` her zaman FALSE ⟹ L102'nin if gövdesine **HİÇ
 girilemez** ⟹ L103-104 çalışmaz.

**Sonuç:** L100 (tvlCap) ile L102 (canMintAfter) **matematiksel olarak eşdeğer**
 kontrol eder. L100 her zaman önce bağlayıcı olduğundan L102'nin true dalı ** ölüdür**.

**Neden kaldırılmıyor?** Natspec'te belgelendi (L90-97): defense-in-depth.
 İleride tvlCap mantığı değişirse (yönetişim ile cap artışı vb.), hard invariant
 (junior ≥ %3) yine korunur. **Kastlı güvenlik katmanı.**

**Test ile kanıt denemesi:** L100'ü geçip L102'yi false'a düşürmek için
 `totalSupply + amount ≤ tvlCap` ama `(totalSupply+amount)×300 > juniorReserve×10000`
 gerekir — yukarıdaki ispat bunun imkansız olduğunu gösterir. **Yazılamaz test.**

---

### 2. ListingGate.sol L214 — `require(uint256(newTier) <= uint256(AuditTier.Priority))`

```solidity
L208:  function upgradeAuditTier(address projectToken, AuditTier newTier) external onlyAegisForge {
L214:      require(uint256(newTier) <= uint256(AuditTier.Priority), "Gecersiz kademe");
```

**İSPAT:**

```solidity
enum AuditTier { None, Scan, FuzzPatch, Priority }  // değerler: 0, 1, 2, 3
```

Solidity ABI **decoder**'i, `AuditTier` enum parametresini decode ederken değerin
 `[0, max]` = `[0, 3]` aralığında olduğunu **zorunlu** doğrular. 4+ bir değer
 gönderildiğinde decode **panik** verir (Panic 0x21) ve **fonksiyon gövdesine
 girilmeden** revert olur.

⟹ Fonksiyon gövdesine ulaşıldığında `uint256(newTier) ≤ 3` **her zaman true** ⟹
 L214'ün require'ı **asla revert etmez** ⟹ false dalına girilemez.

**Kanıt testi:** `testRevertInvalidTierOutOfRange` (`test/ListingGate.t.sol`, commit
 `0b598b7`) — raw calldata ile `uint8(99)` gönderir; decoder katmanında revert
 eder, L214'e ulaşmaz. Bu, korumanın **decoder seviyesinde** olduğunu kanıtlar.

**Neden kaldırılmıyor?** Natspec L211-213'te belgelendi: defense-in-depth.
 Doğrudan `call` (ABI decode'siz) ile gelecek bir saldırıya karşı katman.

---

## Özet: %100'e neden çıkılamaz?

| Açıklık | Satır | Sebep | Ulaşılamaz mi? |
|---|---|---|---|
| CleanUSD canMintAfter true dalı | L102-104 | L100 ile cebirsel eşdeğer (ispat yukarıda) | ❌ **Evet, matematiksel** |
| ListingGate enum üst sınır | L214 | ABI decoder enum'ı zaten doğruluyor | ❌ **Evet, dil seviyesinde** |

**Dürüst sonuç:** %100 line/branch **test ile ulaşılabilir değil**. Kalan 2 dal
 kastlı defense-in-depth katmanlarıdır; natspec'lerinde belgelenmiş,
 "ulaşılamaz" tasarım kararlarıdır. **%99.42/%98.62 nihaidir.**

> **Karar verene not:** Bu 2 dalı kapsamak için ya güvenlik katmanı
> sökülür (tavsiye edilmez) ya da test, sözleşme içi mantığı aşmaya çalışır
> (imkansız). Mevcut durum **en doğru** durum: her açık dalın bir sebebi ve
> natspec'i var.

---

## Kanıt Protokolü

```
IDDIA:  Kalan %0.58 coverage açıklığı matematiksel olarak ulaşılamaz (dead-by-design)
KANIT:  forge coverage --report lcov; python3 lcov parser (DA/BRDA)
RC:     0
CIKTI:  2 acik dal: CleanUSD L102-104 (cebirsel esdeger), ListingGate L214 (ABI decoder)
COMMIT: <bu vardiyanin commit hash'i>
```

**İlgili:** [test/README.md](../test/README.md) — koşum komutları ·
 [README.md](../README.md) L89-92 — coverage notu
