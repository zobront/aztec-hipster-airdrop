mod types;

contract HipsterAirdrop {
    use dep::aztec::{
        state_vars::{
            public_state::PublicState,
        },
        types::{
            address::AztecAddress,
            type_serialization::field_serialization::{
                FIELD_SERIALIZED_LEN, FieldSerializationMethods
            };
        },
        context::Context,
        note::{
            note_getter_options::NoteGetterOptions,
            note_hash::{compute_inner_hash, compute_siloed_hash, compute_unique_hash},
            note_header::NoteHeader,
            note_interface::NoteInterface,
            utils::compute_unique_siloed_note_hash,
        },
        constants_gen::NOTE_HASH_TREE_HEIGHT,
        oracle::{
            get_membership_witness::{
                get_membership_witness,
                MembershipWitness,
            },
        },
    };
    use dep::safe_math::SafeU120;
    use crate::types::{
        balances_map::BalancesMap,
        users::{UserNote, USER_NOTE_LEN, UserNoteMethods}
    };

    struct Storage {
        game_address: PublicState<AztecAddress, FIELD_SERIALIZED_LEN>,
        balances: BalancesMap,
    }

    impl Storage {
        fn init(context: Context) -> Self {
            Storage {
                game_address: PrivateState::new(context, 1, FieldSerializationMethods)
                balances: BalancesMap::new(context, 2);
            }
        }
    }

    #[aztec(public)]
    fn constructor(_app_address: Field) {
        storage.app_address.write(_app_address);
    }

    #[aztec(private)]
    fn claimAirdrop(owner: AztecAddress, randomness: Field, signup_block_number: Field, last_block_number: Field) {
        // get block header from specified block number
        let block_header = context.get_block_header(signup_block_number);

        // compute the note commitment
        let note: UserNote = UserNote::new_with_randomness_and_header(owner.address, randomness, storage.game_address.read(), 1);
        let note_commitment = compute_unique_siloed_note_hash(UserNoteMethods, note);

        // get the membership witness of the note in the note hash tree
        let note_hash_tree_id = 2; // 2 = private state tree
        let witness: MembershipWitness<NOTE_HASH_TREE_HEIGHT, NOTE_HASH_TREE_HEIGHT + 1> =
            get_membership_witness(signup_block_number, note_hash_tree_id, note_commitment);

        // prove that the commitment is in the note hash tree
        assert(
            block_header.note_hash_tree_root ==
            dep::std::merkle::compute_merkle_root(note_commitment, witness.index, witness.path),
            "note proof failed"
        );


        //
        let last_block_header = context.get_block_header(last_block_number);

        let block_witness = MembershipWitness<NOTE_HASH_TREE_HEIGHT, NOTE_HASH_TREE_HEIGHT + 1> =
            get_membership_witness(last_block_number, 5, last_block_header.block_hash());

        assert(
            // maybe replace this with context.block_header.archive_note()
            last_block_header.archive_root ==
            dep::std::merkle::compute_merkle_rootlast_block_header.block_hash() block_witness.index, block_witness.path
        );

        storage.balances.at(owner.address).add(SafeU120::new(last_block_number - signup_block_number));
    }
}
