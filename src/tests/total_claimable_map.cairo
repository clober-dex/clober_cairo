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

    add(ref totalClaimableMap, MAX_TICK.into(), 412443);
    add(ref totalClaimableMap, 102_i32.into(), 202);
    add(ref totalClaimableMap, 101_i32.into(), 201);
    add(ref totalClaimableMap, 100_i32.into(), 4611686018427387903);
    add(ref totalClaimableMap, 1_i32.into(), 321);
    add(ref totalClaimableMap, 0_i32.into(), 123);
    add(ref totalClaimableMap, (-1_i32).into(), 111);
    add(ref totalClaimableMap, (-420_i32).into(), 0);
    add(ref totalClaimableMap, MIN_TICK.into(), 412447);

    assert_eq!(get(ref totalClaimableMap, MAX_TICK.into()), 412443);
    assert_eq!(get(ref totalClaimableMap, 102_i32.into()), 202);
    assert_eq!(get(ref totalClaimableMap, 101_i32.into()), 201);
    assert_eq!(get(ref totalClaimableMap, 100_i32.into()), 4611686018427387903);
    assert_eq!(get(ref totalClaimableMap, 1_i32.into()), 321);
    assert_eq!(get(ref totalClaimableMap, 0_i32.into()), 123);
    assert_eq!(get(ref totalClaimableMap, (-1_i32).into()), 111);
    assert_eq!(get(ref totalClaimableMap, (-420_i32).into()), 0);
    assert_eq!(get(ref totalClaimableMap, MIN_TICK.into()), 412447);
}
