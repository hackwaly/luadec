///|
priv struct VarUse {
  value : @ssa.Var
  found : Array[Bool]
}

///|
impl @structured.IterVisitor for VarUse with visit_Expr(self, expr) {
  match expr {
    VarE(value) if value == self.value => self.found[0] = true
    ClosureE(_, captures) =>
      for capture in captures {
        if capture == self.value {
          self.found[0] = true
        }
      }
    _ => self.base().visit_Expr(expr)
  }
}

///|
fn region_mentions_var(region : Region, value : @ssa.Var) -> Bool {
  let found = [false]
  let visitor : VarUse = { value, found }
  visitor.visit_Region(region)
  found[0]
}

///|
priv struct DropContParams {
  old_label : @ssa.Label
  new_label : @ssa.Label
  keep_indices : Array[Int]
}

///|
impl @structured.MapVisitor for DropContParams with visit_Region_Goto(
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
      Target(self.new_label, kept_args.map(fn(arg) { self.visit_Expr(arg) })),
    )
  } else {
    Goto(self.visit_Target(target))
  }
}

///|
fn prune_cont(
  sources : Array[Region],
  cont : (@ssa.Label, Region),
) -> (Array[Region], (@ssa.Label, Region)) {
  let (old_label, cont_region) = cont
  guard old_label.params.length() > 0 else { return (sources, cont) }
  let keep_indices : Array[Int] = []
  let kept_params : Array[@ssa.Var] = []
  for i in 0..<old_label.params.length() {
    let param = old_label.params[i]
    if region_mentions_var(cont_region, param) {
      keep_indices.push(i)
      kept_params.push(param)
    }
  }
  guard kept_params.length() < old_label.params.length() else {
    return (sources, cont)
  }
  let new_label = { ..old_label, params: kept_params }
  let dropper : DropContParams = { old_label, new_label, keep_indices }
  let new_sources = sources.map(fn(region) {
    prune_region(dropper.visit_Region(region))
  })
  let new_cont_region = prune_region(dropper.visit_Region(cont_region))
  (new_sources, (new_label, new_cont_region))
}

///|
fn prune_region(region : Region) -> Region {
  match region {
    Linear(stmts, next) => Linear(stmts, prune_region(next))
    Return(_, _) | Goto(_) => region
    Branch(cond, then_region, else_region) =>
      Branch(cond, prune_region(then_region), prune_region(else_region))
    If(cond, then_region, else_region, cont) => {
      let then_region = prune_region(then_region)
      let cont_region = prune_region(cont.1)
      match else_region {
        Some(else_region) => {
          let else_region = prune_region(else_region)
          let (sources, cont) = prune_cont(
            [then_region, else_region],
            (cont.0, cont_region),
          )
          If(cond, sources[0], Some(sources[1]), cont)
        }
        None => {
          let (sources, cont) = prune_cont([then_region], (cont.0, cont_region))
          If(cond, sources[0], None, cont)
        }
      }
    }
    Loop(header, init_args, shape, body, exit_region) => {
      let body = prune_region(body)
      match exit_region {
        Some((exit_label, exit_region)) => {
          let exit_region = prune_region(exit_region)
          let (sources, cont) = prune_cont([body], (exit_label, exit_region))
          Loop(header, init_args, shape, sources[0], Some(cont))
        }
        None => Loop(header, init_args, shape, body, None)
      }
    }
  }
}

///|
pub fn prune_cont_params(program : Program) -> Program {
  {
    ..program,
    funcs: program.funcs.map(fn(func) {
      { ..func, body: prune_region(func.body) }
    }),
  }
}
