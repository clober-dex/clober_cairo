#[starknet::contract]
pub mod ClaimRouter {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use clober_cairo::interfaces::book_manager::{
        IBookManagerDispatcher, IBookManagerDispatcherTrait
    };
    use clober_cairo::interfaces::locker::ILocker;
    use clober_cairo::libraries::order_id::OrderIdTrait;

    #[storage]
    struct Storage {
        book_manager: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, book_manager: ContractAddress) {
        self.book_manager.write(book_manager);
    }

    #[starknet::interface]
    pub trait IClaimRouter<TContractState> {
        fn claim(self: @TContractState, id: felt252, hook_data: Span<felt252>) -> u256;
    }

    #[abi(embed_v0)]
    impl ClaimRouterImpl of IClaimRouter<ContractState> {
        fn claim(self: @ContractState, id: felt252, hook_data: Span<felt252>) -> u256 {
            let mut data: Array<felt252> = ArrayTrait::new();
            Serde::serialize(@get_caller_address(), ref data);
            Serde::serialize(@id, ref data);
            Serde::serialize(@hook_data, ref data);

            let bm_address = self.book_manager.read();
            let bm = IBookManagerDispatcher { contract_address: bm_address };
            let mut result = bm.lock(get_contract_address(), data.span());
            Serde::<u256>::deserialize(ref result).unwrap()
        }
    }

    #[abi(embed_v0)]
    impl LockerImpl of ILocker<ContractState> {
        fn lock_acquired(
            ref self: ContractState, lock_caller: ContractAddress, mut data: Span<felt252>
        ) -> Span<felt252> {
            let bm = IBookManagerDispatcher { contract_address: self.book_manager.read() };
            assert(bm.contract_address == get_caller_address(), 'Invalid caller');
            let (payer, id, hook_data) = Serde::<
                (ContractAddress, felt252, Span<felt252>)
            >::deserialize(ref data)
                .unwrap();
            let claimed_amount = bm.claim(id, hook_data);
            if claimed_amount > 0 {
                let base = bm.get_book_key(OrderIdTrait::decode(id).book_id).base;
                bm.withdraw(base, payer, claimed_amount);
            }

            let mut return_data: Array<felt252> = ArrayTrait::new();
            Serde::serialize(@claimed_amount, ref return_data);
            return_data.span()
        }
    }
}
