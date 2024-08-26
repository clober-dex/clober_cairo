#[starknet::contract]
pub mod TakeRouter {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use clober_cairo::interfaces::book_manager::{
        IBookManager, IBookManagerDispatcher, IBookManagerDispatcherTrait, TakeParams
    };
    use clober_cairo::interfaces::locker::ILocker;
    use clober_cairo::libraries::book_key::BookKey;

    #[storage]
    struct Storage {
        book_manager: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, book_manager: ContractAddress) {
        self.book_manager.write(book_manager);
    }

    #[starknet::interface]
    pub trait ITakeRouter<TContractState> {
        fn take(
            self: @TContractState, params: TakeParams, hook_data: Span<felt252>
        ) -> (u256, u256);
    }

    #[abi(embed_v0)]
    impl TakeRouterImpl of ITakeRouter<ContractState> {
        fn take(
            self: @ContractState, params: TakeParams, hook_data: Span<felt252>
        ) -> (u256, u256) {
            let mut data: Array<felt252> = ArrayTrait::new();
            Serde::serialize(@get_caller_address(), ref data);
            Serde::serialize(@params, ref data);
            Serde::serialize(@hook_data, ref data);

            let bm = IBookManagerDispatcher { contract_address: self.book_manager.read() };
            let mut result = bm.lock(get_contract_address(), data.span());
            let (quote_amount, base_amount) = Serde::<(u256, u256)>::deserialize(ref result)
                .unwrap();

            (quote_amount, base_amount)
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
                (ContractAddress, TakeParams, Span<felt252>)
            >::deserialize(ref data)
                .unwrap();
            let (quote_amount, base_amount) = bm.take(params, hook_data);
            if (quote_amount > 0) {
                bm.withdraw(params.key.quote, payer, quote_amount);
            }
            if (base_amount > 0) {
                let currency = IERC20Dispatcher { contract_address: params.key.base };
                currency.transfer_from(payer, bm.contract_address, base_amount);
                bm.settle(params.key.base);
            }

            let mut return_data: Array<felt252> = ArrayTrait::new();
            Serde::serialize(@quote_amount, ref return_data);
            Serde::serialize(@base_amount, ref return_data);
            return_data.span()
        }
    }
}
