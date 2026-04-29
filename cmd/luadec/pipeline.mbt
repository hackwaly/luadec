///|
fn[T : Debug] debug_to_string(x : T) -> String {
  @debug.render(x.to_repr(), max_depth=1000)
}

///|
async fn pipeline(
  bytes : BytesView,
  filename~ : String,
  inspect_filter~ : (String) -> Bool,
) -> @expr.Program {
  let base = filename.strip_suffix(".lua.bytes").unwrap_or(filename)
  let inspect_dir = "\{base}.inspect"
  @fs.rmdir(inspect_dir, recursive=true) catch {
    _ => ()
  }
  @fs.mkdir(inspect_dir, recursive=true)
  let filter = inspect_filter
  bytes
  |> @bc/parse.parse
  |> inspect(
    @bc/disasm.disassemble,
    filter~,
    filename="\{inspect_dir}/100_disasm.txt",
  )
  |> @raw_cfg/from_bc.from_bc
  |> inspect(
    debug_to_string,
    filter~,
    filename="\{inspect_dir}/200_raw_cfg.txt",
  )
  |> @canonical_cfg/from_raw_cfg.from_raw_cfg
  |> inspect(
    debug_to_string,
    filter~,
    filename="\{inspect_dir}/300_canonical_cfg.txt",
  )
  |> @ssa/from_canonical_cfg.from_canonical_cfg
  |> inspect(@ssa/render.render, filter~, filename="\{inspect_dir}/400_ssa.lua")
  |> @ssa/trivial_copy_propagation.trivial_copy_propagation
  |> inspect(
    @ssa/render.render,
    filter~,
    filename="\{inspect_dir}/410_ssa_tcp.lua",
  )
  |> @ssa/recover_method_call.recover_method_call
  |> inspect(
    @ssa/render.render,
    filter~,
    filename="\{inspect_dir}/420_ssa_rmc.lua",
  )
  |> @ssa/simplify.simplify
  |> inspect(
    @ssa/render.render,
    filter~,
    filename="\{inspect_dir}/430_ssa_simp.lua",
  )
  |> @ssa/recover_boolean.recover_boolean
  |> inspect(
    @ssa/render.render,
    filter~,
    filename="\{inspect_dir}/440_ssa_rb.lua",
  )
  |> @ssa/simplify.simplify
  |> inspect(
    @ssa/render.render,
    filter~,
    filename="\{inspect_dir}/480_ssa_simp.lua",
  )
  |> @ssa/materialize_target_args.materialize_target_args
  |> inspect(
    @ssa/render.render,
    filter~,
    filename="\{inspect_dir}/490_ssa_mta.lua",
  )
  |> @structured/from_ssa.from_ssa
  |> inspect(
    @structured/render.render,
    filter~,
    filename="\{inspect_dir}/500_structured.lua",
  )
  |> @structured/recognize_loop_shape.recognize_loop_shape
  |> inspect(
    @structured/render.render,
    filter~,
    filename="\{inspect_dir}/510_structured_loop_shape.lua",
  )
  |> @expr/from_structured.from_program
  |> inspect(
    @expr/render.render,
    filter~,
    filename="\{inspect_dir}/600_expr.lua",
  )
}
