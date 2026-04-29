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
  |> @structured/prune_cont_params.prune_cont_params
  |> inspect(
    @structured/render.render,
    filter~,
    filename="\{inspect_dir}/520_structured_pruned.lua",
  )
  |> @structured/hoist_common_transfers.hoist_common_transfers
  |> inspect(
    @structured/render.render,
    filter~,
    filename="\{inspect_dir}/530_structured_hoisted.lua",
  )
  |> @expr/from_structured.from_program
  |> inspect(
    @expr/render.render,
    filter~,
    filename="\{inspect_dir}/600_expr.lua",
  )
  |> @expr/simplify_temps.simplify_temps
  |> inspect(
    @expr/render.render,
    filter~,
    filename="\{inspect_dir}/605_expr_simplify_temps.lua",
  )
  |> @expr/normalize_if_chain.normalize_if_chain
  |> inspect(
    @expr/render.render,
    filter~,
    filename="\{inspect_dir}/607_expr_normalize_if_chain.lua",
  )
  |> @expr/normalize_if.normalize_if
  |> inspect(
    @expr/render.render,
    filter~,
    filename="\{inspect_dir}/610_expr_normalize_if.lua",
  )
}
