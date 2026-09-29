# Cleanvest — tek komutla is akislari
#
# Kullanim:
#   make test          # 239 forge + 19 Rust testi
#   make deploy-anvil  # yerel anvil'e deploy (anahtar GEREKMEZ)
#   make deploy-dry    # gas tahmini, broadcast YOK
#   make deploy-live   # CANLI ag (PRIVATE_KEY + DEPLOY_CONFIRM zorunlu)
#   make verify        # son deploy'u etherscan'da dogrula
#
# ARAclar:  export PATH="$HOME/.foundry/bin:$PATH"

FOUNDRY ?= $(HOME)/.foundry/bin
FORGE   := $(FOUNDRY)/forge
CAST    := $(FOUNDRY)/cast
ANVIL   := $(FOUNDRY)/anvil
CARGO   ?= cargo

ANVIL_RPC ?= http://127.0.0.1:8545
DEPLOY_SCRIPT := script/Deploy.s.sol:Deploy

# Varsayilan: durum ozeti
.PHONY: all
all:
	@echo "Cleanvest — komutlar:"
	@echo "  make test          239 forge + 19 Rust testi"
	@echo "  make anvil         yerel anvil baslat"
	@echo "  make deploy-anvil  anvil'e deploy (anahtar GEREKMEZ)"
	@echo "  make deploy-dry    gas tahmini (broadcast YOK)"
	@echo "  make deploy-live   CANLI ag (PRIVATE_KEY + DEPLOY_CONFIRM)"
	@echo "  make verify        etherscan dogrulama"
	@echo "  make proof         bagimsiz kanit CLI'ini derle"

# -----------------------------------------------------------
# TEST — 239 forge + 19 Rust (0 failed beklenir)
# -----------------------------------------------------------
.PHONY: test
test: test-forge test-rust
	@echo "=== TUM TESTLER YESIL (forge + rust) ==="

.PHONY: test-forge
test-forge:
	@echo "=== forge test (239 bekleniyor) ==="
	@$(FORGE) test

.PHONY: test-rust
test-rust:
	@echo "=== cargo test (19 bekleniyor) ==="
	@$(CARGO) test

# -----------------------------------------------------------
# ANVIL — yerel test zinciri
# -----------------------------------------------------------
.PHONY: anvil
anvil:
	@echo "Anvil baslatildi (chainId 31337) — http://127.0.0.1:8545"
	@$(ANVIL) --host 127.0.0.1 --port 8545

# -----------------------------------------------------------
# DEPLOY
# -----------------------------------------------------------

# Yerel anvil: PRIVATE_KEY GEREKMEZ (anvil test anahtari kullanilir)
.PHONY: deploy-anvil
deploy-anvil:
	@echo "=== DEPLOY: anvil (yerel, anahtar GEREKMEZ) ==="
	@mkdir -p deploy-out
	@$(FORGE) script $(DEPLOY_SCRIPT) --rpc-url $(ANVIL_RPC) --broadcast
	@echo "Adresler: deploy-out/addresses.json"

# Dry-run: gas tahmini. Broadcast YOK, anahtar YOK, zincir baglantisi YOK
.PHONY: deploy-dry
deploy-dry:
	@echo "=== DRY-RUN: gas tahmini (broadcast YOK) ==="
	@$(FORGE) script $(DEPLOY_SCRIPT)

# CANLI ag: PRIVATE_KEY + DEPLOY_CONFIRM=yes ZORUNLU
# mainnet guard script icinde: eksikse REDDER
.PHONY: deploy-live
deploy-live:
	@echo "=== CANLI DEPLOY — insan karari gerekiyor ==="
	@test -n "$${PRIVATE_KEY}" || { echo "HATA: PRIVATE_KEY ayarli degil"; exit 1; }
	@test "$${DEPLOY_CONFIRM}" = "yes" || { echo "HATA: DEPLOY_CONFIRM=yes gerekli (insan onayi)"; exit 1; }
	@test -n "$${RPC_URL}" || { echo "HATA: RPC_URL ayarli degil"; exit 1; }
	@echo " chainId kontrol ediliyor..."
	@$(CAST) chain-id --rpc-url "$${RPC_URL}"
	@mkdir -p deploy-out
	@$(FORGE) script $(DEPLOY_SCRIPT) --rpc-url "$${RPC_URL}" \
		--private-key "$${PRIVATE_KEY}" --broadcast $(VERIFY_FLAG)

# -----------------------------------------------------------
# VERIFY — etherscan otomatik dogrulama
# -----------------------------------------------------------
.PHONY: verify
verify:
	@test -n "$${ETHERSCAN_API_KEY}" || { echo "HATA: ETHERSCAN_API_KEY ayarli degil"; exit 1; }
	@test -n "$${RPC_URL}" || { echo "HATA: RPC_URL ayarli degil"; exit 1; }
	@$(FORGE) script $(DEPLOY_SCRIPT) --rpc-url "$${RPC_URL}" \
		--private-key "$${PRIVATE_KEY}" --resume --verify \
		--etherscan-api-key "$${ETHERSCAN_API_KEY}"

# -----------------------------------------------------------
# KANIT CLI — bagimsiz Merkle/imza dogrulayici
# -----------------------------------------------------------
.PHONY: proof
proof:
	@cd merkle && $(CARGO) build --release --example verify_cli 2>/dev/null || \
		{ echo "verify_cli ornegi bulunamadi - merkle/examples/ altinda"; exit 1; }
	@echo "Kullanim: merkle/target/release/examples/verify_cli proof.json"

clean:
	@$(FORGE) clean
	@cd merkle && $(CARGO) clean
	@rm -rf deploy-out
