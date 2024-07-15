use starknet::ContractAddress;
use core::poseidon::PoseidonTrait;
use core::hash::{HashStateTrait, HashStateExTrait};
use clober_cairo::libraries::fee_policy::FeePolicy;
use clober_cairo::libraries::hooks::Hooks;

#[derive(Copy, Drop, Hash, Serde)]
pub struct BookKey {
    pub base: ContractAddress,
    pub unit_size: u64,
    pub quote: ContractAddress,
    pub maker_policy: FeePolicy,
    pub hooks: Hooks,
    pub taker_policy: FeePolicy,
}

#[generate_trait]
pub impl BookKeyImpl of BookKeyTrait {
    fn to_id(self: BookKey) -> felt252 {
        let hash = PoseidonTrait::new().update_with(self).finalize();
        // @dev Use 187 bits of the hash as the key.
        (hash.into() & 0x7ffffffffffffffffffffffffffffffffffffffffffffff_u256).try_into().unwrap()
    }
}
