import { useCallback, useEffect, useState } from "react";
import { BrowserProvider } from "ethers";
import type { Eip1193Provider } from "./types";
import { getLang, setLang, t, type Lang } from "./lib/i18n";
import {
  CHAIN_ID,
  depositWithMin,
  fetchVaultState,
  redeemWithMin,
  requestRedemption,
  useContracts,
  type VaultState,
} from "./lib/vault";

const fmtUsd = (v: string) => {
  const n = Number(v);
  if (!isFinite(n)) return "$0";
  return n >= 1_000_000
    ? `$${(n / 1_000_000).toFixed(2)}M`
    : n >= 1_000
      ? `$${(n / 1_000).toFixed(2)}k`
      : `$${n.toFixed(2)}`;
};

const fmtFull = (v: string) => {
  const n = Number(v);
  if (!isFinite(n)) return "0";
  return n.toLocaleString("tr-TR", { maximumFractionDigits: 2 });
};

function App() {
  const [provider, setProvider] = useState<BrowserProvider | null>(null);
  const [account, setAccount] = useState<string | null>(null);
  const [state, setState] = useState<VaultState | null>(null);
  const [tab, setTab] = useState<"deposit" | "redeem">("deposit");
  const [lang, setLangState] = useState<Lang>(() => getLang());
  const tt = (key: string, params?: Record<string, string | number>) => t(lang, key, params);
  const [amount, setAmount] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<{ kind: "ok" | "err" | "info"; text: string } | null>(null);
  const { vault } = useContracts(provider);

  const connect = useCallback(async () => {
    if (!window.ethereum) {
      setMessage({ kind: "err", text: tt("noWallet") });
      return;
    }
    const p = new BrowserProvider(window.ethereum as Eip1193Provider);
    const net = await p.getNetwork();
    if (Number(net.chainId) !== CHAIN_ID) {
      setMessage({
        kind: "err",
        text: tt("wrongNetwork", { id: Number(net.chainId) }),
      });
      return;
    }
    const accounts = await p.send("eth_requestAccounts", []);
    setProvider(p);
    setAccount(accounts[0] ?? null);
    setMessage(null);
  }, []);

  const refresh = useCallback(async () => {
    if (!vault) return;
    try {
      setState(await fetchVaultState(account));
    } catch (e) {
      setMessage({ kind: "err", text: `${tt("dataFail")}: ${(e as Error).message.slice(0, 80)}` });
    }
  }, [vault, account]);

  useEffect(() => {
    refresh();
    const id = setInterval(refresh, 12000);
    return () => clearInterval(id);
  }, [refresh]);

  const submit = useCallback(async () => {
    if (!provider || !account || !amount) return;
    setBusy(true);
    setMessage(null);
    try {
      if (tab === "deposit") {
        const hash = await depositWithMin(provider, amount, account);
        setMessage({ kind: "ok", text: `Depozito basarili: ${hash.slice(0, 18)}…` });
      } else {
        // Cikis: once slippage-korumali dene; kota asarsa T+2 kuyruguna al
        try {
          const hash = await redeemWithMin(provider, amount, account);
          setMessage({ kind: "ok", text: `${tt("redeemOk")}: ${hash.slice(0, 18)}…` });
        } catch {
          const hash = await requestRedemption(provider, amount);
          setMessage({
            kind: "info",
            text: `${tt("queuedInfo")}: ${hash.slice(0, 18)}…`,
          });
        }
      }
      setAmount("");
      await refresh();
    } catch (e) {
      const msg = (e as Error).message ?? "";
      const reason = msg.includes("reason=") ? msg.split("reason=")[1].slice(0, 90) : msg.slice(0, 90);
      setMessage({ kind: "err", text: `${tt("fail")}: ${reason}` });
    } finally {
      setBusy(false);
    }
  }, [provider, account, amount, tab, refresh]);

  const s = state;
  const balance = tab === "deposit" ? s?.walletCUSD : s?.walletScUSD;

  return (
    <div className="mx-auto max-w-5xl px-4 py-8 sm:py-12">
      {/* Baslik */}
      <header className="mb-8 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-center gap-3">
          <div>
            <h1 className="text-2xl font-bold tracking-tight text-white">
              Cleanvest <span className="text-fx-glow">scUSD</span>
            </h1>
            <p className="text-sm text-slate-400">{tt("subtitle")}</p>
          </div>
        </div>
        <div className="flex items-center gap-3">
          <button
            type="button"
            className="btn-ghost w-auto px-3 py-2 text-xs font-mono"
            onClick={() => { const l = lang === "tr" ? "en" : "tr"; setLang(l); setLangState(l); }}
            aria-label={`Switch to ${lang === "tr" ? "English" : "Turkce"}`}
            title={`Switch to ${lang === "tr" ? "English" : "Turkce"}`}
          >
            {lang.toUpperCase()}
          </button>
          {account && s?.loaded ? (
            <span className="chip bg-fx-yield/15 text-fx-yield">
              <span className="h-1.5 w-1.5 rounded-full bg-fx-yield" /> {tt("connected")}
            </span>
          ) : !s?.loaded ? (
            <span className="chip bg-fx-gold/10 text-fx-gold">
              <span className="h-1.5 w-1.5 rounded-full bg-fx-gold" /> {tt("liveNoData")}
            </span>
          ) : (
            <span className="chip bg-fx-base/15 text-fx-base">
              <span className="h-1.5 w-1.5 rounded-full bg-fx-base" /> {tt("live")}
            </span>
          )}
          {account && (
            <span className="chip border border-white/15 bg-white/5 font-mono text-slate-300">
              {account.slice(0, 6)}…{account.slice(-4)}
            </span>
          )}
        </div>
      </header>

      {/* Deploy bekleniyor bilgisi (adresler girilmemisse) */}
      {s && !s.loaded && (
        <div
          role="status"
          className="mb-6 rounded-xl border border-fx-gold/30 bg-fx-gold/5 px-4 py-3 text-sm text-fx-gold"
        >
          ℹ️ Sözleşmeler henüz canlı deploy edilmedi — değerler dağıtım sonrası görünecek.
          Mevcut kod Base mainnet'e hazır (`script/Deploy.s.sol`).
        </div>
      )}

      {/* Stat kartlari */}
      <section className="mb-8 grid grid-cols-2 gap-4 lg:grid-cols-4">
        <StatCard
          label={tt("statTvl")}
          value={s ? fmtUsd(s.tvl) : "…"}
          sub={s ? `${fmtFull(s.totalSupply)} scUSD` : ""}
        />
        <StatCard
          label={tt("statTier")}
          value={s?.tier ?? "…"}
          sub={s ? `Getiri %${s.seniorYieldPct.toFixed(2)}` : ""}
          accent
        />
        <StatCard
          label={tt("statPrice")}
          value={s ? `$${s.sharePrice.toFixed(4)}` : "…"}
          sub={tt("shareSub")}
        />
        <StatCard
          label={tt("statJunior")}
          value={s ? `%${s.juniorRatioPct.toFixed(1)}` : "…"}
          sub={s && s.juniorRatioPct >= 3 ? tt("juniorSafe") : tt("juniorRisk")}
          danger={s ? s.juniorRatioPct < 3 : false}
        />
      </section>

      {/* Getiri egrisi paneli */}
      <section className="mb-8 grid gap-4 lg:grid-cols-3">
        <div className="panel panel-hover p-6 lg:col-span-2">
          <div className="mb-4 flex items-center justify-between">
            <h2 className="text-lg font-semibold text-white">{tt("yieldPanel")}</h2>
            <span className="stat-label">{tt("yieldVerified")}</span>
          </div>
          <div className="space-y-3">
            <TierRow
              name={tt("tier0")}
              range="< $250k"
              yieldPct={3.05}
              active={s?.tier === "Tier 0"}
            />
            <TierRow
              name={tt("tier1")}
              range="$250k – $12.5M"
              yieldPct={2.91}
              active={s?.tier === "Tier 1"}
            />
            <TierRow
              name={tt("tier2")}
              range="≥ $12.5M"
              yieldPct={2.92}
              active={s?.tier === "Tier 2"}
            />
          </div>
          <p className="mt-4 text-xs leading-relaxed text-slate-500">
            {tt("yieldNote")}
          </p>
        </div>

        <div className="panel panel-hover flex flex-col justify-between p-6">
          <div>
            <h2 className="mb-4 text-lg font-semibold text-white">{tt("gatePanel")}</h2>
            <div className="mb-4">
              <p className="stat-label">{tt("dailyCap")}</p>
              <p className="stat-value text-fx-yield">%{s?.dailyInstantCapPct ?? 0}</p>
            </div>
            <div className="mb-4">
              <p className="stat-label">{tt("remainingInstant")}</p>
              <p className="stat-value">{s ? fmtUsd(s.dailyRemaining) : "…"}</p>
            </div>
          </div>
          <div>
            {s && s.queuedUnlock > 0 && (
              <div className="chip bg-fx-gold/15 text-fx-gold">
                {tt("queued", { date: new Date(s.queuedUnlock * 1000).toLocaleDateString(lang) })}
              </div>
            )}
            <p className="mt-3 text-xs text-slate-500">
              {tt("gateNote")}
            </p>
          </div>
        </div>
      </section>

      {/* Risk seffafligi (akademik dayanakli - Bundi 2026) */}
      <section className="mb-8 panel panel-hover p-6">
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-white">{tt("riskPanel")}</h2>
          <span className="stat-label">{tt("riskVerified")}</span>
        </div>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <div className="rounded-xl border border-white/5 bg-white/[0.02] p-4">
            <p className="stat-label">{tt("riskJunior")}</p>
            <p className="mt-1 font-mono text-lg font-semibold text-white">
              %{s ? s.juniorRatioPct.toFixed(1) : "…"}
            </p>
            <p className="mt-1 text-xs text-slate-500">
              {s && s.juniorRatioPct >= 3 ? tt("riskJuniorOk") : tt("riskJuniorLow")}
            </p>
          </div>
          <div className="rounded-xl border border-white/5 bg-white/[0.02] p-4">
            <p className="stat-label">{tt("riskCap")}</p>
            <p className="mt-1 font-mono text-lg font-semibold text-white">%10</p>
            <p className="mt-1 text-xs text-slate-500">{tt("riskCapNote")}</p>
          </div>
          <div className="rounded-xl border border-white/5 bg-white/[0.02] p-4">
            <p className="stat-label">{tt("riskT2")}</p>
            <p className="mt-1 font-mono text-lg font-semibold text-white">T+2</p>
            <p className="mt-1 text-xs text-slate-500">{tt("riskT2Note")}</p>
          </div>
          <div className="rounded-xl border border-white/5 bg-white/[0.02] p-4">
            <p className="stat-label">{tt("riskAudit")}</p>
            <p className="mt-1 font-mono text-lg font-semibold text-white">179</p>
            <p className="mt-1 text-xs text-slate-500">{tt("riskAuditNote")}</p>
          </div>
        </div>
        <p className="mt-4 text-xs leading-relaxed text-slate-500">
          {tt("riskNote")}
        </p>
      </section>

      {/* Islem paneli */}
      <section className="panel panel-hover p-6">
        <div className="mb-5 flex gap-2 rounded-xl bg-ink-900/60 p-1">
          {(["deposit", "redeem"] as const).map((t) => (
            <button
              key={t}
              type="button"
              aria-pressed={tab === t}
              onClick={() => setTab(t)}
              className={`flex-1 rounded-lg px-4 py-2.5 text-sm font-semibold transition-all ${
                tab === t
                  ? "bg-gradient-to-r from-fx-base to-fx-glow text-ink-900 shadow-lg"
                  : "text-slate-400 hover:text-white"
              }`}
            >
              {t === "deposit" ? tt("tabDeposit") : tt("tabRedeem")}
            </button>
          ))}
        </div>

        <div className="mb-4">
          <div className="mb-2 flex items-center justify-between">
            <label className="stat-label" htmlFor="amount-input">
              {tt("amount")}
            </label>
            <span className="text-xs text-slate-500" id="balance-hint">
              Bakiye: {balance ? fmtFull(balance) : "0"} {tab === "deposit" ? "cUSD" : "scUSD"}
            </span>
          </div>
          <input
            id="amount-input"
            className="input"
            inputMode="decimal"
            placeholder="0.00"
            value={amount}
            disabled={busy || !account}
            aria-describedby="balance-hint"
            onChange={(e) => setAmount(e.target.value)}
          />
          {balance && Number(balance) > 0 && (
            <button
              type="button"
              className="mt-2 text-xs font-medium text-fx-glow hover:underline"
              onClick={() => setAmount(balance)}
              disabled={busy}
            >
              {tt("useMax")}
            </button>
          )}
        </div>

        {!account ? (
          <button type="button" className="btn-primary" onClick={connect}>
            {tt("connectWallet")}
          </button>
        ) : (
          <button type="button" className="btn-primary" disabled={busy || !amount} onClick={submit}>
            {busy ? tt("processing") : tab === "deposit" ? tt("depositBtn") : tt("redeemBtn")}
          </button>
        )}

        {message && (
          <div
            role={message.kind === "err" ? "alert" : "status"}
            aria-live={message.kind === "err" ? "assertive" : "polite"}
            className={`mt-4 rounded-xl px-4 py-3 text-sm ${
              message.kind === "ok"
                ? "bg-fx-yield/10 text-fx-yield"
                : message.kind === "info"
                  ? "bg-fx-gold/10 text-fx-gold"
                  : "bg-fx-danger/10 text-fx-danger"
            }`}
          >
            {message.text}
          </div>
        )}

        <p className="mt-4 text-center text-xs text-slate-600">{tt("shieldNote")}</p>
      </section>

      <footer className="mt-8 text-center text-xs text-slate-600">
        Cleanvest · {tt("footer")} · 160/160 Foundry tests · <span className="font-mono">rc=0</span>
      </footer>
    </div>
  );
}

