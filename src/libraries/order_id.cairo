use starknet::storage_access::{StorePacking};
use clober_cairo::utils::constants::{TWO_POW_192, TWO_POW_64, TWO_POW_40};
use clober_cairo::libraries::tick::Tick;

#[derive(Drop, Copy)]
pub struct OrderId {
    pub book_id: felt252, // u187
    pub tick: Tick, // i24
    pub index: u64, // u40
}

#[generate_trait]
pub impl OrderIdImpl of OrderIdTrait {
    fn encode(self: OrderId) -> felt252 {
        assert(self.book_id.into() < TWO_POW_192, 'book_id overflow');
        assert(self.index < TWO_POW_40, 'index overflow');
        let t = if (self.tick.into() < 0_i32) {
            0x1000000 + self.tick.into()
        } else {
            self.tick.into()
        };
        assert(t < 0x1000000_i32, 'tick overflow');
        return self.book_id * TWO_POW_64.into() + t.into() * TWO_POW_40.into() + self.index.into();
    }

    fn decode(value: felt252) -> OrderId {
        let casted_value: u256 = value.into();
        let book_id: u256 = casted_value / TWO_POW_64.into();
        let tick_felt252: felt252 = (casted_value % TWO_POW_64.into() / TWO_POW_40.into())
            .try_into()
            .unwrap();
        let tick_i32: i32 = if (tick_felt252.into() < 0x800000_u256) {
            tick_felt252.try_into().unwrap()
        } else {
            -(0x1000000 - tick_felt252).try_into().unwrap()
        };
        let index: u64 = (casted_value % TWO_POW_40.into()).try_into().unwrap();
        OrderId { book_id: book_id.try_into().unwrap(), tick: tick_i32.into(), index }
    }
}

pub impl OrderIdStoragePacking of StorePacking<OrderId, felt252> {
    fn pack(value: OrderId) -> felt252 {
        value.encode()
    }

    fn unpack(value: felt252) -> OrderId {
        OrderIdImpl::decode(value)
    }
}
