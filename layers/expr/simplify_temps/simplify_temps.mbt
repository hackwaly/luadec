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
priv struct CellAlias {
  from : @ssa.Cell
  to : @ssa.Cell
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
impl @expr.MapVisitor for CellAlias with visit_Cell(self, cell) {
  if cell == self.from {
    self.to
  } else {
    cell
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
fn writes_cell(stmt : Stmt, cell : @ssa.Cell) -> Bool {
  match stmt {
    ParallelAssignS(cells, _) => {
      for target in cells {
        if target == cell {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
fn block_writes_cell(body : Block, cell : @ssa.Cell) -> Bool {
  for stmt in body {
    match stmt {
      DoS(body)
      | WhileS(_, body)
      | NumericForS(_, _, _, _, body)
      | GenericForS(_, _, _, body)
      | ForEachS(_, _, _, body) =>
        if block_writes_cell(body, cell) {
          return true
        }
      IfS(branches, else_body) => {
        for branch in branches {
          let (_, body) = branch
          if block_writes_cell(body, cell) {
            return true
          }
        }
        match else_body {
          Some(body) => if block_writes_cell(body, cell) { return true }
          None => ()
        }
      }
      _ => if writes_cell(stmt, cell) { return true }
    }
  }
  false
}

///|
fn alias_loop_stmt(stmt : Stmt, from : @ssa.Cell, to : @ssa.Cell) -> Stmt {
  let aliaser : CellAlias = { from, to }
  aliaser.visit_Stmt(stmt)
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
fn try_alias_loop_accumulator(
  init : Stmt,
  loop_stmt : Stmt,
  final_assign : Stmt,
) -> Stmt? {
  match (init, final_assign) {
    (
      ParallelAssignS([tmp], [CellE(source)]),
      ParallelAssignS([target], [CellE(tmp2)]),
    ) =>
      if target == source &&
        tmp2 == tmp &&
        !block_writes_cell([loop_stmt], source) {
        Some(alias_loop_stmt(loop_stmt, tmp, source))
      } else {
        None
      }
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
    if i + 2 < body.length() {
      match try_alias_loop_accumulator(body[i], body[i + 1], body[i + 2]) {
        Some(stmt) => {
          out.push(stmt)
          changed[0] = true
          i = i + 3
          continue
        }
        None => ()
      }
    }
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
