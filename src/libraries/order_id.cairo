use starknet::storage_access::{StorePacking};
use clober_cairo::utils::constants::{TWO_POW_192, TWO_POW_64, TWO_POW_40};

#[derive(Copy, Drop, Serde, Debug)]
pub struct OrderId {
    pub book_id: felt252, // u192
    pub tick: u32, // todo: change to Tick struct
    pub index: u64, // u40
}

#[generate_trait]
pub impl OrderIdImpl of OrderIdTrait {
    fn encode(self: OrderId) -> felt252 {
        assert(self.book_id.into() < TWO_POW_192, 'book_id overflow');
        assert(self.index < TWO_POW_40, 'index overflow');
        return self.book_id.try_into().unwrap() * TWO_POW_64.try_into().unwrap()
            + self.tick.into() * TWO_POW_40.try_into().unwrap()
            + self.index.into();
    }
}

pub impl OrderIdStoragePacking of StorePacking<OrderId, felt252> {
    fn pack(value: OrderId) -> felt252 {
        value.encode()
    }

    fn unpack(value: felt252) -> OrderId {
        let casted_value: u256 = value.into();
        let book_id: u256 = casted_value / TWO_POW_64.into();
        let tick_felt252: felt252 = (casted_value % TWO_POW_64.into() / TWO_POW_40.into())
            .try_into()
            .unwrap();
        let index: u64 = (casted_value % TWO_POW_40.into()).try_into().unwrap();
        OrderId {
            book_id: book_id.try_into().unwrap(), tick: tick_felt252.try_into().unwrap(), index
        }
    }
}
