use clober_cairo::libraries::tick::TickImpl;
use clober_cairo::utils::constants::MIN_TICK;

#[test]
fn test_tick_to_price() {
    let tick = MIN_TICK.into();
    let mut last_price = TickImpl::to_price(tick);
    let mut price: u256 = 0;
    let mut index = MIN_TICK + 1;
    while index < MIN_TICK + 100 {
        price = TickImpl::to_price(index.into());

        let tick = TickImpl::from_price(price - 1);
        assert_eq!(tick.into(), index - 1, "LOWER_PRICE");

        let tick = TickImpl::from_price(price);
        assert_eq!(tick.into(), index, "EXACT_PRICE");

        let tick = TickImpl::from_price(price + 1);
        assert_eq!(tick.into(), index, "HIGHER_PRICE");

        let spread = (price - last_price) * 1000000 / last_price;
        assert!(spread >= 99);
        assert!(spread <= 100);
        last_price = price;
        index += 1;
    }
}
