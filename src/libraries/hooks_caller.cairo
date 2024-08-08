use starknet::{SyscallResultTrait, ContractAddress, syscalls, get_caller_address};
use starknet::storage::Map;
use openzeppelin_utils::structs::storage_array::{StorageArray, StorageArrayTrait};
use clober_cairo::utils::constants::ZERO_ADDRESS;
use clober_cairo::libraries::hooks::{Hooks, HooksTrait, Permission};
use clober_cairo::libraries::book_key::BookKey;
use clober_cairo::interfaces::params::{MakeParams, TakeParams, CancelParams};

#[derive(Copy, Drop, starknet::Store)]
pub struct HooksCaller {
    hooks_list: StorageArray<Hooks>,
}

#[generate_trait]
pub impl HooksCallerImpl of HooksCallerTrait {
    fn get_current_hook(self: @HooksCaller) -> ContractAddress {
        let length = self.hooks_list.len();
        if length == 0 {
            ZERO_ADDRESS()
        } else {
            self.hooks_list.read_at(length - 1).into()
        }
    }

    fn get_hook(self: @HooksCaller, i: u32) -> ContractAddress {
        self.hooks_list.read_at(i).into()
    }

    fn call_hook(
        ref self: HooksCaller, hooks: @Hooks, expected_selector: felt252, hook_data: Span<felt252>
    ) {
        // @dev Set current hook here
        self.hooks_list.append(*hooks);

        let mut res = syscalls::call_contract_syscall((*hooks).into(), expected_selector, hook_data)
            .unwrap_syscall();

        let selector = Serde::<felt252>::deserialize(ref res).unwrap();

        // @dev Clear current hook here
        // TODO: check this
        // self.hooks_list.pop();

        assert(selector == expected_selector, 'InvalidHookResponse');
    }

    fn before_open(ref self: HooksCaller, hooks: @Hooks, key: @BookKey, hook_data: Span<felt252>) {
        if (hooks.has_permission(Permission::BEFORE_OPEN)) {
            let caller = get_caller_address();
            let mut data: Array<felt252> = ArrayTrait::new();
            Serde::serialize(@caller, ref data);
            Serde::serialize(key, ref data);
            Serde::serialize(@hook_data, ref data);

            self.call_hook(hooks, selector!("before_open"), data.span());
        }
    }

    fn after_open(ref self: HooksCaller, hooks: @Hooks, key: @BookKey, hook_data: Span<felt252>) {
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
        ref self: HooksCaller, hooks: @Hooks, params: @MakeParams, hook_data: Span<felt252>
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
        ref self: HooksCaller,
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
        ref self: HooksCaller, hooks: @Hooks, params: @TakeParams, hook_data: Span<felt252>
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
        ref self: HooksCaller,
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
        ref self: HooksCaller, hooks: @Hooks, params: @CancelParams, hook_data: Span<felt252>
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
        ref self: HooksCaller,
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
        ref self: HooksCaller, hooks: @Hooks, order_id: felt252, hook_data: Span<felt252>
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
        ref self: HooksCaller,
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
