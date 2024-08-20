use starknet::ContractAddress;
use clober_cairo::interfaces::book_manager::{IBookManagerDispatcher, IBookManagerDispatcherTrait};
use clober_cairo::book_manager::BookManager;
use clober_cairo::libraries::book_key::{BookKey, BookKeyTrait};
use clober_cairo::libraries::fee_policy::{FeePolicy, FeePolicyTrait, MAX_FEE_RATE
    ,MIN_FEE_RATE};
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

fn valid_key(base: ContractAddress, quote: ContractAddress) -> BookKey {
    BookKey {
        base,
        quote,
        hooks: ZERO(),
        unit_size: 1,
        taker_policy: FeePolicy { uses_quote: true, rate: 0 },
        maker_policy: FeePolicy { uses_quote: true, rate: 0 },
    }
}

#[test]
fn test_open() {
    let (quote, base) = deploy_token_pairs(1000000, 1000000000000000000, OWNER(), OWNER());

    let (bm, router) = setup_dispatcher();
    let key = valid_key(base.contract_address, quote.contract_address);
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

#[test]
#[should_panic(expected: ('Invalid unit size',))]
fn test_open_with_invalid_unit_size() {
    let (quote, base) = deploy_token_pairs(1000000, 1000000000000000000, OWNER(), OWNER());
    let (_, router) = setup_dispatcher();

    let mut key = valid_key(base.contract_address, quote.contract_address);
    key.unit_size = 0;
    start_cheat_caller_address(router.contract_address, OWNER());
    router.open(key, ArrayTrait::new().span());
}

#[test]
#[should_panic(expected: ('Invalid fee policy',))]
fn test_open_with_invalid_fee_policy_boundary1() {
    let (quote, base) = deploy_token_pairs(1000000, 1000000000000000000, OWNER(), OWNER());
    let (_, router) = setup_dispatcher();

    let valid_key = valid_key(base.contract_address, quote.contract_address);
    let mut invalid_key = valid_key.clone();
    invalid_key.maker_policy.rate = MIN_FEE_RATE - 1;
    start_cheat_caller_address(router.contract_address, OWNER());
    router.open(invalid_key, ArrayTrait::new().span());
}

#[test]
#[should_panic(expected: ('Invalid fee policy',))]
fn test_open_with_invalid_fee_policy_boundary2() {
    let (quote, base) = deploy_token_pairs(1000000, 1000000000000000000, OWNER(), OWNER());
    let (_, router) = setup_dispatcher();

    let valid_key = valid_key(base.contract_address, quote.contract_address);
    let mut invalid_key = valid_key.clone();
    invalid_key.maker_policy.rate = MAX_FEE_RATE + 1;
    start_cheat_caller_address(router.contract_address, OWNER());
    router.open(invalid_key, ArrayTrait::new().span());
}


#[test]
#[should_panic(expected: ('Invalid fee policy',))]
fn test_open_with_invalid_fee_policy_boundary3() {
    let (quote, base) = deploy_token_pairs(1000000, 1000000000000000000, OWNER(), OWNER());
    let (_, router) = setup_dispatcher();

    let valid_key = valid_key(base.contract_address, quote.contract_address);
    let mut invalid_key = valid_key.clone();
    invalid_key.taker_policy.rate = MIN_FEE_RATE - 1;
    start_cheat_caller_address(router.contract_address, OWNER());
    router.open(invalid_key, ArrayTrait::new().span());
}

#[test]
#[should_panic(expected: ('Invalid fee policy',))]
fn test_open_with_invalid_fee_policy_boundary4() {
    let (quote, base) = deploy_token_pairs(1000000, 1000000000000000000, OWNER(), OWNER());
    let (_, router) = setup_dispatcher();

    let valid_key = valid_key(base.contract_address, quote.contract_address);
    let mut invalid_key = valid_key.clone();
    invalid_key.taker_policy.rate = MAX_FEE_RATE + 1;
    start_cheat_caller_address(router.contract_address, OWNER());
    router.open(invalid_key, ArrayTrait::new().span());
}

#[test]
#[should_panic(expected: ('Invalid fee policy',))]
fn test_open_with_invalid_fee_policy_negative_sum() {
    let (quote, base) = deploy_token_pairs(1000000, 1000000000000000000, OWNER(), OWNER());
    let (_, router) = setup_dispatcher();

    let valid_key = valid_key(base.contract_address, quote.contract_address);
    let mut invalid_key = valid_key.clone();
    invalid_key.taker_policy.rate = 1000;
    invalid_key.maker_policy.rate = -1001;
    start_cheat_caller_address(router.contract_address, OWNER());
    router.open(invalid_key, ArrayTrait::new().span());
}

#[test]
#[should_panic(expected: ('Invalid fee policy',))]
fn test_open_with_invalid_fee_policy_unmatched1() {
    let (quote, base) = deploy_token_pairs(1000000, 1000000000000000000, OWNER(), OWNER());
    let (_, router) = setup_dispatcher();

    let valid_key = valid_key(base.contract_address, quote.contract_address);
    let mut invalid_key = valid_key.clone();
    invalid_key.taker_policy = FeePolicy { uses_quote: false, rate: -1 };
    invalid_key.maker_policy = FeePolicy { uses_quote: true, rate: 2 };
    start_cheat_caller_address(router.contract_address, OWNER());
    router.open(invalid_key, ArrayTrait::new().span());
}

#[test]
#[should_panic(expected: ('Invalid fee policy',))]
fn test_open_with_invalid_fee_policy_unmatched2() {
    let (quote, base) = deploy_token_pairs(1000000, 1000000000000000000, OWNER(), OWNER());
    let (_, router) = setup_dispatcher();

    let valid_key = valid_key(base.contract_address, quote.contract_address);
    let mut invalid_key = valid_key.clone();
    invalid_key.taker_policy = FeePolicy { uses_quote: true, rate: -1 };
    invalid_key.maker_policy = FeePolicy { uses_quote: false, rate: 2 };
    start_cheat_caller_address(router.contract_address, OWNER());
    router.open(invalid_key, ArrayTrait::new().span());
}

#[test]
#[should_panic(expected: ('Invalid fee policy',))]
fn test_open_with_invalid_fee_policy_unmatched3() {
    let (quote, base) = deploy_token_pairs(1000000, 1000000000000000000, OWNER(), OWNER());
    let (_, router) = setup_dispatcher();

    let valid_key = valid_key(base.contract_address, quote.contract_address);
    let mut invalid_key = valid_key.clone();
    invalid_key.taker_policy = FeePolicy { uses_quote: false, rate: 2 };
    invalid_key.maker_policy = FeePolicy { uses_quote: true, rate: -1 };
    start_cheat_caller_address(router.contract_address, OWNER());
    router.open(invalid_key, ArrayTrait::new().span());
}

#[test]
#[should_panic(expected: ('Invalid fee policy',))]
fn test_open_with_invalid_fee_policy_unmatched4() {
    let (quote, base) = deploy_token_pairs(1000000, 1000000000000000000, OWNER(), OWNER());
    let (_, router) = setup_dispatcher();

    let valid_key = valid_key(base.contract_address, quote.contract_address);
    let mut invalid_key = valid_key.clone();
    invalid_key.taker_policy = FeePolicy { uses_quote: true, rate: 2 };
    invalid_key.maker_policy = FeePolicy { uses_quote: false, rate: -1 };
    start_cheat_caller_address(router.contract_address, OWNER());
    router.open(invalid_key, ArrayTrait::new().span());
}

#[test]
#[should_panic(expected: ('Book already opened',))]
fn test_open_duplicated() {
    let (quote, base) = deploy_token_pairs(1000000, 1000000000000000000, OWNER(), OWNER());
    let (_, router) = setup_dispatcher();

    let key = valid_key(base.contract_address, quote.contract_address);
    start_cheat_caller_address(router.contract_address, OWNER());
    router.open(key, ArrayTrait::new().span());
    router.open(key, ArrayTrait::new().span());
}
