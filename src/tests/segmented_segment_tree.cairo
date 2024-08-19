use clober_cairo::libraries::segmented_segment_tree::{
    SegmentedSegmentTree, SegmentedSegmentTreeTrait
};
use clober_cairo::libraries::storage_map::{Felt252Map, Felt252MapTrait};
use starknet::storage_access::storage_base_address_from_felt252;

fn _init(ref tree: SegmentedSegmentTree) {
    let values = array![
        392516968262,
        685254941374,
        40417999639,
        812870557034,
        930570865270,
        455808674244,
        681001210935,
        557296672987,
        478511137195,
        167689665323,
        43488187570,
        657454673901,
        41984994814,
        824022822085,
        943720598638,
        871292947052,
        240514048857,
        191219308611,
        732967950847,
        166804184333,
        556644096766,
        751442240749,
        167449282488,
        258030254650,
        481961736314,
        338311247505,
        294729518953,
        307224312474,
        342617669319,
        1671683738,
        25888719350,
        919540635153,
        909675123707,
        281043799806,
        132731742649,
        61144520382,
        625494188858,
        822897015689,
        456789377365,
        890884549488,
        57429745012,
        367522674167,
        790157236238
    ];

    let length = values.len();
    let mut i = 0;

    while i < length {
        tree.update(i.into(), *values.at(i));
        i += 1;
    }
}

#[test]
fn test_get() {
    let mut tree = Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654321));
    _init(ref tree);
    let mut i: u64 = 0;
    while i < 5 {
        assert_eq!(tree.query(i, i + 1), tree.get_node(i).into());
        i += 1;
    }
}

#[test]
fn test_total() {
    let mut tree = Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654321));
    _init(ref tree);
    let mut length = 100;
    let total = tree.total();
    let query = tree.query(0, length);
    assert_eq!(query, total);
    let mut sum = 0;
    while length > 0 {
        sum += tree.get_node(length - 1).into();
        length -= 1;
    };
    assert_eq!(query, sum);
}

#[test]
fn test_query() {
    let mut tree = Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654321));
    _init(ref tree);
    let mut length = 30;
    let query = tree.query(10, length);
    let mut sum = 0;
    while length > 10 {
        sum += tree.get_node(length - 1).into();
        length -= 1;
    };
    assert_eq!(query, sum);
}

#[test]
fn test_update() {
    let mut tree = Felt252MapTrait::fetch(0, storage_base_address_from_felt252(0x87654321));
    _init(ref tree);
    let mut i: u64 = 0;
    while i < 20 {
        tree.update(i, 0x654);
        let value = tree.get_node(i);
        assert_eq!(value, 0x654);
        i += 1;
    }
}
