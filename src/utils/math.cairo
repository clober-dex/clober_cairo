pub fn divide(a: felt252, b: felt252, rounding_up: bool) -> felt252 {
    let mut result = a / b;
    if rounding_up && a % b != 0 {
        result += 1;
    }
    result
}
