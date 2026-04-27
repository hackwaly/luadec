///|
pub(open) trait MapVisitor {
  base(Self) -> MapVisitorBase[Self] = _
  visit_Program(Self, Program) -> Program = _
  visit_Func(Self, Func) -> Func = _
  visit_Region(Self, Region) -> Region = _
  visit_Region_Linear(Self, stmts~ : Array[Stmt], next~ : Region) -> Region = _
  visit_Region_Return(Self, values~ : Array[Expr], multi~ : Multi?) -> Region = _
  visit_Region_If(
    Self,
    cond~ : Expr,
    then_~ : Region,
    else_~ : Region,
    cont~ : (Label, Region)?,
  ) -> Region = _
  visit_Region_Loop(
    Self,
    header~ : Label,
    init_args~ : Array[Expr],
    shape~ : LoopShape,
    body~ : Region,
    exit_region~ : (Label, Region)?,
  ) -> Region = _
  visit_Region_Goto(Self, target~ : Target) -> Region = _
  visit_LoopShape(Self, LoopShape) -> LoopShape = _
  visit_LoopShape_UnknownLS(Self) -> LoopShape = _
  visit_LoopShape_NumericForLS(
    Self,
    value~ : Var,
    init~ : Expr,
    limit~ : Expr,
    step~ : Expr,
  ) -> LoopShape = _
  visit_LoopShape_GenericForLS(
    Self,
    vars~ : Array[Var],
    exprs~ : Array[Expr],
    multi~ : Multi?,
  ) -> LoopShape = _
  visit_Stmt(Self, Stmt) -> Stmt = _
  visit_Expr(Self, Expr) -> Expr = _
  visit_Target(Self, Target) -> Target = _
  visit_Multi(Self, Multi) -> Multi = _
  visit_Call(Self, @ssa.Call) -> @ssa.Call = _
  visit_TableInit(Self, @ssa.TableInit) -> @ssa.TableInit = _
  visit_Var(Self, Var) -> Var = _
  visit_Cell(Self, Cell) -> Cell = _
  visit_Label(Self, Label) -> Label = _
}

///|
impl MapVisitor with base(self) -> MapVisitorBase[Self] {
  MapVisitorBase::MapVisitorBase(self)
}

///|
impl MapVisitor with visit_Program(env, program) {
  MapVisitorBase::visit_Program(env, program)
}

///|
impl MapVisitor with visit_Func(env, func) {
  MapVisitorBase::visit_Func(env, func)
}

///|
impl MapVisitor with visit_Region(env, region) {
  MapVisitorBase::visit_Region(env, region)
}

///|
impl MapVisitor with visit_Region_Linear(env, stmts~, next~) {
  MapVisitorBase::visit_Region_Linear(env, stmts~, next~)
}

///|
impl MapVisitor with visit_Region_Return(env, values~, multi~) {
  MapVisitorBase::visit_Region_Return(env, values~, multi~)
}

///|
impl MapVisitor with visit_Region_If(env, cond~, then_~, else_~, cont~) {
  MapVisitorBase::visit_Region_If(env, cond~, then_~, else_~, cont~)
}

///|
impl MapVisitor with visit_Region_Loop(
  env,
  header~,
  init_args~,
  shape~,
  body~,
  exit_region~,
) {
  MapVisitorBase::visit_Region_Loop(
    env,
    header~,
    init_args~,
    shape~,
    body~,
    exit_region~,
  )
}

///|
impl MapVisitor with visit_Region_Goto(env, target~) {
  MapVisitorBase::visit_Region_Goto(env, target~)
}

///|
impl MapVisitor with visit_LoopShape(env, shape) {
  MapVisitorBase::visit_LoopShape(env, shape)
}

///|
impl MapVisitor with visit_LoopShape_UnknownLS(env) {
  MapVisitorBase::visit_LoopShape_UnknownLS(env)
}

