use clober_cairo::libraries::book::Book::{Queue, Book, BookImpl};
use clober_cairo::libraries::book_key::{BookKey, BookKeyTrait};
use clober_cairo::libraries::fee_policy::FeePolicy;
use clober_cairo::libraries::hooks::Hooks;
use clober_cairo::libraries::tick_bitmap::TickBitmap;
use clober_cairo::libraries::storage_map::{Felt252Map, Felt252MapTrait};
use clober_cairo::utils::constants::{ZERO_ADDRESS};
use clober_cairo::libraries::tick::Tick;
use starknet::storage_access::storage_base_address_from_felt252;
use clober_cairo::libraries::segmented_segment_tree::SegmentedSegmentTree;
use clober_cairo::libraries::order_id::OrderId;


#[test]
fn test_make() {
    let key = BookKey {
        base: 0x12345678.try_into().unwrap(),
        quote: 0x87654321.try_into().unwrap(),
        hooks: 0x0.try_into().unwrap(),
        unit_size: 0x1,
        maker_policy: FeePolicy { uses_quote: true, rate: 0 },
        taker_policy: FeePolicy { uses_quote: true, rate: 0 }
    };
    let mut book: Book = Book {
        key: key,
        queues: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654321)),
        tick_bitmap: TickBitmap {
            map: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654325))
        },
        total_claimable_of: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654327))
    };
    let mut tick: Tick = 0_i32.into();
    let mut index = book.make(tick, 100, ZERO_ADDRESS());

    assert_eq!(book.is_empty(), false);
    assert_eq!(book.highest().into(), 0);
    assert_eq!(index, 0);
    assert_eq!(book.depth(tick), 100);

    index = book.make(tick, 200, ZERO_ADDRESS());
    assert_eq!(book.highest().into(), 0);
    assert_eq!(index, 1);
    assert_eq!(book.depth(tick), 300);

    tick = 1_i32.into();
    index = book.make(tick, 200, ZERO_ADDRESS());
    assert_eq!(index, 0);
    assert_eq!(book.depth(tick), 200);
    assert_eq!(book.highest().into(), 1);
}

#[test]
fn test_take() {
    let key = BookKey {
        base: 0x12345678.try_into().unwrap(),
        quote: 0x87654321.try_into().unwrap(),
        hooks: 0x0.try_into().unwrap(),
        unit_size: 0x1,
        maker_policy: FeePolicy { uses_quote: true, rate: 0 },
        taker_policy: FeePolicy { uses_quote: true, rate: 0 }
    };
    let mut book: Book = Book {
        key: key,
        queues: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654321)),
        tick_bitmap: TickBitmap {
            map: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654325))
        },
        total_claimable_of: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654327))
    };
    let mut tick: Tick = 0_i32.into();

    book.make(tick, 100, ZERO_ADDRESS());
    book.make(tick, 200, ZERO_ADDRESS());
    book.make(tick, 300, ZERO_ADDRESS());
    book.make(tick, 400, ZERO_ADDRESS());
    book.make(tick, 500, ZERO_ADDRESS());

    let mut unit = book.take(tick, 150);
    assert_eq!(unit, 150);
    assert_eq!(book.depth(tick), 1350);

    unit = book.take(tick, 1000);
    assert_eq!(unit, 1000);
    assert_eq!(book.depth(tick), 350);

    unit = book.take(tick, 1000);
    assert_eq!(unit, 350);
    assert_eq!(book.depth(tick), 0);
}

#[test]
fn test_cancel() {
    let key = BookKey {
        base: 0x12345678.try_into().unwrap(),
        quote: 0x87654321.try_into().unwrap(),
        hooks: 0x0.try_into().unwrap(),
        unit_size: 0x1,
        maker_policy: FeePolicy { uses_quote: true, rate: 0 },
        taker_policy: FeePolicy { uses_quote: true, rate: 0 }
    };
    let mut book: Book = Book {
        key: key,
        queues: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654321)),
        tick_bitmap: TickBitmap {
            map: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654325))
        },
        total_claimable_of: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654327))
    };

    let mut tick: Tick = 0_i32.into();
    let mut index = book.make(tick, 100, ZERO_ADDRESS());
    assert_eq!(index, 0);
    assert_eq!(book.depth(tick), 100);

    index = book.make(tick, 200, ZERO_ADDRESS());
    assert_eq!(index, 1);
    assert_eq!(book.depth(tick), 300);

    book.take(tick, 30);
    assert_eq!(book.depth(tick), 270);

    let mut order_id = OrderId { book_id: key.to_id(), tick: tick, index: 0 };
    let (canceled_unit, pending_unit) = book.cancel(order_id, 40);
    assert_eq!(pending_unit, 70);
    assert_eq!(canceled_unit, 30);
    assert_eq!(book.depth(tick), 240);

    order_id = OrderId { book_id: key.to_id(), tick: tick, index: 1 };
    let (canceled_unit, pending_unit) = book.cancel(order_id, 150);
    assert_eq!(canceled_unit, 50);
    assert_eq!(book.depth(tick), 190);
    assert_eq!(pending_unit, 150);

    order_id = OrderId { book_id: key.to_id(), tick: tick, index: 1 };
    let (canceled_unit, pending_unit) = book.cancel(order_id, 0);
    assert_eq!(canceled_unit, 150);
    assert_eq!(book.depth(tick), 40);
    assert_eq!(pending_unit, 0);
}

#[test]
fn test_claim() {
    let key = BookKey {
        base: 0x12345678.try_into().unwrap(),
        quote: 0x87654321.try_into().unwrap(),
        hooks: 0x0.try_into().unwrap(),
        unit_size: 0x1,
        maker_policy: FeePolicy { uses_quote: true, rate: 0 },
        taker_policy: FeePolicy { uses_quote: true, rate: 0 }
    };
    let mut book: Book = Book {
        key: key,
        queues: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654321)),
        tick_bitmap: TickBitmap {
            map: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654325))
        },
        total_claimable_of: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654327))
    };

    let mut tick: Tick = 0_i32.into();

    book.make(tick, 100, ZERO_ADDRESS());
    book.make(tick, 200, ZERO_ADDRESS());
    book.make(tick, 300, ZERO_ADDRESS());

    book.take(tick, 150);

    assert_eq!(book.get_order(tick, 0).pending, 100);
    assert_eq!(book.get_order(tick, 1).pending, 200);
    assert_eq!(book.get_order(tick, 2).pending, 300);

    assert_eq!(book.calculate_claimable_unit(tick, 0), 100);
    assert_eq!(book.calculate_claimable_unit(tick, 1), 50);
    assert_eq!(book.calculate_claimable_unit(tick, 2), 0);

    let mut claimed_unit = book.claim(tick, 0);
    assert_eq!(claimed_unit, 100);
    claimed_unit = book.claim(tick, 1);
    assert_eq!(claimed_unit, 50);
    claimed_unit = book.claim(tick, 2);
    assert_eq!(claimed_unit, 0);

    assert_eq!(book.get_order(tick, 0).pending, 0);
    assert_eq!(book.get_order(tick, 1).pending, 150);
    assert_eq!(book.get_order(tick, 2).pending, 300);
}
