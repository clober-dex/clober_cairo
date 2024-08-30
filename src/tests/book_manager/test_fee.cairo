use starknet::ContractAddress;
use clober_cairo::interfaces::book_manager::{
    IBookManagerDispatcher, IBookManagerDispatcherTrait, MakeParams, TakeParams, CancelParams
};
use clober_cairo::libraries::book_key::{BookKey, BookKeyTrait};
use clober_cairo::libraries::tick::{Tick, TickTrait};
use clober_cairo::libraries::fee_policy::{FeePolicy, FeePolicyTrait};
use clober_cairo::libraries::i257::i257;
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
use clober_cairo::mocks::claim_router::ClaimRouter::{
    IClaimRouterDispatcher, IClaimRouterDispatcherTrait
};
use clober_cairo::tests::utils::{deploy_token_pairs, BASE_URI, CONTRACT_URI};
use clober_cairo::tests::book_manager::common::{
    BookManagerSpyHelpers, valid_key
};
use openzeppelin_testing as utils;
use openzeppelin_testing::constants::{ZERO, OWNER};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
use openzeppelin_testing::events::EventSpyExt;
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::{spy_events, EventSpy, cheat_caller_address, CheatSpan};

#[derive(Copy, Drop)]
struct Contracts {
    bm: IBookManagerDispatcher,
    or: IOpenRouterDispatcher,
    mr: IMakeRouterDispatcher,
    tr: ITakeRouterDispatcher,
    ccr: ICancelRouterDispatcher,
    clr: IClaimRouterDispatcher,
    base: IERC20Dispatcher,
    quote: IERC20Dispatcher
}

fn setup() -> Contracts {
    let mut calldata = array![];

    calldata.append_serde(OWNER());
    calldata.append_serde(OWNER());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(CONTRACT_URI());
    let book_manager = utils::declare_and_deploy("BookManager", calldata);

    let mut calldata = array![];
    calldata.append_serde(book_manager);
    let open_router = IOpenRouterDispatcher {
        contract_address: utils::declare_and_deploy("OpenRouter", calldata)
    };
    let (base, quote) = deploy_token_pairs(
        1000000000000000000 * 1000000000000000000, 1000000000000000000 * 1000000, OWNER(), OWNER()
    );

    let mut calldata = array![];
    calldata.append_serde(book_manager);
    let make_router = IMakeRouterDispatcher {
        contract_address: utils::declare_and_deploy("MakeRouter", calldata)
    };

    let mut calldata = array![];
    calldata.append_serde(book_manager);
    let take_router = ITakeRouterDispatcher {
        contract_address: utils::declare_and_deploy("TakeRouter", calldata)
    };

    let mut calldata = array![];
    calldata.append_serde(book_manager);
    let cancel_router = ICancelRouterDispatcher {
        contract_address: utils::declare_and_deploy("CancelRouter", calldata)
    };

    let mut calldata = array![];
    calldata.append_serde(book_manager);
    let claim_router = IClaimRouterDispatcher {
        contract_address: utils::declare_and_deploy("ClaimRouter", calldata)
    };

    let erc721 = IERC721Dispatcher { contract_address: book_manager };
    cheat_caller_address(book_manager, OWNER(), CheatSpan::TargetCalls(1));
    erc721.set_approval_for_all(cancel_router.contract_address, true);
    cheat_caller_address(book_manager, OWNER(), CheatSpan::TargetCalls(1));
    erc721.set_approval_for_all(claim_router.contract_address, true);

    cheat_caller_address(base.contract_address, OWNER(), CheatSpan::TargetCalls(2));
    base.approve(make_router.contract_address, 1000000000000000000 * 1000000000000000000);
    base.approve(take_router.contract_address, 1000000000000000000 * 1000000000000000000);

    cheat_caller_address(quote.contract_address, OWNER(), CheatSpan::TargetCalls(2));
    quote.approve(make_router.contract_address, 1000000000000000000 * 1000000);
    quote.approve(take_router.contract_address, 1000000000000000000 * 1000000);

    Contracts {
        bm: IBookManagerDispatcher { contract_address: book_manager },
        or: open_router,
        mr: make_router,
        tr: take_router,
        ccr: cancel_router,
        clr: claim_router,
        base: base,
        quote: quote
    }
}

