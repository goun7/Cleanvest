# CLEANVEST: KULLANICI DENEYİMİ, PSİKOLOJİSİ VE UÇTAN UCA İŞLEM HİKAYESİ (v1.0)

> **Kapsam:** Kullanıcı Gözünden Platform Deneyimi, Kaldıraç Travması Yaşamış Yatırımcının Dönüşümü ve Arayüz Akışı

---

## 1. Kullanıcı Profili ve Pazar Psikolojisi

### 1.1. Hedef Kullanıcı Kimdir? ("The Burned Trader" & "The Smart Saver")
1. **Vadeli İşlem / Kaldıraç Mağduru:** Binance veya Bybit'te 20x kaldıraçla parasını kaybetmiş, gece uyurken gelen bir fitil (wick) yüzünden likide olmuş, "artık sadece spot varlık biriktirmek istiyorum ama botların beni soymasından bıktım" diyen kullanıcı.
2. **Banka Makasından Bunalmış Döviz Tutucu:** Bankaların %2.5'luk döviz makasını ödemekten ve vadesiz hesapta duran dolarına/eurosuna sıfır faiz almaktan şikayetçi olan tasarruf sahibi.
3. **Scam / Rug-Pull Yorgunu:** Yeni çıkan tokenları alıp ertesi gün kontratın kilitlenmesiyle (honeypot) tüm parasını kaybetmiş Web3 perakendecisi.

---

## 2. Uçtan Uca Kullanıcı Deneyimi (Step-by-Step UX Journey)

### Adım 1: Sürtünmesiz Giriş (Zero-Seed Phrase Onboarding)
* Kullanıcı `cleanvest.market` adresine girer.
* Ne 24 kelimelik tohum kelime (seed phrase) ne de karmaşık KYC bürokrasisi ile karşılaşır.
* **"Google veya Apple ile Devam Et"** butonuna basar.
* Arka planda **Privy / Web3Auth MPC** mimarisiyle kullanıcının cihazında şifrelenmiş, anahtarı yalnızca kendisinde olan **%100 Non-Custodial Akıllı Hesap (ERC-4337)** saniyeler içinde oluşturulur.

### Adım 2: CleanFX ile Sıfır-Makas Para Yatırma
* Kullanıcı banka hesabından yerel para birimini (TL, EUR, USD vb.) gönderir.
* Bankanın 2.5 TL makas uyguladığı yerde, CleanFX bankalararası toptan kurla (Interbank rate) **yalnızca 5 kuruş farkla** parayı **`CleanUSD` ($cUSD)** varlığına çevirir.
* Kullanıcı ekranda şunu görür:
  > *"Tebrikler! Bankalara kıyasla işlem başına $240 tasarruf ettiniz."*

### Adım 3: Otomatik Getiri (Boşta Duran Nakit Kazancı)
* Kullanıcı hiçbir kripto para almasa, günlerce ekrana bakmasa bile:
* Cüzdanındaki 10.000 $cUSD bakiyesinin arkasındaki sayaç **her saniye yeşil renkte artar**:
  > *"Mevcut Varlık: 10.000 $cUSD — Yıllık Getiri: %4.80 (ABD Hazine Bonosu Destekli) — Günlük Kazanç: $1.31"*
* Kullanıcı parasının vadesiz hesapta erimediğini, arkada dünyanın en güvenli devlet tahvili faizini kazandığını görerek platforma duygusal olarak bağlanır.

### Adım 4: Spot Alım Emri (Bot-Geçirmez Tahta Deneyimi)
* Kullanıcı listelenmiş temiz bir projeden (Örn: $ETH veya $KOK) 2.000 dolarlık alım emri girer.
* Ekranda CEX benzeri derinlik tablosu ve grafik akar; ancak emir girdiğinde:
  * Hiçbir MEV botu emri önden alıp fiyatı yukarı itemez (Mempool'a düşmez).
  * Arbitraj botları tahtayı tarayıp kayma (slippage) yaratamaz.
  * Eğer içeride aynı anda satış yapan başka bir perakendeci varsa, iki emir tam orta fiyattan **sıfır kaymayla (CoW Netting)** eşleşir.
  * Eşleşmezse onaylı kurumsal toptancı (RFQ Solver) emri en iyi fiyattan kapatır.
* Kullanıcı aldığı varlığın kendi cüzdanında kilitli olduğunu, borsanın asla bu parayla spekülasyon yapamayacağını bilir.

---

## 3. Geleneksel Borsa ile Cleanvest Deneyim Karşılaştırması

| Deneyim Unsuru | Geleneksel Borsalar (Binance / Bybit) | Cleanvest Deneyimi |
|---|---|---|
| **Kaldıraç & Tasfiye** | 100x kumar, gece gelen tek fitille %100 sermaye kaybı | **SIFIR Kaldıraç, SIFIR Tasfiye Riski (%100 Spot)** |
| **Önceden Alım (Front-running)** | HFT botları emirlerinizi milisaniyelerle önden soyar | **Halka Açık API Yok; HFT Botları Fiziksel Olarak Engelli** |
| **Boşta Duran Nakit** | Vadesiz dolara %0 faiz verir (kendi kasasına atar) | **Boşta duran her $cUSD'ye otomatik %4.80 ABD tahvil faizi** |
| **Listelenen Varlıklar** | Parayı basan meme-coin girer, ertesi gün dump yer | **AegisForge + AutoVerus 4 kademeli temizlik süzgeci** |
| **Fon Güvenliği** | Borsa batarsa paranız buharlaşır (FTX senaryosu) | **Validium ZK-Rollup: Fonlar kullanıcının kendi kasasında** |
