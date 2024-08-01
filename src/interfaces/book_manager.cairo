use starknet::{ContractAddress};
use clober_cairo::libraries::book_key::BookKey;
use clober_cairo::interfaces::params::{MakeParams, TakeParams, CancelParams};

#[starknet::interface]
pub trait IBookManager<TContractState> {
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
