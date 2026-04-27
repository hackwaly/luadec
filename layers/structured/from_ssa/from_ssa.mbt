///|
fn fresh_label(id_gen : @ssa.IdGen, params : Array[@ssa.Var]) -> @ssa.Label {
  { id: id_gen.next(), params }
}

///|
priv struct LoweringContext {
  id_gen : @ssa.IdGen
  synthetic_exit : @ssa.Label
  dom_tree : @ssa/cfg_info.DomTree
  postdom_tree : @ssa/cfg_info.DomTree
  loop_forest : @ssa/cfg_info.LoopForest
  cfg_info : @ssa/cfg_info.CfgInfo
  blocks : SortedMap[@ssa.Label, @ssa.Block]
  conts : SortedSet[@ssa.Label]
  cont_redirects : SortedMap[@ssa.Label, @ssa.Label]
}

///|
fn target_with_label_args(label : @ssa.Label) -> @ssa.Target {
  Target(label, label.params.map(fn(param) { VarE(param) }))
}

///|
fn build_region(ctx : LoweringContext, label : @ssa.Label) -> Region {
  let block = ctx.blocks[label]
  let tail = match block.term {
    JumpT(next_target) => build_entry_region(ctx, next_target)
    CondT(cond, then_target, else_target) =>
      build_cond_region(ctx, label, cond, then_target, else_target)
    ReturnT(exprs, multi) => Return(exprs, multi)
  }
  if block.stmts.is_empty() {
    tail
  } else {
    Linear(block.stmts, tail)
  }
}

///|
/// Structured lowering expects `Target.args` to have been normalized by
/// `@ssa/materialize_target_args`: every edge argument should be a `VarE`.
/// The fallback binding of arbitrary expressions below keeps the function total,
/// but callers must materialize first to preserve edge-local evaluation timing.
fn build_entry_region(ctx : LoweringContext, target : @ssa.Target) -> Region {
  let Target(label, args) = target
  guard args.length() == label.params.length() else { panic() }

  if ctx.conts.contains(label) {
    let target = match ctx.cont_redirects.get(label) {
      Some(redirect_label) => redirect_label
      None => label
    }
    return Goto(Target(target, args))
  }
  if ctx.loop_forest.loops.get(label) is Some(loop_info) {
    return build_loop_region(ctx, label, args, loop_info)
  }
  let body = build_region(ctx, label)
  let bindings : Array[@ssa.Stmt] = []
  for i in 0..<args.length() {
    let param = label.params[i]
    let arg = args[i]
    match arg {
      VarE(value) if value == param => ()
      _ => bindings.push(BindS(param, arg))
    }
  }
  if bindings.is_empty() {
    body
  } else {
    match body {
      Linear(stmts, tail) => Linear([..bindings, ..stmts], tail)
      _ => Linear(bindings, body)
    }
  }
}

///|
fn lower_func(id_gen : @ssa.IdGen, func : @ssa.Func) -> Func {
  let cfg_info = @ssa/cfg_info.build_cfg(func)
  let dom_tree = @ssa/cfg_info.build_dom_tree(func.entry, cfg_info)
  let synthetic_exit : @ssa.Label = fresh_label(id_gen, [])
  let postdom_cfg = @ssa/cfg_info.build_postdom_cfg(cfg_info, synthetic_exit)
  let postdom_tree = @ssa/cfg_info.build_dom_tree(synthetic_exit, postdom_cfg)
  let loop_forest = @ssa/cfg_info.build_loop_forest(cfg_info, dom_tree)
  let ctx : LoweringContext = {
    id_gen,
    synthetic_exit,
    dom_tree,
    postdom_tree,
    loop_forest,
    cfg_info,
    blocks: func.blocks,
    conts: SortedSet::new(),
    cont_redirects: SortedMap::new(),
  }
  {
    index: func.index,
    params: func.params,
    cells: func.cells,
    vararg: func.vararg,
    body: build_entry_region(ctx, @ssa.Target(func.entry, [])),
  }
}

///|
pub fn from_ssa(program : @ssa.Program) -> Program {
  {
    _id_gen: program._id_gen,
    funcs: program.funcs.map(func => lower_func(program._id_gen, func)),
    main: program.main,
  }
}
