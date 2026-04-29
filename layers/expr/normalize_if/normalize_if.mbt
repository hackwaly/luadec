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
fn append_all(target : Array[@expr.Stmt], source : Array[@expr.Stmt]) -> Unit {
  for stmt in source {
    target.push(stmt)
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
      @expr.ClosureE({ ..func, body: normalize_block(func.body) })
  }
}

///|
fn is_direct_return(body : @expr.Block) -> Bool {
  match body {
    [@expr.ReturnS(_, _)] => true
    _ => false
  }
}

///|
fn stmt_is_abrupt_exit(stmt : @expr.Stmt) -> Bool {
  match stmt {
    ReturnS(_, _) | BreakS => true
    DoS(body)
    | WhileS(_, body)
    | NumericForS(_, _, _, _, body)
    | GenericForS(_, _, _, body)
    | ForEachS(_, _, _, body) => block_is_abrupt_exit(body)
    IfS(branches, else_body) => {
      for branch in branches {
        let (_, body) = branch
        if !block_is_abrupt_exit(body) {
          return false
        }
      }
      match else_body {
        Some(body) => block_is_abrupt_exit(body)
        None => false
      }
    }
    _ => false
  }
}

///|
fn block_is_abrupt_exit(body : @expr.Block) -> Bool {
  match body {
    [] => false
    _ => stmt_is_abrupt_exit(body[body.length() - 1])
  }
}

///|
priv struct CellUse {
  cell : @ssa.Cell
  found : Array[Bool]
}

///|
impl @expr.IterVisitor for CellUse with visit_Expr_CellE(self, cell~) {
  if cell == self.cell {
    self.found[0] = true
  }
}

///|
impl @expr.IterVisitor for CellUse with visit_Stmt_LocalS(self, cells~, values~) {
  ignore(cells)
  for value in values {
    self.visit_Expr(value)
  }
}

///|
impl @expr.IterVisitor for CellUse with visit_Stmt_ParallelAssignS(
  self,
  cells~,
  values~,
) {
  ignore(cells)
  for value in values {
    self.visit_Expr(value)
  }
}

///|
fn block_reads_cell(body : @expr.Block, cell : @ssa.Cell) -> Bool {
  let found = [false]
  let visitor : CellUse = { cell, found }
  visitor.visit_Block(body)
  found[0]
}

///|
fn direct_cell_assign(body : @expr.Block) -> (@ssa.Cell, @expr.Expr)? {
  match body {
    [@expr.ParallelAssignS([cell], [expr])] => Some((cell, expr))
    _ => None
  }
}

///|
fn same_expr(lhs : @expr.Expr, rhs : @expr.Expr) -> Bool {
  match (lhs, rhs) {
    (ConstE(lhs), ConstE(rhs)) => lhs == rhs
    (VarE(lhs), VarE(rhs)) => lhs == rhs
    (CellE(lhs), CellE(rhs)) => lhs == rhs
    _ => false
  }
}

///|
fn is_default_cell_assign(
  body : @expr.Block,
  cell : @ssa.Cell,
  expr : @expr.Expr,
) -> Bool {
  match direct_cell_assign(body) {
    Some((target, value)) => target == cell && same_expr(value, expr)
    None => false
  }
}

