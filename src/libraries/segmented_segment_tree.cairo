pub mod SegmentedSegmentTree {
    use clober_cairo::libraries::packed_felt252::get_u62;
    use clober_cairo::libraries::packed_felt252::sum_u62;
    use clober_cairo::libraries::packed_felt252::update_62;

    #[derive(Copy, Drop, Serde, Debug)]
    struct LayerIndex {
        pub group: u256,
        pub node: u8
    }

    //    const R: u256 = 2; // There are `2` root node groups
    //    const C: u256 = 4; // There are `4` children (each child is a node group of its own) for
    //    each node
    const L: u8 = 4; // There are `4` layers of node groups
    const P: u8 = 4; // uint256 / uint64 = `4`
    const P_M: u256 = 3; // % 4 = & `3`
    const P_P: u256 = 2; // 2 ** `2` = 4
    const N_P: u256 = 4; // C * P = 2 ** `4`
    const MAX_NODES: u256 = 0x8000; // (R * P) * ((C * P) ** (L - 1)) = `32768`
    const MAX_NODES_P_MINUS_ONE: u256 = 14; // MAX_NODES / R = 2 ** `14`

    pub fn get(ref layers: Felt252Dict<felt252>, index: u256) -> u64 {
        assert(index < MAX_NODES, 'INDEX_ERROR');
        let key: felt252 = ((L.into() - 1) * MAX_NODES + index / P.into()).try_into().unwrap();
        get_u62(layers[key], (index & P_M).try_into().unwrap())
    }

    pub fn total(ref layers: Felt252Dict<felt252>) -> u256 {
        sum_u62(layers[0], 0, 4) + sum_u62(layers[1], 0, 4)
    }

    pub fn _get_layer_indices(index: u256) -> Array<LayerIndex> {
        let mut indices: Array<LayerIndex> = ArrayTrait::new();
        let mut shifter: u256 = MAX_NODES / 2;
        let mut l = 0;
        while l < L {
            indices
                .append(
                    LayerIndex {
                        group: index / shifter,
                        node: ((index / (shifter / P.into())) & P_M).try_into().unwrap()
                    }
                );
            shifter /= 16;
            l += 1;
        };
        indices
    }

    pub fn query(ref layers: Felt252Dict<felt252>, left: u256, right: u256) -> u256 {
        if left == right {
            return 0;
        }
        assert(left < right, 'INDEX_ERROR');
        assert(right <= MAX_NODES, 'INDEX_ERROR');

        let left_indices: Array<LayerIndex> = _get_layer_indices(left);
        let right_indices: Array<LayerIndex> = _get_layer_indices(right);
        let mut ret: u256 = 0;
        let mut deficit: u256 = 0;

        let mut left_node_index: u8 = 0;
        let mut right_node_index: u8 = 0;
        let mut l: u256 = (L - 1).into();

        while l >= 0 {
            let left_index: LayerIndex = *left_indices.at(l.try_into().unwrap());
            let right_index: LayerIndex = *right_indices.at(l.try_into().unwrap());
            left_node_index += left_index.node;
            right_node_index += right_index.node;

            if right_index.group == left_index.group {
                let key: felt252 = (l * MAX_NODES + left_index.group).try_into().unwrap();
                ret += sum_u62(layers[key], left_node_index, right_node_index);
                break;
            }

            if right_index.group - left_index.group < 4 {
                let key: felt252 = (l * MAX_NODES + left_index.group).try_into().unwrap();
                ret += sum_u62(layers[key], left_node_index, P);

                let key: felt252 = (l * MAX_NODES + right_index.group).try_into().unwrap();
                ret += sum_u62(layers[key], 0, right_node_index);
                let mut group = left_index.group + 1;
                while group < right_index.group {
                    let key: felt252 = (l * MAX_NODES + group).try_into().unwrap();
                    ret += sum_u62(layers[key], 0, P);
                    group += 1;
                };
                break;
            }

            if left_index.group % 4 == 0 {
                let key: felt252 = (l * MAX_NODES + left_index.group).try_into().unwrap();
                deficit += sum_u62(layers[key], 0, left_node_index);
                left_node_index = 0;
            } else if left_index.group % 4 == 1 {
                let key: felt252 = (l * MAX_NODES + left_index.group).try_into().unwrap();
                deficit += sum_u62(layers[key - 1], 0, P);
                deficit += sum_u62(layers[key], 0, left_node_index);
                left_node_index = 0;
            } else if left_index.group % 4 == 2 {
                let key: felt252 = (l * MAX_NODES + left_index.group).try_into().unwrap();
                ret += sum_u62(layers[key], left_node_index, P);
                ret += sum_u62(layers[key + 1], 0, P);
                left_node_index = 1;
            } else {
                let key: felt252 = (l * MAX_NODES + left_index.group).try_into().unwrap();
                ret += sum_u62(layers[key], left_node_index, P);
                left_node_index = 1;
            }

            if right_index.group % 4 == 0 {
                let key: felt252 = (l * MAX_NODES + right_index.group).try_into().unwrap();
                ret += sum_u62(layers[key], 0, right_node_index);
                right_node_index = 0;
            } else if right_index.group % 4 == 1 {
                let key: felt252 = (l * MAX_NODES + right_index.group).try_into().unwrap();
                ret += sum_u62(layers[key - 1], 0, P);
                ret += sum_u62(layers[key], 0, right_node_index);
                right_node_index = 0;
            } else if right_index.group % 4 == 2 {
                let key: felt252 = (l * MAX_NODES + right_index.group).try_into().unwrap();
                deficit += sum_u62(layers[key], right_node_index, P);
                deficit += sum_u62(layers[key + 1], 0, P);
                right_node_index = 1;
            } else {
                let key: felt252 = (l * MAX_NODES + right_index.group).try_into().unwrap();
                deficit += sum_u62(layers[key], right_node_index, P);
                right_node_index = 1;
            }

            l -= 1;
        };
        ret - deficit
    }

    pub fn update(ref layers: Felt252Dict<felt252>, index: u256, value: u64) {
        assert(index < MAX_NODES, 'INDEX_ERROR');
        let indices: Array<LayerIndex> = _get_layer_indices(index);
        let bottom_index: LayerIndex = *indices.at((L - 1).try_into().unwrap()).try_into().unwrap();
        let key: felt252 = (MAX_NODES * (L.into() - 1) + bottom_index.group).try_into().unwrap();
        let replaced = get_u62(layers[key], bottom_index.node);
        let mut l: u8 = 0;
        if replaced >= value {
            let diff = replaced - value;
            while l < L {
                let layer_index: LayerIndex = *indices.at(l.into());
                let key: felt252 = (l.into() * MAX_NODES + layer_index.group).try_into().unwrap();
                let node: felt252 = layers[key];
                layers
                    .insert(
                        key,
                        update_62(node, layer_index.node, get_u62(node, layer_index.node) - diff)
                    );
                l += 1;
            }
        } else {
            let diff = value - replaced;
            while l < L {
                let layer_index: LayerIndex = *indices.at(l.into());
                let key: felt252 = (l.into() * MAX_NODES + layer_index.group).try_into().unwrap();
                let node: felt252 = layers[key];
                layers
                    .insert(
                        key,
                        update_62(node, layer_index.node, get_u62(node, layer_index.node) + diff)
                    );
                l += 1;
            }
        }
    }
}


