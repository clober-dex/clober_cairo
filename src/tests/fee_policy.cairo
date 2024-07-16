use clober_cairo::libraries::fee_policy::{FeePolicy, FeePolicyTrait};
use clober_cairo::libraries::i257::i257;
use starknet::storage_access::{StorePacking};

#[test]
fn encode() {
    let fee_policy: FeePolicy = FeePolicy { uses_quote: true, rate: -100000, };
    let packed: u32 = fee_policy.encode();
    assert_eq!(packed, 8788608);

    let fee_policy: FeePolicy = FeePolicy { uses_quote: true, rate: 100000, };
    let packed: u32 = fee_policy.encode();
    assert_eq!(packed, 8988608);

    let fee_policy: FeePolicy = FeePolicy { uses_quote: false, rate: -100000, };
    let packed: u32 = fee_policy.encode();
    assert_eq!(packed, 400000);

    let fee_policy: FeePolicy = FeePolicy { uses_quote: false, rate: 100000, };
    let packed: u32 = fee_policy.encode();
    assert_eq!(packed, 600000);

    let fee_policy: FeePolicy = FeePolicy { uses_quote: false, rate: 0, };
    let packed: u32 = fee_policy.encode();
    assert_eq!(packed, 500000);
}

#[test]
fn decode() {
    let fee_policy: FeePolicy = FeePolicyTrait::decode(8788608);
    assert_eq!(fee_policy.uses_quote, true);
    assert_eq!(fee_policy.rate, -100000);

    let fee_policy: FeePolicy = FeePolicyTrait::decode(8988608);
    assert_eq!(fee_policy.uses_quote, true);
    assert_eq!(fee_policy.rate, 100000);

    let fee_policy: FeePolicy = FeePolicyTrait::decode(400000);
    assert_eq!(fee_policy.uses_quote, false);
    assert_eq!(fee_policy.rate, -100000);

    let fee_policy: FeePolicy = FeePolicyTrait::decode(600000);
    assert_eq!(fee_policy.uses_quote, false);
    assert_eq!(fee_policy.rate, 100000);

    let fee_policy: FeePolicy = FeePolicyTrait::decode(500000);
    assert_eq!(fee_policy.uses_quote, false);
    assert_eq!(fee_policy.rate, 0);
}

#[test]
fn calculate_fee() {
    _calculate_fee(1000, 1000000, false, 1000);
    _calculate_fee(-1000, 1000000, false, -1000);
    _calculate_fee(1000, 1000000, true, 1000);
    _calculate_fee(-1000, 1000000, true, -1000);
    // zero value tests
    _calculate_fee(0, 1000000, false, 0);
    _calculate_fee(1000, 0, false, 0);
    // rounding tests
    _calculate_fee(1500, 1000, false, 2);
    _calculate_fee(-1500, 1000, false, -1);
    _calculate_fee(1500, 1000, true, 1);
    _calculate_fee(-1500, 1000, true, -2);
}

fn _calculate_fee(rate: i32, amount: u256, reverse_rounding: bool, expected: i128) {
    let fee_policy: FeePolicy = FeePolicy { uses_quote: true, rate: rate, };
    let result = fee_policy.calculate_fee(amount, reverse_rounding);
    assert_eq!(result.try_into().unwrap(), expected);
}
