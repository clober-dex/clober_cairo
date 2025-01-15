#[starknet::contract]
pub mod BookViewer {
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_upgrades::UpgradeableComponent;
    use openzeppelin_upgrades::interface::IUpgradeable;
    use starknet::{ClassHash, ContractAddress};
    use clober_cairo::utils::constants::MIN_TICK;
    use clober_cairo::interfaces::book_viewer::{IBookViewer, Liquidity};
    use clober_cairo::interfaces::book_manager::{
        IBookManagerDispatcher, IBookManagerDispatcherTrait
    };
    use clober_cairo::libraries::fee_policy::FeePolicyTrait;
    use clober_cairo::libraries::tick::{Tick, TickTrait};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // Ownable2Step
    #[abi(embed_v0)]
    impl OwnableTwoStepMixinImpl =
        OwnableComponent::OwnableTwoStepMixinImpl<ContractState>;
    impl OwnableTwpStepInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Upgradeable
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pub upgradeable: UpgradeableComponent::Storage,
        book_manager: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, book_manager: ContractAddress, owner: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self.book_manager.write(book_manager);
    }

    #[abi(embed_v0)]
    impl BookViewerImpl of IBookViewer<ContractState> {
        fn book_manager(self: @ContractState) -> ContractAddress {
            self.book_manager.read()
        }

        fn get_liquidity(
            self: @ContractState, book_id: felt252, tick: Tick, n: u32
        ) -> Span<Liquidity> {
            let mut liquidities = ArrayTrait::new();
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read()
            };
            let mut tick = tick;
            if (book_manager.get_depth(book_id, tick) == 0) {
                tick = book_manager.max_less_than(book_id, tick);
            }
            while (liquidities.len() < n) {
                if (tick.into() == MIN_TICK - 1) {
                    break;
                }
                liquidities
                    .append(
                        Liquidity { tick: tick, depth: book_manager.get_depth(book_id, tick), }
                    );
                tick = book_manager.max_less_than(book_id, tick);
            };
            return liquidities.span();
        }

        fn get_expected_input(
            self: @ContractState,
            book_id: felt252,
            limit_price: u256,
            quote_amount: u256,
            max_base_amount: u256,
            hook_data: Span<felt252>,
        ) -> (u256, u256) {
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read()
            };
            let key = book_manager.get_book_key(book_id);

            if (book_manager.is_empty(book_id)) {
                return (0, 0);
            }

            let mut taken_quote_amount = 0;
            let mut spent_base_amount = 0;
            let mut tick = book_manager.get_highest(book_id);

            while (tick.into() > MIN_TICK - 1) {
                if (limit_price > tick.to_price()) {
                    break;
                }
                let mut max_amount = 0;
                if (key.taker_policy.uses_quote) {
                    max_amount = key
                        .taker_policy
                        .calculate_original_amount(quote_amount - taken_quote_amount, true);
                } else {
                    max_amount = quote_amount - taken_quote_amount;
                }
                max_amount = (max_amount + key.unit_size.into() - 1) / key.unit_size.into();

                if (max_amount == 0) {
                    break;
                }
                let current_depth = book_manager.get_depth(book_id, tick).into();
                let mut quote_amount = if (current_depth > max_amount) {
                    max_amount * key.unit_size.into()
                } else {
                    current_depth * key.unit_size.into()
                };
                let mut base_amount = tick.quote_to_base(quote_amount, true);
                if (key.taker_policy.uses_quote) {
                    quote_amount =
                        (-key.taker_policy.calculate_fee(quote_amount, false) + quote_amount.into())
                        .try_into()
                        .unwrap();
                } else {
                    base_amount =
                        (key.taker_policy.calculate_fee(base_amount, false) + base_amount.into())
                        .try_into()
                        .unwrap();
                }
                if (quote_amount == 0) {
                    break;
                }

                taken_quote_amount += quote_amount;
                spent_base_amount += base_amount;
                if (quote_amount <= taken_quote_amount) {
                    break;
                }
                tick = book_manager.max_less_than(book_id, tick);
            };
            return (taken_quote_amount, spent_base_amount);
        }

        fn get_expected_output(
            self: @ContractState,
            book_id: felt252,
            limit_price: u256,
            base_amount: u256,
            min_quote_amount: u256,
            hook_data: Span<felt252>,
        ) -> (u256, u256) {
            let book_manager = IBookManagerDispatcher {
                contract_address: self.book_manager.read()
            };
            let key = book_manager.get_book_key(book_id);

            if (book_manager.is_empty(book_id)) {
                return (0, 0);
            }

            let mut taken_quote_amount = 0;
            let mut spent_base_amount = 0;
            let mut tick = book_manager.get_highest(book_id);

            while (spent_base_amount <= base_amount && tick.into() > MIN_TICK - 1) {
                if (limit_price > tick.to_price()) {
                    break;
                }
                let mut max_amount = 0;
                if (key.taker_policy.uses_quote) {
                    max_amount = base_amount - spent_base_amount;
                } else {
                    max_amount = key
                        .taker_policy
                        .calculate_original_amount(base_amount - spent_base_amount, false);
                }
                max_amount = tick.base_to_quote(max_amount, false) / key.unit_size.into();

                if (max_amount == 0) {
                    break;
                }
                let current_depth = book_manager.get_depth(book_id, tick).into();
                let mut quote_amount = if (current_depth > max_amount) {
                    max_amount * key.unit_size.into()
                } else {
                    current_depth * key.unit_size.into()
                };
                let mut base_amount = tick.quote_to_base(quote_amount, true);
                if (key.taker_policy.uses_quote) {
                    quote_amount =
                        (-key.taker_policy.calculate_fee(quote_amount, false) + quote_amount.into())
                        .try_into()
                        .unwrap();
                } else {
                    base_amount =
                        (key.taker_policy.calculate_fee(base_amount, false) + base_amount.into())
                        .try_into()
                        .unwrap();
                }
                if (base_amount == 0) {
                    break;
                }

                taken_quote_amount += quote_amount;
                spent_base_amount += base_amount;
                tick = book_manager.max_less_than(book_id, tick);
            };
            return (taken_quote_amount, spent_base_amount);
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        /// Upgrades the contract class hash to `new_class_hash`.
        /// This may only be called by the contract owner.
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
