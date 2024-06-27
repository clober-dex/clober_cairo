use core::traits::Into;
use starknet::storage_access::{StorePacking};

const TWO_POW_62: u256 = 0x4000000000000000; // 2**62
const MASK_62: u256 = 0xFFFFFFFFFFFFFFFF; // 2**62 - 1

pub fn get_u62(packed: felt252, mut n: u8) -> u64 {
    assert(n < 4, 'Index out of bounds');
    let mut _packed: u256 = packed.into();
    while n > 0 {
        _packed /= TWO_POW_62;
        n -= 1;
    };
    (_packed & MASK_62).try_into().unwrap()
}

pub fn update_62(packed: felt252, mut n: u8, value: u64) -> felt252 {
    assert(n < 4, 'Index out of bounds');
    let mut _packed: u256 = packed.into();
    let mut data: u256 = value.into();
    let mut mask: u256 = MASK_62;
    while n > 0 {
        data *= TWO_POW_62;
        mask *= TWO_POW_62;
        n -= 1;
    };
    ((_packed & ~mask) + data).try_into().unwrap()
}

pub fn add_u62(packed: felt252, n: u8, value: u64) -> felt252 {
    assert(n < 4, 'Index out of bounds');
    update_62(packed, n, get_u62(packed, n) + value)
}

pub fn sub_u62(packed: felt252, n: u8, value: u64) -> felt252 {
    assert(n < 4, 'Index out of bounds');
    update_62(packed, n, get_u62(packed, n) - value)
}

pub fn sum_u62(packed: felt252, mut s: u8, e: u8) -> u256 {
    assert(e <= 4, 'Index out of bounds');
    let mut packed: u256 = packed.into();
    let mut n: u8 = 0;
    let mut sum: u256 = 0;
    while n < e {
        packed /= TWO_POW_62;
        if n >= s {
            sum += (packed & MASK_62).try_into().unwrap();
        };
        n += 1;
    };
    sum
}
