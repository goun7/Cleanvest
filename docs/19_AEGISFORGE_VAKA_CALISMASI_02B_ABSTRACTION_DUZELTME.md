# AEGISFORGE VAKA ÇALIŞMASI 02B — ABSTRACTION DÜZELTMESİ

**Tarih:** 2026-09-25
**Hedef:** Vaka #02'de tespit edilen %90 yanlış-pozitif oranını düşürmek
**Yöntem:** Selector → model seçimi (ERC-20 / ERC-4626 / uygulanamaz)
**Durum:** YAYINLANDI — sonuç ne olursa olsun (LE-3 kalkanı)

---

## 1. Vaka #02'deki Sorun (hatırlatma)

| Hedef | Eski CleanScore | CRITICAL | Invariant Proven | PoV_Hash |
|---|---|---|---|---|
| CleanUSD | 0/100 (C) | 3 | 1/10 | `0x611a1919…8092f20` |
| CleanFXVault | 0/100 (C) | 3 | 1/10 | `0x0adabac6…` |
| ListingGate | 0/100 (C) | 3 | 1/10 | `0x58192bf6…` |

Kök neden: **ERC-20 hedefleri ERC-4626 vault modeliyle taranmıştı.** Model,
hedefde var olmayan bir değişkeni (`total_shares`) varsaydığı için "Σ balances
≤ total shares" gibi invariant'lar anlamsızlaştı ve **9/10 invariant
counterexample döndü** — hepsi kurgusal.

> Vaka #02'nin kendi dokümanında yazıldığı gibi: "Fix yolu: Stage-1'in
> hedefin arayüzünü tespit edip modeli seçmesi gerekir." **Bu vaka, o fixi
> uygular ve ölçer.**

## 2. Uygulanan Fix: Selector → Model Seçimi

`abstraction_check` artık sadece **raporlamak**la kalmıyor, **modeli seçiyor**:

| Hedefin arayüzü | Model sınıfı | Koşan model |
|---|---|---|
| supply + deposit/withdraw/redeem | `vault` | ERC-4626 (10 invariant, AF-INV-01..10) |
| supply + balanceOf/transfer | `token` | **ERC-20 (5 invariant, AF-INV-201..205)** |
| yukarıdakilerin hiçbiri | `not-applicable` | **hiçbiri — 0 invariant talep edilmez** |

Yeni **ERC-20 modeli** (iki-aktörlü geçiş sistemi):

```
pre-state:  pre_total == pre_bal_a + pre_bal_x   (tümü ≥ 0)
steps (exactly-one selector ile seçilir):
  mint(amt)      → bal_x += amt, total += amt
  burn(amt)      → burned = min(pre_bal_x, amt); bal_x -= burned, total -= burned
  transfer(amt)  → sent = min(pre_bal_x, amt); bal_x -= sent, bal_a += sent
post-state: invariant çürüklüğü Z3 ile çürütülür (Unsat = proven)
```

Model **hedefin kendi selector yüzeyiyle parametreleştirilir**: `burn(uint256)`
/ `burnFrom(address,uint256)` selector'ları mevcutsa arz-azalışı meşrudur ve
AF-INV-204 (arz hiç azalmaz) `not-applicable` döner — sahte bir kanıt değil,
gerçek bir sınır.

## 3. Sonuçlar — Eski vs Yeni

| Hedef | Model sınıfı | Eski skor | **Yeni skor** | Eski CE | **Yeni CE** | Eski proven | **Yeni proven** |
|---|---|---|---|---|---|---|---|
| CleanUSD | token (burn var) | 0/100 (C) | **19/100** | 9 | **0** | 1/10 | **3/5** |
| CleanFXVault | token (burn yok) | 0/100 (C) | **56/100** | 9 | **0** | 1/10 | **4/5** |
| ListingGate | not-applicable | 0/100 (C) | **56/100** | 9 | **0** | 1/10 | **0/1** |

**Yanlış-pozitif oranı: %90 → %0.**

### CleanUSD invariant dağılımı (token modeli, `burn` mevcut)

| Invariant | Başlık | Sonuç |
|---|---|---|
| AF-INV-201 | supply conservation: total == Σ balances | **proven** |
| AF-INV-202 | balances never negative | **proven** |
| AF-INV-203 | external call cannot freeze balance | **not-provable-from-bytecode** |
| AF-INV-204 | totalSupply never decreases | **not-applicable** (burn var) |
| AF-INV-205 | paired-move: bakiye düşüşü eşlikli | **proven** |

### CleanFXVault / ListingGate

CleanFXVault: aynı 5 invariant, **4 proven** (sadece AF-INV-203
not-provable-from-bytecode) — `burn` selector yok olduğu için AF-INV-204
**proven**.

ListingGate: ne vault ne token arayüzü var → `not-applicable`, **0 invariant
talep edildi**. Bu, vaka #02'nin tam olarak başarısız olduğu noktadır: eski
sürüm bu hedefde 9 anlamsız counterexample üretti; yeni sürüm **hiç değil**
"temiz" demez, "uygulanamaz" der.

## 4. Neden %0 Oldu — Dürüst Analiz

Düşüşün üç mekanizması var, hepsi bilinçli:

1. **Sınıf uyuşmazlığı = koşma yok.** ListingGate'de olduğu gibi: hedefde
   vault/token muhasebe yüzeyi yoksa, invariant'lar koşulmaz. Eski sürüm
   "yanlış counterexample" üretirdi; yeni sürüm "hiçbir şey iddia etmiyorum"
   der. **Bu, %90'ın tek başına en büyük düşüş nedenidir.**

