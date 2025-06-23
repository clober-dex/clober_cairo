use starknet::{ContractAddress, get_block_timestamp};
use clober_cairo::tests::constants::{ZERO};
use clober_cairo::libraries::book_key::{BookKey, BookKeyTrait};
use clober_cairo::libraries::fee_policy::FeePolicy;
use clober_cairo::libraries::order_id::{OrderId, OrderIdTrait};
use clober_cairo::libraries::tick::Tick;
use clober_cairo::interfaces::controller::{IControllerDispatcher, IControllerDispatcherTrait};
use clober_cairo::utils::constants::{ZERO_ADDRESS, WAD, TWO_POW_248};

use openzeppelin_token::erc20::interface::IERC20Dispatcher;

pub fn PRICE_TICK() -> Tick {
    2848
}
pub fn QUOTE_AMOUNT1() -> u256 {
    200 * WAD + 123
}
pub fn QUOTE_AMOUNT2() -> u256 {
    152 * WAD + 7347
}
pub fn QUOTE_AMOUNT3() -> u256 {
    94 * WAD + 461767
}
pub fn BASE_AMOUNT1() -> u256 {
    12 * WAD + 23432
}
pub fn MAKER1() -> ContractAddress {
    'maker1'.try_into().unwrap()
}
pub fn MAKER2() -> ContractAddress {
    'maker2'.try_into().unwrap()
}
pub fn MAKER3() -> ContractAddress {
    'maker3'.try_into().unwrap()
}
pub fn TAKER1() -> ContractAddress {
    'taker1'.try_into().unwrap()
}
pub fn TAKER2() -> ContractAddress {
    'taker2'.try_into().unwrap()
}
pub fn TAKER3() -> ContractAddress {
    'taker3'.try_into().unwrap()
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
    controller: IControllerDispatcher, book_key: BookKey, tick: Tick, quote_amount: u256,
) -> OrderId {
    OrderIdTrait::decode(
        controller
            .make(
                book_key.to_id(),
                tick,
                quote_amount,
                ZERO_ADDRESS(),
                ArrayTrait::new().span(),
                get_block_timestamp(),
            ),
    )
}

pub fn limit_order(
    controller: IControllerDispatcher,
    take_book_key: BookKey,
    book_key: BookKey,
    tick: Tick,
    quote_amount: u256,
) -> OrderId {
    OrderIdTrait::decode(
        controller
            .limit(
                take_book_key.to_id(),
                book_key.to_id(),
                0,
                tick,
                quote_amount,
                ZERO_ADDRESS(),
                ArrayTrait::new().span(),
                ArrayTrait::new().span(),
                get_block_timestamp(),
            ),
    )
}

pub fn take_order(controller: IControllerDispatcher, book_key: BookKey, quote_amount: u256) {
    controller
        .take(
            book_key.to_id(),
            0,
            quote_amount,
            TWO_POW_248,
            ArrayTrait::new().span(),
            get_block_timestamp(),
        );
}

pub fn spend_order(controller: IControllerDispatcher, book_key: BookKey, base_amount: u256) {
    controller
        .spend(
            book_key.to_id(), 0, base_amount, 0, ArrayTrait::new().span(), get_block_timestamp(),
        );
}

pub fn cancel_order(controller: IControllerDispatcher, order_id: felt252, to: u256) {
    controller.cancel(order_id, to, ArrayTrait::new().span(), get_block_timestamp());
}

pub fn claim_order(controller: IControllerDispatcher, order_id: felt252) {
    controller.claim(order_id, ArrayTrait::new().span(), get_block_timestamp());
}

