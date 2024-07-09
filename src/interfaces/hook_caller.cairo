use starknet::ContractAddress;

#[starknet::interface]
pub trait IHookCaller<TContractState> {
    fn get_current_hook(self: @TContractState) -> ContractAddress;
    fn get_hook(self: @TContractState, i: u128) -> ContractAddress;
}
