use clober_cairo::libraries::tick::Tick;
use clober_cairo::utils::packed_felt252::update_62;
use clober_cairo::utils::packed_felt252::get_u62;
use clober_cairo::utils::packed_felt252::add_u62;
use clober_cairo::utils::packed_felt252::sub_u62;
use clober_cairo::libraries::storage_map::{Felt252Map, Felt252MapTrait};

pub fn get(ref totalClaimableMap: Felt252Map<felt252>, tick: Tick) -> u64 {
    let (groupIndex, elementIndex) = _split_tick(tick);
    get_u62(totalClaimableMap.read_at(groupIndex), elementIndex)
}

pub fn add(ref totalClaimableMap: Felt252Map<felt252>, tick: Tick, n: u64) {
    let (groupIndex, elementIndex) = _split_tick(tick);
    let group = totalClaimableMap.read_at(groupIndex);
    totalClaimableMap.write_at(groupIndex, add_u62(group, elementIndex, n));
}

pub fn sub(ref totalClaimableMap: Felt252Map<felt252>, tick: Tick, n: u64) {
    let (groupIndex, elementIndex) = _split_tick(tick);
    let group = totalClaimableMap.read_at(groupIndex);
    totalClaimableMap.write_at(groupIndex, sub_u62(group, elementIndex, n));
}

fn _split_tick(tick: Tick) -> (felt252, u8) {
    let value: u32 = (tick.into() + 0x80000).try_into().unwrap();
    let groupIndex: felt252 = (value / 4).into();
    let elementIndex: u8 = (value % 4).try_into().unwrap();
    (groupIndex, elementIndex)
}
