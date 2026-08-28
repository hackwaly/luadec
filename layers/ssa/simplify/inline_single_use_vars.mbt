///|
priv struct Candidates {
  order : Array[@ssa.Var]
  exprs : SortedMap[@ssa.Var, @ssa.Expr]
}

///|
fn empty_candidates() -> Candidates {
  { order: [], exprs: SortedMap::new(), }
}

///|
fn candidates_get(candidates : Candidates, value : @ssa.Var) -> @ssa.Expr? {
  candidates.exprs.get(value)
}

///|
fn candidates_add(
  candidates : Candidates,
  value : @ssa.Var,
  expr : @ssa.Expr,
) -> Candidates {
  {
    order: [..candidates.order, value],
    exprs: candidates.exprs.add(value, expr),
  }
}

///|
fn candidates_remove(candidates : Candidates, value : @ssa.Var) -> Candidates {
  { ..candidates, exprs: candidates.exprs.remove(value), }
}

///|
fn candidates_merge(lhs : Candidates, rhs : Candidates) -> Candidates {
  let mut merged = lhs
  for value in rhs.order {
    match rhs.exprs.get(value) {
      Some(expr) =>
        if merged.exprs.get(value) is None {
          merged = candidates_add(merged, value, expr)
        }
      None => ()
    }
  }
  merged
}

///|
fn candidates_partition(
  candidates : Candidates,
  mentioned : Map[@ssa.Var, Bool],
) -> (Candidates, Candidates) {
  let mut selected = empty_candidates()
  let mut rest = empty_candidates()
  for value in candidates.order {
    match candidates.exprs.get(value) {
      Some(expr) =>
        if mentioned.get(value).unwrap_or(false) {
          selected = candidates_add(selected, value, expr)
        } else {
          rest = candidates_add(rest, value, expr)
        }
      None => ()
    }
  }
  (selected, rest)
}

///|
fn mark_deleted(deleted : Map[@ssa.Var, Bool], value : @ssa.Var) -> Unit {
  deleted[value] = true
}

///|
fn push_if_not_deleted(
  out : Array[@ssa.Stmt],
  deleted : Map[@ssa.Var, Bool],
  stmt : @ssa.Stmt,
) -> Unit {
  match stmt {
    @ssa.BindS(value, _) if deleted.get(value) is Some(true) => ()
    _ => out.push(stmt)
  }
}

///|
fn filter_deleted_stmts(
  stmts : Array[@ssa.Stmt],
  deleted : Map[@ssa.Var, Bool],
) -> Array[@ssa.Stmt] {
  let out : Array[@ssa.Stmt] = []
  for stmt in stmts {
    push_if_not_deleted(out, deleted, stmt)
  }
  out
}

///|
fn can_cross_ctrl_boundary(expr : @ssa.Expr) -> Bool {
  match expr {
    @ssa.ConstE(_) | @ssa.VarE(_) => true
    _ => false
  }
}

///|
fn split_ctrl_boundary_candidates(
  candidates : Candidates,
) -> (Candidates, Candidates) {
  let mut movable = empty_candidates()
  let mut pinned = empty_candidates()
  for value in candidates.order {
    match candidates.exprs.get(value) {
      Some(expr) =>
        if can_cross_ctrl_boundary(expr) {
          movable = candidates_add(movable, value, expr)
        } else {
          pinned = candidates_add(pinned, value, expr)
        }
      None => ()
    }
  }
  (movable, pinned)
}

///|
fn process_exprs(
  changed : Array[Bool],
  deleted : Map[@ssa.Var, Bool],
  index_as_side_effect : Bool,
  candidates : Candidates,
  exprs : Array[@ssa.Expr],
) -> (Candidates, Candidates, Array[@ssa.Expr]) {
  let mut before = empty_candidates()
  let mut after = candidates
  let out : Array[@ssa.Expr] = []
  for expr in exprs {
    let (next_before, next_after, next_expr) = process_expr(
      changed, deleted, index_as_side_effect, after, expr,
    )
    before = candidates_merge(before, next_before)
    after = next_after
    out.push(next_expr)
  }
  (before, after, out)
}