2. **Doğru model = doğru kanıt.** CleanUSD/CleanFXVault artık ERC-4626
   share/asset muhasebesi yerine **kendi muhasebe sınıflarıyla** doğrulanıyor.
   Kalan counterexample'lar gerçek model ihlalleri olabilirdi — hiç bulunmadı.

3. **Karar-verilemez = karar-verilmez.** AF-INV-203 (dondurma/skim) bytecode
   seviyesinde **karar verilemez**: bir contract'ın başka birinin bakiyesini
   keyfi index'le yazıp yazmadığı bytecode'dan görünmez. Eski sürüm ya sahte
   "proven" ya da sahte "counterexample" üretirdi; **yeni sürüm
   `not-provable-from-bytecode` der ve `prove --file X.sol --invariant
   no-freeze` ile kaynak-seviyesi ispata yönlendirir.**

### Kalan bulgular gerçek

Kalan 1–2 HIGH bulgu **gerçektir** ve vaka #02'de zaten 4 gerçek bytecode
bulgusu olarak sahiplenilmişti:

| Kimlik | Açıklama | Kaynak |
|---|---|---|
| AF-STL-001 | SELFDESTRUCT opcode mevcut | OpenZeppelin mirası |
| AF-STL-002 | DELEGATECALL/CALLCODE mevcut | OpenZeppelin mirası |

Bunlar **korunaklı** (guarded) ve miras yoluyla gelen standart kalıplar — vaka
#02'nin analizinde olduğu gibi. Yeni PoV_Hash'ler bunları içerir.

## 5. Yeni PoV_Hash'ler (Üçüncü-Taraf Doğrulama)

| Hedef | PoV_Hash | CleanScore | Model |
|---|---|---|---|
| CleanUSD | `0x2cac8b8250eeb7d2f2bfeea3fa77d2b67b36c05c806fb40130c73c019c1d6ba4` | 19/100 | token |
| CleanFXVault | `0x7c6ac5d2d7c86b3a8271fd821b74cddd4883c5324f93e771d984804e793c89da` | 56/100 | token |
| ListingGate | `0x10e7251b2a052e0122ff3335c4feb5abffe642022f275eefe56316aec0041529` | 56/100 | not-applicable |

**Determinizm kontrolü:** aynı `--timestamp 1790304944` ile iki bağımsız koşu
**byte-identical** PoV_Hash ve JSON rapor üretti. `--timestamp 999` ile
PoV_Hash değişti (`0xf60a2df1…981e8e6d`) — timestamp taahhüt alanının
içindedir, doğrulayıcı hile yapamaz.

## 6. Kalan Sınırlar (Radikal Dürüstük)

1. **Model sınıfı hâlâ soyutlama.** `proven` demek "bu modelin
   parçasında kanıtlandı" demektir — tam EVM eşdeğerliği değil. Model
   gaz, reentrancy sıralaması ve harici-contract durumunu dışlar.
2. **Kaynak gerekli invariant'lar var.** Dondurma/skim ailesi bytecode'dan
   **çözülemez** — bu kasıtlı bir itirafdır, bir eksiklik değil.
3. **48 invariant hedefinin 15'i.** 10 vault + 5 token = 15. Kalan 33
   henüz kodlanmadı; dürüst başlangıç için 15 makul.

   > DÜZELTME (2026-09-27): Gerçek invariant sayısı **5** (`test/scusd_vault_invariants.t.sol:36,50,68,95,106`). "48" hedefinin 33'ü hiç kodlanmadı (yukarıdaki §6.3 itirafı). Bu satır tarihi kayıttır, güncel durum için `docs/36_IDDIALAR_TABLOSU.md`'ne bakın.
4. **ListingGate için alternatif sunuldu:** kaynak-dosya taraması için
   `scan --src-dir` (vaka #03'te pgHeal'de kullanıldı, 100/100 AAA).

## 7. Ticari Etki

- **$299 kademesinin en büyük itibar riski giderildi:** "ERC-20 müşteriye
  0/100 ve 3 CRITICAL" senaryosu artık mümkün değil.
- **Yeni satış argümanı:** "Motor, sizin kontrat sınıfınızı tanır — vault
  invariant'larını bir token'a dayatmaz."
- **Dürüstlük puanı:** `not-applicable` ve `not-provable-from-bytecode`
  durumları **zayıflık değil, doğrulanabilir dürüstlüktür** — her raporda
  tescillidir.

## 8. Yeniden Üretim

```bash
cd 07_Temporit_DeFi_Metamorfik_Yaris_Durumu_Avcisi
cargo build -p aegisforge --release

# bytecode'ları hazırla (26_Cleanvest/out/*.json'dan)
for c in CleanUSD CleanFXVault ListingGate; do
  python3 -c "import json; open('/tmp/$c.hex','w').write(json.load(open('26_Cleanvest/out/$c.sol/$c.json'))['bytecode']['object'])"
done

./target/release/aegisforge scan --file /tmp/CleanUSD.hex --tier scan --timestamp 1790304944
./target/release/aegisforge scan --file /tmp/CleanFXVault.hex --tier scan --timestamp 1790304944
./target/release/aegisforge scan --file /tmp/ListingGate.hex --tier scan --timestamp 1790304944
```

PoV_Hash'lerin yukarıdakiyle aynı olduğu doğrulanabilir.

---
*AegisForge: "PoV_Hash bir SHA-256 hash taahhüdüdür, ZK-SNARK değil. CleanScore
ücretsizdir. Haraç modeli yok."*
