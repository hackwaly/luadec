///|
const DECOMPILE = "decompile"

///|
pub let decompile_command : @argparse.Command = Command(
  DECOMPILE,
  positionals=[PositionArg("input")],
  options=[OptionArg("output", short='o')],
  arg_required_else_help=true,
)

///|
async fn handle_decompile_command(matches : @argparse.Matches) -> Unit {
  let input = matches.values["input"][0]
  let bytes = @fs.read_file(input).binary()
  let named = pipeline(bytes, filename=input, inspect_filter=_ => false)
  let result = @expr/render.render_named(named)
  match matches.values.get("output") {
    None | Some([]) => @console.stdout.write(result)
    Some([output, ..]) => @fs.write_file(output, result)
  }
}
