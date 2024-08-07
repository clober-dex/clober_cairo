use starknet::{ContractAddress};
use clober_cairo::libraries::book_key::BookKey;
use clober_cairo::libraries::tick::Tick;
use clober_cairo::libraries::i257::i257;
use clober_cairo::interfaces::params::{OrderInfo, MakeParams, TakeParams, CancelParams};

#[starknet::interface]
pub trait IBookManager<TContractState> {
    fn base_uri(self: @TContractState) -> ByteArray;
    fn contract_uri(self: @TContractState) -> ByteArray;
    fn default_provider(self: @TContractState) -> ContractAddress;
    fn reserves_of(self: @TContractState, provider: ContractAddress) -> u256;
    fn is_whitelisted(self: @TContractState, provider: ContractAddress) -> bool;
    fn check_authorized(
        self: @TContractState, owner: ContractAddress, spender: ContractAddress, token_id: felt252
    );
    fn token_owed(
        self: @TContractState, owner: ContractAddress, currency: ContractAddress, token_id: felt252
    ) -> u256;
    fn get_current_hook(self: @TContractState) -> ContractAddress;
    fn get_hook(self: @TContractState, i: u32) -> ContractAddress;
    fn get_book_key(self: @TContractState, book_id: felt252) -> BookKey;
    fn get_currency_delta(
        self: @TContractState, locker: ContractAddress, currency: ContractAddress,
    ) -> i257;
    fn get_order(self: @TContractState, order_id: felt252) -> OrderInfo;
    fn get_depth(self: @TContractState, book_id: felt252, tick: Tick) -> u64;
    fn get_highest(self: @TContractState, book_id: felt252) -> Tick;
    fn max_less_than(self: @TContractState, book_id: felt252, tick: Tick) -> Tick;
    fn is_opened(self: @TContractState, book_id: felt252) -> bool;
    fn is_empty(self: @TContractState, book_id: felt252) -> bool;
    fn encode_book_key(self: @TContractState, book_key: BookKey) -> felt252;
    fn open(ref self: TContractState, key: BookKey, hook_data: Span<felt252>);
    fn lock(
        ref self: TContractState, locker: ContractAddress, data: Span<felt252>
    ) -> Span<felt252>;
    fn make(
        ref self: TContractState, params: MakeParams, hook_data: Span<felt252>
    ) -> (felt252, u256);
    fn take(ref self: TContractState, params: TakeParams, hook_data: Span<felt252>) -> (u256, u256);
    fn cancel(ref self: TContractState, params: CancelParams, hook_data: Span<felt252>) -> u256;
    fn claim(ref self: TContractState, id: felt252, hook_data: Span<felt252>) -> u256;
    fn collect(
        ref self: TContractState, recipient: ContractAddress, currency: ContractAddress
    ) -> u256;
    fn withdraw(
        ref self: TContractState, currency: ContractAddress, to: ContractAddress, amount: u256
    );
    fn settle(ref self: TContractState, currency: ContractAddress) -> u256;
    fn whitelist(ref self: TContractState, provider: ContractAddress);
    fn delist(ref self: TContractState, provider: ContractAddress);
    fn set_default_provider(ref self: TContractState, new_default_provider: ContractAddress);
}
