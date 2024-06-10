#[starknet::component]
mod CurrencyDelta {
    use starknet::ContractAddress;

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
        ) -> (bool, u256) {
            self.currency_delta.read((locker, currency))
        }

        fn add(
            ref self: ComponentState<TContractState>,
            locker: ContractAddress,
            currency: ContractAddress,
            sign: bool,
            delta: u256,
        ) {
            let (sign_delta, currency_delta): (bool, u256) = self
                .currency_delta
                .read((locker, currency));
            if sign_delta == sign {
                self.currency_delta.write((locker, currency), (sign, currency_delta + delta))
            } else if currency_delta == delta {
                self.currency_delta.write((locker, currency), (false, 0))
            } else if currency_delta < delta {
                self.currency_delta.write((locker, currency), (sign, delta - currency_delta))
            } else {
                self.currency_delta.write((locker, currency), (sign_delta, currency_delta - delta))
            }
        }
    }
}
