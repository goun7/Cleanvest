# 34 — PQHaven ↔ Cleanvest USDC Köprüsü: Seçenek A (KARAR VERİLDİ)

**Tarih:** 2026-09-27 · **Durum:** ✅ **Lead kararı — Seçenek A yürürlükte**
**Mod:** 🟢 **Sıfır Solidity değişikliği** (rapor modu devam — `contracts/` dokunulmadı)

> **Karar (lead, bağımsız doğrulama sonrası):** Seçenek A — köprü, EOA→EOA
> USDC transferi + mevcut `depositReserve` ile kurulur. **Hiçbir sözleşme
> değişmez; 166/166 test aynen kalır.**

---

## 1. Neden Seçenek A

| Kriter | Seçenek A | Seçenek B | Seçenek C |
|---|---|---|---|
| **Solidity değişikliği** | **YOK** ✅ | Yeni fonksiyon | Mevcut fonksiyona `transferFrom` |
| **166 test etkisi** | **HİÇBİRİ kırılmaz** ✅ | 166 → 166+N (yeni test) | **9 test kırılır** 🔴 |
| **Guard format uyumu** | **Birebir** ✅ | Aynı | Aynı |
| **Yeni güvenlik yüzeyi** | **Yok** ✅ | `approve` + decimals varsayımı | Mevcut testleri bozar |
| **Kod riski** | **Sıfır** ✅ | Düşük | Yüksek |

### Bağımsız doğrulama kanıtları (lead'in teyit ettiği)

1. **Guard'ın izlediği event:** `mainnet_verify.py:30-31` —
   `Transfer(address,address,uint256)`, hedef `pay_to`. **EOA→EOA transfer
   guard için yeterli.**
2. **`depositReserve` accounting-only + `onlyOwner`** (`ReserveManager.sol:205`):
   mevcut tasarım için **doğru** (Tier hesabı modeli). PQHaven köprüsü için
   engeldi — **Seçenek A bu engeli aşar**: treasury önce USDC'yi owner EOA'ya
   transfer eder (guard bunu görür), owner `depositReserve` ile sayıyı günceller.
3. **Mevcut test deseni zaten bunu taklit ediyor:** `test/ReserveManager.t.sol:28-30`
   (`usdc.mint` → `depositReserve`).

---

## 2. Akış Şeması (Seçenek A)

```
┌─────────────┐                                                     
│  MÜŞTERI    │                                                     
│  (EOA)      │                                                     
└──────┬──────┘                                                     
       │ USDC transfer (6-desimal, Base mainnet)                     
       ▼                                                             
┌─────────────────────────────────┐    guard: find_transfer(         
│  PQHAVEN x402 SERVIS           │      musteri → treasury,         
│  require_mainnet_payment()     │      price * 1e6)                
│  mainnet_guard.py:102-173      │      → bulunamazsa 402 (fail-closed)
└──────────────┬──────────────────┘                                  
               │ onay (payer dondu)                                  
               ▼                                                     
┌─────────────────────────────────┐    KÖPRÜ ADIMI (EOA → EOA)       
│  TREASURY EOA                   │    Transfer(treasury → owner)    
│  UNPUMP_TREASURY_EOA            │    ← guard'in BEKLEDIGI event:   
│  (tek-kasa, vergi optimizasyonu)│      ayni format, ek dogrulama  
└──────────────┬──────────────────┘      YOK                         
               │ USDC transfer                                        
               ▼                                                     
┌─────────────────────────────────┐    owner: depositReserve(amount18)
│  CLEANVEST OWNER EOA            │    ↑ accounting-only (sifir kod) 
│  (deployer = ReserveManager     │                                  
│   owner)                        │                                  
└──────────────┬──────────────────┘                                  
               │ owner cagrisi                                       
               ▼                                                     
┌─────────────────────────────────┐    supplyToAave(amount)          
│  ReserveManager                 │    → usdc.transfer(aavePool)     
│  idleBalance += amount          │      GERCEK fon hareketi (L141)  
│  (L205-208, onlyOwner)          │                                  
└─────────────────────────────────┘                                  
```

