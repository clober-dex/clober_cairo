use clober_cairo::libraries::tick::Tick;
use clober_cairo::libraries::tick_bitmap::TickBitmap;
use clober_cairo::libraries::tick_bitmap::TickBitmapTrait;
use clober_cairo::libraries::total_claimable_map::{TotalClaimableOf, TotalClaimableOfTrait};
use clober_cairo::libraries::segmented_segment_tree::{
    SegmentedSegmentTree, SegmentedSegmentTreeTrait,
};
use clober_cairo::libraries::order_id::OrderId;
use clober_cairo::libraries::storage_map::{StorageMap, Felt252Map, Felt252MapTrait};
use starknet::ContractAddress;
use starknet::storage_access::{
    StorageBaseAddress, storage_address_from_base, storage_base_address_from_felt252,
};
use starknet::{Store, SyscallResult};
use clober_cairo::utils::constants::{TWO_POW_15, MASK_15};
use clober_cairo::libraries::order::{Order, OrderStorePacking};
use clober_cairo::libraries::storage_array::{StorageArray, StorageArrayTrait};

const NOT_IMPLEMENTED: felt252 = 'Not implemented';

#[derive(Drop)]
pub struct Book {
    pub queues: StorageMap<Tick, Queue>,
    pub tick_bitmap: TickBitmap,
    pub total_claimable_of: TotalClaimableOf,
}

#[derive(Drop)]
pub struct Queue {
    tree: SegmentedSegmentTree,
    orders: StorageArray<Order>,
}

pub mod Errors {
    pub const ZERO_UNIT: felt252 = 'Zero unit';
    pub const QUEUE_REPLACE_FAILED: felt252 = 'Queue replace failed';
    pub const CANCEL_FAILED: felt252 = 'Cancel failed';
}

impl BookStoreImpl of Store<Book> {
    #[inline(always)]
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Book> {
        let base_felt252: felt252 = storage_address_from_base(base).into();
        let queues_offset: felt252 = Store::<StorageMap<Tick, Queue>>::size().into();
        let tick_bitmap_offset: felt252 = Store::<Felt252Map<u256>>::size().into();
        SyscallResult::Ok(
            Book {
                queues: Felt252MapTrait::fetch(address_domain, base),
                tick_bitmap: Felt252MapTrait::fetch(
                    address_domain, storage_base_address_from_felt252(base_felt252 + queues_offset),
                ),
                total_claimable_of: Felt252MapTrait::fetch(
                    address_domain,
                    storage_base_address_from_felt252(
                        base_felt252 + queues_offset + tick_bitmap_offset,
                    ),
                ),
            },
        )
    }

    #[inline(always)]
    fn write(address_domain: u32, base: StorageBaseAddress, value: Book) -> SyscallResult<()> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }

    #[inline(always)]
    fn read_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8,
    ) -> SyscallResult<Book> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }

    #[inline(always)]
    fn write_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8, value: Book,
    ) -> SyscallResult<()> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }

    #[inline(always)]
    fn size() -> u8 {
        Store::<StorageMap<Tick, Queue>>::size()
            + Store::<Felt252Map<u256>>::size()
            + Store::<Felt252Map<felt252>>::size()
    }
}

impl QueueStoreImpl of Store<Queue> {
    #[inline(always)]
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Queue> {
        let base_felt252: felt252 = storage_address_from_base(base).into();
        let tree_offset: felt252 = Store::<Felt252Map<felt252>>::size().into();
        SyscallResult::Ok(
            Queue {
                tree: Felt252MapTrait::fetch(address_domain, base),
                orders: StorageArrayTrait::fetch(
                    address_domain, storage_base_address_from_felt252(base_felt252 + tree_offset),
                ),
            },
        )
    }

    #[inline(always)]
    fn write(address_domain: u32, base: StorageBaseAddress, value: Queue) -> SyscallResult<()> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }

    #[inline(always)]
    fn read_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8,
    ) -> SyscallResult<Queue> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }

    #[inline(always)]
    fn write_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8, value: Queue,
    ) -> SyscallResult<()> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }

    #[inline(always)]
    fn size() -> u8 {
        Store::<Felt252Map<felt252>>::size() + Store::<Felt252Map<Order>>::size()
    }
}

#[generate_trait]
pub impl BookImpl of BookTrait {
    fn depth(self: @Book, tick: Tick) -> u64 {
        let mut tree = Self::_get_queue(self, tick).tree;
        let mut total_claimable_of = *self.total_claimable_of;
        tree.total() - total_claimable_of.get(tick)
    }

    fn highest(self: @Book) -> Tick {
        self.tick_bitmap.highest()
    }

    fn max_less_than(self: @Book, tick: Tick) -> Tick {
        self.tick_bitmap.max_less_than(tick)
    }

    fn is_empty(self: @Book) -> bool {
        self.tick_bitmap.is_empty()
    }

