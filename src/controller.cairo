#[starknet::contract]
pub mod Controller {
    use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
    use openzeppelin_security::reentrancyguard::ReentrancyGuardComponent;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use clober_cairo::interfaces::book_manager::{
        IBookManagerDispatcher, IBookManagerDispatcherTrait, MakeParams, TakeParams, CancelParams,
        OrderInfo
    };
    use clober_cairo::interfaces::controller::IController;
    use clober_cairo::interfaces::locker::ILocker;
    use clober_cairo::libraries::tick::{Tick, TickTrait};
    use clober_cairo::libraries::book_key::{BookKey, BookKeyTrait};
    use clober_cairo::libraries::order_id::{OrderId, OrderIdTrait};
    use clober_cairo::libraries::fee_policy::{FeePolicy, FeePolicyTrait};
    use clober_cairo::libraries::i257::{i257, I257Trait};
    use clober_cairo::utils::constants::ZERO_ADDRESS;
    use clober_cairo::utils::math::{divide};

    component!(
        path: ReentrancyGuardComponent, storage: reentrancyGuard, event: ReentrancyGuardEvent
    );

    // ReentrancyGuard
    impl ReentrancyGuardImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        reentrancyGuard: ReentrancyGuardComponent::Storage,
        book_manager: ContractAddress
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
    }

    #[derive(Serde, Drop, Copy)]
    pub enum Actions {
        Open,
        Make,
        Take,
        Spend,
        Limit,
        Cancel,
        Claim,
    }

    pub mod Errors {}

    #[constructor]
    fn constructor(ref self: ContractState, book_manager: ContractAddress,) {
        self.book_manager.write(book_manager);
    }

    #[abi(embed_v0)]
    impl ControllerImpl of IController<ContractState> {
        fn get_depth(self: @ContractState, book_id: felt252, tick: Tick,) -> u64 {
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read()
            };
            book_manager.get_depth(book_id, tick)
        }

        fn get_highest_price(self: @ContractState, book_id: felt252,) -> u256 {
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read()
            };
            book_manager.get_highest(book_id).to_price()
        }

        fn get_order(
            self: @ContractState, order_id: felt252,
        ) -> (ContractAddress, u256, u256, u256) {
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read()
            };
            let order_info = book_manager.get_order(order_id);

            let decoded_order_id = OrderIdTrait::decode(order_id);
            let book_key = book_manager.get_book_key(decoded_order_id.book_id);
            let unit_size = book_key.unit_size;
            let maker_policy = book_key.maker_policy;
            let mut claimable_amount = decoded_order_id
                .tick
                .quote_to_base(unit_size.into() * order_info.claimable.into(), false);
            if maker_policy.uses_quote {
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
                claimable_amount
            )
        }

        fn from_price(self: @ContractState, price: u256) -> Tick {
            TickTrait::from_price(price)
        }

        fn to_price(self: @ContractState, tick: Tick,) -> u256 {
            tick.to_price()
        }

        fn open(ref self: ContractState, book_key: BookKey, hook_data: Span<felt252>) -> felt252 {
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read()
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
            hook_data: Span<felt252>
        ) -> u256 {
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read()
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

        fn take(
            ref self: ContractState,
            book_id: felt252,
            limit_price: u256,
            quote_amount: u256,
            max_base_amount: u256,
            hook_data: Span<felt252>
        ) {
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read()
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
            hook_data: Span<felt252>
        ) {
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read()
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
    }

    #[abi(embed_v0)]
    impl LockerImpl of ILocker<ContractState> {
        fn lock_acquired(
            ref self: ContractState, lock_caller: ContractAddress, mut data: Span<felt252>
        ) -> Span<felt252> {
            assert!(self.book_manager.read() == get_caller_address(), "Invalid caller");
            assert!(lock_caller == get_contract_address(), "Invalid lock caller");

            let (user, action, mut params) = Serde::<
                (ContractAddress, Actions, Span<felt252>)
            >::deserialize(ref data)
                .unwrap();
            let mut result = ArrayTrait::new();
            Serde::serialize(
                @match action {
                    Actions::Open => {
                        let (key, hook_data) = Serde::<
                            (BookKey, Span<felt252>)
                        >::deserialize(ref params)
                            .unwrap();
                        let book_manager = IBookManagerDispatcher {
                            contract_address: self.book_manager.read()
                        };
                        book_manager.open(key, hook_data)
                    },
                    Actions::Make => {
                        let (book_id, tick, quote_amount, hook_data) = Serde::<
                            (felt252, Tick, u256, Span<felt252>)
                        >::deserialize(ref params)
                            .unwrap();
                        let order_id = self._make(book_id, tick, quote_amount, hook_data);
                        if (order_id != 0) {
                            let book_manager = IERC721Dispatcher {
                                contract_address: self.book_manager.read()
                            };
                            book_manager
                                .transfer_from(get_contract_address(), user, order_id.into());
                        }
                        order_id
                    },
                    Actions::Take => {
                        let (book_id, limit_price, quote_amount, max_base_amount, hook_data) =
                            Serde::<
                            (felt252, u256, u256, u256, Span<felt252>)
                        >::deserialize(ref params)
                            .unwrap();
                        self._take(book_id, limit_price, quote_amount, max_base_amount, hook_data);
                        0
                    },
                    Actions::Spend => {
                        let (book_id, limit_price, base_amount, min_quote_amount, hook_data) =
                            Serde::<
                            (felt252, u256, u256, u256, Span<felt252>)
                        >::deserialize(ref params)
                            .unwrap();
                        self._take(book_id, limit_price, base_amount, min_quote_amount, hook_data);
                        0
                    },
                    Actions::Cancel => 0,
                    Actions::Claim => 0,
                    Actions::Limit => 0,
                },
                ref result
            );
            // self._settleTokens(user);

            result.span()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _make(
            self: @ContractState,
            book_id: felt252,
            tick: Tick,
            quote_amount: u256,
            hook_data: Span<felt252>
        ) -> felt252 {
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read()
            };
            let key = book_manager.get_book_key(book_id);
            let unit = (quote_amount / key.unit_size.into()).try_into().unwrap();
            if unit == 0 {
                return 0;
            }
            let (order_id, _) = book_manager
                .make(MakeParams { key, tick, unit, provider: ZERO_ADDRESS(), }, hook_data);
            order_id
        }

        fn _take(
            self: @ContractState,
            book_id: felt252,
            limit_price: u256,
            quote_amount: u256,
            max_base_amount: u256,
            hook_data: Span<felt252>
        ) -> (u256, u256) {
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read()
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

                let max_unit: u64 = divide(max_amount, key.unit_size.into(), true)
                    .try_into()
                    .unwrap();
                let (quote_amount, base_amount) = book_manager
                    .take(TakeParams { key, tick, max_unit }, hook_data);
                if quote_amount == 0 {
                    break;
                }

                taken_quote_amount += quote_amount;
                spent_base_amount += base_amount;
            };

            assert!(max_base_amount >= spent_base_amount, "ControllerSlippage");
            (taken_quote_amount, spent_base_amount)
        }
    }

    fn _spend(
        self: @ContractState,
        book_id: felt252,
        limit_price: u256,
        base_amount: u256,
        min_quote_amount: u256,
        hook_data: Span<felt252>
    ) -> (bool, u256) {
        let book_manager = IBookManagerDispatcher { contract_address: self.book_manager.read() };
        let key = book_manager.get_book_key(book_id);
        let mut taken_quote_amount = 0;
        let mut spent_base_amount = 0;
        let mut is_base_remained = false;

        while base_amount > spent_base_amount {
            if book_manager.is_empty(book_id) {
                is_base_remained = true;
                break;
            }
            let tick = book_manager.get_highest(book_id);
            if limit_price > tick.to_price() {
                break;
            }
            let max_amount = if key.taker_policy.uses_quote {
                base_amount - taken_quote_amount
            } else {
                key.taker_policy.calculate_original_amount(base_amount - taken_quote_amount, false)
            };
            if max_amount == 0 {
                break;
            }

            let max_unit: u64 = (tick.base_to_quote(max_amount, false) / key.unit_size.into())
                .try_into()
                .unwrap();
            let (quote_amount, base_amount) = book_manager
                .take(TakeParams { key, tick, max_unit }, hook_data);
            if base_amount == 0 {
                break;
            }

            taken_quote_amount += quote_amount;
            spent_base_amount += base_amount;
        };
        assert!(min_quote_amount <= taken_quote_amount, "ControllerSlippage");
        (is_base_remained, spent_base_amount)
    }
}
