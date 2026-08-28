///|
priv struct MentionVisitor {
  mentioned : Map[@ssa.Var, Bool]
}

///|
impl @ssa.IterVisitor for MentionVisitor with fn visit_Expr_VarE(self, value~) {
  self.mentioned[value] = true
}

///|
impl @ssa.IterVisitor for MentionVisitor with fn visit_Expr_ClosureE(
  self,
  func~,
  captures~,
) {
  ignore(func)
  for capture in captures {
    self.mentioned[capture] = true
  }
}

///|
pub fn mentioned_in_expr(expr : @ssa.Expr) -> Map[@ssa.Var, Bool] {
  let visitor : MentionVisitor = { mentioned: {}, }
  visitor.visit_Expr(expr)
  visitor.mentioned
}

///|
pub fn mentioned_in_target(target : @ssa.Target) -> Map[@ssa.Var, Bool] {
  let visitor : MentionVisitor = { mentioned: {}, }
  visitor.visit_Target(target)
  visitor.mentioned
}

///|
extend MentionVisitor with @ssa.IterVisitor::{visit_Expr, visit_Target}
