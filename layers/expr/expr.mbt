///|
pub(all) struct Func {
  params : Array[Var]
  vararg : Bool
  body : Block
} derive(Debug)

///|
pub(all) struct Names {
  vars : Map[Var, String]
  cells : Map[Cell, String]
}

///|
pub(all) struct NamedProgram {
  program : Program
  names : Names
}

///|
pub type Block = Array[Stmt]

///|
pub(all) enum Multi {
  VarargM
  CallM(Call)
} derive(Debug)

///|
pub(all) enum Call {
  NormalC(Expr, Array[Expr], Multi?)
  MethodC(Expr, String, Array[Expr], Multi?)
} derive(Debug)

///|
pub(all) enum TableInit {
  EmptyTI
  ArrayTI(Array[Expr], Multi?)
  TableTI(Array[(Expr, Expr)])
} derive(Debug)

///|
pub(all) enum Expr {
  ConstE(Constant)
  VarE(Var)
  CellE(Cell)
  NumericForCheckE(Expr, Expr, Expr)
  IndexE(Expr, Expr)
  TableE(TableInit)
  UnaryE(UnaryOp, Expr)
  BinaryE(BinaryOp, Expr, Expr)
  AndE(Expr, Expr)
  OrE(Expr, Expr)
  CallE(Call)
  ClosureE(Func)
} derive(Debug)

///|
pub(all) enum Stmt {
  BindS(Var, Expr)
  BindMultiS(Array[Var], Multi)
  SetIndexS(Expr, Expr, Expr)
  SetListS(Expr, Expr, Array[Expr], Multi?)
  LocalS(Array[Cell], Array[Expr])
  ParallelAssignS(Array[Cell], Array[Expr])
  ReturnS(Array[Expr], Multi?)
  DoS(Block)
  IfS(Array[(Expr, Block)], Block?)
  WhileS(Expr, Block)
  NumericForS(Var, Expr, Expr, Expr?, Block)
  GenericForS(Array[Var], Array[Expr], Multi?, Block)
  ForEachS(Var, Var, Expr, Block)
  BreakS
} derive(Debug)

///|
pub type Program = Block
