///|
priv struct UseCountVisitor {
  use_count : Map[@ssa.Var, Int]
}

///|
fn bump_use_count(use_count : Map[@ssa.Var, Int], value : @ssa.Var) -> Unit {
  use_count[value] = use_count.get(value).unwrap_or(0) + 1
}

///|
impl @ssa.IterVisitor for UseCountVisitor with fn visit_Expr_VarE(self, value~) {
  bump_use_count(self.use_count, value)
}

///|
impl @ssa.IterVisitor for UseCountVisitor with fn visit_Expr_ClosureE(
  self,
  func~,
  captures~,
) {
  ignore(func)
  for capture in captures {
    bump_use_count(self.use_count, capture)
  }
}

///|
pub fn analyze_use_count(func : @ssa.Func) -> Map[@ssa.Var, Int] {
  let visitor : UseCountVisitor = { use_count: {}, }
  visitor.visit_Func(func)
  visitor.use_count
}

///|
extend UseCountVisitor with @ssa.IterVisitor::{visit_Func}
