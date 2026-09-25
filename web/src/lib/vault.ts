import { useMemo } from "react";
import { BrowserProvider, Contract, formatUnits, parseUnits } from "ethers";
import CleanFXVaultAbi from "../contracts/CleanFXVault.abi.json";
import CleanUSDAbi from "../contracts/CleanUSD.abi.json";
import addresses from "../contracts/addresses.json";

export const CHAIN_ID = 8453; // Base
export const VAULT_ADDR = (addresses as unknown as Record<string, string>).CleanFXVault || "";
export const CUSD_ADDR = (addresses as unknown as Record<string, string>).CleanUSD || "";

export type VaultState = {
  tvl: string;
  totalSupply: string;
  sharePrice: number;
  tier: string;
  seniorYieldPct: number;
  juniorRatioPct: number;
  dailyInstantCapPct: number;
  settleDays: number;
  dailyRemaining: string;
  walletCUSD: string;
  walletScUSD: string;
  queuedUnlock: number;
  loaded: boolean;
};

const TIER_NAMES = ["Tier 0", "Tier 1", "Tier 2", "Optimize"];

/** Read-only saglayici (cuzdan bagli degilken bile veri okur). */
function readOnlyProvider(): BrowserProvider | null {
  if (typeof window === "undefined" || !window.ethereum) return null;
  return new BrowserProvider(window.ethereum);
}

export function useContracts(signer?: BrowserProvider | null) {
  return useMemo(() => {
    // Adresler deploy edilene kadar Contract OLUSTURMA - ethers constructor
    // bos stringi ENS adi sanip resolveName yapar (crash).
    if (!VAULT_ADDR || !CUSD_ADDR) return { vault: null, cusd: null };
    const vault = new Contract(VAULT_ADDR, CleanFXVaultAbi, signer);
    const cusd = new Contract(CUSD_ADDR, CleanUSDAbi, signer);
    return { vault, cusd };
  }, [signer]);
}

/** Vault durumunu tek cagrida toplar (HITL minimum: hepsi otomatik). */
export async function fetchVaultState(account: string | null): Promise<VaultState> {
  const provider = readOnlyProvider();
  const empty: VaultState = {
    tvl: "0", totalSupply: "0", sharePrice: 1, tier: "-", seniorYieldPct: 0,
    juniorRatioPct: 0, dailyInstantCapPct: 0, settleDays: 0, dailyRemaining: "0",
    walletCUSD: "0", walletScUSD: "0", queuedUnlock: 0, loaded: false,
  };
  if (!provider) return empty;
  if (!VAULT_ADDR || !CUSD_ADDR) {
    // Adresler henüz deploy edilmedi - UI "deploy bekleniyor" durumunu gosterir.
    // Bos string ethers tarafindan ENS adi saninip crash'e yol acar (resolveName).
    return empty;
  }

  const vault = new Contract(VAULT_ADDR, CleanFXVaultAbi, provider);
  const cusd = new Contract(CUSD_ADDR, CleanUSDAbi, provider);

  const [tvl, totalSupply, tier, yieldRaw, juniorRatio, gate, balance, scBalance, unlock] =
    await Promise.all([
      vault.totalAssets(),
      vault.totalSupply(),
      vault.activeTier(),
      vault.currentSeniorYield(),
      vault.juniorCoverageRatio(),
      vault.redemptionGate(),
      account ? cusd.balanceOf(account) : 0n,
      account ? vault.balanceOf(account) : 0n,
      account ? vault.queuedUnlockTime(account) : 0n,
    ]);

  const [capPct, settleDays] = gate;
  const sharePrice = totalSupply > 0n ? Number(tvl) / Number(totalSupply) : 1;

  return {
    tvl: formatUnits(tvl, 18),
    totalSupply: formatUnits(totalSupply, 18),
    sharePrice,
    tier: TIER_NAMES[Number(tier)] ?? "-",
    seniorYieldPct: (Number(formatUnits(yieldRaw, 18)) * 100),
    // DİKKAT: juniorCoverageRatio BPS doner (300 = %3.00), 18 decimals DEGIL.
    // Onceki kod formatUnits(18) yapip *100 carpiyordu -> UI'da %0.00 gosteriyordu.
    juniorRatioPct: Number(juniorRatio) / 100,
    dailyInstantCapPct: Number(capPct) / 100,
    settleDays: Number(settleDays) / 86400,
    dailyRemaining: formatUnits(await vault.totalSupply().then((s: bigint) => (s * BigInt(capPct)) / 10000n), 18),
    walletCUSD: account ? formatUnits(balance, 18) : "0",
    walletScUSD: account ? formatUnits(scBalance, 18) : "0",
    queuedUnlock: Number(unlock),
    loaded: true,
  };
}

/** Slippage-korumali depozito: minShares UI'da OTOMATIK hesaplanir (inflation attack kalkani). */
export async function depositWithMin(
  provider: BrowserProvider,
  amountEth: string,
  account: string,
  slippageBps = 50,
): Promise<string> {
  const vault = new Contract(VAULT_ADDR, CleanFXVaultAbi, await provider.getSigner());
  const cusd = new Contract(CUSD_ADDR, CleanUSDAbi, await provider.getSigner());
  const amount = parseUnits(amountEth, 18);

  // 1) Onay (yetersizse)
  const allowance = await cusd.allowance(account, VAULT_ADDR);
  if (allowance < amount) {
    const approveTx = await cusd.approve(VAULT_ADDR, amount);
    await approveTx.wait();
  }

  // 2) minShares hesapla: beklenen pay - slippage toleransi
  const expectedShares = await vault.convertToShares(amount);
  const minShares = (expectedShares * (10000n - BigInt(slippageBps))) / 10000n;

  // 3) Slippage-korumali depozito (ERC-4626 inflation attack kalkani)
  const tx = await vault.depositWithMin(amount, account, minShares);
  const receipt = await tx.wait();
  return receipt.hash;
}

/** Slippage-korumali cikis: kota icindeyse anlik, degilse T+2 kuyruk. */
export async function redeemWithMin(
  provider: BrowserProvider,
  amountEth: string,
  account: string,
  slippageBps = 50,
): Promise<string> {
  const vault = new Contract(VAULT_ADDR, CleanFXVaultAbi, await provider.getSigner());
  const amount = parseUnits(amountEth, 18);

  const shares = await vault.convertToShares(amount);
  const expectedAssets = await vault.convertToAssets(shares);
  const minAssets = (expectedAssets * (10000n - BigInt(slippageBps))) / 10000n;

  const tx = await vault.redeemWithMin(shares, account, account, minAssets);
  const receipt = await tx.wait();
  return receipt.hash;
}

/** Kota asimi durumunda cikisi T+2 kuyruguna al (cikislar KILITLENMEZ). */
export async function requestRedemption(
  provider: BrowserProvider,
  amountEth: string,
): Promise<string> {
  const vault = new Contract(VAULT_ADDR, CleanFXVaultAbi, await provider.getSigner());
  const amount = parseUnits(amountEth, 18);
  const tx = await vault.requestRedemption(amount);
  const receipt = await tx.wait();
  return receipt.hash;
}
