///|
priv struct NameState {
  vars : Map[@ssa.Var, String]
  cells : Map[@ssa.Cell, String]
  used : Map[String, Bool]
  class_vars : Map[@ssa.Var, Bool]
  class_cells : Map[@ssa.Cell, Bool]
  var_defs : Map[@ssa.Var, @expr.Expr]
}

///|
fn is_valid_identifier(name : String) -> Bool {
  name =~ re"^[A-Za-z_][A-Za-z0-9_]*$" &&
  !(name
  is ("and"
  | "break"
  | "do"
  | "else"
  | "elseif"
  | "end"
  | "false"
  | "for"
  | "function"
  | "goto"
  | "if"
  | "in"
  | "local"
  | "nil"
  | "not"
  | "or"
  | "repeat"
  | "return"
  | "then"
  | "true"
  | "until"
  | "while"))
}

///|
fn is_generated_identifier(name : String) -> Bool {
  name =~ re"^[vc][0-9]+$"
}

///|
fn usable_name(name : String) -> Bool {
  is_valid_identifier(name) && !is_generated_identifier(name)
}

///|
fn unique_name_in(used : Map[String, Bool], base : String) -> String? {
  guard usable_name(base) else { return None }
  if !used.get(base).unwrap_or(false) {
    used[base] = true
    return Some(base)
  }
  let mut index = 2
  while true {
    let candidate = "\{base}\{index}"
    if !used.get(candidate).unwrap_or(false) {
      used[candidate] = true
      return Some(candidate)
    }
    index = index + 1
  }
  None
}

///|
fn unique_name(state : NameState, base : String) -> String? {
  unique_name_in(state.used, base)
}

///|
fn add_var_name(
  state : NameState,
  value : @ssa.Var,
  candidate : String?,
) -> Unit {
  guard state.vars.get(value) is None else { return }
  match candidate {
    Some(base) =>
      match unique_name(state, base) {
        Some(name) => {
          state.vars[value] = name
          propagate_default_alias_name(state, value, name)
        }
        None => ()
      }
    None => ()
  }
}

///|
fn add_func_param_name(
  state : NameState,
  func : @expr.Func,
  index : Int,
  candidate : String?,
) -> Unit {
  guard index < func.params.length() else { return }
  let value = func.params[index]
  guard state.vars.get(value) is None else { return }
  match candidate {
    Some(base) => {
      let used : Map[String, Bool] = {}
      for param in func.params {
        match state.vars.get(param) {
          Some(name) => used[name] = true
          None => ()
        }
      }
      match unique_name_in(used, base) {
        Some(name) => {
          state.vars[value] = name
          propagate_default_alias_name(state, value, name)
        }
        None => ()
      }
    }
    None => ()
  }
}

///|
fn add_cell_name(
  state : NameState,
  cell : @ssa.Cell,
  candidate : String?,
) -> Unit {
  guard !cell.is_env() && state.cells.get(cell) is None else { return }
  match candidate {
    Some(base) =>
      match unique_name(state, base) {
        Some(name) => state.cells[cell] = name
        None => ()
      }
    None => ()
  }
}

///|
fn string_key_name(expr : @expr.Expr) -> String? {
  match expr {
    ConstE(AsciiString(name, is_valid_identifier=true)) => Some(name)
    _ => None
  }
}

///|
fn lower_first(name : String) -> String? {
  guard !name.is_empty() else { return None }
  let chars = name.to_array()
  chars[0] = chars[0].to_ascii_lowercase()
  Some(String::from_array(chars))
}

///|
fn snake_to_lower_camel(name : String) -> String? {
  let parts = name.split("_").to_array()
  let out : Array[Char] = []
  let mut first = true
  for part_view in parts {
    let part = part_view.to_owned()
    guard !part.is_empty() else { continue }
    let chars = part.to_array()
    if first {
      for ch in chars {
        out.push(ch.to_ascii_lowercase())
      }
      first = false
    } else {
      chars[0] = chars[0].to_ascii_uppercase()
      for i in 0..<chars.length() {
        let ch = if i == 0 { chars[i] } else { chars[i].to_ascii_lowercase() }
        out.push(ch)
      }
    }
  }
  guard !out.is_empty() else { return None }
  Some(String::from_array(out))
}

