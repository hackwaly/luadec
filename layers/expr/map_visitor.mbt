///|
pub(open) trait MapVisitor {
  base(Self) -> MapVisitorBase[Self] = _
  visit_Program(Self, Program) -> Program = _
  visit_Block(Self, Block) -> Block = _
  visit_Func(Self, Func) -> Func = _
  visit_Stmt(Self, Stmt) -> Stmt = _
  visit_Stmt_BindS(Self, value~ : Var, expr~ : Expr) -> Stmt = _
  visit_Stmt_BindMultiS(Self, values~ : Array[Var], multi~ : Multi) -> Stmt = _
  visit_Stmt_SetIndexS(Self, target~ : Expr, key~ : Expr, value~ : Expr) -> Stmt = _
  visit_Stmt_SetListS(
    Self,
    target~ : Expr,
    index~ : Expr,
    values~ : Array[Expr],
    multi~ : Multi?,
  ) -> Stmt = _
  visit_Stmt_LocalS(Self, cells~ : Array[Cell], values~ : Array[Expr]) -> Stmt = _
  visit_Stmt_ParallelAssignS(Self, cells~ : Array[Cell], values~ : Array[Expr]) -> Stmt = _
  visit_Stmt_ReturnS(Self, values~ : Array[Expr], multi~ : Multi?) -> Stmt = _
  visit_Stmt_DoS(Self, body~ : Block) -> Stmt = _
  visit_Stmt_IfS(Self, branches~ : Array[(Expr, Block)], else_body~ : Block?) -> Stmt = _
  visit_Stmt_WhileS(Self, cond~ : Expr, body~ : Block) -> Stmt = _
  visit_Stmt_NumericForS(
    Self,
    value~ : Var,
    start~ : Expr,
    stop~ : Expr,
    step~ : Expr?,
    body~ : Block,
  ) -> Stmt = _
  visit_Stmt_GenericForS(
    Self,
    values~ : Array[Var],
    iterators~ : Array[Expr],
    multi~ : Multi?,
    body~ : Block,
  ) -> Stmt = _
  visit_Stmt_ForEachS(
    Self,
    key~ : Var,
    value~ : Var,
    iter~ : Expr,
    body~ : Block,
  ) -> Stmt = _
  visit_Stmt_BreakS(Self) -> Stmt = _
  visit_Expr(Self, Expr) -> Expr = _
  visit_Expr_ConstE(Self, value~ : Constant) -> Expr = _
  visit_Expr_VarE(Self, value~ : Var) -> Expr = _
  visit_Expr_CellE(Self, cell~ : Cell) -> Expr = _
  visit_Expr_NumericForCheckE(Self, ctrl~ : Expr, limit~ : Expr, step~ : Expr) -> Expr = _
  visit_Expr_IndexE(Self, target~ : Expr, key~ : Expr) -> Expr = _
  visit_Expr_TableE(Self, init~ : TableInit) -> Expr = _
  visit_Expr_UnaryE(Self, op~ : UnaryOp, inner~ : Expr) -> Expr = _
  visit_Expr_BinaryE(Self, op~ : BinaryOp, lhs~ : Expr, rhs~ : Expr) -> Expr = _
  visit_Expr_AndE(Self, lhs~ : Expr, rhs~ : Expr) -> Expr = _
  visit_Expr_OrE(Self, lhs~ : Expr, rhs~ : Expr) -> Expr = _
  visit_Expr_CallE(Self, call~ : Call) -> Expr = _
  visit_Expr_ClosureE(Self, func~ : Func) -> Expr = _
  visit_Multi(Self, Multi) -> Multi = _
  visit_Multi_VarargM(Self) -> Multi = _
  visit_Multi_CallM(Self, call~ : Call) -> Multi = _
  visit_Call(Self, Call) -> Call = _
  visit_Call_NormalC(Self, callee~ : Expr, args~ : Array[Expr], multi~ : Multi?) -> Call = _
  visit_Call_MethodC(
    Self,
    target~ : Expr,
    method_name~ : String,
    args~ : Array[Expr],
    multi~ : Multi?,
  ) -> Call = _
  visit_TableInit(Self, TableInit) -> TableInit = _
  visit_TableInit_EmptyTI(Self) -> TableInit = _
  visit_TableInit_ArrayTI(Self, items~ : Array[Expr], multi~ : Multi?) -> TableInit = _
  visit_TableInit_TableTI(Self, fields~ : Array[(Expr, Expr)]) -> TableInit = _
  visit_Var(Self, Var) -> Var = _
  visit_Cell(Self, Cell) -> Cell = _
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
impl MapVisitor with visit_Block(env, body) {
  MapVisitorBase::visit_Block(env, body)
}

///|
impl MapVisitor with visit_Func(env, func) {
  MapVisitorBase::visit_Func(env, func)
}

///|
impl MapVisitor with visit_Stmt(env, stmt) {
  MapVisitorBase::visit_Stmt(env, stmt)
}

///|
impl MapVisitor with visit_Stmt_BindS(env, value~, expr~) {
  MapVisitorBase::visit_Stmt_BindS(env, value~, expr~)
}

///|
impl MapVisitor with visit_Stmt_BindMultiS(env, values~, multi~) {
  MapVisitorBase::visit_Stmt_BindMultiS(env, values~, multi~)
}

///|
impl MapVisitor with visit_Stmt_SetIndexS(env, target~, key~, value~) {
  MapVisitorBase::visit_Stmt_SetIndexS(env, target~, key~, value~)
}

///|
impl MapVisitor with visit_Stmt_SetListS(env, target~, index~, values~, multi~) {
  MapVisitorBase::visit_Stmt_SetListS(env, target~, index~, values~, multi~)
}

///|
impl MapVisitor with visit_Stmt_LocalS(env, cells~, values~) {
  MapVisitorBase::visit_Stmt_LocalS(env, cells~, values~)
}

///|
impl MapVisitor with visit_Stmt_ParallelAssignS(env, cells~, values~) {
  MapVisitorBase::visit_Stmt_ParallelAssignS(env, cells~, values~)
}

///|
impl MapVisitor with visit_Stmt_ReturnS(env, values~, multi~) {
  MapVisitorBase::visit_Stmt_ReturnS(env, values~, multi~)
}

///|
impl MapVisitor with visit_Stmt_DoS(env, body~) {
  MapVisitorBase::visit_Stmt_DoS(env, body~)
}

///|
impl MapVisitor with visit_Stmt_IfS(env, branches~, else_body~) {
  MapVisitorBase::visit_Stmt_IfS(env, branches~, else_body~)
}

///|
impl MapVisitor with visit_Stmt_WhileS(env, cond~, body~) {
  MapVisitorBase::visit_Stmt_WhileS(env, cond~, body~)
}

///|
impl MapVisitor with visit_Stmt_NumericForS(
  env,
  value~,
  start~,
  stop~,
  step~,
  body~,
) {
  MapVisitorBase::visit_Stmt_NumericForS(
    env,
    value~,
    start~,
    stop~,
    step~,
    body~,
  )
}

///|
impl MapVisitor with visit_Stmt_GenericForS(
  env,
  values~,
  iterators~,
  multi~,
  body~,
) {
  MapVisitorBase::visit_Stmt_GenericForS(
    env,
    values~,
    iterators~,
    multi~,
    body~,
  )
}

///|
impl MapVisitor with visit_Stmt_ForEachS(env, key~, value~, iter~, body~) {
  MapVisitorBase::visit_Stmt_ForEachS(env, key~, value~, iter~, body~)
}

///|
impl MapVisitor with visit_Stmt_BreakS(env) {
  MapVisitorBase::visit_Stmt_BreakS(env)
}

///|
impl MapVisitor with visit_Expr(env, expr) {
  MapVisitorBase::visit_Expr(env, expr)
}

///|
impl MapVisitor with visit_Expr_ConstE(env, value~) {
  MapVisitorBase::visit_Expr_ConstE(env, value~)
}

///|
impl MapVisitor with visit_Expr_VarE(env, value~) {
  MapVisitorBase::visit_Expr_VarE(env, value~)
}

///|
impl MapVisitor with visit_Expr_CellE(env, cell~) {
  MapVisitorBase::visit_Expr_CellE(env, cell~)
}

///|
impl MapVisitor with visit_Expr_NumericForCheckE(env, ctrl~, limit~, step~) {
  MapVisitorBase::visit_Expr_NumericForCheckE(env, ctrl~, limit~, step~)
}

///|
impl MapVisitor with visit_Expr_IndexE(env, target~, key~) {
  MapVisitorBase::visit_Expr_IndexE(env, target~, key~)
}

///|
impl MapVisitor with visit_Expr_TableE(env, init~) {
  MapVisitorBase::visit_Expr_TableE(env, init~)
}

///|
impl MapVisitor with visit_Expr_UnaryE(env, op~, inner~) {
  MapVisitorBase::visit_Expr_UnaryE(env, op~, inner~)
}

///|
impl MapVisitor with visit_Expr_BinaryE(env, op~, lhs~, rhs~) {
  MapVisitorBase::visit_Expr_BinaryE(env, op~, lhs~, rhs~)
}

///|
impl MapVisitor with visit_Expr_AndE(env, lhs~, rhs~) {
  MapVisitorBase::visit_Expr_AndE(env, lhs~, rhs~)
}

///|
impl MapVisitor with visit_Expr_OrE(env, lhs~, rhs~) {
  MapVisitorBase::visit_Expr_OrE(env, lhs~, rhs~)
}

///|
impl MapVisitor with visit_Expr_CallE(env, call~) {
  MapVisitorBase::visit_Expr_CallE(env, call~)
}

///|
impl MapVisitor with visit_Expr_ClosureE(env, func~) {
  MapVisitorBase::visit_Expr_ClosureE(env, func~)
}

///|
impl MapVisitor with visit_Multi(env, multi) {
  MapVisitorBase::visit_Multi(env, multi)
}

///|
impl MapVisitor with visit_Multi_VarargM(env) {
  MapVisitorBase::visit_Multi_VarargM(env)
}

///|
impl MapVisitor with visit_Multi_CallM(env, call~) {
  MapVisitorBase::visit_Multi_CallM(env, call~)
}

///|
impl MapVisitor with visit_Call(env, call) {
  MapVisitorBase::visit_Call(env, call)
}

///|
impl MapVisitor with visit_Call_NormalC(env, callee~, args~, multi~) {
  MapVisitorBase::visit_Call_NormalC(env, callee~, args~, multi~)
}

///|
impl MapVisitor with visit_Call_MethodC(
  env,
  target~,
  method_name~,
  args~,
  multi~,
) {
  MapVisitorBase::visit_Call_MethodC(env, target~, method_name~, args~, multi~)
}

///|
impl MapVisitor with visit_TableInit(env, init) {
  MapVisitorBase::visit_TableInit(env, init)
}

///|
impl MapVisitor with visit_TableInit_EmptyTI(env) {
  MapVisitorBase::visit_TableInit_EmptyTI(env)
}

///|
impl MapVisitor with visit_TableInit_ArrayTI(env, items~, multi~) {
  MapVisitorBase::visit_TableInit_ArrayTI(env, items~, multi~)
}

///|
impl MapVisitor with visit_TableInit_TableTI(env, fields~) {
  MapVisitorBase::visit_TableInit_TableTI(env, fields~)
}

///|
impl MapVisitor with visit_Var(_env, value) {
  value
}

///|
impl MapVisitor with visit_Cell(_env, cell) {
  cell
}

///|
pub(all) struct MapVisitorBase[T](T)

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Program(
  env,
  program,
) {
  env.0.visit_Block(program)
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Block(
  env,
  body,
) {
  body.map(fn(stmt) { env.0.visit_Stmt(stmt) })
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Func(
  env,
  func,
) {
  {
    params: func.params.map(fn(value) { env.0.visit_Var(value) }),
    vararg: func.vararg,
    body: env.0.visit_Block(func.body),
  }
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Stmt(
  env,
  stmt,
) {
  match stmt {
    BindS(value, expr) => env.0.visit_Stmt_BindS(value~, expr~)
    BindMultiS(values, multi) => env.0.visit_Stmt_BindMultiS(values~, multi~)
    SetIndexS(target, key, value) =>
      env.0.visit_Stmt_SetIndexS(target~, key~, value~)
    SetListS(target, index, values, multi) =>
      env.0.visit_Stmt_SetListS(target~, index~, values~, multi~)
    LocalS(cells, values) => env.0.visit_Stmt_LocalS(cells~, values~)
    ParallelAssignS(cells, values) =>
      env.0.visit_Stmt_ParallelAssignS(cells~, values~)
    ReturnS(values, multi) => env.0.visit_Stmt_ReturnS(values~, multi~)
    DoS(body) => env.0.visit_Stmt_DoS(body~)
    IfS(branches, else_body) => env.0.visit_Stmt_IfS(branches~, else_body~)
    WhileS(cond, body) => env.0.visit_Stmt_WhileS(cond~, body~)
    NumericForS(value, start, stop, step, body) =>
      env.0.visit_Stmt_NumericForS(value~, start~, stop~, step~, body~)
    GenericForS(values, iterators, multi, body) =>
      env.0.visit_Stmt_GenericForS(values~, iterators~, multi~, body~)
    ForEachS(key, value, iter, body) =>
      env.0.visit_Stmt_ForEachS(key~, value~, iter~, body~)
    BreakS => env.0.visit_Stmt_BreakS()
  }
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Stmt_BindS(
  env,
  value~,
  expr~,
) {
  BindS(env.0.visit_Var(value), env.0.visit_Expr(expr))
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Stmt_BindMultiS(
  env,
  values~,
  multi~,
) {
  BindMultiS(
    values.map(fn(value) { env.0.visit_Var(value) }),
    env.0.visit_Multi(multi),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Stmt_SetIndexS(
  env,
  target~,
  key~,
  value~,
) {
  SetIndexS(
    env.0.visit_Expr(target),
    env.0.visit_Expr(key),
    env.0.visit_Expr(value),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Stmt_SetListS(
  env,
  target~,
  index~,
  values~,
  multi~,
) {
  SetListS(
    env.0.visit_Expr(target),
    env.0.visit_Expr(index),
    values.map(fn(value) { env.0.visit_Expr(value) }),
    multi.map(fn(next) { env.0.visit_Multi(next) }),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Stmt_LocalS(
  env,
  cells~,
  values~,
) {
  LocalS(
    cells.map(fn(cell) { env.0.visit_Cell(cell) }),
    values.map(fn(value) { env.0.visit_Expr(value) }),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Stmt_ParallelAssignS(
  env,
  cells~,
  values~,
) {
  ParallelAssignS(
    cells.map(fn(cell) { env.0.visit_Cell(cell) }),
    values.map(fn(value) { env.0.visit_Expr(value) }),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Stmt_ReturnS(
  env,
  values~,
  multi~,
) {
  ReturnS(
    values.map(fn(value) { env.0.visit_Expr(value) }),
    multi.map(fn(next) { env.0.visit_Multi(next) }),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Stmt_DoS(
  env,
  body~,
) {
  DoS(env.0.visit_Block(body))
}

///|
fn[T : MapVisitor] map_visit_branch(
  env : T,
  branch : (Expr, Block),
) -> (Expr, Block) {
  let (cond, body) = branch
  (env.visit_Expr(cond), env.visit_Block(body))
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Stmt_IfS(
  env,
  branches~,
  else_body~,
) {
  IfS(
    branches.map(fn(branch) { map_visit_branch(env.0, branch) }),
    else_body.map(fn(body) { env.0.visit_Block(body) }),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Stmt_WhileS(
  env,
  cond~,
  body~,
) {
  WhileS(env.0.visit_Expr(cond), env.0.visit_Block(body))
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Stmt_NumericForS(
  env,
  value~,
  start~,
  stop~,
  step~,
  body~,
) {
  NumericForS(
    env.0.visit_Var(value),
    env.0.visit_Expr(start),
    env.0.visit_Expr(stop),
    step.map(fn(value) { env.0.visit_Expr(value) }),
    env.0.visit_Block(body),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Stmt_GenericForS(
  env,
  values~,
  iterators~,
  multi~,
  body~,
) {
  GenericForS(
    values.map(fn(value) { env.0.visit_Var(value) }),
    iterators.map(fn(iter) { env.0.visit_Expr(iter) }),
    multi.map(fn(next) { env.0.visit_Multi(next) }),
    env.0.visit_Block(body),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Stmt_ForEachS(
  env,
  key~,
  value~,
  iter~,
  body~,
) {
  ForEachS(
    env.0.visit_Var(key),
    env.0.visit_Var(value),
    env.0.visit_Expr(iter),
    env.0.visit_Block(body),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Stmt_BreakS(
  _env,
) {
  BreakS
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Expr(
  env,
  expr,
) {
  match expr {
    ConstE(value) => env.0.visit_Expr_ConstE(value~)
    VarE(value) => env.0.visit_Expr_VarE(value~)
    CellE(cell) => env.0.visit_Expr_CellE(cell~)
    NumericForCheckE(ctrl, limit, step) =>
      env.0.visit_Expr_NumericForCheckE(ctrl~, limit~, step~)
    IndexE(target, key) => env.0.visit_Expr_IndexE(target~, key~)
    TableE(init) => env.0.visit_Expr_TableE(init~)
    UnaryE(op, inner) => env.0.visit_Expr_UnaryE(op~, inner~)
    BinaryE(op, lhs, rhs) => env.0.visit_Expr_BinaryE(op~, lhs~, rhs~)
    AndE(lhs, rhs) => env.0.visit_Expr_AndE(lhs~, rhs~)
    OrE(lhs, rhs) => env.0.visit_Expr_OrE(lhs~, rhs~)
    CallE(call) => env.0.visit_Expr_CallE(call~)
    ClosureE(func) => env.0.visit_Expr_ClosureE(func~)
  }
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Expr_ConstE(
  _env,
  value~,
) {
  ConstE(value)
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Expr_VarE(
  env,
  value~,
) {
  VarE(env.0.visit_Var(value))
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Expr_CellE(
  env,
  cell~,
) {
  CellE(env.0.visit_Cell(cell))
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Expr_NumericForCheckE(
  env,
  ctrl~,
  limit~,
  step~,
) {
  NumericForCheckE(
    env.0.visit_Expr(ctrl),
    env.0.visit_Expr(limit),
    env.0.visit_Expr(step),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Expr_IndexE(
  env,
  target~,
  key~,
) {
  IndexE(env.0.visit_Expr(target), env.0.visit_Expr(key))
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Expr_TableE(
  env,
  init~,
) {
  TableE(env.0.visit_TableInit(init))
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Expr_UnaryE(
  env,
  op~,
  inner~,
) {
  UnaryE(op, env.0.visit_Expr(inner))
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Expr_BinaryE(
  env,
  op~,
  lhs~,
  rhs~,
) {
  BinaryE(op, env.0.visit_Expr(lhs), env.0.visit_Expr(rhs))
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Expr_AndE(
  env,
  lhs~,
  rhs~,
) {
  AndE(env.0.visit_Expr(lhs), env.0.visit_Expr(rhs))
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Expr_OrE(
  env,
  lhs~,
  rhs~,
) {
  OrE(env.0.visit_Expr(lhs), env.0.visit_Expr(rhs))
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Expr_CallE(
  env,
  call~,
) {
  CallE(env.0.visit_Call(call))
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Expr_ClosureE(
  env,
  func~,
) {
  ClosureE(env.0.visit_Func(func))
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Multi(
  env,
  multi,
) {
  match multi {
    VarargM => env.0.visit_Multi_VarargM()
    CallM(call) => env.0.visit_Multi_CallM(call~)
  }
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Multi_VarargM(
  _env,
) {
  VarargM
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Multi_CallM(
  env,
  call~,
) {
  CallM(env.0.visit_Call(call))
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Call(
  env,
  call,
) {
  match call {
    NormalC(callee, args, multi) =>
      env.0.visit_Call_NormalC(callee~, args~, multi~)
    MethodC(target, method_name, args, multi) =>
      env.0.visit_Call_MethodC(target~, method_name~, args~, multi~)
  }
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Call_NormalC(
  env,
  callee~,
  args~,
  multi~,
) {
  NormalC(
    env.0.visit_Expr(callee),
    args.map(fn(arg) { env.0.visit_Expr(arg) }),
    multi.map(fn(next) { env.0.visit_Multi(next) }),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Call_MethodC(
  env,
  target~,
  method_name~,
  args~,
  multi~,
) {
  MethodC(
    env.0.visit_Expr(target),
    method_name,
    args.map(fn(arg) { env.0.visit_Expr(arg) }),
    multi.map(fn(next) { env.0.visit_Multi(next) }),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_TableInit(
  env,
  init,
) {
  match init {
    EmptyTI => env.0.visit_TableInit_EmptyTI()
    ArrayTI(items, multi) => env.0.visit_TableInit_ArrayTI(items~, multi~)
    TableTI(fields) => env.0.visit_TableInit_TableTI(fields~)
  }
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_TableInit_EmptyTI(
  _env,
) {
  EmptyTI
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_TableInit_ArrayTI(
  env,
  items~,
  multi~,
) {
  ArrayTI(
    items.map(fn(item) { env.0.visit_Expr(item) }),
    multi.map(fn(next) { env.0.visit_Multi(next) }),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_TableInit_TableTI(
  env,
  fields~,
) {
  TableTI(
    fields.map(fn(field) {
      let (key, value) = field
      (env.0.visit_Expr(key), env.0.visit_Expr(value))
    }),
  )
}
