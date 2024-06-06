use starknet::storage_access::{StorePacking};
use clober_cairo::utils::math::{divide};

const MAX_FEE_RATE: u32 = 500000;
const RATE_PRECISION: u32 = 1000000;

#[derive(Copy, Drop, Serde, Debug)]
pub struct FeePolicy {
    pub uses_quote: bool,
    pub sign: bool,
    pub rate: u32,
}

#[generate_trait]
impl FeePolicy of FeePolicyTrait {
    fn calculate_fee(self: FeePolicy, amount: felt252, reverse_rounding: bool) -> (bool, felt252) {
        let rounding_up: bool = if (reverse_rounding) {
            self.sign
        } else {
            !self.sign
        };
        let absFee: felt252 = divide(amount * self.rate, RATE_PRECISION, rounding_up);
        (self.sign, absFee)
    }

    fn calculate_original_amount(self: FeePolicy, amount: felt252, reverse_fee: bool) -> felt252 {
        let divider: felt252 = if (self.sign ^ reverse_fee) {
            RATE_PRECISION - self.rate
        } else {
            RATE_PRECISION + self.rate
        };

        originalAmount = divide(amount * RATE_PRECISION, divider, !self.sign);
    }
}

impl FeePolicyStorePacking of StorePacking<FeePolicy, u32> {
    fn pack(value: FeePolicy) -> u32 {
        assert(value.rate < MAX_FEE_RATE, 'invalid_fee_rate');
        let mask: u32 = if (usesQuote_) {
            0x800000
        } else {
            0
        };
        let rate: u32 = if (value.sign) {
            -value.rate
        } else {
            value.rate
        };
        rate = (rate & 0xffffff) + MAX_FEE_RATE;
        mask | rate
    }

    fn unpack(value: u32) -> FeePolicy {
        let uses_quote: bool = value & 0x800000 != 0;
        let rate: u32 = value & 0x7fffff;
        if (rate >= MAX_FEE_RATE) {
            FeePolicy { uses_quote, sign: false, rate: rate - MAX_FEE_RATE }
        } else {
            FeePolicy { uses_quote, sign: true, rate }
        }
    }
}
