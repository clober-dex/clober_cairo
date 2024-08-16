use starknet::ContractAddress;
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin_presets::erc20::ERC20Upgradeable;
use openzeppelin_testing as utils;
use openzeppelin_utils::serde::SerializedAppend;

pub fn deploy_erc20(
    name: ByteArray,
    symbol: ByteArray,
    fixed_supply: u256,
    recipient: ContractAddress,
    owner: ContractAddress
) -> IERC20Dispatcher {
    let mut calldata = array![];
    calldata.append_serde(name);
    calldata.append_serde(symbol);
    calldata.append_serde(fixed_supply);
    calldata.append_serde(recipient);
    calldata.append_serde(owner);

    let address = utils::declare_and_deploy("BookManager", calldata);
    IERC20Dispatcher { contract_address: address }
}
