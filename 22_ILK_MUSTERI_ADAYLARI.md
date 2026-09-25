# 22 — İLK MÜŞTERİ ADAYLARI

**Tarih:** 2026-09-25
**Amaç:** Cleanvest'in ilk üç müşteri segmenti ve bunların sözleşme katmanındaki
kanıtlanmış değer teklifi.

---

## Üç Segment, Üç Farklı Acı

Cleanvest üç tip müşteriyi hedefler ve her birinin **sözleşmelerde kodlanmış**
farklı bir sorunu çözülür. Bu doküman adayları ve neden kasamızın onlara
uyduğunu listeler — vaat değil, dağıtılabilir değer.

### Segment 1 — 30-Kurul: Kurumsal Kurul Üyeleri ve Hazine Ekipleri

**Kim:** 30 kurumsal müşteri adayı — bankaların ödeme-hizmetleri birimleri,
elektronik-para kuruluşları, kurumsal hazine ekipleri ve B2B ödeme işlemcileri.

**Acı:** Kurumsal hazinede bekleyen nakit %0.8–1.5 verimsiz getiriyle durur.
Mevcutiyet %2–3 makasla eritilir. Kurul üyeleri "nakit yönetimini optimize et"
baskısı altındadır ama geleneksel araçlar (gece vadeli repo, T-bill) **operasyonel
yük** ve erişim eşiği getirir.

**Cleanvest'in dağıttığı değer (sözleşmelerde kanıtlanmış):**

| Özellik | Sözleşme | Kurula anlatılabilecek değer |
|---|---|---|
| 3-tier dürüst getiri | `CleanFXVault.sol` | %3.05 → %2.91 → %2.92 (2026-09-24 doğrulanmış); rebase yok |
| Anlık çıkış %10 | `CleanFXVault.sol` | Likidite%10 her gün anlık onaylanır; kalanı T+2 |
| Junior %3 izolasyon | `CleanUSD.sol` | Senior getirisi junior havuzuyla **risk izolasyonu** |
| Anti-kollüzyon bound | `CleanvestSettlement.sol` | Büyük emirler eps kaymasını açığa çıkarır (seffaf) |
| Manipülasyon yok | `ListingGate.sol` | Listeleme yalnızca AegisForge doğrulamasıyla |

**İlk yıl hedefi:** 30 kurul üyesinden 3'ünün TVL ≥ $250k (Tier1'e geçiş) ile
toplam **$60M+ yönetilebilir likidite**.

### Segment 2 — 58-Mahrem: Gizlilik-Duyarlı Müşteriler

**Kim:** 58 müşteri adayı — gizlilik-duyarlı kurumsal müşteriler: offshore yapılar,
aile ofisleri, yüksek-net-değerli bireylerin yöneticileri, mahrem veri taşıyan
ödeme kuruluşları.

**Acı:** Bu müşteriler likiditelerini getiriye yönlendirmek ister ama geleneksel
kurumsal araçlar **KYC/şeffaflık yükü** ve pozisyon ifşası getirir. Mevcut DeFi
alternatifleri ise manipülasyon riski taşır.

**Cleanvest'in dağıttığı değer:**

| Özellik | Sözleşme | Mahrem müşteriye değer |
|---|---|---|
| Sıfır manipülasyon spot borsa | tüm yığın | Fiyat manipülasyonu doğrudan engellenir; manipüle edilebilir havuzlara bağımlılık yok |
| Hesap imzası doğrulaması | `CleanvestSettlement.sol` | Emirler imza+batch proof ile kanıtlanır |
| Rebase yok | `CleanUSD.sol` | $1.00 sabit; gizli enflasyon yok |
| Çıkışlar kilitlenmez | `CleanFXVault.sol` | İnvariant olarak kodlanmış; mahrem müşteri çıkışının kilitlenmeyeceğini bilir |

**İlk yıl hedefi:** 58 mahrem adaydan 6'sı aktif scUSD pozisyonu, ortalama
$400k TVL → **$2.4M+** ek likidite.

### Segment 3 — 15-Hazna: Haznedarlar (Python Çıktısı)

**Kim:** 15 kurumsal haznedar adayı. Aşağıdaki liste **Python ile üretilmiştir**
(`22_hazna_adaylari.py`) — kurumsal hazine ortalamalarından modellenmiş boştaki
nakit ve mevcut verimsiz getiri verileriyle.

**Hesaplama:** Her haznedarın boştaki nakdi, CleanFXVault'ın **gerçek**
getiri egrisinden (Tier0 %3.05 / Tier1 %2.91 / Tier2 %2.92) geçer ve mevcut
verimsiz getirisiyle farkı yıllık kazanç olarak çıkar.

