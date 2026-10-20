"""G42 README-pin: Cleanvest rust-Merkle test-sayisi stale-kalinti-olamaz.

Kapsam: `cargo test --manifest-path merkle/Cargo.toml --features proof`
( README'de 61 passed). forge (Foundry) testleri bu pin'in disinda: forge
bu-makinede-yok ve README-de-ayrica-etiketlidir.
"""
import io
import os
import re
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def test_readme_merkle_test_count_is_not_stale():
    readme = io.open(os.path.join(ROOT, "README.md"), encoding="utf-8").read()
    res = subprocess.run(
        ["cargo", "test", "--manifest-path", "merkle/Cargo.toml",
         "--features", "proof"],
        cwd=ROOT, capture_output=True, text=True, timeout=1800,
    )
    assert res.returncode == 0, "cargo test basarisiz: %s" % res.stderr[-400:]
    passed = 0
    for m in re.finditer(r"test result: ok\.\s*(\d+) passed", res.stdout):
        passed += int(m.group(1))
    stale = []
    for m in re.finditer(r"Rust Merkle:\s*(\d[\d.,]*)\s*passed", readme):
        claimed = int(m.group(1).replace(".", "").replace(",", ""))
        if claimed != passed:
            stale.append(m.group(0))
    assert not stale, (
        "README rust-Merkle test-sayisi stale: %s (taze: %d passed)"
        % (stale, passed)
    )
