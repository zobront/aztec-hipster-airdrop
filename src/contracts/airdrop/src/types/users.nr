use dep::aztec::{
    context::{PrivateContext, PublicContext, Context},
    note::{
        note_header::NoteHeader,
        note_interface::NoteInterface,
        utils::compute_note_hash_for_read_or_nullify
    },
    types::address::AztecAddress,
    hash::compute_secret_hash,
    oracle::{
        rand::rand,
        get_secret_key::get_secret_key
    }
};

global USER_NOTE_LEN: Field = 2;

struct UserNote {
    user: Field,
    randomness: Field,
    header: NoteHeader,
}

impl UserNote {

    pub fn new(user: Field) -> Self {
        let randomness = rand();
        UserNote {
            user,
            randomness,
            header: NoteHeader::empty(),
        }
    }

    pub fn new_with_randomness_and_header(user: Field, randomness: Field, contract_address: Field, storage_slot: Field) -> Self {
        let header = NoteHeader::new(contract_address, 0, storage_slot);
        UserNote {
            user,
            randomness,
            header
        }
    }

    // STANDARD NOTE_INTERFACE FUNCTIONS

    pub fn serialize(self) -> [Field; USER_NOTE_LEN] {
        [self.user, self.randomness]
    }

    pub fn deserialize(preimage: [Field; USER_NOTE_LEN]) -> Self {
        UserNote {
            user: preimage[0],
            randomness: preimage[1],
            header: NoteHeader::empty(),
        }
    }

    pub fn compute_note_hash(self) -> Field {
        dep::std::hash::pedersen_hash([
            self.user,
            self.randomness,
        ])
    }

    pub fn compute_nullifier(self) -> Field {
        let note_hash_for_nullify = compute_note_hash_for_read_or_nullify(UserNoteMethods, self);
        let secret = get_secret_key(self.user);
        dep::std::hash::pedersen_hash([
            note_hash_for_nullify,
            secret.low,
            secret.high,
        ])
    }

    pub fn set_header(&mut self, header: NoteHeader) {
        self.header = header;
    }
}

fn deserialize(preimage: [Field; USER_NOTE_LEN]) -> UserNote {
    UserNote::deserialize(preimage)
}

fn serialize(note: UserNote) -> [Field; USER_NOTE_LEN] {
    note.serialize()
}

fn compute_note_hash(note: UserNote) -> Field {
    note.compute_note_hash()
}

fn compute_nullifier(note: UserNote) -> Field {
    note.compute_nullifier()
}

fn get_header(note: UserNote) -> NoteHeader {
    note.header
}

fn set_header(note: &mut UserNote, header: NoteHeader) {
    note.set_header(header)
}

global UserNoteMethods = NoteInterface {
    deserialize,
    serialize,
    compute_note_hash,
    compute_nullifier,
    get_header,
    set_header,
};
