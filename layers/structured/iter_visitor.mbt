///|
pub(open) trait IterVisitor {
  base(Self) -> IterVisitorBase[Self] = _
  visit_Program(Self, Program) -> Unit = _
  visit_Func(Self, Func) -> Unit = _
  visit_Region(Self, Region) -> Unit = _
  visit_Region_Linear(Self, stmts~ : Array[Stmt], next~ : Region) -> Unit = _
  visit_Region_Return(Self, values~ : Array[Expr], multi~ : Multi?) -> Unit = _
  visit_Region_Branch(Self, cond~ : Expr, then_~ : Region, else_~ : Region) -> Unit = _
  visit_Region_If(
    Self,
    cond~ : Expr,
    then_~ : Region,
    else_~ : Region?,
    cont~ : (Label, Region),
  ) -> Unit = _
  visit_Region_Loop(
    Self,
    header~ : Label,
    init_args~ : Array[Expr],
    shape~ : LoopShape,
    body~ : Region,
    exit_region~ : (Label, Region)?,
  ) -> Unit = _
  visit_Region_Goto(Self, target~ : Target) -> Unit = _
  visit_LoopShape(Self, LoopShape) -> Unit = _
  visit_LoopShape_UnknownLS(Self) -> Unit = _
  visit_LoopShape_NumericForLS(
    Self,
    value~ : Var,
    init~ : Expr,
    limit~ : Expr,
    step~ : Expr,
  ) -> Unit = _
  visit_LoopShape_GenericForLS(
    Self,
    vars~ : Array[Var],
    exprs~ : Array[Expr],
    multi~ : Multi?,
  ) -> Unit = _
  visit_Stmt(Self, Stmt) -> Unit = _
  visit_Expr(Self, Expr) -> Unit = _
  visit_Target(Self, Target) -> Unit = _
  visit_Multi(Self, Multi) -> Unit = _
  visit_Call(Self, @ssa.Call) -> Unit = _
  visit_TableInit(Self, @ssa.TableInit) -> Unit = _
  visit_Var(Self, Var) -> Unit = _
  visit_Cell(Self, Cell) -> Unit = _
  visit_Label(Self, Label) -> Unit = _
}

///|
impl IterVisitor with base(self) -> IterVisitorBase[Self] {
  IterVisitorBase::IterVisitorBase(self)
}

///|
impl IterVisitor with visit_Program(env, program) {
  IterVisitorBase::visit_Program(env, program)
}

///|
impl IterVisitor with visit_Func(env, func) {
  IterVisitorBase::visit_Func(env, func)
}

///|
impl IterVisitor with visit_Region(env, region) {
  IterVisitorBase::visit_Region(env, region)
}

///|
impl IterVisitor with visit_Region_Linear(env, stmts~, next~) {
  IterVisitorBase::visit_Region_Linear(env, stmts~, next~)
}

///|
impl IterVisitor with visit_Region_Return(env, values~, multi~) {
  IterVisitorBase::visit_Region_Return(env, values~, multi~)
}

///|
impl IterVisitor with visit_Region_Branch(env, cond~, then_~, else_~) {
  IterVisitorBase::visit_Region_Branch(env, cond~, then_~, else_~)
}

///|
impl IterVisitor with visit_Region_If(env, cond~, then_~, else_~, cont~) {
  IterVisitorBase::visit_Region_If(env, cond~, then_~, else_~, cont~)
}

///|
impl IterVisitor with visit_Region_Loop(
  env,
  header~,
  init_args~,
  shape~,
  body~,
  exit_region~,
) {
  IterVisitorBase::visit_Region_Loop(
    env,
    header~,
    init_args~,
    shape~,
    body~,
    exit_region~,
  )
}

///|
impl IterVisitor with visit_Region_Goto(env, target~) {
  IterVisitorBase::visit_Region_Goto(env, target~)
}

///|
impl IterVisitor with visit_LoopShape(env, shape) {
  IterVisitorBase::visit_LoopShape(env, shape)
}

///|
impl IterVisitor with visit_LoopShape_UnknownLS(env) {
  IterVisitorBase::visit_LoopShape_UnknownLS(env)
}

