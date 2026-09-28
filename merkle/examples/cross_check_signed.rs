//! İMZALI çapraz doğrulama: Rust imzası Solidity ecrecover ile uyumlu mu?
use cleanvest_merkle::signed::*;
use cleanvest_merkle::{Order, keccak256};
use k256::ecdsa::SigningKey;

const ANVIL_KEY: [u8; 32] = [
    0xac, 0x09, 0x74, 0xbe, 0xc3, 0x9a, 0x17, 0xe3,
    0x6b, 0xa4, 0xa6, 0xb4, 0xd2, 0x38, 0xff, 0x94,
    0x4b, 0xac, 0xb4, 0x78, 0xcb, 0xed, 0x5e, 0xfc,
    0xae, 0x78, 0x4d, 0x7b, 0xf4, 0xf2, 0xff, 0x80,
];
const ANVIL_ADDR: [u8; 20] = [
    0xf3, 0x9F, 0xd6, 0xe5, 0x1a, 0xad, 0x88, 0xF6,
    0xF4, 0xce, 0x6a, 0xB8, 0x82, 0x72, 0x79, 0xcf,
    0xFF, 0xb9, 0x22, 0x66,
];

fn main() {
    // test/SignedMerkle.t.sol::testVerifySignedOrderValid ile AYNI emir
    let order = Order::new(1000, ANVIL_ADDR, 1);
    let leaf = order.leaf_hash();
    println!("leaf       = 0x{}", hex::encode(leaf));

    let digest = eth_signed_message_hash(&leaf);
    println!("eip191     = 0x{}", hex::encode(digest));

    // Rust imzasi (Solidity vm.sign ile KARSILASTIRILACAK)
    let sk = SigningKey::from_slice(&ANVIL_KEY).unwrap();
    let (sig, recid) = sk.sign_prehash_recoverable(&digest);
    let mut sig65 = [0u8; 65];
    let sb = sig.to_bytes();
    sig65[..32].copy_from_slice(&sb[..32]);
    sig65[32..64].copy_from_slice(&sb[32..]);
    sig65[64] = 27 + u8::from(recid);
    println!("signature  = 0x{}", hex::encode(sig65));

    // Rust geri kazanimi
    let recovered = recover_signer(&leaf, &sig65).unwrap();
    println!("recovered  = 0x{}", hex::encode(recovered));
    println!("rust_ok    = {}", recovered == ANVIL_ADDR);

    // Imzali agac + tam kanit
    let signed_leaf = SignedLeaf::new(order, sig65);
    let tree = SignedMerkleTree::build_signed(&[signed_leaf]).unwrap();
    println!("root       = 0x{}", hex::encode(tree.root()));
}
