///|
const DISASSEMBLE = "disassemble"

///|
pub let disassemble_command : @argparse.Command = Command(
  DISASSEMBLE,
  positionals=[PositionArg("input")],
  options=[OptionArg("output", short='o')],
  arg_required_else_help=true,
)

///|
async fn handle_disassemble_command(matches : @argparse.Matches) -> Unit {
  let input = matches.values["input"][0]
  let bytes = @fs.read_file(input).binary()
  let chunk = @bc/parse.parse(bytes)
  let result = @bc/disasm.disassemble(chunk)
  match matches.values.get("output") {
    None | Some([]) => @console.stdout.write(result)
    Some([output, ..]) => @fs.write_file(output, result)
  }
}
