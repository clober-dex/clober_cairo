#[starknet::component]
mod CurrencyDelta {
    use starknet::ContractAddress;
    use clober_cairo::alexandria::i257::i257;
    use clober_cairo::alexandria::i257::I257Impl;
    use starknet::storage::Map;
    use core::starknet::storage::StoragePointerReadAccess;
    use core::starknet::storage::StoragePathEntry;

    #[storage]
    struct Storage {
        currency_delta: Map<(ContractAddress, ContractAddress), (u256, bool)>
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn get(
            ref self: ComponentState<TContractState>,
            locker: ContractAddress,
            currency: ContractAddress,
        ) -> i257 {
            let (abs, sign) = self.currency_delta.read((locker, currency));
            I257Impl::new(abs, sign)
        }

        fn add(
            ref self: ComponentState<TContractState>,
            locker: ContractAddress,
            currency: ContractAddress,
            mut delta: i257,
        ) -> i257 {
            let entry = self.currency_delta.entry((locker, currency));
            let (abs, sign) = entry.read();
            delta += I257Impl::new(abs, sign);
            entry.write((delta.abs(), delta.is_negative()));
            delta
        }
    }
}
