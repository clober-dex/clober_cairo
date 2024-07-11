pub mod Math {
    use clober_cairo::alexandria::i257::i257;
    use clober_cairo::alexandria::i257::I257Impl;
    use clober_cairo::alexandria::fast_power::fast_power;

    const TWO_POW_96: u256 = 0x1000000000000000000000000; // 2**96

    pub fn divide(a: u256, b: u256, rounding_up: bool) -> u256 {
        let mut result = a / b;
        if rounding_up && a % b != 0 {
            result += 1;
        }
        result
    }

    pub fn log_2(mut x: u256) -> u8 {
        assert(x > 0, 'Undefined');

        let mut r: u8 = 0;

        if x >= 0x100000000000000000000000000000000 {
            x /= 0x100000000000000000000000000000000;
            r += 128;
        }
        if x >= 0x10000000000000000 {
            x /= 0x10000000000000000;
            r += 64;
        }
        if x >= 0x100000000 {
            x /= 0x100000000;
            r += 32;
        }
        if x >= 0x10000 {
            x /= 0x10000;
            r += 16;
        }
        if x >= 0x100 {
            x /= 0x100;
            r += 8;
        }
        if x >= 0x10 {
            x /= 0x10;
            r += 4;
        }
        if x >= 0x4 {
            x /= 0x4;
            r += 2;
        }
        if x >= 0x2 {
            r += 1;
        }
        r
    }

    pub fn ln_wad(mut x: u256) -> i128 {
        let r: u8 = log_2(x);
        let k = if r > 96 {
            let abs: u256 = (r - 96).into();
            x /= fast_power(2, abs);
            I257Impl::new(abs, false)
        } else {
            let abs: u256 = (96 - r).into();
            x *= fast_power(2, abs).into();
            I257Impl::new(abs, true)
        };

        // We leave p in 2**192 basis so we don't need to scale it back up for the division.
        // q is monic by convention.
        let mut q = x + 5573035233440673466300451813936;
        q = (q * x) / TWO_POW_96 + 71694874799317883764090561454958;
        q = (q * x) / TWO_POW_96 + 283447036172924575727196451306956;
        q = (q * x) / TWO_POW_96 + 401686690394027663651624208769553;
        q = (q * x) / TWO_POW_96 + 204048457590392012362485061816622;
        q = (q * x) / TWO_POW_96 + 31853899698501571402653359427138;
        q = (q * x) / TWO_POW_96 + 909429971244387300277376558375;

        let x: i257 = x.into();

        // Evaluate using a (8, 8)-term rational approximation.
        // p is made monic, we will multiply by a scale factor later.
        let mut p = x + 3273285459638523848632254066296.into();
        p = (p * x) / TWO_POW_96.into() + 24828157081833163892658089445524.into();
        p = (p * x) / TWO_POW_96.into() + 43456485725739037958740375743393.into();
        p = (p * x) / TWO_POW_96.into() - 11111509109440967052023855526967.into();
        p = (p * x) / TWO_POW_96.into() - 45023709667254063763336534515857.into();
        p = (p * x) / TWO_POW_96.into() - 14706773417378608786704636184526.into();
        p = p * x - (795164235651350426258249787498 * TWO_POW_96).into();

        let mut r = p / q.into();
        r *= 1677202110996718588342820967067443963516166.into();
        r += 16597577552685614221487285958193947469193820559219878177908093499208371.into() * k;
        r += 600920179829731861736702779321621459595472258049074101567377883020018308.into();
        (r / 302231454903657293676544000000000000000000.into()).try_into().unwrap()
    }
}
