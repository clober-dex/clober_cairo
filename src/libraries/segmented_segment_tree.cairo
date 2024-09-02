use clober_cairo::libraries::storage_map::{Felt252Map, Felt252MapTrait};
use clober_cairo::utils::packed_felt252::get_u62;
use clober_cairo::utils::packed_felt252::sum_u62;
use clober_cairo::utils::packed_felt252::update_62;

//    const R: u256 = 2; // There are `2` root node groups
//    const C: u256 = 4; // There are `4` children (each child is a node group of its own) for
//    each node
const L: u32 = 4; // There are `4` layers of node groups
const P: u8 = 4; // uint256 / uint64 = `4`
const P_M: u64 = 3; // % 4 = & `3`
const P_P: u64 = 2; // 2 ** `2` = 4
const N_P: u64 = 4; // C * P = 2 ** `4`
const MAX_NODES: u64 = 0x8000; // (R * P) * ((C * P) ** (L - 1)) = `32768`
const MAX_NODES_P_MINUS_ONE: u64 = 14; // MAX_NODES / R = 2 ** `14`


pub type SegmentedSegmentTree = Felt252Map<felt252>;

#[derive(Copy, Drop)]
struct LayerIndex {
    pub group: u64,
    pub node: u8
}

#[generate_trait]
pub impl SegmentedSegmentTreeImpl of SegmentedSegmentTreeTrait {
    fn get_node(self: @SegmentedSegmentTree, index: u64) -> u64 {
        assert(index < MAX_NODES, 'INDEX_ERROR');
        let key: felt252 = ((L.into() - 1) * MAX_NODES + index / P.into()).into();
        get_u62(self.read_at(key), (index & P_M).try_into().unwrap())
    }

    fn total(self: @SegmentedSegmentTree) -> u64 {
        sum_u62(self.read_at(0), 0, P) + sum_u62(self.read_at(1), 0, P.into())
    }

    fn query(self: @SegmentedSegmentTree, left: u64, right: u64) -> u64 {
        if left == right {
            return 0;
        }
        assert(left < right, 'INDEX_ERROR');
        assert(right <= MAX_NODES, 'INDEX_ERROR');

        let left_indices: Array<LayerIndex> = Self::_get_layer_indices(left);
        let right_indices: Array<LayerIndex> = Self::_get_layer_indices(right);
        let mut ret: u256 = 0;
        let mut deficit: u256 = 0;

        let mut left_node_index: u8 = 0;
        let mut right_node_index: u8 = 0;
        let mut l: u32 = (L - 1).into();

        while l >= 0 {
            let left_index: LayerIndex = *left_indices.at(l);
            let right_index: LayerIndex = *right_indices.at(l);
            left_node_index += left_index.node;
            right_node_index += right_index.node;

            if right_index.group == left_index.group {
                let key: felt252 = (l.into() * MAX_NODES + left_index.group).into();
                ret += sum_u62(self.read_at(key), left_node_index, right_node_index).into();
                break;
            }

            if right_index.group - left_index.group < 4 {
                let key: felt252 = (l.into() * MAX_NODES + left_index.group).into();
                ret += sum_u62(self.read_at(key), left_node_index, P).into();

                let key: felt252 = (l.into() * MAX_NODES + right_index.group).into();
                ret += sum_u62(self.read_at(key), 0, right_node_index).into();
                let mut group = left_index.group + 1;
                while group < right_index.group {
                    let key: felt252 = (l.into() * MAX_NODES + group).into();
                    ret += sum_u62(self.read_at(key), 0, P).into();
                    group += 1;
                };
                break;
            }

            if left_index.group % 4 == 0 {
                let key: felt252 = (l.into() * MAX_NODES + left_index.group).into();
                deficit += sum_u62(self.read_at(key), 0, left_node_index).into();
                left_node_index = 0;
            } else if left_index.group % 4 == 1 {
                let key: felt252 = (l.into() * MAX_NODES + left_index.group).into();
                deficit += sum_u62(self.read_at(key - 1), 0, P).into();
                deficit += sum_u62(self.read_at(key), 0, left_node_index).into();
                left_node_index = 0;
            } else if left_index.group % 4 == 2 {
                let key: felt252 = (l.into() * MAX_NODES + left_index.group).into();
                ret += sum_u62(self.read_at(key), left_node_index, P).into();
                ret += sum_u62(self.read_at(key + 1), 0, P).into();
                left_node_index = 1;
            } else {
                let key: felt252 = (l.into() * MAX_NODES + left_index.group).into();
                ret += sum_u62(self.read_at(key), left_node_index, P).into();
                left_node_index = 1;
            }

            if right_index.group % 4 == 0 {
                let key: felt252 = (l.into() * MAX_NODES + right_index.group).into();
                ret += sum_u62(self.read_at(key), 0, right_node_index).into();
                right_node_index = 0;
            } else if right_index.group % 4 == 1 {
                let key: felt252 = (l.into() * MAX_NODES + right_index.group).into();
                ret += sum_u62(self.read_at(key - 1), 0, P).into();
                ret += sum_u62(self.read_at(key), 0, right_node_index).into();
                right_node_index = 0;
            } else if right_index.group % 4 == 2 {
                let key: felt252 = (l.into() * MAX_NODES + right_index.group).into();
                deficit += sum_u62(self.read_at(key), right_node_index, P).into();
                deficit += sum_u62(self.read_at(key + 1), 0, P).into();
                right_node_index = 1;
            } else {
                let key: felt252 = (l.into() * MAX_NODES + right_index.group).into();
                deficit += sum_u62(self.read_at(key), right_node_index, P).into();
                right_node_index = 1;
            }

            l -= 1;
        };
        (ret - deficit).try_into().unwrap()
    }

    fn _get_layer_indices(index: u64) -> Array<LayerIndex> {
        let mut indices: Array<LayerIndex> = ArrayTrait::new();
        let mut shifter: u64 = MAX_NODES / 2;
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

    fn update(ref self: SegmentedSegmentTree, index: u64, value: u64) {
        assert(index < MAX_NODES, 'INDEX_ERROR');
        let indices: Array<LayerIndex> = Self::_get_layer_indices(index);
        let bottom_index: LayerIndex = *indices.at(L - 1);
        let key: felt252 = (MAX_NODES * (L.into() - 1) + bottom_index.group).into();
        let replaced = get_u62(self.read_at(key), bottom_index.node);
        let mut l: u32 = 0;
        if replaced >= value {
            let diff = replaced - value;
            while l < L {
                let layer_index: LayerIndex = *indices.at(l.into());
                let key: felt252 = (l.into() * MAX_NODES + layer_index.group).into();
                let node: felt252 = self.read_at(key);
                self
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
                let key: felt252 = (l.into() * MAX_NODES + layer_index.group).into();
                let node: felt252 = self.read_at(key);
                self
                    .write_at(
                        key,
                        update_62(node, layer_index.node, get_u62(node, layer_index.node) + diff)
                    );
                l += 1;
            }
        }
    }
}