///|
fn rewrite_default_assign_guards(
  cell : @ssa.Cell,
  expr : @expr.Expr,
  body : @expr.Block,
) -> @expr.Block {
  let out : @expr.Block = []
  for stmt in body {
    match stmt {
      @expr.ParallelAssignS([target], [value]) =>
        if !(target == cell && same_expr(value, expr)) {
          out.push(stmt)
        }
      @expr.IfS([(cond, then_body)], Some(else_body)) =>
        if is_default_cell_assign(then_body, cell, expr) &&
          !else_body.is_empty() &&
          !block_is_abrupt_exit(else_body) &&
          !block_reads_cell(else_body, cell) {
          out.push(
            @expr.IfS(
              [
                (
                  invert_cond(cond),
                  rewrite_default_assign_guards(cell, expr, else_body),
                ),
              ],
              None,
            ),
          )
        } else if is_default_cell_assign(else_body, cell, expr) &&
          !then_body.is_empty() &&
          !block_is_abrupt_exit(then_body) &&
          !block_reads_cell(then_body, cell) {
          out.push(
            @expr.IfS(
              [(cond, rewrite_default_assign_guards(cell, expr, then_body))],
              None,
            ),
          )
        } else {
          out.push(stmt)
        }
      @expr.IfS([(cond, then_body)], None) =>
        out.push(
          @expr.IfS(
            [(cond, rewrite_default_assign_guards(cell, expr, then_body))],
            None,
          ),
        )
      _ => out.push(stmt)
    }
  }
  out
}

