use starknet::ContractAddress;
use clober_cairo::libraries::book_key::BookKey;
use clober_cairo::libraries::tick::Tick;

#[derive(Copy, Drop, Serde)]
pub struct MakeParams {
    pub key: BookKey,
    pub tick: Tick,
    pub unit: u64,
    pub provider: ContractAddress,
}

#[derive(Copy, Drop, Serde)]
pub struct TakeParams {
    pub key: BookKey,
    pub tick: Tick,
    pub max_unit: u64,
}

#[derive(Copy, Drop, Serde)]
pub struct CancelParams {
    pub id: felt252,
    pub to_unit: u64,
}
