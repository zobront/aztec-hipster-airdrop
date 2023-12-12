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
        app_contract: ImmutableSingleton<AztecAddress, FIELD_SERIALIZED_LEN>,
        balances: BalancesMap,
    }

    impl Storage {
        fn init(context: Context) -> Self {
            Storage {
                app_contract: ImmutableSingleton::new(context, 1, FieldSerializationMethods),
                balances: BalancesMap::new(context, 2);
            }
        }
    }

    #[aztec(public)]
    fn constructor(addr: AztecAddress) {
        storage.app_contract.initialize(addr);
    }

    #[aztec(private)]
    fn claimAirdrop(owner: AztecAddress, randomness: Field, signup_block_number: Field, last_block_number: Field) {

        ////////////////////////////////////////////
        // STEP 1: VALIDATE THE SIGNUP BLOCK NOTE //
        ////////////////////////////////////////////

        // get block header from specified block number
        let block_header = context.get_block_header(signup_block_number);

        // compute the note commitment
        let app_address_note = storage.app_contract.get_note();
        let note: UserNote = UserNote::new_with_randomness_and_header(owner.address, randomness, app_address_note.address, 1);
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

        ////////////////////////////////////////////
        //// STEP 2: VALIDATE THE CURRENT BLOCK ////
        ////////////////////////////////////////////

        // get the block header from the last block
        let last_block_header = context.get_block_header(last_block_number);

        // get the witness that this block was in the block tree
        let block_tree_id = 5;
        let block_witness = MembershipWitness<NOTE_HASH_TREE_HEIGHT, NOTE_HASH_TREE_HEIGHT + 1> =
            get_membership_witness(last_block_number, block_tree_id, last_block_header.block_hash());

        // prove that the last block's hash was a part of the last block's tree
        // note: is this verified?
        assert(
            // maybe replace this with context.block_header.archive_note()?
            last_block_header.archive_root ==
            dep::std::merkle::compute_merkle_rootlast_block_header.block_hash() block_witness.index, block_witness.path
        );

        ////////////////////////////////////////////
        //// STEP 3: ADD PRIVATE BALANCE TO USER ///
        ////////////////////////////////////////////

        storage.balances.at(owner.address).add(SafeU120::new(last_block_number - signup_block_number));
    }
}
