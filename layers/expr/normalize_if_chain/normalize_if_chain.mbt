///|
fn invert_binary_op(op : @ssa.BinaryOp) -> @ssa.BinaryOp? {
  match op {
    Eq => Some(Neq)
    Neq => Some(Eq)
    Lt => Some(Geq)
    Gt => Some(Leq)
    Leq => Some(Gt)
    Geq => Some(Lt)
    _ => None
  }
}

///|
fn flip_binary_op(op : @ssa.BinaryOp) -> @ssa.BinaryOp? {
  match op {
    Eq => Some(Eq)
    Neq => Some(Neq)
    Lt => Some(Gt)
    Gt => Some(Lt)
    Leq => Some(Geq)
    Geq => Some(Leq)
    _ => None
  }
}

///|
fn should_flip_binary_operands(lhs : @expr.Expr, rhs : @expr.Expr) -> Bool {
  match (lhs, rhs) {
    (ConstE(_), ConstE(_)) => false
    (ConstE(_), _) => true
    _ => false
  }
}

///|
fn normalize_binary_cond(
  op : @ssa.BinaryOp,
  lhs : @expr.Expr,
  rhs : @expr.Expr,
) -> @expr.Expr {
  if should_flip_binary_operands(lhs, rhs) {
    match flip_binary_op(op) {
      Some(op) => return @expr.BinaryE(op, rhs, lhs)
      None => ()
    }
  }
  @expr.BinaryE(op, lhs, rhs)
}

///|
fn binary_cond_op_cost(op : @ssa.BinaryOp) -> Int {
  match op {
    Neq => 1
    _ => 0
  }
}

///|
fn cond_cost(cond : @expr.Expr) -> Int {
  match cond {
    UnaryE(Not, inner) => 4 + cond_cost(inner)
    BinaryE(op, lhs, rhs) => {
      let mut cost = cond_cost(lhs) + cond_cost(rhs) + binary_cond_op_cost(op)
      if should_flip_binary_operands(lhs, rhs) && flip_binary_op(op) is Some(_) {
        cost = cost + 2
      }
      cost
    }
    AndE(lhs, rhs) | OrE(lhs, rhs) => 1 + cond_cost(lhs) + cond_cost(rhs)
    _ => 0
  }
}

///|
fn choose_lower_cost_cond(lhs : @expr.Expr, rhs : @expr.Expr) -> @expr.Expr {
  if cond_cost(rhs) <= cond_cost(lhs) {
    rhs
  } else {
    lhs
  }
}

///|
fn normalize_cond(cond : @expr.Expr) -> @expr.Expr {
  match cond {
    UnaryE(Not, inner) => invert_cond(inner)
    BinaryE(op, lhs, rhs) =>
      normalize_binary_cond(op, normalize_cond(lhs), normalize_cond(rhs))
    AndE(lhs, rhs) => @expr.AndE(normalize_cond(lhs), normalize_cond(rhs))
    OrE(lhs, rhs) => @expr.OrE(normalize_cond(lhs), normalize_cond(rhs))
    _ => cond
  }
}

///|
fn invert_cond(cond : @expr.Expr) -> @expr.Expr {
  match cond {
    UnaryE(Not, inner) => normalize_cond(inner)
    BinaryE(op, lhs, rhs) =>
      match invert_binary_op(op) {
        Some(op) =>
          normalize_binary_cond(op, normalize_cond(lhs), normalize_cond(rhs))
        None => @expr.UnaryE(Not, normalize_cond(cond))
      }
    AndE(lhs, rhs) =>
      choose_lower_cost_cond(
        @expr.UnaryE(Not, @expr.AndE(normalize_cond(lhs), normalize_cond(rhs))),
        @expr.OrE(invert_cond(lhs), invert_cond(rhs)),
      )
    OrE(lhs, rhs) =>
      choose_lower_cost_cond(
        @expr.UnaryE(Not, @expr.OrE(normalize_cond(lhs), normalize_cond(rhs))),
        @expr.AndE(invert_cond(lhs), invert_cond(rhs)),
      )
    _ => @expr.UnaryE(Not, normalize_cond(cond))
  }
}

