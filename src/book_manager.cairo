#[starknet::contract]
pub mod BookManager {
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_token::erc721::ERC721Component;
    use openzeppelin_token::erc721::extensions::erc721_enumerable::ERC721EnumerableComponent;

    use openzeppelin_access::ownable::OwnableComponent;
    use core::num::traits::zero::Zero;
    use starknet::storage::Map;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use clober_cairo::interfaces::book_manager::{
        IBookManager, MakeParams, TakeParams, CancelParams, OrderInfo, Open, Make, Take, Cancel,
        Claim, Collect, Whitelist, Delist, SetDefaultProvider, Errors,
    };
    use clober_cairo::interfaces::locker::{ILockerDispatcher, ILockerDispatcherTrait};
    use clober_cairo::libraries::i257::{i257, I257Trait};
    use clober_cairo::libraries::book_key::{BookKey, BookKeyTrait, BookKeyStorePacking};
    use clober_cairo::libraries::book::{Book, BookTrait};
    use clober_cairo::libraries::fee_policy::FeePolicyTrait;
    use clober_cairo::libraries::order_id::{OrderId, OrderIdTrait, OrderIdStoragePacking};
    use clober_cairo::libraries::tick::{Tick, TickTrait};
    use clober_cairo::libraries::hooks::HooksTrait;
    use clober_cairo::libraries::hooks_list::{HooksList, HooksListTrait};
    use clober_cairo::libraries::lockers::{Lockers, LockersTrait};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(
        path: ERC721EnumerableComponent, storage: erc721_enumerable, event: ERC721EnumerableEvent,
    );
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // Ownable2Step
    #[abi(embed_v0)]
    impl OwnableTwoStepMixinImpl =
        OwnableComponent::OwnableTwoStepMixinImpl<ContractState>;
    impl OwnableTwpStepInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // ERC721
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721CamelOnly = ERC721Component::ERC721CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataCamelOnly =
        ERC721Component::ERC721MetadataCamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721EnumerableImpl =
        ERC721EnumerableComponent::ERC721EnumerableImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl ERC721EnumerableInternalImpl = ERC721EnumerableComponent::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        erc721_enumerable: ERC721EnumerableComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        lockers: Lockers,
        hooks_list: HooksList,
        currency_delta: Map<(ContractAddress, ContractAddress), i257>,
        contract_uri: ByteArray,
        default_provider: ContractAddress,
        reserves_of: Map<ContractAddress, u256>,
        book_keys: Map<felt252, BookKey>,
        books: Map<felt252, Book>,
        is_whitelisted: Map<ContractAddress, bool>,
        token_owed: Map<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        ERC721EnumerableEvent: ERC721EnumerableComponent::Event,
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
        default_provider: ContractAddress,
        base_uri: ByteArray,
        contract_uri: ByteArray,
    ) {
        self.ownable.initializer(owner);
        self.erc721.initializer("Clober Orderbook Maker Order", "CLOB-ORDER", base_uri);
        self.erc721_enumerable.initializer();
        self._set_default_provider(default_provider);
        self.contract_uri.write(contract_uri);
    }

    impl ERC721HooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            // Call ERC721Enumerable's before_update
            let mut state = self.get_contract_mut();
            ERC721EnumerableComponent::InternalImpl::<
                ContractState,
            >::before_update(ref state.erc721_enumerable, to, token_id);
        }

        fn after_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {}
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _check_opened(self: @ContractState, book_id: felt252) {
            assert(self.is_opened(book_id), Errors::BOOK_NOT_OPENED);
        }

        fn _check_locker(self: @ContractState) {
            let caller = get_caller_address();
            let locker = self.lockers.read().get_current_locker();
            let hook = self.hooks_list.read().get_current_hook();
            assert(caller == locker || caller == hook, Errors::INVALID_LOCKER);
        }

        fn _account_delta(ref self: ContractState, currency: ContractAddress, delta: i257) {
            if delta.is_zero() {
                return;
            }

            let mut lockers = self.lockers.read();
            let locker = lockers.get_current_locker();
            let next = self.currency_delta.read((locker, currency)) + delta;
            self.currency_delta.write((locker, currency), next);

            if next.is_zero() {
                lockers.decrement_nonzero_delta_count();
            } else if next == delta {
                lockers.increment_nonzero_delta_count();
            }
        }

        fn _set_default_provider(ref self: ContractState, provider: ContractAddress) {
            self.default_provider.write(provider);
            self.emit(SetDefaultProvider { provider });
        }
    }

    #[abi(embed_v0)]
    impl BookManagerImpl of IBookManager<ContractState> {
        fn base_uri(self: @ContractState) -> ByteArray {
            self.erc721._base_uri()
        }

        fn contract_uri(self: @ContractState) -> ByteArray {
            self.contract_uri.read()
        }

        fn default_provider(self: @ContractState) -> ContractAddress {
            self.default_provider.read()
        }

        fn reserves_of(self: @ContractState, currency: ContractAddress) -> u256 {
            self.reserves_of.read(currency)
        }

        fn is_whitelisted(self: @ContractState, provider: ContractAddress) -> bool {
            self.is_whitelisted.read(provider)
        }

        fn check_authorized(
            self: @ContractState,
            owner: ContractAddress,
            spender: ContractAddress,
            token_id: felt252,
        ) {
            self.erc721._check_authorized(owner, spender, token_id.into())
        }

        fn token_owed(
            self: @ContractState, owner: ContractAddress, currency: ContractAddress,
        ) -> u256 {
            self.token_owed.read((owner, currency))
        }

        fn get_lock(self: @ContractState, i: u32) -> (ContractAddress, ContractAddress) {
            self.lockers.read().get_lock(i)
        }

        fn get_lock_data(self: @ContractState) -> (u32, u128) {
            self.lockers.read().lock_data()
        }

        fn get_current_hook(self: @ContractState) -> ContractAddress {
            self.hooks_list.read().get_current_hook()
        }

        fn get_hook(self: @ContractState, i: u32) -> ContractAddress {
            self.hooks_list.read().get_hook(i)
        }

        fn get_book_key(self: @ContractState, book_id: felt252) -> BookKey {
            self.book_keys.read(book_id)
        }

        fn get_currency_delta(
            self: @ContractState, locker: ContractAddress, currency: ContractAddress,
        ) -> i257 {
            self.currency_delta.read((locker, currency))
        }

        fn get_order(self: @ContractState, order_id: felt252) -> OrderInfo {
            let decoded_order_id = OrderIdTrait::decode(order_id);
            let book = self.books.read(decoded_order_id.book_id);
            let order = book.get_order(decoded_order_id.tick, decoded_order_id.index);
            let claimable = book
                .calculate_claimable_unit(decoded_order_id.tick, decoded_order_id.index);
            OrderInfo {
                provider: order.provider,
                open: order.pending - claimable,
                claimable,
                initial: order.initial,
                canceled: order.canceled,
            }
        }

        fn get_depth(self: @ContractState, book_id: felt252, tick: Tick) -> u64 {
            self.books.read(book_id).depth(tick)
        }

        fn get_highest(self: @ContractState, book_id: felt252) -> Tick {
            self.books.read(book_id).highest()
        }

        fn max_less_than(self: @ContractState, book_id: felt252, tick: Tick) -> Tick {
            self.books.read(book_id).max_less_than(tick)
        }

        fn is_opened(self: @ContractState, book_id: felt252) -> bool {
            self.book_keys.read(book_id).unit_size > 0
        }

        fn is_empty(self: @ContractState, book_id: felt252) -> bool {
            self.books.read(book_id).is_empty()
        }

        fn encode_book_key(self: @ContractState, book_key: BookKey) -> felt252 {
            book_key.to_id()
        }

        fn open(ref self: ContractState, key: BookKey, hook_data: Span<felt252>) -> felt252 {
            self._check_locker();
            // @dev Also, the book opener should set unit size at least circulatingTotalSupply /
            // type(uint64).max to avoid overflow.
            //      But it is not checked here because it is not possible to check it without
            //      knowing circulatingTotalSupply.
            assert(key.unit_size > 0, Errors::INVALID_UNIT_SIZE);
            assert(
                key.maker_policy.is_valid() && key.taker_policy.is_valid(),
                Errors::INVALID_FEE_POLICY,
            );
            assert(key.maker_policy.rate + key.taker_policy.rate >= 0, Errors::INVALID_FEE_POLICY);
            if key.maker_policy.rate < 0 || key.taker_policy.rate < 0 {
                assert(
                    key.maker_policy.uses_quote == key.taker_policy.uses_quote,
                    Errors::INVALID_FEE_POLICY,
                );
            }

            assert(key.hooks.is_valid_hook_address(), Errors::INVALID_HOOKS);

            let mut hooks_list = self.hooks_list.read();
            hooks_list.before_open(@key.hooks, @key, hook_data);

            let book_id = key.to_id();
            assert(!self.is_opened(book_id), Errors::BOOK_ALREADY_OPENED);
            self.book_keys.write(book_id, key);

            self
                .emit(
                    Open {
                        id: book_id,
                        base: key.base,
                        quote: key.quote,
                        unit_size: key.unit_size,
                        maker_policy: key.maker_policy,
                        taker_policy: key.taker_policy,
                        hooks: key.hooks,
                    },
                );

            hooks_list.after_open(@key.hooks, @key, hook_data);

            book_id
        }

        fn lock(
            ref self: ContractState, locker: ContractAddress, data: Span<felt252>,
        ) -> Span<felt252> {
            // Add the locker to the stack
            let lock_caller = get_caller_address();
            let mut lockers = self.lockers.read();
            lockers.push(locker, lock_caller);

            // The locker does everything in this callback, including paying what they owe via calls
            // to settle
            let locker_dispatcher = ILockerDispatcher { contract_address: locker };
            let result = locker_dispatcher.lock_acquired(lock_caller, data);

            // Remove the locker from the stack
            lockers.pop();

            let (length, nonzero_delta_count) = lockers.lock_data();
            // @dev The locker must settle all currency balances to zero.
            assert(length > 0 || nonzero_delta_count == 0, Errors::CURRENCY_NOT_SETTLED);
            result
        }

        fn make(
            ref self: ContractState, params: MakeParams, hook_data: Span<felt252>,
        ) -> (felt252, u256) {
            self._check_locker();

            assert(
                params.provider.is_zero() || self.is_whitelisted.read(params.provider),
                Errors::INVALID_PROVIDER,
            );
            params.tick.validate();

            let book_id = params.key.to_id();
            self._check_opened(book_id);
            let mut book = self.books.read(book_id);

            let mut hooks_list = self.hooks_list.read();
            hooks_list.before_make(@params.key.hooks, @params, hook_data);

            let order_index = book.make(params.tick, params.unit, params.provider);
            let order_id = (OrderId { book_id, tick: params.tick, index: order_index }).encode();
            let mut quote_amount: u256 = params.unit.into() * params.key.unit_size.into();
            let mut quote_delta: i257 = quote_amount.into();
            if params.key.maker_policy.uses_quote {
                quote_delta += params.key.maker_policy.calculate_fee(quote_amount, false);
                quote_amount = quote_delta.try_into().unwrap();
            }

            self._account_delta(params.key.quote, -quote_delta);

            self.erc721.mint(get_caller_address(), order_id.into());

            self
                .emit(
                    Make {
                        book_id,
                        user: get_caller_address(),
                        tick: params.tick.into(),
                        order_index,
                        unit: params.unit,
                        provider: params.provider,
                    },
                );

            hooks_list.after_make(@params.key.hooks, @params, order_id, hook_data);

            (order_id, quote_amount)
        }

        fn take(
            ref self: ContractState, params: TakeParams, hook_data: Span<felt252>,
        ) -> (u256, u256) {
            self._check_locker();
            params.tick.validate();

            let book_id = params.key.to_id();
            self._check_opened(book_id);
            let mut book = self.books.read(book_id);

            let mut hooks_list = self.hooks_list.read();
            hooks_list.before_take(@params.key.hooks, @params, hook_data);

            let taken_unit = book.take(params.tick, params.max_unit);
            let mut quote_amount: u256 = taken_unit.into() * params.key.unit_size.into();
            let mut base_amount = params.tick.quote_to_base(quote_amount, true);

            let mut quote_delta: i257 = quote_amount.into();
            let mut base_delta: i257 = base_amount.into();
            if params.key.taker_policy.uses_quote {
                quote_delta -= params.key.taker_policy.calculate_fee(quote_amount, false);
                quote_amount = quote_delta.try_into().unwrap();
            } else {
                base_delta += params.key.taker_policy.calculate_fee(base_amount, false);
                base_amount = base_delta.try_into().unwrap();
            }
            self._account_delta(params.key.quote, quote_delta);
            self._account_delta(params.key.base, -base_delta);

            self
                .emit(
                    Take {
                        book_id,
                        user: get_caller_address(),
                        tick: params.tick.into(),
                        unit: taken_unit,
                    },
                );

            hooks_list.after_take(@params.key.hooks, @params, taken_unit, hook_data);
            (quote_amount, base_amount)
        }

        fn cancel(ref self: ContractState, params: CancelParams, hook_data: Span<felt252>) -> u256 {
            self._check_locker();
            self
                .erc721
                ._check_authorized(
                    self.erc721._owner_of(params.id.into()), get_caller_address(), params.id.into(),
                );

            let decoded_order_id = OrderIdTrait::decode(params.id);
            let mut book = self.books.read(decoded_order_id.book_id);
            let key = self.book_keys.read(decoded_order_id.book_id);

            let mut hooks_list = self.hooks_list.read();
            hooks_list.before_cancel(@key.hooks, @params, hook_data);

            let (canceled_unit, pending_unit) = book.cancel(decoded_order_id, params.to_unit);

            let mut canceled_amount: u256 = canceled_unit.into() * key.unit_size.into();
            if key.maker_policy.uses_quote {
                let fee = key.maker_policy.calculate_fee(canceled_amount, true);
                canceled_amount = (canceled_amount.into() + fee).try_into().unwrap();
            }

            if pending_unit == 0 {
                self.erc721.burn(params.id.into());
            }

            self._account_delta(key.quote, canceled_amount.into());

            self.emit(Cancel { order_id: params.id, unit: canceled_unit });

            hooks_list.after_cancel(@key.hooks, @params, canceled_unit, hook_data);

            canceled_amount
        }

        fn claim(ref self: ContractState, id: felt252, hook_data: Span<felt252>) -> u256 {
            self._check_locker();
            self
                .erc721
                ._check_authorized(
                    self.erc721._owner_of(id.into()), get_caller_address(), id.into(),
                );

            let decoded_order_id = OrderIdTrait::decode(id);
            let mut book = self.books.read(decoded_order_id.book_id);
            let key = self.book_keys.read(decoded_order_id.book_id);

            let mut hooks_list = self.hooks_list.read();
            hooks_list.before_claim(@key.hooks, id, hook_data);

            let claimed_unit = book.claim(decoded_order_id.tick, decoded_order_id.index);

            let claimed_in_quote: u256 = claimed_unit.into() * key.unit_size.into();
            let mut claimed_amount = decoded_order_id.tick.quote_to_base(claimed_in_quote, false);

            let (mut quote_fee, mut base_fee) = if key.taker_policy.uses_quote {
                (key.taker_policy.calculate_fee(claimed_in_quote, true), 0.into())
            } else {
                (0.into(), key.taker_policy.calculate_fee(claimed_amount, true))
            };

            if key.maker_policy.uses_quote {
                quote_fee += key.maker_policy.calculate_fee(claimed_in_quote, true);
            } else {
                let make_fee = key.maker_policy.calculate_fee(claimed_amount, false);
                base_fee += make_fee;
                claimed_amount = (claimed_amount.into() - make_fee).try_into().unwrap();
            }

            let order = book.get_order(decoded_order_id.tick, decoded_order_id.index);
            let provider: ContractAddress = if order.provider.is_zero() {
                self.default_provider.read()
            } else {
                order.provider
            };
            if quote_fee > 0.into() {
                self
                    .token_owed
                    .write(
                        (provider, key.quote),
                        self.token_owed.read((provider, key.quote)) + quote_fee.abs(),
                    );
            }
            if base_fee > 0.into() {
                self
                    .token_owed
                    .write(
                        (provider, key.base),
                        self.token_owed.read((provider, key.base)) + base_fee.abs(),
                    );
            }

            if order.pending == 0 {
                self.erc721.burn(id.into());
            }

            self._account_delta(key.base, claimed_amount.into());

            self.emit(Claim { order_id: id, unit: claimed_unit });

            hooks_list.after_claim(@key.hooks, id, claimed_unit, hook_data);

            claimed_amount
        }

        fn collect(
            ref self: ContractState, recipient: ContractAddress, currency: ContractAddress,
        ) -> u256 {
            let caller = get_caller_address();
            let amount = self.token_owed.read((caller, currency));
            self.token_owed.write((caller, currency), 0);
            self.reserves_of.write(currency, self.reserves_of.read(currency) - amount);
            let erc20_dispatcher = IERC20Dispatcher { contract_address: currency };
            assert(erc20_dispatcher.transfer(recipient, amount), Errors::ERC20_TRANSFER_FAILED);
            self.emit(Collect { provider: caller, recipient, currency, amount });
            amount
        }

        fn withdraw(
            ref self: ContractState, currency: ContractAddress, to: ContractAddress, amount: u256,
        ) {
            self._check_locker();

            if amount > 0 {
                self._account_delta(currency, -amount.into());
                self.reserves_of.write(currency, self.reserves_of.read(currency) - amount);
                let erc20_dispatcher = IERC20Dispatcher { contract_address: currency };
                assert(erc20_dispatcher.transfer(to, amount), Errors::ERC20_TRANSFER_FAILED);
            }
        }

        fn settle(ref self: ContractState, currency: ContractAddress) -> u256 {
            self._check_locker();

            let reserves_before = self.reserves_of.read(currency);
            let erc20_dispatcher = IERC20Dispatcher { contract_address: currency };
            let balance_of_self = erc20_dispatcher.balance_of(get_contract_address());
            self.reserves_of.write(currency, balance_of_self);
            let paid = balance_of_self - reserves_before;
            // subtraction must be safe
            self._account_delta(currency, paid.into());
            paid
        }

        fn whitelist(ref self: ContractState, provider: ContractAddress) {
            self.ownable.assert_only_owner();
            self.is_whitelisted.write(provider, true);
            self.emit(Whitelist { provider });
        }

        fn delist(ref self: ContractState, provider: ContractAddress) {
            self.ownable.assert_only_owner();
            self.is_whitelisted.write(provider, false);
            self.emit(Delist { provider });
        }

        fn set_default_provider(ref self: ContractState, new_default_provider: ContractAddress) {
            self.ownable.assert_only_owner();
            self._set_default_provider(new_default_provider);
        }

        fn all_tokens_of_owner(self: @ContractState, owner: ContractAddress) -> Span<u256> {
            self.erc721_enumerable.all_tokens_of_owner(owner)
        }
    }
}
