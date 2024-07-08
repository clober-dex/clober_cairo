use starknet::{SyscallResultTrait, ContractAddress, syscalls};

#[derive(Copy, Drop, Hash)]
pub struct Hooks {
    address: ContractAddress,
}
