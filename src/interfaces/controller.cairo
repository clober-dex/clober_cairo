use starknet::ContractAddress;
use clober_cairo::libraries::tick::Tick;
use clober_cairo::libraries::book_key::BookKey;

#[starknet::interface]
pub trait IController<TContractState> {
    fn get_depth(self: @TContractState, book_id: felt252, tick: Tick,) -> u64;

    fn get_highest_price(self: @TContractState, book_id: felt252,) -> u256;

    fn get_order(self: @TContractState, order_id: felt252,) -> (ContractAddress, u256, u256, u256);

    fn from_price(self: @TContractState, price: u256) -> Tick;

    fn to_price(self: @TContractState, tick: Tick) -> u256;

    fn open(ref self: TContractState, book_key: BookKey, hook_data: Span<felt252>) -> felt252;

    fn make(
        ref self: TContractState,
        book_id: felt252,
        tick: Tick,
        quote_amount: u256,
        hook_data: Span<felt252>
    ) -> u256;

    fn take(
        ref self: TContractState,
        book_id: felt252,
        limit_price: u256,
        quote_amount: u256,
        max_base_amount: u256,
        hook_data: Span<felt252>
    );

    fn spend(
        ref self: TContractState,
        book_id: felt252,
        limit_price: u256,
        base_amount: u256,
        min_quote_amount: u256,
        hook_data: Span<felt252>
    );
}
