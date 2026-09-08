//! `bestie_edit`: the program behind Bestie's `edit` and `create` tools.
//!
//! Reads one JSON request from stdin, performs it, and writes one JSON reply
//! to stdout. Exit status 0 means a reply was written, whatever it says; a
//! nonzero status with a message on stderr means the program could not answer
//! at all (unreadable request, unexpected I/O failure).

mod create;
mod diff;
mod disk;
mod edit;
#[cfg(test)]
mod scratch;
mod wire;

use std::io::{self, Read};
use std::process;

use wire::Request;

fn main() {
    let mut input = String::new();
    if let Err(error) = io::stdin().read_to_string(&mut input) {
        fail(&format!("could not read the request: {error}"));
    }
    let request: Request = match serde_json::from_str(&input) {
        Ok(request) => request,
        Err(error) => fail(&format!("could not parse the request: {error}")),
    };
    let answered = match &request {
        Request::Edit {
            path,
            old,
            new,
            replace_all,
        } => {
            if old.is_empty() {
                fail("`old` must not be empty");
            }
            edit::edit(path, old, new, *replace_all)
        }
        Request::Create { path, contents } => create::create(path, contents),
    };
    match answered {
        Ok(reply) => {
            let json = serde_json::to_string(&reply)
                .unwrap_or_else(|error| fail(&format!("could not encode the reply: {error}")));
            println!("{json}");
        }
        Err(disk::Failure(message)) => fail(&message),
    }
}

fn fail(message: &str) -> ! {
    eprintln!("bestie_edit: {message}");
    process::exit(2);
}
