///|
priv struct Hoister {
  id_gen : @ssa.IdGen
  loop_transfers : Map[@ssa.Label, Bool]
}

///|
priv struct LoopTransferCollector {
  labels : Map[@ssa.Label, Bool]
}

///|
impl @structured.IterVisitor for LoopTransferCollector with fn visit_Region_Loop(
  self,
  header~,
  init_args~,
  shape~,
  body~,
  exit_region~,
) {
  self.labels[header] = true
  match exit_region {
    Some((exit_label, _)) => self.labels[exit_label] = true
    None => ()
  }
  self
  .base()
  .visit_Region_Loop(header~, init_args~, shape~, body~, exit_region~)
}

///|
fn expr_equal(lhs : @ssa.Expr, rhs : @ssa.Expr) -> Bool {
  match (lhs, rhs) {
    (VarE(lhs), VarE(rhs)) => lhs == rhs
    (CellE(lhs), CellE(rhs)) => lhs == rhs
    (ConstE(lhs), ConstE(rhs)) => lhs == rhs
    _ => false
  }
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
fn fresh_label(id_gen : @ssa.IdGen) -> @ssa.Label {
  { id: id_gen.next(), params: [], }
}

///|
fn goto(label : @ssa.Label) -> Region {
  Goto(@ssa.Target(label, []))
}

///|
fn tail_target(region : Region) -> @ssa.Target? {
  match region {
    Linear(_, next) => tail_target(next)
    Goto(target) => Some(target)
    If(_, _, _, (_, cont_region)) => tail_target(cont_region)
    Loop(_, _, _, _, Some((_, exit_region))) => tail_target(exit_region)
    Branch(_, then_region, else_region) =>
      match (tail_target(then_region), tail_target(else_region)) {
        (Some(then_target), Some(else_target)) =>
          if target_equal(then_target, else_target) {
            Some(then_target)
          } else {
            None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn replace_tail_target(
  region : Region,
  expected : @ssa.Target,
  replacement : Region,
) -> Region {
  match region {
    Linear(stmts, next) =>
      Linear(stmts, replace_tail_target(next, expected, replacement))
    Goto(target) =>
      if target_equal(target, expected) {
        replacement
      } else {
        region
      }
    If(cond, then_region, else_region, (cont_label, cont_region)) =>
      If(
        cond,
        replace_tail_target(then_region, expected, replacement),
        else_region.map(fn(region) {
          replace_tail_target(region, expected, replacement)
        }),
        (cont_label, replace_tail_target(cont_region, expected, replacement)),
      )
    Loop(header, init_args, shape, body, Some((exit_label, exit_region))) =>
      Loop(
        header,
        init_args,
        shape,
        replace_tail_target(body, expected, replacement),
        Some(
          (exit_label, replace_tail_target(exit_region, expected, replacement)),
        ),
      )
    Branch(cond, then_region, else_region) =>
      Branch(
        cond,
        replace_tail_target(then_region, expected, replacement),
        replace_tail_target(else_region, expected, replacement),
      )
    _ => region
  }
}

///|
fn materialize_target_then(target : @ssa.Target, next : Region) -> Region {
  let Target(label, args) = target
  guard label.params.length() == args.length() else { panic() }
  let stmts : Array[@ssa.Stmt] = []
  for i in 0..<args.length() {
    stmts.push(BindS(label.params[i], args[i]))
  }
  if stmts.is_empty() {
    next
  } else {
    Linear(stmts, next)
  }
}

///|
fn hoist_branch_tail(
  id_gen : @ssa.IdGen,
  cond : @ssa.Expr,
  then_region : Region,
  else_region : Region,
) -> Region {
  match (tail_target(then_region), tail_target(else_region)) {
    (Some(then_target), Some(else_target)) =>
      if target_equal(then_target, else_target) {
        let cont = fresh_label(id_gen)
        let cont_target = goto(cont)
        If(
          cond,
          replace_tail_target(then_region, then_target, cont_target),
          Some(replace_tail_target(else_region, then_target, cont_target)),
          (cont, Goto(then_target)),
        )
      } else {
        Branch(cond, then_region, else_region)
      }
    _ => Branch(cond, then_region, else_region)
  }
}

///|
fn hoist_if_tail(
  id_gen : @ssa.IdGen,
  loop_transfers : Map[@ssa.Label, Bool],
  cond : @ssa.Expr,
  then_region : Region,
  else_region : Region?,
  cont : (@ssa.Label, Region),
) -> Region {
  match else_region {
    Some(else_region) =>
      match (tail_target(then_region), tail_target(else_region)) {
        (Some(then_target), Some(else_target)) =>
          if target_equal(then_target, else_target) {
            let (old_cont_label, old_cont_region) = cont
            let Target(target_label, _) = then_target
            guard loop_transfers.get(target_label) != Some(true) else {
              return If(cond, then_region, Some(else_region), cont)
            }
            guard target_label == old_cont_label ||
              !target_label.params.is_empty() else {
              return If(cond, then_region, Some(else_region), cont)
            }
            let cont_label = fresh_label(id_gen)
            let cont_target = goto(cont_label)
            If(
              cond,
              replace_tail_target(then_region, then_target, cont_target),
              Some(replace_tail_target(else_region, then_target, cont_target)),
              (
                cont_label,
                materialize_target_then(then_target, old_cont_region),
              ),
            )
          } else {
            If(cond, then_region, Some(else_region), cont)
          }
        _ => If(cond, then_region, Some(else_region), cont)
      }
    None => If(cond, then_region, None, cont)
  }
}

///|
impl @structured.MapVisitor for Hoister with fn visit_Region_Branch(
  self,
  cond~,
  then_~,
  else_~,
) {
  hoist_branch_tail(
    self.id_gen,
    self.visit_Expr(cond),
    self.visit_Region(then_),
    self.visit_Region(else_),
  )
}

///|
impl @structured.MapVisitor for Hoister with fn visit_Region_If(
  self,
  cond~,
  then_~,
  else_~,
  cont~,
) {
  let (cont_label, cont_region) = cont
  hoist_if_tail(
    self.id_gen,
    self.loop_transfers,
    self.visit_Expr(cond),
    self.visit_Region(then_),
    else_.map(fn(region) { self.visit_Region(region) }),
    (self.visit_Label(cont_label), self.visit_Region(cont_region)),
  )
}

///|
pub fn hoist_common_transfers(program : Program) -> Program {
  let loop_transfers : Map[@ssa.Label, Bool] = Map([])
  let collector : LoopTransferCollector = { labels: loop_transfers, }
  collector.visit_Program(program)
  let hoister : Hoister = { id_gen: program._id_gen, loop_transfers, }
  hoister.visit_Program(program)
}

///|
extend LoopTransferCollector with @structured.IterVisitor::{base, visit_Program}

///|
extend Hoister with @structured.MapVisitor::{
  visit_Expr,
  visit_Region,
  visit_Label,
  visit_Program,
}
