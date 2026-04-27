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
fn get_loop_exit(
  ctx : LoweringContext,
  loop_info : @ssa/cfg_info.LoopInfo,
) -> @ssa.Label {
  let mut label = match ctx.postdom_tree.idom.get(loop_info.header) {
    Some(label) => label
    None => ctx.synthetic_exit
  }
  while label != ctx.synthetic_exit && loop_info.members.contains(label) {
    label = match ctx.postdom_tree.idom.get(label) {
      Some(next) => next
      None => ctx.synthetic_exit
    }
  }
  label
}

///|
fn term_successors(block : @ssa.Block) -> Array[@ssa.Label] {
  match block.term {
    JumpT(Target(label, _)) => [label]
    CondT(_, Target(then_label, _), Target(else_label, _)) =>
      if then_label == else_label {
        [then_label]
      } else {
        [then_label, else_label]
      }
    ReturnT(_, _) => []
  }
}

///|
fn collect_if_reachable(
  ctx : LoweringContext,
  if_label : @ssa.Label,
  start_label : @ssa.Label,
) -> SortedSet[@ssa.Label] {
  let seen : Map[@ssa.Label, Bool] = {}
  let mut out : SortedSet[@ssa.Label] = SortedSet::new()
  letrec collect = fn(label : @ssa.Label) -> Unit {
    if ctx.conts.contains(label) {
      out = out.add(label)
      return
    }
    if !@ssa/cfg_info.dominates(ctx.dom_tree, if_label, label) ||
      seen.get(label) is Some(true) {
      return
    }
    seen[label] = true
    let block = ctx.blocks[label]
    match block.term {
      ReturnT(_, _) => {
        let preds = ctx.cfg_info.preds[label]
        if preds.length() > 1 {
          out = out.add(label)
        }
      }
      _ => {
        out = out.add(label)
        match ctx.loop_forest.loops.get(label) {
          Some(loop_info) => {
            let exit_label = get_loop_exit(ctx, loop_info)
            if exit_label != ctx.synthetic_exit {
              collect(exit_label)
            }
          }
          None =>
            for next in term_successors(block) {
              collect(next)
            }
        }
      }
    }
  }
  collect(start_label)
  out
}

///|
fn is_earlier_join_candidate(
  ctx : LoweringContext,
  candidate : @ssa.Label,
  current : @ssa.Label,
) -> Bool {
  let candidate_is_cont = ctx.conts.contains(candidate)
  let current_is_cont = ctx.conts.contains(current)
  if candidate_is_cont != current_is_cont {
    !candidate_is_cont
  } else {
    @ssa/cfg_info.dominates(ctx.dom_tree, candidate, current) &&
    !@ssa/cfg_info.dominates(ctx.dom_tree, current, candidate)
  }
}

///|
fn pick_inner_loop_header_cont(
  ctx : LoweringContext,
  label : @ssa.Label,
) -> @ssa.Label? {
  let mut best : @ssa.Label? = None
  for header, loop_info in ctx.loop_forest.loops {
    if !ctx.conts.contains(header) || !loop_info.members.contains(label) {
      continue
    }
    match best {
      None => best = Some(header)
      Some(current) =>
        if @ssa/cfg_info.dominates(ctx.dom_tree, current, header) &&
          !@ssa/cfg_info.dominates(ctx.dom_tree, header, current) {
          best = Some(header)
        }
    }
  }
  best
}

///|
fn all_join_candidates_are_conts(
  ctx : LoweringContext,
  then_reachable : SortedSet[@ssa.Label],
  else_reachable : SortedSet[@ssa.Label],
) -> Bool {
  let mut saw_candidate = false
  for label in then_reachable {
    if else_reachable.contains(label) {
      saw_candidate = true
      if !ctx.conts.contains(label) {
        return false
      }
    }
  }
  saw_candidate
}

