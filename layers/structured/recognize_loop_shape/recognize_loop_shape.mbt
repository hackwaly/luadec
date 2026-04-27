///|
priv struct Recognizer {
  _unit : Unit
}

///|
priv struct RedirectContinue {
  from : @ssa.Label
  to : @ssa.Label
}

///|
priv struct DropLoopControl {
  old_header : @ssa.Label
  new_header : @ssa.Label
}

///|
priv struct GenericProtocol {
  vars : Array[@ssa.Var]
  iter : @ssa.Var
  state : @ssa.Var
  body : Region
}

///|
priv struct NumericProtocol {
  value : @ssa.Var
  limit : @ssa.Expr
  step : @ssa.Var
  body : Region
}

///|
priv struct NumericInit {
  remaining_stmts : Array[@ssa.Stmt]
  start : @ssa.Expr
}

///|
priv struct GenericInit {
  remaining_stmts : Array[@ssa.Stmt]
  exprs : Array[@ssa.Expr]
  multi : @ssa.Multi?
}

///|
impl @structured.MapVisitor for RedirectContinue with visit_Region_Goto(
  self,
  target~,
) {
  let Target(label, args) = target
  if label == self.from {
    Goto(Target(self.to, args.map(fn(arg) { self.visit_Expr(arg) })))
  } else {
    Goto(self.visit_Target(target))
  }
}

///|
impl @structured.MapVisitor for DropLoopControl with visit_Region_Goto(
  self,
  target~,
) {
  let Target(label, args) = target
  if label == self.old_header &&
    args.length() == self.old_header.params.length() {
    Goto(
      Target(
        self.new_header,
        drop_last_exprs(args).map(fn(arg) { self.visit_Expr(arg) }),
      ),
    )
  } else {
    Goto(self.visit_Target(target))
  }
}

///|
fn drop_last_exprs(values : Array[@ssa.Expr]) -> Array[@ssa.Expr] {
  guard values.length() > 0 else { return [] }
  let out : Array[@ssa.Expr] = []
  for i in 0..<(values.length() - 1) {
    out.push(values[i])
  }
  out
}

///|
fn drop_last_vars(values : Array[@ssa.Var]) -> Array[@ssa.Var] {
  guard values.length() > 0 else { return [] }
  let out : Array[@ssa.Var] = []
  for i in 0..<(values.length() - 1) {
    out.push(values[i])
  }
  out
}

///|
fn take_stmts(stmts : Array[@ssa.Stmt], count : Int) -> Array[@ssa.Stmt] {
  let out : Array[@ssa.Stmt] = []
  for i in 0..<count {
    out.push(stmts[i])
  }
  out
}

///|
fn linear_or_next(stmts : Array[@ssa.Stmt], next : Region) -> Region {
  if stmts.is_empty() {
    next
  } else {
    Linear(stmts, next)
  }
}

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
fn try_match_generic_init_from(
  stmts : Array[@ssa.Stmt],
  start : Int,
  targets : Array[@ssa.Var],
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
        } else {
          return None
        }
      BindMultiS(values, multi) =>
        if i == stmts.length() - 1 &&
          vars_match_suffix(values, targets, target_index) {
          return Some({
            remaining_stmts: take_stmts(stmts, start),
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
  init_ctrl : @ssa.Expr,
) -> GenericInit? {
  let targets = match generic_init_targets(iter, state, init_ctrl) {
    Some(targets) => targets
    None => return None
  }
  let mut found : GenericInit? = None
  for start in 0..<stmts.length() {
    match try_match_generic_init_from(stmts, start, targets) {
      Some(init) => found = Some(init)
      None => ()
    }
  }
  found
}

///|
fn match_numeric_init(
  stmts : Array[@ssa.Stmt],
  init_ctrl : @ssa.Expr,
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
        Some({ remaining_stmts: take_stmts(stmts, stmts.length() - 1), start })
      } else {
        None
      }
    _ => None
  }
}

///|
fn is_identity_args(label : @ssa.Label, args : Array[@ssa.Expr]) -> Bool {
  guard label.params.length() == args.length() else { return false }
  for i in 0..<args.length() {
    match args[i] {
      VarE(value) if value == label.params[i] => ()
      _ => return false
    }
  }
  true
}

///|
fn is_identity_jump(
  region : Region,
  from : @ssa.Label,
  to : @ssa.Label,
) -> Bool {
  match region {
    Goto(Target(label, args)) => label == to && is_identity_args(from, args)
    _ => false
  }
}

///|
fn exits_loop(region : Region, exit_region : (@ssa.Label, Region)?) -> Bool {
  match exit_region {
    Some((exit_label, _)) =>
      match region {
        Goto(Target(label, _)) => label == exit_label
        _ => false
      }
    None => false
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
        else_region,
        Some((cont_label, cont_region))
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
        else_region,
        Some((cont_label, cont_region))
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
fn recognize_shape(
  header : @ssa.Label,
  init_args : Array[@ssa.Expr],
  body : Region,
  _exit_region : (@ssa.Label, Region)?,
) -> (LoopShape, Region) {
  ignore(header)
  ignore(init_args)
  (UnknownLS, body)
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
  let init = match match_numeric_init(stmts, init_ctrl, protocol.step) {
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
      protocol.limit,
      VarE(protocol.step),
    ),
    dropper.visit_Region(protocol.body),
    exit_region,
  )
  Some(linear_or_next(init.remaining_stmts, loop_region))
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
  guard init_args.length() > 0 else { return None }
  let init_ctrl = init_args[init_args.length() - 1]
  let init = match
    match_generic_init(stmts, protocol.iter, protocol.state, init_ctrl) {
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

///|
impl @structured.MapVisitor for Recognizer with visit_Region_Loop(
  self,
  header~,
  init_args~,
  shape~,
  body~,
  exit_region~,
) {
  let body = self.visit_Region(body)
  let exit_region = exit_region.map(fn(item) {
    let (label, region) = item
    (label, self.visit_Region(region))
  })
  let (shape, body) = match shape {
    UnknownLS => recognize_shape(header, init_args, body, exit_region)
    _ => (self.visit_LoopShape(shape), body)
  }
  Loop(header, init_args, shape, body, exit_region)
}

///|
impl @structured.MapVisitor for Recognizer with visit_Region_Linear(
  self,
  stmts~,
  next~,
) {
  let stmts = stmts.map(fn(stmt) { self.visit_Stmt(stmt) })
  let next = self.visit_Region(next)
  match next {
    Loop(header, init_args, UnknownLS, body, exit_region) =>
      match
        recognize_numeric_loop(stmts, header, init_args, body, exit_region) {
        Some(region) => region
        None =>
          match
            recognize_generic_loop(stmts, header, init_args, body, exit_region) {
            Some(region) => region
            None => Linear(stmts, next)
          }
      }
    _ => Linear(stmts, next)
  }
}

///|
pub fn recognize_loop_shape(program : Program) -> Program {
  let recognizer : Recognizer = { _unit: () }
  recognizer.visit_Program(program)
}
