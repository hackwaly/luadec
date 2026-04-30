///|
const INSPECT = "inspect"

///|
pub let inspect_command : @argparse.Command = Command(
  INSPECT,
  positionals=[PositionArg("input")],
  arg_required_else_help=true,
)

///|
async fn[T] inspect(
  input : T,
  inspector : (T) -> String,
  filter~ : (String) -> Bool,
  filename~ : String,
) -> T {
  let enabled = filter(filename)
  if enabled {
    let str = inspector(input)
    let bytes = @encoding/utf8.encode(str)
    @fs.write_file(filename, bytes)
  } else {
    @fs.unlink(filename) catch {
      _ => ()
    }
  }
  input
}

///|
async fn handle_inspect_command(matches : @argparse.Matches) -> Unit {
  let filename = matches.values["input"][0]
  let bytes = @fs.read_file(filename).binary()
  let _ = pipeline(bytes, filename~, inspect_filter=_ => true)
}
