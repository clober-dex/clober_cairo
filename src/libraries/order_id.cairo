use starknet::storage_access::{StorePacking};

const MASK_BOOK_ID: u256 = consteval_int!(2**192);
const MASK_TICK: u256 = consteval_int!(2**32);
const MASK_INDEX: u256 = consteval_int!(2**40);

const TWO_POW_72: u256 = consteval_int!(2**72);
const TWO_POW_40: u256 = consteval_int!(2**40);

#[derive(Copy, Drop, Serde, Debug)]
pub struct OrderId {
    pub book_id: u256, // u192
    pub tick: i32, // u32
    pub index: u64, // u40
}

#[generate_trait]
impl OrderIdImpl of OrderIdTrait {
    fn encode(self: OrderId) -> u256 {
        assert(self.book_id < MASK_BOOK_ID, "book_id overflow");
        assert(self.tick < MASK_TICK, "tick overflow");
        assert(self.index < MASK_INDEX, "index overflow");
        return self.book_id * TWO_POW_72 + self.tick * TWO_POW_40 + self.index;
    }
}

impl OrderIdStoragePacking of StoragePacking<OrderId, u256> {
    fn pack(value: OrderId) -> u256 {
        value.encode()
    }

    fn unpack(value: u256) -> OrderId {
        let book_id = value / TWO_POW_72;
        let tick = (value % TWO_POW_72) / TWO_POW_40;
        let index = value % TWO_POW_40;
        OrderId { book_id, tick, index }
    }
}

#[cfg(test)]
mod tests {
    use super::OrderId;
    use super::OrderIdImpl;
    use super::StoragePacking;

    #[test]
    fn encode() {
        let order_id = OrderId { book_id: 1, tick: 2, index: 3 };
        let encoded = order_id.encode();
        assert_eq!(encoded, 0x10000020000000003_u256);

        let order_id = OrderId { book_id: 1, tick: -2, index: 3 };
        let encoded = order_id.encode();
        assert_eq!(encoded, 0x1fffffe0000000003_u256);
    }

    #[test]
    fn unpack() {
        let encoded = 0x10000020000000003_u256;
        let order_id = OrderId::unpack(encoded);
        assert_eq!(order_id.book_id, 1);
        assert_eq!(order_id.tick, 2);
        assert_eq!(order_id.index, 3);

        let encoded = 0x1fffffe0000000003_u256;
        let order_id = OrderId::unpack(encoded);
        assert_eq!(order_id.book_id, 1);
        assert_eq!(order_id.tick, -2);
        assert_eq!(order_id.index, 3);
    }
}
