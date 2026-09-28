// Cleanvest UI dil paketi (TR + EN). Globallesme icin minimum i18n.
// HITL minimum: dil tercihi localStorage'da saklanir.

export type Lang = "tr" | "en";

type Dict = Record<string, string>;

const tr: Dict = {
  subtitle: "Manipülasyona dayanıklı spot borsa ve getiri kasası",
  modeSimple: "Sade Mod",
  modePro: "Pro Mod",
  modeSimpleTip: "Yalnızca alım satım paneli — yeni başlayanlar için",
  modeProTip: "Tüm paneller: getiri eğrisi, çıkış kapısı, risk şeffaflığı",
  live: "Canlı",
  connected: "Bağlı",
  liveNoData: "Veri bekleniyor",
  connectWallet: "Cüzdan Bağla",
  wrongNetwork: "Base ağına bağlı değilsin (şu an: chainId {id}). Lütfen Base'e geç.",
  noWallet: "Cüzdan bulunamadı (MetaMask yüklü değil).",
  statTvl: "Kasa TVL",
  statTier: "Aktif Kademe",
  statPrice: "Pay Fiyatı",
  statJunior: "Junior Teminat",
  juniorSafe: "GÜVENLİ (≥ %3)",
  juniorRisk: "mint-duraklama riski",
  shareSub: "1 scUSD karşılığı",
  yieldPanel: "Dürüst Getiri Eğrisi",
  yieldVerified: "21.09.2026 tarihinde doğrulanmış veriler",
  tier0: "Kademe 0 — Başlangıç",
  tier1: "Kademe 1 — Kurumsal",
  tier2: "Kademe 2 — Likidite",
  yieldNote:
    "Getiri rezerv katmanından dağıtılır (OUSG %3,46 / BUIDL %3,45 / Aave Base). Rebase YOK — $cUSD sabit $1,00. T+2 çıkış garantisi: günlük arzın %10'u anlık, üstü 2 gün sonra serbest.",
  gatePanel: "Çıkış Kapısı",
  dailyCap: "Günlük anlık kota",
  remainingInstant: "Kalan anlık",
  queued: "Kuyrukta: {date} tarihinde serbest",
  gateNote: "ÇIKIŞLAR ASLA KİTLENMEZ — kotayı aşanlar T+2 kuyruğuna alınır.",
  tabDeposit: "Yatır (cUSD → scUSD)",
  tabRedeem: "Çık (scUSD → cUSD)",
  amount: "Miktar (cUSD)",
  balance: "Bakiye",
  useMax: "Tümünü kullan",
  depositBtn: "Yatır (kayma korumalı)",
  redeemBtn: "Çık (kayma korumalı)",
  processing: "İşleniyor…",
  depositOk: "Yatırma başarılı",
  redeemOk: "Çıkış başarılı (anlık)",
  queuedInfo: "Günlük kotayı aştın — T+2 kuyruğuna alındın (çıkış KİTLENMEZ)",
  fail: "İşlem başarısız",
  dataFail: "Veri okunamadı",
  shieldNote: "ERC-4626 enflasyon saldırısı kalkanı: arayüz minShares değerini otomatik hesaplar",
  riskPanel: "Risk Şeffaflığı",
  riskVerified: "Bundi 2026 (ESORICS) ile doğrulandı",
  riskJunior: "Junior tampon",
  riskJuniorOk: "Yeterli (≥ %3)",
  riskJuniorLow: "YETERSİZ (< %3)",
  riskCap: "Anlık çıkış kotası",
  riskCapNote: "TVL'nin %10'u / gün",
  riskT2: "Kuyruk süresi",
  riskT2Note: "Kotayı aşan çıkışlar 2 gün",
  riskAudit: "Test katmanı",
  riskAuditCount: "187",
  riskAuditNote: "187 Foundry + 28 arayüz testi, 0 başarısız",
  riskNote: "Akademik dayanak: N. Bundi, “Pricing the DeFi Tail” (CBT 2026/ESORICS). Makale, protokollerin standartlaştırılmış risk açıklaması yapmasını önerir. Junior tamponu operasyonel riski KARŞILAMAZ — kredi/likidite kaybı içindir; operasyonel risk 187 test + %97 kapsama ile azaltılmıştır.",
  errTitle: "Bir hata oluştu",
  errBody:
    "Uygulama beklenmeyen bir hatayla karşılaştı. Fonların güvende — bu yalnızca bir arayüz hatası, sözleşmeler etkilenmez.",
  errRetry: "Tekrar dene",
  footer: "Sözleşmeler Base ağında",
};