    fn get_order(self: @Book, tick: Tick, index: u64) -> Order {
        let mut queue = Self::_get_queue(self, tick);
        Self::_get_order(@queue, index)
    }

    fn calculate_claimable_unit(self: @Book, tick: Tick, index: u64) -> u64 {
        let mut queue = Self::_get_queue(self, tick);
        let order_unit = Self::_get_order(@queue, index).pending;
        let length: u64 = Self::_get_orders_length(@queue);

        if index + TWO_POW_15 < length {
            return order_unit;
        }
        let mut total_claimable_of = *self.total_claimable_of;
        let total_claimable_unit = total_claimable_of.get(tick);
        let l = length & MASK_15;
        let r = (index + 1) & MASK_15;
        let range_right = if l < r {
            queue.tree.query(l.into(), r.into())
        } else {
            queue.tree.total() - queue.tree.query(r.into(), l.into())
        };

        if range_right - order_unit >= total_claimable_unit {
            0
        } else if range_right <= total_claimable_unit {
            order_unit
        } else {
            total_claimable_unit - (range_right - order_unit)
        }
    }

    fn make(ref self: Book, tick: Tick, unit: u64, provider: ContractAddress) -> u64 {
        assert(unit != 0, Errors::ZERO_UNIT);
        if !self.tick_bitmap.has(tick) {
            self.tick_bitmap.set(tick);
        }

        let mut queue = Self::_get_queue(@self, tick);
        // Todo
        let order_index: u64 = Self::_get_orders_length(@queue);

        if order_index >= TWO_POW_15 {
            let stale_order_index: u64 = order_index - TWO_POW_15;
            let stale_pending_unit = Self::_get_order(@queue, stale_order_index).pending;
            if stale_pending_unit > 0 {
                let claimable = Self::calculate_claimable_unit(@self, tick, stale_order_index);
                assert(claimable == stale_pending_unit, Errors::QUEUE_REPLACE_FAILED);
            }

            let stale_ordered_unit = queue.tree.get_node((order_index & MASK_15).into());
            if stale_ordered_unit > 0 {
                self.total_claimable_of.sub(tick, stale_ordered_unit);
            }
        }

        queue.tree.update((order_index & MASK_15).into(), unit);

        Self::_append_order(
            ref queue, Order { pending: unit, provider, initial: unit, canceled: 0 },
        );
        order_index
    }

    fn take(ref self: Book, tick: Tick, max_take_unit: u64) -> u64 {
        let current_depth = Self::depth(@self, tick);
        let taken_unit = if current_depth > max_take_unit {
            max_take_unit
        } else {
            self.tick_bitmap.clear(tick);
            current_depth
        };

        self.total_claimable_of.add(tick, taken_unit);
        taken_unit
    }

    fn cancel(ref self: Book, order_id: OrderId, to: u64) -> (u64, u64) {
        let tick = order_id.tick;
        let order_index = order_id.index;
        let mut queue = Self::_get_queue(@self, tick);
        let order = Self::_get_order(@queue, order_index);
        let claimable_unit = Self::calculate_claimable_unit(@self, tick, order_index);
        let after_pending = to + claimable_unit;
        assert(after_pending <= order.pending, Errors::CANCEL_FAILED);
        let canceled = order.pending - after_pending;
        queue
            .tree
            .update(
                (order_index & MASK_15).into(),
                queue.tree.get_node((order_index & MASK_15).into()) - canceled,
            );
        Self::_set_order(
            ref queue,
            order_index,
            Order {
                pending: after_pending,
                provider: order.provider,
                initial: order.initial,
                canceled: order.canceled + canceled,
            },
        );

        if Self::depth(@self, tick) == 0 {
            self.tick_bitmap.clear(tick);
        }

        (canceled, after_pending)
    }

    fn claim(ref self: Book, tick: Tick, index: u64) -> u64 {
        let mut queue = Self::_get_queue(@self, tick);
        let mut order = Self::_get_order(@queue, index);
        let claimable_unit = Self::calculate_claimable_unit(@self, tick, index);
        order.pending -= claimable_unit;
        Self::_set_order(ref queue, index, order);
        claimable_unit
    }

    fn _get_queue(self: @Book, tick: Tick) -> Queue {
        Felt252MapTrait::read_at(self.queues, tick.into())
    }

    fn _get_order(self: @Queue, order_index: u64) -> Order {
        StorageArrayTrait::read_at(self.orders, order_index)
    }

    fn _set_order(ref self: Queue, order_index: u64, order: Order) {
        StorageArrayTrait::write_at(ref self.orders, order_index, order);
    }

    fn _append_order(ref self: Queue, order: Order) {
        StorageArrayTrait::append(ref self.orders, order);
    }

    fn _get_orders_length(self: @Queue) -> u64 {
        StorageArrayTrait::len(self.orders)
    }
}
