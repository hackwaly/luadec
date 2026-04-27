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
  limit : @ssa.Expr
  step : @ssa.Expr
}

///|
priv struct GenericInit {
  remaining_stmts : Array[@ssa.Stmt]
  exprs : Array[@ssa.Expr]
  multi : @ssa.Multi?
}

///|
priv struct VarMention {
  value : @ssa.Var
  found : Array[Bool]
}

///|
priv struct DropLabelParams {
  old_label : @ssa.Label
  new_label : @ssa.Label
  keep_indices : Array[Int]
}

///|
impl @structured.IterVisitor for VarMention with visit_Var(self, value) {
  if value == self.value {
    self.found[0] = true
  }
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
impl @structured.MapVisitor for DropLabelParams with visit_Region_Goto(
  self,
  target~,
) {
  let Target(label, args) = target
  if label == self.old_label && args.length() == self.old_label.params.length() {
    let kept_args : Array[@ssa.Expr] = []
    for index in self.keep_indices {
      kept_args.push(args[index])
    }
    Goto(
      Target(
        self.new_label,
        kept_args.map(fn(arg) { self.visit_Expr(arg) }),
      ),
    )
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
impl @structured.MapVisitor for DropLoopControl with visit_Region_Loop(
  self,
  header~,
  init_args~,
  shape~,
  body~,
  exit_region~,
) {
  let header = self.visit_Label(header)
  let init_args = init_args.map(fn(arg) { self.visit_Expr(arg) })
  let shape = self.visit_LoopShape(shape)
  let body = self.visit_Region(body)
  let exit_region = exit_region.map(fn(item) {
    let (label, region) = item
    (self.visit_Label(label), self.visit_Region(region))
  })
  let (body, exit_region) = prune_unused_exit_params(body, exit_region)
  Loop(header, init_args, shape, body, exit_region)
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
fn region_mentions_var(region : Region, value : @ssa.Var) -> Bool {
  let found = [false]
  let visitor : VarMention = { value, found }
  visitor.visit_Region(region)
  found[0]
}

///|
fn prune_unused_exit_params(
  body : Region,
  exit_region : (@ssa.Label, Region)?,
) -> (Region, (@ssa.Label, Region)?) {
  match exit_region {
    Some((exit_label, exit_body)) => {
      let keep_indices : Array[Int] = []
      let kept_params : Array[@ssa.Var] = []
      for i in 0..<exit_label.params.length() {
        let param = exit_label.params[i]
        if region_mentions_var(exit_body, param) {
          keep_indices.push(i)
          kept_params.push(param)
        }
      }
      guard kept_params.length() < exit_label.params.length() else {
        return (body, exit_region)
      }
      let new_label = { ..exit_label, params: kept_params }
      let dropper : DropLabelParams = { old_label: exit_label, new_label, keep_indices }
      (
        dropper.visit_Region(body),
        Some((new_label, dropper.visit_Region(exit_body))),
      )
    }
    None => (body, None)
  }
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
fn remove_stmts_range(
  stmts : Array[@ssa.Stmt],
  start : Int,
  end : Int,
) -> Array[@ssa.Stmt] {
  let out : Array[@ssa.Stmt] = []
  for i in 0..<start {
    out.push(stmts[i])
  }
  for i in end..<stmts.length() {
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
