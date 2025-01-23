use starknet::ContractAddress;
use clober_cairo::libraries::book_key::BookKey;
use clober_cairo::libraries::tick::Tick;
use clober_cairo::libraries::i257::i257;
use clober_cairo::libraries::fee_policy::FeePolicy;

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

#[derive(Copy, Drop, Serde)]
pub struct OrderInfo {
    pub id: felt252,
    pub provider: ContractAddress,
    pub open: u64,
    pub claimable: u64,
    pub initial: u64,
    pub canceled: u64,
}

#[derive(Drop, starknet::Event)]
pub struct Open {
    #[key]
    pub id: felt252,
    #[key]
    pub base: ContractAddress,
    #[key]
    pub quote: ContractAddress,
    pub unit_size: u64,
    pub maker_policy: FeePolicy,
    pub taker_policy: FeePolicy,
    pub hooks: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct Make {
    #[key]
    pub book_id: felt252,
    #[key]
    pub user: ContractAddress,
    pub tick: i32,
    pub order_index: u64,
    pub unit: u64,
    pub provider: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct Take {
    #[key]
    pub book_id: felt252,
    #[key]
    pub user: ContractAddress,
    pub tick: i32,
    pub unit: u64,
}

#[derive(Drop, starknet::Event)]
pub struct Cancel {
    #[key]
    pub order_id: felt252,
    pub unit: u64,
}

#[derive(Drop, starknet::Event)]
pub struct Claim {
    #[key]
    pub order_id: felt252,
    pub unit: u64,
}

#[derive(Drop, starknet::Event)]
pub struct Collect {
    #[key]
    pub provider: ContractAddress,
    #[key]
    pub recipient: ContractAddress,
    #[key]
    pub currency: ContractAddress,
    pub amount: u256,
}

#[derive(Drop, starknet::Event)]
pub struct Whitelist {
    #[key]
    pub provider: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct Delist {
    #[key]
    pub provider: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct SetDefaultProvider {
    #[key]
    pub provider: ContractAddress,
}

pub mod Errors {
    pub const INVALID_UNIT_SIZE: felt252 = 'Invalid unit size';
    pub const INVALID_FEE_POLICY: felt252 = 'Invalid fee policy';
    pub const INVALID_PROVIDER: felt252 = 'Invalid provider';
    pub const INVALID_LOCKER: felt252 = 'Invalid locker';
    pub const INVALID_HOOKS: felt252 = 'Invalid hooks';
    pub const BOOK_ALREADY_OPENED: felt252 = 'Book already opened';
    pub const BOOK_NOT_OPENED: felt252 = 'Book not opened';
    pub const CURRENCY_NOT_SETTLED: felt252 = 'Currency not settled';
    pub const ERC20_TRANSFER_FAILED: felt252 = 'ERC20 transfer failed';
}

#[starknet::interface]
pub trait IBookManager<TContractState> {
    fn base_uri(self: @TContractState) -> ByteArray;
    fn contract_uri(self: @TContractState) -> ByteArray;
    fn default_provider(self: @TContractState) -> ContractAddress;
    fn reserves_of(self: @TContractState, currency: ContractAddress) -> u256;
    fn is_whitelisted(self: @TContractState, provider: ContractAddress) -> bool;
    fn check_authorized(
        self: @TContractState, owner: ContractAddress, spender: ContractAddress, token_id: felt252,
    );
    fn token_owed(self: @TContractState, owner: ContractAddress, currency: ContractAddress) -> u256;
    fn get_lock(self: @TContractState, i: u32) -> (ContractAddress, ContractAddress);
    fn get_lock_data(self: @TContractState) -> (u32, u128);
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
    fn open(ref self: TContractState, key: BookKey, hook_data: Span<felt252>) -> felt252;
    fn lock(
        ref self: TContractState, locker: ContractAddress, data: Span<felt252>,
    ) -> Span<felt252>;
    fn make(
        ref self: TContractState, params: MakeParams, hook_data: Span<felt252>,
    ) -> (felt252, u256);
    fn take(ref self: TContractState, params: TakeParams, hook_data: Span<felt252>) -> (u256, u256);
    fn cancel(ref self: TContractState, params: CancelParams, hook_data: Span<felt252>) -> u256;
    fn claim(ref self: TContractState, id: felt252, hook_data: Span<felt252>) -> u256;
    fn collect(
        ref self: TContractState, recipient: ContractAddress, currency: ContractAddress,
    ) -> u256;
    fn withdraw(
        ref self: TContractState, currency: ContractAddress, to: ContractAddress, amount: u256,
    );
    fn settle(ref self: TContractState, currency: ContractAddress) -> u256;
    fn whitelist(ref self: TContractState, provider: ContractAddress);
    fn delist(ref self: TContractState, provider: ContractAddress);
    fn set_default_provider(ref self: TContractState, new_default_provider: ContractAddress);

    fn all_tokens_of_owner(self: @TContractState, owner: ContractAddress) -> Span<u256>;
    fn all_orders_of_owner(self: @TContractState, owner: ContractAddress) -> Span<OrderInfo>;
}
