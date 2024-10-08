use clober_cairo::utils::math::{least_significant_bit, fast_power};

#[test]
fn test_least_significant_bit() {
    let mut i: u256 = 0;
    while i < 256 {
        assert_eq!(least_significant_bit(fast_power(2_u256, i)), i.try_into().unwrap());
        i += 1;
    }
}
