use starknet::ContractAddress;
use clober_cairo::interfaces::book_manager::{IBookManagerDispatcher, IBookManagerDispatcherTrait};
use clober_cairo::book_manager::BookManager;
use clober_cairo::libraries::book_key::{BookKey, BookKeyTrait};
use clober_cairo::libraries::fee_policy::{FeePolicy, FeePolicyTrait};
use clober_cairo::mocks::open_router::OpenRouter::{
    IOpenRouterDispatcher, IOpenRouterDispatcherTrait
};
use clober_cairo::tests::utils::deploy_token_pairs;
use clober_cairo::tests::book_manager::common::BookManagerSpyHelpers;
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{ZERO, OWNER, SPENDER, RECIPIENT, OTHER, NAME, SYMBOL};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin_testing::events::EventSpyExt;
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::{spy_events, EventSpy, start_cheat_caller_address};
use starknet::contract_address_const;

fn BASE_URI() -> ByteArray {
    "base_uri"
}
fn CONTRACT_URI() -> ByteArray {
    "contract_uri"
}

fn setup_dispatcher() -> (IBookManagerDispatcher, IOpenRouterDispatcher) {
    let mut calldata = array![];

    calldata.append_serde(OWNER());
    calldata.append_serde(OWNER());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(CONTRACT_URI());
    calldata.append_serde(NAME());
    calldata.append_serde(SYMBOL());
    let book_manager = utils::declare_and_deploy("BookManager", calldata);

    let mut calldata = array![];
    calldata.append_serde(book_manager);
    let open_router = utils::declare_and_deploy("OpenRouter", calldata);

    (
        IBookManagerDispatcher { contract_address: book_manager },
        IOpenRouterDispatcher { contract_address: open_router }
    )
}

#[test]
fn test_open() {
    let (quote, base) = deploy_token_pairs(1000000, 1000000000000000000, OWNER(), OWNER());

    let (bm, router) = setup_dispatcher();
    let key = BookKey {
        base: base.contract_address,
        quote: quote.contract_address,
        hooks: ZERO(),
        unit_size: 1,
        taker_policy: FeePolicy { uses_quote: true, rate: 0 },
        maker_policy: FeePolicy { uses_quote: true, rate: 0 },
    };
    let book_id = key.to_id();

    // let mut spy = spy_events();

    start_cheat_caller_address(router.contract_address, OWNER());
    router.open(key, ArrayTrait::new().span());

    // spy
    //     .assert_only_event_open(
    //         bm.contract_address,
    //         book_id,
    //         key.base,
    //         key.quote,
    //         key.unit_size,
    //         key.maker_policy,
    //         key.taker_policy,
    //         key.hooks
    //     );

    let remote_book_key = bm.get_book_key(book_id);

    assert_eq!(key.base, remote_book_key.base);
    assert_eq!(key.quote, remote_book_key.quote);
    assert_eq!(key.unit_size, remote_book_key.unit_size);
    assert_eq!(key.maker_policy, remote_book_key.maker_policy);
    assert_eq!(key.taker_policy, remote_book_key.taker_policy);
    assert_eq!(key.hooks, remote_book_key.hooks);
    assert!(bm.is_opened(book_id));
}