///|
fn lift_default_cell_assign(
  cond : @expr.Expr,
  then_body : @expr.Block,
  else_body : @expr.Block,
) -> Array[@expr.Stmt]? {
  match direct_cell_assign(then_body) {
    Some((cell, expr)) =>
      if !else_body.is_empty() &&
        !block_is_abrupt_exit(else_body) &&
        !block_reads_cell(else_body, cell) {
        Some([
          @expr.ParallelAssignS([cell], [expr]),
          @expr.IfS(
            [
              (
                invert_cond(cond),
                rewrite_default_assign_guards(cell, expr, else_body),
              ),
            ],
            None,
          ),
        ])
      } else {
        None
      }
    None =>
      match direct_cell_assign(else_body) {
        Some((cell, expr)) =>
          if !then_body.is_empty() &&
            !block_is_abrupt_exit(then_body) &&
            !block_reads_cell(then_body, cell) {
            Some([
              @expr.ParallelAssignS([cell], [expr]),
              @expr.IfS(
                [(cond, rewrite_default_assign_guards(cell, expr, then_body))],
                None,
              ),
            ])
          } else {
            None
          }
        None => None
      }
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
fn normalize_if_stmt(
  branches : Array[(@expr.Expr, @expr.Block)],
  else_body : @expr.Block?,
) -> Array[@expr.Stmt] {
  let branches = normalize_branches(branches)
  let else_body = else_body.map(fn(body) { normalize_block(body) })
  match (branches, else_body) {
    ([(cond, then_body)], Some(else_body)) =>
      match lift_default_cell_assign(cond, then_body, else_body) {
        Some(stmts) => stmts
        None => normalize_if_stmt_fallback(cond, then_body, else_body)
      }
    ([(cond, then_body), .. rest], _) if rest.length() > 0 &&
      block_is_abrupt_exit(then_body) => {
      let tail_else = match else_body {
        Some([]) => None
        other => other
      }
      let rest_branches : Array[(@expr.Expr, @expr.Block)] = []
      for branch in rest {
        rest_branches.push(branch)
      }
      let out : Array[@expr.Stmt] = [@expr.IfS([(cond, then_body)], None)]
      append_all(out, normalize_if_stmt(rest_branches, tail_else))
      out
    }
    _ =>
      [
        @expr.IfS(
          branches,
          match else_body {
            Some([]) => None
            other => other
          },
        ),
      ]
  }
}

///|
fn normalize_if_stmt_fallback(
  cond : @expr.Expr,
  then_body : @expr.Block,
  else_body : @expr.Block,
) -> Array[@expr.Stmt] {
  if then_body.is_empty() && !else_body.is_empty() {
    return [@expr.IfS([(invert_cond(cond), else_body)], None)]
  }
  if else_body.is_empty() {
    return [@expr.IfS([(cond, then_body)], None)]
  }
  if is_direct_return(then_body) && is_direct_return(else_body) {
    let inverted = invert_cond(cond)
    if cond_cost(inverted) < cond_cost(cond) {
      [@expr.IfS([(inverted, else_body)], None), ..then_body]
    } else {
      [@expr.IfS([(cond, then_body)], None), ..else_body]
    }
  } else if block_is_abrupt_exit(then_body) {
    [@expr.IfS([(cond, then_body)], None), ..else_body]
  } else if block_is_abrupt_exit(else_body) {
    [@expr.IfS([(invert_cond(cond), else_body)], None), ..then_body]
  } else {
    [@expr.IfS([(cond, then_body)], Some(else_body))]
  }
}

///|
fn normalize_stmt(stmt : @expr.Stmt) -> Array[@expr.Stmt] {
  match stmt {
    DoS(body) => [@expr.DoS(normalize_block(body))]
    IfS(branches, else_body) => normalize_if_stmt(branches, else_body)
    WhileS(cond, body) =>
      [@expr.WhileS(normalize_cond(cond), normalize_block(body))]
    NumericForS(value, start, stop, step, body) =>
      [
        @expr.NumericForS(
          value,
          normalize_expr(start),
          normalize_expr(stop),
          step.map(fn(value) { normalize_expr(value) }),
          normalize_block(body),
        ),
      ]
    GenericForS(values, iterators, multi, body) =>
      [
        @expr.GenericForS(
          values,
          iterators.map(fn(iter) { normalize_expr(iter) }),
          multi.map(fn(next) { normalize_multi(next) }),
          normalize_block(body),
        ),
      ]
    ForEachS(key, value, iter, body) =>
      [@expr.ForEachS(key, value, normalize_expr(iter), normalize_block(body))]
    BindS(value, expr) => [@expr.BindS(value, normalize_expr(expr))]
    BindMultiS(values, multi) =>
      [@expr.BindMultiS(values, normalize_multi(multi))]
    SetIndexS(target, key, value) =>
      [
        @expr.SetIndexS(
          normalize_expr(target),
          normalize_expr(key),
          normalize_expr(value),
        ),
      ]
    SetListS(target, index, values, multi) =>
      [
        @expr.SetListS(
          normalize_expr(target),
          normalize_expr(index),
          values.map(fn(value) { normalize_expr(value) }),
          multi.map(fn(next) { normalize_multi(next) }),
        ),
      ]
    LocalS(cells, values) =>
      [@expr.LocalS(cells, values.map(fn(value) { normalize_expr(value) }))]
    ParallelAssignS(cells, values) =>
      [
        @expr.ParallelAssignS(
          cells,
          values.map(fn(value) { normalize_expr(value) }),
        ),
      ]
    ReturnS(values, multi) =>
      [
        @expr.ReturnS(
          values.map(fn(value) { normalize_expr(value) }),
          multi.map(fn(next) { normalize_multi(next) }),
        ),
      ]
    BreakS => [@expr.BreakS]
  }
}

///|
fn fold_abrupt_continuation_guards(body : @expr.Block) -> @expr.Block {
  let out : @expr.Block = []
  let mut i = 0
  while i < body.length() {
    if i + 1 < body.length() {
      match (body[i], body[i + 1]) {
        (
          @expr.IfS([(cond, then_body)], None),
          @expr.ReturnS(_, _)
          | @expr.BreakS as cont,
        ) if block_is_abrupt_exit(then_body) &&
          cond_cost(invert_cond(cond)) <= cond_cost(cond) => {
          let inverted = invert_cond(cond)
          out.push(@expr.IfS([(inverted, [cont])], None))
          append_all(out, then_body)
          i = i + 2
          continue
        }
        _ => ()
      }
    }
    out.push(body[i])
    i = i + 1
  }
  out
}

///|
fn normalize_block(body : @expr.Block) -> @expr.Block {
  let normalized : @expr.Block = []
  for stmt in body {
    append_all(normalized, normalize_stmt(stmt))
  }
  fold_abrupt_continuation_guards(normalized)
}

///|
pub fn normalize_if(program : @expr.Program) -> @expr.Program {
  normalize_block(program)
}