///|
fn path_basename(path : String) -> String {
  match path.rev_split_once("/") {
    Some((_, base)) => base.to_owned()
    None => path
  }
}

///|
fn inferred_module_name(path : String) -> String? {
  snake_to_lower_camel(path_basename(path))
}

///|
fn require_name(args : Array[@expr.Expr]) -> String? {
  match args {
    [ConstE(AsciiString(path, ..))] | [ConstE(Utf8String(path))] =>
      inferred_module_name(path)
    _ => None
  }
}

///|
fn class_name(args : Array[@expr.Expr]) -> String? {
  match args {
    [ConstE(AsciiString(name, ..)), ..] | [ConstE(Utf8String(name)), ..] =>
      Some(name)
    _ => None
  }
}

///|
fn is_class_constructor(expr : @expr.Expr) -> Bool {
  match expr {
    CallE(call) =>
      match call {
        NormalC(callee, args, _) =>
          match callee {
            IndexE(CellE(cell), ConstE(AsciiString("class", ..))) if cell.is_env() =>
              class_name(args) is Some(_)
            _ => false
          }
        _ => false
      }
    _ => false
  }
}

///|
fn mark_class_var(
  state : NameState,
  value : @ssa.Var,
  expr : @expr.Expr,
) -> Unit {
  if is_class_constructor(expr) {
    state.class_vars[value] = true
  }
}

///|
fn mark_class_cell(
  state : NameState,
  cell : @ssa.Cell,
  expr : @expr.Expr,
) -> Unit {
  if is_class_constructor(expr) {
    state.class_cells[cell] = true
  }
}

///|
fn is_class_expr(state : NameState, expr : @expr.Expr) -> Bool {
  match expr {
    VarE(value) => state.class_vars.get(value).unwrap_or(false)
    CellE(cell) => state.class_cells.get(cell).unwrap_or(false)
    _ => false
  }
}

///|
fn is_env_expr(expr : @expr.Expr) -> Bool {
  match expr {
    CellE(cell) => cell.is_env()
    _ => false
  }
}

///|
fn infer_assigned_value_name(
  state : NameState,
  target : @expr.Expr,
  key : @expr.Expr,
  value : @expr.Expr,
) -> Unit {
  guard !is_env_expr(target) else { return }
  match string_key_name(key) {
    Some(name) =>
      match value {
        VarE(value) => add_var_name(state, value, Some(name))
        CellE(cell) => add_cell_name(state, cell, Some(name))
        _ => ()
      }
    None => ()
  }
}

///|
fn infer_default_alias_name(
  state : NameState,
  value : @ssa.Var,
  expr : @expr.Expr,
) -> Unit {
  match expr {
    OrE(VarE(source), _) =>
      match state.vars.get(value) {
        Some(name) => add_var_name(state, source, Some(name))
        None => ()
      }
    _ => ()
  }
}

///|
fn propagate_default_alias_name(
  state : NameState,
  value : @ssa.Var,
  name : String,
) -> Unit {
  match state.var_defs.get(value) {
    Some(OrE(VarE(source), _)) => add_var_name(state, source, Some(name))
    _ => ()
  }
}

///|
fn setter_parameter_name(method_name : String) -> String? {
  match method_name.strip_prefix("set") {
    Some(rest) if !rest.is_empty() && rest.to_array()[0].is_ascii_uppercase() =>
      lower_first(rest.to_owned())
    _ => None
  }
}

///|
fn mutator_argument_name(method_name : String) -> String? {
  for prefix in ["set", "add"] {
    match method_name.strip_prefix(prefix) {
      Some(rest) if !rest.is_empty() && rest.to_array()[0].is_ascii_uppercase() =>
        return lower_first(rest.to_owned())
      _ => ()
    }
  }
  None
}

