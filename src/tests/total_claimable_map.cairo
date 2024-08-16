use clober_cairo::libraries::total_claimable_map::{TotalClaimableOf, TotalClaimableOfTrait};
use clober_cairo::libraries::storage_map::{Felt252Map, Felt252MapTrait};
use starknet::storage_access::storage_base_address_from_felt252;
use clober_cairo::libraries::tick::Tick;
use clober_cairo::utils::constants::{MIN_TICK, MAX_TICK};

#[test]
fn test_add() {
    let mut totalClaimableMap = Felt252MapTrait::fetch(
        0, storage_base_address_from_felt252(0x87654321)
    );

    totalClaimableMap.add(MAX_TICK.into(), 412443);
    totalClaimableMap.add(102_i32.into(), 202);
    totalClaimableMap.add(101_i32.into(), 201);
    totalClaimableMap.add(100_i32.into(), 4611686018427387903);
    totalClaimableMap.add(1_i32.into(), 321);
    totalClaimableMap.add(0_i32.into(), 123);
    totalClaimableMap.add((-1_i32).into(), 111);
    totalClaimableMap.add((-420_i32).into(), 0);
    totalClaimableMap.add(MIN_TICK.into(), 412447);

    assert_eq!(totalClaimableMap.get(MAX_TICK.into()), 412443);
    assert_eq!(totalClaimableMap.get(102_i32.into()), 202);
    assert_eq!(totalClaimableMap.get(101_i32.into()), 201);
    assert_eq!(totalClaimableMap.get(100_i32.into()), 4611686018427387903);
    assert_eq!(totalClaimableMap.get(1_i32.into()), 321);
    assert_eq!(totalClaimableMap.get(0_i32.into()), 123);
    assert_eq!(totalClaimableMap.get((-1_i32).into()), 111);
    assert_eq!(totalClaimableMap.get((-420_i32).into()), 0);
    assert_eq!(totalClaimableMap.get(MIN_TICK.into()), 412447);
}
