use clober_cairo::utils::constants::{TWO_POW_64, MASK_64};

pub fn get_u64(packed: u256, n: u8) -> u64 {
    assert(n < 4, 'Index out of bounds');
    let mut _packed = packed;
    let mut index = n;
    while index > 0 {
        _packed /= TWO_POW_64.into();
        index -= 1;
    };
    (_packed & MASK_64.into()).try_into().unwrap()
}

pub fn update_64(packed: u256, n: u8, value: u64) -> u256 {
    assert(n < 4, 'Index out of bounds');
    let mut _packed = packed;
    let mut data: u256 = value.into();
    let mut mask: u256 = MASK_64.into();
    let mut index = n;
    while index > 0 {
        data *= TWO_POW_64.into();
        mask *= TWO_POW_64.into();
        index -= 1;
    };
    (packed & ~mask) + data
}

pub fn sub_u64(packed: u256, n: u8, value: u64) -> u256 {
    assert(n < 4, 'Index out of bounds');
    update_64(packed, n, get_u64(packed, n) - value)
}
