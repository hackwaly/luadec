///|
fn contains_label(labels : Array[@ssa.Label], target : @ssa.Label) -> Bool {
  let mut found = false
  for label in labels {
    if label == target {
      found = true
    }
  }
  found
}

///|
fn is_forwarding_block(label : @ssa.Label, block : @ssa.Block) -> Bool {
  if label.params.length() != 0 || block.stmts.length() != 0 {
    false
  } else {
    match block.term {
      @ssa.JumpT(_) => true
      _ => false
    }
  }
}

///|
fn rewrite_capture(
  subst : Map[@ssa.Var, @ssa.Expr],
  capture : @ssa.Var,
) -> @ssa.Var {
  match subst.get(capture) {
    Some(@ssa.VarE(next)) => next
    Some(_) => panic()
    None => capture
  }
}

///|
fn rewrite_call(
  subst : Map[@ssa.Var, @ssa.Expr],
  call : @ssa.Call,
) -> @ssa.Call {
  match call {
    @ssa.NormalC(callee, args, multi) =>
      @ssa.NormalC(
        rewrite_expr(subst, callee),
        args.map(fn(arg) { rewrite_expr(subst, arg) }),
        multi.map(fn(tail) { rewrite_multi(subst, tail) }),
      )
    @ssa.MethodC(target, method_name, args, multi) =>
      @ssa.MethodC(
        rewrite_expr(subst, target),
        method_name,
        args.map(fn(arg) { rewrite_expr(subst, arg) }),
        multi.map(fn(tail) { rewrite_multi(subst, tail) }),
      )
  }
}

///|
fn rewrite_table_init(
  subst : Map[@ssa.Var, @ssa.Expr],
  init : @ssa.TableInit,
) -> @ssa.TableInit {
  match init {
    @ssa.EmptyTI => @ssa.EmptyTI
    @ssa.ArrayTI(items, multi) =>
      @ssa.ArrayTI(
        items.map(fn(item) { rewrite_expr(subst, item) }),
        multi.map(fn(tail) { rewrite_multi(subst, tail) }),
      )
    @ssa.TableTI(fields) => {
      let rewritten : Array[(@ssa.Expr, @ssa.Expr)] = []
      for field in fields {
        let (key, value) = field
        rewritten.push((rewrite_expr(subst, key), rewrite_expr(subst, value)))
      }
      @ssa.TableTI(rewritten)
    }
  }
}

///|
fn rewrite_multi(
  subst : Map[@ssa.Var, @ssa.Expr],
  multi : @ssa.Multi,
) -> @ssa.Multi {
  match multi {
    @ssa.VarargM => @ssa.VarargM
    @ssa.CallM(call) => @ssa.CallM(rewrite_call(subst, call))
  }
}

///|
fn rewrite_expr(
  subst : Map[@ssa.Var, @ssa.Expr],
  expr : @ssa.Expr,
) -> @ssa.Expr {
  match expr {
    @ssa.ConstE(_) => expr
    @ssa.VarE(value) =>
      match subst.get(value) {
        Some(next) => next
        None => expr
      }
    @ssa.CellE(_) => expr
    @ssa.NumericForCheckE(ctrl, limit, step) =>
      @ssa.NumericForCheckE(
        rewrite_expr(subst, ctrl),
        rewrite_expr(subst, limit),
        rewrite_expr(subst, step),
      )
    @ssa.IndexE(target, key) =>
      @ssa.IndexE(rewrite_expr(subst, target), rewrite_expr(subst, key))
    @ssa.TableE(init) => @ssa.TableE(rewrite_table_init(subst, init))
    @ssa.UnaryE(op, inner) => @ssa.UnaryE(op, rewrite_expr(subst, inner))
    @ssa.BinaryE(op, lhs, rhs) =>
      @ssa.BinaryE(op, rewrite_expr(subst, lhs), rewrite_expr(subst, rhs))
    @ssa.AndE(lhs, rhs) =>
      @ssa.AndE(rewrite_expr(subst, lhs), rewrite_expr(subst, rhs))
    @ssa.OrE(lhs, rhs) =>
      @ssa.OrE(rewrite_expr(subst, lhs), rewrite_expr(subst, rhs))
    @ssa.CallE(call) => @ssa.CallE(rewrite_call(subst, call))
    @ssa.ClosureE(id, captures) =>
      @ssa.ClosureE(
        id,
        captures.map(fn(capture) { rewrite_capture(subst, capture) }),
      )
  }
}

