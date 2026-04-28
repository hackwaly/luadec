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
            let exit_label = get_structured_loop_exit(ctx, loop_info)
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
fn target_label(target : @ssa.Target) -> @ssa.Label {
  let Target(label, _) = target
  label
}

///|
fn invert_binary_op(op : @ssa.BinaryOp) -> @ssa.BinaryOp? {
  match op {
    Eq => Some(Neq)
    Neq => Some(Eq)
    Lt => Some(Geq)
    Gt => Some(Leq)
    Leq => Some(Gt)
    Geq => Some(Lt)
    _ => None
  }
}

///|
fn flip_binary_op(op : @ssa.BinaryOp) -> @ssa.BinaryOp? {
  match op {
    Eq => Some(Eq)
    Neq => Some(Neq)
    Lt => Some(Gt)
    Gt => Some(Lt)
    Leq => Some(Geq)
    Geq => Some(Leq)
    _ => None
  }
}

///|
fn should_flip_binary_operands(lhs : @ssa.Expr, rhs : @ssa.Expr) -> Bool {
  match (lhs, rhs) {
    (ConstE(_), ConstE(_)) => false
    (ConstE(_), _) => true
    _ => false
  }
}

///|
fn normalize_binary_cond(
  op : @ssa.BinaryOp,
  lhs : @ssa.Expr,
  rhs : @ssa.Expr,
) -> @ssa.Expr {
  if should_flip_binary_operands(lhs, rhs) {
    match flip_binary_op(op) {
      Some(op) => return BinaryE(op, rhs, lhs)
      None => ()
    }
  }
  BinaryE(op, lhs, rhs)
}

///|
fn cond_cost(cond : @ssa.Expr) -> Int {
  match cond {
    UnaryE(Not, inner) => 4 + cond_cost(inner)
    BinaryE(op, lhs, rhs) => {
      let mut cost = cond_cost(lhs) + cond_cost(rhs) + binary_cond_op_cost(op)
      if should_flip_binary_operands(lhs, rhs) && flip_binary_op(op) is Some(_) {
        cost = cost + 2
      }
      cost
    }
    AndE(lhs, rhs) | OrE(lhs, rhs) => 1 + cond_cost(lhs) + cond_cost(rhs)
    _ => 0
  }
}

///|
fn binary_cond_op_cost(op : @ssa.BinaryOp) -> Int {
  match op {
    Neq => 1
    _ => 0
  }
}

///|
fn choose_lower_cost_cond(lhs : @ssa.Expr, rhs : @ssa.Expr) -> @ssa.Expr {
  if cond_cost(rhs) <= cond_cost(lhs) {
    rhs
  } else {
    lhs
  }
}

///|
fn normalize_cond(cond : @ssa.Expr) -> @ssa.Expr {
  match cond {
    UnaryE(Not, inner) => invert_cond(inner)
    BinaryE(op, lhs, rhs) =>
      normalize_binary_cond(op, normalize_cond(lhs), normalize_cond(rhs))
    AndE(lhs, rhs) => AndE(normalize_cond(lhs), normalize_cond(rhs))
    OrE(lhs, rhs) => OrE(normalize_cond(lhs), normalize_cond(rhs))
    _ => cond
  }
}

///|
fn invert_cond(cond : @ssa.Expr) -> @ssa.Expr {
  match cond {
    UnaryE(Not, inner) => normalize_cond(inner)
    BinaryE(op, lhs, rhs) =>
      match invert_binary_op(op) {
        Some(op) =>
          normalize_binary_cond(op, normalize_cond(lhs), normalize_cond(rhs))
        None => UnaryE(Not, normalize_cond(cond))
      }
    AndE(lhs, rhs) =>
      choose_lower_cost_cond(
        UnaryE(Not, AndE(normalize_cond(lhs), normalize_cond(rhs))),
        OrE(invert_cond(lhs), invert_cond(rhs)),
      )
    OrE(lhs, rhs) =>
      choose_lower_cost_cond(
        UnaryE(Not, OrE(normalize_cond(lhs), normalize_cond(rhs))),
        AndE(invert_cond(lhs), invert_cond(rhs)),
      )
    _ => UnaryE(Not, normalize_cond(cond))
  }
}