| # | Kategori | Boştaki Nakit | Mevcut % | scUSD % | Yıllık Kazanç |
|---|---|---|---|---|---|
| 1 | Elektronik Para Kuruluşu (EMU) | $4.200.000 | 0,90% | 2,91% | $84.420 |
| 2 | Ödeme Ağı İşlemcisi | $2.800.000 | 1,10% | 2,91% | $50.680 |
| 3 | Kripto Borsa Hazinesi | $15.000.000 | 1,50% | 2,92% | $213.000 |
| 4 | Fintech Cüzdan Sağlayıcı | $1.150.000 | 0,85% | 2,91% | $23.690 |
| 5 | Kurumsal Tedarik Zinciri Finansmanı | $6.700.000 | 1,05% | 2,91% | $124.620 |
| 6 | Banka Ödeme Hizmetleri (BOH) | $22.000.000 | 1,20% | 2,92% | $378.400 |
| 7 | E-Ticaret Pazaryeri Escrow | $9.400.000 | 0,95% | 2,91% | $184.240 |
| 8 | Mikrofinans Kuruluşu | $890.000 | 0,80% | 2,91% | $18.779 |
| 9 | Faktoring Şirketi | $3.600.000 | 1,00% | 2,91% | $68.760 |
| 10 | Sigorta Şirketi Likidite Havuzu | $18.500.000 | 1,15% | 2,92% | $327.450 |
| 11 | Emeklilik Fonu Nakit Bölümü | $31.000.000 | 0,90% | 2,92% | $626.200 |
| 12 | Hazine Yönetim Platformu (B2B) | $5.200.000 | 0,98% | 2,91% | $100.360 |
| 13 | Stablecoin İhraç Edeni | $47.000.000 | 1,40% | 2,92% | $714.400 |
| 14 | Borsalık İşlem Masası | $7.900.000 | 1,25% | 2,91% | $131.140 |
| 15 | Kurumsal Risk Fonu Likidite | $2.100.000 | 1,05% | 2,91% | $39.060 |
| | **TOPLAM (15 haznedar)** | **$177.440.000** | | | **$3.085.199** |

**Çıktı özeti:**

```
Toplam yönetilebilir likidite: $177.440.000
Yıllık ek getiri (verimsizlik farkı): $3.085.199
Ortalama boşta kalma verimsizliği: 1.74%
```

**Önemli not (dürüstlük):** Bu rakamlar **modelleme**dir — gerçek haznedarların
boştaki nakit seviyeleri işlem hacmine, mevzuata ve nakit-akış profilinine göre
değişir. Buradaki amaç, üç segmentin **büyüklük sıralamasını** göstermektir:
haznedar segmenti tek başına $3M/yıllık ek getiri potansiyeli taşır.

---

## Toplam İlk-Yıl Adreslenebilir Değer

| Segment | Aday | Dönüşüm (ilk yıl) | Toplam TVL potansiyeli |
|---|---|---|---|
| 30-Kurul | 30 | %10 (3 müşteri) | $60M |
| 58-Mahrem | 58 | %10 (6 müşteri) | $2,4M |
| 15-Hazna | 15 | %33 (5 müşteri) | $45M |
| **Toplam** | **103** | **14 müşteri** | **~$107M** |

**$107M TVL, Tier2 ($12,5M+) eşiğini 8x geçer** — yani pratikte tüm müşteriler
**%2.92** kademesinden yararlanır. Bu, pazarlamada "en düşük getiri %2.92"
denilebileceği anlamına gelir (dürüst taban).

---

## Sözleşme Kapasitesi ve Kısıtlar

Bu segmentlere hizmet vermek için **mevcut** sözleşme sınırları:

| Kısıt | Değer | Etki |
|---|---|---|
| Soğuk-başlama tavanı | $100k (ilk $3k seed) | İlk müşteriler Tier0'dan başlar; junior seed eklemek gerekir |
| Junior minimum | TVL × %3 | $107M TVL için **$3,2M junior havuz** gerekir (satın alma öncesi tohum) |
| Günlük anlık çıkış | %10 | $107M TVL'de günlük $10,7M anlık çıkış — yeterli |
| T+2 kuyruk | 2 gün | Büyük çıkışlar için kurumsal kabul edilebilir |

**Kritik bağımlılık:** Junior havuzunun **$3,2M**'a çıkarılması ilk müşteri
akışından ÖNCE yapılmalı; yoksa `canMint()` mint-halt'a girer (invariant testleri
ile doğrulanmış davranış).

---

## Reddedilen Müşteriler (şeffaf)

Aşağıdaki aday tipleri **kasamız için değildir** ve proaktif şekilde reddedilir:

- **Manipülatif-high-frequency scalping fonları** — anti-collusion bound emirlerini
  çoğu zaman revert eder (tasarım gereği)
- **Rebase getiri arayanlar** — "$4.8 saniyelik rebase" vaadi tamamen silindi;
  %3.05/2.91/2.92 dışında bir şey vaat edilmez
- **AnonimLayer-1 karanlık-havuz müşterileri** — ListingGate'in AegisForge
  doğrulaması gerekir; doğrulanamayan listelemeler reddedilir
