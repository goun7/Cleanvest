import { describe, it, expect } from 'vitest';
import { bpsToPct, pct, LIVE_VERIFIED } from '../lib/vault';

/**
 * Bu testler CANLI ANVIL degerleriyle yazilmistir (2026-09-25 E2E turu).
 * Amaç: "kod okuma" ile "calistirma" arasindaki hatalari kalici olarak onlemek.
 */
describe('birim donusumleri (canli anvil degerleri)', () => {
  it('juniorCoverageRatio BPS -> yuzde (KRITIK regression)', () => {
    // Canli anvil: juniorCoverageRatio() = 300 bps = %3.00
    // ESKI HATA: formatUnits(300,18)*100 = %0.00 gosteriyordu
    expect(bpsToPct(300)).toBe(3);
    expect(bpsToPct(300n)).toBe(3);
    expect(bpsToPct(0)).toBe(0);
    expect(bpsToPct(1000)).toBe(10); // %10
  });

  it('junior minimum ortu invariant: %3.00', () => {
    // Sozlesme invariant: juniorReserve*10000 >= tvl*300
    // UI'da "GUVENLI (>= %3)" gosterimi icin esik
    expect(bpsToPct(LIVE_VERIFIED.juniorMinBps)).toBe(3);
  });

  it('gunluk cikis kapisi: %10 + 2 gun (canli redemptionGate)', () => {
    // Canli anvil: redemptionGate() = (1000, 172800)
    expect(bpsToPct(LIVE_VERIFIED.dailyCapBps)).toBe(10);
    expect(LIVE_VERIFIED.settleSeconds).toBe(2 * 24 * 60 * 60);
  });

  it('getiri egrisi spec ile birebir (testYieldCurveMatchesSpec ile ayni)', () => {
    // Sozlesme testi 0.0305e18/0.0291e18/0.0292e18 dogrular
    // UI'da toFixed(2) ile gosterilir
    expect(pct(LIVE_VERIFIED.tier0YieldPct)).toBe('%3.05');
    expect(pct(LIVE_VERIFIED.tier1YieldPct)).toBe('%2.91');
    expect(pct(LIVE_VERIFIED.tier2YieldPct)).toBe('%2.92');
  });

  it('18 decimals getiri donusumu (currentSeniorYield)', () => {
    // Canli anvil: currentSeniorYield() = 30500000000000000 (3.05e16) = %3.05
    const raw = 30500000000000000n;
    const eth = Number(raw) / 1e18; // formatUnits(18) karsiligi
    expect(eth).toBe(0.0305);
    expect(eth * 100).toBe(3.05);
  });

  it('bps formatinda 1 ether = 18 decimals DEGIL (tuzak)', () => {
    // Bu test, birimin 18 decimals oldugu yanlis varsayimini yakalar.
    // juniorCoverageRatio BPS doner; 300 bps = %3, 300e18 DEGIL.
    const badCalc = Number(300n * 10n ** 18n) / 1e18 * 100; // eski hatali yol
    expect(badCalc).not.toBe(3); // eski kod %0.00 uretir
    expect(bpsToPct(300)).toBe(3); // dogru yol
  });
});
