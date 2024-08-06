pub mod SegmentedSegmentTree {
    use clober_cairo::libraries::storage_map::{Felt252Map, Felt252MapTrait};
    use clober_cairo::utils::packed_felt252::get_u62;
    use clober_cairo::utils::packed_felt252::sum_u62;
    use clober_cairo::utils::packed_felt252::update_62;

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

    pub fn get(ref layers: Felt252Map<felt252>, index: u256) -> u64 {
        assert(index < MAX_NODES, 'INDEX_ERROR');
        let key: felt252 = ((L.into() - 1) * MAX_NODES + index / P.into()).try_into().unwrap();
        get_u62(layers.read_at(key), (index & P_M).try_into().unwrap())
    }

    pub fn total(ref layers: Felt252Map<felt252>) -> u256 {
        sum_u62(layers.read_at(0), 0, P.into()) + sum_u62(layers.read_at(1), 0, P.into())
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

    pub fn query(ref layers: Felt252Map<felt252>, left: u256, right: u256) -> u256 {
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
                ret += sum_u62(layers.read_at(key), left_node_index, right_node_index);
                break;
            }

            if right_index.group - left_index.group < 4 {
                let key: felt252 = (l * MAX_NODES + left_index.group).try_into().unwrap();
                ret += sum_u62(layers.read_at(key), left_node_index, P);

                let key: felt252 = (l * MAX_NODES + right_index.group).try_into().unwrap();
                ret += sum_u62(layers.read_at(key), 0, right_node_index);
                let mut group = left_index.group + 1;
                while group < right_index.group {
                    let key: felt252 = (l * MAX_NODES + group).try_into().unwrap();
                    ret += sum_u62(layers.read_at(key), 0, P);
                    group += 1;
                };
                break;
            }

            if left_index.group % 4 == 0 {
                let key: felt252 = (l * MAX_NODES + left_index.group).try_into().unwrap();
                deficit += sum_u62(layers.read_at(key), 0, left_node_index);
                left_node_index = 0;
            } else if left_index.group % 4 == 1 {
                let key: felt252 = (l * MAX_NODES + left_index.group).try_into().unwrap();
                deficit += sum_u62(layers.read_at(key - 1), 0, P);
                deficit += sum_u62(layers.read_at(key), 0, left_node_index);
                left_node_index = 0;
            } else if left_index.group % 4 == 2 {
                let key: felt252 = (l * MAX_NODES + left_index.group).try_into().unwrap();
                ret += sum_u62(layers.read_at(key), left_node_index, P);
                ret += sum_u62(layers.read_at(key + 1), 0, P);
                left_node_index = 1;
            } else {
                let key: felt252 = (l * MAX_NODES + left_index.group).try_into().unwrap();
                ret += sum_u62(layers.read_at(key), left_node_index, P);
                left_node_index = 1;
            }

            if right_index.group % 4 == 0 {
                let key: felt252 = (l * MAX_NODES + right_index.group).try_into().unwrap();
                ret += sum_u62(layers.read_at(key), 0, right_node_index);
                right_node_index = 0;
            } else if right_index.group % 4 == 1 {
                let key: felt252 = (l * MAX_NODES + right_index.group).try_into().unwrap();
                ret += sum_u62(layers.read_at(key - 1), 0, P);
                ret += sum_u62(layers.read_at(key), 0, right_node_index);
                right_node_index = 0;
            } else if right_index.group % 4 == 2 {
                let key: felt252 = (l * MAX_NODES + right_index.group).try_into().unwrap();
                deficit += sum_u62(layers.read_at(key), right_node_index, P);
                deficit += sum_u62(layers.read_at(key + 1), 0, P);
                right_node_index = 1;
            } else {
                let key: felt252 = (l * MAX_NODES + right_index.group).try_into().unwrap();
                deficit += sum_u62(layers.read_at(key), right_node_index, P);
                right_node_index = 1;
            }

            l -= 1;
        };
        ret - deficit
    }

    pub fn update(ref layers: Felt252Map<felt252>, index: u256, value: u64) {
        assert(index < MAX_NODES, 'INDEX_ERROR');
        let indices: Array<LayerIndex> = _get_layer_indices(index);
        let bottom_index: LayerIndex = *indices.at((L - 1).try_into().unwrap()).try_into().unwrap();
        let key: felt252 = (MAX_NODES * (L.into() - 1) + bottom_index.group).try_into().unwrap();
        let replaced = get_u62(layers.read_at(key), bottom_index.node);
        let mut l: u8 = 0;
        if replaced >= value {
            let diff = replaced - value;
            while l < L {
                let layer_index: LayerIndex = *indices.at(l.into());
                let key: felt252 = (l.into() * MAX_NODES + layer_index.group).try_into().unwrap();
                let node: felt252 = layers.read_at(key);
                layers
                    .write_at(
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
                let node: felt252 = layers.read_at(key);
                layers
                    .write_at(
                        key,
                        update_62(node, layer_index.node, get_u62(node, layer_index.node) + diff)
                    );
                l += 1;
            }
        }
    }
}
