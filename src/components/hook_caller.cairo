#[starknet::component]
pub mod HookCallerComponent {
    use clober_cairo::interfaces::hook_caller::IHookCaller;
    use clober_cairo::utils::constants::ZERO_ADDRESS;
    use clober_cairo::libraries::hooks::{Hooks, HooksTrait, Permission};
    use clober_cairo::libraries::book_key::BookKey;
    use clober_cairo::interfaces::params::{MakeParams, TakeParams, CancelParams};
    use core::starknet::storage::StoragePointerWriteAccess;
    use starknet::{SyscallResultTrait, ContractAddress, syscalls, get_caller_address};
    use starknet::storage::Map;

    #[storage]
    struct Storage {
        hooks: Map<u128, ContractAddress>,
        length: u128,
    }

    #[embeddable_as(HookCallerImpl)]
    pub impl HookCaller<
        TContractState, +HasComponent<TContractState>
    > of IHookCaller<ComponentState<TContractState>> {
        fn get_current_hook(self: @ComponentState<TContractState>) -> ContractAddress {
            let length = self.length.read();
            if length == 0 {
                ZERO_ADDRESS()
            } else {
                self.hooks.read(length - 1)
            }
        }

        fn get_hook(self: @ComponentState<TContractState>, i: u128) -> ContractAddress {
            self.hooks.read(i)
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn call_hook(
            ref self: ComponentState<TContractState>,
            hooks: @Hooks,
            expected_selector: felt252,
            hook_data: Span<felt252>
        ) {
            // @dev Set current hook here
            let length = self.length.read();
            self.hooks.write(length, *hooks.address);
            self.length.write(length + 1);

            let mut res = syscalls::call_contract_syscall(
                *hooks.address, expected_selector, hook_data
            )
                .unwrap_syscall();

            let selector = Serde::<felt252>::deserialize(ref res).unwrap();

            // @dev Clear current hook here
            self.hooks.write(length, ZERO_ADDRESS());
            self.length.write(length);

            assert(selector == expected_selector, 'InvalidHookResponse');
        }

        fn before_open(
            ref self: ComponentState<TContractState>,
            hooks: @Hooks,
            key: @BookKey,
            hook_data: Span<felt252>
        ) {
            if (hooks.has_permission(Permission::BEFORE_OPEN)) {
                let caller = get_caller_address();
                let mut data: Array<felt252> = ArrayTrait::new();
                Serde::serialize(@caller, ref data);
                Serde::serialize(key, ref data);
                Serde::serialize(@hook_data, ref data);

                self.call_hook(hooks, selector!("before_open"), data.span());
            }
        }

        fn after_open(
            ref self: ComponentState<TContractState>,
            hooks: @Hooks,
            key: @BookKey,
            hook_data: Span<felt252>
        ) {
            if (hooks.has_permission(Permission::AFTER_OPEN)) {
                let caller = get_caller_address();
                let mut data: Array<felt252> = ArrayTrait::new();
                Serde::serialize(@caller, ref data);
                Serde::serialize(key, ref data);
                Serde::serialize(@hook_data, ref data);

                self.call_hook(hooks, selector!("after_open"), data.span());
            }
        }

        fn before_make(
            ref self: ComponentState<TContractState>,
            hooks: @Hooks,
            params: @MakeParams,
            hook_data: Span<felt252>
        ) {
            if (hooks.has_permission(Permission::BEFORE_MAKE)) {
                let caller = get_caller_address();
                let mut data: Array<felt252> = ArrayTrait::new();
                Serde::serialize(@caller, ref data);
                Serde::serialize(params, ref data);
                Serde::serialize(@data, ref data);

                self.call_hook(hooks, selector!("before_make"), data.span());
            }
        }

        fn after_make(
            ref self: ComponentState<TContractState>,
            hooks: @Hooks,
            params: @MakeParams,
            order_id: felt252,
            hook_data: Span<felt252>
        ) {
            if (hooks.has_permission(Permission::AFTER_MAKE)) {
                let caller = get_caller_address();
                let mut data: Array<felt252> = ArrayTrait::new();
                Serde::serialize(@caller, ref data);
                Serde::serialize(params, ref data);
                Serde::serialize(@order_id, ref data);
                Serde::serialize(@data, ref data);

                self.call_hook(hooks, selector!("after_make"), data.span());
            }
        }

        fn before_take(
            ref self: ComponentState<TContractState>,
            hooks: @Hooks,
            params: @TakeParams,
            hook_data: Span<felt252>
        ) {
            if (hooks.has_permission(Permission::BEFORE_TAKE)) {
                let caller = get_caller_address();
                let mut data: Array<felt252> = ArrayTrait::new();
                Serde::serialize(@caller, ref data);
                Serde::serialize(params, ref data);
                Serde::serialize(@data, ref data);

                self.call_hook(hooks, selector!("before_take"), data.span());
            }
        }

        fn after_take(
            ref self: ComponentState<TContractState>,
            hooks: @Hooks,
            params: @TakeParams,
            taken_unit: u64,
            hook_data: Span<felt252>
        ) {
            if (hooks.has_permission(Permission::AFTER_TAKE)) {
                let caller = get_caller_address();
                let mut data: Array<felt252> = ArrayTrait::new();
                Serde::serialize(@caller, ref data);
                Serde::serialize(params, ref data);
                Serde::serialize(@taken_unit, ref data);
                Serde::serialize(@data, ref data);

                self.call_hook(hooks, selector!("after_take"), data.span());
            }
        }

        fn before_cancel(
            ref self: ComponentState<TContractState>,
            hooks: @Hooks,
            params: @CancelParams,
            hook_data: Span<felt252>
        ) {
            if (hooks.has_permission(Permission::BEFORE_CANCEL)) {
                let caller = get_caller_address();
                let mut data: Array<felt252> = ArrayTrait::new();
                Serde::serialize(@caller, ref data);
                Serde::serialize(params, ref data);
                Serde::serialize(@data, ref data);

                self.call_hook(hooks, selector!("before_cancel"), data.span());
            }
        }

        fn after_cancel(
            ref self: ComponentState<TContractState>,
            hooks: @Hooks,
            params: @CancelParams,
            canceled_unit: u64,
            hook_data: Span<felt252>
        ) {
            if (hooks.has_permission(Permission::AFTER_CANCEL)) {
                let caller = get_caller_address();
                let mut data: Array<felt252> = ArrayTrait::new();
                Serde::serialize(@caller, ref data);
                Serde::serialize(params, ref data);
                Serde::serialize(@canceled_unit, ref data);
                Serde::serialize(@data, ref data);

                self.call_hook(hooks, selector!("after_cancel"), data.span());
            }
        }

        fn before_claim(
            ref self: ComponentState<TContractState>,
            hooks: @Hooks,
            order_id: felt252,
            hook_data: Span<felt252>
        ) {
            if (hooks.has_permission(Permission::BEFORE_CLAIM)) {
                let caller = get_caller_address();
                let mut data: Array<felt252> = ArrayTrait::new();
                Serde::serialize(@caller, ref data);
                Serde::serialize(@order_id, ref data);
                Serde::serialize(@data, ref data);

                self.call_hook(hooks, selector!("before_claim"), data.span());
            }
        }

        fn after_claim(
            ref self: ComponentState<TContractState>,
            hooks: @Hooks,
            order_id: felt252,
            claimed_unit: u64,
            hook_data: Span<felt252>
        ) {
            if (hooks.has_permission(Permission::AFTER_CLAIM)) {
                let caller = get_caller_address();
                let mut data: Array<felt252> = ArrayTrait::new();
                Serde::serialize(@caller, ref data);
                Serde::serialize(@order_id, ref data);
                Serde::serialize(@claimed_unit, ref data);
                Serde::serialize(@data, ref data);

                self.call_hook(hooks, selector!("after_claim"), data.span());
            }
        }
    }
}
