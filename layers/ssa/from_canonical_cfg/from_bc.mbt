///|
pub fn from_canonical_cfg(prog : @canonical_cfg.Program) -> Program {
  let id_gen = IdGen()
  let plans = plan_program(prog, id_gen)
  let built_funcs : Map[Int, Func] = {}
  let built : Map[@canonical_cfg.FuncId, Bool] = {}
  let closure_bindings : Map[@canonical_cfg.FuncId, CaptureBinding] = {}

  letrec build_func = fn(
    id : @canonical_cfg.FuncId,
    capture_binding : CaptureBinding,
  ) -> Unit {
    if built.get(id) is Some(true) {
      panic()
    }
    let registered_children : Array[@canonical_cfg.FuncId] = []
    let func = build_ssa_func(
      prog,
      plans,
      prog.funcs[id.index],
      id_gen,
      closure_bindings,
      registered_children,
      capture_binding~,
    )
    built_funcs[id.index] = func
    built[id] = true
    for child_id in registered_children {
      match closure_bindings.get(child_id) {
        Some(binding) => build_func(child_id, binding)
        None => panic()
      }
    }
  }
  build_func(prog.main, { vars: [], cells: [Cell::env()] })
  let funcs : Array[Func] = []
  for func in prog.funcs {
    match built_funcs.get(func.index) {
      Some(lowered) => funcs.push(lowered)
      None => panic()
    }
  }
  { _id_gen: id_gen, funcs, main: ssa_func_id(prog.main) }
}
