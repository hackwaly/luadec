///|
priv struct CellRead {
  cell : @ssa.Cell
  found : Array[Bool]
}

///|
impl @expr.IterVisitor for CellRead with visit_Expr_CellE(self, cell~) {
  if cell == self.cell {
    self.found[0] = true
  }
}

///|
fn expr_reads_cell(expr : @expr.Expr, cell : @ssa.Cell) -> Bool {
  let found = [false]
  let visitor : CellRead = { cell, found }
  visitor.visit_Expr(expr)
  found[0]
}

///|
fn maybe_merge_local_assign(
  init : @expr.Stmt,
  assign : @expr.Stmt,
) -> @expr.Stmt? {
  match (init, assign) {
    (@expr.LocalS([cell], []), @expr.ParallelAssignS([target], [expr])) =>
      if target == cell && !expr_reads_cell(expr, cell) {
        Some(@expr.LocalS([cell], [expr]))
      } else {
        None
      }
    _ => None
  }
}

///|
fn merge_block(body : @expr.Block) -> @expr.Block {
  let out : @expr.Block = []
  let mut i = 0
  while i < body.length() {
    if i + 1 < body.length() {
      match maybe_merge_local_assign(body[i], body[i + 1]) {
        Some(stmt) => {
          out.push(stmt)
          i = i + 2
          continue
        }
        None => ()
      }
    }
    out.push(body[i])
    i = i + 1
  }
  out
}

///|
priv struct Merger {
  _unit : Unit
}

///|
impl @expr.MapVisitor for Merger with visit_Block(self, body) {
  merge_block(self.base().visit_Block(body))
}

///|
pub fn merge_local_assign(program : @expr.Program) -> @expr.Program {
  let merger : Merger = { _unit: () }
  merger.visit_Program(program)
}