///|
fn process_target(
  changed : Array[Bool],
  deleted : Map[@ssa.Var, Bool],
  candidates : Candidates,
  target : @ssa.Target,
) -> (Candidates, Candidates, @ssa.Target) {
  let @ssa.Target(label, args) = target
  let mut before = empty_candidates()
  let mut after = candidates
  let rewritten : Array[@ssa.Expr] = []
  for arg in args {
    match arg {
      @ssa.VarE(value) =>
        match candidates_get(after, value) {
          Some(expr) => {
            changed[0] = true
            mark_deleted(deleted, value)
            after = candidates_remove(after, value)
            rewritten.push(expr)
          }
          _ => {
            let mentioned : Map[@ssa.Var, Bool] = Map([])
            mentioned[value] = true
            let (selected, rest) = candidates_partition(after, mentioned)
            before = candidates_merge(before, selected)
            after = rest
            rewritten.push(arg)
          }
        }
      _ => {
        let mentioned = @ssa/util.mentioned_in_expr(arg)
        let (selected, rest) = candidates_partition(after, mentioned)
        before = candidates_merge(before, selected)
        after = rest
        rewritten.push(arg)
      }
    }
  }
  (before, after, @ssa.Target(label, rewritten))
}

///|
fn process_call(
  changed : Array[Bool],
  deleted : Map[@ssa.Var, Bool],
  index_as_side_effect : Bool,
  candidates : Candidates,
  call : @ssa.Call,
) -> (Candidates, Candidates, @ssa.Call) {
  match call {
    @ssa.NormalC(callee, args, multi) => {
      let (before_callee, after_callee, callee) = process_expr(
        changed, deleted, index_as_side_effect, candidates, callee,
      )
      let (before_args, after_args, args) = process_exprs(
        changed, deleted, index_as_side_effect, after_callee, args,
      )
      let (before_multi, after_multi, multi) = match multi {
        Some(multi) => {
          let (before_multi, after_multi, multi) = process_multi(
            changed, deleted, index_as_side_effect, after_args, multi,
          )
          (before_multi, after_multi, Some(multi))
        }
        None => (empty_candidates(), after_args, None)
      }
      let (passthrough, pinned) = split_ctrl_boundary_candidates(after_multi)
      (
        candidates_merge(
          candidates_merge(before_callee, before_args),
          candidates_merge(before_multi, pinned),
        ),
        passthrough,
        @ssa.NormalC(callee, args, multi),
      )
    }
    @ssa.MethodC(target, method_name, args, multi) => {
      let (before_target, after_target, target) = process_expr(
        changed, deleted, index_as_side_effect, candidates, target,
      )
      let (before_args, after_args, args) = process_exprs(
        changed, deleted, index_as_side_effect, after_target, args,
      )
      let (before_multi, after_multi, multi) = match multi {
        Some(multi) => {
          let (before_multi, after_multi, multi) = process_multi(
            changed, deleted, index_as_side_effect, after_args, multi,
          )
          (before_multi, after_multi, Some(multi))
        }
        None => (empty_candidates(), after_args, None)
      }
      let (passthrough, pinned) = split_ctrl_boundary_candidates(after_multi)
      (
        candidates_merge(
          candidates_merge(before_target, before_args),
          candidates_merge(before_multi, pinned),
        ),
        passthrough,
        @ssa.MethodC(target, method_name, args, multi),
      )
    }
  }
}

///|
fn process_multi(
  changed : Array[Bool],
  deleted : Map[@ssa.Var, Bool],
  index_as_side_effect : Bool,
  candidates : Candidates,
  multi : @ssa.Multi,
) -> (Candidates, Candidates, @ssa.Multi) {
  match multi {
    @ssa.VarargM => (empty_candidates(), candidates, @ssa.VarargM)
    @ssa.CallM(call) => {
      let (before, after, call) = process_call(
        changed, deleted, index_as_side_effect, candidates, call,
      )
      (before, after, @ssa.CallM(call))
    }
  }
}

