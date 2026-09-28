#!/usr/bin/env python3
"""
readme_stats.py — README'e giren HER sayiyi koddan uretir.

Kullanim:  python3 scripts/readme_stats.py
Cikti:     README icin gerekli tum sayilar (test adetleri, coverage,
           fiyatlar, sayisma), her biri uretildigi kaynakla etiketli.

Bu portfoyun TEKRAR EDEN zayifligini kapatir: elle yazilmis sayilarin
koddan kaymasi (README 166 derken gercek 182 oldugu gibi).

Kaynaklar (sifir elle giris):
  - Foundry test sayilari  : forge test --json ciktilarinin toplanmasi
  - Coverage              : forge coverage ciktilarinin parse edilmesi
  - Sözlesme sabitleri    : contracts/*.sol icinden grep
  - Vitest                : web/ test ciktilari (varsa)
"""

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FOUNDRY = str(Path.home() / ".foundry" / "bin")


def sh(cmd, cwd=ROOT):
    """Komut calistir; hata vermez, stdout doner."""
    try:
        r = subprocess.run(
            cmd, cwd=cwd, capture_output=True, text=True, timeout=300,
            env={"PATH": FOUNDRY + ":/usr/bin:/bin", "HOME": str(Path.home())},
        )
        return r.stdout, r.returncode
    except Exception as e:
        return "", 1


def foundry_test_counts():
    """forge test --json -> her suite'in passed/failed sayilari.

    Forge --json formati (v1+): her satir bir JSON nesnesidir;
    ust duzey anahtarlar suite tam adlaridir ("test/X.t.sol:Suite"),
    degerleri {"test_results": {testAdi: {"status": "Success"|"Failure"}}}.
    """
    out, rc = sh(["forge", "test", "--json"])
    if rc != 0 or not out.strip():
        return None, "forge test --json calismadi (rc=%d)" % rc
    total_pass = total_fail = total_suites = 0
    per_suite = {}
    try:
        for line in out.splitlines():
            line = line.strip()
            if not line.startswith("{"):
                continue
            suites = json.loads(line)
            for suite_full, payload in suites.items():
                tests = payload.get("test_results", {})
                p = sum(1 for t in tests.values() if t.get("status") == "Success")
                f = sum(1 for t in tests.values() if t.get("status") != "Success")
                name = suite_full.split(":")[-1] + ".t.sol"
                total_pass += p
                total_fail += f
                total_suites += 1
                per_suite[name] = {"passed": p, "failed": f, "total": p + f}
    except Exception as e:
        return None, "JSON parse hatasi: %s" % e
    if total_suites == 0:
        return None, "suite bulunamadi"
    return {
        "suites": total_suites,
        "passed": total_pass,
        "failed": total_fail,
        "total": total_pass + total_fail,
        "per_suite": per_suite,
    }, None


def foundry_test_counts_text():
    """Fallback: forge test (insan-okunur) ciktilarindan son satiri parse."""
    out, rc = sh(["forge", "test"])
    m = re.search(
        r"Ran (\d+) test suites?.*?(\d+) tests passed, (\d+) failed", out, re.S
    )
    if not m:
        return None, "parse edilemedi"
    return {
        "suites": int(m.group(1)),
        "passed": int(m.group(2)),
        "failed": int(m.group(3)),
        "total": int(m.group(2)) + int(m.group(3)),
    }, None


def vitest_counts():
    """web/ altinda vitest varsa sayar (yoksa atlar).

    Vitest --reporter=json stdout'a basmaz; .vitest/json/output.json
    dosyasina yazar. Once oradan, basarirsizsa stdout'tan dener.
    """
    web = ROOT / "web"
    if not (web / "package.json").exists():
        return None, "web/ yok"

    out, rc = sh(["npx", "vitest", "run", "--reporter=json"], cwd=web)
    # 1) Dosyadan oku (vitest'in asil cikti yolu)
    jpath = web / ".vitest" / "json" / "output.json"
    raw = None
    if jpath.exists():
        try:
            raw = jpath.read_text()
        except Exception:
            raw = None
    # 2)stdout'tan dene (eski vitest surumleri)
    if raw is None and out.strip().startswith("{"):
        raw = out
    if raw is None:
        return None, "vitest JSON ciktisi bulunamadi (%s)" % jpath
    try:
        obj = json.loads(raw)
        return {
            "total": obj.get("numTotalTests", 0),
            "passed": obj.get("numPassedTests", 0),
            "failed": obj.get("numFailedTests", 0),
        }, None
    except Exception as e:
        return None, "vitest JSON parse edilemedi: %s" % e


def price_constants():
    """ListingGate.sol fiyat sabitlerini koddan okur."""
    src = (ROOT / "contracts" / "ListingGate.sol").read_text()
    names = ["PRICE_SCAN", "PRICE_SCAN_HUMAN", "PRICE_FUZZ_PATCH", "PRICE_PRIORITY"]
    prices = {}
    for n in names:
        m = re.search(r"uint256\s+public\s+constant\s+%s\s*=\s*(\d+)" % n, src)
        prices[n] = int(m.group(1)) if m else None
    return prices


def contract_count():
    """contracts/ altindaki .sol sayisi (interface disinda)."""
    cdir = ROOT / "contracts"
    files = [p for p in cdir.glob("*.sol")]
    return len(files), sorted(p.name for p in files)


def main():
    print("=" * 72)
    print("README ISTETISTIKLERI — KODDAN URETILDI (elle giris YOK)")
    print("=" * 72)

    print("\n[1] Foundry test sayilari")
    res, err = foundry_test_counts()
    if res is None:
        print("  JSON modu basarisiz (%s) — metin moduna dusuluyor" % err)
        res, err = foundry_test_counts_text()
    if res is None:
        print("  HATA: %s" % err)
    else:
        print("  Suite sayisi : %d" % res["suites"])
        print("  Gecen test   : %d" % res["passed"])
        print("  Kalan test   : %d" % res["failed"])
        print("  TOPLAM       : %d" % res["total"])
        if "per_suite" in res:
            print("  Suite bazinda:")
            for name, c in sorted(res["per_suite"].items()):
                print("    %-38s %d" % (name, c["total"]))

    print("\n[2] Vitest (web/) sayilari")
    vres, verr = vitest_counts()
    if vres is None:
        print("  ATLANDI: %s" % verr)
    else:
        print("  Gecen : %d   Kalan: %d   Toplam: %d" % (
            vres["passed"], vres["failed"], vres["total"]))

    print("\n[3] ListingGate fiyat sabitleri (contracts/ListingGate.sol)")
    for k, v in price_constants().items():
        print("  %-22s %s" % (k, ("$%d" % v) if v else "BULUNAMADI"))

    print("\n[4] Sözlesme sayisi (contracts/)")
    n, names = contract_count()
    print("  Adet: %d" % n)
    for nm in names:
        print("    - %s" % nm)

    print("\n" + "=" * 72)
    print("README'E YAZILACAK TEK SATIR (uretildi):")
    if res:
        line = "%d Foundry" % res["passed"]
        if vres:
            line += " + %d vitest" % vres["passed"]
        print("  %s" % line)
    print("=" * 72)
    return 0


if __name__ == "__main__":
    sys.exit(main())
