use starknet::{ContractAddress, contract_address_const};
use openzeppelin_token::erc20::interface::IERC20Dispatcher;
use openzeppelin_testing as utils;
use openzeppelin_utils::serde::SerializedAppend;

pub fn BASE_URI() -> ByteArray {
    "base_uri"
}
pub fn CONTRACT_URI() -> ByteArray {
    "contract_uri"
}

fn BASE_NAME() -> ByteArray {
    "Base"
}
fn BASE_SYMBOL() -> ByteArray {
    "BASE"
}
fn QUOTE_NAME() -> ByteArray {
    "Quote"
}
fn QUOTE_SYMBOL() -> ByteArray {
    "QUOTE"
}

pub fn deploy_token_pairs(
    base_supply: u256, quote_supply: u256, recipient: ContractAddress, owner: ContractAddress,
) -> (IERC20Dispatcher, IERC20Dispatcher) {
    let contract = utils::declare_class("ERC20Upgradeable");

    let mut base_calldata = array![];
    base_calldata.append_serde(BASE_NAME());
    base_calldata.append_serde(BASE_SYMBOL());
    base_calldata.append_serde(base_supply);
    base_calldata.append_serde(recipient);
    base_calldata.append_serde(owner);
    let base_address = contract_address_const::<'base'>();
    utils::deploy_at(contract, base_address, base_calldata);

    let mut quote_calldata = array![];
    quote_calldata.append_serde(QUOTE_NAME());
    quote_calldata.append_serde(QUOTE_SYMBOL());
    quote_calldata.append_serde(quote_supply);
    quote_calldata.append_serde(recipient);
    quote_calldata.append_serde(owner);
    let quote_address = contract_address_const::<'quote'>();
    utils::deploy_at(contract, quote_address, quote_calldata);

    (
        IERC20Dispatcher { contract_address: base_address },
        IERC20Dispatcher { contract_address: quote_address },
    )
}

pub fn deploy_erc20_at(
    address: ContractAddress,
    name: ByteArray,
    symbol: ByteArray,
    fixed_supply: u256,
    recipient: ContractAddress,
    owner: ContractAddress,
) -> IERC20Dispatcher {
    let mut calldata = array![];
    calldata.append_serde(name);
    calldata.append_serde(symbol);
    calldata.append_serde(fixed_supply);
    calldata.append_serde(recipient);
    calldata.append_serde(owner);

    utils::declare_and_deploy_at("ERC20Upgradeable", address, calldata);
    IERC20Dispatcher { contract_address: address }
}
