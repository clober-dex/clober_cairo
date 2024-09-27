use clober_cairo::utils::constants::{TWO_POW_248, TWO_POW_96};
use clober_cairo::libraries::i257::i257;
use clober_cairo::libraries::i257::I257Impl;
use core::num::traits::OverflowingMul;

// http://supertech.csail.mit.edu/papers/debruijn.pdf
const DEBRUIJN_SEQ: u256 = 0x818283848586878898A8B8C8D8E8F929395969799A9B9D9E9FAAEB6BEDEEFF;
const DEBRUIJN_INDEX: [u8; 256] = [0, 1, 2, 9, 3, 17, 10, 25, 4, 33, 18, 41, 11, 49, 26, 57, 5, 65, 34, 69, 19, 77, 42, 85, 12, 93, 50, 101, 27, 109, 58, 117, 6, 38, 66, 98, 35, 125, 70, 133, 20, 128, 78, 141, 43, 149, 86, 157, 13, 73, 94, 165, 51, 169, 102, 177, 28, 136, 110, 185, 59, 193, 118, 201, 7, 23, 39, 55, 67, 83, 99, 115, 36, 131, 126, 155, 71, 175, 134, 199, 21, 81, 129, 173, 79, 209, 142, 211, 44, 144, 150, 219, 87, 213, 158, 227, 14, 46, 74, 106, 95, 146, 166, 190, 52, 152, 170, 224, 103, 221, 178, 235, 29, 89, 137, 181, 111, 215, 186, 243, 60, 160, 194, 238, 119, 229, 202, 247, 255, 8, 16, 24, 32, 40, 48, 56, 64, 68, 76, 84, 92, 100, 108, 116, 37, 97, 124, 132, 127, 140, 148, 156, 72, 164, 168, 176, 135, 184, 192, 200, 22, 54, 82, 114, 130, 154, 174, 198, 80, 172, 208, 210, 143, 218, 212, 226, 45, 105, 145, 189, 151, 223, 220, 234, 88, 180, 214, 242, 159, 237, 228, 246, 254, 15, 31, 47, 63, 75, 91, 107, 96, 123, 139, 147, 163, 167, 183, 191, 53, 113, 153, 197, 171, 207, 217, 225, 104, 188, 222, 233, 179, 241, 236, 245, 253, 30, 62, 90, 122, 138, 162, 182, 112, 196, 206, 216, 187, 232, 240, 244, 252, 61, 121, 161, 195, 205, 231, 239, 251, 120, 204, 230, 250, 203, 249, 248];

pub fn divide(a: u256, b: u256, rounding_up: bool) -> u256 {
    let mut result = a / b;
    if rounding_up && a % b != 0 {
        result += 1;
    }
    result
}

pub fn least_significant_bit(x: u256) -> u8 {
    assert(x != 0, 'x must be non-zero');
    let (mul, _) = OverflowingMul::overflowing_mul(x & (~x + 1), DEBRUIJN_SEQ);
    let index = mul / TWO_POW_248;
    *DEBRUIJN_INDEX.span()[index.try_into().unwrap()]
}


pub fn log_2(mut x: u256) -> u8 {
    assert(x > 0, 'undefined');

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
        x *= fast_power(2, abs);
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
    p = p * x - (795164235651350426258249787498_u256 * TWO_POW_96).into();

    let mut r = p / q.into();
    r *= 1677202110996718588342820967067443963516166.into();
    r += 16597577552685614221487285958193947469193820559219878177908093499208371.into() * k;
    (r / 302231454903657293676544000000000000000000.into()).try_into().unwrap()
}

//! # Fast power algorithm

/// Calculate the base ^ power
/// using the fast powering algorithm
/// # Arguments
/// * ` base ` - The base of the exponentiation
/// * ` power ` - The power of the exponentiation
/// # Returns
/// * ` T ` - The result of base ^ power
/// # Panics
/// * ` base ` is 0
pub fn fast_power<
    T,
    +Div<T>,
    +Rem<T>,
    +Into<u8, T>,
    +Into<T, u256>,
    +TryInto<u256, T>,
    +PartialEq<T>,
    +Copy<T>,
    +Drop<T>
>(
    base: T, mut power: T
) -> T {
    assert(base != 0_u8.into(), 'invalid input');

    let mut base: u256 = base.into();
    let mut result: u256 = 1;

    loop {
        if power % 2_u8.into() != 0_u8.into() {
            result *= base;
        }
        power = power / 2_u8.into();
        if power == 0_u8.into() {
            break;
        }
        base *= base;
    };

    result.try_into().expect('too large to fit output type')
}
