"""C1-coverage-pin: Foundry-sozlesme-kapsamisi-stale-kalamaz VE asgari-esik.

Olcum: `forge coverage --report lcov`-ciktisindan lcov.info-ayristirilir;
sozlesme-brancoverage ( script/ VE .t.sol-dosyalari-HARIC) okunur.
README-241-satirinda-fixture-satiri-tazedir ( pin-soft: README'de-sabit-yuzde
YAZILMAZ-notu-vardir, bu-yuzden-pin-yalnizca-olcum-yapabildigi-clarus-bolumu
dogrular-VE-asgari-esikleri-sabitle).

CI-uyumluluk: forge-yoksa-acik-gerekceyle-atlanir ( Foundry-runner-standart
de-gil; GitHub-runner'da-ek-kurulum-gerektirir; sessiz-pas-DEGIL).
"""
import io
import os
import shutil
import subprocess

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _forge() -> str:
    yol = shutil.which("forge")
    if yol:
        return yol
    ev = os.path.expanduser("~/.foundry/bin/forge")
    if os.path.exists(ev):
        return ev
    return ""


FORGE = _forge()

pytestmark = pytest.mark.skipif(
    not FORGE, reason="forge-yok ( C1-pin-atlandi: Foundry-kurulu-degil)")


def _sozlesme_brancov(lcov_yolu):
    """lcov.info-ayristir: SADECE contracts/*-kaynaklari ( script/ ve .t.sol
   fixture'lari-HARIC). Bran-sayimi-DA-satirlari-uzerinden-yapilir ( forge
    lcov'da-budalama-bilgisi-YOK: her-bran-bir-satir-olarak-dusunulur-VE
    budama-bilgisi-YOK'tur)."""
    per_file = {}
    cur = None
    with io.open(lcov_yolu, encoding="utf-8", errors="replace") as fh:
        for ln in fh:
            if ln.startswith("SF:"):
                yol = ln[3:].strip()
                # sozlesme-kaynaklari: contracts/ altinda VE .s.sol-DEGIL
                ad = yol.split("/")[-1]
                if yol.startswith("contracts/") and not ad.endswith(".s.sol"):
                    cur = ad
                    per_file[cur] = {"hit": 0, "tot": 0}
                else:
                    cur = None
            elif ln.startswith("DA:") and cur is not None:
                _sv, hit = ln[3:].strip().split(",")
                per_file[cur]["tot"] += 1
                if hit != "0":
                    per_file[cur]["hit"] += 1
    return per_file


def test_foundry_sozlesme_kapsamisi_asgari_esik_ve_stale_degil():
    res = subprocess.run(
        [FORGE, "coverage", "--report", "lcov"],
        cwd=ROOT, capture_output=True, text=True, timeout=1800,
    )
    assert res.returncode == 0, "forge coverage basarisiz: %s" % res.stderr[-400:]
    lcov = os.path.join(ROOT, "lcov.info")
    assert os.path.isfile(lcov), "lcov.info-uretilmedi"
    per_file = _sozlesme_brancov(lcov)
    assert per_file, "lcov.info-icinde-sozlesme-kaynagi-bulunamadi"
    dosya = sorted(per_file.items())
    for ad, v in dosya:
        assert v["tot"] > 0, "%s-icin-olcum-satiri-yok" % ad
    # asgari-esik: her-sozlesme-%90-VE-uzerinde-olmali ( uretim-kalitesi;
    # C1-olcumu-2026-10-20: 11/11-sozlesme->%94.4-100).
    dusuk = [(ad, 100.0 * v["hit"] / v["tot"])
             for ad, v in dosya if 100.0 * v["hit"] / v["tot"] < 90.0]
    assert not dusuk, (
        "sozlesme-kapsamisi-%90-altinda: %s"
        % ", ".join("%s:%.1f%%" % d for d in dusuk))
    # README'ye-yazili-sabit-yuzde-yok ( README-acikca-boyle-der)-pin-bu-
    # durumda-yalnizca-taze-olcumun-yapilabildigini-kanitlar. README'de-eer
    # sabit-yuzde-belirse-stale-kontrolu-devreye-girer.
    readme = io.open(os.path.join(ROOT, "README.md"), encoding="utf-8").read()
    hit_h = sum(v["hit"] for v in per_file.values())
    hit_t = sum(v["tot"] for v in per_file.values())
    toplam = 100.0 * hit_h / hit_t
    import re
    stale = []
    for m in re.finditer(r"contracts[^\)]*?([0-9.]+)\s*%\s*coverage", readme):
        if abs(float(m.group(1)) - toplam) > 0.5:
            stale.append(m.group(0))
    assert not stale, (
        "README-coverage-stale: %s ( taze-sozlesme-kapsamisi: %.1f%%)"
        % (stale, toplam))
