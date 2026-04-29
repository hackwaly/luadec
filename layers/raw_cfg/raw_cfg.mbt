///|
pub(all) struct Local {
  func : FuncId
  slot : Int
} derive(Eq, Compare, Hash)

///|
pub(all) enum Multi {
  VarargM
  CallM(Expr, Array[Expr], Multi?)
} derive(Debug)

///|
pub(all) enum UnaryOp {
  Neg
  BNot
  Not
  Len
} derive(Debug)

///|
pub(all) enum BinaryOp {
  Add
  Sub
  Mul
  Mod
  Pow
  Div
  IDiv
  BAnd
  BOr
  BXor
  Shl
  Shr
  Eq
  Lt
  Gt
  Neq
  Leq
  Geq
  Concat
} derive(Debug)

///|
pub(all) enum Expr {
  ConstE(Constant)
  LocalE(Local)
  IndexE(Expr, Expr)
  NewTableE
  UnaryE(UnaryOp, Expr)
  BinaryE(BinaryOp, Expr, Expr)
  CallE(Expr, Array[Expr], Multi?)
  ClosureE(FuncId)
} derive(Debug)

///|
pub(all) struct Label {
  pc : Int
} derive(Eq, Compare, Hash)

///|
pub(all) enum Stmt {
  SetS(Local, Expr)
  SetIndexS(Expr, Expr, Expr)
  SetMultiS(Array[Local], Multi)
  SetListS(Expr, Expr, Array[Expr], Multi?)
} derive(Debug)

///|
/// The terminator of a block.
pub(all) enum Term {
  JumpT(Label)
  CondT(Expr, Label, Label)
  CondSetT(Expr, Local, Expr, Label, Label)
  ForPrepT(Local, Expr, Label)
  ForLoopT(Local, Expr, Expr, Local, Label, Label)
  GenericForT(Expr, Expr, Local, Array[Local], Label, Label)
  ReturnT(Array[Expr], Multi?)
} derive(Debug)

///|
pub(all) struct Block {
  stmts : Array[Stmt]
  term : Term
} derive(Debug)

///|
#valtype
pub(all) struct FuncId {
  index : Int
} derive(Eq, Compare, Hash)

///|
pub(all) struct Func {
  index : Int
  params : Array[Local]
  upvalues : Array[Local]
  vararg : Bool
  blocks : Map[Label, Block]
  entry : Label
} derive(Debug)

///|
pub(all) struct Program {
  funcs : Array[Func]
  main : FuncId
} derive(Debug)

///|
pub fn Local::env() -> Local {
  { func: { index: 0 }, slot: -1 }
}

///|
pub fn Local::is_env(self : Local) -> Bool {
  self.slot == -1
}

///|
pub impl Debug for Local with to_repr(self) {
  if self.is_env() {
    Repr::literal("_ENV")
  } else {
    Repr::literal("r\{self.slot}f\{self.func.index}")
  }
}

///|
pub fn Label::Label(pc~ : Int) -> Label {
  { pc, }
}

///|
pub impl Debug for Label with to_repr(self) {
  Repr::literal("L\{self.pc}")
}

///|
pub impl Debug for FuncId with to_repr(self) {
  Repr::literal("f\{self.index}")
}