///|
impl MapVisitor with visit_LoopShape_NumericForLS(
  env,
  value~,
  init~,
  limit~,
  step~,
) {
  MapVisitorBase::visit_LoopShape_NumericForLS(
    env,
    value~,
    init~,
    limit~,
    step~,
  )
}

///|
impl MapVisitor with visit_LoopShape_GenericForLS(env, vars~, exprs~, multi~) {
  MapVisitorBase::visit_LoopShape_GenericForLS(env, vars~, exprs~, multi~)
}

///|
impl MapVisitor with visit_Stmt(env, stmt) {
  MapVisitorBase::visit_Stmt(env, stmt)
}

///|
impl MapVisitor with visit_Expr(env, expr) {
  MapVisitorBase::visit_Expr(env, expr)
}

///|
impl MapVisitor with visit_Target(env, target) {
  MapVisitorBase::visit_Target(env, target)
}

///|
impl MapVisitor with visit_Multi(env, multi) {
  MapVisitorBase::visit_Multi(env, multi)
}

///|
impl MapVisitor with visit_Call(env, call) {
  MapVisitorBase::visit_Call(env, call)
}

///|
impl MapVisitor with visit_TableInit(env, init) {
  MapVisitorBase::visit_TableInit(env, init)
}

///|
impl MapVisitor with visit_Var(env, value) {
  MapVisitorBase::visit_Var(env, value)
}

///|
impl MapVisitor with visit_Cell(env, cell) {
  MapVisitorBase::visit_Cell(env, cell)
}

///|
impl MapVisitor with visit_Label(env, label) {
  MapVisitorBase::visit_Label(env, label)
}

///|
pub(all) struct MapVisitorBase[T](T)

///|
priv struct SsaMapAdapter[T](T)

///|
fn[T] ssa_map_base(env : T) -> @ssa.MapVisitorBase[SsaMapAdapter[T]] {
  @ssa.MapVisitorBase::MapVisitorBase(SsaMapAdapter::SsaMapAdapter(env))
}

///|
impl[T : MapVisitor] @ssa.MapVisitor for SsaMapAdapter[T] with visit_Stmt(
  env,
  stmt,
) {
  env.0.visit_Stmt(stmt)
}

///|
impl[T : MapVisitor] @ssa.MapVisitor for SsaMapAdapter[T] with visit_Expr(
  env,
  expr,
) {
  env.0.visit_Expr(expr)
}

///|
impl[T : MapVisitor] @ssa.MapVisitor for SsaMapAdapter[T] with visit_Target(
  env,
  target,
) {
  env.0.visit_Target(target)
}

///|
impl[T : MapVisitor] @ssa.MapVisitor for SsaMapAdapter[T] with visit_Multi(
  env,
  multi,
) {
  env.0.visit_Multi(multi)
}

///|
impl[T : MapVisitor] @ssa.MapVisitor for SsaMapAdapter[T] with visit_Call(
  env,
  call,
) {
  env.0.visit_Call(call)
}

///|
impl[T : MapVisitor] @ssa.MapVisitor for SsaMapAdapter[T] with visit_TableInit(
  env,
  init,
) {
  env.0.visit_TableInit(init)
}

///|
impl[T : MapVisitor] @ssa.MapVisitor for SsaMapAdapter[T] with visit_Var(
  env,
  value,
) {
  env.0.visit_Var(value)
}

///|
impl[T : MapVisitor] @ssa.MapVisitor for SsaMapAdapter[T] with visit_Cell(
  env,
  cell,
) {
  env.0.visit_Cell(cell)
}

