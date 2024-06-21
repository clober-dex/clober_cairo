#[starknet::component]
mod CurrencyDelta {
    use starknet::ContractAddress;
    use clober_cairo::alexandria::i257::i257;
    use clober_cairo::alexandria::i257::I257Impl;

    #[storage]
    struct Storage {
        currency_delta: LegacyMap::<(ContractAddress, ContractAddress), (bool, u256)>
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
            let (sign, abs) = self.currency_delta.read((locker, currency));
            I257Impl::new(abs, sign)
        }

        fn add(
            ref self: ComponentState<TContractState>,
            locker: ContractAddress,
            currency: ContractAddress,
            mut delta: i257,
        ) {
            let (sign, abs): (bool, u256) = self
                .currency_delta
                .read((locker, currency));
            delta += I257Impl::new(abs, sign);
            self.currency_delta.write((locker, currency), (delta.is_negative(), delta.abs()))
        }
    }
}
