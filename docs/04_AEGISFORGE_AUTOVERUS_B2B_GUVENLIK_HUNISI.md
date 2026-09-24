# CLEANVEST: TEMPORIT (AEGISFORGE) VE AUTOVERUS İLE B2B GÜVENLİK HUNİSİ (v2.0)

> **Kapsam:** 4 Kademeli Otonom Güvenlik Süzgeci, Kriptografik Hash Taahhüdü (Commitment Scheme), Açık CleanScore API ve Faz 1 B2B Gelir Modeli  
> **Sürüm:** 🛡️ **v2.0 — Dürüst Çekirdek (Peer-Review Onaylı)**  
> **Geliştirme Motorları:** `07_Temporit` (Rust Eşzamanlılık Fuzzer'ı) ve `13_AutoVerus` (Z3 SMT Formel Doğrulama Motoru)

---

## 1. Neden Açık Bedava Söylenmez? (Ticari Taahhüt Modeli)

Geleneksel güvenlik araştırmacılarının düştüğü en büyük hata; buldukları açığı satır numarası ve istismar adımlarıyla birlikte doğrudan projeye e-posta ile atmaktır. Proje ekibi hatayı görür, 2 dakikada düzeltir, teşekkür bile etmeden kapıyı kapatır.

Cleanvest Gatekeeper motoru, bu süreci **Kriptografik Hash Taahhüdü (Cryptographic Commitment Scheme)** ile ticarileştirir:
* **Dürüst Kriptografi:** Bu bir ZK-SNARK değil; deterministik ve matematiksel bir **Hash Taahhüdüdür**:
  $$\text{Commitment} = \text{SHA256}(\text{ExploitPayload} \parallel \text{BytecodeHash} \parallel \text{Salt} \parallel \text{Timestamp})$$
* **Sıfır İpucu:** Karşı tarafa açığın satır numarası veya exploit kodu verilmez; yalnızca açığın var olduğu, bağımsız bir mainnet-fork simülasyonunda fon çalındığı ve bu kanıtın hash'inin üretildiği bildirilir.

---

## 2. Dört Kademeli Otonom Güvenlik Süzgeci

Cleanvest listelemesine başvuran veya harici denetim isteyen her akıllı sözleşme 4 katmanlı derin analizden geçer:

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                          CLEANVEST 4 KADEMELİ GÜVENLİK VE LİSTELEME SÜZGECİ                 │
│                                                                                             │
│  [Hedef Akıllı Sözleşme / Bytecode]                                                         │
│                     │                                                                       │
│                     ▼                                                                       │
│  ┌───────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 1. STATİK VE ARKA KAPI ANALİZİ (AST + DESERIALIZATION SCANNER)                        │  │
│  │ - Gizli `blacklist()`, `pause()`, fahiş transfer vergisi (`feeOnTransfer > 5%`).      │  │
│  │ - Yükseltilebilir proxy yetkileri ve gizli `selfdestruct` / `delegatecall` riskleri.   │  │
│  └───────────────────────────────────┬───────────────────────────────────────────────────┘  │
│                                      │                                                      │
│                                      ▼                                                      │
│  ┌───────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 2. METAMORFİK EŞZAMANLILIK VE YARIŞ DURUMU (TEMPORIT / AEGISFORGE FUZZER)             │  │
│  │ - 50.000+ eşzamanlı işlem mutasyonu ve blok-içi yarış senaryoları.                     │  │
│  │ - Reentrancy, Read-Only Reentrancy ve Flash Loan manipülasyon testleri.               │  │
│  │ - Deterministik Foundry/Anvil yeniden oynatma (replay) testi üretimi.                 │  │
│  └───────────────────────────────────┬───────────────────────────────────────────────────┘  │
│                                      │                                                      │
│                                      ▼                                                      │
│  ┌───────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 3. FORMEL DEĞİŞMEZ KONTROLÜ (AUTOVERUS Z3 SMT ENGINE)                                 │  │
│  │ - Temel finansal korunum invariantları: $\sum \text{Balances} \le \text{TotalSupply}$.│  │
│  │ - Yetkisiz mint veya bakiye drenajı matematiksel olarak mümkün mü (UNSAT kanıtı)?     │  │
│  └───────────────────────────────────┬───────────────────────────────────────────────────┘  │
│                                      │                                                      │
│                                      ▼                                                      │
│  ┌───────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 4. LİKİDİTE VE TOKENOMICS DENETİMİ                                                    │  │
│  │ - İlk 10 balina cüzdanının payı (%30'un altında olmalıdır).                           │  │
│  │ - Likidite havuzu Uncx / TeamFinance üzerinde en az 1 yıl kilitli mi?                 │  │
│  │ - Vesting takvimi ani kilit açılışları içeriyor mu?                                   │  │
│  └───────────────────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Ayrıştırılmış (Decoupled) B2B Hizmet Paketleri

Önceki tasarımdaki "öde ya da listelenme" şeklindeki şantaj algısı tamamen kaldırılmıştır. **CleanScore açık ve ücretsiz bir kamu hizmeti API'sidir**; denetim ve düzeltme ise profesyonel B2B yazılım paketleridir:

| Paket | Kapsam | Çıktı ve Değer | Fiyat | Hedef Kitle |
|---|---|---|---|---|
| **Tier 1: Otomatik Teşhis** | Hızlı statik analiz + CleanScore derecelendirmesi (0-100) | SARIF formatında rapor, temel bulgular özeti | **$299** | Yeni başlayan DeFi / token ekipleri |
| **Tier 2: Derin Fuzzing & Yama** | Temporit 50k işlem metamorfik fuzzing testi | Deterministik Foundry PoC kodu + düzeltme yaması | **$1.490** | Mainnet öncesi protokoller |
| **Tier 3: Tam Formel Güvence & Listeleme** | AutoVerus Z3 SMT analizi + Temporit + Cleanvest VIP Öncelik | TUV standardında matematiksel güvence raporu + Cleanvest hızlı onay | **$4.900** | Kurumsal RWA / DeFi projeleri |

---

## 4. Gerçekçi Finansal Projeksiyon (Faz 1 Bootstrapping)

* **Önceki Abartılı Projeksiyon:** "$300.000/ay" (Kanıtsız ve gerçek dışı bulunarak reddedildi).
* **Faz 1 Gerçekçi Hedef (1–3. Ay):**
  - Ayda 10 adet Tier 1 raporu ($2.990)
  - Ayda 3 adet Tier 2 derin analiz ($4.470)
  - Ayda 1 adet Tier 3 tam inceleme ($4.900)
  - **Aylık Toplam Net Nakit Akışı:** **$12.360 / ay**
* **Kullanım Alanı:** Bu nakit, CleanFX'in Faz 2'deki $scUSD kasası için ihtiyaç duyduğu **%3'lük Junior İlk Zarar Sermayesini ($30.000)** doğrudan fonlamak için şirket kasasında biriktirilir. Dışarıdan sermaye arayışı sıfırlanır.

---

## 5. Sorumluluk Sınırı ve False-Negative Bildirimi (Legal Disclaimer)

Otomatik statik ve dinamik analiz araçları doğası gereği son derece karmaşık, çapraz protokol ekonomik manipülasyonlarını (örn. governance flash loan saldırıları) tamamen tespit edemeyebilir.
1. CleanScore bir garanti belgesi değil; **matematiksel ve ampirik bir risk ölçümüdür.**
2. Temiz not alan bir projede daha sonra öngörülemeyen bir zafiyet çıkması durumunda Cleanvest ve Temporit'in yasal sorumluluğu **alınan denetim ücreti ile sınırlıdır (Liability Cap).**
3. 30 gün içinde yeni bir açık keşfedilirse, Tier 2 ve Tier 3 müşterilerine ücretsiz düzeltme yaması desteği (SLA) sağlanır.

