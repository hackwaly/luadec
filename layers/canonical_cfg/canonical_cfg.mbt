///|
/// Canonical CFG is a normalized, non-SSA control-flow IR.
/// It removes bytecode-specific terminators and represents control flow with
/// generic branches only, while still keeping mutable local assignments.
pub(all) struct Local {
  func : FuncId
  index : Int
} derive(Eq, Compare, Hash)

///|
pub(all) enum Multi {
  VarargM
  CallM(Expr, Array[Expr], Multi?)
} derive(Debug)

///|
pub(all) enum Expr {
  ConstE(Constant)
  LocalE(Local)
  /// Numeric-for continuation test. It chooses ascending or descending
  /// comparison based on the runtime sign of `step`.
  NumericForCheckE(Expr, Expr, Expr)
  IndexE(Expr, Expr)
  NewTableE
  UnaryE(UnaryOp, Expr)
  BinaryE(BinaryOp, Expr, Expr)
  CallE(Expr, Array[Expr], Multi?)
  ClosureE(FuncId)
} derive(Debug)

///|
pub(all) struct Label {
  func : FuncId
  index : Int
} derive(Eq, Compare, Hash)

///|
pub(all) enum Stmt {
  AssignS(Local, Expr)
  SetIndexS(Expr, Expr, Expr)
  AssignMultiS(Array[Local], Multi)
  SetListS(Expr, Expr, Array[Expr], Multi?)
} derive(Debug)

///|
/// Canonical CFG keeps only pure control-flow terminators.
/// Any edge-local effects are made explicit with bridge blocks.
pub(all) enum Term {
  JumpT(Label)
  CondT(Expr, Label, Label)
  ReturnT(Array[Expr], Multi?)
} derive(Debug)

///|
pub(all) struct Block {
  stmts : Array[Stmt]
  term : Term
} derive(Debug)

///|
pub(all) struct Func {
  index : Int
  params : Array[Local]
  /// Upvalues still point to outer locals. This keeps closure boundaries
  /// explicit before any SSA/cell lowering happens.
  upvalues : Array[Local]
  vararg : Bool
  blocks : SortedMap[Label, Block]
  entry : Label
} derive(Debug)

///|
pub(all) struct Program {
  funcs : Array[Func]
  main : FuncId
} derive(Debug)

///|
pub fn Local::env() -> Local {
  { func: { index: -1 }, index: 0 }
}

///|
pub fn Local::is_env(self : Local) -> Bool {
  self.func.index == -1 && self.index == 0
}

///|
pub fn Label::new(func~ : FuncId, index~ : Int) -> Label {
  { func, index }
}

///|
pub impl Debug for Local with to_repr(self) {
  if self.is_env() {
    Repr::literal("_ENV")
  } else {
    Repr::literal("l\{self.index}f\{self.func.index}")
  }
}

///|
pub impl Debug for Label with to_repr(self) {
  Repr::literal("L\{self.index}f\{self.func.index}")
}
