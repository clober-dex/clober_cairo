pub mod Book {
    use clober_cairo::libraries::tick::Tick;
    use clober_cairo::libraries::fee_policy::FeePolicy;
    use clober_cairo::libraries::order_id::OrderId;
    use clober_cairo::libraries::book_key::BookKey;
    use clober_cairo::libraries::hooks::Hooks;
    use clober_cairo::libraries::storage_map::{StorageMap, StorageMapTrait};
    use starknet::ContractAddress;
    use starknet::storage_access::{
        StorageBaseAddress, storage_address_from_base, storage_base_address_from_felt252
    };
    use starknet::{Store, SyscallResult, SyscallResultTrait};

    const NOT_IMPLEMENTED: felt252 = 'Not implemented';

    #[derive(Drop)]
    pub struct State {
        key: BookKey,
        queues: StorageMap<Queue>,
        tickBitmap: StorageMap<felt252>,
        totalClaimableOf: StorageMap<felt252>,
    }

    impl StateStoreImpl of Store<State> {
        #[inline(always)]
        fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<State> {
            let base_felt252: felt252 = storage_address_from_base(base).into();
            let book_key_size: felt252 = Store::<BookKey>::size().into();
            SyscallResult::Ok(
                State {
                    key: Store::read(address_domain, base).unwrap_syscall(),
                    queues: StorageMapTrait::fetch(
                        address_domain,
                        storage_base_address_from_felt252(base_felt252 + book_key_size)
                    ),
                    tickBitmap: StorageMapTrait::fetch(
                        address_domain,
                        storage_base_address_from_felt252(base_felt252 + book_key_size + 1)
                    ),
                    totalClaimableOf: StorageMapTrait::fetch(
                        address_domain,
                        storage_base_address_from_felt252(base_felt252 + book_key_size + 2)
                    )
                }
            )
        }

        #[inline(always)]
        fn write(address_domain: u32, base: StorageBaseAddress, value: State) -> SyscallResult<()> {
            Store::write(address_domain, base, value.key)
        }

        #[inline(always)]
        fn read_at_offset(
            address_domain: u32, base: StorageBaseAddress, offset: u8
        ) -> SyscallResult<State> {
            SyscallResult::Err(array![NOT_IMPLEMENTED])
        }

        #[inline(always)]
        fn write_at_offset(
            address_domain: u32, base: StorageBaseAddress, offset: u8, value: State
        ) -> SyscallResult<()> {
            SyscallResult::Err(array![NOT_IMPLEMENTED])
        }

        #[inline(always)]
        fn size() -> u8 {
            Store::<BookKey>::size() + 3
        }
    }

    #[derive(Drop)]
    struct Queue {
        tree: StorageMap<felt252>,
        orders: StorageMap<Order>
    }

    impl QueueStoreImpl of Store<Queue> {
        #[inline(always)]
        fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Queue> {
            SyscallResult::Ok(
                Queue {
                    tree: StorageMapTrait::fetch(address_domain, base),
                    orders: StorageMapTrait::fetch(
                        address_domain,
                        storage_base_address_from_felt252(
                            storage_address_from_base(base).into() + 1
                        )
                    )
                }
            )
        }

        #[inline(always)]
        fn write(address_domain: u32, base: StorageBaseAddress, value: Queue) -> SyscallResult<()> {
            SyscallResult::Err(array![NOT_IMPLEMENTED])
        }

        #[inline(always)]
        fn read_at_offset(
            address_domain: u32, base: StorageBaseAddress, offset: u8
        ) -> SyscallResult<Queue> {
            SyscallResult::Err(array![NOT_IMPLEMENTED])
        }

        #[inline(always)]
        fn write_at_offset(
            address_domain: u32, base: StorageBaseAddress, offset: u8, value: Queue
        ) -> SyscallResult<()> {
            SyscallResult::Err(array![NOT_IMPLEMENTED])
        }

        #[inline(always)]
        fn size() -> u8 {
            2
        }
    }

    #[derive(Copy, Drop, starknet::Store)]
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
