use clober_cairo::libraries::tick::Tick;
use clober_cairo::libraries::packed_felt252::update_62;
use clober_cairo::libraries::packed_felt252::get_u62;
use clober_cairo::libraries::packed_felt252::add_u62;
use clober_cairo::libraries::packed_felt252::sub_u62;

#[generate_trait]
impl TotalClaimableMapImpl of TotalClaimableMapTrait {
    fn get(mut totalClaimableMap: Felt252Dict<felt252>, tick: Tick) -> u64 {
        let (groupIndex, elementIndex) = Self::_split_tick(tick);
        get_u62(totalClaimableMap[groupIndex], elementIndex)
    }

    fn add(mut totalClaimableMap: Felt252Dict<felt252>, tick: Tick, n: u64) {
        let (groupIndex, elementIndex) = Self::_split_tick(tick);
        let group = totalClaimableMap[groupIndex];
        totalClaimableMap.insert(groupIndex, add_u62(group, elementIndex, n));
    }

    fn sub(mut totalClaimableMap: Felt252Dict<felt252>, tick: Tick, n: u64) {
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

