#[starknet::component]
mod CurrencyDelta {
    use starknet::ContractAddress;
    use clober_cairo::interfaces::currency_delta::ICurrencyDelta;
    use clober_cairo::libraries::i257::{i257, I257Impl};
    use starknet::storage::Map;
    use core::starknet::storage::{StoragePointerReadAccess, StoragePathEntry};

    #[storage]
    struct Storage {
        currency_delta: Map<(ContractAddress, ContractAddress), i257>
    }

    #[embeddable_as(CurrencyDelta)]
    impl CurrencyDeltaImpl<
        TContractState, +HasComponent<TContractState>
    > of ICurrencyDelta<ComponentState<TContractState>> {
        fn get_currency_delta(
            self: @ComponentState<TContractState>,
            locker: ContractAddress,
            currency: ContractAddress,
        ) -> i257 {
            self.currency_delta.read((locker, currency))
        }
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
            self.currency_delta.read((locker, currency))
        }

        fn add(
            ref self: ComponentState<TContractState>,
            locker: ContractAddress,
            currency: ContractAddress,
            delta: i257,
        ) -> i257 {
            let entry = self.currency_delta.entry((locker, currency));
            let delta = delta + entry.read();
            entry.write(delta);
            delta
        }
    }
}
