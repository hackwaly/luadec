///|
priv struct UseCounter {
  uses : Map[@ssa.Var, Int]
}

///|
impl @expr.IterVisitor for UseCounter with visit_Expr_VarE(self, value~) {
  self.uses[value] = self.uses.get(value).unwrap_or(0) + 1
}

///|
fn count_uses(body : Block) -> Map[@ssa.Var, Int] {
  let uses : Map[@ssa.Var, Int] = {}
  let counter : UseCounter = { uses, }
  counter.visit_Block(body)
  uses
}

///|
fn is_var_expr(expr : Expr, value : @ssa.Var) -> Bool {
  match expr {
    VarE(other) => other == value
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
      stmt => {
        out.push(stmt)
        i = i + 1
      }
    }
  }
  (out, changed[0])
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
