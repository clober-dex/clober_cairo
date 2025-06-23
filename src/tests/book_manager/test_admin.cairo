use clober_cairo::interfaces::book_manager::{IBookManagerDispatcher, IBookManagerDispatcherTrait};
use clober_cairo::tests::book_manager::common::{BookManagerSpyHelpers};
use clober_cairo::tests::utils::{BASE_URI, CONTRACT_URI};
use openzeppelin_testing as utils;
use clober_cairo::tests::constants::{OWNER, ZERO, OTHER, RECIPIENT};
use openzeppelin_utils::serde::SerializedAppend;
use snforge_std::{spy_events, cheat_caller_address, CheatSpan};

fn setup() -> IBookManagerDispatcher {
    let mut calldata = array![];

    calldata.append_serde(OWNER());
    calldata.append_serde(RECIPIENT());
    calldata.append_serde(BASE_URI());
    calldata.append_serde(CONTRACT_URI());
    let book_manager = utils::declare_and_deploy("BookManager", calldata);
    IBookManagerDispatcher { contract_address: book_manager }
}

#[test]
fn test_whitelist() {
    let bm = setup();
    assert!(!bm.is_whitelisted(OTHER()));

    cheat_caller_address(bm.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    let mut spy = spy_events();
    bm.whitelist(OTHER());
    spy.assert_only_event_whitelist(bm.contract_address, OTHER());

    assert!(bm.is_whitelisted(OTHER()));
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_whitelist_ownership() {
    let bm = setup();

    cheat_caller_address(bm.contract_address, OTHER(), CheatSpan::TargetCalls(1));
    bm.whitelist(OTHER());
}

#[test]
fn test_delist() {
    let bm = setup();
    assert!(!bm.is_whitelisted(OTHER()));

    cheat_caller_address(bm.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    bm.whitelist(OTHER());
    assert!(bm.is_whitelisted(OTHER()));

    cheat_caller_address(bm.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    let mut spy = spy_events();
    bm.delist(OTHER());
    spy.assert_only_event_delist(bm.contract_address, OTHER());

    assert!(!bm.is_whitelisted(OTHER()));
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_delist_ownership() {
    let bm = setup();

    cheat_caller_address(bm.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    bm.whitelist(OTHER());
    assert!(bm.is_whitelisted(OTHER()));

    cheat_caller_address(bm.contract_address, OTHER(), CheatSpan::TargetCalls(1));
    bm.delist(OTHER());
}

#[test]
fn test_set_default_provider() {
    let bm = setup();
    assert_eq!(bm.default_provider(), RECIPIENT());

    cheat_caller_address(bm.contract_address, OWNER(), CheatSpan::TargetCalls(1));
    let mut spy = spy_events();
    bm.set_default_provider(OTHER());
    spy.assert_only_event_set_default_provider(bm.contract_address, OTHER());

    assert_eq!(bm.default_provider(), OTHER());
}

#[test]
#[should_panic(expected: ('Caller is not the owner',))]
fn test_set_default_provider_ownership() {
    let bm = setup();

    cheat_caller_address(bm.contract_address, OTHER(), CheatSpan::TargetCalls(1));
    bm.set_default_provider(OTHER());
}
