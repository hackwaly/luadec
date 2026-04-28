///|
fn fresh_label(id_gen : @ssa.IdGen, params : Array[@ssa.Var]) -> @ssa.Label {
  { id: id_gen.next(), params }
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
fn binary_cond_op_cost(op : @ssa.BinaryOp) -> Int {
  match op {
    Neq => 1
    _ => 0
  }
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
fn is_identity_args(params : Array[@ssa.Var], args : Array[@ssa.Expr]) -> Bool {
  guard params.length() == args.length() else { return false }
  for i in 0..<params.length() {
    match args[i] {
      VarE(value) if value == params[i] => ()
      _ => return false
    }
  }
  true
}

///|
fn is_empty_goto_to(region : Region, label : @ssa.Label) -> Bool {
  match region {
    Linear([], next) => is_empty_goto_to(next, label)
    Goto(Target(target_label, args)) =>
      target_label == label && is_identity_args(label.params, args)
    _ => false
  }
}

///|
fn is_goto_to(region : Region, label : @ssa.Label) -> Bool {
  match region {
    Linear([], next) => is_goto_to(next, label)
    Goto(Target(target_label, _)) => target_label == label
    _ => false
  }
}

///|
fn is_empty_transfer_to(region : Region, cont : (@ssa.Label, Region)) -> Bool {
  let (cont_label, cont_region) = cont
  if is_empty_goto_to(region, cont_label) {
    true
  } else {
    is_direct_return(region) && is_direct_return(cont_region)
  }
}

///|
fn build_param_subst(
  params : Array[@ssa.Var],
  args : Array[@ssa.Expr],
) -> Map[@ssa.Var, @ssa.Expr]? {
  guard params.length() == args.length() else { return None }
  let subst : Map[@ssa.Var, @ssa.Expr] = {}
  for i in 0..<params.length() {
    subst[params[i]] = args[i]
  }
  Some(subst)
}

///|
priv struct SubstituteVars {
  subst : Map[@ssa.Var, @ssa.Expr]
}

///|
impl @ssa.MapVisitor for SubstituteVars with visit_Expr_VarE(self, value~) {
  match self.subst.get(value) {
    Some(expr) => expr
    None => VarE(value)
  }
}

///|
impl @ssa.MapVisitor for SubstituteVars with visit_Expr_ClosureE(
  self,
  func~,
  captures~,
) {
  let captures = captures.map(fn(capture) {
    match self.subst.get(capture) {
      Some(VarE(value)) => value
      _ => capture
    }
  })
  ClosureE(func, captures)
}

///|
impl @structured.MapVisitor for SubstituteVars with visit_Expr(self, expr) {
  match expr {
    VarE(value) => self.visit_Expr_VarE(value~)
    ClosureE(func, captures) => self.visit_Expr_ClosureE(func~, captures~)
    _ =>
      @structured.MapVisitorBase::visit_Expr(
        @structured.MapVisitorBase::MapVisitorBase(self),
        expr,
      )
  }
}

///|
fn substitute_region(
  subst : Map[@ssa.Var, @ssa.Expr],
  region : Region,
) -> Region {
  let visitor : SubstituteVars = { subst, }
  visitor.visit_Region(region)
}

///|
fn inline_goto_to_cont(region : Region, cont : (@ssa.Label, Region)) -> Region? {
  let (cont_label, cont_region) = cont
  match region {
    Linear(stmts, next) =>
      match inline_goto_to_cont(next, cont) {
        Some(next) => Some(Linear(stmts, next))
        None => None
      }
    Goto(Target(label, args)) =>
      if label == cont_label {
        match build_param_subst(cont_label.params, args) {
          Some(subst) => Some(substitute_region(subst, cont_region))
          None => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
priv struct TailCont {
  label : @ssa.Label
  break_on_jump : Bool
}

///|
fn is_direct_return(region : Region) -> Bool {
  match region {
    Linear([], next) => is_direct_return(next)
    Return(_, _) => true
    _ => false
  }
}

///|
fn is_abrupt_exit(region : Region) -> Bool {
  match region {
    Linear(_, next) => is_abrupt_exit(next)
    Return(_, _) => true
    Branch(_, then_region, else_region) =>
      is_abrupt_exit(then_region) && is_abrupt_exit(else_region)
    If(_, then_region, else_region, (_, cont_region)) => {
      let then_abrupt = is_abrupt_exit(then_region)
      let else_abrupt = match else_region {
        Some(region) => is_abrupt_exit(region)
        None => true
      }
      then_abrupt && else_abrupt && is_abrupt_exit(cont_region)
    }
    Loop(_, _, _, _, exit_region) =>
      match exit_region {
        Some((_, region)) => is_abrupt_exit(region)
        None => false
      }
    Goto(_) => true
  }
}

///|
fn build_costed_branch(
  cond : @ssa.Expr,
  then_region : Region,
  else_region : Region,
) -> Region {
  let cond = normalize_cond(cond)
  let inverted = invert_cond(cond)
  if cond_cost(inverted) < cond_cost(cond) {
    Branch(inverted, else_region, then_region)
  } else {
    Branch(cond, then_region, else_region)
  }
}

///|
fn build_direct_return_guard(
  id_gen : @ssa.IdGen,
  cond : @ssa.Expr,
  then_region : Region,
  else_region : Region,
) -> Region? {
  let cond = normalize_cond(cond)
  let then_direct = is_direct_return(then_region)
  let else_direct = is_direct_return(else_region)
  match (then_direct, else_direct) {
    (true, true) => {
      let inverted = invert_cond(cond)
      let cont_label = fresh_label(id_gen, [])
      if cond_cost(inverted) < cond_cost(cond) {
        Some(If(inverted, else_region, None, (cont_label, then_region)))
      } else {
        Some(If(cond, then_region, None, (cont_label, else_region)))
      }
    }
    (true, false) =>
      Some(If(cond, then_region, None, (fresh_label(id_gen, []), else_region)))
    (false, true) =>
      Some(
        If(
          invert_cond(cond),
          else_region,
          None,
          (fresh_label(id_gen, []), then_region),
        ),
      )
    (false, false) => None
  }
}

///|
fn build_branch(
  id_gen : @ssa.IdGen,
  cond : @ssa.Expr,
  then_region : Region,
  else_region : Region,
  tails : ArrayView[TailCont],
) -> Region {
  match build_empty_tail_guard(id_gen, cond, then_region, else_region, tails) {
    Some(region) => return region
    None => ()
  }
  if is_abrupt_exit(then_region) && is_abrupt_exit(else_region) {
    match build_direct_return_guard(id_gen, cond, then_region, else_region) {
      Some(region) => region
      None => build_costed_branch(cond, then_region, else_region)
    }
  } else {
    build_costed_branch(cond, then_region, else_region)
  }
}

///|
fn build_empty_tail_guard(
  id_gen : @ssa.IdGen,
  cond : @ssa.Expr,
  then_region : Region,
  else_region : Region,
  tails : ArrayView[TailCont],
) -> Region? {
  let cond = normalize_cond(cond)
  for tail in tails {
    if tail.break_on_jump {
      continue
    }
    if is_empty_goto_to(then_region, tail.label) {
      let (cont_label, body) = if is_abrupt_exit(else_region) {
        (fresh_label(id_gen, []), else_region)
      } else {
        continue
      }
      return Some(If(invert_cond(cond), body, None, (cont_label, then_region)))
    }
    if is_empty_goto_to(else_region, tail.label) {
      let (cont_label, body) = if is_abrupt_exit(then_region) {
        (fresh_label(id_gen, []), then_region)
      } else {
        continue
      }
      return Some(If(cond, body, None, (cont_label, else_region)))
    }
  }
  None
}

///|
fn branch_as_continuation(
  id_gen : @ssa.IdGen,
  region : Region,
  cont : (@ssa.Label, Region),
) -> (@ssa.Label, Region)? {
  match inline_goto_to_cont(region, cont) {
    Some(region) => Some((fresh_label(id_gen, []), region))
    None =>
      if is_abrupt_exit(region) {
        Some((fresh_label(id_gen, []), region))
      } else {
        None
      }
  }
}

///|
fn build_loop_exit_guard(
  id_gen : @ssa.IdGen,
  cond : @ssa.Expr,
  then_region : Region,
  else_region : Region,
  cont : (@ssa.Label, Region),
  tails : ArrayView[TailCont],
) -> Region? {
  let cond = normalize_cond(cond)
  for tail in tails {
    if !tail.break_on_jump {
      continue
    }
    if is_goto_to(then_region, tail.label) {
      match branch_as_continuation(id_gen, else_region, cont) {
        Some(cont) => return Some(If(cond, then_region, None, cont))
        None => ()
      }
    }
    if is_goto_to(else_region, tail.label) {
      match branch_as_continuation(id_gen, then_region, cont) {
        Some(cont) =>
          return Some(If(invert_cond(cond), else_region, None, cont))
        None => ()
      }
    }
  }
  None
}

///|
fn build_if(
  id_gen : @ssa.IdGen,
  cond : @ssa.Expr,
  then_region : Region,
  else_region : Region?,
  cont : (@ssa.Label, Region),
  tails : ArrayView[TailCont],
) -> Region {
  let cond = normalize_cond(cond)
  match else_region {
    Some(else_region) =>
      if is_empty_transfer_to(else_region, cont) {
        If(cond, then_region, None, cont)
      } else if is_empty_transfer_to(then_region, cont) {
        If(invert_cond(cond), else_region, None, cont)
      } else {
        match
          build_loop_exit_guard(
            id_gen, cond, then_region, else_region, cont, tails,
          ) {
          Some(region) => return region
          None => ()
        }
        let branch_tails = with_tail_cont(tails, {
          label: cont.0,
          break_on_jump: false,
        })
        match
          build_empty_tail_guard(
            id_gen, cond, then_region, else_region, branch_tails,
          ) {
          Some(region) => region
          None =>
            if is_abrupt_exit(then_region) && is_abrupt_exit(else_region) {
              match
                build_direct_return_guard(
                  id_gen, cond, then_region, else_region,
                ) {
                Some(region) => region
                None => If(cond, then_region, Some(else_region), cont)
              }
            } else {
              If(cond, then_region, Some(else_region), cont)
            }
        }
      }
    None => {
      let (cont_label, cont_region) = cont
      if is_direct_return(then_region) && is_direct_return(cont_region) {
        let inverted = invert_cond(cond)
        if cond_cost(inverted) < cond_cost(cond) {
          If(
            inverted,
            cont_region,
            None,
            (fresh_label(id_gen, []), then_region),
          )
        } else {
          If(cond, then_region, None, (cont_label, cont_region))
        }
      } else {
        If(cond, then_region, None, cont)
      }
    }
  }
}

///|
fn with_tail_cont(
  tails : ArrayView[TailCont],
  tail : TailCont,
) -> Array[TailCont] {
  let out : Array[TailCont] = [tail]
  for item in tails {
    out.push(item)
  }
  out
}

///|
fn copy_tail_conts(tails : ArrayView[TailCont]) -> Array[TailCont] {
  let out : Array[TailCont] = []
  for item in tails {
    out.push(item)
  }
  out
}

///|
fn normalize_region(
  id_gen : @ssa.IdGen,
  region : Region,
  tails : ArrayView[TailCont],
) -> Region {
  match region {
    Linear(stmts, next) => Linear(stmts, normalize_region(id_gen, next, tails))
    Return(_, _) | Goto(_) => region
    Branch(cond, then_region, else_region) => {
      let then_region = normalize_region(id_gen, then_region, tails)
      let else_region = normalize_region(id_gen, else_region, tails)
      build_branch(id_gen, cond, then_region, else_region, tails)
    }
    If(cond, then_region, else_region, (cont_label, cont_region)) => {
      let cont_region = normalize_region(id_gen, cont_region, tails)
      let branch_tails = with_tail_cont(tails, {
        label: cont_label,
        break_on_jump: false,
      })
      let then_region = normalize_region(id_gen, then_region, branch_tails)
      let else_region = else_region.map(fn(region) {
        normalize_region(id_gen, region, branch_tails)
      })
      build_if(
        id_gen,
        cond,
        then_region,
        else_region,
        (cont_label, cont_region),
        tails,
      )
    }
    Loop(header, init_args, shape, body, exit_region) => {
      let exit_region = exit_region.map(fn(item) {
        let (label, region) = item
        (label, normalize_region(id_gen, region, tails))
      })
      let body_tails = match exit_region {
        Some((label, _)) =>
          with_tail_cont(tails, { label, break_on_jump: true })
        None => copy_tail_conts(tails)
      }
      Loop(
        header,
        init_args,
        shape,
        normalize_region(id_gen, body, body_tails),
        exit_region,
      )
    }
  }
}

///|
fn normalize_func(id_gen : @ssa.IdGen, func : Func) -> Func {
  { ..func, body: normalize_region(id_gen, func.body, []) }
}

///|
pub fn normalize_if(program : Program) -> Program {
  {
    ..program,
    funcs: program.funcs.map(fn(func) { normalize_func(program._id_gen, func) }),
  }
}
