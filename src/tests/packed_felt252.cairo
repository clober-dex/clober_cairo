use clober_cairo::libraries::packed_felt252::{get_u62, update_62, add_u62, sub_u62};

#[test]
fn test_get_u62() {
    let packed: felt252 = 0x11111111111111103333333333333330888888888888888111111111111111;
    assert_eq!(get_u62(packed, 0), 0x0111111111111111);
    assert_eq!(get_u62(packed, 1), 0x0222222222222222);
    assert_eq!(get_u62(packed, 2), 0x0333333333333333);
    assert_eq!(get_u62(packed, 3), 0x0444444444444444);
}

#[test]
#[should_panic(expected: ('Index out of bounds',))]
fn test_get_u62_out_of_bounds() {
    let packed = 0x11111111111111103333333333333330888888888888888111111111111111;
    get_u62(packed, 4);
}

#[test]
fn test_update_62() {
    let packed = 0x11111111111111103333333333333330888888888888888111111111111111;
    let mut i = 0;
    while (i < 4) {
        let updated = update_62(packed, i, 0x0123456789ABCDEF);
        let mut j = 0;
        while (j < 4) {
            if (j == i) {
                assert_eq!(get_u62(updated, j), 0x0123456789ABCDEF);
            } else {
                assert_eq!(get_u62(updated, j), get_u62(packed, j));
            }
            j += 1;
        };
        i += 1;
    };
}

#[test]
#[should_panic(expected: ('Index out of bounds',))]
fn test_update_64_out_of_bounds() {
    let packed = 0x11111111111111103333333333333330888888888888888111111111111111;
    update_62(packed, 4, 0x0123456789ABCDEF);
}

#[test]
fn test_add_u62() {
    let packed = 0x11111111111111103333333333333330888888888888888111111111111111;
    let base_hex = 0x0111111111111111;
    let mut i = 0;
    while (i < 4) {
        let updated = add_u62(packed, i, base_hex);
        let mut j = 0;
        while (j < 4) {
            if (j == i) {
                assert_eq!(get_u62(updated, j), base_hex * (i + 2).into());
            } else {
                assert_eq!(get_u62(updated, j), get_u62(packed, j));
            }
            j += 1;
        };
        i += 1;
    };
}

#[test]
#[should_panic(expected: ('Index out of bounds',))]
fn test_add_u62_out_of_bounds() {
    let packed = 0x11111111111111103333333333333330888888888888888111111111111111;
    add_u62(packed, 4, 0x1111111111111111);
}

#[test]
#[should_panic(expected: ('u64_add Overflow',))]
fn add_u62_overflow() {
    let packed = 0x11111111111111103333333333333330888888888888888111111111111111;
    add_u62(packed, 0, 0xffffffffffffffff);
}

#[test]
fn test_sub_u62() {
    let packed = 0x11111111111111103333333333333330888888888888888111111111111111;
    let base_hex = 0x0111111111111111;
    let mut i = 0;
    while (i < 4) {
        let updated = sub_u62(packed, i, base_hex * i.into());
        let mut j = 0;
        while (j < 4) {
            if (j == i) {
                assert_eq!(get_u62(updated, j), base_hex);
            } else {
                assert_eq!(get_u62(updated, j), get_u62(packed, j));
            }
            j += 1;
        };
        i += 1;
    };
}

#[test]
#[should_panic(expected: ('Index out of bounds',))]
fn test_sub_u62_out_of_bounds() {
    let packed = 0x11111111111111103333333333333330888888888888888111111111111111;
    sub_u62(packed, 4, 0x1111111111111111);
}

#[test]
#[should_panic(expected: ('u64_sub Overflow',))]
fn sub_u62_overflow() {
    let packed = 0x11111111111111103333333333333330888888888888888111111111111111;
    sub_u62(packed, 0, 0x0111111111111112);
}
