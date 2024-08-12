use clober_cairo::utils::constants::{TWO_POW_62, MASK_62};

pub fn get_u62(packed: felt252, mut n: u8) -> u64 {
    assert(n < 4, 'Index out of bounds');
    let mut _packed: u256 = packed.into();
    while n > 0 {
        _packed /= TWO_POW_62.into();
        n -= 1;
    };
    (_packed & MASK_62.into()).try_into().unwrap()
}

pub fn update_62(packed: felt252, mut n: u8, value: u64) -> felt252 {
    assert(value < TWO_POW_62, 'Invalid value');
    assert(n < 4, 'Index out of bounds');
    let mut _packed: u256 = packed.into();
    let mut data: u256 = value.into();
    let mut mask: u256 = MASK_62.into();
    while n > 0 {
        data *= TWO_POW_62.into();
        mask *= TWO_POW_62.into();
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

pub fn sum_u62(packed: felt252, mut s: u8, e: u8) -> u64 {
    assert(e <= 4, 'Index out of bounds');
    let mut packed: u256 = packed.into();
    let mut n: u8 = 0;
    let mut sum: u64 = 0;
    while n < e {
        if n >= s {
            sum += (packed & MASK_62.into()).try_into().unwrap();
        };
        packed /= TWO_POW_62.into();
        n += 1;
    };
    sum
}
