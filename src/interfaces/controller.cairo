use starknet::ContractAddress;
use clober_cairo::libraries::tick::Tick;

#[starknet::interface]
pub trait IController<TContractState> {
    fn get_depth(self: @TContractState, book_id: felt252, tick: Tick,) -> u64;

    fn get_highest_price(self: @TContractState, book_id: felt252,) -> u256;

    fn get_order(self: @TContractState, order_id: felt252,) -> (ContractAddress, u256, u256, u256);

    fn from_price(self: @TContractState, price: u256) -> Tick;

    fn to_price(self: @TContractState, tick: Tick) -> u256;
}
