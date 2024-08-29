#!/bin/bash

# Deployment script for BookManager
# Example: ./deploy_bookmanager.sh ./account.json ./keystore.json 0x1234...5678 0x1234...5678 'BASE_URI' 'CONTRACT_URI'

# Declare the contract and capture the command output
command_output=$(starkli declare ../target/dev/clober_cairo_BookManager.contract_class.json --network=sepolia --compiler-version=2.7.1 --account $1 --keystore $2)

from_string="Class hash declared:"
class_hash="${command_output#*$from_string}"

base_uri=$(echo -n "$5" | xxd -p | tr -d '\n')

contract_uri=$(echo -n "$6" | xxd -p | tr -d '\n')

# Deploy the contract using the extracted class hash
starkli deploy $class_hash $3 $4 0 $base_uri ${#base_uri} 0 $contract_uri ${#contract_uri} --network=sepolia --account $1 --keystore $2
