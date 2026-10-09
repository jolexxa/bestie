use std::fs;
use std::io::Write;
use std::process::{Child, Command, Stdio};

fn run(input: &str) -> (i32, String, String) {
    finish(start(input))
}

/// Spawns the program with [`input`] on stdin and leaves it running.
fn start(input: &str) -> Child {
    let mut child = Command::new(env!("CARGO_BIN_EXE_bestie_edit"))
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    child
        .stdin
        .take()
        .unwrap()
        .write_all(input.as_bytes())
        .unwrap();
    child
}

fn finish(child: Child) -> (i32, String, String) {
    let output = child.wait_with_output().unwrap();
    (
        output.status.code().unwrap_or(-1),
        String::from_utf8(output.stdout).unwrap(),
        String::from_utf8(output.stderr).unwrap(),
    )
}

fn scratch(name: &str) -> std::path::PathBuf {
    std::env::temp_dir().join(format!("bestie_edit-cli-{}-{name}", std::process::id()))
}

#[test]
fn answers_an_edit_on_stdout() {
    let path = scratch("edit.txt");
    fs::write(&path, "hello\n").unwrap();
    let request = serde_json::json!({
        "action": "edit",
        "path": path.to_string_lossy(),
        "old": "hello",
        "new": "goodbye",
    });
    let (code, stdout, stderr) = run(&request.to_string());
    let _ = fs::remove_file(&path);
    assert_eq!(code, 0, "stderr: {stderr}");
    let reply: serde_json::Value = serde_json::from_str(&stdout).unwrap();
    assert_eq!(reply["outcome"], "succeeded");
    assert_eq!(reply["replacements"], 1);
    assert_eq!(reply["diff"]["added"], 1);
    assert_eq!(reply["diff"]["hunks"][0]["lines"][0]["kind"], "removed");
}

#[test]
fn answers_a_create_on_stdout() {
    let dir = scratch("create");
    let path = dir.join("nested/new.txt");
    let request = serde_json::json!({
        "action": "create",
        "path": path.to_string_lossy(),
        "contents": "fresh\n",
    });
    let (code, stdout, stderr) = run(&request.to_string());
    let written = fs::read(&path);
    let _ = fs::remove_dir_all(&dir);
    assert_eq!(code, 0, "stderr: {stderr}");
    let reply: serde_json::Value = serde_json::from_str(&stdout).unwrap();
    assert_eq!(reply["outcome"], "created");
    assert_eq!(written.unwrap(), b"fresh\n");
}

#[test]
fn refuses_an_unreadable_request() {
    let (code, stdout, stderr) = run("not json");
    assert_eq!(code, 2);
    assert!(stdout.is_empty());
    assert!(stderr.contains("could not parse"));
}

#[test]
fn refuses_an_empty_target() {
    let request = serde_json::json!({
        "action": "edit",
        "path": scratch("empty-target.txt").to_string_lossy(),
        "old": "",
        "new": "y",
    });
    let (code, _, stderr) = run(&request.to_string());
    assert_eq!(code, 2);
    assert!(stderr.contains("must not be empty"));
}

#[test]
fn refuses_a_relative_path() {
    for action in [
        r#"{"action":"edit","path":"notes.md","old":"a","new":"b"}"#,
        r#"{"action":"create","path":"notes.md","contents":"a"}"#,
    ] {
        let (code, stdout, stderr) = run(action);
        assert_eq!(code, 2, "{action}");
        assert!(stdout.is_empty(), "{action}");
        assert!(stderr.contains("must be absolute"), "{action}");
    }
}

#[test]
fn concurrent_edits_to_one_file_both_survive() {
    let path = scratch("concurrent.md");
    fs::write(&path, "alpha\n\nomega\n").unwrap();
    let request = |old: &str, new: &str| {
        serde_json::json!({
            "action": "edit",
            "path": path.to_string_lossy(),
            "old": old,
            "new": new,
        })
        .to_string()
    };
    let first = start(&request("alpha", "ALPHA"));
    let second = start(&request("omega", "OMEGA"));
    let (first_code, first_stdout, first_stderr) = finish(first);
    let (second_code, second_stdout, second_stderr) = finish(second);
    let written = fs::read_to_string(&path).unwrap();
    let _ = fs::remove_file(&path);
    assert_eq!(first_code, 0, "stderr: {first_stderr}");
    assert_eq!(second_code, 0, "stderr: {second_stderr}");
    let first_reply: serde_json::Value = serde_json::from_str(&first_stdout).unwrap();
    let second_reply: serde_json::Value = serde_json::from_str(&second_stdout).unwrap();
    assert_eq!(first_reply["outcome"], "succeeded");
    assert_eq!(second_reply["outcome"], "succeeded");
    assert_eq!(
        written, "ALPHA\n\nOMEGA\n",
        "both edits reported success, so both must be in the file"
    );
}

#[test]
fn concurrent_creates_of_one_path_elect_one() {
    let dir = scratch("concurrent-create");
    let path = dir.join("contested.txt");
    let request = |contents: &str| {
        serde_json::json!({
            "action": "create",
            "path": path.to_string_lossy(),
            "contents": contents,
        })
        .to_string()
    };
    let first = start(&request("one"));
    let second = start(&request("two"));
    let (first_code, first_stdout, first_stderr) = finish(first);
    let (second_code, second_stdout, second_stderr) = finish(second);
    let written = fs::read_to_string(&path).unwrap();
    let _ = fs::remove_dir_all(&dir);
    assert_eq!(first_code, 0, "stderr: {first_stderr}");
    assert_eq!(second_code, 0, "stderr: {second_stderr}");
    let first_reply: serde_json::Value = serde_json::from_str(&first_stdout).unwrap();
    let second_reply: serde_json::Value = serde_json::from_str(&second_stdout).unwrap();
    let outcomes = [
        first_reply["outcome"].as_str().unwrap(),
        second_reply["outcome"].as_str().unwrap(),
    ];
    let mut sorted = outcomes;
    sorted.sort_unstable();
    assert_eq!(sorted, ["created", "pathExists"], "{outcomes:?}");
    let winner = if outcomes[0] == "created" {
        "one"
    } else {
        "two"
    };
    assert_eq!(written, winner);
}

#[cfg(unix)]
#[test]
fn refuses_to_edit_through_a_symlink() {
    let dir = scratch("symlinked");
    fs::create_dir_all(&dir).unwrap();
    let target = dir.join("real.md");
    let link = dir.join("link.md");
    fs::write(&target, "one\n").unwrap();
    std::os::unix::fs::symlink(&target, &link).unwrap();
    let request = serde_json::json!({
        "action": "edit",
        "path": link.to_string_lossy(),
        "old": "one",
        "new": "1",
    });

    let (code, stdout, stderr) = run(&request.to_string());
    let still_linked = fs::symlink_metadata(&link)
        .unwrap()
        .file_type()
        .is_symlink();
    let contents = fs::read_to_string(&target).unwrap();
    let _ = fs::remove_dir_all(&dir);

    assert_eq!(code, 2);
    assert!(stdout.is_empty());
    assert!(stderr.contains("must not be a symlink"), "{stderr}");
    assert!(still_linked);
    assert_eq!(contents, "one\n");
}
