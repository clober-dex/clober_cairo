use clober_cairo::libraries::tick::Tick;
use clober_cairo::utils::math::Math::{least_significant_bit, fast_power};
use clober_cairo::utils::constants::{TWO_POW_128};

const B0_BITMAP_KEY: felt252 = 'TickBitmap';

#[derive(Destruct)]
pub struct TickBitmap {
    pub high: Felt252Dict<u128>,
    pub low: Felt252Dict<u128>,
}

impl TickBitmapDefaultImpl of Default<TickBitmap> {
    fn default() -> TickBitmap {
        TickBitmap { high: Default::default(), low: Default::default() }
    }
}

#[generate_trait]
pub impl TickBitmapImpl of TickBitmapTrait {
    fn has(ref bitmap: TickBitmap, tick: Tick) -> bool {
        let (b0b1, b2) = Self::_split(tick);
        let mask: u256 = fast_power(2_u256, b2.into()).into();
        let value = Self::_get(ref bitmap, b0b1.into());
        value & mask == mask
    }

    fn is_empty(ref bitmap: TickBitmap) -> bool {
        Self::_get(ref bitmap, B0_BITMAP_KEY) == 0
    }

    fn highest(ref bitmap: TickBitmap) -> Tick {
        assert(!Self::is_empty(ref bitmap), 'EmptyError');

        let b0: u32 = least_significant_bit(Self::_get(ref bitmap, B0_BITMAP_KEY)).into();
        let b0b1: u32 = (b0 * 256)
            | least_significant_bit(Self::_get(ref bitmap, (~b0).into())).into();
        let b2: u32 = least_significant_bit(Self::_get(ref bitmap, b0b1.into())).into();
        Self::_to_tick(b0b1, b2)
    }

    fn set(ref bitmap: TickBitmap, tick: Tick) {
        let (b0b1, b2) = Self::_split(tick);
        let mut mask: u256 = fast_power(2_u256, b2.into()).into();
        let b2Bitmap = Self::_get(ref bitmap, b0b1.into());
        assert(b2Bitmap & mask == 0, 'AlreadyExistsError');

        Self::_set(ref bitmap, b0b1.into(), b2Bitmap | mask);
        if b2Bitmap == 0 {
            mask = fast_power(2_u256, (b0b1 & 0xff).into()).into();
            let b1BitmapKey = ~(b0b1 / 256);
            let b1Bitmap = Self::_get(ref bitmap, b1BitmapKey.into());
            Self::_set(ref bitmap, b1BitmapKey.into(), b1Bitmap | mask);
            if b1Bitmap == 0 {
                Self::_set(
                    ref bitmap,
                    B0_BITMAP_KEY,
                    Self::_get(ref bitmap, B0_BITMAP_KEY)
                        | fast_power(2_u256, (~b1BitmapKey).into()).into()
                );
            }
        }
    }

    fn clear(ref bitmap: TickBitmap, tick: Tick) {
        let (b0b1, b2) = Self::_split(tick);
        let mut mask: u256 = fast_power(2_u256, b2.into()).into();
        let b2Bitmap = Self::_get(ref bitmap, b0b1.into());
        Self::_set(ref bitmap, b0b1.into(), b2Bitmap & (~mask));
        if b2Bitmap == mask {
            mask = fast_power(2_u256, (b0b1 & 0xff).into()).into();
            let b1BitmapKey = ~(b0b1 / 256);
            let b1Bitmap = Self::_get(ref bitmap, b1BitmapKey.into());
            Self::_set(ref bitmap, b1BitmapKey.into(), b1Bitmap & (~mask));
            if mask == b1Bitmap {
                mask = fast_power(2_u256, (~b1BitmapKey).into()).into();
                Self::_set(
                    ref bitmap, B0_BITMAP_KEY, Self::_get(ref bitmap, B0_BITMAP_KEY) & (~mask)
                );
            }
        }
    }

    fn _split(tick: Tick) -> (u32, u32) {
        let raw: u32 = (0x80000 - tick.value).try_into().unwrap();
        let b0b1 = (raw & 0xffff00) / 256;
        let b2 = raw & 0xff;
        (b0b1, b2)
    }

    fn _to_tick(b0b1: u32, b2: u32) -> Tick {
        let value: i32 = 0x80000 - (b0b1 * 256 + b2).try_into().unwrap();
        Tick { value }
    }

    fn _get(ref bitmap: TickBitmap, key: felt252) -> u256 {
        bitmap.high[key].into() * TWO_POW_128 + bitmap.low[key].into()
    }

    fn _set(ref bitmap: TickBitmap, key: felt252, value: u256) {
        bitmap.high.insert(key, (value / TWO_POW_128).try_into().unwrap());
        bitmap.low.insert(key, (value % TWO_POW_128).try_into().unwrap());
    }
}
