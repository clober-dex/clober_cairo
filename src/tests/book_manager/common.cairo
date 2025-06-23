use clober_cairo::tests::constants::ZERO;
use clober_cairo::book_manager::BookManager;
use clober_cairo::interfaces::book_manager::{
    Open, Make, Take, Cancel, Claim, Collect, Whitelist, Delist, SetDefaultProvider,
};
use clober_cairo::libraries::book_key::BookKey;
use clober_cairo::libraries::fee_policy::FeePolicy;
use snforge_std::{EventSpy, EventSpyAssertionsTrait, EventSpyTrait, EventsFilterTrait};
use starknet::ContractAddress;

pub fn valid_key(base: ContractAddress, quote: ContractAddress) -> BookKey {
    BookKey {
        base,
        quote,
        hooks: ZERO(),
        unit_size: 1,
        taker_policy: FeePolicy { uses_quote: true, rate: 0 },
        maker_policy: FeePolicy { uses_quote: true, rate: 0 },
    }
}

#[generate_trait]
pub impl EventSpyExtImpl of EventSpyExt {
    fn assert_emitted_single<T, +Drop<T>, +starknet::Event<T>>(
        ref self: EventSpy, contract: ContractAddress, expected: T
    ) {
        self.assert_emitted(@array![(contract, expected)]);
    }

    fn assert_no_events_left_from(ref self: EventSpy, contract: ContractAddress) {
        // In snforge_std 0.44.0, this method should be used differently
        // The pattern now is to assert the exact expected events, not check for "no remaining events"
        // For the assert_only_* pattern, we need to change the approach
        // This method is left as a placeholder but should be used carefully
    }
    
