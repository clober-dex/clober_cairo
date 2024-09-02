use clober_cairo::libraries::book::{Book, BookImpl};
use clober_cairo::libraries::storage_map::Felt252MapTrait;
use clober_cairo::utils::constants::{ZERO_ADDRESS, TWO_POW_62};
use clober_cairo::libraries::tick::Tick;
use starknet::storage_access::storage_base_address_from_felt252;
use clober_cairo::libraries::order_id::OrderId;

#[test]
fn test_make() {
    let mut book: Book = Book {
        queues: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654321)),
        tick_bitmap: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654325)),
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
#[should_panic(expected: ('Zero unit',))]
fn test_make_with_zero_unit() {
    let mut book: Book = Book {
        queues: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654321)),
        tick_bitmap: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654325)),
        total_claimable_of: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654327))
    };
    let mut tick: Tick = 0_i32.into();
    book.make(tick, 0, ZERO_ADDRESS());
}

#[test]
fn test_take() {
    let mut book: Book = Book {
        queues: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654321)),
        tick_bitmap: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654325)),
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
fn test_take_and_clean_tick_bitmap() {
    let mut book: Book = Book {
        queues: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654321)),
        tick_bitmap: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654325)),
        total_claimable_of: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654327))
    };
    let mut tick: Tick = 0_i32.into();

    book.make(tick, 100, ZERO_ADDRESS());
    book.make(4_i32.into(), 200, ZERO_ADDRESS());

    book.take(tick, 200);

    assert_eq!(book.highest().into(), 4);
}

#[test]
fn test_cancel() {
    let book_id = 0x12345678.try_into().unwrap();
    let mut book: Book = Book {
        queues: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654321)),
        tick_bitmap: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654325)),
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

    let mut order_id = OrderId { book_id, tick: tick, index: 0 };
    let (canceled_unit, pending_unit) = book.cancel(order_id, 40);
    assert_eq!(pending_unit, 70);
    assert_eq!(canceled_unit, 30);
    assert_eq!(book.depth(tick), 240);

    order_id = OrderId { book_id, tick: tick, index: 1 };
    let (canceled_unit, pending_unit) = book.cancel(order_id, 150);
    assert_eq!(canceled_unit, 50);
    assert_eq!(book.depth(tick), 190);
    assert_eq!(pending_unit, 150);

    order_id = OrderId { book_id, tick: tick, index: 1 };
    let (canceled_unit, pending_unit) = book.cancel(order_id, 0);
    assert_eq!(canceled_unit, 150);
    assert_eq!(book.depth(tick), 40);
    assert_eq!(pending_unit, 0);
}

#[test]
#[should_panic(expected: ('Cancel failed',))]
fn test_cancel_to_too_large_amount() {
    let book_id = 0x12345678.try_into().unwrap();
    let mut book: Book = Book {
        queues: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654321)),
        tick_bitmap: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654325)),
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

    assert_eq!(book.get_order(tick, index: 0).pending, 100);
    book.cancel(OrderId { book_id, tick, index: 0 }, 71);
}

fn test_cancel_and_remove() {
    let book_id = 0x12345678.try_into().unwrap();
    let mut book: Book = Book {
        queues: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654321)),
        tick_bitmap: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654325)),
        total_claimable_of: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654327))
    };

    book.make(0_i32.into(), 100, ZERO_ADDRESS());
    book.make(123_i32.into(), 200, ZERO_ADDRESS());
    book.make(1234_i32.into(), 300, ZERO_ADDRESS());

    assert_eq!(book.highest(), 1234);

    book.cancel(OrderId { book_id, tick: 1234_i32.into(), index: 0 }, 0);

    assert_eq!(book.highest(), 123);

    book.cancel(OrderId { book_id, tick: 0_i32.into(), index: 0 }, 0);

    assert_eq!(book.depth(0_i32.into()) > 0, false);
}

#[test]
fn test_claim() {
    let mut book: Book = Book {
        queues: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654321)),
        tick_bitmap: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654325)),
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

#[test]
fn test_calculate_claimable_unit() {
    let mut book: Book = Book {
        queues: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654321)),
        tick_bitmap: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654325)),
        total_claimable_of: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654327))
    };

    book.make(0_i32.into(), 100, ZERO_ADDRESS());
    book.make(0_i32.into(), 200, ZERO_ADDRESS());
    book.make(0_i32.into(), 300, ZERO_ADDRESS());

    book.take(0_i32.into(), 150);

    assert_eq!(book.calculate_claimable_unit(0_i32.into(), 0), 100);
    assert_eq!(book.calculate_claimable_unit(0_i32.into(), 1), 50);
    assert_eq!(book.calculate_claimable_unit(0_i32.into(), 2), 0);
}

#[test]
fn test_calculate_claimable_unit_not_overflow() {
    let mut book: Book = Book {
        queues: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654321)),
        tick_bitmap: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654325)),
        total_claimable_of: Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654327))
    };

    book.make(0_i32.into(), (TWO_POW_62 - 1), ZERO_ADDRESS());
    book.take(0_i32.into(), (TWO_POW_62 - 1));
    book.calculate_claimable_unit(0_i32.into(), 0);
}
