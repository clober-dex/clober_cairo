use clober_cairo::utils::math::Math::ln_wad;
use clober_cairo::alexandria::i257::i257;
use clober_cairo::alexandria::i257::I257Impl;

const TWO_POW_96: u256 = 0x1000000000000000000000000; // 2**96
const TWO_POW_128: u256 = 0x100000000000000000000000000000000; // 2**128
const TWO_POW_192: u256 = 0x1000000000000000000000000000000000000000000000000; // 2**192

const MAX_TICK: i32 = 0x7ffff;
const MIN_TICK: i32 = -MAX_TICK;

const MIN_PRICE: u256 = 1350587;
const MAX_PRICE: u256 = 4647684107270898330752324302845848816923571339324334;

const R0: u256 = 0xfff97272373d413259a46990;
const R1: u256 = 0xfff2e50f5f656932ef12357c;
const R2: u256 = 0xffe5caca7e10e4e61c3624ea;
const R3: u256 = 0xffcb9843d60f6159c9db5883;
const R4: u256 = 0xff973b41fa98c081472e6896;
const R5: u256 = 0xff2ea16466c96a3843ec78b3;
const R6: u256 = 0xfe5dee046a99a2a811c461f1;
const R7: u256 = 0xfcbe86c7900a88aedcffc83b;
const R8: u256 = 0xf987a7253ac413176f2b074c;
const R9: u256 = 0xf3392b0822b70005940c7a39;
const R10: u256 = 0xe7159475a2c29b7443b29c7f;
const R11: u256 = 0xd097f3bdfd2022b8845ad8f7;
const R12: u256 = 0xa9f746462d870fdf8a65dc1f;
const R13: u256 = 0x70d869a156d2a1b890bb3df6;
const R14: u256 = 0x31be135f97d08fd981231505;
const R15: u256 = 0x9aa508b5b7a84e1c677de54;
const R16: u256 = 0x5d6af8dedb81196699c329;
const R17: u256 = 0x2216e584f5fa1ea92604;
const R18: u256 = 0x48a170391f7dc42;

#[derive(Copy, Drop, Serde)]
pub struct Tick {
    pub value: i32,
}

#[generate_trait]
pub impl TickImpl of TickTrait {
    fn to_price(tick: Tick) -> u256 {
        assert(tick.value < MIN_TICK || tick.value > MAX_TICK, 'invalid_tick');

        let absTick: u32 = (if tick.value < 0 {
            -tick.value
        } else {
            tick.value
        })
            .try_into()
            .unwrap();

        let mut price: u256 = if absTick & 0x1 != 0 {
            R0
        } else {
            TWO_POW_96
        };
        if absTick & 0x2 != 0 {
            price = (price * R1) / TWO_POW_96;
        }
        if absTick & 0x4 != 0 {
            price = (price * R2) / TWO_POW_96;
        }
        if absTick & 0x8 != 0 {
            price = (price * R3) / TWO_POW_96;
        }
        if absTick & 0x10 != 0 {
            price = (price * R4) / TWO_POW_96;
        }
        if absTick & 0x20 != 0 {
            price = (price * R5) / TWO_POW_96;
        }
        if absTick & 0x40 != 0 {
            price = (price * R6) / TWO_POW_96;
        }
        if absTick & 0x80 != 0 {
            price = (price * R7) / TWO_POW_96;
        }
        if absTick & 0x100 != 0 {
            price = (price * R8) / TWO_POW_96;
        }
        if absTick & 0x200 != 0 {
            price = (price * R9) / TWO_POW_96;
        }
        if absTick & 0x400 != 0 {
            price = (price * R10) / TWO_POW_96;
        }
        if absTick & 0x800 != 0 {
            price = (price * R11) / TWO_POW_96;
        }
        if absTick & 0x1000 != 0 {
            price = (price * R12) / TWO_POW_96;
        }
        if absTick & 0x2000 != 0 {
            price = (price * R13) / TWO_POW_96;
        }
        if absTick & 0x4000 != 0 {
            price = (price * R14) / TWO_POW_96;
        }
        if absTick & 0x8000 != 0 {
            price = (price * R15) / TWO_POW_96;
        }
        if absTick & 0x10000 != 0 {
            price = (price * R16) / TWO_POW_96;
        }
        if absTick & 0x20000 != 0 {
            price = (price * R17) / TWO_POW_96;
        }
        if absTick & 0x40000 != 0 {
            price = (price * R18) / TWO_POW_96;
        }
        if tick.value > 0 {
            return TWO_POW_192 / price;
        }
        price
    }

    fn from_price(price: u256) -> Tick {
        let tick: i128 = (I257Impl::new(42951820407860, false)
            * ln_wad(price).into()
            / TWO_POW_128.into())
            .try_into()
            .unwrap();
        let tick: i32 = tick.try_into().unwrap();
        if Self::to_price(Tick { value: tick }) > price {
            return Tick { value: tick - 1 };
        }
        Tick { value: tick }
    }

    fn base_to_quote(tick: Tick, base: u256, rounding_up: bool) -> u256 {
        let price: u256 = Self::to_price(tick);
        if rounding_up {
            return (base * price + TWO_POW_96 - 1) / TWO_POW_96;
        }
        base * price / TWO_POW_96
    }

    fn quote_to_base(tick: Tick, quote: u256, rounding_up: bool) -> u256 {
        let price: u256 = Self::to_price(tick);
        if rounding_up {
            return (quote * TWO_POW_96 + price - 1) / price;
        }
        quote * TWO_POW_96 / price
    }
}

impl TickPartialEq of PartialEq<Tick> {
    fn eq(lhs: @Tick, rhs: @Tick) -> bool {
        lhs.value == rhs.value
    }

    fn ne(lhs: @Tick, rhs: @Tick) -> bool {
        !Self::eq(lhs, rhs)
    }
}

impl TickPartialOrd of PartialOrd<Tick> {
    fn le(lhs: Tick, rhs: Tick) -> bool {
        !Self::gt(lhs, rhs)
    }
    fn ge(lhs: Tick, rhs: Tick) -> bool {
        Self::gt(lhs, rhs) || lhs == rhs
    }

    fn lt(lhs: Tick, rhs: Tick) -> bool {
        !Self::gt(lhs, rhs) && lhs != rhs
    }

    fn gt(lhs: Tick, rhs: Tick) -> bool {
        lhs.value > rhs.value
    }
}