///|
fn normalize_multi(multi : @expr.Multi) -> @expr.Multi {
  match multi {
    VarargM => @expr.VarargM
    CallM(call) => @expr.CallM(normalize_call(call))
  }
}

///|
fn normalize_call(call : @expr.Call) -> @expr.Call {
  match call {
    NormalC(callee, args, multi) =>
      @expr.NormalC(
        normalize_expr(callee),
        args.map(fn(arg) { normalize_expr(arg) }),
        multi.map(fn(next) { normalize_multi(next) }),
      )
    MethodC(target, method_name, args, multi) =>
      @expr.MethodC(
        normalize_expr(target),
        method_name,
        args.map(fn(arg) { normalize_expr(arg) }),
        multi.map(fn(next) { normalize_multi(next) }),
      )
  }
}

///|
fn normalize_table_init(init : @expr.TableInit) -> @expr.TableInit {
  match init {
    EmptyTI => @expr.EmptyTI
    ArrayTI(items, multi) =>
      @expr.ArrayTI(
        items.map(fn(item) { normalize_expr(item) }),
        multi.map(fn(next) { normalize_multi(next) }),
      )
    TableTI(fields) =>
      @expr.TableTI(
        fields.map(fn(field) {
          let (key, value) = field
          (normalize_expr(key), normalize_expr(value))
        }),
      )
  }
}

///|
fn normalize_expr(expr : @expr.Expr) -> @expr.Expr {
  match expr {
    ConstE(_) | VarE(_) | CellE(_) => expr
    NumericForCheckE(ctrl, limit, step) =>
      @expr.NumericForCheckE(
        normalize_expr(ctrl),
        normalize_expr(limit),
        normalize_expr(step),
      )
    IndexE(target, key) =>
      @expr.IndexE(normalize_expr(target), normalize_expr(key))
    TableE(init) => @expr.TableE(normalize_table_init(init))
    UnaryE(op, inner) => @expr.UnaryE(op, normalize_expr(inner))
    BinaryE(op, lhs, rhs) =>
      @expr.BinaryE(op, normalize_expr(lhs), normalize_expr(rhs))
    AndE(lhs, rhs) => @expr.AndE(normalize_expr(lhs), normalize_expr(rhs))
    OrE(lhs, rhs) => @expr.OrE(normalize_expr(lhs), normalize_expr(rhs))
    CallE(call) => @expr.CallE(normalize_call(call))
    ClosureE(func) =>
      @expr.ClosureE({ ..func, body: normalize_block(func.body), })
  }
}

///|
fn append_branches(
  out : Array[(@expr.Expr, @expr.Block)],
  source : Array[(@expr.Expr, @expr.Block)],
) -> Unit {
  for branch in source {
    out.push(branch)
  }
}

///|
fn normalize_branches(
  branches : Array[(@expr.Expr, @expr.Block)],
) -> Array[(@expr.Expr, @expr.Block)] {
  branches.map(fn(branch) {
    let (cond, body) = branch
    (normalize_cond(cond), normalize_block(body))
  })
}

///|
fn push_terminal_branch(
  branches : Array[(@expr.Expr, @expr.Block)],
  cond : @expr.Expr,
  then_body : @expr.Block,
  else_body : @expr.Block,
) -> @expr.Block? {
  let cond = normalize_cond(cond)
  let inverted = invert_cond(cond)
  if cond_cost(inverted) <= cond_cost(cond) {
    branches.push((inverted, normalize_block(else_body)))
    Some(normalize_block(then_body))
  } else {
    branches.push((cond, normalize_block(then_body)))
    Some(normalize_block(else_body))
  }
}

