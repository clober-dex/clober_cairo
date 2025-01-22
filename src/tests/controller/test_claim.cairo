use starknet::get_block_timestamp;
use clober_cairo::interfaces::book_manager::IBookManagerDispatcher;
use clober_cairo::interfaces::controller::{IControllerDispatcher, IControllerDispatcherTrait};
use clober_cairo::libraries::order_id::OrderIdTrait;
use clober_cairo::utils::constants::WAD;
use clober_cairo::tests::controller::common::{
    valid_key, make_order, take_order, claim_order, PRICE_TICK, MAKER1, MAKER2, MAKER3, TAKER1,
    TAKER2, TAKER3, QUOTE_AMOUNT1,
};
use clober_cairo::tests::utils::{deploy_token_pairs, BASE_URI, CONTRACT_URI};

use openzeppelin_testing as utils;
use openzeppelin_testing::constants::OWNER;
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
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

    let controller_dispatcher = IControllerDispatcher { contract_address: controller };
    controller_dispatcher
        .open(valid_key(base, quote), ArrayTrait::new().span(), get_block_timestamp());

    (controller_dispatcher, IBookManagerDispatcher { contract_address: book_manager }, base, quote)
}

#[test]
fn test_claim() {
    let (controller, book_manager, base, quote) = setup();
    let key = valid_key(base, quote);

    cheat_caller_address(controller.contract_address, MAKER1(), CheatSpan::TargetCalls(1));
    let order_id = make_order(controller, key, PRICE_TICK(), QUOTE_AMOUNT1()).encode();

    cheat_caller_address(controller.contract_address, TAKER1(), CheatSpan::TargetCalls(1));
    take_order(controller, key, QUOTE_AMOUNT1());

    let (_, _, _, claimable_amount) = controller.get_order(order_id);
    let before_balance = base.balance_of(MAKER1());

    cheat_caller_address(book_manager.contract_address, MAKER1(), CheatSpan::TargetCalls(1));
    IERC721Dispatcher { contract_address: book_manager.contract_address }
        .approve(controller.contract_address, order_id.into());

    cheat_caller_address(controller.contract_address, MAKER1(), CheatSpan::TargetCalls(1));
    claim_order(controller, order_id);

    assert_eq!(base.balance_of(MAKER1()) - before_balance, claimable_amount);
    let (_, _, _, claimable_amount) = controller.get_order(order_id);
    assert_eq!(claimable_amount, 0);
}


#[test]
#[should_panic(expected: ('Unauthorized',))]
fn test_claim_not_owner() {
    let (controller, book_manager, base, quote) = setup();
    let key = valid_key(base, quote);

    cheat_caller_address(controller.contract_address, MAKER1(), CheatSpan::TargetCalls(1));
    let order_id = make_order(controller, key, PRICE_TICK(), QUOTE_AMOUNT1()).encode();

    cheat_caller_address(controller.contract_address, TAKER1(), CheatSpan::TargetCalls(1));
    take_order(controller, key, QUOTE_AMOUNT1());

    cheat_caller_address(book_manager.contract_address, MAKER1(), CheatSpan::TargetCalls(1));
    IERC721Dispatcher { contract_address: book_manager.contract_address }
        .approve(controller.contract_address, order_id.into());

    claim_order(controller, order_id);
}
