mod users;

contract App {
    use dep::aztec::{
        note::note_header::NoteHeader,
        context::{PrivateContext, PublicContext, Context},
        state_vars::set::Set
    };

    use crate::users::{UserNote, USER_NOTE_LEN, UserNoteMethods};

    struct Storage {
        users: Set<UserNote, USER_NOTE_LEN>,
    }

    impl Storage {
        fn init(context: Context) -> Self {
            Storage {
                users: Set::new(context, 1, UserNoteMethods),
            }
        }
    }

    #[aztec(private)]
    fn signUp() {
        let user_note = UserNote::new(
            context.msg_sender(),
        );
        storage.users.insert(user_note);
    }
}
