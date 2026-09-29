#!/usr/bin/env bash
# =============================================================================
# Cleanvest — Bagimsiz Kanit Zinciri Demo (uclu capraz-dogrulama)
#
# Bu script, "sifir manipülasyon" iddiasinin DOGRULANABILIR kismini
# uc bagimsiz uygulama uzerinden gosterir:
#
#   1. Foundry cast (C++ implementationu) — emirleri EIP-191 ile imzalar
#   2. Rust (tiny-keccak + k256) — Merkle agacini kurar ve kaniti dogrular
#   3. Solidity (anvil uzerinde) — ayni kanit baytlarini zincir-ustu dogrular
#
# Uclu sonuc OZDESTE olmalidir. Herhangi bir uyumsuzluk manipülasyondur.
#
# Kullanim:
#   export PATH="$HOME/.foundry/bin:$PATH"
#   bash scripts/proof_demo.sh
#
# Onkosul: anvil (127.0.0.1:8545) ve deploy edilmis CleanvestSettlement.
#          Yoksa script anvil baslatip deploy eder.
# =============================================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

RPC="${RPC:-http://127.0.0.1:8545}"

# Anvil'in herkesçe bilinen test anahtari (account #0). MAINNET anahtari DEGIL.
USER=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
PK=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

echo "==================================================================="
echo " Cleanvest — Bagimsiz Kanit Zinciri (cast / Rust / Solidity)"
echo "==================================================================="
echo ""

# ---------------------------------------------------------------------------
# 0. Anvil + deploy (gerekirse)
# ---------------------------------------------------------------------------
if ! cast chain-id --rpc-url "$RPC" >/dev/null 2>&1; then
    echo "[0] Anvil baslatiliyor..."
    anvil --host 127.0.0.1 --port 8545 --silent &
    ANVIL_PID=$!
    trap 'kill $ANVIL_PID 2>/dev/null || true' EXIT
    sleep 2
fi
echo "[0] chainId: $(cast chain-id --rpc-url "$RPC")"

SETTLEMENT=$(jq -r '.CleanvestSettlement' deploy-out/addresses.json 2>/dev/null || echo "")

# Adresin gercekten bu anvil'de kodu var mi? (anvil yeniden basladiysa adres eski)
has_code() {
    [ -n "$1" ] && [ "$1" != "null" ] \
        && [ "$(cast code "$1" --rpc-url "$RPC" 2>/dev/null | wc -c)" -gt 10 ]
}

if ! has_code "$SETTLEMENT"; then
    echo "[0] Settlement bu anvil'de yok — tum stack deploy ediliyor..."
    rm -f deploy-out/addresses.json
    mkdir -p deploy-out
    if ! forge script script/Deploy.s.sol:Deploy --rpc-url "$RPC" --broadcast >/dev/null 2>&1; then
        echo "    DEPLOY BASARISIZ"; exit 1
    fi
    SETTLEMENT=$(jq -r '.CleanvestSettlement' deploy-out/addresses.json)
fi
if ! has_code "$SETTLEMENT"; then
    echo "[0] HATA: settlement kodu yok ($SETTLEMENT)"; exit 1
fi
echo "[0] CleanvestSettlement: $SETTLEMENT"
echo ""

# ---------------------------------------------------------------------------
# 1. Emirleri cast ile imzala (BAGIMSIZ implementasyon)
# ---------------------------------------------------------------------------
echo "[1] Emirler cast (C++) ile EIP-191 imzalaniyor..."
sign_order() { # amount nonce
    local leaf
    leaf=$(cast abi-encode "f(uint256,address,uint256)" "$1" "$USER" "$2" | cast keccak)
    cast wallet sign --private-key "$PK" "$leaf"
}

ORDERS="orders.json"
{
    echo "["
    echo "  {\"amount\":\"1000\",\"user\":\"$USER\",\"nonce\":\"1\",\"signature\":\"$(sign_order 1000 1)\"},"
    echo "  {\"amount\":\"2000\",\"user\":\"$USER\",\"nonce\":\"2\",\"signature\":\"$(sign_order 2000 2)\"},"
    echo "  {\"amount\":\"3500\",\"user\":\"$USER\",\"nonce\":\"3\",\"signature\":\"$(sign_order 3500 3)\"}"
    echo "]"
} > "$ORDERS"
echo "    -> $ORDERS (3 imzali emir)"
echo ""