///|
fn process_expr(
  changed : Array[Bool],
  deleted : Map[@ssa.Var, Bool],
  index_as_side_effect : Bool,
  candidates : Candidates,
  expr : @ssa.Expr,
) -> (Candidates, Candidates, @ssa.Expr) {
  match expr {
    @ssa.ConstE(_) | @ssa.CellE(_) as expr =>
      (empty_candidates(), candidates, expr)
    @ssa.VarE(value) as expr =>
      match candidates_get(candidates, value) {
        Some(inlined) => {
          changed[0] = true
          mark_deleted(deleted, value)
          (empty_candidates(), candidates_remove(candidates, value), inlined)
        }
        None => (empty_candidates(), candidates, expr)
      }
    @ssa.NumericForCheckE(ctrl, limit, step) => {
      let (before_ctrl, after_ctrl, ctrl) = process_expr(
        changed, deleted, index_as_side_effect, candidates, ctrl,
      )
      let (before_limit, after_limit, limit) = process_expr(
        changed, deleted, index_as_side_effect, after_ctrl, limit,
      )
      let (before_step, after_step, step) = process_expr(
        changed, deleted, index_as_side_effect, after_limit, step,
      )
      (
        candidates_merge(
          candidates_merge(before_ctrl, before_limit),
          candidates_merge(before_step, after_step),
        ),
        empty_candidates(),
        @ssa.NumericForCheckE(ctrl, limit, step),
      )
    }
    @ssa.IndexE(target, key) => {
      let (before_target, after_target, target) = process_expr(
        changed, deleted, index_as_side_effect, candidates, target,
      )
      let (before_key, after_key, key) = process_expr(
        changed, deleted, index_as_side_effect, after_target, key,
      )
      if index_as_side_effect {
        let (passthrough, pinned) = split_ctrl_boundary_candidates(after_key)
        (
          candidates_merge(candidates_merge(before_target, before_key), pinned),
          passthrough,
          @ssa.IndexE(target, key),
        )
      } else {
        (
          candidates_merge(before_target, before_key),
          after_key,
          @ssa.IndexE(target, key),
        )
      }
    }
    @ssa.TableE(init) => {
      let (before, after, init) = process_table_init(
        changed, deleted, index_as_side_effect, candidates, init,
      )
      (before, after, @ssa.TableE(init))
    }
    @ssa.UnaryE(op, inner) => {
      let (before, after, inner) = process_expr(
        changed, deleted, index_as_side_effect, candidates, inner,
      )
      match op {
        Not => (before, after, @ssa.UnaryE(op, inner))
        _ =>
          (
            candidates_merge(before, after),
            empty_candidates(),
            @ssa.UnaryE(op, inner),
          )
      }
    }
    @ssa.BinaryE(op, lhs, rhs) => {
      let (before_lhs, after_lhs, lhs) = process_expr(
        changed, deleted, index_as_side_effect, candidates, lhs,
      )
      let (before_rhs, after_rhs, rhs) = process_expr(
        changed, deleted, index_as_side_effect, after_lhs, rhs,
      )
      (
        candidates_merge(candidates_merge(before_lhs, before_rhs), after_rhs),
        empty_candidates(),
        @ssa.BinaryE(op, lhs, rhs),
      )
    }
    @ssa.AndE(lhs, rhs) => {
      let (before_lhs, after_lhs, lhs) = process_expr(
        changed, deleted, index_as_side_effect, candidates, lhs,
      )
      let (before_rhs, after_rhs, rhs) = process_expr(
        changed, deleted, index_as_side_effect, after_lhs, rhs,
      )
      (
        candidates_merge(candidates_merge(before_lhs, before_rhs), after_rhs),
        empty_candidates(),
        @ssa.AndE(lhs, rhs),
      )
    }
    @ssa.OrE(lhs, rhs) => {
      let (before_lhs, after_lhs, lhs) = process_expr(
        changed, deleted, index_as_side_effect, candidates, lhs,
      )
      let (before_rhs, after_rhs, rhs) = process_expr(
        changed, deleted, index_as_side_effect, after_lhs, rhs,
      )
      (
        candidates_merge(candidates_merge(before_lhs, before_rhs), after_rhs),
        empty_candidates(),
        @ssa.OrE(lhs, rhs),
      )
    }
    @ssa.CallE(call) => {
      let (before, after, call) = process_call(
        changed, deleted, index_as_side_effect, candidates, call,
      )
      (before, after, @ssa.CallE(call))
    }
    @ssa.ClosureE(_, _) as expr => (candidates, empty_candidates(), expr)
  }
}

