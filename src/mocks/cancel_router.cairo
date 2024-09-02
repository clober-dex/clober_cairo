#[starknet::contract]
pub mod CancelRouter {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use clober_cairo::interfaces::book_manager::{
        IBookManagerDispatcher, IBookManagerDispatcherTrait, CancelParams
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
    pub trait ICancelRouter<TContractState> {
        fn cancel(self: @TContractState, params: CancelParams, hook_data: Span<felt252>) -> u256;
    }

    #[abi(embed_v0)]
    impl CancelRouterImpl of ICancelRouter<ContractState> {
        fn cancel(self: @ContractState, params: CancelParams, hook_data: Span<felt252>) -> u256 {
            let mut data: Array<felt252> = ArrayTrait::new();
            Serde::serialize(@get_caller_address(), ref data);
            Serde::serialize(@params, ref data);
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
            let (payer, params, hook_data) = Serde::<
                (ContractAddress, CancelParams, Span<felt252>)
            >::deserialize(ref data)
                .unwrap();
            let canceled_amount = bm.cancel(params, hook_data);
            if (canceled_amount > 0) {
                let quote = bm.get_book_key(OrderIdTrait::decode(params.id).book_id).quote;
                bm.withdraw(quote, payer, canceled_amount);
            }

            let mut return_data: Array<felt252> = ArrayTrait::new();
            Serde::serialize(@canceled_amount, ref return_data);
            return_data.span()
        }
    }
}
