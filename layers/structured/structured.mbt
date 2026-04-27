///|
/// Structured control-flow IR.
///
/// This IR still preserves explicit join points through `Blocks` regions and
/// `Target`s, but structured constructs such as `If` and `Loop` are made
/// explicit so later passes can progressively eliminate CFG-shaped artifacts.
pub(all) enum Region {
  /// A straight-line sequence followed by the next region.
  Linear(Array[Stmt], Region)
  /// Function return.
  Return(Array[Expr], Multi?)
  /// Conditional branch without a shared continuation in the current region.
  Branch(Expr, Region, Region)
  /// Structured conditional with an explicit post-dominator continuation.
  If(Expr, Region, Region?, (Label, Region))
  /// Structured loop.
  ///
  /// `header` names the loop header and carries the loop parameters.
  /// `init_args` are the values supplied on first entry.
  /// `body` is the loop body.
  /// `exit_region` is the continuation taken when the loop exits.
  Loop(Label, Array[Expr], LoopShape, Region, (Label, Region)?)
  /// Unified jump within structured regions.
  ///
  /// This covers plain block-to-block jumps as well as structured transfers
  /// such as leaving an `If`, continuing a `Loop`, or exiting a `Loop`.
  /// The meaning is determined by `target.label` relative to the surrounding
  /// structured region that interprets the jump.
  Goto(Target)
} derive(Debug)

///|
pub(all) enum LoopShape {
  UnknownLS
  /// Numeric-for protocol over one loop-control parameter.
  NumericForLS(Var, Expr, Expr, Expr)
  /// Generic-for protocol. The expressions and optional multi value are the
  /// Lua `in` expression list: `exprs..., multi?`.
  GenericForLS(Array[Var], Array[Expr], Multi?)
} derive(Debug)

///|
pub(all) struct Func {
  index : Int
  /// Function parameters are kept at the function boundary instead of being
  /// modeled as entry block parameters.
  params : Array[Var]
  /// Cells allocated by this function for locals that must live in shared
  /// mutable storage.
  cells : Array[Cell]
  vararg : Bool
  body : Region
} derive(Debug)

///|
pub(all) struct Program {
  _id_gen : IdGen
  funcs : Array[Func]
  main : FuncId
} derive(Debug)