#[cfg(test)]
mod tests {
    use super::SegmentedSegmentTree;

    fn _init(ref layers: Felt252Dict<felt252>) {
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
            SegmentedSegmentTree::update(ref layers, i.into(), *values.at(i));
            i += 1;
        }
    }

    #[test]
    fn test_get() {
        let mut layers: Felt252Dict<felt252> = Default::default();
        _init(ref layers);
        let mut i: u256 = 0;
        while i < 5 {
            assert_eq!(
                SegmentedSegmentTree::query(ref layers, i, i + 1),
                SegmentedSegmentTree::get(ref layers, i).into()
            );
            i += 1;
        }
    }

    #[test]
    fn test_total() {
        let mut layers: Felt252Dict<felt252> = Default::default();
        _init(ref layers);
        let mut length = 100;
        let total = SegmentedSegmentTree::total(ref layers);
        let query = SegmentedSegmentTree::query(ref layers, 0, length);
        assert_eq!(query, total);
        let mut sum = 0;
        while length > 0 {
            sum += SegmentedSegmentTree::get(ref layers, length - 1).into();
            length -= 1;
        };
        assert_eq!(query, sum);
    }

    #[test]
    fn test_query() {
        let mut layers: Felt252Dict<felt252> = Default::default();
        _init(ref layers);
        let mut length = 30;
        let query = SegmentedSegmentTree::query(ref layers, 10, length);
        let mut sum = 0;
        while length > 10 {
            sum += SegmentedSegmentTree::get(ref layers, length - 1).into();
            length -= 1;
        };
        assert_eq!(query, sum);
    }

    #[test]
    fn test_update() {
        let mut layers: Felt252Dict<felt252> = Default::default();
        _init(ref layers);
        let mut i: u256 = 0;
        while i < 20 {
            SegmentedSegmentTree::update(ref layers, i, 0x654);
            let value = SegmentedSegmentTree::get(ref layers, i);
            assert_eq!(value, 0x654);
            i += 1;
        }
    }
}
