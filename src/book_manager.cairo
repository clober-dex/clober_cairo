use starknet::{ContractAddress};
use clober_cairo::libraries::book_key::BookKey;
use clober_cairo::interfaces::params::{MakeParams, TakeParams, CancelParams};

#[starknet::interface]
trait IBookManager<TContractState> {
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
    fn collect(ref self: TContractState, recipient: ContractAddress, currency: ContractAddress);
    fn withdraw(ref self: TContractState, to: ContractAddress, amount: u256);
    fn settle(ref self: TContractState, currency: ContractAddress);
    fn whitelist(ref self: TContractState, provider: ContractAddress);
    fn delist(ref self: TContractState, provider: ContractAddress);
    fn set_default_provider(ref self: TContractState, new_default_provider: ContractAddress);
}

#[starknet::contract]
pub mod BookManager {
    use core::num::traits::zero::Zero;
    use starknet::storage::Map;
    use starknet::{get_caller_address};
    use clober_cairo::interfaces::locker::{ILockerDispatcher, ILockerDispatcherTrait};
    use clober_cairo::components::currency_delta::CurrencyDelta;
    use clober_cairo::components::hook_caller::HookCaller;
    use clober_cairo::components::lockers::Lockers;
    use clober_cairo::libraries::i257::i257;
    use clober_cairo::libraries::book_key::{BookKey, BookKeyTrait};
    use clober_cairo::libraries::fee_policy::{FeePolicy, FeePolicyTrait};
    use clober_cairo::libraries::order_id::{OrderId, OrderIdTrait};
    use clober_cairo::libraries::tick::{Tick, TickTrait};
    use clober_cairo::libraries::hooks::{Hooks, HooksTrait};
    use super::{ContractAddress, MakeParams, TakeParams, CancelParams};

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

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
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
        pub const CURRENCY_NOT_SETTLED: felt252 = 'Currency not settled';
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

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn check_locker(self: @ContractState) {
            let caller = get_caller_address();
            let locker = self.lockers.get_current_locker();
            let hook = self.hook_caller.get_current_hook();
            assert(caller == locker || caller == hook, Errors::INVALID_LOCKER);
        }

        fn account_delta(ref self: ContractState, currency: ContractAddress, delta: i257) {
            if (delta.is_zero()) {
                return;
            }

            let locker = self.lockers.get_current_locker();
            let next = self.currency_delta.add(locker, currency, delta);

            if (next.is_zero()) {
                self.lockers.decrement_nonzero_delta_count();
            } else if (next == delta) {
                self.lockers.increment_nonzero_delta_count();
            }
        }
    }

    #[abi(embed_v0)]
    impl BookManagerImpl of super::IBookManager<ContractState> {
        fn open(ref self: ContractState, key: BookKey, hook_data: Span<felt252>) {
            self.check_locker();
            // @dev Also, the book opener should set unit size at least circulatingTotalSupply /
            // type(uint64).max to avoid overflow.
            //      But it is not checked here because it is not possible to check it without
            //      knowing circulatingTotalSupply.
            assert(key.unit_size > 0, Errors::INVALID_UNIT_SIZE);
            assert(
                key.maker_policy.is_valid() && key.taker_policy.is_valid(),
                Errors::INVALID_FEE_POLICY
            );
            assert(key.maker_policy.rate + key.taker_policy.rate >= 0, Errors::INVALID_FEE_POLICY);
            if (key.maker_policy.rate < 0 || key.taker_policy.rate < 0) {
                assert(
                    key.maker_policy.uses_quote == key.taker_policy.uses_quote,
                    Errors::INVALID_FEE_POLICY
                );
            }

            assert(key.hooks.is_valid_hook_address(), Errors::INVALID_HOOKS);

            self.hook_caller.before_open(@key.hooks, @key, hook_data);

            let book_id = key.to_id();
            // todo: store book key
            self
                .emit(
                    Open {
                        id: book_id,
                        base: key.base,
                        quote: key.quote,
                        unit_size: key.unit_size,
                        maker_policy: key.maker_policy,
                        taker_policy: key.taker_policy,
                        hooks: key.hooks.address
                    }
                );

            self.hook_caller.after_open(@key.hooks, @key, hook_data);
        }

        fn lock(
            ref self: ContractState, locker: ContractAddress, data: Span<felt252>
        ) -> Span<felt252> {
            // Add the locker to the stack
            let lock_caller = get_caller_address();
            self.lockers.push(locker, lock_caller);

            // The locker does everything in this callback, including paying what they owe via calls
            // to settle
            let locker_dispatcher = ILockerDispatcher {
                contract_address: locker
            }; // todo: call lock_acquired
            let result = locker_dispatcher.lock_acquired(lock_caller, data);

            // Remove the locker from the stack
            self.lockers.pop();

            let (length, nonzero_delta_count) = self.lockers.lock_data();
            // @dev The locker must settle all currency balances to zero.
            assert(length > 0 || nonzero_delta_count == 0, Errors::CURRENCY_NOT_SETTLED);
            result
        }

        fn make(
            ref self: ContractState, params: MakeParams, hook_data: Span<felt252>
        ) -> (felt252, u256) {
            self.check_locker();

            assert(
                params.provider.is_zero() || self.is_whitelisted.read(params.provider),
                Errors::INVALID_PROVIDER
            );
            params.tick.validate();

            let book_id = params.key.to_id();
            // book.check_opened();

            self.hook_caller.before_make(@params.key.hooks, @params, hook_data);

            let order_index: u64 = 0; // book.make(params.tick, params.unit, params.provider);
            let order_id = (OrderId { book_id, tick: params.tick, index: order_index }).encode();
            let mut quote_amount: u256 = params.unit.into() * params.key.unit_size.into();
            let mut quote_delta: i257 = quote_amount.into();
            if (params.key.maker_policy.uses_quote) {
                quote_delta += params.key.maker_policy.calculate_fee(quote_amount, false);
                quote_amount = quote_delta.try_into().unwrap();
            }

            self.account_delta(params.key.quote, -quote_delta);

            // todo: _mint();

            self
                .emit(
                    Make {
                        book_id,
                        user: get_caller_address(),
                        tick: params.tick.value,
                        order_index,
                        unit: params.unit,
                        provider: params.provider
                    }
                );

            self.hook_caller.after_make(@params.key.hooks, @params, order_id, hook_data);

            (order_id, quote_amount)
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
