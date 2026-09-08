# vt_parser test fixtures

Each `<name>.bin` is a raw capture of the bytes a real child process
wrote to its controlling tty when run under `process_host`. Each
`<name>.events.json` is the golden `VtParser` event stream produced
by replaying those bytes through `VtParser`, serialised to JSON.
