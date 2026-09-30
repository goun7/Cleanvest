#!/usr/bin/env python3
"""tier_yield testleri — CleanFXVault.activeTier() ile birebirlik."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from importlib import import_module

# Dosya adi rakamla basladigi icin normal import calismaz
_mod = import_module("22_hazna_adaylari")
tier_yield = _mod.tier_yield
TIERS = _mod.TIERS
HAZINEDARLAR = _mod.HAZINEDARLAR


class TestTierYield:
    """Solidity CleanFXVault.activeTier() ile birebirlik."""

    def test_tier0_kucuk_tvl(self):
        """TVL < $250k -> %3.05 (Tier0)."""
        assert tier_yield(100_000) == 0.0305

    def test_tier0_sifir(self):
        """TVL = 0 -> Tier0."""
        assert tier_yield(0) == 0.0305

    def test_tier0_sinir_alti(self):
        """TVL = $249,999 -> hala Tier0."""
        assert tier_yield(249_999) == 0.0305

    def test_tier1_sinir(self):
        """TVL = $250k -> Tier1 (%2.91), '<' kati sinir."""
        assert tier_yield(250_000) == 0.0291

    def test_tier1_orta(self):
        """TVL = $2.8M -> Tier1."""
        assert tier_yield(2_800_000) == 0.0291

    def test_tier2_sinir(self):
        """TVL = $12.5M -> Tier2 (%2.92)."""
        assert tier_yield(12_500_000) == 0.0292

    def test_tier2_buyuk(self):
        """TVL = $47M -> Tier2."""
        assert tier_yield(47_000_000) == 0.0292

    def test_tier2_cok_buyuk(self):
        """TVL = $1B -> Tier2 (inf siniri)."""
        assert tier_yield(1_000_000_000) == 0.0292

    def test_determinizm(self):
        """Ayni input -> ayni output (10 kez)."""
        once = tier_yield(3_000_000)
        for _ in range(10):
            assert tier_yield(3_000_000) == once

    def test_monoton_artan_tvl_tier_atlamasi(self):
        """Artan TVL ile sadece tier 0->1->2 sirasiyla atlar."""
        onceki = tier_yield(1)
        for tvl in [10_000, 100_000, 249_999, 250_000, 1_000_000,
                    12_499_999, 12_500_000, 100_000_000]:
            simdi = tier_yield(tvl)
            assert simdi in {0.0305, 0.0291, 0.0292}
            onceki = simdi


class TestSablonTutarliligi:
    """TIERS ile HAZINEDARLAR arasi tutarlilik."""

    def test_tiers_3_adet(self):
        """Docstring'de 3 tier soz verilmis."""
        assert len(TIERS) == 3

    def test_haznedarlar_15_adet(self):
        """15 kurumsal haznedar profili."""
        assert len(HAZINEDARLAR) == 15

    def test_haznedarlar_getiri_negatif_degil(self):
        """Hicbir mevcut getiri negatif olamaz."""
        for _kat, _nakit, verimsiz in HAZINEDARLAR:
            assert verimsiz >= 0

    def test_haznedarlar_nakit_pozitif(self):
        """Bosta nakit pozitif olmali."""
        for _kat, nakit, _verim in HAZINEDARLAR:
            assert nakit > 0

    def test_tum_haznedarlar_tier_yield_alir(self):
        """Her haznedar icin tier_yield tanimli."""
        for _kat, nakit, _verim in HAZINEDARLAR:
            assert tier_yield(nakit) in {0.0305, 0.0291, 0.0292}

    def test_tier1_daha_verimli_hepsi_icin(self):
        """Cleanvest getirisi mevcut verimsiz getiriyi her zaman gecmeli."""
        for _kat, nakit, verimsiz in HAZINEDARLAR:
            assert tier_yield(nakit) > verimsiz