///|
fn rewrite_target_args(
  subst : Map[@ssa.Var, @ssa.Expr],
  target : @ssa.Target,
) -> @ssa.Target {
  let @ssa.Target(label, args) = target
  @ssa.Target(label, args.map(fn(arg) { rewrite_expr(subst, arg) }))
}

///|
fn build_subst(
  params : Array[@ssa.Var],
  args : Array[@ssa.Expr],
) -> Map[@ssa.Var, @ssa.Expr] {
  guard params.length() == args.length() else { panic() }
  let subst : Map[@ssa.Var, @ssa.Expr] = {}
  for i in 0..<params.length() {
    subst[params[i]] = args[i]
  }
  subst
}

///|
fn compose_target(
  label : @ssa.Label,
  block : @ssa.Block,
  args : Array[@ssa.Expr],
) -> @ssa.Target {
  match block.term {
    @ssa.JumpT(target) =>
      rewrite_target_args(build_subst(label.params, args), target)
    _ => panic()
  }
}

///|
fn redirect_target(
  blocks : Map[@ssa.Label, @ssa.Block],
  target : @ssa.Target,
) -> @ssa.Target {
  let seen : Array[@ssa.Label] = []
  let mut current = target
  let mut done = false
  while !done {
    let @ssa.Target(label, args) = current
    if contains_label(seen, label) {
      done = true
    } else {
      seen.push(label)
      match blocks.get(label) {
        Some(block) =>
          if is_forwarding_block(label, block) {
            current = compose_target(label, block, args)
          } else {
            done = true
          }
        None => done = true
      }
    }
  }
  current
}

///|
fn redirect_term(
  blocks : Map[@ssa.Label, @ssa.Block],
  term : @ssa.Term,
) -> @ssa.Term {
  match term {
    @ssa.JumpT(target) => @ssa.JumpT(redirect_target(blocks, target))
    @ssa.CondT(cond, true_target, false_target) =>
      @ssa.CondT(
        cond,
        redirect_target(blocks, true_target),
        redirect_target(blocks, false_target),
      )
    @ssa.ReturnT(_, _) => term
  }
}

///|
fn successor_labels(term : @ssa.Term) -> Array[@ssa.Label] {
  match term {
    @ssa.JumpT(@ssa.Target(label, _)) => [label]
    @ssa.CondT(_, @ssa.Target(true_label, _), @ssa.Target(false_label, _)) =>
      [true_label, false_label]
    @ssa.ReturnT(_, _) => []
  }
}

///|
fn reachable_labels(
  entry : @ssa.Label,
  blocks : Map[@ssa.Label, @ssa.Block],
) -> Array[@ssa.Label] {
  let order : Array[@ssa.Label] = []
  let worklist : Array[@ssa.Label] = [entry]
  while worklist.pop() is Some(label) {
    if contains_label(order, label) {
      continue
    }
    order.push(label)
    match blocks.get(label) {
      Some(block) =>
        for next in successor_labels(block.term) {
          if !contains_label(order, next) && !contains_label(worklist, next) {
            worklist.push(next)
          }
        }
      None => panic()
    }
  }
  order
}

///|
fn add_predecessor(
  preds : Map[@ssa.Label, Array[@ssa.Label]],
  label : @ssa.Label,
  pred : @ssa.Label,
) -> Unit {
  match preds.get(label) {
    Some(items) => if !contains_label(items, pred) { items.push(pred) }
    None => preds[label] = [pred]
  }
}