///|
fn is_empty_goto_to(region : Region, label : @ssa.Label) -> Bool {
  match region {
    Linear([], next) => is_empty_goto_to(next, label)
    Goto(Target(target_label, args)) => target_label == label && args.is_empty()
    _ => false
  }
}

///|
fn is_empty_transfer_to(region : Region, cont : (@ssa.Label, Region)) -> Bool {
  let (cont_label, cont_region) = cont
  if is_empty_goto_to(region, cont_label) {
    true
  } else {
    is_bare_empty_return(region) && is_bare_empty_return(cont_region)
  }
}

///|
fn build_if_region(
  cond : @ssa.Expr,
  then_region : Region,
  else_region : Region,
  cont : (@ssa.Label, Region),
) -> Region {
  if is_empty_transfer_to(else_region, cont) {
    If(cond, then_region, None, cont)
  } else if is_empty_transfer_to(then_region, cont) {
    If(invert_cond(cond), else_region, None, cont)
  } else {
    If(cond, then_region, Some(else_region), cont)
  }
}

///|
fn strip_bare_return(region : Region, cont_label : @ssa.Label) -> Region? {
  match region {
    Return([], None) => Some(Goto(Target(cont_label, [])))
    Linear([], next) => strip_bare_return(next, cont_label)
    Linear(stmts, next) =>
      match strip_bare_return(next, cont_label) {
        Some(next) => Some(Linear(stmts, next))
        None => None
      }
    _ => None
  }
}

///|
fn extract_bare_return(
  ctx : LoweringContext,
  cond : @ssa.Expr,
  then_region : Region,
  else_region : Region,
) -> Region? {
  let cont_label = fresh_label(ctx.id_gen, [])
  let then_stripped = strip_bare_return(then_region, cont_label)
  let else_stripped = strip_bare_return(else_region, cont_label)
  match (then_stripped, else_stripped) {
    (Some(then_region), Some(else_region)) =>
      Some(
        build_if_region(
          cond,
          then_region,
          else_region,
          (cont_label, Return([], None)),
        ),
      )
    (Some(_), None) =>
      Some(
        If(invert_cond(cond), else_region, None, (cont_label, Return([], None))),
      )
    (None, Some(_)) =>
      Some(If(cond, then_region, None, (cont_label, Return([], None))))
    (None, None) => None
  }
}

///|
fn is_loop_continue_target(ctx : LoweringContext, label : @ssa.Label) -> Bool {
  ctx.conts.contains(label) && ctx.loop_forest.loops.get(label) is Some(_)
}

///|
fn is_loop_exit_target(
  ctx : LoweringContext,
  from_label : @ssa.Label,
  target_label : @ssa.Label,
) -> Bool {
  for _, loop_info in ctx.loop_forest.loops {
    if loop_info.members.contains(from_label) &&
      get_structured_loop_exit(ctx, loop_info) == target_label {
      return true
    }
  }
  false
}

///|
fn target_equal(lhs : @ssa.Target, rhs : @ssa.Target) -> Bool {
  let Target(lhs_label, lhs_args) = lhs
  let Target(rhs_label, rhs_args) = rhs
  guard lhs_label == rhs_label && lhs_args.length() == rhs_args.length() else {
    return false
  }
  for i in 0..<lhs_args.length() {
    if !expr_equal(lhs_args[i], rhs_args[i]) {
      return false
    }
  }
  true
}

///|
fn identity_cont_target(
  ctx : LoweringContext,
  label : @ssa.Label,
) -> @ssa.Target {
  let target = target_with_label_args(label)
  match ctx.cont_redirects.get(label) {
    Some(template) => redirect_target(label, target.1, template)
    None => target
  }
}

///|
fn is_empty_goto_to_target(region : Region, target : @ssa.Target) -> Bool {
  match region {
    Linear([], next) => is_empty_goto_to_target(next, target)
    Goto(goto_target) => target_equal(goto_target, target)
    _ => false
  }
}

///|
fn is_identity_goto_to_cont(
  ctx : LoweringContext,
  region : Region,
  label : @ssa.Label,
) -> Bool {
  is_empty_goto_to_target(region, identity_cont_target(ctx, label))
}

