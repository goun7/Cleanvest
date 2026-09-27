// Cleanvest UI dil paketi (TR + EN). Globallesme icin minimum i18n.
// HITL minimum: dil tercihi localStorage'da saklanir.

export type Lang = "tr" | "en";

type Dict = Record<string, string>;

const tr: Dict = {
  subtitle: "Sifir manipulasyonlu spot borsa ve getiri kasasi",
  live: "Canli",
  connected: "Bagli",
  liveNoData: "Veri bekleniyor",
  connectWallet: "Cuzdan Bagla",
  wrongNetwork: "Base agina bagli degilsin (su an: chainId {id}). Lutfen Base'e gec.",
  noWallet: "Cuzdan bulunamadi (MetaMask yuklu degil).",
  statTvl: "Kasa TVL",
  statTier: "Aktif Kademe",
  statPrice: "Pay Fiyati",
  statJunior: "Junior Ortusu",
  juniorSafe: "GUVENLI (>= %3)",
  juniorRisk: "mint-halt riski",
  shareSub: "1 scUSD karsiligi",
  yieldPanel: "Dürüst Getiri Egrisi",
  yieldVerified: "2026-09-24 dogrulanmis veriler",
  tier0: "Tier 0 — Baslangic",
  tier1: "Tier 1 — Kurumsal",
  tier2: "Tier 2 — Likidite",
  yieldNote:
    "Getiri Rezerv katmanindan dagitilir (OUSG %3.46 / BUIDL %3.45 / Aave Base). Rebase YOK — $cUSD sabit $1.00. T+2 cikis garantisi: gunluk arzin %10'u anlik, ustu 2 gun sonra serbest.",
  gatePanel: "Cikis Kapisi",
  dailyCap: "Gunluk anlik kota",
  remainingInstant: "Kalan anlik",
  queued: "Kuyrukta: {date} serbest",
  gateNote: "CIKISLAR ASLA KILITLENMEZ — kotayi asanlar T+2 kuyruguna alinir.",
  tabDeposit: "Yatir (cUSD → scUSD)",
  tabRedeem: "Cik (scUSD → cUSD)",
  amount: "Miktar (cUSD)",
  balance: "Bakiye",
  useMax: "Maksimum kullan",
  depositBtn: "Yatir (slippage korumali)",
  redeemBtn: "Cik (slippage korumali)",
  processing: "Isleniyor…",
  depositOk: "Depozito basarili",
  redeemOk: "Cikis basarili (anlik)",
  queuedInfo: "Gunluk kotayi astin - T+2 kuyruguna alindi (cikis KILITLENMEZ)",
  fail: "Islem basarisiz",
  dataFail: "Veri okunamadi",
  shieldNote: "ERC-4626 inflation-attack kalkani: UI minShares degerini otomatik hesaplar",
  riskPanel: "Risk Seffafligi",
  riskVerified: "Bundi 2026 (ESORICS) ile dogrulandi",
  riskJunior: "Junior tampon",
  riskJuniorOk: "Yeterli (>= %3)",
  riskJuniorLow: "YETERSIZ (< %3)",
  riskCap: "Anlik cikis kota",
  riskCapNote: "TVL'nin %10'u / gun",
  riskT2: "Kuyruk suresi",
  riskT2Note: "Kotayi asan cikislar 2 gun",
  riskAudit: "Test katmani",
  riskAuditNote: "179 Foundry + 24 UI testi, 0 failed",
  riskNote: "Akademik dayanak: N. Bundi, 'Pricing the DeFi Tail' (CBT 2026/ESORICS). Makale protokollerin standartlastirilmis risk aciklamasi yapmasini onerir. Junior tamponu operasyonel riski KARSILAMAZ - kredi/likidite kaybi icindir; operasyonel risk 179 test + %96 coverage ile azaltilmistir.",
  footer: "Sözlesmeler Base aginda",
};

const en: Dict = {
  subtitle: "Zero-manipulation spot exchange and yield vault",
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
  riskAuditNote: "179 Foundry + 24 UI tests, 0 failed",
  riskNote: "Academic basis: N. Bundi, 'Pricing the DeFi Tail' (CBT 2026/ESORICS). The paper recommends standardized risk disclosure. The junior buffer does NOT cover operational risk - it covers credit/liquidity loss; operational risk is mitigated by 179 tests + 96% coverage.",
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
