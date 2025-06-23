use starknet::get_block_timestamp;
use clober_cairo::interfaces::book_manager::IBookManagerDispatcher;
use clober_cairo::interfaces::controller::{IControllerDispatcher, IControllerDispatcherTrait};
use clober_cairo::libraries::fee_policy::FeePolicyTrait;
use clober_cairo::libraries::tick::{Tick, TickTrait};
use clober_cairo::utils::constants::WAD;
use clober_cairo::tests::controller::common::{
    valid_key, make_order, take_order, PRICE_TICK, MAKER1, MAKER2, MAKER3, TAKER1, TAKER2, TAKER3,
    QUOTE_AMOUNT1, QUOTE_AMOUNT2, QUOTE_AMOUNT3,
};
use clober_cairo::tests::utils::{deploy_token_pairs, BASE_URI, CONTRACT_URI};

use openzeppelin_testing as utils;
use clober_cairo::tests::constants::{OWNER};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
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
    quote.transfer(MAKER1(), 1000 * WAD);
    quote.transfer(MAKER2(), 1000 * WAD);
    quote.transfer(MAKER3(), 1000 * WAD);

    cheat_caller_address(quote.contract_address, MAKER1(), CheatSpan::TargetCalls(1));
    quote.approve(controller, 1000 * WAD);

    cheat_caller_address(quote.contract_address, MAKER2(), CheatSpan::TargetCalls(1));
    quote.approve(controller, 1000 * WAD);

    cheat_caller_address(quote.contract_address, MAKER3(), CheatSpan::TargetCalls(1));
    quote.approve(controller, 1000 * WAD);

    cheat_caller_address(base.contract_address, OWNER(), CheatSpan::TargetCalls(3));
    base.transfer(TAKER1(), 1000 * WAD);
    base.transfer(TAKER2(), 1000 * WAD);
    base.transfer(TAKER3(), 1000 * WAD);

    cheat_caller_address(base.contract_address, TAKER1(), CheatSpan::TargetCalls(1));
    base.approve(controller, 1000 * WAD);

    cheat_caller_address(base.contract_address, TAKER2(), CheatSpan::TargetCalls(1));
    base.approve(controller, 1000 * WAD);

    cheat_caller_address(base.contract_address, TAKER3(), CheatSpan::TargetCalls(1));
    base.approve(controller, 1000 * WAD);

    let key = valid_key(base, quote);
    let controller_dispatcher = IControllerDispatcher { contract_address: controller };
    controller_dispatcher.open(key, ArrayTrait::new().span(), get_block_timestamp());

    cheat_caller_address(controller, MAKER1(), CheatSpan::TargetCalls(1));
    make_order(controller_dispatcher, key, PRICE_TICK(), QUOTE_AMOUNT1());

    cheat_caller_address(controller, MAKER2(), CheatSpan::TargetCalls(1));
    make_order(controller_dispatcher, key, PRICE_TICK() + 1, QUOTE_AMOUNT2());

    cheat_caller_address(controller, MAKER3(), CheatSpan::TargetCalls(1));
    make_order(controller_dispatcher, key, PRICE_TICK() + 1, QUOTE_AMOUNT3());

    cheat_caller_address(controller, MAKER1(), CheatSpan::TargetCalls(1));
    make_order(controller_dispatcher, key, PRICE_TICK() + 2, QUOTE_AMOUNT1());

    (controller_dispatcher, IBookManagerDispatcher { contract_address: book_manager }, base, quote)
}

#[test]
fn test_take() {
    let (controller, _, base, quote) = setup();
    let key = valid_key(base, quote);
    let take_amount = 152000000479800000000;
    let tick: Tick = PRICE_TICK() + 2;
    let base_amount = tick
        .quote_to_base(key.taker_policy.calculate_original_amount(take_amount, true), true);

    let before_quote_balance = quote.balance_of(TAKER1());
    let before_base_balance = base.balance_of(TAKER1());

    cheat_caller_address(controller.contract_address, TAKER1(), CheatSpan::TargetCalls(1));
    take_order(controller, key, QUOTE_AMOUNT2());

    assert_eq!(quote.balance_of(TAKER1()) - before_quote_balance, take_amount);
    assert_eq!(before_base_balance - base.balance_of(TAKER1()), base_amount);
}
