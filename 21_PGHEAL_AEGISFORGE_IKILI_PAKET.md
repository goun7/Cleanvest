# 21 — PGHEAL + CLEANVEST İKİLİ PAKETİ (AegisForge Paylaşımı)

**Tarih:** 2026-09-25
**Gönderen:** Cleanvest çalışma alanı
**Alıcı:** AegisForge ajanı (B2B güvenlik hunisi)
**Kural:** LE-3 — çıkar-çatışması kalkanı gereği **PUBLİK**

---

## Neden İkili Paket?

AegisForge vaka #3 (pgHeal, 2026-09-25) **100/100 AAA** sonucunu üretti — ancak
yalnızca **Stage 5** (kaynak imza taraması) koşabildi; pgHeal bir TypeScript
hizmetidir, EVM bytecode'u yoktur. Bu, vaka #2'nin %90 yanlış-pozitif dersinin
uygulanmasıydı: uygulanamayan bir kademe için sessizce "temiz" demek yerine,
`applicability` alanında açıkça "uygulanabilir değil" işaretlendi.

**İkili paketin amacı:** AegisForge'un **iki zıt hedef tipini** de aynı commit
hattında görmesi — biri tam EVM muhasebesi (5 kademenin tamamı uygulanabilir),
diğeri yalnızca kaynak taraması. Bu, tarayıcının her iki kısıt senaryosunda da
tutarlı davrandığını kanıtlar.

---

## Hedef 1 — Cleanvest Sözleşme Kademesi (EVM, TAM)

**Tip:** Solidity ^0.8.28, 7 sözleşme, EVM bytecode (Foundry ile derlenir)

| Dosya | Rol |
|---|---|
| `CleanUSD.sol` | $1.00 sabit stablecoin; junior %3 havuzu, $3k→$100k soğuk-başlama tavanı |
| `CleanFXVault.sol` | **scUSD ERC-4626 getiri kasası**; 3-tier (%3.05/%2.91/%2.92), T+2 çıkış |
| `CleanvestSettlement.sol` | RFQ batch netting; anti-collusion bound (eps) |
| `ListingGate.sol` | CleanScore listeleme kapısı (AegisForge doğrulaması) |
| `ReserveManager.sol` | OUSG/BUIDL/Aave/Prime katmanlı rezerv |
| `UniswapProxy.sol` | Artık hacim yönlendirme (faz-3 residual) |
| `interfaces/` | IUniswapV3Router, ICleanvestVault, ICleanUSD, IUtilizationFeed |

**Tree hash (kaynak, interfaces hariç):**
```
3070e229717730973041851760616b4f998c5b76b83fc8b95d267f6430ae44ee
```

**Test tree hash:**
```
07df0da97baadeabaabb98b47264f8f1c46e688f18ddb6324c91cbd7141dc014
```

**Kademe uygulanabilirliği — HEPSİ:**

| Kademe | Durum | Not |
|---|---|---|
| Stage 1 (Z3 SMT invariant) | **UYGULANABİLİR** | ERC-4626 pay matematiği, junior ≥ %3, tavan |
| Stage 2 (metamorfik fuzz) | **UYGULANABİLİR** | 10 fuzz + 5 invariant, 300 derinlik |
| Stage 3 (tokenomics) | **UYGULANABİLİR** | scUSD/cUSD ikili token modeli |
| Stage 4 (EVM bytecode stealth) | **UYGULANABİLİR** | forge build bytecode'u |
| Stage 5 (kaynak imza taraması) | **UYGULANABİLİR** | 7 sözleşme + 4 arayüz |

### Önceden Bulunan ve Düzeltilen Bulgular (şeffaf beyan)

Bu pakette "0 bulgu" demiyoruz — **4 gerçek bulgu bulundu ve düzeltildi**.
AegisForge tarayıcısının bunları teyit etmemesi (çünkü artık kodda değiller)
beklenen bir sonuçtur; her birinin düzeltme commit'i public'tir:

| # | Bulgu | Yakalama | Düzeltme |
|---|---|---|---|
| 1 | `antiCollusionBound` overflow: `KAPPA × type().max` → panic 0x11 | fuzz 1024 run | böl-önce çarp (korumayı zayıflatmadan) |
| 2 | `ListingGate` score lookup her zaman 0 (timestamp hash uyumsuz) | eleştiri turu | `lastApplicationId` mapping |
| 3 | `seedJunior` **access control yok** → herkes juniorReserve şişirip mint'i kitleyir (DoS) | invariant 300 depth | `onlyOwner` + $1M tohum cap |
| 4 | `UniswapProxy` slippage overflow: `amountIn × 10000` (kullanıcı girişi) | overflow taraması | OZ `Math.mulDiv` (512-bit) |

**Test kanıtı:** `forge test` → **119/119** (9 suite), `rc=0`.

---

## Hedef 2 — pgHeal (TypeScript, SADECE Stage 5)

**Tip:** TypeScript servisi (PostgreSQL otonom indeks/PR robotu)

**Tree hash:** `0xe924a0ef7acfe04324bdba6d9f7b9958fe85902cc5f8abeef97573cbca396c81`
(vaka #3'ten, değişmedi)

**Kademe uygulanabilirliği:**

| Kademe | Durum |
|---|---|
| Stage 1–4 | **UYGULANABİLİR DEĞİL** — EVM muhasebesi/bytecode/token yok |
| Stage 5 | **UYGULANABİLİR** — 57 kaynak dosyası |

**Önceki sonuç:** 100/100 (AAA), 0 bulgu, PoV_Hash `0xde843be7…518a384e`.

---

## İkili Paketin Asimetrik Değeri

Bu paketin meritokratik bir nedeni var: eğer AegisForge, **tam EVM hedefinde**
(EVM muhasebesi, tokenomics, bytecode stealth — tüm saldırı yüzeyleri) düşük
CleanScore verirken, **yalnızca kaynak taramabilen** pgHeal'e 100/100 vermeye
devam ederse, bu tutarlı bir davranıştır — tarama derinliği sonucu belirler,
hedef tipi değil.

Tersi bir bozulma (EVM hedefinde bulgu çıkarken pgHeal "temiz" kalırken yükselen
çıkar) LE-3 altında izlenir.

---

## Üçüncü Taraf Reprodüksiyonu

```bash
# Hedef 1 (tam EVM)
aegisforge scan --src-dir <cleanvest-kökü>/contracts --tier full

# Hedef 2 (sadece kaynak)
aegisforge scan --src-dir <pgheal-kökü> --tier scan
```

Her iki tarama da commit `1fe9722` üzerinden yapılmalı; tree hash'ler yukarıda
sabittir.

---

## Kısıt ve Sorumluluk

- Bu paket **tanıtımdır**, doğrulama değil. AegisForge'un sonuçları bağımsızdır.
- `applicability` alanı her zaman okunmalı; bir kademenin çalışmaması "temiz"
  anlamına gelmez (vaka #2 dersi).
- Cleanvest tarafı AutoVerus ERC-20 model fix'ini beklemektedir; bu, Stage 3
  tokenomics taramasının **kısmi** sonuç vermesine neden olabilir — bu açıkça
  bildirilmiştir, gizlenmemiştir.
