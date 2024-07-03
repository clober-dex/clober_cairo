use starknet::ContractAddress;
use starknet::contract_address_const;

pub(crate) const TWO_POW_248: u256 =
    0x100000000000000000000000000000000000000000000000000000000000000; // 2**248
pub(crate) const TWO_POW_192: u256 = 0x1000000000000000000000000000000000000000000000000; // 2**192
pub(crate) const TWO_POW_128: u256 = 0x100000000000000000000000000000000; // 2**128
pub(crate) const TWO_POW_96: u128 = 0x1000000000000000000000000; // 2**96
pub(crate) const TWO_POW_64: u128 = 0x10000000000000000; // 2**64
pub(crate) const TWO_POW_62: u64 = 0x4000000000000000; // 2**62
pub(crate) const TWO_POW_40: u64 = 0x10000000000; // 2**40
pub(crate) const TWO_POW_24: u32 = 0x1000000; // 2**24
pub(crate) const TWO_POW_16: u32 = 0x10000; // 2**24

pub(crate) const MASK_64: u64 = 0xFFFFFFFFFFFFFFFF; // 2**64 - 1
pub(crate) const MASK_62: u64 = 0x3fffffffffffffff; // 2**62 - 1

pub(crate) const RATE_PRECISION: u32 = 1000000;

pub(crate) const MAX_TICK: i32 = 0x7ffff;
pub(crate) const MIN_TICK: i32 = -MAX_TICK;

pub(crate) fn ZERO_ADDRESS() -> ContractAddress {
    contract_address_const::<0>()
}
