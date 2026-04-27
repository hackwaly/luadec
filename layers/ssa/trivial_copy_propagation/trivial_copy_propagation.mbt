///|
priv struct CopyCollector {
  copies : Map[@ssa.Var, @ssa.Var]
}

///|
impl @ssa.IterVisitor for CopyCollector with visit_Stmt_BindS(
  self,
  value~,
  expr~,
) {
  if expr is VarE(source) {
    let source = self.copies.get(source).unwrap_or(source)
    self.copies[value] = source
  }
}

///|
fn collect_copy_map(program : @ssa.Program) -> Map[@ssa.Var, @ssa.Var] {
  let collector : CopyCollector = { copies: {} }
  collector.visit_Program(program)
  collector.copies
}

///|
priv struct CopyRewriteVisitor {
  copies : Map[@ssa.Var, @ssa.Var]
}

///|
impl @ssa.MapVisitor for CopyRewriteVisitor with visit_Expr_VarE(self, value~) {
  match self.copies.get(value) {
    Some(source) => @ssa.VarE(source)
    None => self.base().visit_Expr_VarE(value~)
  }
}

///|
impl @ssa.MapVisitor for CopyRewriteVisitor with visit_Expr_ClosureE(
  self,
  func~,
  captures~,
) {
  @ssa.ClosureE(
    func,
    captures.map(capture => {
      match self.copies.get(capture) {
        Some(source) => source
        None => capture
      }
    }),
  )
}

///|
impl @ssa.MapVisitor for CopyRewriteVisitor with visit_Block(self, block) {
  let stmts = []
  for stmt in block.stmts {
    if !(stmt is BindS(_, VarE(_))) {
      stmts.push(self.visit_Stmt(stmt))
    }
  }
  let term = self.visit_Term(block.term)
  { stmts, term }
}

///|
pub fn trivial_copy_propagation(program : @ssa.Program) -> @ssa.Program {
  let copies = collect_copy_map(program)
  let visitor : CopyRewriteVisitor = { copies, }
  visitor.visit_Program(program)
}
