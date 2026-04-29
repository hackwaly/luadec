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
fn is_empty_table_init(init : @expr.TableInit) -> Bool {
  match init {
    EmptyTI => true
    ArrayTI([], None) => true
    TableTI([]) => true
    _ => false
  }
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
      None => break
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
          out.push(@expr.BindS(value, @expr.TableE(@expr.TableTI(fields))))
          i = next
        }
      }
      LocalS([cell], [TableE(init)]) if is_empty_table_init(init) => {
        let (fields, next) = collect_field_assigns(body, i + 1, CellT(cell))
        if fields.is_empty() {
          out.push(body[i])
          i = i + 1
        } else {
          out.push(@expr.LocalS([cell], [@expr.TableE(@expr.TableTI(fields))]))
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
            @expr.ParallelAssignS([cell], [@expr.TableE(@expr.TableTI(fields))]),
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
