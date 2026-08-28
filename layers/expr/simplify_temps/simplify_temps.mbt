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
priv struct InlineSubst {
  subst : Map[@ssa.Var, Expr]
  deleted : Map[@ssa.Var, Bool]
  used_count : Map[@ssa.Var, Int]
}

///|
impl @expr.IterVisitor for UseCounter with fn visit_Expr_VarE(self, value~) {
  self.uses[value] = self.uses.get(value).unwrap_or(0) + 1
}

///|
impl @expr.IterVisitor for CellCounter with fn visit_Expr_CellE(self, cell~) {
  self.stats.reads[cell] = self.stats.reads.get(cell).unwrap_or(0) + 1
}

///|
impl @expr.IterVisitor for CellCounter with fn visit_Stmt_LocalS(
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
impl @expr.IterVisitor for CellCounter with fn visit_Stmt_ParallelAssignS(
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
impl @expr.MapVisitor for CellAlias with fn visit_Cell(self, cell) {
  if cell == self.from {
    self.to
  } else {
    cell
  }
}

///|
impl @expr.MapVisitor for InlineSubst with fn visit_Expr_VarE(self, value~) {
  match self.subst.get(value) {
    Some(expr) => {
      self.used_count[value] = self.used_count.get(value).unwrap_or(0) + 1
      if !can_inline_multiple_uses(expr) {
        self.deleted[value] = true
        self.subst.remove(value)
      }
      expr
    }
    None => @expr.VarE(value)
  }
}

///|
impl @expr.MapVisitor for InlineSubst with fn visit_Expr_ClosureE(self, func~) {
  ignore(self)
  @expr.ClosureE(func)
}

///|
fn count_uses(body : Block) -> Map[@ssa.Var, Int] {
  let uses : Map[@ssa.Var, Int] = Map([])
  let counter : UseCounter = { uses, }
  counter.visit_Block(body)
  uses
}

///|
fn count_cells(body : Block) -> CellStats {
  let stats : CellStats = { reads: {}, writes: {}, }
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
fn same_expr(lhs : Expr, rhs : Expr) -> Bool {
  match (lhs, rhs) {
    (ConstE(lhs), ConstE(rhs)) => lhs == rhs
    (VarE(lhs), VarE(rhs)) => lhs == rhs
    (CellE(lhs), CellE(rhs)) => lhs == rhs
    (IndexE(lhs_target, lhs_key), IndexE(rhs_target, rhs_key)) =>
      same_expr(lhs_target, rhs_target) && same_expr(lhs_key, rhs_key)
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
      | GenericForS(_, _, _, body) =>
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
  let aliaser : CellAlias = { from, to, }
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
fn can_defer_inline_expr(expr : Expr) -> Bool {
  match expr {
    ConstE(_) | VarE(_) | CellE(_) => true
    IndexE(target, key) =>
      can_defer_inline_expr(target) && can_defer_inline_expr(key)
    UnaryE(_, inner) => can_defer_inline_expr(inner)
    BinaryE(_, lhs, rhs) =>
      can_defer_inline_expr(lhs) && can_defer_inline_expr(rhs)
    AndE(lhs, rhs) | OrE(lhs, rhs) =>
      can_defer_inline_expr(lhs) && can_defer_inline_expr(rhs)
    _ => false
  }
}

///|
fn can_inline_multiple_uses(expr : Expr) -> Bool {
  match expr {
    ConstE(Nil) => true
    _ => false
  }
}

///|
fn expr_invalidated_by_set_index(
  expr : Expr,
  target : Expr,
  key : Expr,
) -> Bool {
  match expr {
    IndexE(expr_target, expr_key) =>
      (same_expr(expr_target, target) && same_expr(expr_key, key)) ||
      expr_invalidated_by_set_index(expr_target, target, key) ||
      expr_invalidated_by_set_index(expr_key, target, key)
    NumericForCheckE(ctrl, limit, step) =>
      expr_invalidated_by_set_index(ctrl, target, key) ||
      expr_invalidated_by_set_index(limit, target, key) ||
      expr_invalidated_by_set_index(step, target, key)
    TableE(init) =>
      match init {
        EmptyTI => false
        ArrayTI(items, multi) => {
          for item in items {
            if expr_invalidated_by_set_index(item, target, key) {
              return true
            }
          }
          multi_invalidated_by_set_index(multi, target, key)
        }
        TableTI(fields) => {
          for field in fields {
            let (field_key, field_value) = field
            if expr_invalidated_by_set_index(field_key, target, key) ||
              expr_invalidated_by_set_index(field_value, target, key) {
              return true
            }
          }
          false
        }
      }
    UnaryE(_, inner) => expr_invalidated_by_set_index(inner, target, key)
    BinaryE(_, lhs, rhs) | AndE(lhs, rhs) | OrE(lhs, rhs) =>
      expr_invalidated_by_set_index(lhs, target, key) ||
      expr_invalidated_by_set_index(rhs, target, key)
    CallE(call) => call_invalidated_by_set_index(call, target, key)
    ConstE(_) | VarE(_) | CellE(_) | ClosureE(_) => false
  }
}

///|
fn multi_invalidated_by_set_index(
  multi : @expr.Multi?,
  target : Expr,
  key : Expr,
) -> Bool {
  match multi {
    Some(CallM(call)) => call_invalidated_by_set_index(call, target, key)
    Some(VarargM) | None => false
  }
}

///|
fn call_invalidated_by_set_index(
  call : @expr.Call,
  target : Expr,
  key : Expr,
) -> Bool {
  match call {
    NormalC(callee, args, multi) => {
      if expr_invalidated_by_set_index(callee, target, key) {
        return true
      }
      for arg in args {
        if expr_invalidated_by_set_index(arg, target, key) {
          return true
        }
      }
      multi_invalidated_by_set_index(multi, target, key)
    }
    MethodC(receiver, _, args, multi) => {
      if expr_invalidated_by_set_index(receiver, target, key) {
        return true
      }
      for arg in args {
        if expr_invalidated_by_set_index(arg, target, key) {
          return true
        }
      }
      multi_invalidated_by_set_index(multi, target, key)
    }
  }
}

///|
fn rewrite_with_subst(
  subst : Map[@ssa.Var, Expr],
  deleted : Map[@ssa.Var, Bool],
  used_count : Map[@ssa.Var, Int],
  stmt : Stmt,
) -> Stmt {
  let inliner : InlineSubst = { subst, deleted, used_count, }
  inliner.visit_Stmt(stmt)
}

///|
fn inline_deferred_single_use_binds(
  body : Block,
  uses : Map[@ssa.Var, Int],
) -> (Block, Bool) {
  let subst : Map[@ssa.Var, Expr] = Map([])
  let deleted : Map[@ssa.Var, Bool] = Map([])
  let used_count : Map[@ssa.Var, Int] = Map([])
  let out : Block = []
  let changed = [false]
  for stmt in body {
    match stmt {
      SetIndexS(target, key, _) =>
        for var_name, expr in subst {
          if expr_invalidated_by_set_index(expr, target, key) {
            subst.remove(var_name)
          }
        }
      _ => ()
    }
    match stmt {
      BindS(value, expr) if (
          uses.get(value).unwrap_or(0) == 1 || can_inline_multiple_uses(expr)
        ) &&
        can_defer_inline_expr(expr) => {
        let stmt = rewrite_with_subst(
          subst,
          deleted,
          used_count,
          @expr.BindS(value, expr),
        )
        match stmt {
          BindS(_, expr) => subst[value] = expr
          _ => panic()
        }
        out.push(stmt)
      }
      _ => out.push(rewrite_with_subst(subst, deleted, used_count, stmt))
    }
  }
  let filtered : Block = []
  for stmt in out {
    match stmt {
      BindS(value, _) if deleted.get(value).unwrap_or(false) =>
        changed[0] = true
      BindS(value, _) if used_count.get(value).unwrap_or(0) ==
        uses.get(value).unwrap_or(0) &&
        subst.get(value) is Some(_) &&
        used_count.get(value).unwrap_or(0) > 0 => changed[0] = true
      _ => filtered.push(stmt)
    }
  }
  (filtered, changed[0])
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
fn cleanup_unused_nil_binds(
  body : Block,
  uses : Map[@ssa.Var, Int],
) -> (Block, Bool) {
  let out : Block = []
  let changed = [false]
  for stmt in body {
    match stmt {
      BindS(value, ConstE(Nil)) if uses.get(value).unwrap_or(0) == 0 =>
        changed[0] = true
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
  let (out, unused_nil_changed) = cleanup_unused_nil_binds(out, uses)
  let (out, deferred_changed) = inline_deferred_single_use_binds(out, uses)
  (out, changed[0] || locals_changed || unused_nil_changed || deferred_changed)
}

///|
priv struct Simplifier {
  _unit : Unit
}

///|
impl @expr.MapVisitor for Simplifier with fn visit_Block(self, body) {
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
  let simplifier : Simplifier = { _unit: (), }
  simplifier.visit_Program(program)
}

///|
extend UseCounter with @expr.IterVisitor::{visit_Block}

///|
extend CellCounter with @expr.IterVisitor::{visit_Expr, visit_Block}

///|
extend CellAlias with @expr.MapVisitor::{visit_Stmt}

///|
extend InlineSubst with @expr.MapVisitor::{visit_Stmt}

///|
extend Simplifier with @expr.MapVisitor::{visit_Stmt, visit_Program}
