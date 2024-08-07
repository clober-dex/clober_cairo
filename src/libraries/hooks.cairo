use starknet::ContractAddress;

#[derive(Copy, Drop, Hash, Serde, starknet::Store)]
pub struct Hooks {
    pub address: ContractAddress,
}

pub struct Permissions {
    beforeOpen: bool,
    afterOpen: bool,
    beforeMake: bool,
    afterMake: bool,
    beforeTake: bool,
    afterTake: bool,
    beforeCancel: bool,
    afterCancel: bool,
    beforeClaim: bool,
    afterClaim: bool,
}

pub mod Permission {
    pub const BEFORE_OPEN: u256 = 0x1; // 1 << 0
    pub const AFTER_OPEN: u256 = 0x2; // 1 << 1
    pub const BEFORE_MAKE: u256 = 0x4; // 1 << 2
    pub const AFTER_MAKE: u256 = 0x8; // 1 << 3
    pub const BEFORE_TAKE: u256 = 0x10; // 1 << 4
    pub const AFTER_TAKE: u256 = 0x20; // 1 << 5
    pub const BEFORE_CANCEL: u256 = 0x40; // 1 << 6
    pub const AFTER_CANCEL: u256 = 0x80; // 1 << 7
    pub const BEFORE_CLAIM: u256 = 0x100; // 1 << 8
    pub const AFTER_CLAIM: u256 = 0x200; // 1 << 9
}

#[generate_trait]
pub impl HooksImpl of HooksTrait {
    fn has_permission(self: @Hooks, flag: u256) -> bool {
        let address_felt252: felt252 = (*self.address).into();
        address_felt252.into() & flag != 0
    }

    fn validate_hook_permissions(self: @Hooks, permissions: @Permissions) {
        assert(
            *permissions.beforeOpen == self.has_permission(Permission::BEFORE_OPEN)
                && *permissions.afterOpen == self.has_permission(Permission::AFTER_OPEN)
                && *permissions.beforeMake == self.has_permission(Permission::BEFORE_MAKE)
                && *permissions.afterMake == self.has_permission(Permission::AFTER_MAKE)
                && *permissions.beforeTake == self.has_permission(Permission::BEFORE_TAKE)
                && *permissions.afterTake == self.has_permission(Permission::AFTER_TAKE)
                && *permissions.beforeCancel == self.has_permission(Permission::BEFORE_CANCEL)
                && *permissions.afterCancel == self.has_permission(Permission::AFTER_CANCEL)
                && *permissions.beforeClaim == self.has_permission(Permission::BEFORE_CLAIM)
                && *permissions.afterClaim == self.has_permission(Permission::AFTER_CLAIM),
            'HookAddressNotValid'
        )
    }

    fn is_valid_hook_address(self: @Hooks) -> bool {
        // If a hook contract is set, it must have at least 1 flag set
        let address_felt252: felt252 = (*self.address).into();
        address_felt252 == 0 || address_felt252.into() >= Permission::AFTER_CLAIM
    }
}
