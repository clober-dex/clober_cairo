use starknet::storage_access::{StorePacking};

const TWO_POW_192: u256 = 0x1000000000000000000000000000000000000000000000000; // 2**192
const TWO_POW_64: u256 = 0x10000000000000000; // 2**64
const TWO_POW_40: u64 = 0x10000000000; // 2**40

#[derive(Copy, Drop, Serde, Debug)]
pub struct OrderId {
    pub book_id: felt252, // u192
    pub tick: u32, // todo: change to Tick struct
    pub index: u64, // u40
}

#[generate_trait]
impl OrderIdImpl of OrderIdTrait {
    fn encode(self: OrderId) -> felt252 {
        assert(self.book_id.into() < TWO_POW_192, 'book_id overflow');
        assert(self.index < TWO_POW_40, 'index overflow');
        return self.book_id.try_into().unwrap() * TWO_POW_64.try_into().unwrap()
            + self.tick.into() * TWO_POW_40.try_into().unwrap()
            + self.index.into();
    }
}

impl OrderIdStoragePacking of StorePacking<OrderId, felt252> {
    fn pack(value: OrderId) -> felt252 {
        value.encode()
    }

    fn unpack(value: felt252) -> OrderId {
        let casted_value: u256 = value.into();
        let book_id: u256 = casted_value / TWO_POW_64.into();
        let tick_felt252: felt252 = (casted_value % TWO_POW_64.into() / TWO_POW_40.into())
            .try_into()
            .unwrap();
        let index: u64 = (casted_value % TWO_POW_40.into()).try_into().unwrap();
        OrderId {
            book_id: book_id.try_into().unwrap(), tick: tick_felt252.try_into().unwrap(), index
        }
    }
}

#[cfg(test)]
mod tests {
    use super::OrderId;
    use super::OrderIdImpl;
    use super::StorePacking;

    // todo delete this
    const TWO_POW_24: u32 = 0x1000000; // 2**24

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
}
