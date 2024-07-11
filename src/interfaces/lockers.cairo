use starknet::ContractAddress;

#[starknet::interface]
pub trait ILockers<TContractState> {
    fn get_lock(self: @TContractState, i: u128) -> (ContractAddress, ContractAddress);
    fn get_lock_data(self: @TContractState) -> (u128, u128);
}
