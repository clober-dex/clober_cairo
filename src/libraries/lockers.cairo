#[starknet::component]
mod Lockers {
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        lockers: LegacyMap::<u128, ContractAddress>, // use Array<ContractAddress>,
        lock_callers: LegacyMap::<u128, ContractAddress>,
        // optimistic storage
        length: u128,
        non_zero_delta_count: u128
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
            let mut length = self.length.read();
            self.lockers.write(length, locker);
            self.lock_callers.write(length, locker);
            self.length.write(length + 1);
        }

        fn pop(ref self: ComponentState<TContractState>) {
            let mut length = self.length.read();
            assert(length > 0, 'LOCKER_POP_FAILED');

            // let locker = self.lockers.read(length);
            // let lock_caller = self.lock_callers.read(length);
            self.length.write(length - 1);
        // check if it's better to reset locker and lock_caller
        }

        fn lock_data(ref self: ComponentState<TContractState>) -> (u128, u128) {
            let length = self.length.read();
            let non_zero_delta_count = self.non_zero_delta_count.read();
            (length, non_zero_delta_count)
        }

        fn length(ref self: ComponentState<TContractState>) -> u128 {
            self.length.read()
        }

        fn get_locker(ref self: ComponentState<TContractState>, index: u128) -> ContractAddress {
            self.lockers.read(index)
        }

        fn get_lock_caller(
            ref self: ComponentState<TContractState>, index: u128
        ) -> ContractAddress {
            self.lock_callers.read(index)
        }

        fn get_current_locker(ref self: ComponentState<TContractState>) -> ContractAddress {
            let length = self.length.read();
            if length == 0 {// return ContractAddress::zero();
            }
            self.lockers.read(length - 1)
        }

        fn get_current_lock_caller(ref self: ComponentState<TContractState>) -> ContractAddress {
            let length = self.length.read();
            if length == 0 {// return ContractAddress::zero();
            }
            self.lock_callers.read(length - 1)
        }

        fn increment_nonzero_delta_count(ref self: ComponentState<TContractState>) {
            let mut non_zero_delta_count = self.non_zero_delta_count.read();
            self.non_zero_delta_count.write(non_zero_delta_count + 1);
        }

        fn decrement_nonzero_delta_count(ref self: ComponentState<TContractState>) {
            let mut non_zero_delta_count = self.non_zero_delta_count.read();
            // assert(non_zero_delta_count > 0, 'NON_ZERO_DELTA_COUNT_DECREMENT_FAILED');
            self.non_zero_delta_count.write(non_zero_delta_count - 1);
        }
    }
}