# ---------------------------------------------------------------------------
# 2. Rust ile Merkle agaci kur + kanit uret
# ---------------------------------------------------------------------------
echo "[2] Rust: imzali Merkle agaci kuruluyor (tum imzalar dogrulanir)..."
cargo run --quiet --release --features proof --example prove_cli -- \
    --orders "$ORDERS" --index 1 --out proof.json --chain-id 31337 \
    --settlement "$SETTLEMENT" 2>/dev/null | sed 's/^/    /'
echo ""

RUST_ROOT=$(jq -r '.root' proof.json)
LEAF=$(jq -r '.order | .amount' proof.json | head -1 >/dev/null; echo "")
echo "    Rust koku: $RUST_ROOT"
echo ""

# ---------------------------------------------------------------------------
# 3. Rust ile BAGIMSIZ dogrula (ag baglantisi YOK)
# ---------------------------------------------------------------------------
echo "[3] Rust verify_cli: kanit bagimsiz dogrulaniyor (offline)..."
if cargo run --quiet --release --features proof --example verify_cli -- proof.json 2>/dev/null \
    | grep -q "KANIT GECTI"; then
    echo "    -> [GECTI] kullanici imzasi -> yaprak -> kok zinciri dogrulandi"
else
    echo "    -> [BASARISIZ] Rust dogrulamadi"; exit 1
fi
echo ""

# ---------------------------------------------------------------------------
# 4. Solidity ile zincir-ustu dogrula (ayni kanit baytlari)
# ---------------------------------------------------------------------------
echo "[4] Solidity: ayni kanit baytlari zincir-ustu dogrulaniyor..."
PROOF_BYTES=$(jq -r '.proof_bytes' proof.json)
SIG=$(jq -r '.signature' proof.json)
# Yaprak hash'i emir alanlarindan YENIDEN hesapla (amount, user, nonce)
AMOUNT=$(jq -r '.order.amount' proof.json)
NONCE=$(jq -r '.order.nonce' proof.json)
LEAF=$(cast abi-encode "f(uint256,address,uint256)" "$AMOUNT" "$USER" "$NONCE" | cast keccak)

ONCHAIN_OK=$(cast call "$SETTLEMENT" \
    "verifySignedOrder(bytes32,bytes,address,bytes,bytes32)(bool)" \
    "$LEAF" "$SIG" "$USER" "$PROOF_BYTES" "$RUST_ROOT" --rpc-url "$RPC")
echo "    verifySignedOrder (zincir-ustu) = $ONCHAIN_OK"

# Solidity kendi bagimsiz kokunu hesapla ve Rust ile karsilastir
L1=$(cast abi-encode "f(uint256,address,uint256)" 1000 "$USER" 1 | cast keccak)
L2=$(cast abi-encode "f(uint256,address,uint256)" 2000 "$USER" 2 | cast keccak)
L3=$(cast abi-encode "f(uint256,address,uint256)" 3500 "$USER" 3 | cast keccak)
SOL_ROOT=$(cast call "$SETTLEMENT" "computeRoot(bytes32[])(bytes32)" "[$L1,$L2,$L3]" --rpc-url "$RPC")
echo "    Solidity koku                          = $SOL_ROOT"
echo "    Rust koku                              = $RUST_ROOT"
echo ""

# ---------------------------------------------------------------------------
# 5. Uclu karsilastirma
# ---------------------------------------------------------------------------
echo "[5] UCLU CAPRAZ-DOGRULAMA SONUCU"
echo "-------------------------------------------------------------------"
if [ "$SOL_ROOT" = "$RUST_ROOT" ] && [ "$ONCHAIN_OK" = "true" ]; then
    echo "  [OZDES] cast imza  ==  Rust koku  ==  Solidity koku"
    echo "  [OZDES] Rust verify  ==  Solidity verifySignedOrder"
    echo ""
    echo "  Kanit zinciri UC bagimsiz uygulama tarafindan dogrulandi:"
    echo "    1. EIP-191 imza (cast ile uretilen, Rust ve Solidite ile dogrulanan)"
    echo "    2. Merkle inclusion (ayni proof_bytes, Rust ve Solidite ile)"
    echo "    3. Kok (Rust uretti, Solidity bagimsiz olarak yeniden hesapladi)"
    echo ""
    echo "  Bu kanit OPERATORE GUVENMEDEN herkes tarafindan yeniden uretilebilir."
    echo "  Bir uyumsuzluk, manipülasyon kaniti olurdu."
    echo "-------------------------------------------------------------------"
    exit 0
else
    echo "  [UYUMSUZLUK] capraz-dogrulama BASARISIZ — arastirin!"
    echo "-------------------------------------------------------------------"
    exit 1
fi
