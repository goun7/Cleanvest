// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
// BRACED import: her iki kontrat da en üst düzeyde `error InvalidSignatureS();`
// tanımladığından, tüm-dosya import'u isim çakışması yaratır. Yalnızca tip
// adlarını içe aktarıyoruz; error seçiciyi aşağıda yerel olarak tanımlıyoruz
// (aynı imza "InvalidSignatureS()" → her iki kontratla AYNI seçici).
import {ProofOfLiabilities} from "../contracts/ProofOfLiabilities.sol";
import {CleanvestSettlement} from "../contracts/CleanvestSettlement.sol";

/// @title EIP-2 Low-s Malleability Test Suite (DAR görev, 2026-09-30)
/// @notice README dürüst sınırının kapanması: **ECDSA imza malleability
///         (low-s/EIP-2) kontrolü artık MEVCUTTUR** — hem legacy EIP-191
///         hem EIP-712 yollarında. Bir imzadan ikinci bir *gösterim*
///         (representation) artık ÜRETİLEMEZ: (r, s) geçerliyken (r, n-s, v')
///         aynı adresi geri kazansa bile ACIK REVERT (InvalidSignatureS) alır.
/// @dev 5 test:
///        1) Malleable imza SALDIRI GERÇEĞİ kanıtlanıp RED (Settlement, legacy+EIP-712)
///        2) Malleable imza RED (PoL, 4 yol) + iyi-cüzdan hâlâ çalışır
///        3) High-s doğrudan RED + low-s kabul (sınır değer kanıtı)
///        4) GERİYE DÖNÜK UYUM — vm.sign (düşük-s) imzaları 4 yolda geçerli
///        5) EIP-712 + low-s BİRLİKTE çalışır (katmanlı savunma)
contract EIP2MalleabilityTest is Test {
    ProofOfLiabilities public pol;
    CleanvestSettlement public settlement;

    /// @notice Standart anvil test anahtarı #0 (test-only, PUBLIC).
    ///         anvil --mnemonic "test test ... junk" ile üretilir.
    ///         PRIVATE_KEY DEĞİL — mainnet değeri YOK.
    uint256 constant ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address constant ANVIL_ADDR = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    /// @notice Anvil varsayılan zincir kimliği (forge test).
    uint256 constant ANVIL_CHAIN_ID = 31337;

    /// @notice secp256k1 eğri sırası n.
    uint256 constant N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    /// @notice EIP-2 eşiği: n/2. n tek sayı → floor = (n-1)/2; hiçbir tamsayı
    ///         s tam olarak n/2 olamayacağından "s <= n/2" EIP-2 ile birebirdir.
    uint256 constant HALF_N = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;

    /// @notice Test yaprakları (tek-yapraklı ağaç: kök = yaprak, proof = "").
    uint256 constant BALANCE = 1_000 ether;
    uint256 constant AMOUNT = 500 ether;
    uint256 constant NONCE = 7;

    /// @dev İki kontratın en üst düzey error'u ile AYNI imzaya (parametresiz)
    ///      sahip olduğu için AYNI seçici — expectRevert'te kullanılır. Braced
    ///      import error'ları dosya kapsamına getirmediği için isim çakışmaz.
    error InvalidSignatureS();

    function setUp() public {
        pol = new ProofOfLiabilities();
        settlement = new CleanvestSettlement();
    }

    // ============================================================
    // YARDIMCILAR
    // ============================================================

    /// @dev Özet üzerine imza üretir (EIP-191 sarmalama YAPMAZ — özet
    ///      "\x19Ethereum Signed Message:\n32" veya "\x19\x01" önekini
    ///      taşır). vm.sign düşük-s (canonical) imza üretir. Geri dönüş:
    ///      r(32) + s(32) + v(1) = 65 bayt.
    function _signDigest(bytes32 digest) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ANVIL_KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    /// @dev Legacy EIP-191 imzası: önce "\x19Ethereum Signed Message:\n32"
    ///      ile sarmalar, sonra imzalar.
    function _signEip191(bytes32 hash) internal pure returns (bytes memory) {
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
        return _signDigest(digest);
    }

    /// @dev MALLEABLE ÇİFT: (r, s, v) → (r, n-s, v'). ECDSA'da bir imzanın
    ///      iki geçerli gösterimi vardır: s' = n - s ve v' = v'un evirmesi
    ///      (27 ↔ 28). İKİSİ de AYNI adresi geri kazanır — malleability.
    ///      s düşük-s ise s' = n - s > n/2 → HIGH-s → EIP-2 ile RED.
    function _flipToHighS(bytes memory sig) internal pure returns (bytes memory) {
        (bytes32 r, bytes32 s, uint8 v) = _split(sig);
        // s' = n - s (yüksek yarıda); v' = 27 ↔ 28 evirmesi
        return abi.encodePacked(r, bytes32(N - uint256(s)), (v == 27) ? uint8(28) : uint8(27));
    }

    /// @dev 65 bayt imzayı (r, s, v) olarak parçalar. bytes memory
    ///      yerleşimi: 32 bayt uzunluk + veri (r 0..32, s 32..64, v 64).
    function _split(bytes memory sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "Imza 65 bayt olmali");
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    /// @dev Ham ecrecover precompile (address(1)) — kontratın kontrolü
    ///      OLMADAN imzanın hangi adresi geri kazandığını gösterir.
    function _rawEcrecover(bytes32 digest, uint8 v, bytes32 r, bytes32 s)
        internal
        view
        returns (address)
    {
        (bool ok, bytes memory out) =
            address(1).staticcall(abi.encodePacked(digest, bytes32(uint256(v)), r, s));
        require(ok, "ecrecover precompile cagrisi basarisiz");
        // Precompile 32 bayt döner; adres sağa-hizalı (alt 20 bayt).
        return address(uint160(uint256(bytes32(out))));
    }

    /// @dev SALDIRI GERÇEĞİ kanıtı: orijinal ve malleable (r,n-s,v') imzaları
    ///      ecrecover'da AYNI adresi geri kazanır — yani EIP-2 kontrolü
    ///      OLMADAN ikinci bir gösterim replay için kullanılabilirdi.
    ///      Yerel değişken sayısını test fonksiyonundan çıkartır (stack).
    function _assertMalleablePairSameAddress(
        bytes32 digest,
        bytes memory orig,
        bytes memory flipped
    ) internal view {
        (bytes32 rO, bytes32 sO, uint8 vO) = _split(orig);
        (bytes32 rF, bytes32 sF, uint8 vF) = _split(flipped);
        assertEq(
            _rawEcrecover(digest, vO, rO, sO), ANVIL_ADDR, "orijinal imza ANVIL_ADDR'i vermeli"
        );
        assertEq(
            _rawEcrecover(digest, vF, rF, sF),
            ANVIL_ADDR,
            "malleable imza AYNI adresi geri kazanir (saldiri gercegi)"
        );
        assertTrue(uint256(sF) > HALF_N, "cevrilmis s degeri high-s olmali");
    }

    /// @dev PoL'de domain-aware fail-closed yayın yapar; kullanılan epoch'u
    ///      döner. Özeti kontratın SEÇECEĞI epoch ile (currentEpoch + 1)
    ///      imzalar — önceki (revert olmamış) yayınlardan bağımsızdır.
    function _publishDomainPoL() internal returns (uint256 epoch) {
        epoch = pol.currentEpoch() + 1;
        address[] memory users = new address[](1);
        users[0] = ANVIL_ADDR;
        uint256[] memory balances = new uint256[](1);
        balances[0] = BALANCE;
        bytes[] memory sigs = new bytes[](1);
        sigs[0] = _signDigest(pol.liabilityDomainDigest(ANVIL_ADDR, BALANCE, epoch));

        pol.publishLiabilitiesFromSignedLeavesWithDomain(users, balances, sigs);
    }

    // ============================================================
    // 1) MALLEABLE İMZA — SALDIRI GERÇEĞİ + RED (CleanvestSettlement)
    // ============================================================

    /// @notice Saldırı: (r, s, v) imzasından (r, n-s, v') türetilir. Bu çift
    ///         ecrecover'da AYNI adresi geri kazanır (aşağıda kanıtlanır),
    ///         yani replay için ikinci bir gösterim üretmek MÜMKÜNDÜ.
    ///         Artık DEĞİL: legacy ve EIP-712 tüm Settlement yolları
    ///         InvalidSignatureS ile RED.
    function testMalleableSignatureRejectedInSettlement() public {
        assertEq(block.chainid, ANVIL_CHAIN_ID, "anvil zincir kimligi bekleniyor");

        bytes32 leaf = settlement.leafHash(AMOUNT, ANVIL_ADDR, NONCE);
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = leaf;
        bytes32 root = settlement.computeRoot(leaves);

        // --- LEGACY EIP-191 yolu ---
        bytes32 legacyDigest = settlement.toEthSignedMessageHash(leaf);
        bytes memory sig = _signDigest(legacyDigest);
        bytes memory malleable = _flipToHighS(sig);

        // SALDIRI GERÇEĞİ: malleable çift AYNI adresi geri kazanır
        _assertMalleablePairSameAddress(legacyDigest, sig, malleable);

        // Orijinal (düşük-s) imza hâlâ geçerli
        assertTrue(
            settlement.verifySignedOrder(leaf, sig, ANVIL_ADDR, "", root),
            "dusuk-s orijinal imza gecerli olmali"
        );

        // Malleable imza ARTIK reddedilir: public recoverSigner (legacy)
        vm.expectRevert(InvalidSignatureS.selector);
        settlement.recoverSigner(leaf, malleable);

        // verifyLeafSignature (legacy) → recoverSigner yolu
        vm.expectRevert(InvalidSignatureS.selector);
        settlement.verifyLeafSignature(leaf, malleable, ANVIL_ADDR);

        // verifySignedOrder (legacy EIP-191) yolu
        vm.expectRevert(InvalidSignatureS.selector);
        settlement.verifySignedOrder(leaf, malleable, ANVIL_ADDR, "", root);

        // --- EIP-712 DOMAIN yolu ---
        bytes32 domainDigest = settlement.orderDomainDigest(AMOUNT, ANVIL_ADDR, NONCE);
        bytes memory dSig = _signDigest(domainDigest);

        // domain imzası düşük-s iken geçerli
        assertTrue(
            settlement.verifySignedOrderWithDomain(AMOUNT, ANVIL_ADDR, NONCE, dSig, "", root),
            "dusuk-s domain imzasi gecerli olmali"
        );
        // malleable domain imzası RED
        vm.expectRevert(InvalidSignatureS.selector);
        settlement.verifySignedOrderWithDomain(
            AMOUNT, ANVIL_ADDR, NONCE, _flipToHighS(dSig), "", root
        );
    }

    // ============================================================
    // 2) MALLEABLE İMZA — RED (ProofOfLiabilities, 4 yol)
    // ============================================================

    /// @notice PoL'de her imza yolu (legacy publish, domain publish,
    ///         legacy verify, domain verify) malleable imzayı REDDER.
    ///         İyi-cüzdan kanıtı: saldırı girişimi sonrası düşük-s imzalar
    ///         hâlâ tüm yollarda çalışır (fail-open YOK).
    function testMalleableSignatureRejectedInPoL() public {
        address[] memory users = new address[](1);
        users[0] = ANVIL_ADDR;
        uint256[] memory balances = new uint256[](1);
        balances[0] = BALANCE;

        // --- A) legacy publishLiabilitiesFromSignedLeaves ---
        bytes32 legacyLeaf = keccak256(abi.encode(ANVIL_ADDR, BALANCE, 1));
        bytes[] memory legacySigs = new bytes[](1);
        legacySigs[0] = _flipToHighS(_signEip191(legacyLeaf));

        vm.expectRevert(InvalidSignatureS.selector);
        pol.publishLiabilitiesFromSignedLeaves(users, balances, legacySigs);

        // --- B) domain publishLiabilitiesFromSignedLeavesWithDomain ---
        bytes[] memory domainSigs = new bytes[](1);
        domainSigs[0] = _flipToHighS(_signDigest(pol.liabilityDomainDigest(ANVIL_ADDR, BALANCE, 1)));

        vm.expectRevert(InvalidSignatureS.selector);
        pol.publishLiabilitiesFromSignedLeavesWithDomain(users, balances, domainSigs);

        // --- C) domain verify (önce yayın, sonra malleable doğrulama) ---
        uint256 epoch = _publishDomainPoL();
        bytes32 root = pol.epochRoot(epoch);

        bytes memory goodDomainSig =
            _signDigest(pol.liabilityDomainDigest(ANVIL_ADDR, BALANCE, epoch));
        vm.expectRevert(InvalidSignatureS.selector);
        pol.verifyLiabilityWithDomain(ANVIL_ADDR, BALANCE, epoch, _flipToHighS(goodDomainSig), "");

        // --- D) legacy verifyLiability (yayını legacy yolla kur) ---
        pol.publishLiabilities(root, BALANCE, 1);
        bytes memory goodLegacySig = _signEip191(legacyLeaf);
        vm.expectRevert(InvalidSignatureS.selector);
        pol.verifyLiability(ANVIL_ADDR, BALANCE, 1, _flipToHighS(goodLegacySig), "");

        // --- İYİ-CÜZDAN KANITI: düşük-s imzalar hâlâ çalışır ---
        assertTrue(
            pol.verifyLiabilityWithDomain(ANVIL_ADDR, BALANCE, epoch, goodDomainSig, ""),
            "domain: dusuk-s imza saldiridan sonra hala gecerli"
        );
        assertTrue(
            pol.verifyLiability(ANVIL_ADDR, BALANCE, 1, goodLegacySig, ""),
            "legacy: dusuk-s imza saldiridan sonra hala gecerli"
        );
    }

    // ============================================================
    // 3) HIGH-S SINIR DEĞER — RED / LOW-S — KABUL
    // ============================================================

    /// @notice EIP-2 eşiği birebir: s > n/2 → RED. Doğrudan high-s değeri
    ///         (n-1, açıkça > n/2) reddedilir; tam eşiğin altındaki değer
    ///         (n-1)/2 ise EIP-2 kontrolünden geçer. Bu, "s <= n/2" koşusunun
    ///         çalıştığının sınır değer kanıtıdır.
    function testHighSRejectedAndLowSAccepted() public {
        bytes32 leaf = settlement.leafHash(AMOUNT, ANVIL_ADDR, NONCE);
        bytes32 fixedR =
            bytes32(uint256(0x1111111111111111111111111111111111111111111111111111111111111111));

        // Doğrudan high-s: r keyfi, s = n-1 (> n/2), v = 27
        bytes memory highS = abi.encodePacked(fixedR, bytes32(N - 1), uint8(27));
        (, bytes32 sHigh,) = _split(highS);
        assertTrue(uint256(sHigh) > HALF_N, "n-1 high-s olmali");

        vm.expectRevert(InvalidSignatureS.selector);
        settlement.recoverSigner(leaf, highS);

        // Aynı r ile low-s: s = (n-1)/2 → s <= n/2 → EIP-2'den GEÇER
        // (imza geçersiz olduğundan address(0) döner; ama InvalidSignatureS
        // REVERT almaz — EIP-2 yalnızca high-s'yi hedefler, dar kapsamlı)
        bytes memory lowS = abi.encodePacked(fixedR, bytes32(HALF_N), uint8(27));
        assertEq(settlement.recoverSigner(leaf, lowS), address(0), "low-s EIP-2'den gecer");
    }

    // ============================================================
    // 4) GERİYE DÖNÜK UYUM — düşük-s imzalar hâlâ çalışır
    // ============================================================

    /// @notice EIP-2 eklenmesi GEÇERLİ (düşük-s) imzaları KIRMAZ. vm.sign,
    ///         Rust k256 ve `cast wallet sign` hep DÜŞÜK-S üretir — yani
    ///         mevcut off-chain imzalayanlar ve eski testler çalışmaya devam
    ///         eder. Bu, 4 yolun da (PoL legacy, PoL domain, Settlement
    ///         legacy, Settlement domain) kanıtıdır.
    /// @dev EĞER eski bir imza high-s olsaydı artık RED alırdı — dürüst
    ///      rapor: testler ve tüm bilinen imzalayanlar düşük-s üretir,
    ///      bu yüzden GERİYE DÖNÜK UYUMLUDUR (breaking change DEĞİL).
    function testValidLowSSignaturesStillWork() public {
        // --- PoL legacy: EIP-191 imzalı fail-closed yayın ---
        address[] memory users = new address[](1);
        users[0] = ANVIL_ADDR;
        uint256[] memory balances = new uint256[](1);
        balances[0] = BALANCE;
        bytes[] memory sigs = new bytes[](1);
        bytes32 legacyLeaf = keccak256(abi.encode(ANVIL_ADDR, BALANCE, 1));
        sigs[0] = _signEip191(legacyLeaf);

        pol.publishLiabilitiesFromSignedLeaves(users, balances, sigs);
        assertEq(pol.currentEpoch(), 1, "legacy PoL yayini basarili");
        assertTrue(pol.epochSignatureEnforced(1), "legacy yol da fail-closed isaretli");

        assertTrue(
            pol.verifyLiability(ANVIL_ADDR, BALANCE, 1, _signEip191(legacyLeaf), ""),
            "PoL legacy EIP-191 dogrulama hala gecerli"
        );

        // --- PoL domain ---
        uint256 epoch = _publishDomainPoL();
        assertTrue(
            pol.verifyLiabilityWithDomain(
                ANVIL_ADDR,
                BALANCE,
                epoch,
                _signDigest(pol.liabilityDomainDigest(ANVIL_ADDR, BALANCE, epoch)),
                ""
            ),
            "PoL EIP-712 domain dogrulama hala gecerli"
        );

        // --- Settlement legacy ---
        bytes32 leaf = settlement.leafHash(AMOUNT, ANVIL_ADDR, NONCE);
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = leaf;

        assertTrue(
            settlement.verifySignedOrder(
                leaf, _signEip191(leaf), ANVIL_ADDR, "", settlement.computeRoot(leaves)
            ),
            "Settlement legacy EIP-191 dogrulama hala gecerli"
        );

        // --- Settlement domain ---
        assertTrue(
            settlement.verifySignedOrderWithDomain(
                AMOUNT,
                ANVIL_ADDR,
                NONCE,
                _signDigest(settlement.orderDomainDigest(AMOUNT, ANVIL_ADDR, NONCE)),
                "",
                settlement.computeRoot(leaves)
            ),
            "Settlement EIP-712 domain dogrulama hala gecerli"
        );
    }

    // ============================================================
    // 5) EIP-712 + LOW-S BİRLİKTE — katmanlı savunma
    // ============================================================

    /// @notice İki kalkan birlikte çalışır: domain-ayrımı VE low-s. Doğru
    ///         domain + düşük-s → GEÇERLİ. Yanlış domain (tahrif edilmiş
    ///         sürüm) + düşük-s → "EIP-712 domain imzasi gecersiz" RED.
    ///         Yanlış domain + malleable (high-s) → InvalidSignatureS RED
    ///         (s-kontrolü ÖNCE fişeğini atar — savunma derinliği).
    function testEip2AndDomainSeparationComposed() public {
        uint256 epoch = _publishDomainPoL();
        bytes32 realDigest = pol.liabilityDomainDigest(ANVIL_ADDR, BALANCE, epoch);
        bytes32 structHash = pol.liabilityLeafStructHash(ANVIL_ADDR, BALANCE, epoch);

        // 1) Doğru domain + düşük-s → GEÇERLİ
        assertTrue(
            pol.verifyLiabilityWithDomain(ANVIL_ADDR, BALANCE, epoch, _signDigest(realDigest), ""),
            "dogru domain + dusuk-s gecerli olmali"
        );

        // 2) Tahrif edilmiş domain (sürüm "2") + düşük-s imza → domain RED
        bytes32 tamperedDomain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("Cleanvest-ProofOfLiabilities")),
                keccak256(bytes("2")), // <-- TAHRİR: sürüm 2
                block.chainid,
                address(pol)
            )
        );
        bytes32 evilDigest = keccak256(abi.encodePacked("\x19\x01", tamperedDomain, structHash));
        vm.expectRevert("EIP-712 domain imzasi gecersiz");
        pol.verifyLiabilityWithDomain(ANVIL_ADDR, BALANCE, epoch, _signDigest(evilDigest), "");

        // 3) Bileşik saldırı: tahrif edilmiş domain + malleable (high-s) →
        //    InvalidSignatureS (low-s kontrolü domain kontrolünden ÖNCE fişeğini atar)
        vm.expectRevert(InvalidSignatureS.selector);
        pol.verifyLiabilityWithDomain(
            ANVIL_ADDR, BALANCE, epoch, _flipToHighS(_signDigest(evilDigest)), ""
        );

        // 4) Doğru domain + malleable → InvalidSignatureS (low-s kalkanı)
        vm.expectRevert(InvalidSignatureS.selector);
        pol.verifyLiabilityWithDomain(
            ANVIL_ADDR, BALANCE, epoch, _flipToHighS(_signDigest(realDigest)), ""
        );
    }
}
