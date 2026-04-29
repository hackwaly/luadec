///|
priv struct UseCounter {
  uses : Map[@ssa.Var, Int]
}

///|
priv struct CellStats {
  reads : Map[@ssa.Cell, Int]
  writes : Map[@ssa.Cell, Int]
}

///|
priv struct CellCounter {
  stats : CellStats
}

///|
impl @expr.IterVisitor for UseCounter with visit_Expr_VarE(self, value~) {
  self.uses[value] = self.uses.get(value).unwrap_or(0) + 1
}

///|
impl @expr.IterVisitor for CellCounter with visit_Expr_CellE(self, cell~) {
  self.stats.reads[cell] = self.stats.reads.get(cell).unwrap_or(0) + 1
}

///|
impl @expr.IterVisitor for CellCounter with visit_Stmt_LocalS(
  self,
  cells~ : Array[@ssa.Cell],
  values~,
) {
  ignore(cells)
  for value in values {
    self.visit_Expr(value)
  }
}

///|
impl @expr.IterVisitor for CellCounter with visit_Stmt_ParallelAssignS(
  self,
  cells~,
  values~,
) {
  for cell in cells {
    self.stats.writes[cell] = self.stats.writes.get(cell).unwrap_or(0) + 1
  }
  for value in values {
    self.visit_Expr(value)
  }
}

///|
fn count_uses(body : Block) -> Map[@ssa.Var, Int] {
  let uses : Map[@ssa.Var, Int] = {}
  let counter : UseCounter = { uses, }
  counter.visit_Block(body)
  uses
}

///|
fn count_cells(body : Block) -> CellStats {
  let stats : CellStats = { reads: {}, writes: {} }
  let counter : CellCounter = { stats, }
  counter.visit_Block(body)
  stats
}

///|
fn is_var_expr(expr : Expr, value : @ssa.Var) -> Bool {
  match expr {
    VarE(other) => other == value
    _ => false
  }
}

///|
fn is_cell_expr(expr : Expr, cell : @ssa.Cell) -> Bool {
  match expr {
    CellE(other) => other == cell
    _ => false
  }
}

///|
fn can_inline_into_return(expr : Expr) -> Bool {
  match expr {
    CallE(_) => false
    _ => true
  }
}

///|
fn maybe_inline_cell_tmp(
  stmt : Stmt,
  tmp : @ssa.Cell,
  expr : Expr,
  stats : CellStats,
) -> Stmt? {
  guard stats.reads.get(tmp).unwrap_or(0) == 1 &&
    stats.writes.get(tmp).unwrap_or(0) == 1 else {
    return None
  }
  match stmt {
    ParallelAssignS([cell], [value]) if is_cell_expr(value, tmp) =>
      Some(@expr.ParallelAssignS([cell], [expr]))
    _ => None
  }
}

///|
fn cleanup_unused_empty_locals(body : Block) -> (Block, Bool) {
  let stats = count_cells(body)
  let out : Block = []
  let changed = [false]
  for stmt in body {
    match stmt {
      LocalS(cells, []) => {
        let kept : Array[@ssa.Cell] = []
        for cell in cells {
          if stats.reads.get(cell).unwrap_or(0) > 0 ||
            stats.writes.get(cell).unwrap_or(0) > 0 {
            kept.push(cell)
          }
        }
        if kept.length() == cells.length() {
          out.push(stmt)
        } else {
          changed[0] = true
          if !kept.is_empty() {
            out.push(@expr.LocalS(kept, []))
          }
        }
      }
      _ => out.push(stmt)
    }
  }
  (out, changed[0])
}

///|
fn maybe_inline_tmp(
  stmt : Stmt,
  tmp : @ssa.Var,
  expr : Expr,
  uses : Map[@ssa.Var, Int],
) -> Stmt? {
  guard uses.get(tmp).unwrap_or(0) == 1 else { return None }
  match stmt {
    ParallelAssignS([cell], [value]) if is_var_expr(value, tmp) =>
      Some(@expr.ParallelAssignS([cell], [expr]))
    BindS(target, value) if is_var_expr(value, tmp) =>
      Some(@expr.BindS(target, expr))
    ReturnS([value], None) if is_var_expr(value, tmp) &&
      can_inline_into_return(expr) => Some(@expr.ReturnS([expr], None))
    _ => None
  }
}

///|
fn simplify_block_once(body : Block) -> (Block, Bool) {
  let uses = count_uses(body)
  let cell_stats = count_cells(body)
  let out : Block = []
  let changed = [false]
  let mut i = 0
  while i < body.length() {
    match body[i] {
      BindS(tmp, expr) if i + 1 < body.length() => {
        let next = body[i + 1]
        match maybe_inline_tmp(next, tmp, expr, uses) {
          Some(stmt) => {
            out.push(stmt)
            changed[0] = true
            i = i + 2
          }
          None => {
            out.push(body[i])
            i = i + 1
          }
        }
      }
      ParallelAssignS([tmp], [expr]) if i + 1 < body.length() => {
        let next = body[i + 1]
        match maybe_inline_cell_tmp(next, tmp, expr, cell_stats) {
          Some(stmt) => {
            out.push(stmt)
            changed[0] = true
            i = i + 2
          }
          None => {
            out.push(body[i])
            i = i + 1
          }
        }
      }
      stmt => {
        out.push(stmt)
        i = i + 1
      }
    }
  }
  let (out, locals_changed) = cleanup_unused_empty_locals(out)
  (out, changed[0] || locals_changed)
}

///|
priv struct Simplifier {
  _unit : Unit
}

///|
impl @expr.MapVisitor for Simplifier with visit_Block(self, body) {
  let mut body = body.map(fn(stmt) { self.visit_Stmt(stmt) })
  while true {
    let (next, changed) = simplify_block_once(body)
    body = next
    if !changed {
      break
    }
  }
  body
}

///|
pub fn simplify_temps(program : Program) -> Program {
  let simplifier : Simplifier = { _unit: () }
  simplifier.visit_Program(program)
}
