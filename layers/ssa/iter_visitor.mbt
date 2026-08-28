///|
pub(open) trait IterVisitor {
  fn base(Self) -> IterVisitorBase[Self] = _
  fn visit_Program(Self, Program) -> Unit = _
  fn visit_Func(Self, Func) -> Unit = _
  fn visit_Block(Self, Block) -> Unit = _
  fn visit_Stmt(Self, Stmt) -> Unit = _
  fn visit_Stmt_BindS(Self, value~ : Var, expr~ : Expr) -> Unit = _
  fn visit_Stmt_StoreCellS(Self, cell~ : Cell, expr~ : Expr) -> Unit = _
  fn visit_Stmt_SetIndexS(Self, table~ : Expr, index~ : Expr, value~ : Expr) -> Unit = _
  fn visit_Stmt_BindMultiS(Self, values~ : Array[Var], multi~ : Multi) -> Unit = _
  fn visit_Stmt_SetListS(
    Self,
    table~ : Expr,
    index~ : Expr,
    values~ : Array[Expr],
    multi~ : Multi?,
  ) -> Unit = _
  fn visit_Term(Self, Term) -> Unit = _
  fn visit_Term_JumpT(Self, target~ : Target) -> Unit = _
  fn visit_Term_CondT(Self, cond~ : Expr, then_~ : Target, else_~ : Target) -> Unit = _
  fn visit_Term_ReturnT(Self, values~ : Array[Expr], multi~ : Multi?) -> Unit = _
  fn visit_Target(Self, Target) -> Unit = _
  fn visit_Multi(Self, Multi) -> Unit = _
  fn visit_Multi_VarargM(Self) -> Unit = _
  fn visit_Multi_CallM(Self, call~ : Call) -> Unit = _
  fn visit_Call(Self, Call) -> Unit = _
  fn visit_Call_NormalC(
    Self,
    target~ : Expr,
    args~ : Array[Expr],
    multi~ : Multi?,
  ) -> Unit = _
  fn visit_Call_MethodC(
    Self,
    target~ : Expr,
    method_name~ : String,
    args~ : Array[Expr],
    multi~ : Multi?,
  ) -> Unit = _
  fn visit_Expr(Self, Expr) -> Unit = _
  fn visit_Expr_ConstE(Self, constant~ : Constant) -> Unit = _
  fn visit_Expr_VarE(Self, value~ : Var) -> Unit = _
  fn visit_Expr_CellE(Self, cell~ : Cell) -> Unit = _
  fn visit_Expr_NumericForCheckE(
    Self,
    ctrl~ : Expr,
    limit~ : Expr,
    step~ : Expr,
  ) -> Unit = _
  fn visit_Expr_IndexE(Self, table~ : Expr, index~ : Expr) -> Unit = _
  fn visit_Expr_TableE(Self, init~ : TableInit) -> Unit = _
  fn visit_Expr_UnaryE(Self, op~ : UnaryOp, expr~ : Expr) -> Unit = _
  fn visit_Expr_BinaryE(Self, op~ : BinaryOp, lhs~ : Expr, rhs~ : Expr) -> Unit = _
  fn visit_Expr_AndE(Self, lhs~ : Expr, rhs~ : Expr) -> Unit = _
  fn visit_Expr_OrE(Self, lhs~ : Expr, rhs~ : Expr) -> Unit = _
  fn visit_Expr_CallE(Self, call~ : Call) -> Unit = _
  fn visit_Expr_ClosureE(Self, func~ : FuncId, captures~ : Array[Var]) -> Unit = _
  fn visit_TableInit(Self, TableInit) -> Unit = _
  fn visit_TableInit_EmptyTI(Self) -> Unit = _
  fn visit_TableInit_ArrayTI(Self, values~ : Array[Expr], multi~ : Multi?) -> Unit = _
  fn visit_TableInit_TableTI(Self, fields~ : Array[(Expr, Expr)]) -> Unit = _
  fn visit_Var(Self, Var) -> Unit = _
  fn visit_Cell(Self, Cell) -> Unit = _
  fn visit_Label(Self, Label) -> Unit = _
}

///|
impl IterVisitor with fn base(self) -> IterVisitorBase[Self] {
  IterVisitorBase::IterVisitorBase(self)
}

///|
impl IterVisitor with fn visit_Program(env, program) {
  IterVisitorBase::visit_Program(env, program)
}

///|
impl IterVisitor with fn visit_Func(env, func) {
  IterVisitorBase::visit_Func(env, func)
}

///|
impl IterVisitor with fn visit_Block(env, block) {
  IterVisitorBase::visit_Block(env, block)
}

