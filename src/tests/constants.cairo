use starknet::ContractAddress;

pub fn OWNER() -> ContractAddress {
    'owner'.try_into().unwrap()
}

pub fn ZERO() -> ContractAddress {
    0.try_into().unwrap()
}

pub fn OTHER() -> ContractAddress {
    'other'.try_into().unwrap()
}

pub fn RECIPIENT() -> ContractAddress {
    'recipient'.try_into().unwrap()
} 