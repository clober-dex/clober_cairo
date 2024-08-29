#[starknet::contract]
pub mod Controller {
    use openzeppelin_security::reentrancyguard::ReentrancyGuardComponent;
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use clober_cairo::interfaces::book_manager::{
        IBookManagerDispatcher, IBookManagerDispatcherTrait
    };
    use clober_cairo::interfaces::controller::IController;
    use clober_cairo::interfaces::locker::ILocker;
    use clober_cairo::libraries::tick::{Tick, TickTrait};
    use clober_cairo::libraries::order_id::{OrderId, OrderIdTrait};
    use clober_cairo::libraries::fee_policy::{FeePolicy, FeePolicyTrait};
    use clober_cairo::libraries::i257::{i257, I257Trait};
    use clober_cairo::utils::constants::ZERO_ADDRESS;

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

    #[derive(Serde, Drop)]
    pub enum Actions {
        Open,
        Make,
        Take,
        Cancel,
        Claim,
        Collect,
        Limit,
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
    }

    #[abi(embed_v0)]
    impl LockerImpl of ILocker<ContractState> {
        fn lock_acquired(
            ref self: ContractState, lock_caller: ContractAddress, mut data: Span<felt252>
        ) -> Span<felt252> {
            assert!(self.book_manager.read() == get_caller_address(), "Invalid caller");
            assert!(lock_caller == get_contract_address(), "Invalid lock caller");
            let (user, action, data) = Serde::<
                (ContractAddress, Actions, Span<felt252>)
            >::deserialize(ref data)
                .unwrap();
            data
        }
    }
}