///|
fn is_empty_transfer_to_enclosing_cont(
  ctx : LoweringContext,
  if_label : @ssa.Label,
  region : Region,
) -> Bool {
  match region {
    Linear([], next) => is_empty_transfer_to_enclosing_cont(ctx, if_label, next)
    Goto(Target(label, _) as target) =>
      ctx.conts.contains(label) &&
      !is_loop_continue_target(ctx, label) &&
      !is_loop_exit_target(ctx, if_label, label) &&
      target_equal(target, identity_cont_target(ctx, label))
    _ => false
  }
}

///|
fn is_bare_empty_return(region : Region) -> Bool {
  match region {
    Return([], None) => true
    Linear([], next) => is_bare_empty_return(next)
    _ => false
  }
}

///|
fn is_abrupt_exit(ctx : LoweringContext, region : Region) -> Bool {
  match region {
    Linear(_, next) => is_abrupt_exit(ctx, next)
    Return(_, _) => true
    Branch(_, then_region, else_region) =>
      is_abrupt_exit(ctx, then_region) && is_abrupt_exit(ctx, else_region)
    If(_, then_region, else_region, (_, cont_region)) => {
      let then_abrupt = is_abrupt_exit(ctx, then_region)
      let else_abrupt = match else_region {
        Some(region) => is_abrupt_exit(ctx, region)
        None => true
      }
      then_abrupt && else_abrupt && is_abrupt_exit(ctx, cont_region)
    }
    Loop(_, _, _, _, exit_region) =>
      match exit_region {
        Some((_, region)) => is_abrupt_exit(ctx, region)
        None => false
      }
    Goto(Target(label, _)) => !is_loop_continue_target(ctx, label)
  }
}

///|
fn is_direct_exit_region(
  ctx : LoweringContext,
  if_label : @ssa.Label,
  region : Region,
) -> Bool {
  match region {
    Linear([], next) => is_direct_exit_region(ctx, if_label, next)
    Return(_, _) => true
    Goto(Target(label, _)) =>
      !is_loop_continue_target(ctx, label) &&
      (!ctx.conts.contains(label) || is_loop_exit_target(ctx, if_label, label))
    _ => false
  }
}

///|
fn build_costed_branch(
  cond : @ssa.Expr,
  then_region : Region,
  else_region : Region,
) -> Region {
  let inverted = invert_cond(cond)
  if cond_cost(inverted) < cond_cost(cond) {
    Branch(inverted, else_region, then_region)
  } else {
    Branch(cond, then_region, else_region)
  }
}

///|
fn build_direct_exit_guard(
  ctx : LoweringContext,
  if_label : @ssa.Label,
  cond : @ssa.Expr,
  then_region : Region,
  else_region : Region,
) -> Region? {
  let then_direct = is_direct_exit_region(ctx, if_label, then_region)
  let else_direct = is_direct_exit_region(ctx, if_label, else_region)
  match (then_direct, else_direct) {
    (true, true) => {
      let inverted = invert_cond(cond)
      let cont_label = fresh_label(ctx.id_gen, [])
      if cond_cost(inverted) < cond_cost(cond) {
        Some(If(inverted, else_region, None, (cont_label, then_region)))
      } else {
        Some(If(cond, then_region, None, (cont_label, else_region)))
      }
    }
    (true, false) => {
      let cont_label = fresh_label(ctx.id_gen, [])
      Some(If(cond, then_region, None, (cont_label, else_region)))
    }
    (false, true) => {
      let cont_label = fresh_label(ctx.id_gen, [])
      Some(If(invert_cond(cond), else_region, None, (cont_label, then_region)))
    }
    (false, false) => None
  }
}

///|
fn should_preserve_abrupt_branch(
  ctx : LoweringContext,
  if_label : @ssa.Label,
  join_label : @ssa.Label,
  then_region : Region,
  else_region : Region,
) -> Bool {
  if is_loop_continue_target(ctx, join_label) {
    return false
  }
  if !is_abrupt_exit(ctx, then_region) || !is_abrupt_exit(ctx, else_region) {
    return false
  }
  if !is_loop_exit_target(ctx, if_label, join_label) &&
    (
      is_identity_goto_to_cont(ctx, then_region, join_label) ||
      is_identity_goto_to_cont(ctx, else_region, join_label)
    ) {
    return false
  }
  if is_bare_empty_return(then_region) || is_bare_empty_return(else_region) {
    return false
  }
  true
}

