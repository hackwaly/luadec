///|
fn drop_tail_return_in_func_body(body : @expr.Block) -> @expr.Block {
  let body = body.map(fn(stmt) { drop_tail_return_stmt(stmt) })
  if body.length() > 0 && body[body.length() - 1] is @expr.ReturnS([], None) {
    let out : @expr.Block = []
    for i in 0..<(body.length() - 1) {
      out.push(body[i])
    }
    out
  } else {
    body
  }
}

///|
fn drop_tail_return_block(body : @expr.Block) -> @expr.Block {
  body.map(fn(stmt) { drop_tail_return_stmt(stmt) })
}

///|
fn drop_tail_return_expr(expr : @expr.Expr) -> @expr.Expr {
  match expr {
    ConstE(_) | VarE(_) | CellE(_) => expr
    NumericForCheckE(ctrl, limit, step) =>
      @expr.NumericForCheckE(
        drop_tail_return_expr(ctrl),
        drop_tail_return_expr(limit),
        drop_tail_return_expr(step),
      )
    IndexE(target, key) =>
      @expr.IndexE(drop_tail_return_expr(target), drop_tail_return_expr(key))
    TableE(init) => @expr.TableE(drop_tail_return_table_init(init))
    UnaryE(op, inner) => @expr.UnaryE(op, drop_tail_return_expr(inner))
    BinaryE(op, lhs, rhs) =>
      @expr.BinaryE(op, drop_tail_return_expr(lhs), drop_tail_return_expr(rhs))
    AndE(lhs, rhs) =>
      @expr.AndE(drop_tail_return_expr(lhs), drop_tail_return_expr(rhs))
    OrE(lhs, rhs) =>
      @expr.OrE(drop_tail_return_expr(lhs), drop_tail_return_expr(rhs))
    CallE(call) => @expr.CallE(drop_tail_return_call(call))
    ClosureE(func) =>
      @expr.ClosureE({ ..func, body: drop_tail_return_in_func_body(func.body) })
  }
}

///|
fn drop_tail_return_table_init(init : @expr.TableInit) -> @expr.TableInit {
  match init {
    EmptyTI => @expr.EmptyTI
    ArrayTI(items, multi) =>
      @expr.ArrayTI(
        items.map(fn(item) { drop_tail_return_expr(item) }),
        multi.map(fn(next) { drop_tail_return_multi(next) }),
      )
    TableTI(fields) =>
      @expr.TableTI(
        fields.map(fn(field) {
          let (key, value) = field
          (drop_tail_return_expr(key), drop_tail_return_expr(value))
        }),
      )
  }
}

///|
fn drop_tail_return_multi(multi : @expr.Multi) -> @expr.Multi {
  match multi {
    VarargM => @expr.VarargM
    CallM(call) => @expr.CallM(drop_tail_return_call(call))
  }
}

///|
fn drop_tail_return_call(call : @expr.Call) -> @expr.Call {
  match call {
    NormalC(callee, args, multi) =>
      @expr.NormalC(
        drop_tail_return_expr(callee),
        args.map(fn(arg) { drop_tail_return_expr(arg) }),
        multi.map(fn(next) { drop_tail_return_multi(next) }),
      )
    MethodC(target, method_name, args, multi) =>
      @expr.MethodC(
        drop_tail_return_expr(target),
        method_name,
        args.map(fn(arg) { drop_tail_return_expr(arg) }),
        multi.map(fn(next) { drop_tail_return_multi(next) }),
      )
  }
}

///|
fn drop_tail_return_stmt(stmt : @expr.Stmt) -> @expr.Stmt {
  match stmt {
    BindS(value, expr) => @expr.BindS(value, drop_tail_return_expr(expr))
    BindMultiS(values, multi) =>
      @expr.BindMultiS(values, drop_tail_return_multi(multi))
    SetIndexS(target, key, value) =>
      @expr.SetIndexS(
        drop_tail_return_expr(target),
        drop_tail_return_expr(key),
        drop_tail_return_expr(value),
      )
    SetListS(target, index, values, multi) =>
      @expr.SetListS(
        drop_tail_return_expr(target),
        drop_tail_return_expr(index),
        values.map(fn(value) { drop_tail_return_expr(value) }),
        multi.map(fn(next) { drop_tail_return_multi(next) }),
      )
    LocalS(cells, values) =>
      @expr.LocalS(
        cells,
        values.map(fn(value) { drop_tail_return_expr(value) }),
      )
    ParallelAssignS(cells, values) =>
      @expr.ParallelAssignS(
        cells,
        values.map(fn(value) { drop_tail_return_expr(value) }),
      )
    ReturnS(values, multi) =>
      @expr.ReturnS(
        values.map(fn(value) { drop_tail_return_expr(value) }),
        multi.map(fn(next) { drop_tail_return_multi(next) }),
      )
    DoS(body) => @expr.DoS(drop_tail_return_block(body))
    IfS(branches, else_body) =>
      @expr.IfS(
        branches.map(fn(branch) {
          let (cond, body) = branch
          (drop_tail_return_expr(cond), drop_tail_return_block(body))
        }),
        else_body.map(fn(body) { drop_tail_return_block(body) }),
      )
    WhileS(cond, body) =>
      @expr.WhileS(drop_tail_return_expr(cond), drop_tail_return_block(body))
    NumericForS(value, start, stop, step, body) =>
      @expr.NumericForS(
        value,
        drop_tail_return_expr(start),
        drop_tail_return_expr(stop),
        step.map(fn(value) { drop_tail_return_expr(value) }),
        drop_tail_return_block(body),
      )
    GenericForS(values, iterators, multi, body) =>
      @expr.GenericForS(
        values,
        iterators.map(fn(iter) { drop_tail_return_expr(iter) }),
        multi.map(fn(next) { drop_tail_return_multi(next) }),
        drop_tail_return_block(body),
      )
    BreakS => @expr.BreakS
  }
}

///|
pub fn drop_tail_return(program : @expr.Program) -> @expr.Program {
  drop_tail_return_in_func_body(program)
}
