#[starknet::component]
mod CurrencyDelta {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        currency_delta: LegacyMap::<(ContractAddress, ContractAddress), i128>
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn get(
            ref self: ComponentState<TContractState>,
            locker: ContractAddress,
            currency: ContractAddress,
        ) -> i128 {
            self.currency_delta.read((locker, currency))
        }

        fn add(
            ref self: ComponentState<TContractState>,
            locker: ContractAddress,
            currency: ContractAddress,
            delta: i128,
        ) {
            let mut currency_delta = self.currency_delta.read((locker, currency));
            self.currency_delta.write((locker, currency), currency_delta + delta)
        }
    }
}
