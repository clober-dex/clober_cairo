use starknet::ContractAddress;
use clober_cairo::libraries::tick::Tick;
use clober_cairo::libraries::book_key::BookKey;

#[derive(Serde, Drop, Copy)]
pub enum Actions {
    Open,
    Make,
    Limit,
    Take,
    Spend,
    Cancel,
    Claim,
}

pub mod Errors {
    pub const INVALID_CALLER: felt252 = 'Invalid caller';
    pub const INVALID_LOCK_CALLER: felt252 = 'Invalid lock caller';
    pub const UNAUTHORIZED: felt252 = 'Unauthorized';
    pub const DEADLINE: felt252 = 'Deadline';
    pub const SLIPPAGE: felt252 = 'Slippage';
}

#[starknet::interface]
pub trait IController<TContractState> {
    fn get_depth(self: @TContractState, book_id: felt252, tick: Tick,) -> u64;

    fn get_highest_price(self: @TContractState, book_id: felt252,) -> u256;

    fn get_order(self: @TContractState, order_id: felt252,) -> (ContractAddress, u256, u256, u256);

    fn from_price(self: @TContractState, price: u256) -> Tick;

    fn to_price(self: @TContractState, tick: Tick) -> u256;

    fn open(
        ref self: TContractState, book_key: BookKey, hook_data: Span<felt252>, deadline: u64
    ) -> felt252;

    fn make(
        ref self: TContractState,
        book_id: felt252,
        tick: Tick,
        quote_amount: u256,
        hook_data: Span<felt252>,
        deadline: u64
    ) -> felt252;

    fn limit(
        ref self: TContractState,
        take_book_id: felt252,
        make_book_id: felt252,
        limit_price: u256,
        tick: Tick,
        quote_amount: u256,
        take_hook_data: Span<felt252>,
        make_hook_data: Span<felt252>,
        deadline: u64
    ) -> felt252;

    fn take(
        ref self: TContractState,
        book_id: felt252,
        limit_price: u256,
        quote_amount: u256,
        max_base_amount: u256,
        hook_data: Span<felt252>,
        deadline: u64
    );

    fn spend(
        ref self: TContractState,
        book_id: felt252,
        limit_price: u256,
        base_amount: u256,
        min_quote_amount: u256,
        hook_data: Span<felt252>,
        deadline: u64
    );

    fn claim(ref self: TContractState, order_id: felt252, hook_data: Span<felt252>, deadline: u64);

    fn cancel(
        ref self: TContractState,
        order_id: felt252,
        left_quote_amount: u256,
        hook_data: Span<felt252>,
        deadline: u64
    );
}
