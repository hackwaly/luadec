///|
pub(open) trait MapVisitor {
  base(Self) -> MapVisitorBase[Self] = _
  visit_Program(Self, Program) -> Program = _
  visit_Func(Self, Func) -> Func = _
  visit_Block(Self, Block) -> Block = _
  visit_Stmt(Self, Stmt) -> Stmt = _
  visit_Stmt_BindS(Self, value~ : Var, expr~ : Expr) -> Stmt = _
  visit_Stmt_StoreCellS(Self, cell~ : Cell, expr~ : Expr) -> Stmt = _
  visit_Stmt_SetIndexS(Self, table~ : Expr, index~ : Expr, value~ : Expr) -> Stmt = _
  visit_Stmt_BindMultiS(Self, values~ : Array[Var], multi~ : Multi) -> Stmt = _
  visit_Stmt_SetListS(
    Self,
    table~ : Expr,
    index~ : Expr,
    values~ : Array[Expr],
    multi~ : Multi?,
  ) -> Stmt = _
  visit_Term(Self, Term) -> Term = _
  visit_Term_JumpT(Self, target~ : Target) -> Term = _
  visit_Term_CondT(Self, cond~ : Expr, then_~ : Target, else_~ : Target) -> Term = _
  visit_Term_ReturnT(Self, values~ : Array[Expr], multi~ : Multi?) -> Term = _
  visit_Target(Self, Target) -> Target = _
  visit_Multi(Self, Multi) -> Multi = _
  visit_Multi_VarargM(Self) -> Multi = _
  visit_Multi_CallM(Self, call~ : Call) -> Multi = _
  visit_Call(Self, Call) -> Call = _
  visit_Call_NormalC(Self, target~ : Expr, args~ : Array[Expr], multi~ : Multi?) -> Call = _
  visit_Call_MethodC(
    Self,
    target~ : Expr,
    method_name~ : String,
    args~ : Array[Expr],
    multi~ : Multi?,
  ) -> Call = _
  visit_Expr(Self, Expr) -> Expr = _
  visit_Expr_ConstE(Self, constant~ : Constant) -> Expr = _
  visit_Expr_VarE(Self, value~ : Var) -> Expr = _
  visit_Expr_CellE(Self, cell~ : Cell) -> Expr = _
  visit_Expr_NumericForCheckE(Self, ctrl~ : Expr, limit~ : Expr, step~ : Expr) -> Expr = _
  visit_Expr_IndexE(Self, table~ : Expr, index~ : Expr) -> Expr = _
  visit_Expr_TableE(Self, init~ : TableInit) -> Expr = _
  visit_Expr_UnaryE(Self, op~ : UnaryOp, expr~ : Expr) -> Expr = _
  visit_Expr_BinaryE(Self, op~ : BinaryOp, lhs~ : Expr, rhs~ : Expr) -> Expr = _
  visit_Expr_AndE(Self, lhs~ : Expr, rhs~ : Expr) -> Expr = _
  visit_Expr_OrE(Self, lhs~ : Expr, rhs~ : Expr) -> Expr = _
  visit_Expr_CallE(Self, call~ : Call) -> Expr = _
  visit_Expr_ClosureE(Self, func~ : FuncId, captures~ : Array[Var]) -> Expr = _
  visit_TableInit(Self, TableInit) -> TableInit = _
  visit_TableInit_EmptyTI(Self) -> TableInit = _
  visit_TableInit_ArrayTI(Self, values~ : Array[Expr], multi~ : Multi?) -> TableInit = _
  visit_TableInit_TableTI(Self, fields~ : Array[(Expr, Expr)]) -> TableInit = _
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
impl MapVisitor with visit_Block(env, block) {
  MapVisitorBase::visit_Block(env, block)
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
impl MapVisitor with visit_Stmt_StoreCellS(env, cell~, expr~) {
  MapVisitorBase::visit_Stmt_StoreCellS(env, cell~, expr~)
}

///|
impl MapVisitor with visit_Stmt_SetIndexS(env, table~, index~, value~) {
  MapVisitorBase::visit_Stmt_SetIndexS(env, table~, index~, value~)
}

///|
impl MapVisitor with visit_Stmt_BindMultiS(env, values~, multi~) {
  MapVisitorBase::visit_Stmt_BindMultiS(env, values~, multi~)
}

///|
impl MapVisitor with visit_Stmt_SetListS(env, table~, index~, values~, multi~) {
  MapVisitorBase::visit_Stmt_SetListS(env, table~, index~, values~, multi~)
}

///|
impl MapVisitor with visit_Term(env, term) {
  MapVisitorBase::visit_Term(env, term)
}

///|
impl MapVisitor with visit_Term_JumpT(env, target~) {
  MapVisitorBase::visit_Term_JumpT(env, target~)
}

///|
impl MapVisitor with visit_Term_CondT(env, cond~, then_~, else_~) {
  MapVisitorBase::visit_Term_CondT(env, cond~, then_~, else_~)
}

///|
impl MapVisitor with visit_Term_ReturnT(env, values~, multi~) {
  MapVisitorBase::visit_Term_ReturnT(env, values~, multi~)
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
impl MapVisitor with visit_Call_NormalC(env, target~, args~, multi~) {
  MapVisitorBase::visit_Call_NormalC(env, target~, args~, multi~)
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
impl MapVisitor with visit_Expr(env, expr) {
  MapVisitorBase::visit_Expr(env, expr)
}

///|
impl MapVisitor with visit_Expr_ConstE(env, constant~) {
  MapVisitorBase::visit_Expr_ConstE(env, constant~)
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
impl MapVisitor with visit_Expr_IndexE(env, table~, index~) {
  MapVisitorBase::visit_Expr_IndexE(env, table~, index~)
}

///|
impl MapVisitor with visit_Expr_TableE(env, init~) {
  MapVisitorBase::visit_Expr_TableE(env, init~)
}

///|
impl MapVisitor with visit_Expr_UnaryE(env, op~, expr~) {
  MapVisitorBase::visit_Expr_UnaryE(env, op~, expr~)
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
impl MapVisitor with visit_Expr_ClosureE(env, func~, captures~) {
  MapVisitorBase::visit_Expr_ClosureE(env, func~, captures~)
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
impl MapVisitor with visit_TableInit_ArrayTI(env, values~, multi~) {
  MapVisitorBase::visit_TableInit_ArrayTI(env, values~, multi~)
}

///|
impl MapVisitor with visit_TableInit_TableTI(env, fields~) {
  MapVisitorBase::visit_TableInit_TableTI(env, fields~)
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
  let mut blocks : SortedMap[Label, Block] = SortedMap::new()
  for label, block in func.blocks {
    blocks = blocks.add(env.0.visit_Label(label), env.0.visit_Block(block))
  }
  {
    index: func.index,
    params: func.params.map(fn(value) { env.0.visit_Var(value) }),
    capture_vars: func.capture_vars.map(fn(value) { env.0.visit_Var(value) }),
    capture_cells: func.capture_cells.map(fn(cell) { env.0.visit_Cell(cell) }),
    cells: func.cells.map(fn(cell) { env.0.visit_Cell(cell) }),
    vararg: func.vararg,
    blocks,
    entry: env.0.visit_Label(func.entry),
  }
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Block(
  env,
  block,
) {
  {
    stmts: block.stmts.map(fn(stmt) { env.0.visit_Stmt(stmt) }),
    term: env.0.visit_Term(block.term),
  }
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Stmt(
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
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Stmt_BindS(
  env,
  value~,
  expr~,
) {
  BindS(env.0.visit_Var(value), env.0.visit_Expr(expr))
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Stmt_StoreCellS(
  env,
  cell~,
  expr~,
) {
  StoreCellS(env.0.visit_Cell(cell), env.0.visit_Expr(expr))
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Stmt_SetIndexS(
  env,
  table~,
  index~,
  value~,
) {
  SetIndexS(
    env.0.visit_Expr(table),
    env.0.visit_Expr(index),
    env.0.visit_Expr(value),
  )
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
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Stmt_SetListS(
  env,
  table~,
  index~,
  values~,
  multi~,
) {
  SetListS(
    env.0.visit_Expr(table),
    env.0.visit_Expr(index),
    values.map(fn(value) { env.0.visit_Expr(value) }),
    multi.map(fn(multi) { env.0.visit_Multi(multi) }),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Term(
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
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Term_JumpT(
  env,
  target~,
) {
  JumpT(env.0.visit_Target(target))
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Term_CondT(
  env,
  cond~,
  then_~,
  else_~,
) {
  CondT(
    env.0.visit_Expr(cond),
    env.0.visit_Target(then_),
    env.0.visit_Target(else_),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Term_ReturnT(
  env,
  values~,
  multi~,
) {
  ReturnT(
    values.map(fn(value) { env.0.visit_Expr(value) }),
    multi.map(fn(multi) { env.0.visit_Multi(multi) }),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Target(
  env,
  target,
) {
  let Target(label, args) = target
  Target(env.0.visit_Label(label), args.map(fn(arg) { env.0.visit_Expr(arg) }))
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
    NormalC(target, args, multi) =>
      env.0.visit_Call_NormalC(target~, args~, multi~)
    MethodC(target, method_name, args, multi) =>
      env.0.visit_Call_MethodC(target~, method_name~, args~, multi~)
  }
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Call_NormalC(
  env,
  target~,
  args~,
  multi~,
) {
  NormalC(
    env.0.visit_Expr(target),
    args.map(fn(arg) { env.0.visit_Expr(arg) }),
    multi.map(fn(multi) { env.0.visit_Multi(multi) }),
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
    multi.map(fn(multi) { env.0.visit_Multi(multi) }),
  )
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Expr(
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
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_Expr_ConstE(
  _env,
  constant~,
) {
  ConstE(constant)
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
  table~,
  index~,
) {
  IndexE(env.0.visit_Expr(table), env.0.visit_Expr(index))
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
  expr~,
) {
  UnaryE(op, env.0.visit_Expr(expr))
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
  captures~,
) {
  ClosureE(func, captures.map(fn(value) { env.0.visit_Var(value) }))
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_TableInit(
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
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_TableInit_EmptyTI(
  _env,
) {
  EmptyTI
}

///|
pub impl[T : MapVisitor] MapVisitor for MapVisitorBase[T] with visit_TableInit_ArrayTI(
  env,
  values~,
  multi~,
) {
  ArrayTI(
    values.map(fn(value) { env.0.visit_Expr(value) }),
    multi.map(fn(multi) { env.0.visit_Multi(multi) }),
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
