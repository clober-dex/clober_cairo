use core::poseidon::{poseidon_hash_span, PoseidonTrait};
use core::hash::{HashStateTrait, HashStateExTrait};
use starknet::storage_access::{
    Store, StorageBaseAddress, storage_address_from_base, storage_base_address_from_felt252
};
use starknet::{SyscallResult, SyscallResultTrait};

const NOT_IMPLEMENTED: felt252 = 'Not implemented';

#[derive(Copy, Drop)]
pub struct StorageMap<T> {
    address_domain: u32,
    base: StorageBaseAddress
}

impl StoreStorageMap<T, impl TDrop: Drop<T>, impl TStore: Store<T>> of Store<StorageMap<T>> {
    #[inline(always)]
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<StorageMap<T>> {
        SyscallResult::Ok(StorageMap { address_domain, base })
    }
    #[inline(always)]
    fn write(
        address_domain: u32, base: StorageBaseAddress, value: StorageMap<T>
    ) -> SyscallResult<()> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }
    #[inline(always)]
    fn read_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8
    ) -> SyscallResult<StorageMap<T>> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }
    #[inline(always)]
    fn write_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8, value: StorageMap<T>
    ) -> SyscallResult<()> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }
    #[inline(always)]
    fn size() -> u8 {
        // 0 was selected because the read method doesn't actually read from storage
        0_u8
    }
}

fn caculate_storage_address(storage_address_felt: felt252, key: felt252) -> felt252 {
    PoseidonTrait::new().update_with((storage_address_felt, key)).finalize()
}

#[generate_trait]
pub impl StorageMapImpl<T, +Drop<T>, impl TStore: Store<T>> of StorageMapTrait<T> {
    #[inline]
    fn fetch(address_domain: u32, base: StorageBaseAddress) -> StorageMap<T> {
        StorageMap { address_domain, base }
    }

    fn address_at(self: @StorageMap<T>, key: felt252) -> felt252 {
        let base_storage_address: felt252 = storage_address_from_base(*self.base).into();

        caculate_storage_address(base_storage_address, key)
    }

    fn read_at(self: @StorageMap<T>, key: felt252) -> T {
        let base_storage_address: felt252 = storage_address_from_base(*self.base).into();

        let element_address = caculate_storage_address(base_storage_address, key);

        TStore::read(*self.address_domain, storage_base_address_from_felt252(element_address))
            .unwrap_syscall()
    }

    fn write_at(ref self: StorageMap<T>, key: felt252, value: T) {
        let base_storage_address: felt252 = storage_address_from_base(self.base).into();

        let element_address = caculate_storage_address(base_storage_address, key);

        TStore::write(
            self.address_domain, storage_base_address_from_felt252(element_address), value
        )
            .unwrap_syscall()
    }
}
