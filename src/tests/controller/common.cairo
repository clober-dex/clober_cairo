use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use openzeppelin_testing::constants::ZERO;
use clober_cairo::libraries::book_key::{BookKey, BookKeyTrait};
use clober_cairo::libraries::fee_policy::FeePolicy;
use clober_cairo::libraries::order_id::{OrderId, OrderIdTrait};
use clober_cairo::libraries::tick::Tick;
use clober_cairo::interfaces::controller::{IControllerDispatcher, IControllerDispatcherTrait};
use clober_cairo::utils::constants::WAD;

use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

pub fn PRICE_TICK() -> Tick {
    2848
}
pub fn QUOTE_AMOUNT1() -> u256 {
    200 * WAD + 123
}
pub fn MAKER1() -> ContractAddress {
    contract_address_const::<'maker1'>()
}

pub fn valid_key(base: IERC20Dispatcher, quote: IERC20Dispatcher) -> BookKey {
    BookKey {
        base: base.contract_address,
        quote: quote.contract_address,
        hooks: ZERO(),
        unit_size: 1000000000000,
        taker_policy: FeePolicy { uses_quote: true, rate: 100 },
        maker_policy: FeePolicy { uses_quote: true, rate: -100 },
    }
}

pub fn make_order(
    controller: IControllerDispatcher,
    book_key: BookKey,
    tick: Tick,
    quote_amount: u256,
    base: IERC20Dispatcher,
    quote: IERC20Dispatcher,
    maker: ContractAddress
) -> OrderId {
    OrderIdTrait::decode(
        controller
            .make(
                book_key.to_id(),
                tick,
                quote_amount,
                ArrayTrait::new().span(),
                get_block_timestamp()
            )
    )
}
