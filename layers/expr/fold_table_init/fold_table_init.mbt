///|
priv struct CellRead {
  cell : @ssa.Cell
  found : Array[Bool]
}

///|
priv struct VarRead {
  value : @ssa.Var
  found : Array[Bool]
}

///|
priv struct VarMention {
  value : @ssa.Var
  found : Array[Bool]
}

///|
priv enum TableTarget {
  CellT(@ssa.Cell)
  VarT(@ssa.Var)
}

///|
impl @expr.IterVisitor for CellRead with visit_Expr_CellE(self, cell~) {
  if cell == self.cell {
    self.found[0] = true
  }
}

///|
impl @expr.IterVisitor for VarRead with visit_Expr_VarE(self, value~) {
  if value == self.value {
    self.found[0] = true
  }
}

///|
impl @expr.IterVisitor for VarMention with visit_Expr_VarE(self, value~) {
  if value == self.value {
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
fn expr_reads_var(expr : @expr.Expr, value : @ssa.Var) -> Bool {
  let found = [false]
  let visitor : VarRead = { value, found }
  visitor.visit_Expr(expr)
  found[0]
}

///|
fn stmt_mentions_var(stmt : @expr.Stmt, value : @ssa.Var) -> Bool {
  let found = [false]
  let visitor : VarMention = { value, found }
  visitor.visit_Stmt(stmt)
  found[0]
}

///|
fn expr_reads_target(expr : @expr.Expr, target : TableTarget) -> Bool {
  match target {
    CellT(cell) => expr_reads_cell(expr, cell)
    VarT(value) => expr_reads_var(expr, value)
  }
}

///|
fn same_target(lhs : TableTarget, rhs : TableTarget) -> Bool {
  match (lhs, rhs) {
    (CellT(lhs), CellT(rhs)) => lhs == rhs
    (VarT(lhs), VarT(rhs)) => lhs == rhs
    _ => false
  }
}

///|
fn var_is_mentioned_after(
  body : @expr.Block,
  start : Int,
  value : @ssa.Var,
) -> Bool {
  for i in start..<body.length() {
    if stmt_mentions_var(body[i], value) {
      return true
    }
  }
  false
}

///|
fn is_empty_table_init(init : @expr.TableInit) -> Bool {
  match init {
    EmptyTI => true
    ArrayTI([], None) => true
    TableTI([]) => true
    _ => false
  }
}

///|
fn can_inline_interleaved_expr(expr : @expr.Expr) -> Bool {
  match expr {
    ConstE(_) | VarE(_) | CellE(_) => true
    IndexE(target, key) =>
      can_inline_interleaved_expr(target) && can_inline_interleaved_expr(key)
    UnaryE(_, inner) => can_inline_interleaved_expr(inner)
    BinaryE(_, lhs, rhs) | AndE(lhs, rhs) | OrE(lhs, rhs) =>
      can_inline_interleaved_expr(lhs) && can_inline_interleaved_expr(rhs)
    TableE(init) =>
      match init {
        EmptyTI => true
        ArrayTI(items, None) => {
          for item in items {
            if !can_inline_interleaved_expr(item) {
              return false
            }
          }
          true
        }
        ArrayTI(_, Some(_)) => false
        TableTI(fields) => {
          for field in fields {
            let (key, value) = field
            if !can_inline_interleaved_expr(key) ||
              !can_inline_interleaved_expr(value) {
              return false
            }
          }
          true
        }
      }
    NumericForCheckE(_, _, _) | CallE(_) | ClosureE(_) => false
  }
}

///|
fn positive_integer_key(expr : @expr.Expr) -> Int64? {
  match expr {
    ConstE(Integer(value)) => if value > 0 { Some(value) } else { None }
    _ => None
  }
}

///|
fn fields_to_array_init(
  fields : Array[(@expr.Expr, @expr.Expr)],
) -> @expr.TableInit {
  let items : Array[@expr.Expr] = []
  for i in 0..<fields.length() {
    let (key, value) = fields[i]
    match positive_integer_key(key) {
      Some(index) if index == (i + 1).to_int64() => items.push(value)
      _ => return @expr.TableTI(fields)
    }
  }
  @expr.ArrayTI(items, None)
}

///|
fn field_target(stmt : @expr.Stmt) -> (TableTarget, @expr.Expr, @expr.Expr)? {
  match stmt {
    SetIndexS(CellE(cell), key, value) => Some((CellT(cell), key, value))
    SetIndexS(VarE(target), key, value) => Some((VarT(target), key, value))
    _ => None
  }
}

///|
fn field_assigns_temp_value(
  stmt : @expr.Stmt,
  target : TableTarget,
  temp : @ssa.Var,
) -> (@expr.Expr, @expr.Expr)? {
  match field_target(stmt) {
    Some((actual, key, VarE(value))) if same_target(actual, target) &&
      value == temp &&
      !expr_reads_target(key, target) &&
      !expr_reads_var(key, temp) => Some((key, @expr.VarE(value)))
    _ => None
  }
}

///|
fn collect_interleaved_temp_field(
  body : @expr.Block,
  index : Int,
  target : TableTarget,
) -> (@expr.Expr, @expr.Expr, Int)? {
  match body[index] {
    BindS(temp, expr) if can_inline_interleaved_expr(expr) &&
      !expr_reads_target(expr, target) => {
      let mut value = expr
      let mut next = index + 1
      match expr {
        TableE(init) if is_empty_table_init(init) => {
          let (fields, after_fields) = collect_field_assigns(
            body,
            next,
            VarT(temp),
          )
          value = @expr.TableE(fields_to_array_init(fields))
          next = after_fields
        }
        _ => ()
      }
      guard next < body.length() else { return None }
      match field_assigns_temp_value(body[next], target, temp) {
        Some((key, _)) if !var_is_mentioned_after(body, next + 1, temp) &&
          !expr_reads_target(value, target) => Some((key, value, next + 1))
        _ => None
      }
    }
    _ => None
  }
}

///|
fn collect_field_assigns(
  body : @expr.Block,
  start : Int,
  target : TableTarget,
) -> (Array[(@expr.Expr, @expr.Expr)], Int) {
  let fields : Array[(@expr.Expr, @expr.Expr)] = []
  let mut i = start
  while i < body.length() {
    match field_target(body[i]) {
      Some((actual, key, value)) =>
        if same_target(actual, target) &&
          !expr_reads_target(key, target) &&
          !expr_reads_target(value, target) {
          fields.push((key, value))
          i = i + 1
        } else {
          break
        }
      None =>
        match collect_interleaved_temp_field(body, i, target) {
          Some((key, value, next)) => {
            fields.push((key, value))
            i = next
          }
          None => break
        }
    }
  }
  (fields, i)
}

///|
priv struct Folder {
  _unit : Unit
}

///|
fn fold_current_block(body : @expr.Block) -> @expr.Block {
  let out : @expr.Block = []
  let mut i = 0
  while i < body.length() {
    match body[i] {
      BindS(value, TableE(init)) if is_empty_table_init(init) => {
        let (fields, next) = collect_field_assigns(body, i + 1, VarT(value))
        if fields.is_empty() {
          out.push(body[i])
          i = i + 1
        } else {
          out.push(
            @expr.BindS(value, @expr.TableE(fields_to_array_init(fields))),
          )
          i = next
        }
      }
      LocalS([cell], [TableE(init)]) if is_empty_table_init(init) => {
        let (fields, next) = collect_field_assigns(body, i + 1, CellT(cell))
        if fields.is_empty() {
          out.push(body[i])
          i = i + 1
        } else {
          out.push(
            @expr.LocalS([cell], [@expr.TableE(fields_to_array_init(fields))]),
          )
          i = next
        }
      }
      ParallelAssignS([cell], [TableE(init)]) if is_empty_table_init(init) => {
        let (fields, next) = collect_field_assigns(body, i + 1, CellT(cell))
        if fields.is_empty() {
          out.push(body[i])
          i = i + 1
        } else {
          out.push(
            @expr.ParallelAssignS([cell], [
              @expr.TableE(fields_to_array_init(fields)),
            ]),
          )
          i = next
        }
      }
      _ => {
        out.push(body[i])
        i = i + 1
      }
    }
  }
  out
}

///|
impl @expr.MapVisitor for Folder with visit_Block(self, body) {
  fold_current_block(self.base().visit_Block(body))
}

///|
pub fn fold_table_init(program : @expr.Program) -> @expr.Program {
  let folder : Folder = { _unit: () }
  folder.visit_Program(program)
}
