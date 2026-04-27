///|
fn simplify_func(func : @ssa.Func, index_as_side_effect : Bool) -> @ssa.Func {
  let mut current = func
  let mut changed = true
  while changed {
    changed = false
    let (after_inline, inline_changed) = inline_single_use_vars_func(
      current, index_as_side_effect,
    )
    let (after_cfg, cfg_changed) = simplify_cfg_func(after_inline)
    current = after_cfg
    if inline_changed || cfg_changed {
      changed = true
    }
  }
  current
}

///|
pub fn simplify(
  program : @ssa.Program,
  index_as_side_effect? : Bool = false,
) -> @ssa.Program {
  {
    _id_gen: program._id_gen,
    funcs: program.funcs.map(fn(func) {
      simplify_func(func, index_as_side_effect)
    }),
    main: program.main,
  }
}