///|
impl IterVisitor with fn visit_Stmt(env, stmt) {
  IterVisitorBase::visit_Stmt(env, stmt)
}

///|
impl IterVisitor with fn visit_Stmt_BindS(env, value~, expr~) {
  IterVisitorBase::visit_Stmt_BindS(env, value~, expr~)
}

///|
impl IterVisitor with fn visit_Stmt_StoreCellS(env, cell~, expr~) {
  IterVisitorBase::visit_Stmt_StoreCellS(env, cell~, expr~)
}

///|
impl IterVisitor with fn visit_Stmt_SetIndexS(env, table~, index~, value~) {
  IterVisitorBase::visit_Stmt_SetIndexS(env, table~, index~, value~)
}

///|
impl IterVisitor with fn visit_Stmt_BindMultiS(env, values~, multi~) {
  IterVisitorBase::visit_Stmt_BindMultiS(env, values~, multi~)
}

///|
impl IterVisitor with fn visit_Stmt_SetListS(
  env,
  table~,
  index~,
  values~,
  multi~,
) {
  IterVisitorBase::visit_Stmt_SetListS(env, table~, index~, values~, multi~)
}

///|
impl IterVisitor with fn visit_Term(env, term) {
  IterVisitorBase::visit_Term(env, term)
}

///|
impl IterVisitor with fn visit_Term_JumpT(env, target~) {
  IterVisitorBase::visit_Term_JumpT(env, target~)
}

///|
impl IterVisitor with fn visit_Term_CondT(env, cond~, then_~, else_~) {
  IterVisitorBase::visit_Term_CondT(env, cond~, then_~, else_~)
}

///|
impl IterVisitor with fn visit_Term_ReturnT(env, values~, multi~) {
  IterVisitorBase::visit_Term_ReturnT(env, values~, multi~)
}

///|
impl IterVisitor with fn visit_Target(env, target) {
  IterVisitorBase::visit_Target(env, target)
}

///|
impl IterVisitor with fn visit_Multi(env, multi) {
  IterVisitorBase::visit_Multi(env, multi)
}

///|
impl IterVisitor with fn visit_Multi_VarargM(env) {
  IterVisitorBase::visit_Multi_VarargM(env)
}

///|
impl IterVisitor with fn visit_Multi_CallM(env, call~) {
  IterVisitorBase::visit_Multi_CallM(env, call~)
}

///|
impl IterVisitor with fn visit_Call(env, call) {
  IterVisitorBase::visit_Call(env, call)
}

///|
impl IterVisitor with fn visit_Call_NormalC(env, target~, args~, multi~) {
  IterVisitorBase::visit_Call_NormalC(env, target~, args~, multi~)
}

///|
impl IterVisitor with fn visit_Call_MethodC(
  env,
  target~,
  method_name~,
  args~,
  multi~,
) {
  IterVisitorBase::visit_Call_MethodC(env, target~, method_name~, args~, multi~)
}

///|
impl IterVisitor with fn visit_Expr(env, expr) {
  IterVisitorBase::visit_Expr(env, expr)
}

///|
impl IterVisitor with fn visit_Expr_ConstE(env, constant~) {
  IterVisitorBase::visit_Expr_ConstE(env, constant~)
}

///|
impl IterVisitor with fn visit_Expr_VarE(env, value~) {
  IterVisitorBase::visit_Expr_VarE(env, value~)
}

///|
impl IterVisitor with fn visit_Expr_CellE(env, cell~) {
  IterVisitorBase::visit_Expr_CellE(env, cell~)
}

///|
impl IterVisitor with fn visit_Expr_NumericForCheckE(env, ctrl~, limit~, step~) {
  IterVisitorBase::visit_Expr_NumericForCheckE(env, ctrl~, limit~, step~)
}

///|
impl IterVisitor with fn visit_Expr_IndexE(env, table~, index~) {
  IterVisitorBase::visit_Expr_IndexE(env, table~, index~)
}

///|
impl IterVisitor with fn visit_Expr_TableE(env, init~) {
  IterVisitorBase::visit_Expr_TableE(env, init~)
}

///|
impl IterVisitor with fn visit_Expr_UnaryE(env, op~, expr~) {
  IterVisitorBase::visit_Expr_UnaryE(env, op~, expr~)
}

///|
impl IterVisitor with fn visit_Expr_BinaryE(env, op~, lhs~, rhs~) {
  IterVisitorBase::visit_Expr_BinaryE(env, op~, lhs~, rhs~)
}

///|
impl IterVisitor with fn visit_Expr_AndE(env, lhs~, rhs~) {
  IterVisitorBase::visit_Expr_AndE(env, lhs~, rhs~)
}

