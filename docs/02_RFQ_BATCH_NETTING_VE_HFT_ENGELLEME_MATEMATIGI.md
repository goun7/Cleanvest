# CLEANVEST: RFQ BATCH NETTING VE HFT ENGELLEME MATEMATİĞİ (v1.0)

> **Kapsam:** Budish et al. Sık Toplu Açık Artırma (Frequent Batch Auctions) Teorisi, Sürekli Zaman Yarışının Ortadan Kaldırılması ve Sıfır Sermayeli Netting Matematiği

---

## 1. Yüksek Frekanslı Ticaretin (HFT) Anatomisi ve Piyasa Hatası

Chicago Üniversitesi'nden Eric Budish, Peter Cramton ve John Shim'in ünlü *Quarterly Journal of Economics (QJE)* makalesinde kanıtlandığı üzere:
* Geleneksel borsalar **sürekli zamanlı limit emir defteri (Continuous-Time Limit Order Book)** ile çalışır.
* Bu modelde milisaniyeler (hatta nanosaniyeler) düzeyinde hızlı olan HFT algoritmaları, dış borsalardaki fiyat değişimlerini perakendeden $10 \text{ ms}$ önce görerek perakendenin bekleyen limit emirlerini saniyeler içinde avlar (Sniping / Toxic Order Flow).
* Bu durum piyasada yapay bir "silahlanma yarışı" yaratır ve sıradan yatırımcının aleyhine kalıcı bir gizli vergi (spread) oluşturur.

---

## 2. Budish Modeli: Sık Toplu Açık Artırma (Frequent Batch Auctions - FBA)

Cleanvest, sürekli zaman yerine **Ayrık Zamanlı Toplu Takas (Discrete-Time Batch Auction)** mimarisini uygular:

### 2.1. Zaman Ayrıklaştırması ($T_{\text{batch}}$)
Piyasa sürekli bir zaman çizgisi yerine $t \in \{t_1, t_2, \dots\}$ şeklinde küçük zaman pencerelerine bölünür ($T_{\text{batch}} = 500 \text{ ms}$):
* $500 \text{ ms}$ içinde gelen tüm emirler sisteme kabul edilir ancak anında işlenmez.
* Bu pencere içinde gelen hiçbir emrin "daha önce gelmiş olması" ona öncelik sağlamaz; zaman avantajı sıfırlanır ($dt \to 0$ yarışması biter).

### 2.2. Talep Çakışması ve İç Netleştirme (CoW Netting)
$T_{\text{batch}}$ süresince toplanan alış ($D$) ve satış ($S$) emirleri toplanır:
$$D_{\text{total}} = \sum_{i=1}^n q_i^{\text{buy}}, \quad S_{\text{total}} = \sum_{j=1}^m q_j^{\text{sell}}$$
* **Durum 1 (Tam Kesişim):** $D_{\text{total}} = S_{\text{total}}$ ise, tüm emirler dış piyasa bağımsız olarak tam orta fiyattan ($P_{\text{clearing}} = \frac{P_{\text{bid}} + P_{\text{ask}}}{2}$) P2P eşlenir. **Sıfır kayma, sıfır borsa likiditesi!**
* **Durum 2 (Artık Hacim - Imbalance):**
  $$\Delta Q = |D_{\text{total}} - S_{\text{total}}|$$
  Artık hacim oluştuğunda sistem bu miktarı onaylı kurumsal RFQ toptancılarına açık artırmaya çıkarır.

---

## 3. Kurumsal RFQ Toptancı Açık Artırması (Solver Auction)

Borsa artık hacim ($\Delta Q$) için kendi sermayesini riske atmaz:
1. Sistem, Cleanvest onaylı kurumsal toptancılara kapalı bir kriptografik RFQ sinyali iletir:
   $$\text{RFQ} = \{\text{Asset}: \text{ETH}, \text{Direction}: \text{BUY}, \text{Size}: \Delta Q, \text{MaxSlip}: 0.05\%\}$$
2. Bağımsız çözücüler ($S_1, S_2, \dots, S_k$) kendi sermayeleriyle teklif verir:
   $$\text{Quote}_k = (P_k, \text{Fee}_k)$$
3. Sistem en iyi fiyatı ($P_{\text{best}}$) seçer ve atomik olarak emri kapatır:
   $$\text{Eğer } P_{\text{best}} > P_{\text{Oracle}} \cdot (1 + \epsilon) \implies \text{İşlem Reddedilir (Anti-Collusion Bound)}$$

Bu model sayesinde kurucu **$0 sermaye ile milyar dolarlık derinlik** sunar; kullanıcı ise HFT botlarına tek bir kuruş kaptırmadan en iyi kurumsal toptan fiyattan işlem yapar.
