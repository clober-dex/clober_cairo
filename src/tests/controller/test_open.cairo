use starknet::get_block_timestamp;
use clober_cairo::interfaces::book_manager::{IBookManagerDispatcher, IBookManagerDispatcherTrait};
use clober_cairo::interfaces::controller::{IControllerDispatcher, IControllerDispatcherTrait};
use clober_cairo::libraries::book_key::BookKeyTrait;
use clober_cairo::utils::constants::WAD;
use clober_cairo::tests::utils::{deploy_token_pairs, BASE_URI, CONTRACT_URI};
use clober_cairo::tests::controller::common::valid_key;

use openzeppelin_testing as utils;
use clober_cairo::tests::constants::{OWNER, ZERO, OTHER};
use openzeppelin_token::erc20::interface::IERC20Dispatcher;
use openzeppelin_utils::serde::SerializedAppend;

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

    (
        IControllerDispatcher { contract_address: controller },
        IBookManagerDispatcher { contract_address: book_manager },
        base,
        quote,
    )
}

#[test]
fn test_open() {
    let (controller, book_manager, base, quote) = setup();

    let book_key = valid_key(base, quote);
    let book_id = book_key.to_id();

    assert_eq!(book_manager.is_opened(book_id), false);
    controller.open(book_key, ArrayTrait::new().span(), get_block_timestamp());
    assert_eq!(book_manager.is_opened(book_id), true);
}
