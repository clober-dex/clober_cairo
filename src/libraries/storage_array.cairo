// SPDX-License-Identifier: MIT
// This code was originally written by OpenZeppelin Contracts for Cairo v0.15.0-rc.0
// (utils/structs/storage_array.cairo)
// Modified by Clober

use core::hash::{HashStateExTrait, HashStateTrait};
use core::poseidon::PoseidonTrait;
use starknet::storage_access::{
    StorageBaseAddress, storage_address_from_base, storage_base_address_from_felt252,
};
use starknet::syscalls::{storage_read_syscall, storage_write_syscall};
use starknet::{Store, SyscallResultTrait, SyscallResult};

const NOT_IMPLEMENTED: felt252 = 'Not implemented';

/// Represents an Array that can be stored in storage.
#[derive(Copy, Drop)]
pub struct StorageArray<T> {
    address_domain: u32,
    base: StorageBaseAddress,
}

impl StoreStorageArray<T, impl TDrop: Drop<T>, impl TStore: Store<T>> of Store<StorageArray<T>> {
    #[inline(always)]
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<StorageArray<T>> {
        SyscallResult::Ok(StorageArray { address_domain, base })
    }
    #[inline(always)]
    fn write(
        address_domain: u32, base: StorageBaseAddress, value: StorageArray<T>,
    ) -> SyscallResult<()> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }
    #[inline(always)]
    fn read_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8,
    ) -> SyscallResult<StorageArray<T>> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }
    #[inline(always)]
    fn write_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8, value: StorageArray<T>,
    ) -> SyscallResult<()> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }
    #[inline(always)]
    fn size() -> u8 {
        // 0 was selected because the read method doesn't actually read from storage
        0_u8
    }
}

/// Trait for accessing a storage array.
///
/// `read_at` and `write_at` don't check the length of the array, caution must be exercised.
/// The current length of the array is stored at the base StorageBaseAddress as felt.
pub trait StorageArrayTrait<T> {
    fn fetch(address_domain: u32, base: StorageBaseAddress) -> StorageArray<T>;
    fn read_at(self: @StorageArray<T>, index: u64) -> T;
    fn write_at(ref self: StorageArray<T>, index: u64, value: T) -> ();
    fn append(ref self: StorageArray<T>, value: T) -> ();
    fn pop(ref self: StorageArray<T>) -> T;
    fn len(self: @StorageArray<T>) -> u64;
}

impl StorageArrayImpl<T, +Drop<T>, impl TStore: Store<T>> of StorageArrayTrait<T> {
    #[inline]
    fn fetch(address_domain: u32, base: StorageBaseAddress) -> StorageArray<T> {
        StorageArray { address_domain, base }
    }

    fn read_at(self: @StorageArray<T>, index: u64) -> T {
        // Get the storage address of the element
        let storage_address_felt: felt252 = storage_address_from_base(*self.base).into();

        let mut state = PoseidonTrait::new();
        let element_address = state.update_with(storage_address_felt + index.into()).finalize();

        // Read the element from storage
        TStore::read(*self.address_domain, storage_base_address_from_felt252(element_address))
            .unwrap_syscall()
    }

    fn write_at(ref self: StorageArray<T>, index: u64, value: T) {
        // Get the storage address of the element
        let storage_address_felt: felt252 = storage_address_from_base(self.base).into();

        let mut state = PoseidonTrait::new();
        let element_address = state.update_with(storage_address_felt + index.into()).finalize();

        // Write the element to storage
        TStore::write(
            self.address_domain, storage_base_address_from_felt252(element_address), value,
        )
            .unwrap_syscall()
    }

    fn append(ref self: StorageArray<T>, value: T) {
        let len = self.len();

        // Write the element to storage
        self.write_at(len, value);

        // Update the len
        let new_len: felt252 = (len + 1).into();
        storage_write_syscall(self.address_domain, storage_address_from_base(self.base), new_len)
            .unwrap_syscall();
    }

    fn pop(ref self: StorageArray<T>) -> T {
        let len = self.len();

        // Get the element
        let element = self.read_at(len - 1);

        // Update the len
        let new_len: felt252 = (len - 1).into();
        storage_write_syscall(self.address_domain, storage_address_from_base(self.base), new_len)
            .unwrap_syscall();

        element
    }

    fn len(self: @StorageArray<T>) -> u64 {
        storage_read_syscall(*self.address_domain, storage_address_from_base(*self.base))
            .unwrap_syscall()
            .try_into()
            .unwrap()
    }
}
