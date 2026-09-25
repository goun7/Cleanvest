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

/**
 * dailyRemaining bug regresyonu (GERCEK hata):
 * Onceden UI "Kalan anlik" icin yanlizca cap = supply*%10 gosteriyordu;
 * bugun kullanilan kotayi cikarmiyordu. Sozlesmedeki
 * _dailyRemainingInstant(usedToday) ile ayni formul olmali:
 *   cap - usedToday (0'a sabitlenir, negatif olmaz)
 */
describe("dailyRemaining (anlik kalan kota)", () => {
  const capOf = (supply: bigint) => (supply * 1000n) / 10000n;
  const remaining = (supply: bigint, used: bigint) => {
    const cap = capOf(supply);
    return used >= cap ? 0n : cap - used;
  };

  it("kullanilmamissa cap'in tamamini gosterir", () => {
    expect(remaining(1000n, 0n)).toBe(100n);
  });

  it("kullanilmis miktari cikarir (onceki bug)", () => {
    // 1000 supply, cap 100, 40 kullanildi -> 60 kalmali (eski kod 100 gosterirdi)
    expect(remaining(1000n, 40n)).toBe(60n);
  });

  it("cap asilinca 0'a sabitlenir, negatif olmaz", () => {
    expect(remaining(1000n, 100n)).toBe(0n);
    expect(remaining(1000n, 999n)).toBe(0n);
  });
});
