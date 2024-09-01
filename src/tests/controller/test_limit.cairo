use starknet::{ContractAddress, get_block_timestamp};
use clober_cairo::interfaces::book_manager::{IBookManagerDispatcher, IBookManagerDispatcherTrait};
use clober_cairo::interfaces::controller::{IControllerDispatcher, IControllerDispatcherTrait};
use clober_cairo::libraries::book_key::{BookKey, BookKeyTrait};
use clober_cairo::libraries::order_id::{OrderId, OrderIdTrait};
use clober_cairo::libraries::fee_policy::{FeePolicy, FeePolicyTrait};
use clober_cairo::libraries::tick::{Tick, TickTrait};
use clober_cairo::libraries::i257::I257Trait;
use clober_cairo::utils::constants::WAD;
use clober_cairo::tests::controller::common::{
    valid_key, make_order, limit_order, PRICE_TICK, MAKER1, MAKER2, MAKER3, TAKER1, TAKER2, TAKER3,
    QUOTE_AMOUNT1, QUOTE_AMOUNT2, QUOTE_AMOUNT3
};
use clober_cairo::tests::utils::{deploy_token_pairs, BASE_URI, CONTRACT_URI};

use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{ZERO, OWNER};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
use openzeppelin_testing::events::EventSpyExt;
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::{cheat_caller_address, CheatSpan};

fn setup() -> (IControllerDispatcher, IBookManagerDispatcher, IERC20Dispatcher, IERC20Dispatcher) {
    let mut calldata = array![];

    calldata.append_serde(OWNER());
    calldata.append_serde(OWNER());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(CONTRACT_URI());
    let book_manager = utils::declare_and_deploy("BookManager", calldata);

    let mut calldata = array![];
    calldata.append_serde(book_manager);
    let controller = utils::declare_and_deploy("Controller", calldata);
    let (base, quote) = deploy_token_pairs(WAD * WAD, WAD * WAD, OWNER(), OWNER());

    cheat_caller_address(quote.contract_address, OWNER(), CheatSpan::TargetCalls(3));
    quote.transfer(TAKER1(), 1000 * WAD);

    cheat_caller_address(quote.contract_address, TAKER1(), CheatSpan::TargetCalls(1));
    quote.approve(controller, 1000 * WAD);

    cheat_caller_address(base.contract_address, OWNER(), CheatSpan::TargetCalls(3));
    base.transfer(MAKER1(), 1000 * WAD);

    cheat_caller_address(base.contract_address, MAKER1(), CheatSpan::TargetCalls(1));
    base.approve(controller, 1000 * WAD);

    let key = valid_key(base, quote);
    let controller_dispatcher = IControllerDispatcher { contract_address: controller };
    controller_dispatcher.open(key, ArrayTrait::new().span(), get_block_timestamp());

    let take_book_key = BookKey {
        base: quote.contract_address,
        quote: base.contract_address,
        hooks: ZERO(),
        unit_size: 1000000000000000000,
        taker_policy: FeePolicy { uses_quote: true, rate: 100 },
        maker_policy: FeePolicy { uses_quote: true, rate: -100 },
    };
    controller_dispatcher.open(take_book_key, ArrayTrait::new().span(), get_block_timestamp());

    cheat_caller_address(controller, MAKER1(), CheatSpan::TargetCalls(1));
    make_order(controller_dispatcher, take_book_key, PRICE_TICK(), QUOTE_AMOUNT3());

    (controller_dispatcher, IBookManagerDispatcher { contract_address: book_manager }, base, quote)
}

#[test]
fn test_limit() {
    let (controller, _, base, quote) = setup();
    let key = valid_key(base, quote);
    let take_book_key = BookKey {
        base: quote.contract_address,
        quote: base.contract_address,
        hooks: ZERO(),
        unit_size: 1000000000000000000,
        taker_policy: FeePolicy { uses_quote: true, rate: 100 },
        maker_policy: FeePolicy { uses_quote: true, rate: -100 },
    };

    let quote_amount = 199987070394079345754;
    let take_amount = 93990600000000000000;

    let before_quote_balance = quote.balance_of(TAKER1());
    let before_base_balance = base.balance_of(TAKER1());
    cheat_caller_address(controller.contract_address, TAKER1(), CheatSpan::TargetCalls(1));
    limit_order(controller, take_book_key, key, PRICE_TICK(), QUOTE_AMOUNT1());
    assert_eq!(quote_amount, before_quote_balance - quote.balance_of(TAKER1()));
    assert_eq!(before_base_balance + take_amount, base.balance_of(TAKER1()));
}
