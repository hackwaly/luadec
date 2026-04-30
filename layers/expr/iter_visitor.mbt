///|
pub(open) trait IterVisitor {
  base(Self) -> IterVisitorBase[Self] = _
  visit_Program(Self, Program) -> Unit = _
  visit_Block(Self, Block) -> Unit = _
  visit_Func(Self, Func) -> Unit = _
  visit_Stmt(Self, Stmt) -> Unit = _
  visit_Stmt_BindS(Self, value~ : Var, expr~ : Expr) -> Unit = _
  visit_Stmt_BindMultiS(Self, values~ : Array[Var], multi~ : Multi) -> Unit = _
  visit_Stmt_SetIndexS(Self, target~ : Expr, key~ : Expr, value~ : Expr) -> Unit = _
  visit_Stmt_SetListS(
    Self,
    target~ : Expr,
    index~ : Expr,
    values~ : Array[Expr],
    multi~ : Multi?,
  ) -> Unit = _
  visit_Stmt_LocalS(Self, cells~ : Array[Cell], values~ : Array[Expr]) -> Unit = _
  visit_Stmt_ParallelAssignS(Self, cells~ : Array[Cell], values~ : Array[Expr]) -> Unit = _
  visit_Stmt_ReturnS(Self, values~ : Array[Expr], multi~ : Multi?) -> Unit = _
  visit_Stmt_DoS(Self, body~ : Block) -> Unit = _
  visit_Stmt_IfS(Self, branches~ : Array[(Expr, Block)], else_body~ : Block?) -> Unit = _
  visit_Stmt_WhileS(Self, cond~ : Expr, body~ : Block) -> Unit = _
  visit_Stmt_NumericForS(
    Self,
    value~ : Var,
    start~ : Expr,
    stop~ : Expr,
    step~ : Expr?,
    body~ : Block,
  ) -> Unit = _
  visit_Stmt_GenericForS(
    Self,
    values~ : Array[Var],
    iterators~ : Array[Expr],
    multi~ : Multi?,
    body~ : Block,
  ) -> Unit = _
  visit_Stmt_BreakS(Self) -> Unit = _
  visit_Expr(Self, Expr) -> Unit = _
  visit_Expr_ConstE(Self, value~ : Constant) -> Unit = _
  visit_Expr_VarE(Self, value~ : Var) -> Unit = _
  visit_Expr_CellE(Self, cell~ : Cell) -> Unit = _
  visit_Expr_NumericForCheckE(Self, ctrl~ : Expr, limit~ : Expr, step~ : Expr) -> Unit = _
  visit_Expr_IndexE(Self, target~ : Expr, key~ : Expr) -> Unit = _
  visit_Expr_TableE(Self, init~ : TableInit) -> Unit = _
  visit_Expr_UnaryE(Self, op~ : UnaryOp, inner~ : Expr) -> Unit = _
  visit_Expr_BinaryE(Self, op~ : BinaryOp, lhs~ : Expr, rhs~ : Expr) -> Unit = _
  visit_Expr_AndE(Self, lhs~ : Expr, rhs~ : Expr) -> Unit = _
  visit_Expr_OrE(Self, lhs~ : Expr, rhs~ : Expr) -> Unit = _
  visit_Expr_CallE(Self, call~ : Call) -> Unit = _
  visit_Expr_ClosureE(Self, func~ : Func) -> Unit = _
  visit_Multi(Self, Multi) -> Unit = _
  visit_Multi_VarargM(Self) -> Unit = _
  visit_Multi_CallM(Self, call~ : Call) -> Unit = _
  visit_Call(Self, Call) -> Unit = _
  visit_Call_NormalC(Self, callee~ : Expr, args~ : Array[Expr], multi~ : Multi?) -> Unit = _
  visit_Call_MethodC(
    Self,
    target~ : Expr,
    method_name~ : String,
    args~ : Array[Expr],
    multi~ : Multi?,
  ) -> Unit = _
  visit_TableInit(Self, TableInit) -> Unit = _
  visit_TableInit_EmptyTI(Self) -> Unit = _
  visit_TableInit_ArrayTI(Self, items~ : Array[Expr], multi~ : Multi?) -> Unit = _
  visit_TableInit_TableTI(Self, fields~ : Array[(Expr, Expr)]) -> Unit = _
  visit_Var(Self, Var) -> Unit = _
  visit_Cell(Self, Cell) -> Unit = _
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
impl IterVisitor with visit_Block(env, body) {
  IterVisitorBase::visit_Block(env, body)
}

///|
impl IterVisitor with visit_Func(env, func) {
  IterVisitorBase::visit_Func(env, func)
}

///|
impl IterVisitor with visit_Stmt(env, stmt) {
  IterVisitorBase::visit_Stmt(env, stmt)
}

///|
impl IterVisitor with visit_Stmt_BindS(env, value~, expr~) {
  IterVisitorBase::visit_Stmt_BindS(env, value~, expr~)
}

///|
impl IterVisitor with visit_Stmt_BindMultiS(env, values~, multi~) {
  IterVisitorBase::visit_Stmt_BindMultiS(env, values~, multi~)
}

///|
impl IterVisitor with visit_Stmt_SetIndexS(env, target~, key~, value~) {
  IterVisitorBase::visit_Stmt_SetIndexS(env, target~, key~, value~)
}

///|
impl IterVisitor with visit_Stmt_SetListS(env, target~, index~, values~, multi~) {
  IterVisitorBase::visit_Stmt_SetListS(env, target~, index~, values~, multi~)
}

///|
impl IterVisitor with visit_Stmt_LocalS(env, cells~, values~) {
  IterVisitorBase::visit_Stmt_LocalS(env, cells~, values~)
}

///|
impl IterVisitor with visit_Stmt_ParallelAssignS(env, cells~, values~) {
  IterVisitorBase::visit_Stmt_ParallelAssignS(env, cells~, values~)
}

///|
impl IterVisitor with visit_Stmt_ReturnS(env, values~, multi~) {
  IterVisitorBase::visit_Stmt_ReturnS(env, values~, multi~)
}

///|
impl IterVisitor with visit_Stmt_DoS(env, body~) {
  IterVisitorBase::visit_Stmt_DoS(env, body~)
}

///|
impl IterVisitor with visit_Stmt_IfS(env, branches~, else_body~) {
  IterVisitorBase::visit_Stmt_IfS(env, branches~, else_body~)
}

///|
impl IterVisitor with visit_Stmt_WhileS(env, cond~, body~) {
  IterVisitorBase::visit_Stmt_WhileS(env, cond~, body~)
}

///|
impl IterVisitor with visit_Stmt_NumericForS(
  env,
  value~,
  start~,
  stop~,
  step~,
  body~,
) {
  IterVisitorBase::visit_Stmt_NumericForS(
    env,
    value~,
    start~,
    stop~,
    step~,
    body~,
  )
}

///|
impl IterVisitor with visit_Stmt_GenericForS(
  env,
  values~,
  iterators~,
  multi~,
  body~,
) {
  IterVisitorBase::visit_Stmt_GenericForS(
    env,
    values~,
    iterators~,
    multi~,
    body~,
  )
}

///|
impl IterVisitor with visit_Stmt_BreakS(env) {
  IterVisitorBase::visit_Stmt_BreakS(env)
}

///|
impl IterVisitor with visit_Expr(env, expr) {
  IterVisitorBase::visit_Expr(env, expr)
}

///|
impl IterVisitor with visit_Expr_ConstE(env, value~) {
  IterVisitorBase::visit_Expr_ConstE(env, value~)
}

///|
impl IterVisitor with visit_Expr_VarE(env, value~) {
  IterVisitorBase::visit_Expr_VarE(env, value~)
}

///|
impl IterVisitor with visit_Expr_CellE(env, cell~) {
  IterVisitorBase::visit_Expr_CellE(env, cell~)
}

///|
impl IterVisitor with visit_Expr_NumericForCheckE(env, ctrl~, limit~, step~) {
  IterVisitorBase::visit_Expr_NumericForCheckE(env, ctrl~, limit~, step~)
}

///|
impl IterVisitor with visit_Expr_IndexE(env, target~, key~) {
  IterVisitorBase::visit_Expr_IndexE(env, target~, key~)
}

///|
impl IterVisitor with visit_Expr_TableE(env, init~) {
  IterVisitorBase::visit_Expr_TableE(env, init~)
}

///|
impl IterVisitor with visit_Expr_UnaryE(env, op~, inner~) {
  IterVisitorBase::visit_Expr_UnaryE(env, op~, inner~)
}

///|
impl IterVisitor with visit_Expr_BinaryE(env, op~, lhs~, rhs~) {
  IterVisitorBase::visit_Expr_BinaryE(env, op~, lhs~, rhs~)
}

///|
impl IterVisitor with visit_Expr_AndE(env, lhs~, rhs~) {
  IterVisitorBase::visit_Expr_AndE(env, lhs~, rhs~)
}

///|
impl IterVisitor with visit_Expr_OrE(env, lhs~, rhs~) {
  IterVisitorBase::visit_Expr_OrE(env, lhs~, rhs~)
}

///|
impl IterVisitor with visit_Expr_CallE(env, call~) {
  IterVisitorBase::visit_Expr_CallE(env, call~)
}

///|
impl IterVisitor with visit_Expr_ClosureE(env, func~) {
  IterVisitorBase::visit_Expr_ClosureE(env, func~)
}

///|
impl IterVisitor with visit_Multi(env, multi) {
  IterVisitorBase::visit_Multi(env, multi)
}

///|
impl IterVisitor with visit_Multi_VarargM(env) {
  IterVisitorBase::visit_Multi_VarargM(env)
}

///|
impl IterVisitor with visit_Multi_CallM(env, call~) {
  IterVisitorBase::visit_Multi_CallM(env, call~)
}

///|
impl IterVisitor with visit_Call(env, call) {
  IterVisitorBase::visit_Call(env, call)
}

///|
impl IterVisitor with visit_Call_NormalC(env, callee~, args~, multi~) {
  IterVisitorBase::visit_Call_NormalC(env, callee~, args~, multi~)
}

///|
impl IterVisitor with visit_Call_MethodC(
  env,
  target~,
  method_name~,
  args~,
  multi~,
) {
  IterVisitorBase::visit_Call_MethodC(env, target~, method_name~, args~, multi~)
}

///|
impl IterVisitor with visit_TableInit(env, init) {
  IterVisitorBase::visit_TableInit(env, init)
}

///|
impl IterVisitor with visit_TableInit_EmptyTI(env) {
  IterVisitorBase::visit_TableInit_EmptyTI(env)
}

///|
impl IterVisitor with visit_TableInit_ArrayTI(env, items~, multi~) {
  IterVisitorBase::visit_TableInit_ArrayTI(env, items~, multi~)
}

///|
impl IterVisitor with visit_TableInit_TableTI(env, fields~) {
  IterVisitorBase::visit_TableInit_TableTI(env, fields~)
}

///|
impl IterVisitor with visit_Var(_env, _value) {
  ()
}

///|
impl IterVisitor with visit_Cell(_env, _cell) {
  ()
}

///|
pub(all) struct IterVisitorBase[T](T)

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Program(
  env,
  program,
) {
  env.0.visit_Block(program)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Block(
  env,
  body,
) {
  for stmt in body {
    env.0.visit_Stmt(stmt)
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
  env.0.visit_Block(func.body)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Stmt(
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
    BreakS => env.0.visit_Stmt_BreakS()
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Stmt_BindS(
  env,
  value~,
  expr~,
) {
  env.0.visit_Var(value)
  env.0.visit_Expr(expr)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Stmt_BindMultiS(
  env,
  values~,
  multi~,
) {
  for value in values {
    env.0.visit_Var(value)
  }
  env.0.visit_Multi(multi)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Stmt_SetIndexS(
  env,
  target~,
  key~,
  value~,
) {
  env.0.visit_Expr(target)
  env.0.visit_Expr(key)
  env.0.visit_Expr(value)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Stmt_SetListS(
  env,
  target~,
  index~,
  values~,
  multi~,
) {
  env.0.visit_Expr(target)
  env.0.visit_Expr(index)
  for value in values {
    env.0.visit_Expr(value)
  }
  match multi {
    Some(next) => env.0.visit_Multi(next)
    None => ()
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Stmt_LocalS(
  env,
  cells~,
  values~,
) {
  for cell in cells {
    env.0.visit_Cell(cell)
  }
  for value in values {
    env.0.visit_Expr(value)
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Stmt_ParallelAssignS(
  env,
  cells~,
  values~,
) {
  for cell in cells {
    env.0.visit_Cell(cell)
  }
  for value in values {
    env.0.visit_Expr(value)
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Stmt_ReturnS(
  env,
  values~,
  multi~,
) {
  for value in values {
    env.0.visit_Expr(value)
  }
  match multi {
    Some(next) => env.0.visit_Multi(next)
    None => ()
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Stmt_DoS(
  env,
  body~,
) {
  env.0.visit_Block(body)
}

///|
fn[T : IterVisitor] iter_visit_branch(env : T, branch : (Expr, Block)) -> Unit {
  let (cond, body) = branch
  env.visit_Expr(cond)
  env.visit_Block(body)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Stmt_IfS(
  env,
  branches~,
  else_body~,
) {
  for branch in branches {
    iter_visit_branch(env.0, branch)
  }
  match else_body {
    Some(body) => env.0.visit_Block(body)
    None => ()
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Stmt_WhileS(
  env,
  cond~,
  body~,
) {
  env.0.visit_Expr(cond)
  env.0.visit_Block(body)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Stmt_NumericForS(
  env,
  value~,
  start~,
  stop~,
  step~,
  body~,
) {
  env.0.visit_Var(value)
  env.0.visit_Expr(start)
  env.0.visit_Expr(stop)
  match step {
    Some(value) => env.0.visit_Expr(value)
    None => ()
  }
  env.0.visit_Block(body)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Stmt_GenericForS(
  env,
  values~,
  iterators~,
  multi~,
  body~,
) {
  for value in values {
    env.0.visit_Var(value)
  }
  for iter in iterators {
    env.0.visit_Expr(iter)
  }
  match multi {
    Some(next) => env.0.visit_Multi(next)
    None => ()
  }
  env.0.visit_Block(body)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Stmt_BreakS(
  _env,
) {
  ()
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Expr(
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
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Expr_ConstE(
  _env,
  value~ : Constant,
) {
  ignore(value)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Expr_VarE(
  env,
  value~,
) {
  env.0.visit_Var(value)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Expr_CellE(
  env,
  cell~,
) {
  env.0.visit_Cell(cell)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Expr_NumericForCheckE(
  env,
  ctrl~,
  limit~,
  step~,
) {
  env.0.visit_Expr(ctrl)
  env.0.visit_Expr(limit)
  env.0.visit_Expr(step)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Expr_IndexE(
  env,
  target~,
  key~,
) {
  env.0.visit_Expr(target)
  env.0.visit_Expr(key)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Expr_TableE(
  env,
  init~,
) {
  env.0.visit_TableInit(init)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Expr_UnaryE(
  env,
  op~ : UnaryOp,
  inner~,
) {
  ignore(op)
  env.0.visit_Expr(inner)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Expr_BinaryE(
  env,
  op~ : BinaryOp,
  lhs~,
  rhs~,
) {
  ignore(op)
  env.0.visit_Expr(lhs)
  env.0.visit_Expr(rhs)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Expr_AndE(
  env,
  lhs~,
  rhs~,
) {
  env.0.visit_Expr(lhs)
  env.0.visit_Expr(rhs)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Expr_OrE(
  env,
  lhs~,
  rhs~,
) {
  env.0.visit_Expr(lhs)
  env.0.visit_Expr(rhs)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Expr_CallE(
  env,
  call~,
) {
  env.0.visit_Call(call)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Expr_ClosureE(
  env,
  func~,
) {
  env.0.visit_Func(func)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Multi(
  env,
  multi,
) {
  match multi {
    VarargM => env.0.visit_Multi_VarargM()
    CallM(call) => env.0.visit_Multi_CallM(call~)
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Multi_VarargM(
  _env,
) {
  ()
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Multi_CallM(
  env,
  call~,
) {
  env.0.visit_Call(call)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Call(
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
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Call_NormalC(
  env,
  callee~,
  args~,
  multi~,
) {
  env.0.visit_Expr(callee)
  for arg in args {
    env.0.visit_Expr(arg)
  }
  match multi {
    Some(next) => env.0.visit_Multi(next)
    None => ()
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_Call_MethodC(
  env,
  target~,
  method_name~,
  args~,
  multi~,
) {
  ignore(method_name)
  env.0.visit_Expr(target)
  for arg in args {
    env.0.visit_Expr(arg)
  }
  match multi {
    Some(next) => env.0.visit_Multi(next)
    None => ()
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_TableInit(
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
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_TableInit_EmptyTI(
  _env,
) {
  ()
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_TableInit_ArrayTI(
  env,
  items~,
  multi~,
) {
  for item in items {
    env.0.visit_Expr(item)
  }
  match multi {
    Some(next) => env.0.visit_Multi(next)
    None => ()
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with visit_TableInit_TableTI(
  env,
  fields~,
) {
  for field in fields {
    let (key, value) = field
    env.0.visit_Expr(key)
    env.0.visit_Expr(value)
  }
}