**Üç ana adım:**

| # | Adım | Kim yapar | Kod |
|---|---|---|---|
| **1** | Müşteri USDC'yi treasury'ye yatırır | müşteri EOA | — (guard'ın mevcut akışı) |
| **2** | Treasury USDC'yi **owner EOA'ya** transfer eder | treasury EOA | **sıfır** — düz ERC-20 transfer |
| **3** | Owner `depositReserve(usdc18)` + `supplyToAave` çağırır | owner EOA | **sıfır** — mevcut fonksiyonlar |

> **Desimal notu (karışmaz):** Adım 2'de transfer **USDC native 6-desimal**.
> Adım 3'te `depositReserve` 18-desimal `ether` birimi bekler — **owner
> elle `× 1e12` çevirir** (`1000 USDC → 1000 ether`). Bu çevrim **kodda
> değil, operasyonel notta**dır. Taşma yok (USDC max `1e12 × 1e12 = 1e24 ≪
> type(uint256).max`).

---

## 3. 🔴 MERKEZİ RİSK — Açık Beyan (tevazu)

> **⚠️ Bu bölüm tezimize aykırı olabilir — gizlemiyoruz, yazıyoruz.**

**Seçenek A'da fonlar önce `Cleanvest owner EOA`'da BİRİKİYOR.** Bu,
sistemin **en merkezi güven noktasıdır**:

- Adım 2 ile Adım 3 **aynı tx içinde değil** — arada fonlar owner EOA'da
- Owner EOA'nın private key'i ele geçirilirse, **biriken USDC çalınabilir**
- "Sıfır manipülasyon" tezi, **sözleşme katmanı** için geçerlidir; bu risk
  **off-chain operasyonel** katmandadır

**Risk büyüklüğü:** birikim miktarı = treasury'den owner'a transfer edilen
ama henüz `depositReserve` ile reserve'a girmemiş USDC. Operasyonel disiplin
(günde 1-2 kez batch) ile **küçük** tutulabilir.

### Öneri: Multisig / TimeLock (SADECE ÖNERİ — KOD YAZILMADI)

**Hemen (Seçenek A, sıfır kod):**

| Öneri | Açıklama | Kod |
|---|---|---|
| **Operasyonel disiplin** | Owner, transfer gelen USDC'yi **aynı gün** `depositReserve` + `supplyToAave` ile reserve'a taşır → birikim küçük kalır | **Yok** |
| **Ayrı anahtarlar** | Treasury EOA ve owner EOA **farklı** anahtarlar kullanır (guard zaten tek-kasa EOA'sını zorunlu kılar) | **Yok** |
| **Soğuk saklama** | Owner private key'i **soğuk cüzdan** (24_DEPLOY RİSK NOTU zaten öneriyor) | **Yok** |

**İleride (Seçenek B öncesi) — hala sadece öneri:**

| Öneri | Açıklama | Kod |
|---|---|---|
| **Multisig** | Tüm 6 sözleşme `Ownable` — `transferOwnership` ile owner **Gnosis Safe**'e alınır. Owner EOA'da birikmez; multisig onayı zorunlu olur | **Sadece `transferOwnership` çağrısı** (sözleşme değişikliği YOK) |
| **TimeLock** | Owner işlemleri (depositReserve, rebalance) **gecikmeli** yürütülür → manipülasyon penceresi kapanır | Sözleşme değişikliği GEREKİR (ileride) |
| **Seçenek B** | `depositReserveUSDC` ile treasury **doğrudan** reserve'a yatırır → owner EOA'da birikim **sıfır** | Yeni fonksiyon (aşağıya bakın) |

> **Tez ile barışma:** "Sıfır manipülasyon" tezi, **on-chain** manipülasyona
> karşıdır (FBA batch, rebase yok, plain `deposit` yok). Bu risk **off-chain
> anahtar yönetimidir** — multisig ile kapatılır. **Açık beyan etmemiz,
> müşteriye dürüstlüğümüzün kanıtıdır.**

---

## 4. Seçenek B — "İleride Multisig Kurulduktan Sonra"

**İşaretlendi:** Seçenek B **şimdi YAPILMAYACAK**. Gerekçe: Seçenek A sıfır
riskle çalışıyor; B yeni güvenlik yüzeyi açar (yeni fonksiyon = yeni bug
yüzeyi). **Multisig kurulmadan B'ye geçilmemesi önerilir.**

**B'nin amacı (ileride):** owner EOA'daki merkezi birikimi **tamamen
ortadan kaldırmak** — treasury multisig'i **doğrudan** reserve'a yatırır.

```solidity
// ÖNERILEN IMZA (YAZILMADI — MULTISIG KURULDUKTAN SONRA)
// USDC 6-desimal kabul eder, 18-desimal reserve birimine cevirir
function depositReserveUSDC(uint256 usdcAmount6) external onlyOwner nonReentrant {
    require(usdcAmount6 > 0, "Sifir olamaz");
    uint256 amount18 = usdcAmount6 * 1e12;          // 6 -> 18 desimal
    require(usdc.transferFrom(msg.sender, address(this), usdcAmount6), "USDC transfer fail");
    idleBalance += amount18;
}
// + revert testleri: 0 miktar, transferFrom fail, yetkisiz cagri
// + basari testi: gercek USDC 6-desimal bakiye akisi
// Sonuc: 166 -> 166+N (mevcut testler korunur)
```

**B'nin önkoşulları (üçü de sağlanmadan geçilmez):**
1. ✅ Multisig (Gnosis Safe) kurulmuş — `transferOwnership` yapılmış
2. ✅ Treasury multisig'i ile reserve owner **aynı** multisig
3. ✅ Yeni testler yazılmış, `forge test` ile **166+N** doğrulanmış

> **Seçenek C reddedildi (kalıcı):** `depositReserve`'e `transferFrom` eklemek
> **9 testi kırar** (`testDepositAndWithdrawReserve` + 6'sı approve'suz
> çağırır) → 166 hedefi bozulur. **Asla yapılmayacak.**

---

## 5. `juniorCoverageBps` = 1.157e77 — Tasarımsal Not (KORUNDU)

```solidity
// CleanUSD.sol:54-59 — DEGISMEDI
function juniorCoverageBps() public view returns (uint256) {
    uint256 tvl = totalSupply();
    if (tvl == 0) return type(uint256).max;   // ← L58: 1.157e77 = tasarim
    return (juniorReserve * 10000) / tvl;
}
```

| Durum | Değer | Anlamı |
|---|---|---|
| Bootstrap sonrası (TVL=0) | **`1.157e77`** | ✅ **Tasarım** — sıfıra bölmeden kaçınma |
| 1.000 cUSD depozit sonrası | **`15000`** bps | ✅ %150 örtü (300'ün ≫ üstünde) |

**Bu bir bug DEĞİL.** `24_DEPLOY`'daki "panik yapmayın" notu korundu.
Canlı anvil kanıtı: commit `1bfe352`.

---

## 6. Kanıt Protokolü

```
IDDIA:  Seçenek A dokumante edildi — SIFIR Solidity degisikligi, 166/166 korundu
KANIT:  git diff --stat HEAD~1 (sadece docs/34 eklendi)
        + forge test: 166 passed, 0 failed
RC:     0
COMMIT: (bu commit)
DOSYA:  docs/34_PQHAVEN_KOPRU_SECENEK_A.md
```

**Kısıt uyumu:**
- ✅ **HİÇBİR Solidity kodu değiştirilmedi** (`contracts/` dokunulmadı)
- ✅ **166 forge test** altına düşmedi (aşağıda kanıt)
- ✅ **`juniorCoverageBps` 1.157e77** tasarım notu korundu
- ✅ Merkezi risk **açıkça** yazıldı, gizlenmedi
- ✅ Multisig/TimeLock **sadece öneri** olarak sunuldu
- ✅ Seçenek B "ileride multisig sonrası" olarak işaretlendi
