use clober_cairo::libraries::total_claimable_map::{get, add, sub};
use clober_cairo::libraries::storage_map::{Felt252Map, Felt252MapTrait};
use starknet::storage_access::storage_base_address_from_felt252;
use clober_cairo::libraries::tick::Tick;
use clober_cairo::utils::constants::{MIN_TICK, MAX_TICK};

#[test]
fn test_add() {
    let mut totalClaimableMap: Felt252Map<felt252> = Felt252MapTrait::fetch(
        0, storage_base_address_from_felt252(0x87654321)
    );

    add(ref totalClaimableMap, Tick { value: MAX_TICK }, 412443);
    add(ref totalClaimableMap, Tick { value: 102 }, 202);
    add(ref totalClaimableMap, Tick { value: 101 }, 201);
    add(ref totalClaimableMap, Tick { value: 100 }, 4611686018427387903);
    add(ref totalClaimableMap, Tick { value: 1 }, 321);
    add(ref totalClaimableMap, Tick { value: 0 }, 123);
    add(ref totalClaimableMap, Tick { value: -1 }, 111);
    add(ref totalClaimableMap, Tick { value: -420 }, 0);
    add(ref totalClaimableMap, Tick { value: MIN_TICK }, 412447);

    assert_eq!(get(ref totalClaimableMap, Tick { value: MAX_TICK }), 412443);
    assert_eq!(get(ref totalClaimableMap, Tick { value: 102 }), 202);
    assert_eq!(get(ref totalClaimableMap, Tick { value: 101 }), 201);
    assert_eq!(get(ref totalClaimableMap, Tick { value: 100 }), 4611686018427387903);
    assert_eq!(get(ref totalClaimableMap, Tick { value: 1 }), 321);
    assert_eq!(get(ref totalClaimableMap, Tick { value: 0 }), 123);
    assert_eq!(get(ref totalClaimableMap, Tick { value: -1 }), 111);
    assert_eq!(get(ref totalClaimableMap, Tick { value: -420 }), 0);
    assert_eq!(get(ref totalClaimableMap, Tick { value: MIN_TICK }), 412447);
}
