use clober_cairo::interfaces::book_manager::{IBookManagerDispatcher, IBookManagerDispatcherTrait};
use clober_cairo::libraries::book_key::BookKeyTrait;
use clober_cairo::libraries::fee_policy::{FeePolicy, MAX_FEE_RATE, MIN_FEE_RATE};
use clober_cairo::mocks::open_router::OpenRouter::{
    IOpenRouterDispatcher, IOpenRouterDispatcherTrait,
};
use clober_cairo::tests::utils::{deploy_token_pairs, BASE_URI, CONTRACT_URI};
use clober_cairo::tests::book_manager::common::{BookManagerSpyHelpers, valid_key};
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::OWNER;
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::{spy_events, cheat_caller_address, CheatSpan};

fn setup() -> (IBookManagerDispatcher, IOpenRouterDispatcher) {
    let mut calldata = array![];

    calldata.append_serde(OWNER());
    calldata.append_serde(OWNER());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(CONTRACT_URI());
    let book_manager = utils::declare_and_deploy("BookManager", calldata);

    let mut calldata = array![];
    calldata.append_serde(book_manager);
    let open_router = utils::declare_and_deploy("OpenRouter", calldata);

    (
        IBookManagerDispatcher { contract_address: book_manager },
        IOpenRouterDispatcher { contract_address: open_router },
    )
}

