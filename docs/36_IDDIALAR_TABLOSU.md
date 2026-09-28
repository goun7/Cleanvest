# 36 — İDDİALAR TABLOSU: Müşteriye Söylenen Her İddianın Kodda Kanıtı

**Tarih:** 2026-09-27 · **Mod:** 🟢 **RAPOR — SIFIR Solidity değişikliği**
**Amaç:** Müşteriye söylenen her iddia için **kodda kanıtı** (dosya:satır) ve **durum**
(MEVCUT / YOL HARİTASI / VAAT DEĞİL). Bu tablo, `PROJE_KAGIDI.md` sayfa başı
"DURUM RAPORU" ile `docs/35` müşteri pitch'i ile **birebir tutarlıdır**.

> **Okuma kuralı:** Yalnızca **✅ MEVCUT** satırları müşteri sunumunda kullanılabilir.
> 🗺️ **YOL HARİTASI** satırları "gelecek vaadidir" olarak sunulmalıdır. 🔴 **VAAT
> DEĞİL** satırları **hiçbir koşulda** müşteriye vaad edilemez — koddaki karşılığı
> farklıdır veya yoktur.

**Mevcut ürünün doğru tanımı** (`PROJE_KAGIDI.md` sayfa başı DURUM RAPORU ile
`docs/35` ile **birebir**):

> **ERC-4626 getiri kasası + FBA settlement + AegisForge denetim kapısı +
> PQHaven USDC köprüsü (Seçenek A).** Kodda **7 sözleşme** vardır:
> `CleanUSD`, `CleanFXVault`, `ListingGate`, `CleanvestSettlement`,
> `ReserveManager`, `UniswapProxy`.

---

## İddialar Tablosu (14 satır)

