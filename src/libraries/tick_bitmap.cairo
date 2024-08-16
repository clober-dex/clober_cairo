use clober_cairo::libraries::tick::Tick;
use clober_cairo::libraries::storage_map::{Felt252Map, Felt252MapTrait};
use clober_cairo::utils::math::{least_significant_bit, fast_power};
use clober_cairo::utils::constants::{TWO_POW_128, MIN_TICK};

const B0_BITMAP_KEY: felt252 = 'TickBitmap';

pub type TickBitmap = Felt252Map<u256>;

#[generate_trait]
pub impl TickBitmapImpl of TickBitmapTrait {
    fn has(self: @TickBitmap, tick: Tick) -> bool {
        let (b0b1, b2) = Self::_split(tick);
        let mask: u256 = fast_power(2_u256, b2.into()).into();
        let value = Self::_get(self, b0b1.into());
        value & mask == mask
    }

    fn is_empty(self: @TickBitmap) -> bool {
        Self::_get(self, B0_BITMAP_KEY) == 0
    }

    fn highest(self: @TickBitmap) -> Tick {
        assert(!self.is_empty(), 'EmptyError');

        let b0: u32 = least_significant_bit(Self::_get(self, B0_BITMAP_KEY)).into();
        let b0b1: u32 = (b0 * 256) | least_significant_bit(Self::_get(self, (~b0).into())).into();
        let b2: u32 = least_significant_bit(Self::_get(self, b0b1.into())).into();
        Self::_to_tick(b0b1, b2)
    }

    fn set(ref self: TickBitmap, tick: Tick) {
        let (b0b1, b2) = Self::_split(tick);
        let mut mask: u256 = fast_power(2_u256, b2.into()).into();
        let b2Bitmap = Self::_get(@self, b0b1.into());
        assert(b2Bitmap & mask == 0, 'AlreadyExistsError');

        Self::_set(ref self, b0b1.into(), b2Bitmap | mask);
        if b2Bitmap == 0 {
            mask = fast_power(2_u256, (b0b1 & 0xff).into()).into();
            let b1BitmapKey = ~(b0b1 / 256);
            let b1Bitmap = Self::_get(@self, b1BitmapKey.into());
            Self::_set(ref self, b1BitmapKey.into(), b1Bitmap | mask);
            if b1Bitmap == 0 {
                Self::_set(
                    ref self,
                    B0_BITMAP_KEY,
                    Self::_get(@self, B0_BITMAP_KEY)
                        | fast_power(2_u256, (~b1BitmapKey).into()).into()
                );
            }
        }
    }

    fn clear(ref self: TickBitmap, tick: Tick) {
        let (b0b1, b2) = Self::_split(tick);
        let mut mask: u256 = fast_power(2_u256, b2.into()).into();
        let b2Bitmap = Self::_get(@self, b0b1.into());
        Self::_set(ref self, b0b1.into(), b2Bitmap & (~mask));
        if b2Bitmap == mask {
            mask = fast_power(2_u256, (b0b1 & 0xff).into()).into();
            let b1BitmapKey = ~(b0b1 / 256);
            let b1Bitmap = Self::_get(@self, b1BitmapKey.into());
            Self::_set(ref self, b1BitmapKey.into(), b1Bitmap & (~mask));
            if mask == b1Bitmap {
                mask = fast_power(2_u256, (~b1BitmapKey).into()).into();
                Self::_set(ref self, B0_BITMAP_KEY, Self::_get(@self, B0_BITMAP_KEY) & (~mask));
            }
        }
    }

    fn max_less_than(self: @TickBitmap, tick: Tick) -> Tick {
        let (mut b0b1, b2) = Self::_split(tick);
        let mut mask: u256 = ~((fast_power(2_u256, b2.into()) - 1) * 2 + 1);
        let mut b2Bitmap = Self::_get(self, b0b1.into()) & mask;
        if b2Bitmap == 0 {
            let mut b0: u32 = b0b1 / 256;
            let b1: u32 = b0b1 & 0xff;
            mask = ~((fast_power(2_u256, b1.into()) - 1) * 2 + 1);
            let mut b1Bitmap = Self::_get(self, (~b0).into()) & mask;
            if b1Bitmap == 0 {
                mask = ~((fast_power(2_u256, b0.into()) - 1) * 2 + 1);
                let b0Bitmap = Self::_get(self, B0_BITMAP_KEY) & mask;
                if b0Bitmap == 0 {
                    return (MIN_TICK - 1).into();
                }
                b0 = least_significant_bit(b0Bitmap).into();
                b1Bitmap = Self::_get(self, (~b0).into());
            }
            b0b1 = (b0 * 256) | least_significant_bit(b1Bitmap).into();
            b2Bitmap = Self::_get(self, b0b1.into());
        }
        let b2 = least_significant_bit(b2Bitmap).into();
        Self::_to_tick(b0b1, b2)
    }

    fn _split(tick: Tick) -> (u32, u32) {
        let raw: u32 = (0x80000 - tick.into()).try_into().unwrap();
        let b0b1 = (raw & 0xffff00) / 256;
        let b2 = raw & 0xff;
        (b0b1, b2)
    }

    fn _to_tick(b0b1: u32, b2: u32) -> Tick {
        let value: i32 = 0x80000 - (b0b1 * 256 + b2).try_into().unwrap();
        value.into()
    }

    fn _get(bitmap: @TickBitmap, key: felt252) -> u256 {
        bitmap.read_at(key)
    }

    fn _set(ref bitmap: TickBitmap, key: felt252, value: u256) {
        bitmap.write_at(key, value);
    }
}