///|
fn process_table_init(
  changed : Array[Bool],
  deleted : Map[@ssa.Var, Bool],
  index_as_side_effect : Bool,
  candidates : Candidates,
  init : @ssa.TableInit,
) -> (Candidates, Candidates, @ssa.TableInit) {
  match init {
    @ssa.EmptyTI => (empty_candidates(), candidates, @ssa.EmptyTI)
    @ssa.ArrayTI(items, multi) => {
      let (before, after, items) = process_exprs(
        changed, deleted, index_as_side_effect, candidates, items,
      )
      let (before_multi, after_multi, multi) = match multi {
        Some(multi) => {
          let (before_multi, after_multi, multi) = process_multi(
            changed, deleted, index_as_side_effect, after, multi,
          )
          (before_multi, after_multi, Some(multi))
        }
        None => (empty_candidates(), after, None)
      }
      (
        candidates_merge(before, before_multi),
        after_multi,
        @ssa.ArrayTI(items, multi),
      )
    }
    @ssa.TableTI(fields) => {
      let mut before = empty_candidates()
      let mut after = candidates
      let rewritten : Array[(@ssa.Expr, @ssa.Expr)] = []
      for field in fields {
        let (key, value) = field
        let (before_key, after_key, key) = process_expr(
          changed, deleted, index_as_side_effect, after, key,
        )
        let (before_value, after_value, value) = process_expr(
          changed, deleted, index_as_side_effect, after_key, value,
        )
        before = candidates_merge(
          before,
          candidates_merge(before_key, before_value),
        )
        after = after_value
        rewritten.push((key, value))
      }
      (before, after, @ssa.TableTI(rewritten))
    }
  }
}

///|
fn process_stmt(
  changed : Array[Bool],
  deleted : Map[@ssa.Var, Bool],
  index_as_side_effect : Bool,
  use_count : Map[@ssa.Var, Int],
  candidates : Candidates,
  stmt : @ssa.Stmt,
) -> (Candidates, Candidates, @ssa.Stmt?) {
  match stmt {
    @ssa.BindS(value, expr) => {
      let (before, after, expr) = process_expr(
        changed, deleted, index_as_side_effect, candidates, expr,
      )
      if use_count.get(value).unwrap_or(0) == 1 {
        (
          before,
          candidates_add(after, value, expr),
          Some(@ssa.BindS(value, expr)),
        )
      } else {
        (before, after, Some(@ssa.BindS(value, expr)))
      }
    }
    @ssa.StoreCellS(cell, expr) => {
      let (before, after, expr) = process_expr(
        changed, deleted, index_as_side_effect, candidates, expr,
      )
      (
        candidates_merge(before, after),
        empty_candidates(),
        Some(@ssa.StoreCellS(cell, expr)),
      )
    }
    @ssa.SetIndexS(target, key, value) => {
      let mentioned = @ssa/util.mentioned_in_expr(target)
      let (target_deps, candidates) = candidates_partition(
        candidates, mentioned,
      )
      let (before_target, after_target, target) = process_expr(
        changed,
        deleted,
        index_as_side_effect,
        empty_candidates(),
        target,
      )
      let (before_key, after_key, key) = process_expr(
        changed,
        deleted,
        index_as_side_effect,
        candidates_merge(candidates, after_target),
        key,
      )
      let (before_value, after_value, value) = process_expr(
        changed, deleted, index_as_side_effect, after_key, value,
      )
      (
        candidates_merge(
          candidates_merge(
            candidates_merge(
              candidates_merge(target_deps, before_target),
              before_key,
            ),
            before_value,
          ),
          after_value,
        ),
        empty_candidates(),
        Some(@ssa.SetIndexS(target, key, value)),
      )
    }
    @ssa.BindMultiS(values, multi) => {
      let (before, after, multi) = process_multi(
        changed, deleted, index_as_side_effect, candidates, multi,
      )
      (before, after, Some(@ssa.BindMultiS(values, multi)))
    }
    @ssa.SetListS(target, index, values, multi) => {
      let mentioned = @ssa/util.mentioned_in_expr(target)
      let (target_deps, candidates) = candidates_partition(
        candidates, mentioned,
      )
      let (before_target, after_target, target) = process_expr(
        changed,
        deleted,
        index_as_side_effect,
        empty_candidates(),
        target,
      )
      let (before_index, after_index, index) = process_expr(
        changed,
        deleted,
        index_as_side_effect,
        candidates_merge(candidates, after_target),
        index,
      )
      let (before_values, after_values, values) = process_exprs(
        changed, deleted, index_as_side_effect, after_index, values,
      )
      let (before_multi, after_multi, multi) = match multi {
        Some(multi) => {
          let (before_multi, after_multi, multi) = process_multi(
            changed, deleted, index_as_side_effect, after_values, multi,
          )
          (before_multi, after_multi, Some(multi))
        }
        None => (empty_candidates(), after_values, None)
      }
      let before = candidates_merge(target_deps, before_target)
      let before = candidates_merge(before, before_index)
      let before = candidates_merge(before, before_values)
      let before = candidates_merge(before, before_multi)
      let before = candidates_merge(before, after_multi)
      (
        before,
        empty_candidates(),
        Some(@ssa.SetListS(target, index, values, multi)),
      )
    }
  }
}

