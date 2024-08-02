pub mod Book {
    use clober_cairo::libraries::tick::Tick;
    use clober_cairo::libraries::tick_bitmap::TickBitmap;
    use clober_cairo::libraries::fee_policy::FeePolicy;
    use clober_cairo::libraries::segmented_segment_tree::SegmentedSegmentTree;
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
    pub struct Book {
        pub key: BookKey,
        pub queues: StorageMap<Queue>,
        pub tickBitmap: TickBitmap,
        pub totalClaimableOf: StorageMap<felt252>,
    }

    impl BookStoreImpl of Store<Book> {
        #[inline(always)]
        fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Book> {
            let base_felt252: felt252 = storage_address_from_base(base).into();
            let book_key_size: felt252 = Store::<BookKey>::size().into();
            SyscallResult::Ok(
                Book {
                    key: Store::read(address_domain, base).unwrap_syscall(),
                    queues: StorageMapTrait::fetch(
                        address_domain,
                        storage_base_address_from_felt252(base_felt252 + book_key_size)
                    ),
                    tickBitmap: TickBitmap {
                        high: StorageMapTrait::fetch(
                            address_domain,
                            storage_base_address_from_felt252(base_felt252 + book_key_size + 1)
                        ),
                        low: StorageMapTrait::fetch(
                            address_domain,
                            storage_base_address_from_felt252(base_felt252 + book_key_size + 2)
                        ),
                    },
                    totalClaimableOf: StorageMapTrait::fetch(
                        address_domain,
                        storage_base_address_from_felt252(base_felt252 + book_key_size + 3)
                    )
                }
            )
        }

        #[inline(always)]
        fn write(address_domain: u32, base: StorageBaseAddress, value: Book) -> SyscallResult<()> {
            Store::write(address_domain, base, value.key)
        }

        #[inline(always)]
        fn read_at_offset(
            address_domain: u32, base: StorageBaseAddress, offset: u8
        ) -> SyscallResult<Book> {
            SyscallResult::Err(array![NOT_IMPLEMENTED])
        }

        #[inline(always)]
        fn write_at_offset(
            address_domain: u32, base: StorageBaseAddress, offset: u8, value: Book
        ) -> SyscallResult<()> {
            SyscallResult::Err(array![NOT_IMPLEMENTED])
        }

        #[inline(always)]
        fn size() -> u8 {
            Store::<BookKey>::size() + 4
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
    pub struct Order {
        pub provider: ContractAddress,
        pub pending: u64
    }

    #[generate_trait]
    pub impl BookImpl of BookTrait {
        fn open(ref self: Book, key: BookKey) {
            panic!("Not implemented")
        }

        fn is_opened(self: @Book) -> bool {
            panic!("Not implemented")
        }

        fn check_opened(self: @Book) {
            panic!("Not implemented")
        }

        fn depth(self: @Book, tick: Tick) -> u64 {
            panic!("Not implemented")
        }

        fn highest(self: @Book) -> Tick {
            panic!("Not implemented")
        }

        fn max_less_than(self: @Book, tick: Tick) -> Tick {
            panic!("Not implemented")
        }

        fn is_empty(self: @Book) -> bool {
            panic!("Not implemented")
        }

        fn get_order(self: @Book, tick: Tick, index: u64) -> Order {
            panic!("Not implemented")
        }

        fn make(ref self: Book, tick: Tick, unit: u64, provider: ContractAddress) -> u64 {
            panic!("Not implemented")
        }

        fn take(ref self: Book, tick: Tick, max_take_unit: u64) -> u64 {
            panic!("Not implemented")
        }

        fn cancel(ref self: Book, order_id: OrderId, to: u64) -> (u64, u64) {
            panic!("Not implemented")
        }

        fn claim(ref self: Book, tick: Tick, index: u64) -> u64 {
            panic!("Not implemented")
        }

        fn calculate_claimable_unit(self: @Book, tick: Tick, index: u64) -> u64 {
            panic!("Not implemented")
        }
    }
}
