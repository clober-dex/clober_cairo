use openzeppelin_token::erc20::ERC20Component::{Approval, Transfer};
use openzeppelin_token::erc20::ERC20Component;
use openzeppelin_utils::test_utils::events::EventSpyExt;
use clober_cairo::book_manager::BookManager;
use clober_cairo::book_manager::BookManager::{
    Open, Make, Take, Cancel, Claim, Collect, Whitelist, Delist, SetDefaultProvider
};
use clober_cairo::libraries::fee_policy::FeePolicy;
use snforge_std::EventSpy;
use starknet::ContractAddress;

#[generate_trait]
pub impl BookManagerSpyHelpersImpl of BookManagerSpyHelpers {
    fn assert_event_open(
        ref self: EventSpy,
        contract: ContractAddress,
        id: felt252,
        base: ContractAddress,
        quote: ContractAddress,
        unit_size: u64,
        maker_policy: FeePolicy,
        taker_policy: FeePolicy,
        hooks: ContractAddress
    ) {
        let expected = Open { id, base, quote, unit_size, maker_policy, taker_policy, hooks };
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_open(
        ref self: EventSpy,
        contract: ContractAddress,
        id: felt252,
        base: ContractAddress,
        quote: ContractAddress,
        unit_size: u64,
        maker_policy: FeePolicy,
        taker_policy: FeePolicy,
        hooks: ContractAddress
    ) {
        self
            .assert_event_open(
                contract, id, base, quote, unit_size, maker_policy, taker_policy, hooks
            );
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_make(
        ref self: EventSpy,
        contract: ContractAddress,
        book_id: felt252,
        user: ContractAddress,
        tick: i32,
        order_index: u64,
        unit: u64,
        provider: ContractAddress
    ) {
        let expected = Make { book_id, user, tick, order_index, unit, provider };
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_make(
        ref self: EventSpy,
        contract: ContractAddress,
        book_id: felt252,
        user: ContractAddress,
        tick: i32,
        order_index: u64,
        unit: u64,
        provider: ContractAddress
    ) {
        self.assert_event_make(contract, book_id, user, tick, order_index, unit, provider);
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_take(
        ref self: EventSpy,
        contract: ContractAddress,
        book_id: felt252,
        user: ContractAddress,
        tick: i32,
        unit: u64
    ) {
        let expected = Take { book_id, user, tick, unit };
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_take(
        ref self: EventSpy,
        contract: ContractAddress,
        book_id: felt252,
        user: ContractAddress,
        tick: i32,
        unit: u64
    ) {
        self.assert_event_take(contract, book_id, user, tick, unit);
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_cancel(
        ref self: EventSpy, contract: ContractAddress, order_id: felt252, unit: u64
    ) {
        let expected = Cancel { order_id, unit };
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_cancel(
        ref self: EventSpy, contract: ContractAddress, order_id: felt252, unit: u64
    ) {
        self.assert_event_cancel(contract, order_id, unit);
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_claim(
        ref self: EventSpy, contract: ContractAddress, order_id: felt252, unit: u64
    ) {
        let expected = Claim { order_id, unit };
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_claim(
        ref self: EventSpy, contract: ContractAddress, order_id: felt252, unit: u64
    ) {
        self.assert_event_claim(contract, order_id, unit);
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_collect(
        ref self: EventSpy,
        contract: ContractAddress,
        provider: ContractAddress,
        recipient: ContractAddress,
        currency: ContractAddress,
        amount: u256
    ) {
        let expected = Collect { provider, recipient, currency, amount };
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_collect(
        ref self: EventSpy,
        contract: ContractAddress,
        provider: ContractAddress,
        recipient: ContractAddress,
        currency: ContractAddress,
        amount: u256
    ) {
        self.assert_event_collect(contract, provider, recipient, currency, amount);
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_whitelist(
        ref self: EventSpy, contract: ContractAddress, provider: ContractAddress
    ) {
        let expected = Whitelist { provider };
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_whitelist(
        ref self: EventSpy, contract: ContractAddress, provider: ContractAddress
    ) {
        self.assert_event_whitelist(contract, provider);
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_delist(
        ref self: EventSpy, contract: ContractAddress, provider: ContractAddress
    ) {
        let expected = Delist { provider };
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_delist(
        ref self: EventSpy, contract: ContractAddress, provider: ContractAddress
    ) {
        self.assert_event_delist(contract, provider);
        self.assert_no_events_left_from(contract);
    }

    fn assert_event_set_default_provider(
        ref self: EventSpy, contract: ContractAddress, provider: ContractAddress
    ) {
        let expected = SetDefaultProvider { provider };
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_set_default_provider(
        ref self: EventSpy, contract: ContractAddress, provider: ContractAddress
    ) {
        self.assert_event_set_default_provider(contract, provider);
        self.assert_no_events_left_from(contract);
    }
}
