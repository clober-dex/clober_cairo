#[starknet::component]
pub mod LockersComponent {
    use clober_cairo::utils::constants::ZERO_ADDRESS;
    use clober_cairo::interfaces::lockers::ILockers;
    use starknet::ContractAddress;
    use starknet::storage::Map;

    #[storage]
    struct Storage {
        lockers: Map<u128, ContractAddress>, // use Array<ContractAddress>,
        lock_callers: Map<u128, ContractAddress>,
        length: u128,
        non_zero_delta_count: u128
    }

    #[embeddable_as(LockersImpl)]
    pub impl Lockers<
        TContractState, +HasComponent<TContractState>
    > of ILockers<ComponentState<TContractState>> {
        fn get_lock(
            self: @ComponentState<TContractState>, i: u128
        ) -> (ContractAddress, ContractAddress) {
            (self.get_locker(i), self.get_lock_caller(i))
        }

        fn get_lock_data(self: @ComponentState<TContractState>) -> (u128, u128) {
            self.lock_data()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn push(
            ref self: ComponentState<TContractState>,
            locker: ContractAddress,
            lock_caller: ContractAddress
        ) {
            let length = self.length.read();
            self.lockers.write(length, locker);
            self.lock_callers.write(length, locker);
            self.length.write(length + 1);
        }

        fn pop(ref self: ComponentState<TContractState>) {
            let length = self.length.read() - 1;
            // assert(length > 0, 'LOCKER_POP_FAILED');

            self.lockers.write(length, ZERO_ADDRESS());
            self.lock_callers.write(length, ZERO_ADDRESS());
            self.length.write(length);
        }

        fn lock_data(self: @ComponentState<TContractState>) -> (u128, u128) {
            let length = self.length.read();
            let non_zero_delta_count = self.non_zero_delta_count.read();
            (length, non_zero_delta_count)
        }

        fn length(self: @ComponentState<TContractState>) -> u128 {
            self.length.read()
        }

        fn get_locker(self: @ComponentState<TContractState>, index: u128) -> ContractAddress {
            self.lockers.read(index)
        }

        fn get_lock_caller(self: @ComponentState<TContractState>, index: u128) -> ContractAddress {
            self.lock_callers.read(index)
        }

        fn get_current_locker(self: @ComponentState<TContractState>) -> ContractAddress {
            let length = self.length.read();
            if length == 0 {
                ZERO_ADDRESS()
            } else {
                self.lockers.read(length - 1)
            }
        }

        fn get_current_lock_caller(self: @ComponentState<TContractState>) -> ContractAddress {
            let length = self.length.read();
            if length == 0 {
                ZERO_ADDRESS()
            } else {
                self.lock_callers.read(length - 1)
            }
        }

        fn increment_nonzero_delta_count(ref self: ComponentState<TContractState>) {
            let non_zero_delta_count = self.non_zero_delta_count.read();
            self.non_zero_delta_count.write(non_zero_delta_count + 1);
        }

        fn decrement_nonzero_delta_count(ref self: ComponentState<TContractState>) {
            let non_zero_delta_count = self.non_zero_delta_count.read();
            // assert(non_zero_delta_count > 0, 'NON_ZERO_DELTA_COUNT_DECREMENT_FAILED');
            self.non_zero_delta_count.write(non_zero_delta_count - 1);
        }
    }
}
