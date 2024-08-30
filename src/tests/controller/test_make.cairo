use starknet::{ContractAddress, get_block_timestamp};
use clober_cairo::interfaces::book_manager::{IBookManagerDispatcher, IBookManagerDispatcherTrait};
use clober_cairo::interfaces::controller::{IControllerDispatcher, IControllerDispatcherTrait};
use clober_cairo::libraries::book_key::{BookKey, BookKeyTrait};
use clober_cairo::libraries::order_id::{OrderId, OrderIdTrait};
use clober_cairo::libraries::fee_policy::{FeePolicy, FeePolicyTrait};
use clober_cairo::libraries::i257::I257Trait;
use clober_cairo::utils::constants::WAD;
use clober_cairo::tests::controller::common::{
    valid_key, make_order, PRICE_TICK, MAKER1, QUOTE_AMOUNT1
};
use clober_cairo::tests::utils::{deploy_token_pairs, BASE_URI, CONTRACT_URI};

use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{ZERO, OWNER};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
use openzeppelin_testing::events::EventSpyExt;
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::{spy_events, EventSpy, cheat_caller_address, CheatSpan};

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
    let (base, quote) = deploy_token_pairs(WAD * 1000000, WAD * WAD, OWNER(), OWNER());

    cheat_caller_address(quote.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    quote.transfer(MAKER1(), 1000 * WAD);

    cheat_caller_address(quote.contract_address, MAKER1(), CheatSpan::TargetCalls(1));
    quote.approve(controller, 1000 * WAD);

    let controller_dispatcher = IControllerDispatcher { contract_address: controller };
    controller_dispatcher
        .open(valid_key(base, quote), ArrayTrait::new().span(), get_block_timestamp());

    (controller_dispatcher, IBookManagerDispatcher { contract_address: book_manager }, base, quote)
}

#[test]
fn test_make() {
    let (controller, book_manager, base, quote) = setup();
    let key = valid_key(base, quote);
    let before_balance = quote.balance_of(MAKER1());

    cheat_caller_address(controller.contract_address, MAKER1(), CheatSpan::TargetCalls(1));
    let id = make_order(controller, key, PRICE_TICK(), QUOTE_AMOUNT1(), base, quote, MAKER1());
    assert_eq!(
        IERC721Dispatcher { contract_address: book_manager.contract_address }
            .owner_of(id.encode().into()),
        MAKER1()
    );
    let (provider, price, open_quote_amount, claimable_quote_amount) = controller
        .get_order(id.encode());
    assert_eq!(
        open_quote_amount - key.maker_policy.calculate_fee(open_quote_amount, true).abs(),
        before_balance - quote.balance_of(MAKER1())
    );
    assert_eq!(price, controller.to_price(PRICE_TICK()));
    assert_eq!(claimable_quote_amount, 0);
    assert_eq!(provider, ZERO());
}
