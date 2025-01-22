#[starknet::contract]
pub mod MakeRouter {
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use openzeppelin_token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use clober_cairo::interfaces::book_manager::{
        IBookManagerDispatcher, IBookManagerDispatcherTrait, MakeParams,
    };
    use clober_cairo::interfaces::locker::ILocker;

    #[storage]
    struct Storage {
        book_manager: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, book_manager: ContractAddress) {
        self.book_manager.write(book_manager);
    }

    #[starknet::interface]
    pub trait IMakeRouter<TContractState> {
        fn make(
            self: @TContractState, params: MakeParams, hook_data: Span<felt252>,
        ) -> (felt252, u256);
    }

    #[abi(embed_v0)]
    impl MakeRouterImpl of IMakeRouter<ContractState> {
        fn make(
            self: @ContractState, params: MakeParams, hook_data: Span<felt252>,
        ) -> (felt252, u256) {
            let mut data: Array<felt252> = ArrayTrait::new();
            Serde::serialize(@get_caller_address(), ref data);
            Serde::serialize(@params, ref data);
            Serde::serialize(@hook_data, ref data);

            let bm_address = self.book_manager.read();
            let bm = IBookManagerDispatcher { contract_address: bm_address };
            let mut result = bm.lock(get_contract_address(), data.span());
            let (id, quote_amount) = Serde::<(felt252, u256)>::deserialize(ref result).unwrap();
            IERC721Dispatcher { contract_address: bm_address }
                .transfer_from(get_contract_address(), get_caller_address(), id.into());
            (id, quote_amount)
        }
    }

    #[abi(embed_v0)]
    impl LockerImpl of ILocker<ContractState> {
        fn lock_acquired(
            ref self: ContractState, lock_caller: ContractAddress, mut data: Span<felt252>,
        ) -> Span<felt252> {
            let bm = IBookManagerDispatcher { contract_address: self.book_manager.read() };
            assert(bm.contract_address == get_caller_address(), 'Invalid caller');
            let (payer, params, hook_data) = Serde::<
                (ContractAddress, MakeParams, Span<felt252>),
            >::deserialize(ref data)
                .unwrap();
            let (id, quote_amount) = bm.make(params, hook_data);
            if quote_amount > 0 {
                let currency = IERC20Dispatcher { contract_address: params.key.quote };
                currency.transfer_from(payer, bm.contract_address, quote_amount);
                bm.settle(params.key.quote);
            }

            let mut return_data: Array<felt252> = ArrayTrait::new();
            Serde::serialize(@id, ref return_data);
            Serde::serialize(@quote_amount, ref return_data);
            return_data.span()
        }
    }
}
