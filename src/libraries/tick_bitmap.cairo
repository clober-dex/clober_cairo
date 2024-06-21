use core::dict::Felt252DictTrait;
use core::traits::Into;
use clober_cairo::libraries::tick::Tick;
use clober_cairo::alexandria::fast_power::fast_power;
use clober_cairo::libraries::significant_bit::{SignificantBitImpl};

const TWO_POW_128: u256 = 0x100000000000000000000000000000000; // 2**128
const B0_BITMAP_KEY: felt252 = 0x15654;

#[derive(Destruct)]
pub struct TickBitmap {
    pub hi: Felt252Dict<u128>,
    pub low: Felt252Dict<u128>,
}

fn _split(tick: Tick) -> (u32, u32) {
    let mut value: u32 = ~(tick.value + 0x800000).try_into().unwrap();
    value = ~value + 0x800000;
    let b0b1 = (value & 0xffff00) / 256;
    let b2 = value & 0xff;
    (b0b1, b2)
}

fn _to_tick(raw: felt252) -> Tick {
    let value: u32 = (~(raw - 0x800000).try_into().unwrap()) & 0xffffff;
    let value: i32 = value.try_into().unwrap();
    Tick { value }
}

fn _get(ref bitmap: TickBitmap, key: felt252) -> u256 {
    bitmap.hi.get(key).into() * TWO_POW_128 + bitmap.low.get(key).into()
}

fn _set(ref bitmap: TickBitmap, key: felt252, value: u256) {
    bitmap.hi.insert(key, (value / TWO_POW_128).try_into().unwrap());
    bitmap.low.insert(key, (value % TWO_POW_128).try_into().unwrap());
}

fn _is_empty(ref bitmap: TickBitmap) -> bool {
    _get(ref bitmap, B0_BITMAP_KEY) == 0
}

#[generate_trait]
impl TickBitmapImpl of TickBitmapTrait {
    fn has(ref bitmap: TickBitmap, tick: Tick) -> bool {
        let (b0b1, b2) = _split(tick);
        let mask: u256 = fast_power(2, (b2)).into();
        let value = _get(ref bitmap, b0b1.into());
        value & mask == mask
    }

    fn is_empty(ref bitmap: TickBitmap) -> bool {
        _get(ref bitmap, B0_BITMAP_KEY) == 0
    }

    fn highest(ref bitmap: TickBitmap) -> Tick {
        assert(_is_empty(ref bitmap), 'EmptyError');

        let b0: u32 = SignificantBitImpl::least_significant_bit(_get(ref bitmap, B0_BITMAP_KEY))
            .into();
        let b0b1: u32 = (b0 * 256)
            | SignificantBitImpl::least_significant_bit(_get(ref bitmap, (~b0).into())).into();
        let b2: u32 = SignificantBitImpl::least_significant_bit(_get(ref bitmap, b0b1.into()))
            .into();
        _to_tick(((b0b1 * 256) + b2).into())
    }

    fn set(ref bitmap: TickBitmap, tick: Tick) {
        let (b0b1, b2) = _split(tick);
        let mut mask: u256 = fast_power(2, (b2)).into();
        let mut b2Bitmap = _get(ref bitmap, b0b1.into());
        assert(b2Bitmap & mask == 0, 'AlreadyExistsError');

        _set(ref bitmap, b0b1.into(), b2Bitmap | mask);
        if b2Bitmap == 0 {
            mask = fast_power(2, (b0b1 & 0xff)).into();
            let b1BitmapKey = ~(b0b1 / 256);
            let mut b1Bitmap = _get(ref bitmap, b1BitmapKey.into());
            _set(ref bitmap, b1BitmapKey.into(), b1Bitmap | mask);
            if b1Bitmap == 0 {
                _set(
                    ref bitmap,
                    B0_BITMAP_KEY,
                    _get(ref bitmap, B0_BITMAP_KEY) | fast_power(2, (~b1BitmapKey)).into()
                );
            }
        }
    }

    fn clear(ref bitmap: TickBitmap, tick: Tick) {
        let (b0b1, b2) = _split(tick);
        let mut mask: u256 = fast_power(2, (b2)).into();
        let mut b2Bitmap = _get(ref bitmap, b0b1.into());
        _set(ref bitmap, b0b1.into(), b2Bitmap & (~mask));
        if b2Bitmap == mask {
            mask = fast_power(2, (b0b1 & 0xff)).into();
            let b1BitmapKey = ~(b0b1 / 256);
            let mut b1Bitmap = _get(ref bitmap, b1BitmapKey.into());
            _set(ref bitmap, b1BitmapKey.into(), b1Bitmap & (~mask));
            if mask == b1Bitmap {
                mask = fast_power(2, (~b1BitmapKey)).into();
                _set(ref bitmap, B0_BITMAP_KEY, _get(ref bitmap, B0_BITMAP_KEY) & (~mask));
            }
        }
    }
}

