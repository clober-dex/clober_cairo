use starknet::ContractAddress;
use clober_cairo::libraries::tick::Tick;

#[derive(Copy, Drop, Serde)]
pub struct Liquidity {
    pub tick: Tick,
    pub depth: u64,
}

#[starknet::interface]
pub trait IBookViewer<TContractState> {
    fn book_manager(self: @TContractState) -> ContractAddress;

    fn get_liquidity(
        self: @TContractState, book_id: felt252, tick: Tick, n: u32,
    ) -> Span<Liquidity>;

    fn get_expected_input(
        self: @TContractState,
        book_id: felt252,
        limit_price: u256,
        quote_amount: u256,
        max_base_amount: u256,
        hook_data: Span<felt252>,
    ) -> (u256, u256);

    fn get_expected_output(
        self: @TContractState,
        book_id: felt252,
        limit_price: u256,
        base_amount: u256,
        min_quote_amount: u256,
        hook_data: Span<felt252>,
    ) -> (u256, u256);
}
