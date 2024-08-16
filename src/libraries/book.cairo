pub mod Book {
    use clober_cairo::libraries::tick::Tick;
    use clober_cairo::libraries::tick_bitmap::TickBitmap;
    use clober_cairo::libraries::tick_bitmap::TickBitmapTrait;
    use clober_cairo::libraries::total_claimable_map::{add, get, sub};
    use clober_cairo::libraries::fee_policy::FeePolicy;
    use clober_cairo::libraries::segmented_segment_tree::SegmentedSegmentTree;
    use clober_cairo::libraries::order_id::OrderId;
    use clober_cairo::libraries::book_key::BookKey;
    use clober_cairo::libraries::hooks::Hooks;
    use clober_cairo::libraries::storage_map::{Felt252Map, Felt252MapTrait};
    use starknet::ContractAddress;
    use starknet::storage_access::{
        StorageBaseAddress, storage_address_from_base, storage_base_address_from_felt252
    };
    use starknet::storage::{Vec, VecTrait};
    use starknet::{Store, SyscallResult, SyscallResultTrait};
    use openzeppelin_utils::structs::storage_array::{StorageArray};
    use clober_cairo::utils::constants::{TWO_POW_15, ZERO_ADDRESS, MAX_FELT252};

    const NOT_IMPLEMENTED: felt252 = 'Not implemented';
    const MAX_ORDER: u64 = TWO_POW_15;


    #[derive(Drop)]
    pub struct Book {
        pub key: BookKey,
        pub queues: Felt252Map<Queue>, // Todo to storage map
        pub tick_bitmap: TickBitmap,
        pub total_claimable_of: Felt252Map<felt252>,
    }

    impl BookStoreImpl of Store<Book> {
        #[inline(always)]
        fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Book> {
            let base_felt252: felt252 = storage_address_from_base(base).into();
            let book_key_offset: felt252 = Store::<BookKey>::size().into();
            let queues_offset: felt252 = Store::<Felt252Map<Queue>>::size().into();
            let tick_bitmap_offset: felt252 = Store::<Felt252Map<u256>>::size().into();
            SyscallResult::Ok(
                Book {
                    key: Store::read(address_domain, base).unwrap_syscall(),
                    queues: Felt252MapTrait::fetch(
                        address_domain,
                        storage_base_address_from_felt252(base_felt252 + book_key_offset)
                    ),
                    tick_bitmap: TickBitmap {
                        map: Felt252MapTrait::fetch(
                            address_domain,
                            storage_base_address_from_felt252(
                                base_felt252 + book_key_offset + queues_offset
                            )
                        )
                    },
                    total_claimable_of: Felt252MapTrait::fetch(
                        address_domain,
                        storage_base_address_from_felt252(
                            base_felt252 + book_key_offset + queues_offset + tick_bitmap_offset
                        )
                    )
                }
            )
        }

        #[inline(always)]
        fn write(address_domain: u32, base: StorageBaseAddress, value: Book) -> SyscallResult<()> {
            let base_felt252: felt252 = storage_address_from_base(base).into();
            let book_key_offset: felt252 = Store::<BookKey>::size().into();
            let queues_offset: felt252 = Store::<Felt252Map<Queue>>::size().into();
            let tick_bitmap_offset: felt252 = Store::<Felt252Map<u256>>::size().into();

            // Todo error check
            Store::write(address_domain, base, value.key);
            Store::write(
                address_domain,
                storage_base_address_from_felt252(base_felt252 + book_key_offset),
                value.queues
            );
            Store::write(
                address_domain,
                storage_base_address_from_felt252(base_felt252 + book_key_offset + queues_offset),
                value.tick_bitmap.map
            );
            Store::write(
                address_domain,
                storage_base_address_from_felt252(
                    base_felt252 + book_key_offset + queues_offset + tick_bitmap_offset
                ),
                value.total_claimable_of
            )
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
            Store::<BookKey>::size()
                + Store::<Felt252Map<Queue>>::size()
                + Store::<Felt252Map<u256>>::size()
                + Store::<Felt252Map<felt252>>::size()
        }
    }

    #[derive(Drop)]
    pub struct Queue {
        tree: Felt252Map<felt252>,
        // Todo to Vec
        orders: Felt252Map<Order>,
        size: u64
    }

    impl QueueStoreImpl of Store<Queue> {
        #[inline(always)]
        fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Queue> {
            let base_felt252: felt252 = storage_address_from_base(base).into();
            let tree_offset: felt252 = Store::<Felt252Map<felt252>>::size().into();
            let orders_offset: felt252 = Store::<Felt252Map<felt252>>::size().into();
            SyscallResult::Ok(
                Queue {
                    tree: Felt252MapTrait::fetch(address_domain, base),
                    orders: Felt252MapTrait::fetch(
                        address_domain,
                        storage_base_address_from_felt252(base_felt252 + tree_offset)
                    ),
                    size: 0 // Todo use Vec
                }
            )
        }

        #[inline(always)]
        fn write(address_domain: u32, base: StorageBaseAddress, value: Queue) -> SyscallResult<()> {
            let base_felt252: felt252 = storage_address_from_base(base).into();
            let tree_offset: felt252 = Store::<Felt252Map<felt252>>::size().into();
            let orders_offset: felt252 = Store::<Felt252Map<felt252>>::size().into();

            // Todo error check
            Store::write(address_domain, base, value.tree);
            Store::write(
                address_domain,
                storage_base_address_from_felt252(base_felt252 + tree_offset),
                value.orders
            );
            Store::write(
                address_domain,
                storage_base_address_from_felt252(base_felt252 + tree_offset + orders_offset),
                value.size
            )
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
            Store::<Felt252Map<felt252>>::size()
                + Store::<Felt252Map<Order>>::size()
                + Store::<u64>::size()
        }
    }

    #[derive(Copy, Drop, starknet::Store)]
    pub struct Order {
        pub provider: ContractAddress,
        pub pending: u64
    }

    #[generate_trait]
    pub impl BookImpl of BookTrait {
        fn is_opened(self: @Book) -> bool {
            *self.key.unit_size != 0
        }

        fn check_opened(self: @Book) {
            assert(self.is_opened(), 'book_not_opened');
        }

        fn depth(self: @Book, tick: Tick) -> u64 {
            let mut tree = self.queues.read_at(tick.into()).tree;
            let mut total_claimable_of = *self.total_claimable_of;
            (SegmentedSegmentTree::total(ref tree) - get(ref total_claimable_of, tick).into())
                .try_into()
                .unwrap()
        }

        fn highest(self: @Book) -> Tick {
            let mut tick_bitmap = *self.tick_bitmap;
            TickBitmapTrait::highest(ref tick_bitmap)
        }

        fn max_less_than(self: @Book, tick: Tick) -> Tick {
            let mut tick_bitmap = *self.tick_bitmap;
            TickBitmapTrait::max_less_than(ref tick_bitmap, tick)
        }

        fn is_empty(self: @Book) -> bool {
            let mut tick_bitmap = *self.tick_bitmap;
            TickBitmapTrait::is_empty(ref tick_bitmap)
        }

        fn get_order(self: @Book, tick: Tick, index: u64) -> Order {
            self.queues.read_at(tick.into()).orders.read_at(index.into())
        }

        fn make(ref self: Book, tick: Tick, unit: u64, provider: ContractAddress) -> u64 {
            assert(unit != 0, 'Zero unit');
            let mut tick_bitmap = self.tick_bitmap;
            if !TickBitmapTrait::has(ref tick_bitmap, tick) {
                TickBitmapTrait::set(ref tick_bitmap, tick);
            }

            let mut queue = self.queues.read_at(tick.into());
            // Todo
            let order_index: u64 = queue.orders.read_at(MAX_FELT252).pending;

            if order_index >= MAX_ORDER {
                let stale_order_index: u64 = order_index - MAX_ORDER;
                let stale_pending_unit = queue.orders.read_at(stale_order_index.into()).pending;
                if stale_pending_unit > 0 {
                    let claimable = self.calculate_claimable_unit(tick, stale_order_index);
                    if claimable != stale_pending_unit {
                        panic!("Queue replace failed");
                    }
                }

                let stale_ordered_unit = SegmentedSegmentTree::get(
                    ref queue.tree, (order_index & (MAX_ORDER - 1)).into()
                );
                if stale_ordered_unit > 0 {
                    sub(ref self.total_claimable_of, tick, stale_ordered_unit);
                }
            }

            SegmentedSegmentTree::update(
                ref queue.tree, (order_index & (MAX_ORDER - 1)).into(), unit
            );

            queue.orders.write_at(order_index.into(), Order { pending: unit, provider });
            queue.orders.write_at(MAX_FELT252, Order { pending: order_index + 1, provider: ZERO_ADDRESS() });
            order_index
        }

        fn take(ref self: Book, tick: Tick, max_take_unit: u64) -> u64 {
            let current_depth = Self::depth(@self, tick);
            let taken_unit = if current_depth > max_take_unit {
                max_take_unit
            } else {
                TickBitmapTrait::clear(ref self.tick_bitmap, tick);
                current_depth
            };

            add(ref self.total_claimable_of, tick, taken_unit);
            taken_unit
        }

        fn cancel(ref self: Book, order_id: OrderId, to: u64) -> (u64, u64) {
            let tick = order_id.tick;
            let order_index = order_id.index;
            let mut queue = self.queues.read_at(tick.into());
            let order = queue.orders.read_at(order_index.into());
            let claimable_unit = self.calculate_claimable_unit(tick, order_index);
            let after_pending = to + claimable_unit;
            if order.pending < after_pending {
                panic!("Cancel failed");
            }
            let canceled = order.pending - after_pending;
            SegmentedSegmentTree::update(
                ref queue.tree, (order_index & (MAX_ORDER - 1)).into(), canceled
            );
            queue
                .orders
                .write_at(
                    order_index.into(), Order { pending: after_pending, provider: order.provider }
                );

            if Self::depth(@self, tick) == 0 {
                TickBitmapTrait::clear(ref self.tick_bitmap, tick);
            }

            (canceled, after_pending)
        }

        fn claim(ref self: Book, tick: Tick, index: u64) -> u64 {
            let mut order = Self::get_order(@self, tick, index);
            let claimable_unit = Self::calculate_claimable_unit(@self, tick, index);
            order.pending -= claimable_unit;
            let mut queue = self.queues.read_at(tick.into());
            queue.orders.write_at(index.into(), order);
            claimable_unit
        }

        fn calculate_claimable_unit(self: @Book, tick: Tick, index: u64) -> u64 {
            let order_unit = Self::get_order(self, tick, index).pending;
            let mut queue = self.queues.read_at(tick.into());
            if index + MAX_ORDER < queue.size {
                return order_unit;
            }
            let mut total_claimable_of = *self.total_claimable_of;
            let total_claimable_unit = get(ref total_claimable_of, tick);
            let range_right = Self::_get_claim_range_right(ref queue, index);
            if range_right - order_unit >= total_claimable_unit {
                return 0;
            }

            if range_right <= total_claimable_unit {
                order_unit
            } else {
                total_claimable_unit - (range_right - order_unit)
            }
        }

        fn _get_claim_range_right(ref self: Queue, order_index: u64) -> u64 {
            let l = self.size & MAX_ORDER;
            let r = (order_index + 1) & MAX_ORDER;
            if l < r {
                SegmentedSegmentTree::query(ref self.tree, l.into(), r.into())
            } else {
                SegmentedSegmentTree::total(ref self.tree)
                    - SegmentedSegmentTree::query(ref self.tree, r.into(), l.into())
            }
        }
    }
}
