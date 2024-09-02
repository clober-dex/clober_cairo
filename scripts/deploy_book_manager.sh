#!/bin/bash

# Deployment script for BookManager
# Example: ./deploy_book_manager.sh --network dev 0x1234...5678 0x1234...5678 'BASE_URI' 'CONTRACT_URI'

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
if [[ "${#args[@]}" -ne 4 ]]; then
    echo "Error: Arguments missing. Usage: ./deploy_book_manager.sh --network dev 0x1234...5678 0x1234...5678 'BASE_URI' 'CONTRACT_URI'"
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
command_output=$(starkli declare ./target/dev/clober_cairo_BookManager.contract_class.json --rpc=$rpc --compiler-version=2.7.1 --account $account $key_command)

from_string="Class hash declared:"
class_hash="${command_output#*$from_string}"

echo "$class_hash"

parse_string() {
    local input_string="$1"

    # All comments MUST be English
    # Convert the string to hex
    local hex_string=$(echo -n "$input_string" | xxd -p | tr -d '\n')

    # Divide the string into 31-byte chunks
    local chunk_size=62  # 31 bytes is 62 hex characters (31 bytes)
    local chunks=()
    while [ -n "$hex_string" ]; do
        local chunk="${hex_string:0:$chunk_size}"
        chunks+=("$chunk")
        hex_string="${hex_string:$chunk_size}"
    done

    # Number of 31-byte chunks - 1
    local chunk_count_minus_one=$((${#chunks[@]} - 1))

    # Calculate the length of the last chunk
    local last_chunk="${chunks[${#chunks[@]}-1]}"
    local last_chunk_length=$((${#last_chunk} / 2))  # Convert the length of the hex string to bytes by dividing by 2

    # Output the result as a single line (0x format)
    local result="0x$chunk_count_minus_one"
    for chunk in "${chunks[@]}"; do
        result+=" 0x$chunk"
    done
    result+=" 0x$last_chunk_length"

    echo "$result"
}

base_uri=$(parse_string "${args[2]}")

contract_uri=$(parse_string "${args[3]}")

# Deploy the contract using the extracted class hash
starkli deploy $class_hash ${args[0]} ${args[1]} $base_uri $contract_uri --rpc=$rpc --account $account $key_command
