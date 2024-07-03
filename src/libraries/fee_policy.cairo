use starknet::storage_access::{StorePacking};
use clober_cairo::utils::math::{Math};
use clober_cairo::utils::constants::{RATE_PRECISION};

const MAX_FEE_RATE: u32 = 500000;

#[derive(Copy, Drop, Serde, Debug)]
pub struct FeePolicy {
    pub uses_quote: bool,
    pub sign: bool,
    pub rate: u32,
}

#[generate_trait]
pub impl FeePolicyImpl of FeePolicyTrait {
    fn calculate_fee(self: FeePolicy, amount: u256, reverse_rounding: bool) -> (bool, u256) {
        let rounding_up: bool = if (reverse_rounding) {
            self.sign
        } else {
            !self.sign
        };
        let absFee: u256 = Math::divide(
            amount * self.rate.into(), RATE_PRECISION.into(), rounding_up
        );
        (self.sign, absFee)
    }

    fn calculate_original_amount(self: FeePolicy, amount: u256, reverse_fee: bool) -> u256 {
        let divider: u32 = if (self.sign ^ reverse_fee) {
            RATE_PRECISION - self.rate
        } else {
            RATE_PRECISION + self.rate
        };

        Math::divide(amount * RATE_PRECISION.into(), divider.into(), !self.sign)
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
        let rate: u32 = if (value.sign) {
            MAX_FEE_RATE - value.rate
        } else {
            MAX_FEE_RATE + value.rate
        };
        mask | rate
    }

    fn unpack(value: u32) -> FeePolicy {
        let uses_quote: bool = value & 0x800000 != 0;
        let rate: u32 = value & 0x7fffff;

        if (rate < MAX_FEE_RATE) {
            FeePolicy { uses_quote, sign: true, rate: MAX_FEE_RATE - rate, }
        } else {
            FeePolicy { uses_quote, sign: false, rate: rate - MAX_FEE_RATE, }
        }
    }
}
