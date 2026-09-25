import { describe, it, expect } from "vitest";
import { getLang, t } from "../lib/i18n";

describe('i18n dil paketi', () => {
  it('tum TR anahtarlari EN karsiligina sahip', () => {
    // Iki dilde de tum anahtarlar tanimli olmali (eksik anahtar = UI'da gozukmeyen metin)
    const trKeys = new Set<string>();
    const enKeys = new Set<string>();

    // i18n.ts icerisindeki her iki dict'i dolasilabilir degil,
    // bu yuzden tum bilinen anahtarlari test ediyoruz
    const known = [
      'subtitle', 'live', 'connected', 'liveNoData', 'connectWallet', 'wrongNetwork', 'noWallet',
      'statTvl', 'statTier', 'statPrice', 'statJunior',
      'juniorSafe', 'juniorRisk', 'shareSub',
      'yieldPanel', 'yieldVerified', 'tier0', 'tier1', 'tier2', 'yieldNote',
      'gatePanel', 'dailyCap', 'remainingInstant', 'queued', 'gateNote',
      'tabDeposit', 'tabRedeem', 'amount', 'balance', 'useMax',
      'depositBtn', 'redeemBtn', 'processing',
      'depositOk', 'redeemOk', 'queuedInfo', 'fail', 'dataFail',
      'shieldNote', 'footer',
    ];
    for (const k of known) {
      trKeys.add(t('tr', k));
      enKeys.add(t('en', k));
      // Anahtar kendisi donerse = tanimsiz (dict'te yok)
      expect(t('tr', k), `TR eksik anahtar: ${k}`).not.toBe(k);
      expect(t('en', k), `EN eksik anahtar: ${k}`).not.toBe(k);
    }
    expect(trKeys.size).toBeGreaterThan(30);
    expect(enKeys.size).toBeGreaterThan(30);
  });

  it('parametre degisimi calisir', () => {
    expect(t('tr', 'wrongNetwork', { id: 8453 })).toContain('8453');
    expect(t('en', 'wrongNetwork', { id: 8453 })).toContain('8453');
    expect(t('tr', 'queued', { date: '01.01.2026' })).toContain('01.01.2026');
  });

  it('getLang tarayici diline gore varsayilan doner', () => {
    const lang = getLang();
    expect(['tr', 'en']).toContain(lang);
  });

  it('bilinmeyen anahtar kendisiyle geri doner (fallback)', () => {
    expect(t('tr', 'BOYLE_BIR_ANAHTAR_YOK')).toBe('BOYLE_BIR_ANAHTAR_YOK');
  });

  it('EN ve TR ayni metni degil (gercek ceviri)', () => {
    expect(t('tr', 'connectWallet')).not.toBe(t('en', 'connectWallet'));
    expect(t('tr', 'statTvl')).not.toBe(t('en', 'statTvl'));
  });
});