#[derive(Copy, Drop)]
struct TestParams {
    index: u32,
    maker_policy: FeePolicy,
    taker_policy: FeePolicy,
    make_used_quote: u256,
    take_used_base: u256,
    take_quote: u256,
    claim_base: u256,
    cancel_quote: u256,
    collect_base: u256,
    collect_quote: u256
}

fn _test_fee(p: TestParams) {
    let mut c = setup();
    let mut key = valid_key(c.base.contract_address, c.quote.contract_address);
    key.maker_policy = p.maker_policy;
    key.taker_policy = p.taker_policy;
    c.or.open(key, ArrayTrait::new().span());

    let (bb, qb) = (c.base.balance_of(OWNER()), c.quote.balance_of(OWNER()));

    // make
    let make_unit = 100000000;
    let tick: Tick = -80000;
    cheat_caller_address(c.mr.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    let (order_id, _) = c
        .mr
        .make(
            MakeParams { key, tick, unit: make_unit, provider: ZERO() }, ArrayTrait::new().span()
        );
    // check fee
    let (_bb, _qb) = (c.base.balance_of(OWNER()), c.quote.balance_of(OWNER()));
    assert_eq!(_bb, bb);
    assert_eq!(qb - _qb, p.make_used_quote);
    let (bb, qb) = (_bb, _qb);

    // take partially
    let take_unit = 10000000;
    cheat_caller_address(c.tr.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    c.tr.take(TakeParams { key, tick, max_unit: take_unit }, ArrayTrait::new().span());
    // check fee
    let (_bb, _qb) = (c.base.balance_of(OWNER()), c.quote.balance_of(OWNER()));
    assert_eq!(bb - _bb, p.take_used_base);
    assert_eq!(_qb - qb, p.take_quote);
    let (bb, qb) = (_bb, _qb);

    // claim
    cheat_caller_address(c.clr.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    c.clr.claim(order_id, ArrayTrait::new().span());
    // check fee
    let (_bb, _qb) = (c.base.balance_of(OWNER()), c.quote.balance_of(OWNER()));
    assert_eq!(_bb - bb, p.claim_base);
    assert_eq!(_qb, qb);
    let (bb, qb) = (_bb, _qb);

    // cancel
    cheat_caller_address(c.ccr.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    c.ccr.cancel(CancelParams { id: order_id, to_unit: 0 }, ArrayTrait::new().span());
    // check fee
    let (_bb, _qb) = (c.base.balance_of(OWNER()), c.quote.balance_of(OWNER()));
    assert_eq!(_bb, bb);
    assert_eq!(_qb - qb, p.cancel_quote);
    let (bb, qb) = (_bb, _qb);

    // collect
    let (collected_base, collected_quote) = (
        c.bm.token_owed(OWNER(), c.base.contract_address),
        c.bm.token_owed(OWNER(), c.quote.contract_address)
    );
    cheat_caller_address(c.bm.contract_address, OWNER(), CheatSpan::TargetCalls(2));
    c.bm.collect(OWNER(), c.quote.contract_address);
    c.bm.collect(OWNER(), c.base.contract_address);
    // check fee
    let (_bb, _qb) = (c.base.balance_of(OWNER()), c.quote.balance_of(OWNER()));
    assert_eq!(_bb - bb, collected_base);
    assert_eq!(_qb - qb, collected_quote);
    assert_eq!(c.bm.token_owed(OWNER(), c.base.contract_address), 0);
    assert_eq!(c.bm.token_owed(OWNER(), c.quote.contract_address), 0);
    assert_eq!(_bb - bb, p.collect_base);
    assert_eq!(_qb - qb, p.collect_quote);
}

// Q/B: Quote/Base
// N/P: Negative/Positive
#[test]
fn test_maker_QN_taker_QP() {
    _test_fee(
        TestParams {
            index: 0,
            maker_policy: FeePolicy { uses_quote: true, rate: -1000 },
            taker_policy: FeePolicy { uses_quote: true, rate: 2000 },
            make_used_quote: 99900000,
            take_used_base: 29797659218,
            take_quote: 9980000,
            claim_base: 29797659217,
            cancel_quote: 89910000,
            collect_base: 0,
            collect_quote: 10000
        }
    );
}

#[test]
fn test_maker_BN_taker_BP() {
    _test_fee(
        TestParams {
            index: 1,
            maker_policy: FeePolicy { uses_quote: false, rate: -1000 },
            taker_policy: FeePolicy { uses_quote: false, rate: 2000 },
            make_used_quote: 100000000,
            take_used_base: 29857254537,
            take_quote: 10000000,
            claim_base: 29827456876,
            cancel_quote: 90000000,
            collect_base: 29797659,
            collect_quote: 0
        }
    );
}

#[test]
fn test_maker_QP_taker_QN() {
    _test_fee(
        TestParams {
            index: 2,
            maker_policy: FeePolicy { uses_quote: true, rate: 2000 },
            taker_policy: FeePolicy { uses_quote: true, rate: -1000 },
            make_used_quote: 100200000,
            take_used_base: 29797659218,
            take_quote: 10010000,
            claim_base: 29797659217,
            cancel_quote: 90180000,
            collect_base: 0,
            collect_quote: 10000
        }
    );
}

#[test]
fn test_maker_BP_taker_BN() {
    _test_fee(
        TestParams {
            index: 3,
            maker_policy: FeePolicy { uses_quote: false, rate: 2000 },
            taker_policy: FeePolicy { uses_quote: false, rate: -1000 },
            make_used_quote: 100000000,
            take_used_base: 29767861559,
            take_quote: 10000000,
            claim_base: 29738063898,
            cancel_quote: 90000000,
            collect_base: 29797659,
            collect_quote: 0
        }
    );
}

#[test]
fn test_maker_QP_taker_QP() {
    _test_fee(
        TestParams {
            index: 4,
            maker_policy: FeePolicy { uses_quote: true, rate: 1000 },
            taker_policy: FeePolicy { uses_quote: true, rate: 1000 },
            make_used_quote: 100100000,
            take_used_base: 29797659218,
            take_quote: 9990000,
            claim_base: 29797659217,
            cancel_quote: 90090000,
            collect_base: 0,
            collect_quote: 20000
        }
    );
}

#[test]
fn test_maker_QP_taker_BP() {
    _test_fee(
        TestParams {
            index: 5,
            maker_policy: FeePolicy { uses_quote: true, rate: 1000 },
            taker_policy: FeePolicy { uses_quote: false, rate: 1000 },
            make_used_quote: 100100000,
            take_used_base: 29827456878,
            take_quote: 10000000,
            claim_base: 29797659217,
            cancel_quote: 90090000,
            collect_base: 29797659,
            collect_quote: 10000
        }
    );
}

#[test]
fn test_maker_BP_taker_QP() {
    _test_fee(
        TestParams {
            index: 6,
            maker_policy: FeePolicy { uses_quote: false, rate: 1000 },
            taker_policy: FeePolicy { uses_quote: true, rate: 1000 },
            make_used_quote: 100000000,
            take_used_base: 29797659218,
            take_quote: 9990000,
            claim_base: 29767861557,
            cancel_quote: 90000000,
            collect_base: 29797660,
            collect_quote: 10000
        }
    );
}

#[test]
fn test_maker_BP_taker_BP() {
    _test_fee(
        TestParams {
            index: 7,
            maker_policy: FeePolicy { uses_quote: false, rate: 1000 },
            taker_policy: FeePolicy { uses_quote: false, rate: 1000 },
            make_used_quote: 100000000,
            take_used_base: 29827456878,
            take_quote: 10000000,
            claim_base: 29767861557,
            cancel_quote: 90000000,
            collect_base: 59595319,
            collect_quote: 0
        }
    );
}
