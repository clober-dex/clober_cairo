use starknet::ContractAddress;
use clober_cairo::libraries::book_key::BookKey;
use clober_cairo::libraries::tick::Tick;

#[derive(Drop, Serde)]
pub struct MakeParams {
    pub key: BookKey,
    pub tick: Tick,
    pub unit: u64,
    pub provider: ContractAddress,
}

#[derive(Drop, Serde)]
pub struct TakeParams {
    pub key: BookKey,
    pub tick: Tick,
    pub max_unit: u64,
}

#[derive(Drop, Serde)]
pub struct CancelParams {
    pub id: felt252,
    pub to_unit: u64,
}

#[derive(Drop, Serde)]
pub struct OrderInfo {
    pub provider: ContractAddress,
    pub open: u64,
    pub cliamable: u64,
}
