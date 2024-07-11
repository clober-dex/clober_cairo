use starknet::{ContractAddress};
use clober_cairo::libraries::book_key::BookKey;
use clober_cairo::interfaces::params::{MakeParams, TakeParams, CancelParams};

#[starknet::interface]
trait IBookManager<TContractState> {
    fn open(ref self: TContractState, key: BookKey, hook_data: Span<felt252>);
    fn lock(ref self: TContractState, locker: ContractAddress, data: Span<felt252>);
    fn make(
        ref self: TContractState, params: MakeParams, hook_data: Span<felt252>
    ) -> (felt252, u256);
    fn take(ref self: TContractState, params: TakeParams, hook_data: Span<felt252>) -> (u256, u256);
    fn cancel(ref self: TContractState, params: CancelParams, hook_data: Span<felt252>) -> u256;
    fn claim(ref self: TContractState, id: felt252, hook_data: Span<felt252>) -> u256;
    fn collect(ref self: TContractState, recipient: ContractAddress, currency: ContractAddress);
    fn withdraw(ref self: TContractState, to: ContractAddress, amount: u256);
    fn settle(ref self: TContractState, currency: ContractAddress);
    fn whitelist(ref self: TContractState, provider: ContractAddress);
    fn delist(ref self: TContractState, provider: ContractAddress);
    fn set_default_provider(ref self: TContractState, new_default_provider: ContractAddress);
}

#[starknet::contract]
pub mod BookManager {
    use clober_cairo::components::currency_delta::CurrencyDelta;
    use clober_cairo::components::hook_caller::HookCaller;
    use clober_cairo::components::lockers::Lockers;
    use super::{ContractAddress, BookKey, MakeParams, TakeParams, CancelParams};

    component!(path: CurrencyDelta, storage: currency_delta, event: CurrencyDeltaEvent);
    component!(path: HookCaller, storage: hook_caller, event: HookCallerEvent);
    component!(path: Lockers, storage: lockers, event: LockersEvent);

    #[abi(embed_v0)]
    impl CurrencyDeltaImpl = CurrencyDelta::CurrencyDeltaImpl<ContractState>;
    impl CurrencyDeltaInternalImpl = CurrencyDelta::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl HookCallerImpl = HookCaller::HookCallerImpl<ContractState>;
    impl HookCallerInternalImpl = HookCaller::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl LockersImpl = Lockers::LockersImpl<ContractState>;
    impl LockersInternalImpl = Lockers::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        currency_delta: CurrencyDelta::Storage,
        #[substorage(v0)]
        hook_caller: HookCaller::Storage,
        #[substorage(v0)]
        lockers: Lockers::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        CurrencyDeltaEvent: CurrencyDelta::Event,
        #[flat]
        HookCallerEvent: HookCaller::Event,
        #[flat]
        LockersEvent: Lockers::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        base_uri: ByteArray,
        contract_uri: ByteArray,
        name: felt252,
        symbol: felt252,
    ) {}

    #[external(v0)]
    fn hi(self: @ContractState) {
        panic!("Not implemented");
    }

    #[abi(embed_v0)]
    impl BookManagerImpl of super::IBookManager<ContractState> {
        fn open(ref self: ContractState, key: BookKey, hook_data: Span<felt252>) {
            panic!("Not implemented");
        }

        fn lock(ref self: ContractState, locker: ContractAddress, data: Span<felt252>) {
            panic!("Not implemented");
        }

        fn make(
            ref self: ContractState, params: MakeParams, hook_data: Span<felt252>
        ) -> (felt252, u256) {
            panic!("Not implemented");
            (0, 0)
        }

        fn take(
            ref self: ContractState, params: TakeParams, hook_data: Span<felt252>
        ) -> (u256, u256) {
            panic!("Not implemented");
            (0, 0)
        }

        fn cancel(ref self: ContractState, params: CancelParams, hook_data: Span<felt252>) -> u256 {
            panic!("Not implemented");
            0
        }

        fn claim(ref self: ContractState, id: felt252, hook_data: Span<felt252>) -> u256 {
            panic!("Not implemented");
            0
        }

        fn collect(ref self: ContractState, recipient: ContractAddress, currency: ContractAddress) {
            panic!("Not implemented");
        }

        fn withdraw(ref self: ContractState, to: ContractAddress, amount: u256) {
            panic!("Not implemented");
        }

        fn settle(ref self: ContractState, currency: ContractAddress) {
            panic!("Not implemented");
        }

        fn whitelist(ref self: ContractState, provider: ContractAddress) {
            panic!("Not implemented");
        }

        fn delist(ref self: ContractState, provider: ContractAddress) {
            panic!("Not implemented");
        }

        fn set_default_provider(ref self: ContractState, new_default_provider: ContractAddress) {
            panic!("Not implemented");
        }
    }
}
