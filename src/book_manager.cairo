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
    use starknet::storage::Map;
    use clober_cairo::components::currency_delta::CurrencyDelta;
    use clober_cairo::components::hook_caller::HookCaller;
    use clober_cairo::components::lockers::Lockers;
    use clober_cairo::libraries::fee_policy::FeePolicy;
    use clober_cairo::libraries::tick::Tick;
    use super::{ContractAddress, BookKey, MakeParams, TakeParams, CancelParams};

    component!(path: CurrencyDelta, storage: currency_delta, event: CurrencyDeltaEvent);
    component!(path: HookCaller, storage: hook_caller, event: HookCallerEvent);
    component!(path: Lockers, storage: lockers, event: LockersEvent);

    #[abi(embed_v0)]
    impl CurrencyDeltaImpl = CurrencyDelta::CurrencyDelta<ContractState>;
    impl CurrencyDeltaInternalImpl = CurrencyDelta::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl HookCallerImpl = HookCaller::HookCaller<ContractState>;
    impl HookCallerInternalImpl = HookCaller::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl LockersImpl = Lockers::Lockers<ContractState>;
    impl LockersInternalImpl = Lockers::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        currency_delta: CurrencyDelta::Storage,
        #[substorage(v0)]
        hook_caller: HookCaller::Storage,
        #[substorage(v0)]
        lockers: Lockers::Storage,
        contract_uri: ByteArray,
        default_provier: ContractAddress,
        reserves_of: Map<ContractAddress, u256>,
        is_whitelisted: Map<ContractAddress, bool>,
        token_owed: Map<(ContractAddress, ContractAddress), u256>,
    }

    #[derive(Drop, starknet::Event)]
    struct Open {
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
    struct Make {
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
    struct Take {
        #[key]
        pub book_id: felt252,
        #[key]
        pub user: ContractAddress,
        pub tick: i32,
        pub unit: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct Cancel {
        #[key]
        pub order_id: felt252,
        pub unit: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct Claim {
        #[key]
        pub order_id: felt252,
        pub unit: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct Collect {
        #[key]
        pub provider: ContractAddress,
        #[key]
        pub recipient: ContractAddress,
        #[key]
        pub currency: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Whitelist {
        #[key]
        pub provider: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct Delist {
        #[key]
        pub provider: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct SetDefaultProvider {
        #[key]
        pub provider: ContractAddress,
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
        Open: Open,
        Make: Make,
        Take: Take,
        Cancel: Cancel,
        Claim: Claim,
        Collect: Collect,
        Whitelist: Whitelist,
        Delist: Delist,
        SetDefaultProvider: SetDefaultProvider,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        base_uri: ByteArray,
        contract_uri: ByteArray,
        name: felt252,
        symbol: felt252,
    ) {
        self.contract_uri.write(contract_uri);
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