///|
fn infer_var_arg_name(
  state : NameState,
  arg : @expr.Expr,
  candidate : String?,
) -> Unit {
  match arg {
    VarE(value) => add_var_name(state, value, candidate)
    _ => ()
  }
}

///|
fn infer_class_method_names(
  state : NameState,
  target : @expr.Expr,
  key : @expr.Expr,
  value : @expr.Expr,
) -> Unit {
  guard is_class_expr(state, target) else { return }
  match (key, value) {
    (ConstE(AsciiString(method_name, is_valid_identifier=true)), ClosureE(func)) => {
      if !func.params.is_empty() {
        add_func_param_name(state, func, 0, Some("self"))
      }
      match setter_parameter_name(method_name) {
        Some(name) if func.params.length() >= 2 =>
          add_func_param_name(state, func, 1, Some(name))
        _ => ()
      }
    }
    _ => ()
  }
}

///|
fn strip_method_prefix(name : String) -> String? {
  for prefix in ["get", "create", "make", "new", "find"] {
    match name.strip_prefix(prefix) {
      Some(rest) if !rest.is_empty() => return Some(rest.to_owned())
      _ => ()
    }
  }
  None
}

///|
fn inferred_method_result_name(method_name : String) -> String? {
  match strip_method_prefix(method_name) {
    Some(rest) => lower_first(rest)
    None =>
      if method_name.has_prefix("is") ||
        method_name.has_prefix("has") ||
        method_name.has_prefix("can") ||
        method_name.has_prefix("should") {
        Some(method_name)
      } else {
        None
      }
  }
}

///|
fn expr_name(expr : @expr.Expr) -> String? {
  match expr {
    IndexE(_, key) => string_key_name(key)
    CallE(call) => call_name(call)
    _ => None
  }
}

///|
fn multi_name(multi : @expr.Multi) -> String? {
  match multi {
    CallM(call) => call_name(call)
    VarargM => None
  }
}

///|
fn call_name(call : @expr.Call) -> String? {
  match call {
    MethodC(_, method_name, _, _) => inferred_method_result_name(method_name)
    NormalC(callee, args, _) =>
      match callee {
        IndexE(CellE(cell), ConstE(AsciiString("require", ..))) if cell.is_env() =>
          require_name(args)
        IndexE(CellE(cell), ConstE(AsciiString("class", ..))) if cell.is_env() =>
          class_name(args)
        _ => None
      }
  }
}

///|
fn infer_expr(state : NameState, expr : @expr.Expr) -> Unit {
  match expr {
    ConstE(_) | VarE(_) | CellE(_) => ()
    NumericForCheckE(ctrl, limit, step) => {
      infer_expr(state, ctrl)
      infer_expr(state, limit)
      infer_expr(state, step)
    }
    IndexE(target, key) => {
      infer_expr(state, target)
      infer_expr(state, key)
    }
    TableE(init) => infer_table_init(state, init)
    UnaryE(_, inner) => infer_expr(state, inner)
    BinaryE(_, lhs, rhs) | AndE(lhs, rhs) | OrE(lhs, rhs) => {
      infer_expr(state, lhs)
      infer_expr(state, rhs)
    }
    CallE(call) => infer_call(state, call)
    ClosureE(func) => infer_func(state, func)
  }
}

///|
fn infer_table_init(state : NameState, init : @expr.TableInit) -> Unit {
  match init {
    EmptyTI => ()
    ArrayTI(items, multi) => {
      for item in items {
        infer_expr(state, item)
      }
      match multi {
        Some(next) => infer_multi(state, next)
        None => ()
      }
    }
    TableTI(fields) =>
      for field in fields {
        let (key, value) = field
        infer_expr(state, key)
        infer_expr(state, value)
      }
  }
}

///|
fn infer_multi(state : NameState, multi : @expr.Multi) -> Unit {
  match multi {
    VarargM => ()
    CallM(call) => infer_call(state, call)
  }
}

