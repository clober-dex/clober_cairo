use starknet::ContractAddress;

#[starknet::interface]
pub trait ILocker<TContractState> {
    fn lock_acquired(
        ref self: TContractState, lock_caller: ContractAddress, data: Span<felt252>,
    ) -> Span<felt252>;
}
