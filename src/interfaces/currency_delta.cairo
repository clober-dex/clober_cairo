use starknet::ContractAddress;
use clober_cairo::libraries::i257::i257;

#[starknet::interface]
pub trait ICurrencyDelta<TContractState> {
    fn get_currency_delta(
        self: @TContractState, locker: ContractAddress, currency: ContractAddress,
    ) -> i257;
}