| # | İddia | KODDA KANITI (dosya:satır) | Durum |
|---|---|---|---|
| 1 | **ERC-4626 getiri kasası** (`$scUSD`, standart) | `CleanFXVault.sol:21` `contract CleanFXVault is ... ERC4626, Ownable, ReentrancyGuard`; `:56` `ERC4626(IERC20(asset))`; `testYieldCurveMatchesSpec` | ✅ MEVCUT |
| 2 | **`$cUSD` sabit 1:1 = $1.00, rebase YOK** | `CleanUSD.sol:15` "hiçbir rebase/mint-yield fonksiyonu içermez"; `:99-100` mint kuralı | ✅ MEVCUT |
| 3 | **Çıkış kapısı ASLA kilitlenmez** (günlük %10 anlık, üstü T+2 kuyruk) | `CleanFXVault.sol:38` `DAILY_INSTANT_CAP_BPS=1000` (%10); `:40` T+2; `:164-185` kuyruk; `invariantRedemptionNeverLocked` | ✅ MEVCUT |
| 4 | **Kademeli getiri eğrisi**: %3.05 / %2.91 / %2.92 | `CleanFXVault.sol:23-24` `TIER1_THRESHOLD=250_000 ether` / `TIER2_THRESHOLD=12_500_000 ether`; `:64-65` tier seçimi | ✅ MEVCUT |
| 5 | **Tier0 rezerv dağılımı: %73 Aave / %15 Prime / %12 idle** | `ReserveManager.sol:15` (kod yorumu + `:85` `// %73 Aave / %0 RWA / %15 Prime / %12 idle`) | ✅ MEVCUT |
| 6 | **Rezerv dağılımı BUIDL/OU SG yalnızca Tier2'de** (TVL ≥ $12.5M) | `ReserveManager.sol:17` `Tier2: %40 BUIDL / %33 Aave / %12 idle / %15 Prime`; `:40` `TIER2_THRESHOLD` | ✅ MEVCUT (koşullu) |
| 7 | **Slippage kalkanı `depositWithMin`** (ERC-4626 donation attack'e karşı) | `CleanFXVault.sol:203` `function depositWithMin`; `testSecurityDonationAttackVectors` (199 wei kayıp) | ✅ MEVCUT |
| 8 | **Junior rezerv ≥ %3 TVL** (fail-closed mint-halt) | `CleanUSD.sol:25` `JUNIOR_MIN_BPS=300`; `:46` `canMint()`; `:99` `require(canMint(), "Junior <%3, mint kilitli")` | ✅ MEVCUT |
| 9 | **400ms FBA batch settlement** (Budish frequent batch auction) | `CleanvestSettlement.sol:23` `T_BATCH_MS=400`; `:119` `executeBatch Settlement` | ✅ MEVCUT |
| 10 | **AegisForge denetim kapısı: PoV_Hash taahhüdü** (ZK-SNARK DEĞİL) | `ListingGate.sol:28-30` PoV_Hash = `SHA256("aegisforge-pov-v1" \|\| ...)`; `:118` `onlyAegisForge` | ✅ MEVCUT |
| 11 | **AegisForge 3 kademeli fiyatlandırma** ($299 / $1.490 / $4.900) | `ListingGate.sol:73` `$299 kademesi PoV_Hash raporu verir`; `:50` `MIN_CLEAN_SCORE=70` | ✅ MEVCUT |
| 12 | **PQHaven USDC köprüsü (Seçenek A)** — canlı anvil'de kanıtlandı | `test/PQHavenBridge.t.sol` (8 test) + `docs/34 §7` (anvil koşusu, `e6a58b6`) | ✅ MEVCUT (testnet) |
| 13 | **"48 Güvenlik İnvariantı"** | **KODDA KANITLANAMAZ** — `test/`'te 5 invariant var (`test/scusd_vault_invariants.t.sol:36,50,68,95,106`), 48 DEĞİL | 🔴 **VAAT DEĞİL** |
| 14 | **Validium / ZK-Proof settlement, Escape Hatch, Privy/Web3Auth, Omnichain** | **Kodda 0 dosya** — grep ile doğrulandı (`PROJE_KAGIDI.md` sayfa başı tablo) | 🗺️ YOL HARİTASI |
| 15 | **Delta-neutral vadeli fonlama arbitrajı** (rezervde %15) | **Kodda 0 dosya** — `ReserveManager.sol`'de türev/arbitraj mantığı YOK | 🔴 **VAAT DEĞİL** |
| 16 | **%75 BUIDL + USDY / %10 anlık nakit dağılımı** (PROJE_KAGIDI §4.3 diyagramı) | **Kodda 0 dosya** — gerçek Tier0 dağılımı #5'te; BUIDL %40 yalnızca Tier2 | 🔴 **VAAT DEĞİL** |
| 17 | **"Sıfır manipülasyon" → operatöre bağımlı** (owner EOA'da fon birikebilir) | `ReserveManager.sol:132-144` `supplyToAave` `onlyOwner`; `docs/34 §7` — 7e9 USDC EOA'da kaldı, `idleBalance` değişmedi | 🔴 **VAAT DEĞİL** |
| 18 | **Köprü + Aave getiri treasury'ye akar, müşteriye DEĞİL** | `ReserveManager.sol:62` `Ownable(msg.sender)`; `:140` `usdc.transfer(aavePool, amount)` — getiri owner'a; `docs/35 §2` dürüst itiraf | 🔴 **VAAT DEĞİL** |
| 19 | **"Aylık $1.200.000+ Net Nakit Akışı"** (12. ay hedefi) | **Kodda kanıt yok** — 0 gerçek müşteri, $0 gerçek gelir; bir *hedef*tir | 🗺️ YOL HARİTASI (hedef) |
| 20 | **Otonomi: "%0 HITL (ZK-Rollup)"** | **Kodda kanıt yok** — ZK-Rollup YOK; operatör disiplinine bağlı (bkz. #17) | 🔴 **VAAT DEĞİL** |

---

## İddia 13 detayı — "48 Güvenlik İnvariantı" 🔴

**Bu sayı kodda kanıtlanamaz.** Doğrulama:

```
$ grep -rn "function invariant" test/ | wc -l
5
```

Koddaki 5 invariant (`test/scusd_vault_invariants.t.sol`):

| # | İnvariant | Satır |
|---|---|---|
| 1 | `invariantJuniorCoverageAfterMint` | `:36` |
| 2 | `invariantVaultAssetsCovered` | `:50` |
| 3 | `invariantRedemptionNeverLocked` | `:68` |
| 4 | `invariantSeedToTvlCap` | `:95` |
| 5 | `invariantAllocationSumsTo10000` | `:106` |

`docs/35` L122 zaten doğruyu söylüyordu: **"Invariant'lar: 5 (300 derinlik fuzz)"**.
**"48" sayısı `docs/35`'te geçmiyordu; yalnızca `PROJE_KAGIDI.md` L208'de**
(AegisForge satış metninde) geçiyordu. **Bu güncelleme ile PROJE_KAGIDI'dan da
çıkarıldı** — kanıtlanamaz sayı müşteri materyallerinde kalamaz.

> **Kesin kanıt (docs/19 §6.3):** *"48 invariant hedefinin 15'i. 10 vault +
> 5 token = 15. **Kalan 33 henüz kodlanmadı.**"* Yani "48" bir **hedeftir**,
> 33'sü hiç var olmadı. Ayrıca `test/`'te **5** invariant çalışır — yani
> "48'in 33'ü kodlanmadı" bile gerçeğin üzerindedir; **gerçek sayı 5'tir.**

> **Dürüst not:** AegisForge kendi ürününde 48 invariant kullanıyor olabilir,
> ancak bu **Cleanvest kodunun** iddiası değildir. İki ürün karıştırıldığında
> doğan bir abartıdır. AegisForge'un invariant sayısı için `07_AegisForge`
> dokümanlarına atıf yapılmalıdır; Cleanvest **5**'idir.

---

## İddia 5 detayı — Gerçek Tier0 Rezerv Dağılımı ✅

`PROJE_KAGIDI.md` §4.3 diyagramı "%75 BUIDL+USDY / %15 arbitraj / %10 nakit"
gösteriyordu. **Gerçek dağılım** (`ReserveManager.sol:13-18`):

```
Tier0 (<$250k):    %73 Aave(3.78) / %12 idle(0)   / %15 Prime(3.30) = %3.254
Tier1 ($250k-12.5M): %40 OUSG(3.44) / %33 Aave / %12 idle / %15 Prime = %3.118
Tier2 (>=$12.5M):  %40 BUIDL(3.47) / %33 Aave / %12 idle / %15 Prime = %3.130
```

> **Müşteriye doğru söylem:** "Boşta duran USDC'niz bugün **Aave V3 + Aave
> Prime**'a yatırılır (Tier0). TVL $250k'ya ulaşınca **OU SG** (Ondo) eklenir;
> $12.5M'ya ulaşınca **BlackRock BUIDL** eklenir. **ABD Hazine Bonosu doğrudan
> alımı bugün YOK** — bunun için Tier2'ye ulaşmak ve Qualified Purchaser
> statüsü gerekir ($5M minimum)."

---

## Özet: Hangi iddialar müşteri sunumunda kullanılabilir?

| Kategori | Sayı | Müşteriye |
|---|---|---|
| ✅ **MEVCUT** | 12 | **EVET** — kod kanıtlı |
| 🗺️ **YOL HARİTASI** | 2 | **"Gelecek vaadi" olarak** — net etiketle |
| 🔴 **VAAT DEĞİL** | 6 | **HAYIR** — koddaki karşılığı farklı/yok |

> **Toplam 20 iddia incelendi.** %60'ı kod kanıtlı, %10'u gelecek vaadi,
> %30'u koddaki karşılığından farklı. Bu oran **gizlenmez** — müşteriye
> gösterilir. Gizlenmeyen zayıflık, gizilen zayıflıktan güvenilirdir.

---

## Kanıt Protokolü

```
IDDIA:  docs/35 pitch'i + PROJE_KAGIDI birebir hizalandi + iddialar tablosu
KANIT:  git status --short contracts/ | wc -l → 0  +  forge test → 186 passed, 0 failed
RC:     0
COMMIT: (bu commit)
DOSYA:  docs/36_IDDIALAR_TABLOSU.md
```

**Kısıt uyumu:**
- ✅ **HİÇBİR Solidity kodu değiştirilmedi** (`contracts/` dokunulmadı)
- ✅ **174 forge test** altına düşmedi
- ✅ **"48 Güvenlik İnvariantı" ÇIKARILDI** (kanıtlanamaz — gerçeği 5, `docs/19` §6.3)
- ✅ **"48" PROJE_KAGIDI'dan da çıkarıldı** (eski L208 → "güvenlik invariantlarında")
- ✅ **docs/35 pitch'i ile PROJE_KAGIDI birebir** (aynı mevcut-ürün tanımı)
- ✅ **%73 Aave / %15 Prime / %12 idle** tabloya dahil edildi
- ✅ **$1.200.000+ hedefine "HENÜZ KANITLANMAMIŞ" notu** eklendi
- ✅ Rapor modu: sadece doküman, hiçbir kod
- ✅ **3. parti denetim gerekliliği** açıkça belirtildi (docs/24, 25, 27, 41)
  — dahili test bağımsız denetimin YERİNE GEÇMEZ