///|
impl[T : MapVisitor] @ssa.MapVisitor for SsaMapAdapter[T] with visit_Label(
  env,
  label,
) {
  env.0.visit_Label(label)
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Program(
  env,
  program,
) {
  { ..program, funcs: program.funcs.map(fn(func) { env.0.visit_Func(func) }) }
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Func(
  env,
  func,
) {
  {
    index: func.index,
    params: func.params.map(fn(value) { env.0.visit_Var(value) }),
    cells: func.cells.map(fn(cell) { env.0.visit_Cell(cell) }),
    vararg: func.vararg,
    body: env.0.visit_Region(func.body),
  }
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Region(
  env,
  region,
) {
  match region {
    Linear(stmts, next) => env.0.visit_Region_Linear(stmts~, next~)
    Return(values, multi) => env.0.visit_Region_Return(values~, multi~)
    If(cond, then_, else_, cont) =>
      env.0.visit_Region_If(cond~, then_~, else_~, cont~)
    Loop(header, init_args, shape, body, exit_region) =>
      env.0.visit_Region_Loop(header~, init_args~, shape~, body~, exit_region~)
    Goto(target) => env.0.visit_Region_Goto(target~)
  }
}

///|
fn[T : MapVisitor] map_visit_cont(
  env : T,
  cont : (Label, Region)?,
) -> (Label, Region)? {
  cont.map(fn(item) {
    let (label, region) = item
    (env.visit_Label(label), env.visit_Region(region))
  })
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Region_Linear(
  env,
  stmts~,
  next~,
) {
  Linear(
    stmts.map(fn(stmt) { env.0.visit_Stmt(stmt) }),
    env.0.visit_Region(next),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Region_Return(
  env,
  values~,
  multi~,
) {
  Return(
    values.map(fn(value) { env.0.visit_Expr(value) }),
    multi.map(fn(multi) { env.0.visit_Multi(multi) }),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Region_If(
  env,
  cond~,
  then_~,
  else_~,
  cont~,
) {
  If(
    env.0.visit_Expr(cond),
    env.0.visit_Region(then_),
    env.0.visit_Region(else_),
    map_visit_cont(env.0, cont),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Region_Loop(
  env,
  header~,
  init_args~,
  shape~,
  body~,
  exit_region~,
) {
  Loop(
    env.0.visit_Label(header),
    init_args.map(fn(arg) { env.0.visit_Expr(arg) }),
    env.0.visit_LoopShape(shape),
    env.0.visit_Region(body),
    map_visit_cont(env.0, exit_region),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Region_Goto(
  env,
  target~,
) {
  Goto(env.0.visit_Target(target))
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_LoopShape(
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
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_LoopShape_UnknownLS(
  _env,
) {
  UnknownLS
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_LoopShape_NumericForLS(
  env,
  value~,
  init~,
  limit~,
  step~,
) {
  NumericForLS(
    env.0.visit_Var(value),
    env.0.visit_Expr(init),
    env.0.visit_Expr(limit),
    env.0.visit_Expr(step),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_LoopShape_GenericForLS(
  env,
  vars~,
  exprs~,
  multi~,
) {
  GenericForLS(
    vars.map(fn(value) { env.0.visit_Var(value) }),
    exprs.map(fn(expr) { env.0.visit_Expr(expr) }),
    multi.map(fn(multi) { env.0.visit_Multi(multi) }),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Stmt(
  env,
  stmt,
) {
  @ssa.MapVisitorBase::visit_Stmt(ssa_map_base(env.0), stmt)
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Expr(
  env,
  expr,
) {
  @ssa.MapVisitorBase::visit_Expr(ssa_map_base(env.0), expr)
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Target(
  env,
  target,
) {
  @ssa.MapVisitorBase::visit_Target(ssa_map_base(env.0), target)
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Multi(
  env,
  multi,
) {
  @ssa.MapVisitorBase::visit_Multi(ssa_map_base(env.0), multi)
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Call(
  env,
  call,
) {
  @ssa.MapVisitorBase::visit_Call(ssa_map_base(env.0), call)
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_TableInit(
  env,
  init,
) {
  @ssa.MapVisitorBase::visit_TableInit(ssa_map_base(env.0), init)
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Var(
  _env,
  value,
) {
  value
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Cell(
  _env,
  cell,
) {
  cell
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Label(
  _env,
  label,
) {
  label
}
