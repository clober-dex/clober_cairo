use clober_cairo::libraries::tick::Tick;
use clober_cairo::alexandria::fast_power::fast_power;
use clober_cairo::libraries::significant_bit::{SignificantBitImpl};

const TWO_POW_128: u256 = 0x100000000000000000000000000000000; // 2**128
const B0_BITMAP_KEY: felt252 = 'TickBitmap';

#[derive(Destruct)]
pub struct TickBitmap {
    pub hi: Felt252Dict<u128>,
    pub low: Felt252Dict<u128>,
}

impl TickBitmapDefaultImpl of Default<TickBitmap> {
    fn default() -> TickBitmap {
        TickBitmap { hi: Default::default(), low: Default::default() }
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

        let b0: u32 = SignificantBitImpl::least_significant_bit(
            Self::_get(ref bitmap, B0_BITMAP_KEY)
        )
            .into();
        let b0b1: u32 = (b0 * 256)
            | SignificantBitImpl::least_significant_bit(Self::_get(ref bitmap, (~b0).into()))
                .into();
        let b2: u32 = SignificantBitImpl::least_significant_bit(Self::_get(ref bitmap, b0b1.into()))
            .into();
        Self::_to_tick(b0b1, b2)
    }

    fn set(ref bitmap: TickBitmap, tick: Tick) {
        let (b0b1, b2) = Self::_split(tick);
        let mut mask: u256 = fast_power(2_u256, b2.into()).into();
        let mut b2Bitmap = Self::_get(ref bitmap, b0b1.into());
        assert(b2Bitmap & mask == 0, 'AlreadyExistsError');

        Self::_set(ref bitmap, b0b1.into(), b2Bitmap | mask);
        if b2Bitmap == 0 {
            mask = fast_power(2_u256, (b0b1 & 0xff).into()).into();
            let b1BitmapKey = ~(b0b1 / 256);
            let mut b1Bitmap = Self::_get(ref bitmap, b1BitmapKey.into());
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
        let mut b2Bitmap = Self::_get(ref bitmap, b0b1.into());
        Self::_set(ref bitmap, b0b1.into(), b2Bitmap & (~mask));
        if b2Bitmap == mask {
            mask = fast_power(2_u256, (b0b1 & 0xff).into()).into();
            let b1BitmapKey = ~(b0b1 / 256);
            let mut b1Bitmap = Self::_get(ref bitmap, b1BitmapKey.into());
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
        let mut raw: u32 = (0x800000 - tick.value).try_into().unwrap();
        let b0b1 = (raw & 0xffff00) / 256;
        let b2 = raw & 0xff;
        (b0b1, b2)
    }

    fn _to_tick(b0b1: u32, b2: u32) -> Tick {
        let value: i32 = 0x800000 - (b0b1 * 256 + b2).try_into().unwrap();
        Tick { value }
    }

    fn _get(ref bitmap: TickBitmap, key: felt252) -> u256 {
        bitmap.hi[key].into() * TWO_POW_128 + bitmap.low[key].into()
    }

    fn _set(ref bitmap: TickBitmap, key: felt252, value: u256) {
        bitmap.hi.insert(key, (value / TWO_POW_128).try_into().unwrap());
        bitmap.low.insert(key, (value % TWO_POW_128).try_into().unwrap());
    }
}

#[cfg(test)]
mod tests {
    use clober_cairo::libraries::tick::Tick;
    use super::TickBitmap;
    use super::TickBitmapImpl;

    fn sort<T, +Copy<T>, +Drop<T>, +PartialOrd<T>>(mut array: Span<T>) -> Array<T> {
        if array.len() == 0 {
            return array![];
        }
        if array.len() == 1 {
            return array![*array[0]];
        }
        let mut idx1 = 0;
        let mut idx2 = 1;
        let mut sorted_iteration = true;
        let mut sorted_array = array![];

        loop {
            if idx2 == array.len() {
                sorted_array.append(*array[idx1]);
                if sorted_iteration {
                    break;
                }
                array = sorted_array.span();
                sorted_array = array![];
                idx1 = 0;
                idx2 = 1;
                sorted_iteration = true;
            } else {
                if *array[idx1] <= *array[idx2] {
                    sorted_array.append(*array[idx1]);
                    idx1 = idx2;
                    idx2 += 1;
                } else {
                    sorted_array.append(*array[idx2]);
                    idx2 += 1;
                    sorted_iteration = false;
                }
            };
        };
        sorted_array
    }

    #[test]
    fn test_highest() {
        let mut bitmap: TickBitmap = Default::default();
        let numbers = array![
            -263808,
            -254026,
            399716,
            -3465,
            221293,
            -22152,
            299822,
            304803,
            -449410,
            -517771,
            65795,
            299308,
            188576,
            -350322,
            -177543,
            461681,
            104058,
            -517144,
            256148,
            248225,
            -455504,
            359408,
            -428457,
            -312770,
            -315528,
            -231155,
            -443426,
            -156975,
            261919,
            -156378,
            -320077,
            206952,
            275889,
            486548,
            403234,
            378398,
            -412794,
            201417,
            301547,
            -332948,
            -375847,
            286713,
            89897,
            90631,
            -57473,
            -414417,
            187062,
            373640,
            355869,
            -91398,
            -126803,
            168038,
            3522,
            469585,
            -127950,
            -245845,
            -379423,
            513898,
            217937,
            -347853,
            -248326,
            -310549,
            317346,
            -443394,
            -191364,
            -425599,
            -205181,
            28223,
            -114726,
            199022,
            -519834,
            -434281,
            418697,
            -296928,
            65277,
            249945,
            -127923,
            -252186,
            -70273,
            91649,
            -613,
            -433167
        ];
        let mut elements = sort(_set(ref bitmap, numbers).span());
        assert!(!TickBitmapImpl::is_empty(ref bitmap), "HAS_TO_BE_OCCUPIED");
        let length = elements.len();

        let mut i = 0;
        while i < length {
            let number = *elements.at(i);
            assert!(TickBitmapImpl::has(ref bitmap, Tick { value: number }), "BEFORE_CLEAR");
            TickBitmapImpl::clear(ref bitmap, Tick { value: number });
            assert!(!TickBitmapImpl::has(ref bitmap, Tick { value: number }), "AFTER_CLEAR");
            i += 1;
        }
    }

    #[test]
    fn test_clear() {
        let mut bitmap: TickBitmap = Default::default();
        let numbers = array![
            -613,
            -433167,
            430136,
            146279,
            -296056,
            92926,
            397908,
            285240,
            -113488,
            438417,
            295583,
            57058,
            -100146,
            -81238,
            87166,
            -172207,
            112492,
            107822,
            398473,
            310027,
            -297589,
            -386926,
            -247954,
            -156027,
            109110,
            48339,
            -457962,
            -356079,
            -67960,
            -445170,
            9939,
            159533,
            -280769,
            167167,
            370773,
            -197636,
            -161622,
            -29755,
            307344,
            121125,
            222719,
            172118,
            -66786,
            281325,
            -328947,
            -425124,
            44830,
            -277992,
            144696,
            78287,
            244099,
            233470,
            93643,
            186586,
            -418189,
            231398,
            -447754,
            2273,
            456054,
            -51841,
            414725,
            -154119,
            -426655,
            204206,
            246070,
            -70390,
            -62884,
            328027,
            -44567,
            -144985,
            -143436,
            228369,
            295686,
            163031
        ];
        let mut elements = sort(_set(ref bitmap, numbers).span());
        assert!(!TickBitmapImpl::is_empty(ref bitmap), "HAS_TO_BE_OCCUPIED");
        let length = elements.len();

        let mut i = 0;
        while i < length {
            let number = *elements.at(i);
            assert!(TickBitmapImpl::has(ref bitmap, Tick { value: number }), "BEFORE_CLEAR");
            TickBitmapImpl::clear(ref bitmap, Tick { value: number });
            assert!(!TickBitmapImpl::has(ref bitmap, Tick { value: number }), "AFTER_CLEAR");
            i += 1;
        }
    }

    #[test]
    #[should_panic(expected: ('AlreadyExistsError',))]
    fn test_set() {
        let mut bitmap: TickBitmap = Default::default();
        let number = 5;

        assert!(!TickBitmapImpl::has(ref bitmap, Tick { value: number }), "BEFORE_SET");
        TickBitmapImpl::set(ref bitmap, Tick { value: number });
        assert!(TickBitmapImpl::has(ref bitmap, Tick { value: number }), "AFTER_SET");
        TickBitmapImpl::set(ref bitmap, Tick { value: number });
    }

    fn _set(ref bitmap: TickBitmap, numbers: Array<i32>) -> Array<i32> {
        let length = numbers.len();
        let mut i = 0;
        let mut max: i32 = -0x1000000;
        let mut elements: Array<i32> = Default::default();
        while i < length {
            let number: i32 = *numbers.at(i);
            if TickBitmapImpl::has(ref bitmap, Tick { value: number }) {
                continue;
            }
            if number > max {
                max = number;
            }

            assert!(!TickBitmapImpl::has(ref bitmap, Tick { value: number }), "BEFORE_PUSH");
            TickBitmapImpl::set(ref bitmap, Tick { value: number });
            elements.append(number);
            assert!(TickBitmapImpl::has(ref bitmap, Tick { value: number }), "AFTER_PUSH");
            let highest = TickBitmapImpl::highest(ref bitmap).value;
            assert_eq!(max, highest, "ASSERT_MIN");
            i += 1;
        };
        elements
    }
}