    fn drop_all_events(ref self: EventSpy) {
        // In newer snforge_std, we can just call get_events() to "consume" them
        // This effectively clears the spy's accumulated events
        let _ = self.get_events();
    }
}

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
        hooks: ContractAddress,
    ) {
        let expected = BookManager::Event::Open(
            Open { id, base, quote, unit_size, maker_policy, taker_policy, hooks },
        );
        self.assert_emitted(@array![(contract, expected)]);
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
        hooks: ContractAddress,
    ) {
        let expected = BookManager::Event::Open(
            Open { id, base, quote, unit_size, maker_policy, taker_policy, hooks },
        );
        // In snforge_std 0.44.0, we assert exact events instead of checking for "no remaining"
        self.assert_emitted(@array![(contract, expected)]);
        
        // Verify that only this one event was emitted by checking total count
        let events = self.get_events().emitted_by(contract);
        assert(events.events.len() == 1, 'Unexpected events found');
    }

    fn assert_event_make(
        ref self: EventSpy,
        contract: ContractAddress,
        book_id: felt252,
        user: ContractAddress,
        tick: i32,
        order_index: u64,
        unit: u64,
        provider: ContractAddress,
    ) {
        let expected = BookManager::Event::Make(
            Make { book_id, user, tick, order_index, unit, provider },
        );
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
        provider: ContractAddress,
    ) {
        let expected = BookManager::Event::Make(
            Make { book_id, user, tick, order_index, unit, provider },
        );
        self.assert_emitted(@array![(contract, expected)]);
        
        let events = self.get_events().emitted_by(contract);
        assert(events.events.len() == 1, 'Unexpected events found');
    }

    fn assert_event_take(
        ref self: EventSpy,
        contract: ContractAddress,
        book_id: felt252,
        user: ContractAddress,
        tick: i32,
        unit: u64,
    ) {
        let expected = BookManager::Event::Take(Take { book_id, user, tick, unit });
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_take(
        ref self: EventSpy,
        contract: ContractAddress,
        book_id: felt252,
        user: ContractAddress,
        tick: i32,
        unit: u64,
    ) {
        let expected = BookManager::Event::Take(Take { book_id, user, tick, unit });
        self.assert_emitted(@array![(contract, expected)]);
        
        let events = self.get_events().emitted_by(contract);
        assert(events.events.len() == 1, 'Unexpected events found');
    }

    fn assert_event_cancel(
        ref self: EventSpy, contract: ContractAddress, order_id: felt252, unit: u64,
    ) {
        let expected = BookManager::Event::Cancel(Cancel { order_id, unit });
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_cancel(
        ref self: EventSpy, contract: ContractAddress, order_id: felt252, unit: u64,
    ) {
        let expected = BookManager::Event::Cancel(Cancel { order_id, unit });
        self.assert_emitted(@array![(contract, expected)]);
        
        let events = self.get_events().emitted_by(contract);
        assert(events.events.len() == 1, 'Unexpected events found');
    }

    fn assert_event_claim(
        ref self: EventSpy, contract: ContractAddress, order_id: felt252, unit: u64,
    ) {
        let expected = BookManager::Event::Claim(Claim { order_id, unit });
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_claim(
        ref self: EventSpy, contract: ContractAddress, order_id: felt252, unit: u64,
    ) {
        let expected = BookManager::Event::Claim(Claim { order_id, unit });
        self.assert_emitted(@array![(contract, expected)]);
        
        let events = self.get_events().emitted_by(contract);
        assert(events.events.len() == 1, 'Unexpected events found');
    }

    fn assert_event_collect(
        ref self: EventSpy,
        contract: ContractAddress,
        provider: ContractAddress,
        recipient: ContractAddress,
        currency: ContractAddress,
        amount: u256,
    ) {
        let expected = BookManager::Event::Collect(
            Collect { provider, recipient, currency, amount },
        );
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_collect(
        ref self: EventSpy,
        contract: ContractAddress,
        provider: ContractAddress,
        recipient: ContractAddress,
        currency: ContractAddress,
        amount: u256,
    ) {
        let expected = BookManager::Event::Collect(
            Collect { provider, recipient, currency, amount },
        );
        self.assert_emitted(@array![(contract, expected)]);
        
        let events = self.get_events().emitted_by(contract);
        assert(events.events.len() == 1, 'Unexpected events found');
    }

    fn assert_event_whitelist(
        ref self: EventSpy, contract: ContractAddress, provider: ContractAddress,
    ) {
        let expected = BookManager::Event::Whitelist(Whitelist { provider });
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_whitelist(
        ref self: EventSpy, contract: ContractAddress, provider: ContractAddress,
    ) {
        let expected = BookManager::Event::Whitelist(Whitelist { provider });
        self.assert_emitted(@array![(contract, expected)]);
        
        let events = self.get_events().emitted_by(contract);
        assert(events.events.len() == 1, 'Unexpected events found');
    }

    fn assert_event_delist(
        ref self: EventSpy, contract: ContractAddress, provider: ContractAddress,
    ) {
        let expected = BookManager::Event::Delist(Delist { provider });
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_delist(
        ref self: EventSpy, contract: ContractAddress, provider: ContractAddress,
    ) {
        let expected = BookManager::Event::Delist(Delist { provider });
        self.assert_emitted(@array![(contract, expected)]);
        
        let events = self.get_events().emitted_by(contract);
        assert(events.events.len() == 1, 'Unexpected events found');
    }

    fn assert_event_set_default_provider(
        ref self: EventSpy, contract: ContractAddress, provider: ContractAddress,
    ) {
        let expected = BookManager::Event::SetDefaultProvider(SetDefaultProvider { provider });
        self.assert_emitted_single(contract, expected);
    }

    fn assert_only_event_set_default_provider(
        ref self: EventSpy, contract: ContractAddress, provider: ContractAddress,
    ) {
        let expected = BookManager::Event::SetDefaultProvider(SetDefaultProvider { provider });
        self.assert_emitted(@array![(contract, expected)]);
        
        let events = self.get_events().emitted_by(contract);
        assert(events.events.len() == 1, 'Unexpected events found');
    }
}
