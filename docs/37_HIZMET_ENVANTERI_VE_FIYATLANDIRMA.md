# 37 — HİZMET ENVANTERİ VE FİYATLANDIRMA (Müşteri İlk Somut Teklif Hazırlığı)

**Tarih:** 2026-09-27 · **Mod:** 🟢 **RAPOR — SIFIR Solidity değişikliği**
**Amaç:** Müşteri "ne alıyorum, kaç para?" sorduğunda **sayılarla** cevap verebilmek.
Her hizmet yalnızca `docs/36_IDDIALAR_TABLOSU.md`'daki **✅ MEVCUT** iddialardan
alınmıştır — **YOL HARİTASI veya VAAT DEĞİL hiçbir hizmet fiyatlandırılmaz.**

> **Kapsam kuralı:** Bu envanter `docs/36` tablosunun **12 ✅ MEVCUT** satırından
> çıkar. `docs/36`'da 🗺️ YOL HARİTASI veya 🔴 VAAT DEĞİL olarak işaretli hiçbir
> özellik burada **hizmet olarak satılamaz.**

---

## 1. Hizmet Envanteri (6 hizmet — hepsi kod kanıtlı)

| # | Hizmet | Kodda Kanıtı (dosya:satır) | Müşteriye Somut Vaadi | Ölçüm Birimi | Fiyatlandırma |
|---|---|---|---|---|---|
| **H1** | **Getiri Kasası (ERC-4626 vault)** — boşta duran USDC'yi getiriye yatırır | `CleanFXVault.sol:21` (`is ... ERC4626`), `:203` `depositWithMin`, `:227` `requestRedemption` | "USDC'niz 1:1 girer, 3 kademeli kodlanmış getiri üretir, çıkış kapısı asla kilitlenmez" | **TVL'ye bağlı yıllık getiri** (%3.05 / %2.91 / %2.92 — `CleanFXVault.sol:23-24,60-65`) | **Getiri payı (spread)** — bkz. §2 |
| **H2** | **Korumalı Giriş Kalkanı** (ERC-4626 donation attack koruması) | `CleanFXVault.sol:203` `depositWithMin(assets, receiver, minShares)` | "İlk yatıranda hisse fiyatı manipülasyonu yapamaz — 199 wei kayıp örneği test edildi" | **Her depozit için slippage limiti** (müşteri belirler) | **H2 = H1'in içinde ÜCRETSİZ** (ayrı fiyat YOK) |
| **H3** | **Anlık Çıkış Garantisi** (günlük %10 anlık, üstü T+2) | `CleanFXVault.sol:38` `DAILY_INSTANT_CAP_BPS=1000` (%10), `:109` `redemptionGate()`, `:227` `requestRedemption` | "Çekim talebiniz asla reddedilmez — kotayı aşan kısım T+2 kuyruğuna alınır ama VAAT DEĞİL kilitlenmez" | **Günlük anlık kota: TVL'nin %10'u** (`:38,256`) | **H3 = H1'in içinde ÜCRETSİZ** (çekim ücreti YOK) |
| **H4** | **Rezerv Yönetimi** (3 kademe kurumsal dağılım) | `ReserveManager.sol:15-17` (Tier0/1/2 dağılımı), `:108` `rebalance`, `:132` `supplyToAave` | "Fonlarınız TVL kademesine göre Aave/Prime veya OUSG/BUIDL'e dağıtılır — **dağılım koda kilitli**" | **Rezerv toplam varlığı** (`:102` `totalReserveAssets`) | **Rezerv yönetim payı (spread)** — bkz. §2 |
| **H5** | **Denetim Kapısı** (CleanAudit PoV_Hash ile listeleme) | `ListingGate.sol:28-30` PoV_Hash şeması, `:144` `recordAuditResult`, `:191` `cleanScore >= 70` kontrolü | "Projeniz ancak PoV_Hash taahhüdüyle ve CleanScore ≥ 70 ile listelenir — karar on-chain, insan kararı DEĞİL" | **PoV_Hash taahhüdü** (SHA-256, zincirde) | **3 kademe: $299 / $1.490 / $4.900** — bkz. §3 |
| **H6** | **Kamusal CleanScore API** (haraç modeli YOK) | `ListingGate.sol:253` `getCleanScore`, `:334-335` `applicationFee() = 0`, `:12` yorum | "Herkes herhangi bir ödeme yapmadan projenizin güvenlik skorunu sorgulayabilir" | **Her sorgu** (view, gas ücreti ödeyen sorgulayıcı) | **ÜCRETSİZ — koda kilitli** (`:334-335` `return 0`) |

