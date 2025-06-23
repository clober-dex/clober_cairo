use clober_cairo::interfaces::book_manager::{
    IBookManagerDispatcher, IBookManagerDispatcherTrait, MakeParams, TakeParams,
};
use clober_cairo::libraries::book_key::BookKeyTrait;
use clober_cairo::libraries::tick::{Tick, TickTrait};
use clober_cairo::mocks::open_router::OpenRouter::{
    IOpenRouterDispatcher, IOpenRouterDispatcherTrait,
};
use clober_cairo::mocks::make_router::MakeRouter::{
    IMakeRouterDispatcher, IMakeRouterDispatcherTrait,
};
use clober_cairo::mocks::take_router::TakeRouter::{
    ITakeRouterDispatcher, ITakeRouterDispatcherTrait,
};
use clober_cairo::tests::utils::{deploy_token_pairs, BASE_URI, CONTRACT_URI};
use clober_cairo::tests::book_manager::common::{BookManagerSpyHelpers, valid_key, EventSpyExt};
use openzeppelin_testing as utils;
use clober_cairo::tests::constants::{ZERO, OWNER, OTHER};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::{spy_events, cheat_caller_address, CheatSpan};

fn setup() -> (
    IBookManagerDispatcher,
    IOpenRouterDispatcher,
    IMakeRouterDispatcher,
    ITakeRouterDispatcher,
    IERC20Dispatcher,
    IERC20Dispatcher,
) {
    let mut calldata = array![];

    calldata.append_serde(OWNER());
    calldata.append_serde(OWNER());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(CONTRACT_URI());
    let book_manager = utils::declare_and_deploy("BookManager", calldata);

    let mut calldata = array![];
    calldata.append_serde(book_manager);
    let open_router = utils::declare_and_deploy("OpenRouter", calldata);
    let (base, quote) = deploy_token_pairs(
        1000000000000000000 * 1000000000000000000, 1000000000000000000 * 1000000, OWNER(), OWNER(),
    );

    let mut calldata = array![];
    calldata.append_serde(book_manager);
    let make_router = utils::declare_and_deploy("MakeRouter", calldata);

    let mut calldata = array![];
    calldata.append_serde(book_manager);
    let take_router = utils::declare_and_deploy("TakeRouter", calldata);

    cheat_caller_address(base.contract_address, OWNER(), CheatSpan::TargetCalls(2));
    base.approve(make_router, 1000000000000000000 * 1000000000000000000);
    base.approve(take_router, 1000000000000000000 * 1000000000000000000);

    cheat_caller_address(quote.contract_address, OWNER(), CheatSpan::TargetCalls(2));
    quote.approve(make_router, 1000000000000000000 * 1000000);
    quote.approve(take_router, 1000000000000000000 * 1000000);

    (
        IBookManagerDispatcher { contract_address: book_manager },
        IOpenRouterDispatcher { contract_address: open_router },
        IMakeRouterDispatcher { contract_address: make_router },
        ITakeRouterDispatcher { contract_address: take_router },
        base,
        quote,
    )
}

#[test]
fn test_success() {
    let (bm, open_router, make_router, take_router, base, quote) = setup();
    let key = valid_key(base.contract_address, quote.contract_address);
    open_router.open(key, ArrayTrait::new().span());
    let make_unit = 10000;
    let tick: Tick = -80000;
    cheat_caller_address(make_router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    let (order_id, _) = make_router
        .make(
            MakeParams { key, tick, unit: make_unit, provider: ZERO() }, ArrayTrait::new().span(),
        );

    let before_quote_balance = quote.balance_of(OWNER());
    let before_base_balance = base.balance_of(OWNER());

    let take_unit = 1000;

    cheat_caller_address(take_router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    let mut spy = spy_events();
    spy.drop_all_events();
    let (quote_amount, base_amount) = take_router
        .take(TakeParams { key, tick, max_unit: take_unit }, ArrayTrait::new().span());
    spy
        .assert_only_event_take(
            bm.contract_address, key.to_id(), take_router.contract_address, tick, take_unit,
        );

    let order_info = bm.get_order(order_id);

    assert_eq!(quote_amount, take_unit.into() * key.unit_size.into());
    assert_eq!(base_amount, tick.quote_to_base(take_unit.into() * key.unit_size.into(), true));
    assert_eq!(quote.balance_of(OWNER()), before_quote_balance + quote_amount);
    assert_eq!(base.balance_of(OWNER()), before_base_balance - base_amount);
    assert_eq!(
        bm.reserves_of(quote.contract_address),
        make_unit.into() * key.unit_size.into() - quote_amount,
    );
    assert_eq!(bm.reserves_of(base.contract_address), base_amount);
    assert_eq!(bm.get_depth(key.to_id(), tick), make_unit - take_unit);
    assert_eq!(bm.get_highest(key.to_id()), tick);
    assert!(!bm.is_empty(key.to_id()));
    assert_eq!(order_info.provider, ZERO());
    assert_eq!(order_info.open, make_unit - take_unit);
    assert_eq!(order_info.claimable, take_unit);
}

#[test]
fn test_success_with_greater_max_unit() {
    let (bm, open_router, make_router, take_router, base, quote) = setup();
    let key = valid_key(base.contract_address, quote.contract_address);
    open_router.open(key, ArrayTrait::new().span());
    let make_unit = 1000;
    let tick: Tick = -80000;
    cheat_caller_address(make_router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    let (order_id, _) = make_router
        .make(
            MakeParams { key, tick, unit: make_unit, provider: ZERO() }, ArrayTrait::new().span(),
        );

    let before_quote_balance = quote.balance_of(OWNER());
    let before_base_balance = base.balance_of(OWNER());

    let take_unit = 10000;

    cheat_caller_address(take_router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    let mut spy = spy_events();
    spy.drop_all_events();
    let (quote_amount, base_amount) = take_router
        .take(TakeParams { key, tick, max_unit: take_unit }, ArrayTrait::new().span());
    spy
        .assert_only_event_take(
            bm.contract_address, key.to_id(), take_router.contract_address, tick, make_unit,
        );

    let order_info = bm.get_order(order_id);

    assert_eq!(quote_amount, make_unit.into() * key.unit_size.into());
    assert_eq!(base_amount, tick.quote_to_base(make_unit.into() * key.unit_size.into(), true));
    assert_eq!(quote.balance_of(OWNER()), before_quote_balance + quote_amount);
    assert_eq!(base.balance_of(OWNER()), before_base_balance - base_amount);
    assert_eq!(bm.reserves_of(quote.contract_address), 0);
    assert_eq!(bm.reserves_of(base.contract_address), base_amount);
    assert_eq!(bm.get_depth(key.to_id(), tick), 0);
    assert!(bm.is_empty(key.to_id()));
    assert_eq!(order_info.provider, ZERO());
    assert_eq!(order_info.open, 0);
    assert_eq!(order_info.claimable, make_unit);
}

#[test]
#[should_panic(expected: ('Book not opened',))]
fn test_take_with_invalid_book_key() {
    let (_, _, _, take_router, base, quote) = setup();
    let key = valid_key(base.contract_address, quote.contract_address);
    let take_unit = 1000;
    let tick: Tick = -80000;

    cheat_caller_address(take_router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    take_router.take(TakeParams { key, tick, max_unit: take_unit }, ArrayTrait::new().span());
}