///|
fn collect_predecessors(
  entry : @ssa.Label,
  blocks : Map[@ssa.Label, @ssa.Block],
) -> Map[@ssa.Label, Array[@ssa.Label]] {
  let preds : Map[@ssa.Label, Array[@ssa.Label]] = {}
  for label in reachable_labels(entry, blocks) {
    match blocks.get(label) {
      Some(block) =>
        for next in successor_labels(block.term) {
          add_predecessor(preds, next, label)
        }
      None => panic()
    }
  }
  preds
}

///|
fn materialize_params(
  params : Array[@ssa.Var],
  args : Array[@ssa.Expr],
) -> Array[@ssa.Stmt] {
  guard params.length() == args.length() else { panic() }
  let stmts : Array[@ssa.Stmt] = []
  for i in 0..<params.length() {
    stmts.push(@ssa.BindS(params[i], args[i]))
  }
  stmts
}

///|
fn try_inline_cfg_once(
  entry : @ssa.Label,
  blocks : Map[@ssa.Label, @ssa.Block],
) -> Bool {
  let preds = collect_predecessors(entry, blocks)
  for pred_label in reachable_labels(entry, blocks) {
    match blocks.get(pred_label) {
      Some(pred_block) =>
        match pred_block.term {
          @ssa.JumpT(@ssa.Target(target_label, target_args)) => {
            if target_label == entry {
              continue
            }
            match (preds.get(target_label), blocks.get(target_label)) {
              (Some([only_pred]), Some(target_block)) => {
                if only_pred != pred_label ||
                  is_forwarding_block(target_label, target_block) {
                  continue
                }
                let stmts : Array[@ssa.Stmt] = []
                for stmt in pred_block.stmts {
                  stmts.push(stmt)
                }
                for stmt in materialize_params(target_label.params, target_args) {
                  stmts.push(stmt)
                }
                for stmt in target_block.stmts {
                  stmts.push(stmt)
                }
                blocks[pred_label] = { stmts, term: target_block.term }
                return true
              }
              (_, _) => ()
            }
          }
          _ => ()
        }
      None => panic()
    }
  }
  false
}

///|
fn rewrite_all_terms(blocks : Map[@ssa.Label, @ssa.Block]) -> Unit {
  let labels : Array[@ssa.Label] = []
  for label, _ in blocks {
    labels.push(label)
  }
  for label in labels {
    match blocks.get(label) {
      Some(block) =>
        blocks[label] = {
          stmts: block.stmts,
          term: redirect_term(blocks, block.term),
        }
      None => ()
    }
  }
}

///|
fn simplify_cfg_func(func : @ssa.Func) -> (@ssa.Func, Bool) {
  let blocks : Map[@ssa.Label, @ssa.Block] = {}
  for label, block in func.blocks {
    blocks[label] = block
  }
  let mut entry = func.entry
  let mut changed = true
  let mut changed_any = false
  while changed {
    changed = false
    rewrite_all_terms(blocks)
    let redirected_entry = redirect_target(blocks, @ssa.Target(entry, []))
    let @ssa.Target(redirected_label, redirected_args) = redirected_entry
    if redirected_args.length() == 0 && redirected_label != entry {
      entry = redirected_label
      changed = true
    }
    if try_inline_cfg_once(entry, blocks) {
      changed = true
    }
    if changed {
      changed_any = true
    }
  }
  rewrite_all_terms(blocks)
  let reachable = reachable_labels(entry, blocks)
  let mut out_blocks : SortedMap[@ssa.Label, @ssa.Block] = SortedMap::new()
  for label in reachable {
    match blocks.get(label) {
      Some(block) => out_blocks = out_blocks.add(label, block)
      None => panic()
    }
  }
  ({ ..func, blocks: out_blocks, entry }, changed_any)
}
