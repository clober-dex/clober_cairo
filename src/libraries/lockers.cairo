use starknet::{ContractAddress, Store, SyscallResultTrait, SyscallResult};
use starknet::storage::Map;
use starknet::storage_access::{
    StorageBaseAddress, storage_address_from_base, storage_base_address_from_felt252
};
use clober_cairo::utils::constants::{ZERO_ADDRESS, TWO_POW_32};
use clober_cairo::interfaces::lockers::ILockers;
use clober_cairo::libraries::storage_map::{Felt252Map, Felt252MapTrait};

const NOT_IMPLEMENTED: felt252 = 'Not implemented';

#[derive(Copy, Drop)]
pub struct Lockers {
    lockers: Felt252Map<(ContractAddress, ContractAddress)>
}

impl StoreLockers of Store<Lockers> {
    #[inline(always)]
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Lockers> {
        SyscallResult::Ok(Lockers { lockers: Felt252MapTrait::fetch(address_domain, base), })
    }

    #[inline(always)]
    fn write(address_domain: u32, base: StorageBaseAddress, value: Lockers) -> SyscallResult<()> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }

    #[inline(always)]
    fn read_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8
    ) -> SyscallResult<Lockers> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }

    #[inline(always)]
    fn write_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8, value: Lockers
    ) -> SyscallResult<()> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }

    #[inline(always)]
    fn size() -> u8 {
        1_u8
    }
}

#[generate_trait]
pub impl LockersImpl of LockersTrait {
    fn update_data(ref self: Lockers, length: u32, non_zero_delta_count: u128) {
        let packed: u256 = (non_zero_delta_count * TWO_POW_32.into() + length.into()).into();
        let (address_domain, base) = self.lockers.get_base_storage_address();
        Store::write(address_domain, base, packed.into()).unwrap_syscall();
    }

    fn push(ref self: Lockers, locker: ContractAddress, lock_caller: ContractAddress) {
        let (length, non_zero_delta_count) = self.lock_data();
        self.lockers.write_at(length.into(), (locker, lock_caller));
        self.update_data(length + 1, non_zero_delta_count);
    }

    fn pop(ref self: Lockers) {
        let (length, non_zero_delta_count) = self.lock_data();
        assert(length > 0, 'LOCKER_POP_FAILED');

        let new_length = length - 1;
        self.lockers.write_at(new_length.into(), (ZERO_ADDRESS(), ZERO_ADDRESS()));
        self.update_data(new_length, non_zero_delta_count);
    }

    fn lock_data(self: @Lockers) -> (u32, u128) {
        let (address_domain, base) = self.lockers.get_base_storage_address();
        let packed: felt252 = Store::read(address_domain, base).unwrap_syscall();
        let packed_u256: u256 = packed.into();
        let length: u32 = (packed_u256 & TWO_POW_32.into() - 1).try_into().unwrap();
        let non_zero_delta_count: u128 = (packed_u256 / TWO_POW_32.into()).try_into().unwrap();
        (length, non_zero_delta_count)
    }

    fn length(self: @Lockers) -> u32 {
        let (length, _) = self.lock_data();
        length
    }

    fn get_lock(self: @Lockers, index: u32) -> (ContractAddress, ContractAddress) {
        self.lockers.read_at(index.into())
    }

    fn get_locker(self: @Lockers, index: u32) -> ContractAddress {
        let (locker, _) = self.lockers.read_at(index.into());
        locker
    }

    fn get_lock_caller(self: @Lockers, index: u32) -> ContractAddress {
        let (_, locker_caller) = self.lockers.read_at(index.into());
        locker_caller
    }

    fn get_current_locker(self: @Lockers) -> ContractAddress {
        let length = self.length();
        if length == 0 {
            ZERO_ADDRESS()
        } else {
            self.get_locker(length - 1)
        }
    }

    fn get_current_lock_caller(self: @Lockers) -> ContractAddress {
        let length = self.length();
        if length == 0 {
            ZERO_ADDRESS()
        } else {
            self.get_lock_caller(length - 1)
        }
    }

    fn increment_nonzero_delta_count(ref self: Lockers) {
        let (length, non_zero_delta_count) = self.lock_data();
        self.update_data(length, non_zero_delta_count + 1);
    }

    fn decrement_nonzero_delta_count(ref self: Lockers) {
        let (length, non_zero_delta_count) = self.lock_data();
        self.update_data(length, non_zero_delta_count - 1);
    }
}
