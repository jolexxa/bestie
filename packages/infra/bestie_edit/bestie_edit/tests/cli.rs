use std::fs;
use std::io::Write;
use std::process::{Command, Stdio};

fn run(input: &str) -> (i32, String, String) {
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
    let (code, _, stderr) = run(r#"{"action":"edit","path":"x","old":"","new":"y"}"#);
    assert_eq!(code, 2);
    assert!(stderr.contains("must not be empty"));
}
