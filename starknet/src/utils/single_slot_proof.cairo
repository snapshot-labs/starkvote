#[starknet::contract]
mod SingleSlotProof {
    use starknet::{ContractAddress, EthAddress};
    use sx::external::herodotus::{
        ProofElement, BinarySearchTree, ITimestampRemappersDispatcher,
        ITimestampRemappersDispatcherTrait, IEVMFactsRegistryDispatcher,
        IEVMFactsRegistryDispatcherTrait
    };
    use sx::utils::math;
    use sx::utils::endian::ByteReverse;

    #[storage]
    struct Storage {
        _timestamp_remappers: ContractAddress,
        _facts_registry: ContractAddress
    }

    #[internal]
    fn initializer(
        ref self: ContractState,
        timestamp_remappers: ContractAddress,
        facts_registry: ContractAddress
    ) {
        self._timestamp_remappers.write(timestamp_remappers);
        self._facts_registry.write(facts_registry);
    }

    #[internal]
    fn get_mapping_slot_key(mapping_key: u256, slot_index: u256) -> u256 {
        keccak::keccak_u256s_be_inputs(array![mapping_key, slot_index].span()).byte_reverse()
    }

    #[internal]
    fn get_storage_slot(
        self: @ContractState,
        timestamp: u32,
        l1_contract_address: EthAddress,
        slot_index: u256,
        mapping_key: u256,
        serialized_tree: Span<felt252>
    ) -> u256 {
        let mut serialized_tree = serialized_tree;
        let tree = Serde::<BinarySearchTree>::deserialize(ref serialized_tree).unwrap();

        // Map timestamp to closest L1 block number that occured before the timestamp.
        let l1_block_number = ITimestampRemappersDispatcher {
            contract_address: self._timestamp_remappers.read()
        }
            .get_closest_l1_block_number(tree, timestamp.into())
            .unwrap();

        // Computes the key of the EVM storage slot from the index of the mapping in storage and the mapping key.
        let slot_key = get_mapping_slot_key(slot_index, mapping_key);

        // Returns the value of the storage slot of account: `l1_contract_address` at key: `slot_key` and block number: `l1_block_number`.
        let slot_value = IEVMFactsRegistryDispatcher {
            contract_address: self._facts_registry.read()
        }
            .get_slot_value(l1_contract_address.into(), l1_block_number, slot_key);

        assert(slot_value.is_non_zero(), 'Slot is zero');

        slot_value
    }
}

#[cfg(test)]
mod tests {
    use super::SingleSlotProof;

    #[test]
    #[available_gas(10000000)]
    fn get_mapping_slot_key() {
        assert(
            SingleSlotProof::get_mapping_slot_key(
                0x0_u256, 0x0_u256
            ) == u256 {
                low: 0x2b36e491b30a40b2405849e597ba5fb5, high: 0xad3228b676f7d3cd4284a5443f17f196
            }, 'Incorrect slot key'
        );
        assert(
            SingleSlotProof::get_mapping_slot_key(
                0x1_u256, 0x0_u256
            ) == u256 {
                low: 0x10426056ef8ca54750cb9bb552a59e7d, high: 0xada5013122d395ba3c54772283fb069b
            }, 'Incorrect slot key'
        );
        assert(
            SingleSlotProof::get_mapping_slot_key(
                0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045_u256, 0x1_u256
            ) == u256 {
                low: 0xad9172e102b3af1e07a10cc29003beb2, high: 0xb931be0b3d1fb06daf0d92e2b8dfe49e
            }, 'Incorrect slot key'
        );
    }
}

