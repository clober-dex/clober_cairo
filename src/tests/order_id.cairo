use clober_cairo::libraries::order_id::OrderId;
use clober_cairo::libraries::order_id::OrderIdImpl;
use clober_cairo::libraries::tick::Tick;
use clober_cairo::utils::constants::{TWO_POW_24};

#[test]
fn encode() {
    let order_id = OrderId { book_id: 1, tick: 2_i32.into(), index: 3 };
    let encoded = order_id.encode();
    assert_eq!(encoded, 0x10000020000000003_felt252);

    let order_id = OrderId { book_id: 1, tick: (-2_i32).into(), index: 3 };
    let encoded = order_id.encode();
    assert_eq!(encoded, 0x1fffffe0000000003_felt252);
}

#[test]
fn decode() {
    let encoded = 0x10000020000000003_felt252;
    let order_id: OrderId = OrderIdImpl::decode(encoded);
    assert_eq!(order_id.book_id, 1);
    assert_eq!(order_id.tick.into(), 2);
    assert_eq!(order_id.index, 3);

    let encoded = 0x1fffffe0000000003_felt252;
    let order_id: OrderId = OrderIdImpl::decode(encoded);
    assert_eq!(order_id.book_id, 1);
    assert_eq!(order_id.tick.into(), -2);
    assert_eq!(order_id.index, 3);
}