///|
impl IterVisitor with fn visit_Expr_OrE(env, lhs~, rhs~) {
  IterVisitorBase::visit_Expr_OrE(env, lhs~, rhs~)
}

///|
impl IterVisitor with fn visit_Expr_CallE(env, call~) {
  IterVisitorBase::visit_Expr_CallE(env, call~)
}

///|
impl IterVisitor with fn visit_Expr_ClosureE(env, func~, captures~) {
  IterVisitorBase::visit_Expr_ClosureE(env, func~, captures~)
}

///|
impl IterVisitor with fn visit_TableInit(env, init) {
  IterVisitorBase::visit_TableInit(env, init)
}

///|
impl IterVisitor with fn visit_TableInit_EmptyTI(env) {
  IterVisitorBase::visit_TableInit_EmptyTI(env)
}

///|
impl IterVisitor with fn visit_TableInit_ArrayTI(env, values~, multi~) {
  IterVisitorBase::visit_TableInit_ArrayTI(env, values~, multi~)
}

///|
impl IterVisitor with fn visit_TableInit_TableTI(env, fields~) {
  IterVisitorBase::visit_TableInit_TableTI(env, fields~)
}

///|
impl IterVisitor with fn visit_Var(env, value) {
  IterVisitorBase::visit_Var(env, value)
}

///|
impl IterVisitor with fn visit_Cell(env, cell) {
  IterVisitorBase::visit_Cell(env, cell)
}

///|
impl IterVisitor with fn visit_Label(env, label) {
  IterVisitorBase::visit_Label(env, label)
}