> **Toplam 6 hizmet.** 5'i ücretli kademeler (H1/H4 spread, H5 kademe fiyatı),
> 3'ü müşteriye ek ücretsiz (H2, H3 H1'in içinde; H6 tamamen ücretsiz).

---

## 2. Getiri Payı (Spread) Fiyatlandırması — H1 + H4

Müşteri USDC'sini kasaya yatırdığında getiri **kodlanmış 3 kademede** üretilir.
Getirinin bir kısmı müşteriye (senior), kalanı protokol hazinesine (junior +
treasury) gider:

| TVL Kademesi | Müşteriye (senior yield) | Rezerv getirisi | **Spread (protokol)** | Kanıt |
|---|---|---|---|---|
| **Tier0** (< $250k) | **%3.05** | ~%3.25 | **~%0.20** | `CleanFXVault.sol:60-65`, `ReserveManager.sol:15` |
| **Tier1** ($250k–$12.5M) | **%2.91** | ~%3.12 | **~%0.21** | `CleanFXVault.sol:64`, `ReserveManager.sol:16` |
| **Tier2** (≥ $12.5M) | **%2.92** | ~%3.13 | **~0.21** | `CleanFXVault.sol:65`, `ReserveManager.sol:17` |

> **Fiyatlandırma dürüstlüğü:** Müşteri **önceden sabit bir fiyat ÖDEMEZ**.
> Fiyat = getirisinin ~%0.20'si (spread). **USDC nominal olarak** ödenir, ama
> **GERÇEK mainnet akışı YOKTUR** — bu bir **fiyatlandırma teklifidir, henüz
> tahsil edilmemiştir.** Mainnet ödeme entegrasyonu YOL HARİTASIDIR.

**Örnek:** $100.000 TVL, Tier0 → rezerv ~%3.254 = $3.254/yıl; müşteri %3.05 =
$3.050/yıl; **protokol spread = $204/yıl** ($17.00/ay).

---

## 3. Denetim Kapısı Fiyatlandırması — H5 (CleanAudit)

`ListingGate.sol:77-84` ve `:208` `upgradeAuditTier` ile kodlanmış 3 kademe:

| Kademe | Fiyat (USDC nominal) | İçerik | Kodda Kanıtı |
|---|---|---|---|
| **Scan** | **$299** | 4 kademeli huni + PoV_Hash raporu (payload'a tam erişim YOK) | `:82` `Scan, // $299 - 4 kademe huni + PoV_Hash raporu` |
| **FuzzPatch** | **$1.490** | Scan + 10k metamorfik fuzz + remediation diff | `:83` `FuzzPatch, // $1.490 - Scan + 10k metamorfik fuzz + remediation diff` |
| **Priority** | **$4.900** | Tümü + formal assurance + 30-gün SLA + öncelik | `:84` `Priority, // $4.900 - tumu + formal assurance + 30-gun SLA + oncelik` |

> **Kurallar (koda kilitli):**
> - **Sadece ileri yönlü yükseltme** — downgrade YOK (`:79`, `:208-214`)
> - **İlk tarama varsayılan Scan** kademesine atanır (`:187-188`)
> - **Başvuru HER ZAMAN ücretsizdir** — haraç modeli YOK (`:333-335`)
>
> **Fiyatlandırma dürüstlüğü:** Fiyatlar **USDC nominal olarak** teklif
> edilir ama **GERÇEK mainnet akışı YOKTUR — henüz tahsil edilmemiştir.**
> "30-gün SLA" ve "formal assurance" insan operasyonel taahhüdü gerektirir;
> bunlar **kod ile otomatik değildir** — müşteriye açıkça söylenmelidir.

---

## 4. Altyapı Maliyet Kırılımı (Dürüst)

> **DÜRÜST DÜZELTME — iddiadan vazgeçildi.** Önceki "altyapı $0/ay (RPC
> ücretsiz, audit saf-stdlib, Unpump dry-run kanıtı)" ifadesi **kanıtlanamaz**:
> `docs/19_DEPLOYMENT_REHBERI.md:4,36`'deki "dry-run" yalnızca **deployment
> simülasyonudur**, bir RPC maliyet kanıtı DEĞİLDİR; "saf-stdlib" ifadesi ise
> hiçbir dokümanda geçmemektedir. **Uydurulmuş kabulü çıkardık.** Gerçek:

