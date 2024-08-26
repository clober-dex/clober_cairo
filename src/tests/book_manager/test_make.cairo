use starknet::ContractAddress;
use clober_cairo::interfaces::book_manager::{
    IBookManagerDispatcher, IBookManagerDispatcherTrait, MakeParams
};
use clober_cairo::libraries::book_key::BookKeyTrait;
use clober_cairo::libraries::tick::Tick;
use clober_cairo::libraries::order_id::{OrderId, OrderIdTrait};
use clober_cairo::utils::constants::{MAX_TICK, MIN_TICK};
use clober_cairo::mocks::open_router::OpenRouter::{
    IOpenRouterDispatcher, IOpenRouterDispatcherTrait
};
use clober_cairo::mocks::make_router::MakeRouter::{
    IMakeRouterDispatcher, IMakeRouterDispatcherTrait
};
use clober_cairo::tests::utils::deploy_token_pairs;
use clober_cairo::tests::book_manager::common::{
    BookManagerSpyHelpers, valid_key, BASE_URI, CONTRACT_URI
};
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{ZERO, OWNER, OTHER, NAME, SYMBOL};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
use openzeppelin_testing::events::EventSpyExt;
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::{spy_events, EventSpy, cheat_caller_address, CheatSpan};

fn setup() -> (
    IBookManagerDispatcher,
    IOpenRouterDispatcher,
    IMakeRouterDispatcher,
    IERC20Dispatcher,
    IERC20Dispatcher
) {
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
    let (base, quote) = deploy_token_pairs(
        1000000000000000000 * 1000000000000000000, 1000000000000000000 * 1000000, OWNER(), OWNER()
    );

    let mut calldata = array![];
    calldata.append_serde(book_manager);
    let make_router = utils::declare_and_deploy("MakeRouter", calldata);

    cheat_caller_address(base.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    base.approve(make_router, 1000000000000000000 * 1000000000000000000);

    cheat_caller_address(quote.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    quote.approve(make_router, 1000000000000000000 * 1000000);

    (
        IBookManagerDispatcher { contract_address: book_manager },
        IOpenRouterDispatcher { contract_address: open_router },
        IMakeRouterDispatcher { contract_address: make_router },
        base,
        quote
    )
}

#[test]
fn test_success() {
    let (bm, open_router, make_router, base, quote) = setup();
    let key = valid_key(base.contract_address, quote.contract_address);
    open_router.open(key, ArrayTrait::new().span());

    let make_unit = 10000;
    let tick: Tick = -80000;
    let before_quote_balance = quote.balance_of(OWNER());

    cheat_caller_address(make_router.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    let mut spy = spy_events();

    let (id, quote_amount) = make_router
        .make(
            MakeParams { key, tick, unit: make_unit, provider: ZERO() }, ArrayTrait::new().span()
        );
    let order_info = bm.get_order(id);
    let erc721 = IERC721Dispatcher { contract_address: bm.contract_address };

    spy
        .assert_event_make(
            bm.contract_address,
            key.to_id(),
            make_router.contract_address,
            tick,
            0,
            make_unit,
            ZERO()
        );

    assert_eq!(OrderId { book_id: key.to_id(), tick, index: 0 }.encode(), id);
    assert_eq!(quote_amount, make_unit.into() * key.unit_size.into());
    assert_eq!(quote.balance_of(OWNER()), before_quote_balance - quote_amount);
    assert_eq!(erc721.balance_of(OWNER()), 1);
    assert_eq!(erc721.owner_of(id.into()), OWNER());
    assert_eq!(bm.reserves_of(quote.contract_address), quote_amount);
    assert_eq!(bm.get_depth(key.to_id(), tick), make_unit);
    assert_eq!(bm.get_highest(key.to_id()), tick);
    assert!(!bm.is_empty(key.to_id()));
    assert_eq!(order_info.provider, ZERO());
    assert_eq!(order_info.open, make_unit);
    assert_eq!(order_info.claimable, 0);
}

#[test]
#[should_panic(expected: ('Invalid provider',))]
fn test_make_with_invalid_provider() {
    let (_, open_router, make_router, base, quote) = setup();
    let key = valid_key(base.contract_address, quote.contract_address);
    open_router.open(key, ArrayTrait::new().span());

    make_router
        .make(
            MakeParams { key, tick: 100000, unit: 10000, provider: OTHER() },
            ArrayTrait::new().span()
        );
}

#[test]
#[should_panic(expected: ('invalid_tick',))]
fn test_make_with_invalid_tick1() {
    let (_, open_router, make_router, base, quote) = setup();
    let key = valid_key(base.contract_address, quote.contract_address);
    open_router.open(key, ArrayTrait::new().span());

    make_router
        .make(
            MakeParams { key, tick: MAX_TICK + 1, unit: 10000, provider: ZERO() },
            ArrayTrait::new().span()
        );
}

#[test]
#[should_panic(expected: ('invalid_tick',))]
fn test_make_with_invalid_tick2() {
    let (_, open_router, make_router, base, quote) = setup();
    let key = valid_key(base.contract_address, quote.contract_address);
    open_router.open(key, ArrayTrait::new().span());

    make_router
        .make(
            MakeParams { key, tick: MIN_TICK - 1, unit: 10000, provider: ZERO() },
            ArrayTrait::new().span()
        );
}

#[test]
#[should_panic(expected: ('Book not opened',))]
fn test_make_with_invalid_book_key() {
    let (_, _, make_router, base, quote) = setup();
    let key = valid_key(base.contract_address, quote.contract_address);

    make_router
        .make(
            MakeParams { key, tick: 100000, unit: 10000, provider: ZERO() },
            ArrayTrait::new().span()
        );
}