///|
fn infer_call(state : NameState, call : @expr.Call) -> Unit {
  match call {
    NormalC(callee, args, multi) => {
      infer_expr(state, callee)
      for arg in args {
        infer_expr(state, arg)
      }
      match multi {
        Some(next) => infer_multi(state, next)
        None => ()
      }
    }
    MethodC(target, method_name, args, multi) => {
      match args {
        [first_arg, ..] =>
          infer_var_arg_name(
            state,
            first_arg,
            mutator_argument_name(method_name),
          )
        _ => ()
      }
      infer_expr(state, target)
      for arg in args {
        infer_expr(state, arg)
      }
      match multi {
        Some(next) => infer_multi(state, next)
        None => ()
      }
    }
  }
}

///|
fn infer_stmt(state : NameState, stmt : @expr.Stmt) -> Unit {
  match stmt {
    BindS(value, expr) => {
      state.var_defs[value] = expr
      add_var_name(state, value, expr_name(expr))
      mark_class_var(state, value, expr)
      infer_default_alias_name(state, value, expr)
      infer_expr(state, expr)
    }
    BindMultiS(values, multi) => {
      match values {
        [value] => add_var_name(state, value, multi_name(multi))
        _ => ()
      }
      infer_multi(state, multi)
    }
    SetIndexS(target, key, value) => {
      infer_class_method_names(state, target, key, value)
      infer_assigned_value_name(state, target, key, value)
      infer_expr(state, target)
      infer_expr(state, key)
      infer_expr(state, value)
    }
    SetListS(target, index, values, multi) => {
      infer_expr(state, target)
      infer_expr(state, index)
      for value in values {
        infer_expr(state, value)
      }
      match multi {
        Some(next) => infer_multi(state, next)
        None => ()
      }
    }
    LocalS(cells, values) =>
      for i in 0..<values.length() {
        if i < cells.length() {
          add_cell_name(state, cells[i], expr_name(values[i]))
          mark_class_cell(state, cells[i], values[i])
        }
        infer_expr(state, values[i])
      }
    ParallelAssignS(cells, values) =>
      for i in 0..<values.length() {
        if i < cells.length() {
          add_cell_name(state, cells[i], expr_name(values[i]))
          mark_class_cell(state, cells[i], values[i])
        }
        infer_expr(state, values[i])
      }
    ReturnS(values, multi) => {
      for value in values {
        infer_expr(state, value)
      }
      match multi {
        Some(next) => infer_multi(state, next)
        None => ()
      }
    }
    DoS(body) | WhileS(_, body) => infer_block(state, body)
    IfS(branches, else_body) => {
      for branch in branches {
        let (cond, body) = branch
        infer_expr(state, cond)
        infer_block(state, body)
      }
      match else_body {
        Some(body) => infer_block(state, body)
        None => ()
      }
    }
    NumericForS(value, start, stop, step, body) => {
      add_var_name(state, value, Some("i"))
      infer_expr(state, start)
      infer_expr(state, stop)
      match step {
        Some(value) => infer_expr(state, value)
        None => ()
      }
      infer_block(state, body)
    }
    GenericForS(values, iterators, multi, body) => {
      match values {
        [key, value] => {
          add_var_name(state, key, Some("key"))
          add_var_name(state, value, Some("value"))
        }
        _ => ()
      }
      for iter in iterators {
        infer_expr(state, iter)
      }
      match multi {
        Some(next) => infer_multi(state, next)
        None => ()
      }
      infer_block(state, body)
    }
    BreakS => ()
  }
}

///|
fn infer_block(state : NameState, body : @expr.Block) -> Unit {
  for stmt in body {
    infer_stmt(state, stmt)
  }
}

///|
fn infer_func(state : NameState, func : @expr.Func) -> Unit {
  infer_block(state, func.body)
}

///|
pub fn infer_names(program : @expr.Program) -> @expr.NamedProgram {
  let state : NameState = {
    vars: {},
    cells: {},
    used: {},
    class_vars: {},
    class_cells: {},
    var_defs: {},
  }
  infer_block(state, program)
  { program, names: { vars: state.vars, cells: state.cells } }
}
