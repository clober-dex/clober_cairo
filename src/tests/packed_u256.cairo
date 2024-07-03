use clober_cairo::libraries::packed_u256::{get_u64, update_64, sub_u64};

#[test]
fn test_get_u64() {
    let packed: u256 = 0x4444444444444444333333333333333322222222222222221111111111111111;
    assert_eq!(get_u64(packed, 0), 0x1111111111111111);
    assert_eq!(get_u64(packed, 1), 0x2222222222222222);
    assert_eq!(get_u64(packed, 2), 0x3333333333333333);
    assert_eq!(get_u64(packed, 3), 0x4444444444444444);
}

#[test]
#[should_panic(expected: ('Index out of bounds',))]
fn test_get_u64_out_of_bounds() {
    let packed = 0x4444444444444444333333333333333322222222222222221111111111111111;
    get_u64(packed, 4);
}

#[test]
fn test_update_64() {
    let packed = 0x4444444444444444333333333333333322222222222222221111111111111111;
    let mut i = 0;
    while (i < 4) {
        let updated = update_64(packed, i, 0x123456789ABCDEF0);
        let mut j = 0;
        while (j < 4) {
            if (j == i) {
                assert_eq!(get_u64(updated, j), 0x123456789ABCDEF0);
            } else {
                assert_eq!(get_u64(updated, j), get_u64(packed, j));
            }
            j += 1;
        };
        i += 1;
    };
}

#[test]
#[should_panic(expected: ('Index out of bounds',))]
fn test_update_64_out_of_bounds() {
    let packed = 0x4444444444444444333333333333333322222222222222221111111111111111;
    update_64(packed, 4, 0x123456789ABCDEF0);
}

#[test]
fn test_sub_u64() {
    let packed = 0x4444444444444444333333333333333322222222222222221111111111111111;
    let base_hex = 0x1111111111111111;
    let mut i = 0;
    while (i < 4) {
        let updated = sub_u64(packed, i, base_hex * i.into());
        let mut j = 0;
        while (j < 4) {
            if (j == i) {
                assert_eq!(get_u64(updated, j), base_hex);
            } else {
                assert_eq!(get_u64(updated, j), get_u64(packed, j));
            }
            j += 1;
        };
        i += 1;
    };
}

#[test]
#[should_panic(expected: ('Index out of bounds',))]
fn test_sub_u64_out_of_bounds() {
    let packed = 0x4444444444444444333333333333333322222222222222221111111111111111;
    sub_u64(packed, 4, 0x1111111111111111);
}

#[test]
#[should_panic(expected: ('u64_sub Overflow',))]
fn sub_u64_overflow() {
    let packed = 0x4444444444444444333333333333333322222222222222221111111111111111;
    sub_u64(packed, 0, 0x1111111111111112);
}