///|
fn process_term(
  changed : Array[Bool],
  deleted : Map[@ssa.Var, Bool],
  index_as_side_effect : Bool,
  candidates : Candidates,
  term : @ssa.Term,
) -> (Candidates, Candidates, @ssa.Term) {
  match term {
    @ssa.JumpT(target) => {
      let (before, after, target) = process_target(
        changed, deleted, candidates, target,
      )
      (before, after, @ssa.JumpT(target))
    }
    @ssa.CondT(cond, true_target, false_target) => {
      let (before_cond, after_cond, cond) = process_expr(
        changed, deleted, index_as_side_effect, candidates, cond,
      )
      let (movable, pinned) = split_ctrl_boundary_candidates(after_cond)
      let (true_candidates, rest0) = candidates_partition(
        movable,
        @ssa/util.mentioned_in_target(true_target),
      )
      let (false_candidates, rest1) = candidates_partition(
        rest0,
        @ssa/util.mentioned_in_target(false_target),
      )
      let (before_true, after_true, true_target) = process_target(
        changed, deleted, true_candidates, true_target,
      )
      let (before_false, after_false, false_target) = process_target(
        changed, deleted, false_candidates, false_target,
      )
      (
        candidates_merge(
          candidates_merge(
            candidates_merge(before_cond, pinned),
            candidates_merge(rest1, candidates_merge(before_true, after_true)),
          ),
          candidates_merge(before_false, after_false),
        ),
        empty_candidates(),
        @ssa.CondT(cond, true_target, false_target),
      )
    }
    @ssa.ReturnT(values, multi) => {
      let (before_values, after_values, values) = process_exprs(
        changed, deleted, index_as_side_effect, candidates, values,
      )
      let (before_multi, after_multi, multi) = match multi {
        Some(multi) => {
          let (before_multi, after_multi, multi) = process_multi(
            changed, deleted, index_as_side_effect, after_values, multi,
          )
          (before_multi, after_multi, Some(multi))
        }
        None => (empty_candidates(), after_values, None)
      }
      (
        candidates_merge(before_values, before_multi),
        after_multi,
        @ssa.ReturnT(values, multi),
      )
    }
  }
}

///|
fn process_block(
  changed : Array[Bool],
  index_as_side_effect : Bool,
  use_count : Map[@ssa.Var, Int],
  block : @ssa.Block,
) -> @ssa.Block {
  let out : Array[@ssa.Stmt] = []
  let mut candidates = empty_candidates()
  let deleted : Map[@ssa.Var, Bool] = Map([])
  for stmt in block.stmts {
    let (_, after, stmt) = process_stmt(
      changed, deleted, index_as_side_effect, use_count, candidates, stmt,
    )
    match stmt {
      Some(stmt) => out.push(stmt)
      None => ()
    }
    candidates = after
  }
  let (_, _, term) = process_term(
    changed,
    deleted,
    index_as_side_effect,
    candidates,
    block.term,
  )
  { stmts: filter_deleted_stmts(out, deleted), term, }
}

///|
fn inline_single_use_vars_func(
  func : @ssa.Func,
  index_as_side_effect : Bool,
) -> (@ssa.Func, Bool) {
  let mut current = func
  let mut changed_any = false
  let mut done = false
  while !done {
    let changed = [false]
    let use_count = @ssa/util.analyze_use_count(current)
    let mut blocks : SortedMap[@ssa.Label, @ssa.Block] = SortedMap::new()
    for label, block in current.blocks {
      blocks = blocks.add(
        label,
        process_block(changed, index_as_side_effect, use_count, block),
      )
    }
    if !changed[0] {
      done = true
    } else {
      current = { ..current, blocks, entry: current.entry, }
      changed_any = true
    }
  }
  (current, changed_any)
}
