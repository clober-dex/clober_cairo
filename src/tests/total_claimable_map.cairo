use clober_cairo::libraries::total_claimable_map::TotalClaimableMapImpl;
use clober_cairo::libraries::tick::Tick;

#[test]
fn test_add() {
    let mut totalClaimableMap: Felt252Dict<felt252> = Default::default();

    TotalClaimableMapImpl::add(ref totalClaimableMap, Tick { value: 2147483647 }, 412443);
    TotalClaimableMapImpl::add(ref totalClaimableMap, Tick { value: 102 }, 202);
    TotalClaimableMapImpl::add(ref totalClaimableMap, Tick { value: 101 }, 201);
    TotalClaimableMapImpl::add(ref totalClaimableMap, Tick { value: 100 }, 18446744073709551615);
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
        TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: 100 }), 18446744073709551615
    );
    assert_eq!(TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: 1 }), 321);
    assert_eq!(TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: 0 }), 123);
    assert_eq!(TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: -1 }), 111);
    assert_eq!(TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: -420 }), 0);
    assert_eq!(
        TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: -2147483648 }), 412447
    );
}