///|
pub(all) struct IterVisitorBase[T](T)

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Program(
  env,
  program,
) {
  for func in program.funcs {
    env.0.visit_Func(func)
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Func(
  env,
  func,
) {
  for param in func.params {
    env.0.visit_Var(param)
  }
  for value in func.capture_vars {
    env.0.visit_Var(value)
  }
  for cell in func.capture_cells {
    env.0.visit_Cell(cell)
  }
  for cell in func.cells {
    env.0.visit_Cell(cell)
  }
  for label, block in func.blocks {
    env.0.visit_Label(label)
    env.0.visit_Block(block)
  }
  env.0.visit_Label(func.entry)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Block(
  env,
  block,
) {
  for stmt in block.stmts {
    env.0.visit_Stmt(stmt)
  }
  env.0.visit_Term(block.term)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Stmt(
  env,
  stmt,
) {
  match stmt {
    BindS(value, expr) => env.0.visit_Stmt_BindS(value~, expr~)
    StoreCellS(cell, expr) => env.0.visit_Stmt_StoreCellS(cell~, expr~)
    SetIndexS(table, index, value) =>
      env.0.visit_Stmt_SetIndexS(table~, index~, value~)
    BindMultiS(values, multi) => env.0.visit_Stmt_BindMultiS(values~, multi~)
    SetListS(table, index, values, multi) =>
      env.0.visit_Stmt_SetListS(table~, index~, values~, multi~)
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Stmt_BindS(
  env,
  value~,
  expr~,
) {
  env.0.visit_Var(value)
  env.0.visit_Expr(expr)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Stmt_StoreCellS(
  env,
  cell~,
  expr~,
) {
  env.0.visit_Cell(cell)
  env.0.visit_Expr(expr)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Stmt_SetIndexS(
  env,
  table~,
  index~,
  value~,
) {
  env.0.visit_Expr(table)
  env.0.visit_Expr(index)
  env.0.visit_Expr(value)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Stmt_BindMultiS(
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
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Stmt_SetListS(
  env,
  table~,
  index~,
  values~,
  multi~,
) {
  env.0.visit_Expr(table)
  env.0.visit_Expr(index)
  for value in values {
    env.0.visit_Expr(value)
  }
  match multi {
    Some(multi) => env.0.visit_Multi(multi)
    None => ()
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Term(
  env,
  term,
) {
  match term {
    JumpT(target) => env.0.visit_Term_JumpT(target~)
    CondT(cond, then_, else_) => env.0.visit_Term_CondT(cond~, then_~, else_~)
    ReturnT(values, multi) => env.0.visit_Term_ReturnT(values~, multi~)
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Term_JumpT(
  env,
  target~,
) {
  env.0.visit_Target(target)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Term_CondT(
  env,
  cond~,
  then_~,
  else_~,
) {
  env.0.visit_Expr(cond)
  env.0.visit_Target(then_)
  env.0.visit_Target(else_)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Term_ReturnT(
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
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Target(
  env,
  target,
) {
  let Target(label, args) = target
  env.0.visit_Label(label)
  for arg in args {
    env.0.visit_Expr(arg)
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Multi(
  env,
  multi,
) {
  match multi {
    VarargM => env.0.visit_Multi_VarargM()
    CallM(call) => env.0.visit_Multi_CallM(call~)
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Multi_VarargM(
  _env,
) {

}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Multi_CallM(
  env,
  call~,
) {
  env.0.visit_Call(call)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Call(
  env,
  call,
) {
  match call {
    NormalC(target, args, multi) =>
      env.0.visit_Call_NormalC(target~, args~, multi~)
    MethodC(target, method_name, args, multi) =>
      env.0.visit_Call_MethodC(target~, method_name~, args~, multi~)
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Call_NormalC(
  env,
  target~,
  args~,
  multi~,
) {
  env.0.visit_Expr(target)
  for arg in args {
    env.0.visit_Expr(arg)
  }
  match multi {
    Some(multi) => env.0.visit_Multi(multi)
    None => ()
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Call_MethodC(
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
    Some(multi) => env.0.visit_Multi(multi)
    None => ()
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Expr(
  env,
  expr,
) {
  match expr {
    ConstE(constant) => env.0.visit_Expr_ConstE(constant~)
    VarE(value) => env.0.visit_Expr_VarE(value~)
    CellE(cell) => env.0.visit_Expr_CellE(cell~)
    NumericForCheckE(ctrl, limit, step) =>
      env.0.visit_Expr_NumericForCheckE(ctrl~, limit~, step~)
    IndexE(table, index) => env.0.visit_Expr_IndexE(table~, index~)
    TableE(init) => env.0.visit_Expr_TableE(init~)
    UnaryE(op, expr) => env.0.visit_Expr_UnaryE(op~, expr~)
    BinaryE(op, lhs, rhs) => env.0.visit_Expr_BinaryE(op~, lhs~, rhs~)
    AndE(lhs, rhs) => env.0.visit_Expr_AndE(lhs~, rhs~)
    OrE(lhs, rhs) => env.0.visit_Expr_OrE(lhs~, rhs~)
    CallE(call) => env.0.visit_Expr_CallE(call~)
    ClosureE(func, captures) => env.0.visit_Expr_ClosureE(func~, captures~)
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Expr_ConstE(
  _env,
  constant~,
) {
  ignore(constant)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Expr_VarE(
  env,
  value~,
) {
  env.0.visit_Var(value)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Expr_CellE(
  env,
  cell~,
) {
  env.0.visit_Cell(cell)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Expr_NumericForCheckE(
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
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Expr_IndexE(
  env,
  table~,
  index~,
) {
  env.0.visit_Expr(table)
  env.0.visit_Expr(index)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Expr_TableE(
  env,
  init~,
) {
  env.0.visit_TableInit(init)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Expr_UnaryE(
  env,
  op~,
  expr~,
) {
  ignore(op)
  env.0.visit_Expr(expr)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Expr_BinaryE(
  env,
  op~,
  lhs~,
  rhs~,
) {
  ignore(op)
  env.0.visit_Expr(lhs)
  env.0.visit_Expr(rhs)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Expr_AndE(
  env,
  lhs~,
  rhs~,
) {
  env.0.visit_Expr(lhs)
  env.0.visit_Expr(rhs)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Expr_OrE(
  env,
  lhs~,
  rhs~,
) {
  env.0.visit_Expr(lhs)
  env.0.visit_Expr(rhs)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Expr_CallE(
  env,
  call~,
) {
  env.0.visit_Call(call)
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Expr_ClosureE(
  env,
  func~,
  captures~,
) {
  ignore(func)
  for value in captures {
    env.0.visit_Var(value)
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_TableInit(
  env,
  init,
) {
  match init {
    EmptyTI => env.0.visit_TableInit_EmptyTI()
    ArrayTI(values, multi) => env.0.visit_TableInit_ArrayTI(values~, multi~)
    TableTI(fields) => env.0.visit_TableInit_TableTI(fields~)
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_TableInit_EmptyTI(
  _env,
) {

}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_TableInit_ArrayTI(
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
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_TableInit_TableTI(
  env,
  fields~,
) {
  for field in fields {
    let (key, value) = field
    env.0.visit_Expr(key)
    env.0.visit_Expr(value)
  }
}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Var(
  _env,
  _value,
) {

}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Cell(
  _env,
  _cell,
) {

}

///|
pub impl[T : IterVisitor] IterVisitor for IterVisitorBase[T] with fn visit_Label(
  _env,
  _label,
) {

}
