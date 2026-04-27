///|
fn generic_init_targets(
  iter : @ssa.Var,
  state : @ssa.Var,
  init_ctrl : @ssa.Expr,
) -> Array[@ssa.Var]? {
  match init_ctrl {
    VarE(ctrl) => Some([iter, state, ctrl])
    _ => None
  }
}

///|
fn vars_match_suffix(
  values : Array[@ssa.Var],
  targets : Array[@ssa.Var],
  start : Int,
) -> Bool {
  guard values.length() == targets.length() - start else { return false }
  for i in 0..<values.length() {
    if values[i] != targets[start + i] {
      return false
    }
  }
  true
}

///|
fn init_args_contain_var(
  init_args : Array[@ssa.Expr],
  value : @ssa.Var,
) -> Bool {
  for arg in init_args {
    match arg {
      VarE(arg_value) if arg_value == value => return true
      _ => ()
    }
  }
  false
}

///|
fn can_follow_generic_init(
  init_args : Array[@ssa.Expr],
  stmt : @ssa.Stmt,
) -> Bool {
  match stmt {
    BindS(value, ConstE(_) | VarE(_)) => init_args_contain_var(init_args, value)
    _ => false
  }
}

///|
fn can_finish_generic_init_at(
  stmts : Array[@ssa.Stmt],
  end : Int,
  init_args : Array[@ssa.Expr],
) -> Bool {
  for i in end..<stmts.length() {
    if !can_follow_generic_init(init_args, stmts[i]) {
      return false
    }
  }
  true
}

///|
fn try_match_generic_init_from(
  stmts : Array[@ssa.Stmt],
  start : Int,
  targets : Array[@ssa.Var],
  init_args : Array[@ssa.Expr],
) -> GenericInit? {
  let exprs : Array[@ssa.Expr] = []
  let mut target_index = 0
  for i in start..<stmts.length() {
    guard target_index < targets.length() else { return None }
    match stmts[i] {
      BindS(value, expr) =>
        if value == targets[target_index] {
          exprs.push(expr)
          target_index = target_index + 1
          let end = i + 1
          if target_index == targets.length() &&
            can_finish_generic_init_at(stmts, end, init_args) {
            return Some({
              remaining_stmts: remove_stmts_range(stmts, start, end),
              exprs,
              multi: None,
            })
          }
        } else {
          return None
        }
      BindMultiS(values, multi) =>
        if vars_match_suffix(values, targets, target_index) {
          let end = i + 1
          guard can_finish_generic_init_at(stmts, end, init_args) else {
            return None
          }
          return Some({
            remaining_stmts: remove_stmts_range(stmts, start, end),
            exprs,
            multi: Some(multi),
          })
        } else {
          return None
        }
      _ => return None
    }
  }
  if target_index == targets.length() {
    Some({ remaining_stmts: take_stmts(stmts, start), exprs, multi: None })
  } else {
    None
  }
}

///|
fn match_generic_init(
  stmts : Array[@ssa.Stmt],
  iter : @ssa.Var,
  state : @ssa.Var,
  init_args : Array[@ssa.Expr],
) -> GenericInit? {
  guard init_args.length() > 0 else { return None }
  let init_ctrl = init_args[init_args.length() - 1]
  let targets = match generic_init_targets(iter, state, init_ctrl) {
    Some(targets) => targets
    None => return None
  }
  let mut found : GenericInit? = None
  for start in 0..<stmts.length() {
    match try_match_generic_init_from(stmts, start, targets, init_args) {
      Some(init) => found = Some(init)
      None => ()
    }
  }
  found
}

///|
fn recognize_generic_for(
  header : @ssa.Label,
  init_args : Array[@ssa.Expr],
  body : Region,
  exit_region : (@ssa.Label, Region)?,
) -> GenericProtocol? {
  guard header.params.length() > 0 else { return None }
  guard init_args.length() >= header.params.length() else { return None }
  match body {
    Linear(
      [
        BindMultiS(
          vars,
          CallM(NormalC(VarE(iter), [VarE(state), VarE(ctrl)], None))
        ),
      ],
      If(
        BinaryE(Neq, VarE(first), ConstE(Nil)),
        then_region,
        Some(else_region),
        (cont_label, cont_region)
      )
    ) =>
      if vars.length() > 0 &&
        vars[0] == first &&
        ctrl == header.params[header.params.length() - 1] &&
        exits_loop(else_region, exit_region) &&
        is_identity_jump(cont_region, cont_label, header) {
        let redirect : RedirectContinue = { from: cont_label, to: header }
        Some({ vars, iter, state, body: redirect.visit_Region(then_region) })
      } else {
        None
      }
    _ => None
  }
}

///|
fn recognize_generic_loop(
  stmts : Array[@ssa.Stmt],
  header : @ssa.Label,
  init_args : Array[@ssa.Expr],
  body : Region,
  exit_region : (@ssa.Label, Region)?,
) -> Region? {
  let protocol = match
    recognize_generic_for(header, init_args, body, exit_region) {
    Some(protocol) => protocol
    None => return None
  }
  let init = match
    match_generic_init(stmts, protocol.iter, protocol.state, init_args) {
    Some(init) => init
    None => return None
  }
  let new_header = { ..header, params: drop_last_vars(header.params) }
  let dropper : DropLoopControl = { old_header: header, new_header }
  let loop_region = @structured.Loop(
    new_header,
    drop_last_exprs(init_args),
    @structured.GenericForLS(protocol.vars, init.exprs, init.multi),
    dropper.visit_Region(protocol.body),
    exit_region,
  )
  Some(linear_or_next(init.remaining_stmts, loop_region))
}
