use starknet::storage_access::{StorePacking};
use clober_cairo::utils::math::{Math};
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
        let absFee: u256 = Math::divide(
            amount * abs_rate.into(), RATE_PRECISION.into(), rounding_up
        );
        let absFee_i257: i257 = absFee.try_into().unwrap();
        if (is_positive) {
            absFee_i257
        } else {
            -absFee_i257
        }
    }

    fn calculate_original_amount(self: FeePolicy, amount: u256, reverse_fee: bool) -> u256 {
        let mut rate = self.rate;
        let positive = rate > 0;
        if (reverse_fee) {
            rate = -rate;
        }
        let divider: u32 = (RATE_PRECISION.try_into().unwrap() + rate).try_into().unwrap();

        Math::divide(amount * RATE_PRECISION.into(), divider.into(), positive)
    }
}

impl FeePolicyStorePacking of StorePacking<FeePolicy, u32> {
    fn pack(value: FeePolicy) -> u32 {
        assert(value.rate < MAX_FEE_RATE, 'invalid_fee_rate');
        let mask: u32 = if (value.uses_quote) {
            0x800000
        } else {
            0
        };
        let rate: u32 = (MAX_FEE_RATE + value.rate).try_into().unwrap();
        mask | rate
    }

    fn unpack(value: u32) -> FeePolicy {
        let uses_quote: bool = value & 0x800000 != 0;
        let rate: u32 = value & 0x7fffff;
        let max_u32: u32 = MAX_FEE_RATE.try_into().unwrap();

        if (rate < max_u32) {
            FeePolicy { uses_quote, rate: -(max_u32 - rate).try_into().unwrap(), }
        } else {
            FeePolicy { uses_quote, rate: (rate - max_u32).try_into().unwrap(), }
        }
    }
}
