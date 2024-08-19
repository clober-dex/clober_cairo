use starknet::storage_access::{StorePacking};
use clober_cairo::utils::math::{divide};
use clober_cairo::utils::constants::{RATE_PRECISION};
use clober_cairo::libraries::i257::i257;

const MAX_FEE_RATE: i32 = 500000;
const MIN_FEE_RATE: i32 = -500000;

#[derive(Copy, Drop, Serde, Debug, Hash)]
pub struct FeePolicy {
    pub uses_quote: bool,
    pub rate: i32,
}

#[generate_trait]
pub impl FeePolicyImpl of FeePolicyTrait {
    fn is_valid(self: FeePolicy) -> bool {
        self.rate >= MIN_FEE_RATE && self.rate <= MAX_FEE_RATE
    }

    fn calculate_fee(self: FeePolicy, amount: u256, reverse_rounding: bool) -> i257 {
        let is_positive = self.rate > 0;
        let abs_rate: u32 = if (is_positive) {
            self.rate.try_into().unwrap()
        } else {
            (-self.rate).try_into().unwrap()
        };
        let rounding_up: bool = if (reverse_rounding) {
            !is_positive
        } else {
            is_positive
        };
        let abs_fee: i257 = divide(amount * abs_rate.into(), RATE_PRECISION.into(), rounding_up)
            .into();
        if (is_positive) {
            abs_fee
        } else {
            -abs_fee
        }
    }

    fn calculate_original_amount(self: FeePolicy, amount: u256, reverse_fee: bool) -> u256 {
        let mut rate = self.rate;
        let positive = rate > 0;
        if (reverse_fee) {
            rate = -rate;
        }
        let divider: u32 = (RATE_PRECISION.try_into().unwrap() + rate).try_into().unwrap();

        divide(amount * RATE_PRECISION.into(), divider.into(), positive)
    }

    fn encode(self: FeePolicy) -> u32 {
        assert(self.rate < MAX_FEE_RATE, 'invalid_fee_rate');
        let mask: u32 = if (self.uses_quote) {
            0x800000
        } else {
            0
        };
        let rate: u32 = (MAX_FEE_RATE + self.rate).try_into().unwrap();
        mask | rate
    }

    fn decode(self: u32) -> FeePolicy {
        let uses_quote: bool = self & 0x800000 != 0;
        let rate: u32 = self & 0x7fffff;
        let max_u32: u32 = MAX_FEE_RATE.try_into().unwrap();

        if (rate < max_u32) {
            FeePolicy { uses_quote, rate: -(max_u32 - rate).try_into().unwrap(), }
        } else {
            FeePolicy { uses_quote, rate: (rate - max_u32).try_into().unwrap(), }
        }
    }
}
