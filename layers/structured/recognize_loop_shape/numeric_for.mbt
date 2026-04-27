///|
fn resolve_trailing_numeric_bound(
  stmts : Array[@ssa.Stmt],
  end : Int,
  expr : @ssa.Expr,
) -> (@ssa.Expr, Int) {
  match expr {
    VarE(value) =>
      if end > 0 {
        match stmts[end - 1] {
          BindS(bound_value, bound_expr) if bound_value == value =>
            (bound_expr, end - 1)
          _ => (expr, end)
        }
      } else {
        (expr, end)
      }
    _ => (expr, end)
  }
}

///|
fn match_numeric_init(
  stmts : Array[@ssa.Stmt],
  init_ctrl : @ssa.Expr,
  limit : @ssa.Expr,
  step : @ssa.Var,
) -> NumericInit? {
  guard stmts.length() > 0 else { return None }
  let ctrl = match init_ctrl {
    VarE(ctrl) => ctrl
    _ => return None
  }
  match stmts[stmts.length() - 1] {
    BindS(value, BinaryE(Sub, start, VarE(init_step))) =>
      if value == ctrl && init_step == step {
        let (step, end) = resolve_trailing_numeric_bound(
          stmts, stmts.length() - 1, VarE(step),
        )
        let (limit, end) = resolve_trailing_numeric_bound(stmts, end, limit)
        Some({ remaining_stmts: take_stmts(stmts, end), start, limit, step })
      } else {
        None
      }
    _ => None
  }
}

///|
fn recognize_numeric_for(
  header : @ssa.Label,
  init_args : Array[@ssa.Expr],
  body : Region,
  exit_region : (@ssa.Label, Region)?,
) -> NumericProtocol? {
  guard init_args.length() > 0 else { return None }
  guard header.params.length() > 0 else { return None }
  match body {
    Linear(
      [BindS(ctrl, BinaryE(Add, VarE(prev_ctrl), VarE(step)))],
      If(
        NumericForCheckE(VarE(check_ctrl), limit, VarE(check_step)),
        then_region,
        Some(else_region),
        (cont_label, cont_region)
      )
    ) =>
      if prev_ctrl == header.params[header.params.length() - 1] &&
        check_ctrl == ctrl &&
        check_step == step &&
        exits_loop(else_region, exit_region) &&
        is_identity_jump(cont_region, cont_label, header) {
        let redirect : RedirectContinue = { from: cont_label, to: header }
        Some({
          value: ctrl,
          limit,
          step,
          body: redirect.visit_Region(then_region),
        })
      } else {
        None
      }
    _ => None
  }
}

///|
fn recognize_numeric_loop(
  stmts : Array[@ssa.Stmt],
  header : @ssa.Label,
  init_args : Array[@ssa.Expr],
  body : Region,
  exit_region : (@ssa.Label, Region)?,
) -> Region? {
  let protocol = match
    recognize_numeric_for(header, init_args, body, exit_region) {
    Some(protocol) => protocol
    None => return None
  }
  guard init_args.length() > 0 else { return None }
  let init_ctrl = init_args[init_args.length() - 1]
  let init = match
    match_numeric_init(stmts, init_ctrl, protocol.limit, protocol.step) {
    Some(init) => init
    None => return None
  }
  let new_header = { ..header, params: drop_last_vars(header.params) }
  let dropper : DropLoopControl = { old_header: header, new_header }
  let loop_region = @structured.Loop(
    new_header,
    drop_last_exprs(init_args),
    @structured.NumericForLS(
      protocol.value,
      init.start,
      init.limit,
      init.step,
    ),
    dropper.visit_Region(protocol.body),
    exit_region,
  )
  Some(linear_or_next(init.remaining_stmts, loop_region))
}
