use starknet::storage_access::{StorePacking};
use starknet::ContractAddress;
use core::poseidon::PoseidonTrait;
use core::hash::{HashStateTrait, HashStateExTrait};
use clober_cairo::libraries::fee_policy::{FeePolicy, FeePolicyTrait};
use clober_cairo::libraries::hooks::Hooks;
use clober_cairo::utils::constants::{TWO_POW_64, TWO_POW_96, TWO_POW_32};

#[derive(Copy, Drop, Hash, Serde)]
pub struct BookKey {
    pub base: ContractAddress,
    pub quote: ContractAddress,
    pub hooks: Hooks,
    pub unit_size: u64,
    pub maker_policy: FeePolicy,
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

pub impl BookKeyStorePacking of StorePacking<BookKey, [felt252; 4]> {
    fn pack(value: BookKey) -> [felt252; 4] {
        let packed: u128 = value.unit_size.into()
            + TWO_POW_64 * value.maker_policy.encode().into()
            + TWO_POW_96.try_into().unwrap() * value.taker_policy.encode().into();
        [value.base.into(), value.quote.into(), value.hooks.into(), packed.into()]
    }

    fn unpack(value: [felt252; 4]) -> BookKey {
        let v = value.span();
        let packed: u256 = (*v[3]).into();
        let unit_size = packed % TWO_POW_64.into();
        let maker_policy = FeePolicyTrait::decode(
            ((packed / TWO_POW_64.into()) % TWO_POW_32.into()).try_into().unwrap(),
        );
        let taker_policy = FeePolicyTrait::decode(
            ((packed / TWO_POW_96) % TWO_POW_32.into()).try_into().unwrap(),
        );

        BookKey {
            base: (*v[0]).try_into().unwrap(),
            quote: (*v[1]).try_into().unwrap(),
            hooks: (*v[2]).try_into().unwrap(),
            unit_size: unit_size.try_into().unwrap(),
            maker_policy,
            taker_policy,
        }
    }
}
