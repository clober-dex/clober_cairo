#[starknet::contract]
pub mod Controller {
    use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin_security::reentrancyguard::ReentrancyGuardComponent;
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};
    use clober_cairo::interfaces::book_manager::{
        IBookManagerDispatcher, IBookManagerDispatcherTrait, MakeParams, TakeParams, CancelParams,
    };
    use clober_cairo::interfaces::controller::{IController, Actions, Errors};
    use clober_cairo::interfaces::locker::ILocker;
    use clober_cairo::libraries::tick::{Tick, TickTrait};
    use clober_cairo::libraries::book_key::BookKey;
    use clober_cairo::libraries::order_id::OrderIdTrait;
    use clober_cairo::libraries::fee_policy::FeePolicyTrait;
    use clober_cairo::libraries::i257::I257Trait;
    use clober_cairo::utils::constants::ZERO_ADDRESS;
    use clober_cairo::utils::math::{divide};

    component!(
        path: ReentrancyGuardComponent, storage: reentrancyGuard, event: ReentrancyGuardEvent,
    );

    // ReentrancyGuard
    impl ReentrancyGuardImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        reentrancyGuard: ReentrancyGuardComponent::Storage,
        book_manager: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, book_manager: ContractAddress) {
        self.book_manager.write(book_manager);
    }

    #[abi(embed_v0)]
    impl ControllerImpl of IController<ContractState> {
        fn get_depth(self: @ContractState, book_id: felt252, tick: Tick) -> u64 {
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read(),
            };
            book_manager.get_depth(book_id, tick)
        }

        fn get_highest_price(self: @ContractState, book_id: felt252) -> u256 {
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read(),
            };
            book_manager.get_highest(book_id).to_price()
        }

        fn get_order(
            self: @ContractState, order_id: felt252,
        ) -> (ContractAddress, u256, u256, u256) {
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read(),
            };
            let order_info = book_manager.get_order(order_id);

            let decoded_order_id = OrderIdTrait::decode(order_id);
            let book_key = book_manager.get_book_key(decoded_order_id.book_id);
            let unit_size = book_key.unit_size;
            let maker_policy = book_key.maker_policy;
            let mut claimable_amount = decoded_order_id
                .tick
                .quote_to_base(unit_size.into() * order_info.claimable.into(), false);
            if !maker_policy.uses_quote {
                let fee = maker_policy.calculate_fee(claimable_amount, false);
                claimable_amount =
                    if !fee.is_negative() {
                        claimable_amount - fee.abs()
                    } else {
                        claimable_amount + fee.abs()
                    };
            }
            (
                order_info.provider,
                decoded_order_id.tick.to_price(),
                unit_size.into() * order_info.open.into(),
                claimable_amount,
            )
        }

        fn from_price(self: @ContractState, price: u256) -> Tick {
            TickTrait::from_price(price)
        }

        fn to_price(self: @ContractState, tick: Tick) -> u256 {
            tick.to_price()
        }

        fn open(
            ref self: ContractState, book_key: BookKey, hook_data: Span<felt252>, deadline: u64,
        ) -> felt252 {
            self._check_deadline(deadline);
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read(),
            };
            let mut params = ArrayTrait::new();
            Serde::serialize(@book_key, ref params);
            Serde::serialize(@hook_data, ref params);

            let mut data = ArrayTrait::new();
            Serde::serialize(@get_caller_address(), ref data);
            Serde::serialize(@Actions::Open, ref data);
            Serde::serialize(@params, ref data);
            let mut result = book_manager.lock(get_contract_address(), data.span());
            Serde::deserialize(ref result).unwrap()
        }

        fn make(
            ref self: ContractState,
            book_id: felt252,
            tick: Tick,
            quote_amount: u256,
            hook_data: Span<felt252>,
            deadline: u64,
        ) -> felt252 {
            self._check_deadline(deadline);
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read(),
            };
            let mut params = ArrayTrait::new();
            Serde::serialize(@book_id, ref params);
            Serde::serialize(@tick, ref params);
            Serde::serialize(@quote_amount, ref params);
            Serde::serialize(@hook_data, ref params);

            let mut data = ArrayTrait::new();
            Serde::serialize(@get_caller_address(), ref data);
            Serde::serialize(@Actions::Make, ref data);
            Serde::serialize(@params, ref data);
            let mut result = book_manager.lock(get_contract_address(), data.span());
            Serde::deserialize(ref result).unwrap()
        }

        fn limit(
            ref self: ContractState,
            take_book_id: felt252,
            make_book_id: felt252,
            limit_price: u256,
            tick: Tick,
            quote_amount: u256,
            take_hook_data: Span<felt252>,
            make_hook_data: Span<felt252>,
            deadline: u64,
        ) -> felt252 {
            self._check_deadline(deadline);
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read(),
            };
            let mut params = ArrayTrait::new();
            Serde::serialize(@take_book_id, ref params);
            Serde::serialize(@make_book_id, ref params);
            Serde::serialize(@limit_price, ref params);
            Serde::serialize(@tick, ref params);
            Serde::serialize(@quote_amount, ref params);
            Serde::serialize(@take_hook_data, ref params);
            Serde::serialize(@make_hook_data, ref params);

            let mut data = ArrayTrait::new();
            Serde::serialize(@get_caller_address(), ref data);
            Serde::serialize(@Actions::Limit, ref data);
            Serde::serialize(@params, ref data);
            let mut result = book_manager.lock(get_contract_address(), data.span());
            Serde::deserialize(ref result).unwrap()
        }

        fn take(
            ref self: ContractState,
            book_id: felt252,
            limit_price: u256,
            quote_amount: u256,
            max_base_amount: u256,
            hook_data: Span<felt252>,
            deadline: u64,
        ) {
            self._check_deadline(deadline);
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read(),
            };
            let mut params = ArrayTrait::new();
            Serde::serialize(@book_id, ref params);
            Serde::serialize(@limit_price, ref params);
            Serde::serialize(@quote_amount, ref params);
            Serde::serialize(@max_base_amount, ref params);
            Serde::serialize(@hook_data, ref params);

            let mut data = ArrayTrait::new();
            Serde::serialize(@get_caller_address(), ref data);
            Serde::serialize(@Actions::Take, ref data);
            Serde::serialize(@params, ref data);
            book_manager.lock(get_contract_address(), data.span());
        }

        fn spend(
            ref self: ContractState,
            book_id: felt252,
            limit_price: u256,
            base_amount: u256,
            min_quote_amount: u256,
            hook_data: Span<felt252>,
            deadline: u64,
        ) {
            self._check_deadline(deadline);
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read(),
            };
            let mut params = ArrayTrait::new();
            Serde::serialize(@book_id, ref params);
            Serde::serialize(@limit_price, ref params);
            Serde::serialize(@base_amount, ref params);
            Serde::serialize(@min_quote_amount, ref params);
            Serde::serialize(@hook_data, ref params);

            let mut data = ArrayTrait::new();
            Serde::serialize(@get_caller_address(), ref data);
            Serde::serialize(@Actions::Spend, ref data);
            Serde::serialize(@params, ref data);
            book_manager.lock(get_contract_address(), data.span());
        }

        fn cancel(
            ref self: ContractState,
            order_id: felt252,
            left_quote_amount: u256,
            hook_data: Span<felt252>,
            deadline: u64,
        ) {
            self._check_deadline(deadline);
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read(),
            };
            let mut params = ArrayTrait::new();
            Serde::serialize(@order_id, ref params);
            Serde::serialize(@left_quote_amount, ref params);
            Serde::serialize(@hook_data, ref params);

            let mut data = ArrayTrait::new();
            Serde::serialize(@get_caller_address(), ref data);
            Serde::serialize(@Actions::Cancel, ref data);
            Serde::serialize(@params, ref data);
            book_manager.lock(get_contract_address(), data.span());
        }

        fn claim(
            ref self: ContractState, order_id: felt252, hook_data: Span<felt252>, deadline: u64,
        ) {
            self._check_deadline(deadline);
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read(),
            };
            let mut params = ArrayTrait::new();
            Serde::serialize(@order_id, ref params);
            Serde::serialize(@hook_data, ref params);

            let mut data = ArrayTrait::new();
            Serde::serialize(@get_caller_address(), ref data);
            Serde::serialize(@Actions::Claim, ref data);
            Serde::serialize(@params, ref data);
            book_manager.lock(get_contract_address(), data.span());
        }
    }

    #[abi(embed_v0)]
    impl LockerImpl of ILocker<ContractState> {
        fn lock_acquired(
            ref self: ContractState, lock_caller: ContractAddress, mut data: Span<felt252>,
        ) -> Span<felt252> {
            assert(self.book_manager.read() == get_caller_address(), Errors::INVALID_CALLER);
            assert(lock_caller == get_contract_address(), Errors::INVALID_LOCK_CALLER);

            let (user, action, mut params) = Serde::<
                (ContractAddress, Actions, Span<felt252>),
            >::deserialize(ref data)
                .unwrap();

            let (data, tokens) = match action {
                Actions::Open => {
                    let (key, hook_data) = Serde::<
                        (BookKey, Span<felt252>),
                    >::deserialize(ref params)
                        .unwrap();
                    let book_manager = IBookManagerDispatcher {
                        contract_address: self.book_manager.read(),
                    };
                    (book_manager.open(key, hook_data), ArrayTrait::new().span())
                },
                Actions::Make => {
                    let (book_id, tick, quote_amount, hook_data) = Serde::<
                        (felt252, Tick, u256, Span<felt252>),
                    >::deserialize(ref params)
                        .unwrap();
                    let (order_id, tokens) = self._make(book_id, tick, quote_amount, hook_data);
                    if order_id != 0 {
                        let book_manager = IERC721Dispatcher {
                            contract_address: self.book_manager.read(),
                        };
                        book_manager.transfer_from(get_contract_address(), user, order_id.into());
                    }
                    (order_id, tokens)
                },
                Actions::Limit => {
                    let (
                        take_book_id,
                        make_book_id,
                        limit_price,
                        tick,
                        quote_amount,
                        take_hook_data,
                        make_hook_data,
                    ) =
                        Serde::<
                        (felt252, felt252, u256, Tick, u256, Span<felt252>, Span<felt252>),
                    >::deserialize(ref params)
                        .unwrap();
                    let (order_id, tokens) = self
                        ._limit(
                            take_book_id,
                            make_book_id,
                            limit_price,
                            tick,
                            quote_amount,
                            take_hook_data,
                            make_hook_data,
                        );
                    if order_id != 0 {
                        let book_manager = IERC721Dispatcher {
                            contract_address: self.book_manager.read(),
                        };
                        book_manager.transfer_from(get_contract_address(), user, order_id.into());
                    }
                    (order_id, tokens)
                },
                Actions::Take => {
                    let (book_id, limit_price, quote_amount, max_base_amount, hook_data) = Serde::<
                        (felt252, u256, u256, u256, Span<felt252>),
                    >::deserialize(ref params)
                        .unwrap();
                    let (_, _, tokens) = self
                        ._take(book_id, limit_price, quote_amount, max_base_amount, hook_data);
                    (0, tokens)
                },
                Actions::Spend => {
                    let (book_id, limit_price, base_amount, min_quote_amount, hook_data) = Serde::<
                        (felt252, u256, u256, u256, Span<felt252>),
                    >::deserialize(ref params)
                        .unwrap();
                    let (_, _, tokens) = self
                        ._spend(book_id, limit_price, base_amount, min_quote_amount, hook_data);
                    (0, tokens)
                },
                Actions::Cancel => {
                    let (order_id, left_quote_amount, hook_data) = Serde::<
                        (felt252, u256, Span<felt252>),
                    >::deserialize(ref params)
                        .unwrap();
                    let tokens = self._cancel(user, order_id, left_quote_amount, hook_data);
                    (0, tokens)
                },
                Actions::Claim => {
                    let (order_id, hook_data) = Serde::<
                        (felt252, Span<felt252>),
                    >::deserialize(ref params)
                        .unwrap();
                    let tokens = self._claim(user, order_id, hook_data);
                    (0, tokens)
                },
            };

            let mut result = ArrayTrait::new();
            Serde::serialize(@data, ref result);
            self._settle_tokens(user, tokens);

            result.span()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        #[inline(always)]
        fn _check_deadline(self: @ContractState, deadline: u64) {
            assert(deadline >= get_block_timestamp(), Errors::DEADLINE);
        }

        fn _make(
            self: @ContractState,
            book_id: felt252,
            tick: Tick,
            quote_amount: u256,
            hook_data: Span<felt252>,
        ) -> (felt252, Span<felt252>) {
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read(),
            };
            let key = book_manager.get_book_key(book_id);
            let unit = (quote_amount / key.unit_size.into()).try_into().unwrap();
            let mut tokens = ArrayTrait::new();
            if unit == 0 {
                return (0, tokens.span());
            }
            let (order_id, _) = book_manager
                .make(MakeParams { key, tick, unit, provider: ZERO_ADDRESS() }, hook_data);
            Serde::serialize(@key.quote, ref tokens);
            (order_id, tokens.span())
        }

        fn _limit(
            self: @ContractState,
            take_book_id: felt252,
            make_book_id: felt252,
            limit_price: u256,
            tick: Tick,
            mut quote_amount: u256,
            take_hook_data: Span<felt252>,
            make_hook_data: Span<felt252>,
        ) -> (felt252, Span<felt252>) {
            let (is_quote_remained, spent_quote_amount, tokens) = self
                ._spend(take_book_id, limit_price, quote_amount, 0, take_hook_data);
            quote_amount -= spent_quote_amount;
            if is_quote_remained {
                let (order_id, _) = self._make(make_book_id, tick, quote_amount, make_hook_data);
                (order_id, tokens)
            } else {
                (0, tokens)
            }
        }

        fn _take(
            self: @ContractState,
            book_id: felt252,
            limit_price: u256,
            quote_amount: u256,
            max_base_amount: u256,
            hook_data: Span<felt252>,
        ) -> (u256, u256, Span<felt252>) {
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read(),
            };
            let key = book_manager.get_book_key(book_id);

            let mut taken_quote_amount = 0;
            let mut spent_base_amount = 0;

            while quote_amount > taken_quote_amount && !book_manager.is_empty(book_id) {
                let tick = book_manager.get_highest(book_id);
                if limit_price > tick.to_price() {
                    break;
                }
                let max_amount = if key.taker_policy.uses_quote {
                    key
                        .taker_policy
                        .calculate_original_amount(quote_amount - taken_quote_amount, true)
                } else {
                    quote_amount - taken_quote_amount
                };
                if max_amount == 0 {
                    break;
                }

                let max_unit_u256 = divide(max_amount, key.unit_size.into(), true);
                let max_unit: u64 = if max_unit_u256 > 0xffffffffffffffff {
                    0xffffffffffffffff_u64
                } else {
                    max_unit_u256.try_into().unwrap()
                };
                let (quote_amount, base_amount) = book_manager
                    .take(TakeParams { key, tick, max_unit }, hook_data);
                if quote_amount == 0 {
                    break;
                }

                taken_quote_amount += quote_amount;
                spent_base_amount += base_amount;
            };

            assert(max_base_amount >= spent_base_amount, Errors::SLIPPAGE);
            let mut tokens = ArrayTrait::new();
            Serde::serialize(@key.quote, ref tokens);
            Serde::serialize(@key.base, ref tokens);

            (taken_quote_amount, spent_base_amount, tokens.span())
        }

        fn _spend(
            self: @ContractState,
            book_id: felt252,
            limit_price: u256,
            max_base_amount: u256,
            min_quote_amount: u256,
            hook_data: Span<felt252>,
        ) -> (bool, u256, Span<felt252>) {
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read(),
            };
            let key = book_manager.get_book_key(book_id);
            let mut taken_quote_amount = 0;
            let mut spent_base_amount = 0;
            let mut is_base_remained = false;

            while max_base_amount > spent_base_amount {
                if book_manager.is_empty(book_id) {
                    is_base_remained = true;
                    break;
                }
                let tick = book_manager.get_highest(book_id);
                if limit_price > tick.to_price() {
                    is_base_remained = true;
                    break;
                }
                let max_amount = if key.taker_policy.uses_quote {
                    max_base_amount - spent_base_amount
                } else {
                    key
                        .taker_policy
                        .calculate_original_amount(max_base_amount - spent_base_amount, false)
                };
                if max_amount == 0 {
                    break;
                }

                let mut max_unit_u256 = tick.base_to_quote(max_amount, false) / key.unit_size.into();
                let max_unit: u64 = if max_unit_u256 > 0xffffffffffffffff {
                    0xffffffffffffffff_u64
                } else {
                    max_unit_u256.try_into().unwrap()
                };

                let (quote_amount, base_amount) = book_manager
                    .take(TakeParams { key, tick, max_unit }, hook_data);
                if base_amount == 0 {
                    break;
                }

                taken_quote_amount += quote_amount;
                spent_base_amount += base_amount;
            };
            assert(min_quote_amount <= taken_quote_amount, Errors::SLIPPAGE);
            let mut tokens = ArrayTrait::new();
            Serde::serialize(@key.quote, ref tokens);
            Serde::serialize(@key.base, ref tokens);

            (is_base_remained, spent_base_amount, tokens.span())
        }

        fn _cancel(
            self: @ContractState,
            user: ContractAddress,
            order_id: felt252,
            left_quote_amount: u256,
            hook_data: Span<felt252>,
        ) -> Span<felt252> {
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read(),
            };
            assert(
                IERC721Dispatcher { contract_address: book_manager.contract_address }
                    .owner_of(order_id.into()) == user,
                Errors::UNAUTHORIZED,
            );

            let key = book_manager.get_book_key(OrderIdTrait::decode(order_id).book_id);
            // Todo try catch
            book_manager
                .cancel(
                    CancelParams {
                        id: order_id,
                        to_unit: (left_quote_amount / key.unit_size.into()).try_into().unwrap(),
                    },
                    hook_data,
                );
            let mut tokens = ArrayTrait::new();
            Serde::serialize(@key.quote, ref tokens);
            tokens.span()
        }

        fn _claim(
            self: @ContractState,
            user: ContractAddress,
            order_id: felt252,
            hook_data: Span<felt252>,
        ) -> Span<felt252> {
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read(),
            };
            assert(
                IERC721Dispatcher { contract_address: book_manager.contract_address }
                    .owner_of(order_id.into()) == user,
                Errors::UNAUTHORIZED,
            );
            let key = book_manager.get_book_key(OrderIdTrait::decode(order_id).book_id);
            book_manager.claim(order_id, hook_data);

            let mut tokens = ArrayTrait::new();
            Serde::serialize(@key.base, ref tokens);
            tokens.span()
        }

        fn _settle_tokens(self: @ContractState, user: ContractAddress, tokens: Span<felt252>) {
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read(),
            };
            let controller_address = get_contract_address();
            for address in tokens {
                let token: ContractAddress = (*address).try_into().unwrap();
                let mut currency_delta = book_manager.get_currency_delta(controller_address, token);

                let token_dispatcher = IERC20Dispatcher { contract_address: token };

                if currency_delta.is_negative() {
                    assert(
                        token_dispatcher
                            .transfer_from(
                                user, book_manager.contract_address, currency_delta.abs().into(),
                            ),
                        Errors::ERC20_TRANSFER_FAILED,
                    );
                    book_manager.settle(token);
                }

                currency_delta = book_manager.get_currency_delta(controller_address, token);
                if !currency_delta.is_negative() {
                    book_manager.withdraw(token, user, currency_delta.abs().into());
                }

                let balance = token_dispatcher.balance_of(controller_address);
                if balance > 0 {
                    assert(token_dispatcher.transfer(user, balance), Errors::ERC20_TRANSFER_FAILED);
                }
            }
        }
    }
}
