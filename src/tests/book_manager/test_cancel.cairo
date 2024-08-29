use starknet::ContractAddress;
use clober_cairo::interfaces::book_manager::{
    IBookManagerDispatcher, IBookManagerDispatcherTrait, MakeParams, TakeParams, CancelParams
};
use clober_cairo::libraries::book_key::BookKeyTrait;
use clober_cairo::libraries::tick::{Tick, TickTrait};
use clober_cairo::mocks::open_router::OpenRouter::{
    IOpenRouterDispatcher, IOpenRouterDispatcherTrait
};
use clober_cairo::mocks::make_router::MakeRouter::{
    IMakeRouterDispatcher, IMakeRouterDispatcherTrait
};
use clober_cairo::mocks::take_router::TakeRouter::{
    ITakeRouterDispatcher, ITakeRouterDispatcherTrait
};
use clober_cairo::mocks::cancel_router::CancelRouter::{
    ICancelRouterDispatcher, ICancelRouterDispatcherTrait
};
use clober_cairo::tests::utils::deploy_token_pairs;
use clober_cairo::tests::book_manager::common::{
    BookManagerSpyHelpers, valid_key, BASE_URI, CONTRACT_URI
};
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{ZERO, OWNER};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
use openzeppelin_testing::events::EventSpyExt;
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::{spy_events, EventSpy, cheat_caller_address, CheatSpan};

fn setup() -> (
    IBookManagerDispatcher,
    IOpenRouterDispatcher,
    IMakeRouterDispatcher,
    ITakeRouterDispatcher,
    ICancelRouterDispatcher,
    IERC20Dispatcher,
    IERC20Dispatcher
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
        1000000000000000000 * 1000000000000000000, 1000000000000000000 * 1000000, OWNER(), OWNER()
    );

    let mut calldata = array![];
    calldata.append_serde(book_manager);
    let make_router = utils::declare_and_deploy("MakeRouter", calldata);

    let mut calldata = array![];
    calldata.append_serde(book_manager);
    let take_router = utils::declare_and_deploy("TakeRouter", calldata);

    let mut calldata = array![];
    calldata.append_serde(book_manager);
    let cancel_router = utils::declare_and_deploy("CancelRouter", calldata);

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
        ICancelRouterDispatcher { contract_address: cancel_router },
        base,
        quote
    )
}