///|
fn flatten_inverted_nested_if(
  cond : @expr.Expr,
  then_body : @expr.Block,
  else_body : @expr.Block,
) -> (Array[(@expr.Expr, @expr.Block)], @expr.Block?)? {
  let cond = normalize_cond(cond)
  let inverted = invert_cond(cond)
  guard cond_cost(inverted) <= cond_cost(cond) else { return None }
  match then_body {
    [@expr.IfS(inner_branches, Some(inner_else))] => {
      let branches : Array[(@expr.Expr, @expr.Block)] = [
        (inverted, normalize_block(else_body)),
      ]
      match inner_branches {
        [(inner_cond, inner_then)] =>
          match flatten_inverted_nested_if(inner_cond, inner_then, inner_else) {
            Some((more_branches, tail)) => {
              append_branches(branches, more_branches)
              Some((branches, tail))
            }
            None => {
              let tail = push_terminal_branch(
                branches, inner_cond, inner_then, inner_else,
              )
              Some((branches, tail))
            }
          }
        _ => {
          append_branches(branches, normalize_branches(inner_branches))
          Some((branches, Some(normalize_block(inner_else))))
        }
      }
    }
    [@expr.IfS(inner_branches, None)] => {
      let branches : Array[(@expr.Expr, @expr.Block)] = [
        (inverted, normalize_block(else_body)),
      ]
      append_branches(branches, normalize_branches(inner_branches))
      Some((branches, None))
    }
    _ => None
  }
}

///|
fn normalize_if_stmt(
  branches : Array[(@expr.Expr, @expr.Block)],
  else_body : @expr.Block?,
) -> @expr.Stmt {
  match (branches, else_body) {
    ([(cond, then_body)], Some(else_body)) =>
      match flatten_inverted_nested_if(cond, then_body, else_body) {
        Some((branches, else_body)) => @expr.IfS(branches, else_body)
        None =>
          @expr.IfS(
            [(normalize_cond(cond), normalize_block(then_body))],
            Some(normalize_block(else_body)),
          )
      }
    _ =>
      @expr.IfS(
        normalize_branches(branches),
        else_body.map(fn(body) { normalize_block(body) }),
      )
  }
}

///|
fn normalize_stmt(stmt : @expr.Stmt) -> @expr.Stmt {
  match stmt {
    DoS(body) => @expr.DoS(normalize_block(body))
    IfS(branches, else_body) => normalize_if_stmt(branches, else_body)
    WhileS(cond, body) =>
      @expr.WhileS(normalize_expr(cond), normalize_block(body))
    NumericForS(value, start, stop, step, body) =>
      @expr.NumericForS(
        value,
        normalize_expr(start),
        normalize_expr(stop),
        step.map(fn(value) { normalize_expr(value) }),
        normalize_block(body),
      )
    GenericForS(values, iterators, multi, body) =>
      @expr.GenericForS(
        values,
        iterators.map(fn(iter) { normalize_expr(iter) }),
        multi.map(fn(next) { normalize_multi(next) }),
        normalize_block(body),
      )
    BindS(value, expr) => @expr.BindS(value, normalize_expr(expr))
    BindMultiS(values, multi) =>
      @expr.BindMultiS(values, normalize_multi(multi))
    SetIndexS(target, key, value) =>
      @expr.SetIndexS(
        normalize_expr(target),
        normalize_expr(key),
        normalize_expr(value),
      )
    SetListS(target, index, values, multi) =>
      @expr.SetListS(
        normalize_expr(target),
        normalize_expr(index),
        values.map(fn(value) { normalize_expr(value) }),
        multi.map(fn(next) { normalize_multi(next) }),
      )
    LocalS(cells, values) =>
      @expr.LocalS(cells, values.map(fn(value) { normalize_expr(value) }))
    ParallelAssignS(cells, values) =>
      @expr.ParallelAssignS(
        cells,
        values.map(fn(value) { normalize_expr(value) }),
      )
    ReturnS(values, multi) =>
      @expr.ReturnS(
        values.map(fn(value) { normalize_expr(value) }),
        multi.map(fn(next) { normalize_multi(next) }),
      )
    BreakS => @expr.BreakS
  }
}

///|
fn normalize_block(body : @expr.Block) -> @expr.Block {
  let out : @expr.Block = []
  for stmt in body {
    out.push(normalize_stmt(stmt))
  }
  out
}

///|
pub fn normalize_if_chain(program : @expr.Program) -> @expr.Program {
  normalize_block(program)
}