///|
fn build_branch_region(
  ctx : LoweringContext,
  if_label : @ssa.Label,
  cond : @ssa.Expr,
  then_region : Region,
  else_region : Region,
) -> Region {
  match extract_bare_return(ctx, cond, then_region, else_region) {
    Some(region) => return region
    None => ()
  }
  if is_bare_empty_return(then_region) {
    let cont_label = fresh_label(ctx.id_gen, [])
    return If(
      invert_cond(cond),
      else_region,
      None,
      (cont_label, Return([], None)),
    )
  }
  if is_bare_empty_return(else_region) {
    let cont_label = fresh_label(ctx.id_gen, [])
    return If(cond, then_region, None, (cont_label, Return([], None)))
  }
  if is_empty_transfer_to_enclosing_cont(ctx, if_label, then_region) &&
    is_abrupt_exit(ctx, else_region) {
    let cont_label = fresh_label(ctx.id_gen, [])
    return If(invert_cond(cond), else_region, None, (cont_label, then_region))
  }
  if is_empty_transfer_to_enclosing_cont(ctx, if_label, else_region) &&
    is_abrupt_exit(ctx, then_region) {
    let cont_label = fresh_label(ctx.id_gen, [])
    return If(cond, then_region, None, (cont_label, else_region))
  }
  let then_abrupt = is_abrupt_exit(ctx, then_region)
  let else_abrupt = is_abrupt_exit(ctx, else_region)
  if then_abrupt && else_abrupt {
    match
      build_direct_exit_guard(ctx, if_label, cond, then_region, else_region) {
      Some(region) => region
      None => build_costed_branch(cond, then_region, else_region)
    }
  } else if else_abrupt {
    let cont_label = fresh_label(ctx.id_gen, [])
    If(invert_cond(cond), else_region, None, (cont_label, then_region))
  } else if then_abrupt {
    let cont_label = fresh_label(ctx.id_gen, [])
    If(cond, then_region, None, (cont_label, else_region))
  } else {
    Branch(cond, then_region, else_region)
  }
}

///|
fn build_cond_region(
  ctx : LoweringContext,
  label : @ssa.Label,
  cond : @ssa.Expr,
  then_target : @ssa.Target,
  else_target : @ssa.Target,
) -> Region {
  let cond = normalize_cond(cond)
  let then_label = target_label(then_target)
  let else_label = target_label(else_target)
  match get_if_join(ctx, label, then_label, else_label) {
    None => {
      let then_region = build_entry_region(ctx, then_target)
      let else_region = build_entry_region(ctx, else_target)
      build_branch_region(ctx, label, cond, then_region, else_region)
    }
    Some(join_label) =>
      if ctx.conts.contains(join_label) {
        let then_region = build_entry_region(ctx, then_target)
        let else_region = build_entry_region(ctx, else_target)
        if should_preserve_abrupt_branch(
            ctx, label, join_label, then_region, else_region,
          ) {
          Branch(cond, then_region, else_region)
        } else {
          let bridge_label = fresh_label_like(ctx.id_gen, join_label)
          let cont_target = bridge_cont_target(ctx, join_label, bridge_label)
          let branch_ctx = {
            ..ctx,
            conts: ctx.conts.add(join_label).add(bridge_label),
            cont_redirects: ctx.cont_redirects.add(
              join_label,
              bridge_redirect_template(join_label, bridge_label),
            ),
          }
          let then_region = build_entry_region(branch_ctx, then_target)
          let else_region = build_entry_region(branch_ctx, else_target)
          let cont_region : Region = Goto(cont_target)
          let (then_region, else_region, cont) = shrink_if_cont_params(
            then_region,
            else_region,
            (bridge_label, cont_region),
          )
          build_if_region(cond, then_region, else_region, cont)
        }
      } else {
        let branch_ctx = { ..ctx, conts: ctx.conts.add(join_label) }
        let then_region = build_entry_region(branch_ctx, then_target)
        let else_region = build_entry_region(branch_ctx, else_target)
        let join_region = build_entry_region(
          ctx,
          target_with_label_args(join_label),
        )
        build_if_region(
          cond,
          then_region,
          else_region,
          (join_label, join_region),
        )
      }
  }
}
