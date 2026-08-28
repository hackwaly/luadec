///|
using @immut/sorted_map {type SortedMap}

///|
using @immut/sorted_set {type SortedSet}

///|
fn expr_equal(lhs : @ssa.Expr, rhs : @ssa.Expr) -> Bool {
  match (lhs, rhs) {
    (ConstE(lhs), ConstE(rhs)) => lhs == rhs
    (VarE(lhs), VarE(rhs)) => lhs == rhs
    (CellE(lhs), CellE(rhs)) => lhs == rhs
    _ => false
  }
}

///|
fn same_target(lhs : @ssa.Target, rhs : @ssa.Target) -> Bool {
  let @ssa.Target(lhs_label, lhs_args) = lhs
  let @ssa.Target(rhs_label, rhs_args) = rhs
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
fn target_is_empty_return(
  blocks : Map[@ssa.Label, @ssa.Block],
  target : @ssa.Target,
) -> Bool {
  let @ssa.Target(label, args) = target
  guard args.length() == 0 && label.params.length() == 0 else { return false }
  match blocks.get(label) {
    Some({ stmts: [], term: @ssa.ReturnT([], None), }) => true
    _ => false
  }
}

///|
fn same_destination(
  blocks : Map[@ssa.Label, @ssa.Block],
  lhs : @ssa.Target,
  rhs : @ssa.Target,
) -> Bool {
  same_target(lhs, rhs) ||
  (target_is_empty_return(blocks, lhs) && target_is_empty_return(blocks, rhs))
}

///|
fn pred_count(
  blocks : SortedMap[@ssa.Label, @ssa.Block],
) -> Map[@ssa.Label, Int] {
  let preds : Map[@ssa.Label, Int] = Map([])
  for _, block in blocks {
    match block.term {
      @ssa.JumpT(@ssa.Target(label, _)) =>
        preds[label] = preds.get(label).unwrap_or(0) + 1
      @ssa.CondT(_, @ssa.Target(true_label, _), @ssa.Target(false_label, _)) => {
        preds[true_label] = preds.get(true_label).unwrap_or(0) + 1
        preds[false_label] = preds.get(false_label).unwrap_or(0) + 1
      }
      @ssa.ReturnT(_, _) => ()
    }
  }
  preds
}

///|
fn get_cond_block(
  blocks : Map[@ssa.Label, @ssa.Block],
  label : @ssa.Label,
) -> (@ssa.Expr, @ssa.Target, @ssa.Target)? {
  match blocks.get(label) {
    Some({ stmts: [], term: @ssa.CondT(rhs, true_target, false_target), }) =>
      Some((rhs, true_target, false_target))
    _ => None
  }
}

///|
fn target_single_arg_expr(target : @ssa.Target) -> (@ssa.Label, @ssa.Expr)? {
  let @ssa.Target(label, args) = target
  match args {
    [arg] => Some((label, arg))
    _ => None
  }
}

///|
fn forwarded_single_arg_expr(
  blocks : Map[@ssa.Label, @ssa.Block],
  target : @ssa.Target,
) -> (@ssa.Label, @ssa.Expr)? {
  match target_single_arg_expr(target) {
    Some(result) => Some(result)
    None => {
      let @ssa.Target(label, args) = target
      match (args, blocks.get(label)) {
        ([], Some({ stmts: [], term: @ssa.JumpT(next), })) =>
          target_single_arg_expr(next)
        _ => None
      }
    }
  }
}

///|
fn resolve_const_expr(
  blocks : Map[@ssa.Label, @ssa.Block],
  target : @ssa.Target,
) -> (@ssa.Label, @ssa.Var, @ssa.Expr, @ssa.Label?)? {
  let @ssa.Target(label, args) = target
  match (args, blocks.get(label)) {
    (
      [],
      Some(
        {
          stmts: [@ssa.BindS(value, @ssa.ConstE(_) as expr)],
          term: @ssa.JumpT(next),
        }
      ),
    ) =>
      match target_single_arg_expr(next) {
        Some((join_label, @ssa.VarE(arg))) if arg == value =>
          Some((join_label, value, expr, Some(label)))
        _ => None
      }
    _ => None
  }
}

///|
fn resolve_boolean_value_target(
  blocks : Map[@ssa.Label, @ssa.Block],
  target : @ssa.Target,
) -> (@ssa.Label, @ssa.Var?, @ssa.Expr, @ssa.Label?)? {
  match resolve_const_expr(blocks, target) {
    Some((join_label, value, expr, drop_label)) =>
      Some((join_label, Some(value), expr, drop_label))
    None =>
      match forwarded_single_arg_expr(blocks, target) {
        Some((join_label, @ssa.VarE(value))) =>
          Some((join_label, Some(value), @ssa.VarE(value), None))
        Some((join_label, expr)) => Some((join_label, None, expr, None))
        None => None
      }
  }
}

///|
fn join_accepts_single_value(label : @ssa.Label) -> Bool {
  label.params.length() == 1
}

///|
fn get_boolean_const(expr : @ssa.Expr) -> Bool? {
  match expr {
    @ssa.ConstE(Boolean(value)) => Some(value)
    _ => None
  }
}

///|
fn negate(expr : @ssa.Expr) -> @ssa.Expr {
  match expr {
    @ssa.UnaryE(Not, inner) => inner
    @ssa.AndE(lhs, rhs) => @ssa.OrE(negate(lhs), negate(rhs))
    @ssa.OrE(lhs, rhs) => @ssa.UnaryE(Not, @ssa.AndE(negate(lhs), negate(rhs)))
    _ => @ssa.UnaryE(Not, expr)
  }
}

///|
fn normalize_bool_expr(expr : @ssa.Expr) -> @ssa.Expr {
  match expr {
    @ssa.AndE(lhs, rhs) =>
      @ssa.AndE(normalize_bool_expr(lhs), normalize_bool_expr(rhs))
    @ssa.OrE(@ssa.UnaryE(Not, lhs), @ssa.UnaryE(Not, rhs)) =>
      @ssa.UnaryE(
        Not,
        @ssa.AndE(normalize_bool_expr(lhs), normalize_bool_expr(rhs)),
      )
    @ssa.OrE(lhs, rhs) =>
      @ssa.OrE(normalize_bool_expr(lhs), normalize_bool_expr(rhs))
    @ssa.UnaryE(Not, inner) => negate(normalize_bool_expr(inner))
    _ => expr
  }
}

///|
fn boolean_expr_for_targets(
  cond : @ssa.Expr,
  true_arg : @ssa.Expr,
  false_arg : @ssa.Expr,
) -> @ssa.Expr? {
  match (get_boolean_const(true_arg), get_boolean_const(false_arg)) {
    (Some(true), Some(false)) => Some(cond)
    (Some(false), Some(true)) => Some(negate(cond))
    _ => None
  }
}

///|
fn invert_condition_expr(expr : @ssa.Expr) -> @ssa.Expr {
  match expr {
    @ssa.UnaryE(Not, inner) => inner
    @ssa.BinaryE(op, lhs, rhs) =>
      match invert_binary_op(op) {
        Some(op) => @ssa.BinaryE(op, lhs, rhs)
        None => @ssa.UnaryE(Not, expr)
      }
    @ssa.AndE(lhs, rhs) =>
      @ssa.OrE(invert_condition_expr(lhs), invert_condition_expr(rhs))
    @ssa.OrE(lhs, rhs) =>
      @ssa.AndE(invert_condition_expr(lhs), invert_condition_expr(rhs))
    _ => @ssa.UnaryE(Not, expr)
  }
}

///|
fn truthy_expr_when_cond_false(
  cond : @ssa.Expr,
  false_arg : @ssa.Expr,
) -> @ssa.Expr? {
  match cond {
    @ssa.OrE(lhs, @ssa.UnaryE(Not, rhs)) if expr_equal(rhs, false_arg) =>
      Some(
        normalize_bool_expr(@ssa.AndE(invert_condition_expr(lhs), false_arg)),
      )
    @ssa.OrE(@ssa.UnaryE(Not, lhs), rhs) if expr_equal(lhs, false_arg) =>
      Some(
        normalize_bool_expr(@ssa.AndE(invert_condition_expr(rhs), false_arg)),
      )
    @ssa.UnaryE(Not, inner) if expr_equal(inner, false_arg) => Some(false_arg)
    _ => None
  }
}

///|
fn value_expr_for_targets(
  cond : @ssa.Expr,
  true_arg : @ssa.Expr,
  false_arg : @ssa.Expr,
) -> @ssa.Expr? {
  match boolean_expr_for_targets(cond, true_arg, false_arg) {
    Some(expr) => Some(expr)
    None =>
      match truthy_expr_when_cond_false(cond, false_arg) {
        Some(false_value) =>
          Some(normalize_bool_expr(@ssa.OrE(false_value, true_arg)))
        None =>
          match (cond, true_arg, false_arg) {
            (@ssa.VarE(lhs), rhs, @ssa.VarE(lhs2)) if lhs == lhs2 =>
              Some(normalize_bool_expr(@ssa.AndE(@ssa.VarE(lhs), rhs)))
            (@ssa.VarE(lhs), @ssa.VarE(lhs2), rhs) if lhs == lhs2 =>
              Some(normalize_bool_expr(@ssa.OrE(@ssa.VarE(lhs), rhs)))
            _ => None
          }
      }
  }
}

///|
fn rewrite_value_expr(
  id_gen : @ssa.IdGen,
  blocks : Map[@ssa.Label, @ssa.Block],
  preds : Map[@ssa.Label, Int],
  block : @ssa.Block,
) -> (@ssa.Block, SortedSet[@ssa.Label])? {
  match block.term {
    @ssa.CondT(cond, true_target, false_target) =>
      match
        (
          resolve_boolean_value_target(blocks, true_target),
          resolve_boolean_value_target(blocks, false_target),
        ) {
        (
          Some((join_label, _, true_arg, true_drop)),
          Some((join_label2, _, false_arg, false_drop)),
        ) if join_label == join_label2 && join_accepts_single_value(join_label) =>
          match value_expr_for_targets(cond, true_arg, false_arg) {
            Some(expr) => {
              let result : @ssa.Var = { id: id_gen.next(), }
              let mut removed : SortedSet[@ssa.Label] = SortedSet::new()
              match true_drop {
                Some(label) =>
                  if preds.get(label).unwrap_or(0) == 1 {
                    removed = removed.add(label)
                  }
                None => ()
              }
              match false_drop {
                Some(label) =>
                  if preds.get(label).unwrap_or(0) == 1 {
                    removed = removed.add(label)
                  }
                None => ()
              }
              Some(
                (
                  {
                    stmts: [..block.stmts, @ssa.BindS(result, expr)],
                    term: @ssa.JumpT(
                      @ssa.Target(join_label, [@ssa.VarE(result)]),
                    ),
                  },
                  removed,
                ),
              )
            }
            None => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn rewrite_cond_and_or(
  blocks : Map[@ssa.Label, @ssa.Block],
  preds : Map[@ssa.Label, Int],
  block : @ssa.Block,
) -> (@ssa.Block, SortedSet[@ssa.Label])? {
  match block.term {
    @ssa.CondT(lhs, @ssa.Target(rhs_label, []), false_target) if preds
      .get(rhs_label)
      .unwrap_or(0) ==
      1 =>
      match get_cond_block(blocks, rhs_label) {
        Some((rhs, true_target, rhs_false)) if same_destination(
            blocks, rhs_false, false_target,
          ) =>
          Some(
            (
              {
                stmts: block.stmts,
                term: @ssa.CondT(
                  normalize_bool_expr(@ssa.AndE(lhs, rhs)),
                  true_target,
                  false_target,
                ),
              },
              SortedSet::new().add(rhs_label),
            ),
          )
        Some((rhs, rhs_true, false_target2)) if same_destination(
            blocks, rhs_true, false_target,
          ) =>
          Some(
            (
              {
                stmts: block.stmts,
                term: @ssa.CondT(
                  normalize_bool_expr(@ssa.AndE(lhs, negate(rhs))),
                  false_target2,
                  false_target,
                ),
              },
              SortedSet::new().add(rhs_label),
            ),
          )
        _ => None
      }
    @ssa.CondT(lhs, true_target, @ssa.Target(rhs_label, [])) if preds
      .get(rhs_label)
      .unwrap_or(0) ==
      1 =>
      match get_cond_block(blocks, rhs_label) {
        Some((rhs, rhs_true, false_target)) if same_destination(
            blocks, rhs_true, true_target,
          ) =>
          Some(
            (
              {
                stmts: block.stmts,
                term: @ssa.CondT(
                  normalize_bool_expr(@ssa.OrE(lhs, rhs)),
                  true_target,
                  false_target,
                ),
              },
              SortedSet::new().add(rhs_label),
            ),
          )
        Some((rhs, true_target2, rhs_false)) if same_destination(
            blocks, rhs_false, true_target,
          ) =>
          Some(
            (
              {
                stmts: block.stmts,
                term: @ssa.CondT(
                  normalize_bool_expr(@ssa.OrE(lhs, negate(rhs))),
                  true_target,
                  true_target2,
                ),
              },
              SortedSet::new().add(rhs_label),
            ),
          )
        _ => None
      }
    _ => None
  }
}

///|
fn try_rewrite_block(
  id_gen : @ssa.IdGen,
  blocks : Map[@ssa.Label, @ssa.Block],
  preds : Map[@ssa.Label, Int],
  block : @ssa.Block,
) -> (@ssa.Block, SortedSet[@ssa.Label])? {
  match rewrite_value_expr(id_gen, blocks, preds, block) {
    Some(result) => Some(result)
    None => rewrite_cond_and_or(blocks, preds, block)
  }
}

///|
fn recover_func(id_gen : @ssa.IdGen, func : @ssa.Func) -> @ssa.Func {
  let mut current = func
  let mut changed = true
  while changed {
    changed = false
    let blocks : Map[@ssa.Label, @ssa.Block] = Map([])
    for label, block in current.blocks {
      blocks[label] = block
    }
    let preds = pred_count(current.blocks)
    let mut removed : SortedSet[@ssa.Label] = SortedSet::new()
    let mut out_blocks : SortedMap[@ssa.Label, @ssa.Block] = SortedMap::new()
    for label, block in current.blocks {
      if removed.contains(label) {
        changed = true
        continue
      }
      match try_rewrite_block(id_gen, blocks, preds, block) {
        Some((next_block, next_removed)) => {
          changed = true
          for removed_label in next_removed {
            removed = removed.add(removed_label)
          }
          out_blocks = out_blocks.add(label, next_block)
        }
        None => out_blocks = out_blocks.add(label, block)
      }
    }
    if changed {
      current = { ..current, blocks: out_blocks, }
    }
  }
  current
}

///|
pub fn recover_boolean(program : @ssa.Program) -> @ssa.Program {
  {
    _id_gen: program._id_gen,
    funcs: program.funcs.map(fn(func) { recover_func(program._id_gen, func) }),
    main: program.main,
  }
}