///|
impl IterVisitor with visit_LoopShape_NumericForLS(
  env,
  value~,
  init~,
  limit~,
  step~,
) {
  IterVisitorBase::visit_LoopShape_NumericForLS(
    env,
    value~,
    init~,
    limit~,
    step~,
  )
}

///|
impl IterVisitor with visit_LoopShape_GenericForLS(env, vars~, exprs~, multi~) {
  IterVisitorBase::visit_LoopShape_GenericForLS(env, vars~, exprs~, multi~)
}

///|
impl IterVisitor with visit_Stmt(env, stmt) {
  IterVisitorBase::visit_Stmt(env, stmt)
}

///|
impl IterVisitor with visit_Expr(env, expr) {
  IterVisitorBase::visit_Expr(env, expr)
}

///|
impl IterVisitor with visit_Target(env, target) {
  IterVisitorBase::visit_Target(env, target)
}

///|
impl IterVisitor with visit_Multi(env, multi) {
  IterVisitorBase::visit_Multi(env, multi)
}

///|
impl IterVisitor with visit_Call(env, call) {
  IterVisitorBase::visit_Call(env, call)
}

///|
impl IterVisitor with visit_TableInit(env, init) {
  IterVisitorBase::visit_TableInit(env, init)
}

///|
impl IterVisitor with visit_Var(env, value) {
  IterVisitorBase::visit_Var(env, value)
}

///|
impl IterVisitor with visit_Cell(env, cell) {
  IterVisitorBase::visit_Cell(env, cell)
}

///|
impl IterVisitor with visit_Label(env, label) {
  IterVisitorBase::visit_Label(env, label)
}

///|
pub(all) struct IterVisitorBase[T](T)

///|
priv struct SsaIterAdapter[T](T)

///|
fn[T] ssa_iter_base(env : T) -> @ssa.IterVisitorBase[SsaIterAdapter[T]] {
  @ssa.IterVisitorBase::IterVisitorBase(SsaIterAdapter::SsaIterAdapter(env))
}

///|
impl[T : IterVisitor] @ssa.IterVisitor for SsaIterAdapter[T] with visit_Stmt(
  env,
  stmt,
) {
  env.0.visit_Stmt(stmt)
}

///|
impl[T : IterVisitor] @ssa.IterVisitor for SsaIterAdapter[T] with visit_Expr(
  env,
  expr,
) {
  env.0.visit_Expr(expr)
}

///|
impl[T : IterVisitor] @ssa.IterVisitor for SsaIterAdapter[T] with visit_Target(
  env,
  target,
) {
  env.0.visit_Target(target)
}

///|
impl[T : IterVisitor] @ssa.IterVisitor for SsaIterAdapter[T] with visit_Multi(
  env,
  multi,
) {
  env.0.visit_Multi(multi)
}

///|
impl[T : IterVisitor] @ssa.IterVisitor for SsaIterAdapter[T] with visit_Call(
  env,
  call,
) {
  env.0.visit_Call(call)
}

///|
impl[T : IterVisitor] @ssa.IterVisitor for SsaIterAdapter[T] with visit_TableInit(
  env,
  init,
) {
  env.0.visit_TableInit(init)
}

///|
impl[T : IterVisitor] @ssa.IterVisitor for SsaIterAdapter[T] with visit_Var(
  env,
  value,
) {
  env.0.visit_Var(value)
}

///|
impl[T : IterVisitor] @ssa.IterVisitor for SsaIterAdapter[T] with visit_Cell(
  env,
  cell,
) {
  env.0.visit_Cell(cell)
}

