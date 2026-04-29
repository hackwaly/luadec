///|
priv struct AnalyzeUseCountVisitor {
  use_count : Map[@ssa.Var, Int]
}

///|
impl @ssa.IterVisitor for AnalyzeUseCountVisitor with visit_Expr_VarE(
  self,
  value~,
) {
  self.use_count[value] = self.use_count.get(value).unwrap_or(0) + 1
}

///|
pub fn analyze_use_count(prog : @ssa.Program) -> Map[@ssa.Var, Int] {
  let visitor : AnalyzeUseCountVisitor = { use_count: {} }
  visitor.visit_Program(prog)
  visitor.use_count
}

///|
priv struct MethodLikeCollector {
  use_count : Map[@ssa.Var, Int]
  method_like : Map[@ssa.Var, (@ssa.Var, String)]
}

///|
priv struct MethodCallRewriter {
  method_like : Map[@ssa.Var, (@ssa.Var, String)]
  to_drop : Set[@ssa.Var]
}

///|
impl @ssa.IterVisitor for MethodLikeCollector with visit_Stmt_BindS(
  self,
  value~,
  expr~,
) {
  match expr {
    @ssa.IndexE(VarE(target), ConstE(AsciiString(id, is_valid_identifier=true))) =>
      if self.use_count.get(value).unwrap_or(0) == 1 {
        self.method_like[value] = (target, id)
      }
    _ => ()
  }
  self.visit_Expr(expr)
}

///|
impl @ssa.MapVisitor for MethodCallRewriter with visit_Call(self, call) {
  match call {
    @ssa.NormalC(
      VarE(method_candidate),
      [VarE(receiver_candidate), .. args],
      multi
    ) if self.method_like.get(method_candidate) is Some((receiver, method_name)) &&
      receiver_candidate == receiver => {
      self.method_like.remove(method_candidate)
      self.to_drop.add(method_candidate)
      self
      .base()
      .visit_Call(@ssa.MethodC(VarE(receiver), method_name, [..args], multi))
    }
    _ => self.base().visit_Call(call)
  }
}

///|
impl @ssa.MapVisitor for MethodCallRewriter with visit_Block(self, block) {
  let block = self.base().visit_Block(block)
  let block2 = {
    ..block,
    stmts: block.stmts.filter(fn(stmt) {
      !(stmt is @ssa.BindS(value, _) && self.to_drop.contains(value))
    }),
  }
  block2
}

///|
pub fn recover_method_call(program : @ssa.Program) -> @ssa.Program {
  let use_count = analyze_use_count(program)
  let collector = MethodLikeCollector::{ use_count, method_like: {} }
  collector.visit_Program(program)
  let rewriter = MethodCallRewriter::{
    method_like: collector.method_like,
    to_drop: Set::new(),
  }
  let program = rewriter.visit_Program(program)
  if rewriter.to_drop.is_empty() {
    program
  } else {
    let cleanup = MethodCallRewriter::{
      method_like: {},
      to_drop: rewriter.to_drop,
    }
    cleanup.visit_Program(program)
  }
}