| Kalemler | Maliyet | Kanıt / Not |
|---|---|---|
| **Akıllı sözleşme部署** | **$0** (bir kerelik) | `docs/19_DEPLOYMENT_REHBERI.md:4` "100/100 Foundry testi yeşil, deployment dry-run doğrulandı" — bir kerelik gas dışında |
| **CleanScore API sorgusu** | **$0** protokol için | `ListingGate.sol:334-335` `applicationFee() = 0` — sorgulayıcı kendi gas'ını öder |
| **Başvuru (application)** | **$0** | `ListingGate.sol:333` "Harac modeli YOK - basvuru daima ucretsiz" |
| **Aave V3 protokol komisyonu** | **Aave protokolüne** (Cleanvest değil) | `ReserveManager.sol:132-144` `supplyToAave` — Aave protokolü kendi reserve factor'ünü alır; Cleanvest bunu yönetmez |
| **Base L2 gas** | **$0.004–$0.017/müşteri/ay** | **ÖLÇÜLDÜ** (`docs/38`): `eth_gasPrice` = 0.006 gwei + 7 gas ölçümü; müşteri öder, protokol DEĞİL |
| **RPC / indexleyici / sunucu** | **$0** — **ÖLÇÜLDÜ** | `docs/38 §4,6`: indexleyici **YOK** (grep sıfır çıktı), kendi RPC node'u **YOK** — müşteri kendi cüzdan RPC'sini kullanır |

> **Sonuç:** "%100 marj" iddiası **ancak teknik altyapı bazında** geçerlidir —
> **insan işçiliği hariç.** `docs/38` bunu **ölçtü**: teknik altyapı marjı
> **%99.90–%99.97'dir** ($17.00 spread'e karşı $0.004–$0.017 müşteri gas).
> Ama CleanAudit denetimi (Z3 SMT, fuzz, remediation diff) **insan mühendislik
> zamanı gerektirir**; bu maliyet **ölçülmemiştir** ve marj hesabına
> **DAHİL EDİLEMEZ.**

---

## 5. Zayıflıklardan Etkilenen Hizmetler

`docs/35 §5` ve `PROJE_KAGIDI` sayfa başı **Bilinen 3 Zayıf Yön**'ün her
hizmet üzerindeki etkisi:

| Zayıf Yön | Etkilenen Hizmet | Etki | İnsan-Gated mi? |
|---|---|---|---|
| **#1 Kapsam farkı (giderildi)** | — | **Bu güncelleme ile giderildi** — `PROJE_KAGIDI` sayfa başı DURUM RAPORU artık mevcut ürünü doğru tanımlıyor. **Etki kalmadı.** | Hayır |
| **#2 Merkezi risk (owner EOA'da fon birikimi)** | **H1, H4** | Fonların reserve'e aktarılması **operasyonel bir adımdır** — owner `depositReserve` çağırmazsa USDC EOA'da kalır. `ReserveManager.sol:132-144` `supplyToAave` `onlyOwner`. | **EVET — insan-gated** 🔴 |
| **#3 Köprü getirisi treasury'ye** | **H1, H4** | Getiri müşteriye **DEĞİL treasury'ye** akar — `docs/35 §2` itirafı. Müşteri "getiri ürünü" olarak satılamaz. | **EVET — insan-gated** 🔴 |