///|
impl[T : IterVisitor] @ssa.IterVisitor for SsaIterAdapter[T] with visit_Label(
  env,
  label,
) {
  env.0.visit_Label(label)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Program(
  env,
  program,
) {
  for func in program.funcs {
    env.0.visit_Func(func)
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Func(
  env,
  func,
) {
  for param in func.params {
    env.0.visit_Var(param)
  }
  for cell in func.cells {
    env.0.visit_Cell(cell)
  }
  env.0.visit_Region(func.body)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Region(
  env,
  region,
) {
  match region {
    Linear(stmts, next) => env.0.visit_Region_Linear(stmts~, next~)
    Return(values, multi) => env.0.visit_Region_Return(values~, multi~)
    Branch(cond, then_, else_) =>
      env.0.visit_Region_Branch(cond~, then_~, else_~)
    If(cond, then_, else_, cont) =>
      env.0.visit_Region_If(cond~, then_~, else_~, cont~)
    Loop(header, init_args, shape, body, exit_region) =>
      env.0.visit_Region_Loop(header~, init_args~, shape~, body~, exit_region~)
    Goto(target) => env.0.visit_Region_Goto(target~)
  }
}

///|
fn[T : IterVisitor] iter_visit_cont(env : T, cont : (Label, Region)?) -> Unit {
  match cont {
    Some((label, region)) => {
      env.visit_Label(label)
      env.visit_Region(region)
    }
    None => ()
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Region_Linear(
  env,
  stmts~,
  next~,
) {
  for stmt in stmts {
    env.0.visit_Stmt(stmt)
  }
  env.0.visit_Region(next)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Region_Return(
  env,
  values~,
  multi~,
) {
  for value in values {
    env.0.visit_Expr(value)
  }
  match multi {
    Some(multi) => env.0.visit_Multi(multi)
    None => ()
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Region_Branch(
  env,
  cond~,
  then_~,
  else_~,
) {
  env.0.visit_Expr(cond)
  env.0.visit_Region(then_)
  env.0.visit_Region(else_)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Region_If(
  env,
  cond~,
  then_~,
  else_~,
  cont~,
) {
  env.0.visit_Expr(cond)
  env.0.visit_Region(then_)
  match else_ {
    Some(region) => env.0.visit_Region(region)
    None => ()
  }
  let (label, region) = cont
  env.0.visit_Label(label)
  env.0.visit_Region(region)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Region_Loop(
  env,
  header~,
  init_args~,
  shape~,
  body~,
  exit_region~,
) {
  env.0.visit_Label(header)
  for arg in init_args {
    env.0.visit_Expr(arg)
  }
  env.0.visit_LoopShape(shape)
  env.0.visit_Region(body)
  iter_visit_cont(env.0, exit_region)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Region_Goto(
  env,
  target~,
) {
  env.0.visit_Target(target)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_LoopShape(
  env,
  shape,
) {
  match shape {
    UnknownLS => env.0.visit_LoopShape_UnknownLS()
    NumericForLS(value, init, limit, step) =>
      env.0.visit_LoopShape_NumericForLS(value~, init~, limit~, step~)
    GenericForLS(vars, exprs, multi) =>
      env.0.visit_LoopShape_GenericForLS(vars~, exprs~, multi~)
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_LoopShape_UnknownLS(
  _env,
) {
  ()
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_LoopShape_NumericForLS(
  env,
  value~,
  init~,
  limit~,
  step~,
) {
  env.0.visit_Var(value)
  env.0.visit_Expr(init)
  env.0.visit_Expr(limit)
  env.0.visit_Expr(step)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_LoopShape_GenericForLS(
  env,
  vars~,
  exprs~,
  multi~,
) {
  for value in vars {
    env.0.visit_Var(value)
  }
  for expr in exprs {
    env.0.visit_Expr(expr)
  }
  match multi {
    Some(multi) => env.0.visit_Multi(multi)
    None => ()
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Stmt(
  env,
  stmt,
) {
  @ssa.IterVisitorBase::visit_Stmt(ssa_iter_base(env.0), stmt)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Expr(
  env,
  expr,
) {
  @ssa.IterVisitorBase::visit_Expr(ssa_iter_base(env.0), expr)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Target(
  env,
  target,
) {
  @ssa.IterVisitorBase::visit_Target(ssa_iter_base(env.0), target)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Multi(
  env,
  multi,
) {
  @ssa.IterVisitorBase::visit_Multi(ssa_iter_base(env.0), multi)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Call(
  env,
  call,
) {
  @ssa.IterVisitorBase::visit_Call(ssa_iter_base(env.0), call)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_TableInit(
  env,
  init,
) {
  @ssa.IterVisitorBase::visit_TableInit(ssa_iter_base(env.0), init)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Var(
  _env,
  _value,
) {
  ()
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Cell(
  _env,
  _cell,
) {
  ()
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Label(
  _env,
  _label,
) {
  ()
}
