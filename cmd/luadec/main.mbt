///|
let main_command : @argparse.Command = Command(
  "luadec",
  about="Lua 5.3 decompiler",
  arg_required_else_help=true,
  subcommands=[disassemble_command, inspect_command, decompile_command],
)

///|
async fn main {
  try {
    match main_command.parse(argv=@console.argv) {
      { subcommand: Some((DISASSEMBLE, matches)), .. } =>
        handle_disassemble_command(matches)
      { subcommand: Some((INSPECT, matches)), .. } =>
        handle_inspect_command(matches)
      { subcommand: Some((DECOMPILE, matches)), .. } =>
        handle_decompile_command(matches)
      _ => panic()
    }
  } catch {
    err => @console.stderr.write(err.to_string())
  }
}
