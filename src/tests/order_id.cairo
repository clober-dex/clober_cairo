use clober_cairo::libraries::order_id::OrderId;
use clober_cairo::libraries::order_id::OrderIdImpl;
use starknet::storage_access::{StorePacking};
use clober_cairo::utils::constants::{TWO_POW_24};

#[test]
fn encode() {
    let order_id = OrderId { book_id: 1, tick: 2, index: 3 };
    let encoded = order_id.encode();
    assert_eq!(encoded, 0x10000020000000003_felt252);

    let order_id = OrderId { book_id: 1, tick: TWO_POW_24 - 2, index: 3 };
    let encoded = order_id.encode();
    assert_eq!(encoded, 0x1fffffe0000000003_felt252);
}

#[test]
fn unpack() {
    let encoded = 0x10000020000000003_felt252;
    let order_id: OrderId = StorePacking::unpack(encoded);
    assert_eq!(order_id.book_id, 1);
    assert_eq!(order_id.tick, 2);
    assert_eq!(order_id.index, 3);

    let encoded = 0x1fffffe0000000003_felt252;
    let order_id: OrderId = StorePacking::unpack(encoded);
    assert_eq!(order_id.book_id, 1);
    assert_eq!(order_id.tick, TWO_POW_24 - 2);
    assert_eq!(order_id.index, 3);
}
