use clober_cairo::libraries::tick::Tick;
use clober_cairo::libraries::packed_felt252::update_62;
use clober_cairo::libraries::packed_felt252::get_u62;
use clober_cairo::libraries::packed_felt252::add_u62;
use clober_cairo::libraries::packed_felt252::sub_u62;

#[generate_trait]
impl TotalClaimableMapImpl of TotalClaimableMapTrait {
    fn get(ref totalClaimableMap: Felt252Dict<felt252>, tick: Tick) -> u64 {
        let (groupIndex, elementIndex) = Self::_split_tick(tick);
        get_u62(totalClaimableMap[groupIndex], elementIndex)
    }

    fn add(ref totalClaimableMap: Felt252Dict<felt252>, tick: Tick, n: u64) {
        let (groupIndex, elementIndex) = Self::_split_tick(tick);
        let group = totalClaimableMap[groupIndex];
        totalClaimableMap.insert(groupIndex, add_u62(group, elementIndex, n));
    }

    fn sub(ref totalClaimableMap: Felt252Dict<felt252>, tick: Tick, n: u64) {
        let (groupIndex, elementIndex) = Self::_split_tick(tick);
        let group = totalClaimableMap[groupIndex];
        totalClaimableMap.insert(groupIndex, sub_u62(group, elementIndex, n));
    }

    fn _split_tick(tick: Tick) -> (felt252, u8) {
        let groupIndex: felt252 = (tick.value / 4).into();
        let elementIndex: u8 = (tick.value % 4).try_into().unwrap();
        (groupIndex, elementIndex)
    }
}

#[cfg(test)]
mod tests {
    use super::TotalClaimableMapImpl;
    use clober_cairo::libraries::tick::Tick;

    #[test]
    fn test_add() {
        let mut totalClaimableMap: Felt252Dict<felt252> = Default::default();

        TotalClaimableMapImpl::add(ref totalClaimableMap, Tick { value: 2147483647 }, 412443);
        TotalClaimableMapImpl::add(ref totalClaimableMap, Tick { value: 102 }, 202);
        TotalClaimableMapImpl::add(ref totalClaimableMap, Tick { value: 101 }, 201);
        TotalClaimableMapImpl::add(
            ref totalClaimableMap, Tick { value: 100 }, 18446744073709551615
        );
        TotalClaimableMapImpl::add(ref totalClaimableMap, Tick { value: 1 }, 321);
        TotalClaimableMapImpl::add(ref totalClaimableMap, Tick { value: 0 }, 123);
        TotalClaimableMapImpl::add(ref totalClaimableMap, Tick { value: -1 }, 111);
        TotalClaimableMapImpl::add(ref totalClaimableMap, Tick { value: -420 }, 0);
        TotalClaimableMapImpl::add(ref totalClaimableMap, Tick { value: -2147483648 }, 412447);

        assert_eq!(
            TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: 2147483647 }), 412443
        );
        assert_eq!(TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: 102 }), 202);
        assert_eq!(TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: 101 }), 201);
        assert_eq!(
            TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: 100 }),
            18446744073709551615
        );
        assert_eq!(TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: 1 }), 321);
        assert_eq!(TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: 0 }), 123);
        assert_eq!(TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: -1 }), 111);
        assert_eq!(TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: -420 }), 0);
        assert_eq!(
            TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: -2147483648 }), 412447
        );
    }
}

