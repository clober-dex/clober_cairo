use starknet::ContractAddress;
use core::poseidon::PoseidonTrait;
use core::hash::{HashStateTrait, HashStateExTrait};
use clober_cairo::libraries::fee_policy::FeePolicy;
use clober_cairo::libraries::hooks::Hooks;

#[derive(Copy, Drop, Hash, Serde)]
pub struct BookKey {
    pub base: ContractAddress,
    pub unit_size: u64,
    pub qutoe: ContractAddress,
    pub maker_policy: FeePolicy,
    pub hooks: Hooks,
    pub taker_policy: FeePolicy,
}

#[generate_trait]
impl BookKeyImpl of BookKeyTrait {
    fn to_id(key: @BookKey) -> felt252 {
        let hash = PoseidonTrait::new().update_with(*key).finalize();
        // @dev Use 187 bits of the hash as the key.
        (hash.into() & 0x7ffffffffffffffffffffffffffffffffffffffffffffff_u256).try_into().unwrap()
    }
}
