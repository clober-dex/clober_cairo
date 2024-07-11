use clober_cairo::libraries::tick::Tick;
use clober_cairo::libraries::tick::TickImpl;
use clober_cairo::utils::constants::{MIN_TICK, MAX_TICK};

#[test]
fn test_tick_to_price() {
    let tick = Tick { value: MIN_TICK };
    let mut last_price = TickImpl::to_price(tick);
    let mut price: u256 = 0;
    let mut index = MIN_TICK + 1;
    while index < MIN_TICK + 100 {
        price = TickImpl::to_price(Tick { value: index });

        let tick = TickImpl::from_price(price - 1);
        assert_eq!(tick.value, index - 1, "LOWER_PRICE");

        let tick = TickImpl::from_price(price);
        assert_eq!(tick.value, index, "EXACT_PRICE");

        let tick = TickImpl::from_price(price + 1);
        assert_eq!(tick.value, index, "HIGHER_PRICE");

        let spread = (price - last_price) * 1000000 / last_price;
        assert!(spread >= 99);
        assert!(spread <= 100);
        last_price = price;
        index += 1;
    }
}