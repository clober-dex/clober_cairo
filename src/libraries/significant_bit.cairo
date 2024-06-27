use core::integer::u256_overflow_mul;

// http://supertech.csail.mit.edu/papers/debruijn.pdf
const DEBRUIJN_SEQ: u256 = 0x818283848586878898A8B8C8D8E8F929395969799A9B9D9E9FAAEB6BEDEEFF;
const DEBRUIJN_INDEX: [
    u8
    ; 256] = [
    0,
    1,
    2,
    9,
    3,
    17,
    10,
    25,
    4,
    33,
    18,
    41,
    11,
    49,
    26,
    57,
    5,
    65,
    34,
    69,
    19,
    77,
    42,
    85,
    12,
    93,
    50,
    101,
    27,
    109,
    58,
    117,
    6,
    38,
    66,
    98,
    35,
    125,
    70,
    133,
    20,
    128,
    78,
    141,
    43,
    149,
    86,
    157,
    13,
    73,
    94,
    165,
    51,
    169,
    102,
    177,
    28,
    136,
    110,
    185,
    59,
    193,
    118,
    201,
    7,
    23,
    39,
    55,
    67,
    83,
    99,
    115,
    36,
    131,
    126,
    155,
    71,
    175,
    134,
    199,
    21,
    81,
    129,
    173,
    79,
    209,
    142,
    211,
    44,
    144,
    150,
    219,
    87,
    213,
    158,
    227,
    14,
    46,
    74,
    106,
    95,
    146,
    166,
    190,
    52,
    152,
    170,
    224,
    103,
    221,
    178,
    235,
    29,
    89,
    137,
    181,
    111,
    215,
    186,
    243,
    60,
    160,
    194,
    238,
    119,
    229,
    202,
    247,
    255,
    8,
    16,
    24,
    32,
    40,
    48,
    56,
    64,
    68,
    76,
    84,
    92,
    100,
    108,
    116,
    37,
    97,
    124,
    132,
    127,
    140,
    148,
    156,
    72,
    164,
    168,
    176,
    135,
    184,
    192,
    200,
    22,
    54,
    82,
    114,
    130,
    154,
    174,
    198,
    80,
    172,
    208,
    210,
    143,
    218,
    212,
    226,
    45,
    105,
    145,
    189,
    151,
    223,
    220,
    234,
    88,
    180,
    214,
    242,
    159,
    237,
    228,
    246,
    254,
    15,
    31,
    47,
    63,
    75,
    91,
    107,
    96,
    123,
    139,
    147,
    163,
    167,
    183,
    191,
    53,
    113,
    153,
    197,
    171,
    207,
    217,
    225,
    104,
    188,
    222,
    233,
    179,
    241,
    236,
    245,
    253,
    30,
    62,
    90,
    122,
    138,
    162,
    182,
    112,
    196,
    206,
    216,
    187,
    232,
    240,
    244,
    252,
    61,
    121,
    161,
    195,
    205,
    231,
    239,
    251,
    120,
    204,
    230,
    250,
    203,
    249,
    248
];

#[generate_trait]
pub impl SignificantBitImpl of SignificantBitTrait {
    fn least_significant_bit(x: u256) -> u8 {
        assert!(x != 0, "x must be non-zero");
        let (mul, _) = u256_overflow_mul(x & (~x + 1), DEBRUIJN_SEQ);
        let index = mul / 0x100000000000000000000000000000000000000000000000000000000000000;
        *DEBRUIJN_INDEX.span()[index.try_into().unwrap()]
    }
}

#[cfg(test)]
mod tests {
    use super::SignificantBitImpl;
    use clober_cairo::alexandria::fast_power::fast_power;

    #[test]
    fn test_least_significant_bit() {
        let mut i: u256 = 0;
        while i < 256 {
            assert_eq!(
                SignificantBitImpl::least_significant_bit(fast_power(2_u256, i)),
                i.try_into().unwrap()
            );
            i += 1;
        }
    }
}
