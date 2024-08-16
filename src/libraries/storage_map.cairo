use core::poseidon::{HashState, poseidon_hash_span, PoseidonTrait};
use core::hash::{Hash, HashStateTrait, HashStateExTrait};
use starknet::storage_access::{
    Store, StorageBaseAddress, storage_address_from_base, storage_base_address_from_felt252
};
use starknet::{SyscallResult, SyscallResultTrait};

const NOT_IMPLEMENTED: felt252 = 'Not implemented';

#[derive(Copy, Drop)]
pub struct Felt252Map<T> {
    address_domain: u32,
    base: StorageBaseAddress
}

impl StoreFelt252Map<T, impl TDrop: Drop<T>, impl TStore: Store<T>> of Store<Felt252Map<T>> {
    #[inline(always)]
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult<Felt252Map<T>> {
        SyscallResult::Ok(Felt252Map { address_domain, base })
    }
    #[inline(always)]
    fn write(
        address_domain: u32, base: StorageBaseAddress, value: Felt252Map<T>
    ) -> SyscallResult<()> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }
    #[inline(always)]
    fn read_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8
    ) -> SyscallResult<Felt252Map<T>> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }
    #[inline(always)]
    fn write_at_offset(
        address_domain: u32, base: StorageBaseAddress, offset: u8, value: Felt252Map<T>
    ) -> SyscallResult<()> {
        SyscallResult::Err(array![NOT_IMPLEMENTED])
    }
    #[inline(always)]
    fn size() -> u8 {
        // 0 was selected because the read method doesn't actually read from storage
        100_u8
    }
}

fn caculate_storage_address(storage_address_felt: felt252, key: felt252) -> felt252 {
    PoseidonTrait::new().update_with((storage_address_felt, key)).finalize()
}

#[generate_trait]
pub impl Felt252MapImpl<T, +Drop<T>, impl TStore: Store<T>> of Felt252MapTrait<T> {
    #[inline]
    fn fetch(address_domain: u32, base: StorageBaseAddress) -> Felt252Map<T> {
        Felt252Map { address_domain, base }
    }

    fn get_base_storage_address(self: @Felt252Map<T>) -> (u32, StorageBaseAddress) {
        (*self.address_domain, *self.base)
    }

    fn address_at(self: @Felt252Map<T>, key: felt252) -> felt252 {
        let base_storage_address: felt252 = storage_address_from_base(*self.base).into();

        caculate_storage_address(base_storage_address, key)
    }

    fn read_at(self: @Felt252Map<T>, key: felt252) -> T {
        let base_storage_address: felt252 = storage_address_from_base(*self.base).into();

        let element_address = caculate_storage_address(base_storage_address, key);

        TStore::read(*self.address_domain, storage_base_address_from_felt252(element_address))
            .unwrap_syscall()
    }

    fn write_at(ref self: Felt252Map<T>, key: felt252, value: T) {
        let base_storage_address: felt252 = storage_address_from_base(self.base).into();

        let element_address = caculate_storage_address(base_storage_address, key);

        TStore::write(
            self.address_domain, storage_base_address_from_felt252(element_address), value
        )
            .unwrap_syscall()
    }
}

pub type StorageMap<K, V> = Felt252Map<V>;

pub trait StorageMapTrait<K, V> {
    fn address_at(self: @StorageMap<K, V>, key: K) -> felt252;
    fn read_at(self: @StorageMap<K, V>, key: K) -> V;
    fn write_at(ref self: StorageMap<K, V>, key: K, value: V);
}

impl StorageMapIntoImpl<
    K, V, +Into<K, felt252>, +Drop<K>, +Drop<V>, impl TStore: Store<V>
> of StorageMapTrait<K, V> {
    fn address_at(self: @StorageMap<K, V>, key: K) -> felt252 {
        Felt252MapTrait::address_at(self, key.into())
    }

    fn read_at(self: @StorageMap<K, V>, key: K) -> V {
        Felt252MapTrait::read_at(self, key.into())
    }

    fn write_at(ref self: StorageMap<K, V>, key: K, value: V) {
        Felt252MapTrait::write_at(ref self, key.into(), value)
    }
}

impl StorageMapHashImpl<
    K, V, +Hash<K, HashState>, +Drop<K>, +Drop<V>, impl TStore: Store<V>
> of StorageMapTrait<K, V> {
    fn address_at(self: @StorageMap<K, V>, key: K) -> felt252 {
        Felt252MapTrait::address_at(self, PoseidonTrait::new().update_with(key).finalize())
    }

    fn read_at(self: @StorageMap<K, V>, key: K) -> V {
        Felt252MapTrait::read_at(self, PoseidonTrait::new().update_with(key).finalize())
    }

    fn write_at(ref self: StorageMap<K, V>, key: K, value: V) {
        Felt252MapTrait::write_at(ref self, PoseidonTrait::new().update_with(key).finalize(), value)
    }
}
