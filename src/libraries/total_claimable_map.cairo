use clober_cairo::libraries::tick::Tick;
use clober_cairo::utils::packed_felt252::update_62;
use clober_cairo::utils::packed_felt252::get_u62;
use clober_cairo::utils::packed_felt252::add_u62;
use clober_cairo::utils::packed_felt252::sub_u62;
use clober_cairo::libraries::storage_map::{Felt252Map, Felt252MapTrait};

pub type TotalClaimableOf = Felt252Map<felt252>;

#[generate_trait]
pub impl TotalClaimableOfImpl of TotalClaimableOfTrait {
    fn get(self: TotalClaimableOf, tick: Tick) -> u64 {
        let (groupIndex, elementIndex) = Self::_split_tick(tick);
        get_u62(self.read_at(groupIndex), elementIndex)
    }

    fn add(ref self: TotalClaimableOf, tick: Tick, n: u64) {
        let (groupIndex, elementIndex) = Self::_split_tick(tick);
        let group = self.read_at(groupIndex);
        self.write_at(groupIndex, add_u62(group, elementIndex, n));
    }

    fn sub(ref self: TotalClaimableOf, tick: Tick, n: u64) {
        let (groupIndex, elementIndex) = Self::_split_tick(tick);
        let group = self.read_at(groupIndex);
        self.write_at(groupIndex, sub_u62(group, elementIndex, n));
    }

    fn _split_tick(tick: Tick) -> (felt252, u8) {
        let value: u32 = (tick.into() + 0x80000).try_into().unwrap();
        let groupIndex: felt252 = (value / 4).into();
        let elementIndex: u8 = (value % 4).try_into().unwrap();
        (groupIndex, elementIndex)
    }
}