const en: Dict = {
  subtitle: "Zero-manipulation spot exchange and yield vault",
  modeSimple: "Simple",
  modePro: "Pro",
  modeSimpleTip: "Trading panel only — for beginners",
  modeProTip: "All panels: yield curve, exit gate, risk transparency",
  live: "Live",
  connected: "Connected",
  liveNoData: "Awaiting data",
  connectWallet: "Connect Wallet",
  wrongNetwork: "Not on Base network (current: chainId {id}). Please switch to Base.",
  noWallet: "No wallet found (MetaMask not installed).",
  statTvl: "Vault TVL",
  statTier: "Active Tier",
  statPrice: "Share Price",
  statJunior: "Junior Backing",
  juniorSafe: "SAFE (>= %3)",
  juniorRisk: "mint-halt risk",
  shareSub: "per 1 scUSD",
  yieldPanel: "Honest Yield Curve",
  yieldVerified: "verified 2026-09-24 data",
  tier0: "Tier 0 — Entry",
  tier1: "Tier 1 — Institutional",
  tier2: "Tier 2 — Liquidity",
  yieldNote:
    "Yield is distributed from the Reserve layer (OUSG 3.46% / BUIDL 3.45% / Aave Base). NO rebase — $cUSD is fixed at $1.00. T+2 exit guarantee: daily supply 10% instant, above that free in 2 days.",
  gatePanel: "Exit Gate",
  dailyCap: "Daily instant cap",
  remainingInstant: "Instant remaining",
  queued: "Queued: free on {date}",
  gateNote: "EXITS ARE NEVER LOCKED — above-cap withdrawals enter the T+2 queue.",
  tabDeposit: "Deposit (cUSD → scUSD)",
  tabRedeem: "Withdraw (scUSD → cUSD)",
  amount: "Amount (cUSD)",
  balance: "Balance",
  useMax: "Use maximum",
  depositBtn: "Deposit (slippage protected)",
  redeemBtn: "Withdraw (slippage protected)",
  processing: "Processing…",
  depositOk: "Deposit successful",
  redeemOk: "Withdrawal successful (instant)",
  queuedInfo: "Exceeded daily cap — moved to T+2 queue (exit NEVER LOCKED)",
  fail: "Transaction failed",
  dataFail: "Failed to read data",
  shieldNote: "ERC-4626 inflation-attack shield: UI auto-computes minShares",
  riskPanel: "Risk Transparency",
  riskVerified: "verified with Bundi 2026 (ESORICS)",
  riskJunior: "Junior buffer",
  riskJuniorOk: "Adequate (>= 3%)",
  riskJuniorLow: "INADEQUATE (< 3%)",
  riskCap: "Instant exit cap",
  riskCapNote: "10% of TVL / day",
  riskT2: "Queue period",
  riskT2Note: "Above-cap exits free in 2 days",
  riskAudit: "Test layer",
  riskAuditCount: "187",
  riskAuditNote: "187 Foundry + 28 UI tests, 0 failed",
  riskNote: "Academic basis: N. Bundi, “Pricing the DeFi Tail” (CBT 2026/ESORICS). The paper recommends standardized risk disclosure. The junior buffer does NOT cover operational risk — it covers credit/liquidity loss; operational risk is mitigated by 187 tests + 97% coverage.",
  errTitle: "Something went wrong",
  errBody:
    "The app hit an unexpected error. Your funds are safe — this is a UI-only error, the contracts are unaffected.",
  errRetry: "Try again",
  footer: "Contracts on Base network",
};

const dicts: Record<Lang, Dict> = { tr, en };

export function getLang(): Lang {
  if (typeof localStorage !== "undefined") {
    const stored = localStorage.getItem("cleanvest-lang");
    if (stored === "tr" || stored === "en") return stored;
  }
  // Tarayici diline gore varsayilan
  if (typeof navigator !== "undefined" && navigator.language?.startsWith("en")) return "en";
  return "tr";
}

export function setLang(lang: Lang) {
  if (typeof localStorage !== "undefined") localStorage.setItem("cleanvest-lang", lang);
}

export function t(lang: Lang, key: string, params?: Record<string, string | number>): string {
  let s = dicts[lang]?.[key] ?? dicts.tr[key] ?? key;
  if (params) {
    for (const [k, v] of Object.entries(params)) {
      s = s.replace(`{${k}}`, String(v));
    }
  }
  return s;
}