///|
/// Return the earliest block, by dominator order, that both branches can reach
/// without crossing a single-predecessor return or the current if's dominance
/// boundary. Enclosing continuations are kept as boundary candidates but are
/// not traversed. Multi-predecessor returns are shared tails, so they stay
/// eligible as join candidates. Loop headers are kept as join candidates and
/// traversal skips their bodies, but continues through their exits so a branch
/// starting with a loop can still meet a later shared continuation.
fn get_if_join(
  ctx : LoweringContext,
  if_label : @ssa.Label,
  then_label : @ssa.Label,
  else_label : @ssa.Label,
) -> @ssa.Label? {
  let then_reachable = collect_if_reachable(ctx, if_label, then_label)
  let else_reachable = collect_if_reachable(ctx, if_label, else_label)
  let mut best : @ssa.Label? = None
  for label in then_reachable {
    if !else_reachable.contains(label) {
      continue
    }
    match best {
      None => best = Some(label)
      Some(current) =>
        if is_earlier_join_candidate(ctx, label, current) {
          best = Some(label)
        }
    }
  }
  match best {
    None => pick_inner_loop_header_cont(ctx, if_label)
    Some(label) =>
      if all_join_candidates_are_conts(ctx, then_reachable, else_reachable) {
        match pick_inner_loop_header_cont(ctx, if_label) {
          Some(header) => Some(header)
          None => Some(label)
        }
      } else {
        Some(label)
      }
  }
}

///|
fn target_with_label_args(label : @ssa.Label) -> @ssa.Target {
  Target(label, label.params.map(fn(param) { VarE(param) }))
}

///|
fn target_label(target : @ssa.Target) -> @ssa.Label {
  let Target(label, _) = target
  label
}

///|
fn build_region(ctx : LoweringContext, label : @ssa.Label) -> Region {
  let block = ctx.blocks[label]
  let tail = match block.term {
    JumpT(next_target) => build_entry_region(ctx, next_target)
    CondT(cond, then_target, else_target) => {
      let then_label = target_label(then_target)
      let else_label = target_label(else_target)
      match get_if_join(ctx, label, then_label, else_label) {
        None => {
          let then_region = build_entry_region(ctx, then_target)
          let else_region = build_entry_region(ctx, else_target)
          If(cond, then_region, else_region, None)
        }
        Some(join_label) =>
          if ctx.conts.contains(join_label) {
            let bridge_label = fresh_label(ctx.id_gen, join_label.params)
            let branch_ctx = {
              ..ctx,
              conts: ctx.conts.add(join_label).add(bridge_label),
              cont_redirects: ctx.cont_redirects.add(join_label, bridge_label),
            }
            let then_region = build_entry_region(branch_ctx, then_target)
            let else_region = build_entry_region(branch_ctx, else_target)
            If(
              cond,
              then_region,
              else_region,
              Some((bridge_label, Goto(target_with_label_args(join_label)))),
            )
          } else {
            let branch_ctx = { ..ctx, conts: ctx.conts.add(join_label) }
            let then_region = build_entry_region(branch_ctx, then_target)
            let else_region = build_entry_region(branch_ctx, else_target)
            let join_region = build_entry_region(
              ctx,
              target_with_label_args(join_label),
            )
            If(cond, then_region, else_region, Some((join_label, join_region)))
          }
      }
    }
    ReturnT(exprs, multi) => Return(exprs, multi)
  }
  if block.stmts.is_empty() {
    tail
  } else {
    Linear(block.stmts, tail)
  }
}

///|
fn build_loop_region(
  ctx : LoweringContext,
  header : @ssa.Label,
  init : Array[@ssa.Expr],
  loop_info : @ssa/cfg_info.LoopInfo,
) -> Region {
  let exit_label = get_loop_exit(ctx, loop_info)
  let (body_ctx, exit_region) : (LoweringContext, (@ssa.Label, Region)?) = if exit_label ==
    ctx.synthetic_exit {
    ({ ..ctx, conts: ctx.conts.add(header).add(exit_label) }, None)
  } else if ctx.conts.contains(exit_label) {
    let bridge_label = fresh_label(ctx.id_gen, exit_label.params)
    (
      {
        ..ctx,
        conts: ctx.conts.add(header).add(exit_label).add(bridge_label),
        cont_redirects: ctx.cont_redirects.add(exit_label, bridge_label),
      },
      Some((bridge_label, Goto(target_with_label_args(exit_label)))),
    )
  } else {
    (
      { ..ctx, conts: ctx.conts.add(header).add(exit_label) },
      Some((exit_label, build_region(ctx, exit_label))),
    )
  }
  Loop(header, init, UnknownLS, build_region(body_ctx, header), exit_region)
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
  match body {
    Linear(stmts, tail) => Linear([..bindings, ..stmts], tail)
    _ => Linear(bindings, body)
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
