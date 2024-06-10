pub mod Math {
    pub fn divide(a: u256, b: u256, rounding_up: bool) -> u256 {
        let mut result = a / b;
        if rounding_up && a % b != 0 {
            result += 1;
        }
        result
    }
}
