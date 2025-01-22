use starknet::storage_access::{StorePacking};
use starknet::ContractAddress;
use clober_cairo::utils::constants::{TWO_POW_64, TWO_POW_128};

#[derive(Drop)]
pub struct Order {
    pub provider: ContractAddress,
    pub pending: u64,
    pub initial: u64,
    pub canceled: u64,
}

pub impl OrderStorePacking of StorePacking<Order, [felt252; 2]> {
    fn pack(value: Order) -> [felt252; 2] {
        let packed: felt252 = value.pending.into()
            + value.initial.into() * TWO_POW_64.into()
            + value.canceled.into() * TWO_POW_128.try_into().unwrap();
        [value.provider.into(), packed]
    }

    fn unpack(value: [felt252; 2]) -> Order {
        let v = value.span();
        let packed: u256 = (*v[1]).into();
        let pending = packed % TWO_POW_64.into();
        let initial = (packed / TWO_POW_64.into()) % TWO_POW_64.into();
        let canceled = (packed / TWO_POW_128) % TWO_POW_64.into();

        Order {
            provider: (*v[0]).try_into().unwrap(),
            pending: pending.try_into().unwrap(),
            initial: initial.try_into().unwrap(),
            canceled: canceled.try_into().unwrap(),
        }
    }
}
