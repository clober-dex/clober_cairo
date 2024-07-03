use clober_cairo::libraries::fee_policy::FeePolicy;
use clober_cairo::libraries::fee_policy::FeePolicyImpl;
use starknet::storage_access::{StorePacking};

#[test]
fn pack() {
    let fee_policy: FeePolicy = FeePolicy { uses_quote: true, sign: true, rate: 100000, };
    let packed: u32 = StorePacking::pack(fee_policy);
    assert_eq!(packed, 8788608);

    let fee_policy: FeePolicy = FeePolicy { uses_quote: true, sign: false, rate: 100000, };
    let packed: u32 = StorePacking::pack(fee_policy);
    assert_eq!(packed, 8988608);

    let fee_policy: FeePolicy = FeePolicy { uses_quote: false, sign: true, rate: 100000, };
    let packed: u32 = StorePacking::pack(fee_policy);
    assert_eq!(packed, 400000);

    let fee_policy: FeePolicy = FeePolicy { uses_quote: false, sign: false, rate: 100000, };
    let packed: u32 = StorePacking::pack(fee_policy);
    assert_eq!(packed, 600000);

    let fee_policy: FeePolicy = FeePolicy { uses_quote: false, sign: false, rate: 0, };
    let packed: u32 = StorePacking::pack(fee_policy);
    assert_eq!(packed, 500000);
}

#[test]
fn unpack() {
    let fee_policy: FeePolicy = StorePacking::unpack(8788608);
    assert_eq!(fee_policy.uses_quote, true);
    assert_eq!(fee_policy.sign, true);
    assert_eq!(fee_policy.rate, 100000);

    let fee_policy: FeePolicy = StorePacking::unpack(8988608);
    assert_eq!(fee_policy.uses_quote, true);
    assert_eq!(fee_policy.sign, false);
    assert_eq!(fee_policy.rate, 100000);

    let fee_policy: FeePolicy = StorePacking::unpack(400000);
    assert_eq!(fee_policy.uses_quote, false);
    assert_eq!(fee_policy.sign, true);
    assert_eq!(fee_policy.rate, 100000);

    let fee_policy: FeePolicy = StorePacking::unpack(600000);
    assert_eq!(fee_policy.uses_quote, false);
    assert_eq!(fee_policy.sign, false);
    assert_eq!(fee_policy.rate, 100000);

    let fee_policy: FeePolicy = StorePacking::unpack(500000);
    assert_eq!(fee_policy.uses_quote, false);
    assert_eq!(fee_policy.sign, false);
    assert_eq!(fee_policy.rate, 0);
}

#[test]
fn calculate_fee() {
    _calculate_fee((false, 1000), 1000000, false, (false, 1000));
    _calculate_fee((true, 1000), 1000000, false, (true, 1000));
    _calculate_fee((false, 1000), 1000000, true, (false, 1000));
    _calculate_fee((true, 1000), 1000000, true, (true, 1000));
    // zero value tests
    _calculate_fee((false, 0), 1000000, false, (false, 0));
    _calculate_fee((false, 1000), 0, false, (false, 0));
    // rounding tests
    _calculate_fee((false, 1500), 1000, false, (false, 2));
    _calculate_fee((true, 1500), 1000, false, (true, 1));
    _calculate_fee((false, 1500), 1000, true, (false, 1));
    _calculate_fee((true, 1500), 1000, true, (true, 2));
}

fn _calculate_fee(rate: (bool, u32), amount: u256, reverse_rounding: bool, expected: (bool, u256)) {
    let (s, r) = rate;
    let fee_policy: FeePolicy = FeePolicy { uses_quote: true, sign: s, rate: r, };
    let result = fee_policy.calculate_fee(amount, reverse_rounding);
    assert_eq!(result, expected);
}