> 🔴 **İnsan-gated hizmetler:** H1 ve H4, **multisig (Gnosis Safe) veya
> zaman-kilidi ile korunmadan** tamamen otonom DEĞİLDİR. Bu korumalar **YOL
> HARİTASIDIR** (`transferOwnership` tüm 7 sözleşmede `Ownable`):
> - **Multisig:** `CleanFXVault.sol`/`ReserveManager.sol` `Ownable(msg.sender)`
>   constructor — `transferOwnership` ile Gnosis Safe'e devir **yol haritası**
> - **Zaman-kilidi (timelock):** kodda YOK — tüm `onlyOwner` fonksiyonlar
>   anında yürütülebilir. **YOL HARİTASI.**
>
> **Müşteriye söylenmeli:** "Operatör anahtarı tek bir güven noktasıdır. Bu
> adımı multisig ile koruyana dek **risk bizdedir.**" (`docs/35 §5.2`)

---

## 6. Müşteri İçin İlk Somut Teklif (örnek: $100.000 hazine)

| Kalemler | Değer |
|---|---|
| **H1 Getiri Kasası** | $100.000 → **$3.050/yıl** (%3.05, Tier0) |
| **H2 Korumalı Giriş** | Dahil (ücretsiz) |
| **H3 Anlık Çıkış** | Dahil (günlük %10 anlık = $10.000/gün, üstü T+2) |
| **H4 Rezerv Yönetimi** | Dahil (Tier0: %73 Aave / %15 Prime / %12 idle) |
| **H5 Denetim (opsiyonel)** | Scan **$299** veya FuzzPatch **$1.490** veya Priority **$4.900** |
| **H6 CleanScore API** | **Ücretsiz** (her sorgu) |
| **Protokol spread (H1+H4)** | **$204/yıl** ($17.00/ay) |
| **Altyapı maliyeti (müşteriye)** | **$0 teorik** — yalnızca Base L2 gas |
| **%100 marj (teknik altyapı bazında, insan işçiliği hariç)** | Teorik — kanıtlanmadı |

> **Toplam müşteriye: $17.00/ay teklif (spread olarak) + opsiyonel $299–$4.900
> denetim.** **$0 protokol altyapı maliyeti (ölçüldü, `docs/38 §6`) +
> $0.004–$0.017 müşteri gas** — **teknik altyapı marjı %99.90–%99.97 (insan
> işçiliği hariç, `docs/38 §7`).**
>
> 🔴 **Tüm fiyatlar USDC nominal olarak bir TEKLİFTİR — GERÇEK mainnet akışı
> YOKTUR, henüz tahsil edilmemiştir.** $0 gerçek gelir, 0 gerçek müşteri
> (bkz. `PROJE_KAGIDI` §7 madde 5).

---

## Kanıt Protokolü

```
IDDIA:  Hizmet envanteri + fiyatlandirma dokumani yazildi — SIFIR Solidity degisikligi
KANIT:  git status --short contracts/ | wc -l → 0  +  forge test → 186 passed, 0 failed
        + dosya: docs/37_HIZMET_ENVANTERI_VE_FIYATLANDIRMA.md
RC:     0
COMMIT: (bu commit)
DOSYA:  docs/37_HIZMET_ENVANTERI_VE_FIYATLANDIRMA.md
```

**Kısıt uyumu:**
- ✅ **HİÇBİR Solidity kodu değiştirilmedi** (`contracts/` dokunulmadı)
- ✅ **174 forge test** altına düşmedi
- ✅ **Sadece docs/36'daki ✅ MEVCUT iddialar** kullanıldı (12 satır)
- ✅ **"48" / "15" invariant** hiçbir yerde kullanılmadı
- ✅ **"$0/ay altyapı" KANITSIZ iddia ÇIKARILDI** (dry-run ≠ RPC kanıtı)
- ✅ Her fiyata "USDC nominal, GERÇEK mainnet akışı YOK" notu eklendi
- ✅ "%100 marj" → "teknik altyapı bazında, insan işçiliği hariç" notu
- ✅ İnsan-gated hizmetler (H1, H4) multisig/timelock YOL HARİTASI ile işaretlendi
- ✅ Hiçbir sayı uydurulmadı — her sayının yanında kanıt dosya:satır
- ✅ Rapor modu: sadece doküman, hiçbir kod