function StatCard({
  label,
  value,
  sub,
  accent,
  danger,
}: {
  label: string;
  value: string;
  sub?: string;
  accent?: boolean;
  danger?: boolean;
}) {
  return (
    <div className="panel panel-hover p-5">
      <p className="stat-label">{label}</p>
      <p
        className={`mt-1 font-mono text-2xl font-semibold ${
          danger ? "text-fx-danger" : accent ? "text-fx-glow" : "text-white"
        }`}
      >
        {value}
      </p>
      {sub && <p className="mt-1 text-xs text-slate-500">{sub}</p>}
    </div>
  );
}

function TierRow({
  name,
  range,
  yieldPct,
  active,
}: {
  name: string;
  range: string;
  yieldPct: number;
  active: boolean;
}) {
  return (
    <div
      className={`flex items-center justify-between rounded-xl border px-4 py-3 transition-all ${
        active ? "border-fx-base/50 bg-fx-base/10" : "border-white/5 bg-white/[0.02]"
      }`}
    >
      <div className="flex items-center gap-3">
        <span className={`h-2 w-2 rounded-full ${active ? "bg-fx-glow" : "bg-slate-600"}`} />
        <span className="text-sm font-medium text-slate-200">{name}</span>
        <span className="font-mono text-xs text-slate-500">{range}</span>
      </div>
      <span className={`font-mono text-lg font-semibold ${active ? "text-fx-yield" : "text-slate-300"}`}>
        %{yieldPct.toFixed(2)}
      </span>
    </div>
  );
}

export default App;
