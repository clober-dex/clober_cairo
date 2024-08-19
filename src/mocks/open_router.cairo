#[starknet::contract]
pub mod OpenRouter {
    use starknet::{ContractAddress, get_contract_address};
    use clober_cairo::interfaces::book_manager::{
        IBookManager, IBookManagerDispatcher, IBookManagerDispatcherTrait
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
    pub trait IOpenRouter<TContractState> {
        fn open(self: @TContractState, book_key: BookKey, hook_data: Span<felt252>);
    }

    #[abi(embed_v0)]
    impl OpenRouterImpl of IOpenRouter<ContractState> {
        fn open(self: @ContractState, book_key: BookKey, hook_data: Span<felt252>) {
            let mut data: Array<felt252> = ArrayTrait::new();
            Serde::serialize(@book_key, ref data);
            Serde::serialize(@hook_data, ref data);

            let bm = IBookManagerDispatcher { contract_address: self.book_manager.read() };
            bm.lock(get_contract_address(), data.span());
        }
    }

    #[abi(embed_v0)]
    impl LockerImpl of ILocker<ContractState> {
        fn lock_acquired(
            ref self: ContractState, lock_caller: ContractAddress, mut data: Span<felt252>
        ) -> Span<felt252> {
            let bm = IBookManagerDispatcher { contract_address: self.book_manager.read() };
            let (book_key, hook_data) = Serde::<(BookKey, Span<felt252>)>::deserialize(ref data)
                .unwrap();
            bm.open(book_key, hook_data);
            ArrayTrait::new().span()
        }
    }
}
