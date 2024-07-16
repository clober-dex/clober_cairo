pub mod Book {
    use clober_cairo::libraries::tick::Tick;
    use clober_cairo::libraries::fee_policy::FeePolicy;
    use clober_cairo::libraries::order_id::OrderId;
    use clober_cairo::libraries::book_key::BookKey;
    use clober_cairo::libraries::hooks::Hooks;
    use starknet::ContractAddress;

    pub struct State {
        key: BookKey,
        queues: Felt252Dict<Queue>,
        tickBitmap: Felt252Dict<felt252>,
        totalClaimableOf: Felt252Dict<felt252>,
    }

    struct Queue {
        tree: Felt252Dict<felt252>,
        orders: Felt252Dict<Order>
    }

    struct Order {
        provider: ContractAddress,
        pending: u64
    }

    pub trait Book {
        fn open(ref self: State, key: BookKey);

        fn is_opened(ref self: State) -> bool;

        fn check_opened(ref self: State);

        fn depth(ref self: State, tick: Tick) -> u64;

        fn highest(ref self: State) -> Tick;

        fn max_less_than(ref self: State, tick: Tick) -> Tick;

        fn is_empty(ref self: State) -> bool;

        fn get_order(ref self: State, tick: Tick, index: u64) -> Order;

        fn make(ref self: State, tick: Tick, unit: u64, provider: ContractAddress) -> u64;

        fn take(ref self: State, tick: Tick, max_take_unit: u64) -> u64;

        fn cancel(ref self: State, order_id: OrderId, to: u64) -> (u64, u64);

        fn claim(ref self: State, tick: Tick, index: u64) -> u64;

        fn calculate_claimable_unit(ref self: State, tick: Tick, index: u64) -> u64;
    }
}
