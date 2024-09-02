#!/bin/bash

# Deployment script for Controller
# Example: ./deploy_controller.sh --network dev 0x1234...5678

# Parse the network flag and remove it from the arguments
network_provided=false
network=""
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --network)
            network_flag=true
            network="$2"
            shift 2
            ;;
        *)
            args+=("$1")
            shift
            ;;
    esac
done

# Check if the network flag is provided
if ! $network_flag; then
    echo "Error: --network option is required (dev, prod)"
    exit 1
fi

# Check if the number of arguments is correct
if [[ "${#args[@]}" -ne 1 ]]; then
    echo "Error: Arguments missing. Usage: ./deploy_controller.sh --network dev 0x1234...5678"
    exit 1
fi

# Load .env
if [ -f .env ]; then
    source .env
else
    echo ".env file not found!"
    exit 1
fi

# Extract the arguments
case $network in
    dev)
        rpc=$DEV_RPC
        key_command="--private-key $DEV_PRIVATE_KEY"
        account=$DEV_ACCOUNT
        ;;
    prod)
        rpc=$PROD_RPC
        key_command="--keystore $PROD_KEYSTORE"
        account=$PROD_ACCOUNT
        ;;
    *)
        echo "Error: Invalid network. Available options: dev, prod"
        exit 1
        ;;
esac

# Build first
scarb build

# Declare the contract and capture the command output
command_output=$(starkli declare ./target/dev/clober_cairo_Controller.contract_class.json --rpc=$rpc --compiler-version=2.7.1 --account $account $key_command)

from_string="Class hash declared:"
class_hash="${command_output#*$from_string}"

# Deploy the contract using the extracted class hash
starkli deploy $class_hash ${args[0]} --rpc=$rpc --account $account $key_command
