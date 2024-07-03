#[starknet::contract]
pub mod BookManager {
    #[storage]
    struct Storage {
        foo: u128,
    }
}