#[test]
fn test_success() {
    let (bm, open_router, make_router, _, cancel_router, base, quote) = setup();
    let key = valid_key(base.contract_address, quote.contract_address);
    open_router.open(key, ArrayTrait::new().span());
    let make_unit = 10000;
    let tick: Tick = -80000;
    cheat_caller_address(make_router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    let (order_id, _) = make_router
        .make(
            MakeParams { key, tick, unit: make_unit, provider: ZERO() }, ArrayTrait::new().span()
        );

    let erc721 = IERC721Dispatcher { contract_address: bm.contract_address };
    cheat_caller_address(erc721.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    erc721.approve(cancel_router.contract_address, order_id.into());

    let cancel_amount = 1000;
    let before_quote_balance = quote.balance_of(OWNER());
    let before_base_balance = base.balance_of(OWNER());

    cheat_caller_address(cancel_router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    let mut spy = spy_events();
    spy.drop_all_events();
    let canceled_amount = cancel_router
        .cancel(
            CancelParams { id: order_id, to_unit: make_unit - cancel_amount },
            ArrayTrait::new().span()
        );
    spy.assert_only_event_cancel(bm.contract_address, order_id, cancel_amount);

    let order_info = bm.get_order(order_id);

    assert_eq!(canceled_amount, cancel_amount.into() * key.unit_size.into());
    assert_eq!(
        quote.balance_of(OWNER()),
        before_quote_balance + cancel_amount.into() * key.unit_size.into()
    );
    assert_eq!(base.balance_of(OWNER()), before_base_balance);
    assert_eq!(
        bm.reserves_of(quote.contract_address),
        (make_unit - cancel_amount).into() * key.unit_size.into()
    );
    assert_eq!(bm.reserves_of(base.contract_address), 0);
    assert_eq!(bm.get_depth(key.to_id(), tick), make_unit - cancel_amount);
    assert_eq!(bm.get_highest(key.to_id()), tick);
    assert!(!bm.is_empty(key.to_id()));
    assert_eq!(order_info.provider, ZERO());
    assert_eq!(order_info.open, make_unit - cancel_amount);
    assert_eq!(order_info.claimable, 0);
    assert_eq!(erc721.balance_of(OWNER()), 1);
    assert_eq!(erc721.owner_of(order_id.into()), OWNER());
}

#[test]
fn test_cancel_to_zero_with_parially_taken_order() {
    let (bm, open_router, make_router, take_router, cancel_router, base, quote) = setup();
    let key = valid_key(base.contract_address, quote.contract_address);
    open_router.open(key, ArrayTrait::new().span());
    let make_unit = 10000;
    let tick: Tick = -80000;
    cheat_caller_address(make_router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    let (order_id, _) = make_router
        .make(
            MakeParams { key, tick, unit: make_unit, provider: ZERO() }, ArrayTrait::new().span()
        );

    let take_unit = 1000;
    cheat_caller_address(take_router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    take_router.take(TakeParams { key, tick, max_unit: take_unit }, ArrayTrait::new().span());

    let before_quote_balance = quote.balance_of(OWNER());
    let before_base_balance = base.balance_of(OWNER());
    let before_quote_reserve = bm.reserves_of(quote.contract_address);
    let before_base_reserve = bm.reserves_of(base.contract_address);

    let erc721 = IERC721Dispatcher { contract_address: bm.contract_address };
    cheat_caller_address(erc721.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    erc721.approve(cancel_router.contract_address, order_id.into());

    cheat_caller_address(cancel_router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    let mut spy = spy_events();
    spy.drop_all_events();
    let canceled_amount = cancel_router
        .cancel(CancelParams { id: order_id, to_unit: 0 }, ArrayTrait::new().span());
    spy.assert_only_event_cancel(bm.contract_address, order_id, make_unit - take_unit);

    let order_info = bm.get_order(order_id);

    assert_eq!(canceled_amount, (make_unit - take_unit).into() * key.unit_size.into());
    assert_eq!(
        quote.balance_of(OWNER()),
        before_quote_balance + (make_unit - take_unit).into() * key.unit_size.into()
    );
    assert_eq!(base.balance_of(OWNER()), before_base_balance);
    assert_eq!(
        bm.reserves_of(quote.contract_address),
        before_quote_reserve - (make_unit - take_unit).into() * key.unit_size.into()
    );
    assert_eq!(bm.reserves_of(base.contract_address), before_base_reserve);
    assert_eq!(bm.get_depth(key.to_id(), tick), 0);
    assert!(bm.is_empty(key.to_id()));
    assert_eq!(order_info.provider, ZERO());
    assert_eq!(order_info.open, 0);
    assert_eq!(order_info.claimable, take_unit);
    assert_eq!(erc721.balance_of(OWNER()), 1);
    assert_eq!(erc721.owner_of(order_id.into()), OWNER());
}

#[test]
fn test_cancel_to_zero_should_burn_with_zero_claimable() {
    let (bm, open_router, make_router, _, cancel_router, base, quote) = setup();
    let key = valid_key(base.contract_address, quote.contract_address);
    open_router.open(key, ArrayTrait::new().span());
    let make_unit = 10000;
    let tick: Tick = -80000;
    cheat_caller_address(make_router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    let (order_id, _) = make_router
        .make(
            MakeParams { key, tick, unit: make_unit, provider: ZERO() }, ArrayTrait::new().span()
        );

    let before_quote_balance = quote.balance_of(OWNER());
    let before_base_balance = base.balance_of(OWNER());
    let before_quote_reserve = bm.reserves_of(quote.contract_address);
    let before_base_reserve = bm.reserves_of(base.contract_address);

    let erc721 = IERC721Dispatcher { contract_address: bm.contract_address };
    cheat_caller_address(erc721.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    erc721.approve(cancel_router.contract_address, order_id.into());

    cheat_caller_address(cancel_router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    let mut spy = spy_events();
    spy.drop_all_events();
    let canceled_amount = cancel_router
        .cancel(CancelParams { id: order_id, to_unit: 0 }, ArrayTrait::new().span());
    spy.assert_event_cancel(bm.contract_address, order_id, make_unit);

    let order_info = bm.get_order(order_id);

    assert_eq!(canceled_amount, make_unit.into() * key.unit_size.into());
    assert_eq!(
        quote.balance_of(OWNER()), before_quote_balance + make_unit.into() * key.unit_size.into()
    );
    assert_eq!(base.balance_of(OWNER()), before_base_balance);
    assert_eq!(
        bm.reserves_of(quote.contract_address),
        before_quote_reserve - make_unit.into() * key.unit_size.into()
    );
    assert_eq!(bm.reserves_of(base.contract_address), before_base_reserve);
    assert_eq!(bm.get_depth(key.to_id(), tick), 0);
    assert!(bm.is_empty(key.to_id()));
    assert_eq!(order_info.provider, ZERO());
    assert_eq!(order_info.open, 0);
    assert_eq!(order_info.claimable, 0);
    assert_eq!(erc721.balance_of(OWNER()), 0);
}

#[test]
#[should_panic(expected: ('ERC721: invalid token ID',))]
fn test_cancel_nonexistent_order() {
    let (_, open_router, _, _, cancel_router, base, quote) = setup();
    let key = valid_key(base.contract_address, quote.contract_address);
    open_router.open(key, ArrayTrait::new().span());

    cheat_caller_address(cancel_router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    cancel_router.cancel(CancelParams { id: 123, to_unit: 0 }, ArrayTrait::new().span());
}

#[test]
#[should_panic(expected: ('ERC721: unauthorized caller',))]
fn test_cancel_auth() {
    let (_, open_router, make_router, _, cancel_router, base, quote) = setup();
    let key = valid_key(base.contract_address, quote.contract_address);
    open_router.open(key, ArrayTrait::new().span());
    let make_unit = 10000;
    let tick: Tick = -80000;
    cheat_caller_address(make_router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    let (order_id, _) = make_router
        .make(
            MakeParams { key, tick, unit: make_unit, provider: ZERO() }, ArrayTrait::new().span()
        );

    cancel_router.cancel(CancelParams { id: order_id, to_unit: 0 }, ArrayTrait::new().span());
}
