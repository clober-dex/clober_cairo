use starknet::storage_access::{StorePacking};

const TWO_POW_64: u256 = 0x10000000000000000; // 2**64
const MASK_64: u256 = 0xFFFFFFFFFFFFFFFF; // 2**64 - 1

#[derive(Copy, Drop, Serde, Debug)]
pub struct PackedU256 {
    pub data: u256
}

#[generate_trait]
impl PackedU256Impl of PackedU256Trait {
    fn get_u64(self: PackedU256, n: u8) -> u64 {
        assert(n < 4, 'Index out of bounds');
        let mut value = self.data;
        let mut index = n;
        while index > 0 {
            value /= TWO_POW_64;
            index -= 1;
        };
        (value & MASK_64).try_into().unwrap()
    }

    fn update_64(self: PackedU256, n: u8, value: u64) -> PackedU256 {
        assert(n < 4, 'Index out of bounds');
        let mut packed = self.data;
        let mut data: u256 = value.into();
        let mut mask: u256 = MASK_64;
        let mut index = n;
        while index > 0 {
            data *= TWO_POW_64;
            mask *= TWO_POW_64;
            index -= 1;
        };
        PackedU256 { data: (packed & ~mask) + data }
    }

    fn sub_u64(self: PackedU256, n: u8, value: u64) -> PackedU256 {
        assert(n < 4, 'Index out of bounds');
        self.update_64(n, self.get_u64(n) - value)
    }
}

impl PackedU256StoragePacking of StorePacking<PackedU256, u256> {
    fn pack(value: PackedU256) -> u256 {
        value.data
    }

    fn unpack(value: u256) -> PackedU256 {
        PackedU256 { data: value }
    }
}

#[cfg(test)]
mod tests {
    use super::PackedU256;
    use super::PackedU256Trait;

    #[test]
    fn get_u64() {
        let packed = PackedU256 {
            data: 0x4444444444444444333333333333333322222222222222221111111111111111
        };
        assert_eq!(packed.get_u64(0), 0x1111111111111111);
        assert_eq!(packed.get_u64(1), 0x2222222222222222);
        assert_eq!(packed.get_u64(2), 0x3333333333333333);
        assert_eq!(packed.get_u64(3), 0x4444444444444444);
    }

    #[test]
    #[should_panic(expected: ('Index out of bounds',))]
    fn get_u64_out_of_bounds() {
        let packed = PackedU256 {
            data: 0x4444444444444444333333333333333322222222222222221111111111111111
        };
        packed.get_u64(4);
    }

    #[test]
    fn update_64() {
        let packed = PackedU256 {
            data: 0x4444444444444444333333333333333322222222222222221111111111111111
        };
        let mut i = 0;
        while (i < 4) {
            let updated = packed.update_64(i, 0x123456789ABCDEF0);
            let mut j = 0;
            while (j < 4) {
                if (j == i) {
                    assert_eq!(updated.get_u64(j), 0x123456789ABCDEF0);
                } else {
                    assert_eq!(updated.get_u64(j), packed.get_u64(j));
                }
                j += 1;
            };
            i += 1;
        };
    }

    #[test]
    #[should_panic(expected: ('Index out of bounds',))]
    fn update_64_out_of_bounds() {
        let packed = PackedU256 {
            data: 0x4444444444444444333333333333333322222222222222221111111111111111
        };
        packed.update_64(4, 0x123456789ABCDEF0);
    }

    #[test]
    fn sub_u64() {
        let packed = PackedU256 {
            data: 0x4444444444444444333333333333333322222222222222221111111111111111
        };
        let base_hex = 0x1111111111111111;
        let mut i = 0;
        while (i < 4) {
            let updated = packed.sub_u64(i, base_hex * i.into());
            let mut j = 0;
            while (j < 4) {
                if (j == i) {
                    assert_eq!(updated.get_u64(j), base_hex);
                } else {
                    assert_eq!(updated.get_u64(j), packed.get_u64(j));
                }
                j += 1;
            };
            i += 1;
        };
    }

    #[test]
    #[should_panic(expected: ('Index out of bounds',))]
    fn sub_u64_out_of_bounds() {
        let packed = PackedU256 {
            data: 0x4444444444444444333333333333333322222222222222221111111111111111
        };
        packed.sub_u64(4, 0x1111111111111111);
    }

    #[test]
    #[should_panic(expected: ('u64_sub Overflow',))]
    fn sub_u64_overflow() {
        let packed = PackedU256 {
            data: 0x4444444444444444333333333333333322222222222222221111111111111111
        };
        packed.sub_u64(0, 0x1111111111111112);
    }
}
