use clober_cairo::libraries::total_claimable_map::TotalClaimableMapImpl;
use clober_cairo::libraries::tick::Tick;
use clober_cairo::utils::constants::{MIN_TICK, MAX_TICK};

#[test]
fn test_add() {
    let mut totalClaimableMap: Felt252Dict<felt252> = Default::default();

    TotalClaimableMapImpl::add(ref totalClaimableMap, Tick { value: MAX_TICK }, 412443);
    TotalClaimableMapImpl::add(ref totalClaimableMap, Tick { value: 102 }, 202);
    TotalClaimableMapImpl::add(ref totalClaimableMap, Tick { value: 101 }, 201);
    TotalClaimableMapImpl::add(ref totalClaimableMap, Tick { value: 100 }, 4611686018427387903);
    TotalClaimableMapImpl::add(ref totalClaimableMap, Tick { value: 1 }, 321);
    TotalClaimableMapImpl::add(ref totalClaimableMap, Tick { value: 0 }, 123);
    TotalClaimableMapImpl::add(ref totalClaimableMap, Tick { value: -1 }, 111);
    TotalClaimableMapImpl::add(ref totalClaimableMap, Tick { value: -420 }, 0);
    TotalClaimableMapImpl::add(ref totalClaimableMap, Tick { value: MIN_TICK }, 412447);

    assert_eq!(
        TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: MAX_TICK }), 412443
    );
    assert_eq!(TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: 102 }), 202);
    assert_eq!(TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: 101 }), 201);
    assert_eq!(
        TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: 100 }), 4611686018427387903
    );
    assert_eq!(TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: 1 }), 321);
    assert_eq!(TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: 0 }), 123);
    assert_eq!(TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: -1 }), 111);
    assert_eq!(TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: -420 }), 0);
    assert_eq!(
        TotalClaimableMapImpl::get(ref totalClaimableMap, Tick { value: MIN_TICK }), 412447
    );
}