#[test]
fn test_success() {
    let (base, quote) = deploy_token_pairs(1000000000000000000, 1000000, OWNER(), OWNER());

    let (bm, router) = setup();
    let key = valid_key(base.contract_address, quote.contract_address);
    let book_id = key.to_id();

    let mut spy = spy_events();

    cheat_caller_address(router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    router.open(key, ArrayTrait::new().span());

    spy
        .assert_only_event_open(
            bm.contract_address,
            book_id,
            key.base,
            key.quote,
            key.unit_size,
            key.maker_policy,
            key.taker_policy,
            key.hooks,
        );

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
    let (base, quote) = deploy_token_pairs(1000000000000000000, 1000000, OWNER(), OWNER());
    let (_, router) = setup();

    let mut key = valid_key(base.contract_address, quote.contract_address);
    key.unit_size = 0;
    cheat_caller_address(router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    router.open(key, ArrayTrait::new().span());
}

#[test]
#[should_panic(expected: ('Invalid fee policy',))]
fn test_open_with_invalid_fee_policy_boundary1() {
    let (base, quote) = deploy_token_pairs(1000000000000000000, 1000000, OWNER(), OWNER());
    let (_, router) = setup();

    let valid_key = valid_key(base.contract_address, quote.contract_address);
    let mut invalid_key = valid_key.clone();
    invalid_key.maker_policy.rate = MIN_FEE_RATE - 1;
    cheat_caller_address(router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    router.open(invalid_key, ArrayTrait::new().span());
}

#[test]
#[should_panic(expected: ('Invalid fee policy',))]
fn test_open_with_invalid_fee_policy_boundary2() {
    let (base, quote) = deploy_token_pairs(1000000000000000000, 1000000, OWNER(), OWNER());
    let (_, router) = setup();

    let valid_key = valid_key(base.contract_address, quote.contract_address);
    let mut invalid_key = valid_key.clone();
    invalid_key.maker_policy.rate = MAX_FEE_RATE + 1;
    cheat_caller_address(router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    router.open(invalid_key, ArrayTrait::new().span());
}


#[test]
#[should_panic(expected: ('Invalid fee policy',))]
fn test_open_with_invalid_fee_policy_boundary3() {
    let (base, quote) = deploy_token_pairs(1000000000000000000, 1000000, OWNER(), OWNER());
    let (_, router) = setup();

    let valid_key = valid_key(base.contract_address, quote.contract_address);
    let mut invalid_key = valid_key.clone();
    invalid_key.taker_policy.rate = MIN_FEE_RATE - 1;
    cheat_caller_address(router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    router.open(invalid_key, ArrayTrait::new().span());
}

#[test]
#[should_panic(expected: ('Invalid fee policy',))]
fn test_open_with_invalid_fee_policy_boundary4() {
    let (base, quote) = deploy_token_pairs(1000000000000000000, 1000000, OWNER(), OWNER());
    let (_, router) = setup();

    let valid_key = valid_key(base.contract_address, quote.contract_address);
    let mut invalid_key = valid_key.clone();
    invalid_key.taker_policy.rate = MAX_FEE_RATE + 1;
    cheat_caller_address(router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    router.open(invalid_key, ArrayTrait::new().span());
}

#[test]
#[should_panic(expected: ('Invalid fee policy',))]
fn test_open_with_invalid_fee_policy_negative_sum() {
    let (base, quote) = deploy_token_pairs(1000000000000000000, 1000000, OWNER(), OWNER());
    let (_, router) = setup();

    let valid_key = valid_key(base.contract_address, quote.contract_address);
    let mut invalid_key = valid_key.clone();
    invalid_key.taker_policy.rate = 1000;
    invalid_key.maker_policy.rate = -1001;
    cheat_caller_address(router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    router.open(invalid_key, ArrayTrait::new().span());
}

#[test]
#[should_panic(expected: ('Invalid fee policy',))]
fn test_open_with_invalid_fee_policy_unmatched1() {
    let (base, quote) = deploy_token_pairs(1000000000000000000, 1000000, OWNER(), OWNER());
    let (_, router) = setup();

    let valid_key = valid_key(base.contract_address, quote.contract_address);
    let mut invalid_key = valid_key.clone();
    invalid_key.taker_policy = FeePolicy { uses_quote: false, rate: -1 };
    invalid_key.maker_policy = FeePolicy { uses_quote: true, rate: 2 };
    cheat_caller_address(router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    router.open(invalid_key, ArrayTrait::new().span());
}

#[test]
#[should_panic(expected: ('Invalid fee policy',))]
fn test_open_with_invalid_fee_policy_unmatched2() {
    let (base, quote) = deploy_token_pairs(1000000000000000000, 1000000, OWNER(), OWNER());
    let (_, router) = setup();

    let valid_key = valid_key(base.contract_address, quote.contract_address);
    let mut invalid_key = valid_key.clone();
    invalid_key.taker_policy = FeePolicy { uses_quote: true, rate: -1 };
    invalid_key.maker_policy = FeePolicy { uses_quote: false, rate: 2 };
    cheat_caller_address(router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    router.open(invalid_key, ArrayTrait::new().span());
}

#[test]
#[should_panic(expected: ('Invalid fee policy',))]
fn test_open_with_invalid_fee_policy_unmatched3() {
    let (base, quote) = deploy_token_pairs(1000000000000000000, 1000000, OWNER(), OWNER());
    let (_, router) = setup();

    let valid_key = valid_key(base.contract_address, quote.contract_address);
    let mut invalid_key = valid_key.clone();
    invalid_key.taker_policy = FeePolicy { uses_quote: false, rate: 2 };
    invalid_key.maker_policy = FeePolicy { uses_quote: true, rate: -1 };
    cheat_caller_address(router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    router.open(invalid_key, ArrayTrait::new().span());
}

#[test]
#[should_panic(expected: ('Invalid fee policy',))]
fn test_open_with_invalid_fee_policy_unmatched4() {
    let (base, quote) = deploy_token_pairs(1000000000000000000, 1000000, OWNER(), OWNER());
    let (_, router) = setup();

    let valid_key = valid_key(base.contract_address, quote.contract_address);
    let mut invalid_key = valid_key.clone();
    invalid_key.taker_policy = FeePolicy { uses_quote: true, rate: 2 };
    invalid_key.maker_policy = FeePolicy { uses_quote: false, rate: -1 };
    cheat_caller_address(router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    router.open(invalid_key, ArrayTrait::new().span());
}

#[test]
#[should_panic(expected: ('Book already opened',))]
fn test_open_duplicated() {
    let (base, quote) = deploy_token_pairs(1000000000000000000, 1000000, OWNER(), OWNER());
    let (_, router) = setup();

    let key = valid_key(base.contract_address, quote.contract_address);
    cheat_caller_address(router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    router.open(key, ArrayTrait::new().span());
    router.open(key, ArrayTrait::new().span());
}
