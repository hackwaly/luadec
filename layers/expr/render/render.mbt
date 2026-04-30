///|
fn is_not_generated_identifier(id : StringView) -> Bool {
  match id {
    ['v' | 'c', '0'..='9', ..] => false
    _ => true
  }
}

///|
priv struct RenderCtx {
  names : @expr.Names?
}

///|
fn default_ctx() -> RenderCtx {
  { names: None }
}

///|
fn comma_sep_docs(docs : ArrayView[@pretty.Doc]) -> @pretty.Doc {
  @pretty.join(@pretty.concat(@pretty.text(","), @pretty.line()), docs)
}

///|
fn comma_space_sep_docs(docs : ArrayView[@pretty.Doc]) -> @pretty.Doc {
  @pretty.join(@pretty.text(", "), docs)
}

///|
fn comma_sep_group(docs : ArrayView[@pretty.Doc]) -> @pretty.Doc {
  @pretty.group(comma_sep_docs(docs))
}

///|
fn paren_list(docs : ArrayView[@pretty.Doc]) -> @pretty.Doc {
  if docs.is_empty() {
    @pretty.text("()")
  } else {
    @pretty.group(
      @pretty.concat_all([
        @pretty.text("("),
        @pretty.nest(
          2,
          @pretty.concat(@pretty.linebreak(), comma_sep_docs(docs)),
        ),
        @pretty.linebreak(),
        @pretty.text(")"),
      ]),
    )
  }
}

///|
fn hardline_comma_sep_docs(docs : ArrayView[@pretty.Doc]) -> @pretty.Doc {
  @pretty.join(@pretty.concat(@pretty.text(","), @pretty.hardline()), docs)
}

///|
fn paren_list_with_closure_args(docs : ArrayView[@pretty.Doc]) -> @pretty.Doc {
  if docs.is_empty() {
    @pretty.text("()")
  } else {
    @pretty.UnionD(
      @pretty.concat_all([
        @pretty.text("("),
        comma_space_sep_docs(docs),
        @pretty.text(")"),
      ]),
      @pretty.concat_all([
        @pretty.text("("),
        @pretty.nest(
          2,
          @pretty.concat(@pretty.hardline(), hardline_comma_sep_docs(docs)),
        ),
        @pretty.hardline(),
        @pretty.text(")"),
      ]),
    )
  }
}

///|
fn brace_list(docs : ArrayView[@pretty.Doc]) -> @pretty.Doc {
  @pretty.group(
    @pretty.concat_all([
      @pretty.text("{"),
      @pretty.nest(2, @pretty.concat(@pretty.line(), comma_sep_docs(docs))),
      @pretty.line(),
      @pretty.text("}"),
    ]),
  )
}

///|
fn line_docs(docs : ArrayView[@pretty.Doc]) -> @pretty.Doc {
  @pretty.join(@pretty.hardline(), docs)
}

///|
fn block_docs(docs : ArrayView[@pretty.Doc]) -> @pretty.Doc {
  @pretty.join(@pretty.concat(@pretty.hardline(), @pretty.hardline()), docs)
}

///|
pub fn format_value(value : @ssa.Var) -> String {
  "v\{value.id.0}"
}

///|
fn format_value_with(ctx : RenderCtx, value : @ssa.Var) -> String {
  match ctx.names {
    Some(names) =>
      match names.vars.get(value) {
        Some(name) => name
        None => "v\{value.id.0}"
      }
    None => "v\{value.id.0}"
  }
}

///|
pub fn format_cell(cell : @ssa.Cell) -> String {
  format_cell_with(default_ctx(), cell)
}

///|
fn format_cell_with(ctx : RenderCtx, cell : @ssa.Cell) -> String {
  if cell.id.0 == -1 {
    "_ENV"
  } else {
    match ctx.names {
      Some(names) =>
        match names.cells.get(cell) {
          Some(name) => name
          None => "c\{cell.id.0}"
        }
      None => "c\{cell.id.0}"
    }
  }
}

///|
fn unary_op_text(op : @ssa.UnaryOp) -> String {
  match op {
    Neg => "-"
    BNot => "~"
    Not => "not "
    Len => "#"
  }
}

///|
fn binary_op_text(op : @ssa.BinaryOp) -> String {
  match op {
    Add => "+"
    Sub => "-"
    Mul => "*"
    Mod => "%"
    Pow => "^"
    Div => "/"
    IDiv => "//"
    BAnd => "&"
    BOr => "|"
    BXor => "~"
    Shl => "<<"
    Shr => ">>"
    Eq => "=="
    Lt => "<"
    Gt => ">"
    Neq => "~="
    Leq => "<="
    Geq => ">="
    Concat => ".."
  }
}

///|
fn binary_op_prec(op : @ssa.BinaryOp) -> Int {
  match op {
    Pow => 12
    Mul | Div | IDiv | Mod => 10
    Add | Sub => 9
    Concat => 8
    Shl | Shr => 7
    BAnd => 6
    BXor => 5
    BOr => 4
    Eq | Neq | Lt | Gt | Leq | Geq => 3
  }
}

///|
fn binary_op_right_assoc(op : @ssa.BinaryOp) -> Bool {
  match op {
    Concat | Pow => true
    _ => false
  }
}

///|
fn swap_ordered_comparison_op(op : @ssa.BinaryOp) -> @ssa.BinaryOp? {
  match op {
    Lt => Some(Gt)
    Gt => Some(Lt)
    Leq => Some(Geq)
    Geq => Some(Leq)
    _ => None
  }
}

///|
fn logical_op_prec(expr : @expr.Expr) -> Int {
  match expr {
    OrE(_, _) => 1
    AndE(_, _) => 2
    _ => 100
  }
}

///|
fn expr_prec(expr : @expr.Expr) -> Int {
  match expr {
    ConstE(_)
    | VarE(_)
    | CellE(_)
    | CallE(_)
    | TableE(_)
    | ClosureE(_)
    | IndexE(_, _)
    | NumericForCheckE(_, _, _) => 100
    UnaryE(_, _) => 11
    BinaryE(op, _, _) => binary_op_prec(op)
    AndE(_, _) => 2
    OrE(_, _) => 1
  }
}

///|
fn render_expr_ctx_with(
  ctx : RenderCtx,
  expr : @expr.Expr,
  min_prec : Int,
) -> @pretty.Doc {
  let doc = render_expr_doc_with(ctx, expr)
  if expr_prec(expr) < min_prec {
    @pretty.parens(doc)
  } else {
    doc
  }
}

///|
fn render_constant(constant : @ssa.Constant) -> String {
  match constant {
    Nil => "nil"
    Boolean(value) => value.to_string()
    Number(value) => value.to_string()
    Integer(value) => value.to_string()
    Utf8String(value) => value.escape(quote=true)
    BytesString(value) => value.to_string()
    AsciiString(value, ..) => value.escape(quote=true)
  }
}

///|
pub fn render_multi_doc(multi : @expr.Multi) -> @pretty.Doc {
  render_multi_doc_with(default_ctx(), multi)
}

///|
fn render_multi_doc_with(ctx : RenderCtx, multi : @expr.Multi) -> @pretty.Doc {
  match multi {
    VarargM => @pretty.text("...")
    CallM(call) => render_call_doc_with(ctx, call)
  }
}

///|
fn render_callee_doc_with(ctx : RenderCtx, expr : @expr.Expr) -> @pretty.Doc {
  match expr {
    ConstE(_) | VarE(_) | CellE(_) | IndexE(_, _) | CallE(_) =>
      render_expr_doc_with(ctx, expr)
    _ => @pretty.parens(render_expr_doc_with(ctx, expr))
  }
}

///|
fn has_closure_arg(args : ArrayView[@expr.Expr]) -> Bool {
  for arg in args {
    if arg is ClosureE(_) {
      return true
    }
  }
  false
}

///|
fn call_paren_list(
  arg_docs : ArrayView[@pretty.Doc],
  args : ArrayView[@expr.Expr],
) -> @pretty.Doc {
  if has_closure_arg(args) {
    paren_list_with_closure_args(arg_docs)
  } else {
    paren_list(arg_docs)
  }
}

///|
pub fn render_call_doc(call : @expr.Call) -> @pretty.Doc {
  render_call_doc_with(default_ctx(), call)
}

///|
fn render_call_doc_with(ctx : RenderCtx, call : @expr.Call) -> @pretty.Doc {
  match call {
    NormalC(callee, args, multi) => {
      let arg_docs : Array[@pretty.Doc] = []
      for arg in args {
        arg_docs.push(render_expr_doc_with(ctx, arg))
      }
      match multi {
        Some(next) => arg_docs.push(render_multi_doc_with(ctx, next))
        None => ()
      }
      @pretty.concat(
        render_callee_doc_with(ctx, callee),
        call_paren_list(arg_docs, args),
      )
    }
    MethodC(target, method_name, args, multi) => {
      let arg_docs : Array[@pretty.Doc] = []
      for arg in args {
        arg_docs.push(render_expr_doc_with(ctx, arg))
      }
      match multi {
        Some(next) => arg_docs.push(render_multi_doc_with(ctx, next))
        None => ()
      }
      @pretty.concat(
        @pretty.concat_all([
          render_callee_doc_with(ctx, target),
          @pretty.text(":"),
          @pretty.text(method_name),
        ]),
        call_paren_list(arg_docs, args),
      )
    }
  }
}

///|
fn render_table_init_doc_with(
  ctx : RenderCtx,
  init : @expr.TableInit,
) -> @pretty.Doc {
  match init {
    EmptyTI => @pretty.text("{}")
    ArrayTI(items, multi) => {
      let docs = items.map(fn(item) { render_expr_doc_with(ctx, item) })
      match multi {
        Some(next) => docs.push(render_multi_doc_with(ctx, next))
        None => ()
      }
      brace_list(docs)
    }
    TableTI(fields) => {
      let docs : Array[@pretty.Doc] = []
      for field in fields {
        let (key, value) = field
        match key {
          ConstE(AsciiString(id, is_valid_identifier=true)) =>
            docs.push(
              @pretty.concat_all([
                @pretty.text(id),
                @pretty.text(" = "),
                render_expr_doc_with(ctx, value),
              ]),
            )
          _ =>
            docs.push(
              @pretty.concat_all([
                @pretty.text("["),
                render_expr_doc_with(ctx, key),
                @pretty.text("] = "),
                render_expr_doc_with(ctx, value),
              ]),
            )
        }
      }
      brace_list(docs)
    }
  }
}

///|
pub fn render_expr_doc(expr : @expr.Expr) -> @pretty.Doc {
  render_expr_doc_with(default_ctx(), expr)
}

///|
fn render_expr_doc_with(ctx : RenderCtx, expr : @expr.Expr) -> @pretty.Doc {
  match expr {
    ConstE(constant) => @pretty.text(render_constant(constant))
    VarE(value) => @pretty.text(format_value_with(ctx, value))
    CellE(cell) => @pretty.text(format_cell_with(ctx, cell))
    NumericForCheckE(ctrl, limit, step) =>
      @pretty.concat(
        @pretty.text("numeric_for_check"),
        paren_list([
          render_expr_doc_with(ctx, ctrl),
          render_expr_doc_with(ctx, limit),
          render_expr_doc_with(ctx, step),
        ]),
      )
    IndexE(target, ConstE(AsciiString(id, is_valid_identifier=true))) =>
      if target is CellE(c) && c.is_env() && is_not_generated_identifier(id) {
        @pretty.text(id)
      } else {
        @pretty.concat_all([
          render_callee_doc_with(ctx, target),
          @pretty.text("."),
          @pretty.text(id),
        ])
      }
    IndexE(target, key) =>
      @pretty.concat(
        render_callee_doc_with(ctx, target),
        @pretty.brackets(render_expr_doc_with(ctx, key)),
      )
    TableE(init) => render_table_init_doc_with(ctx, init)
    UnaryE(op, inner) =>
      @pretty.concat(
        @pretty.text(unary_op_text(op)),
        render_expr_ctx_with(ctx, inner, 11),
      )
    BinaryE(op, lhs, rhs) => {
      let (op, lhs, rhs) = match (lhs, rhs) {
        (ConstE(_), _) =>
          match swap_ordered_comparison_op(op) {
            Some(swapped) => (swapped, rhs, lhs)
            None => (op, lhs, rhs)
          }
        _ => (op, lhs, rhs)
      }
      let prec = binary_op_prec(op)
      let right_assoc = binary_op_right_assoc(op)
      let lhs_min = if right_assoc { prec + 1 } else { prec }
      let rhs_min = if right_assoc { prec } else { prec + 1 }
      @pretty.concat_all([
        render_expr_ctx_with(ctx, lhs, lhs_min),
        @pretty.space(),
        @pretty.text(binary_op_text(op)),
        @pretty.space(),
        render_expr_ctx_with(ctx, rhs, rhs_min),
      ])
    }
    AndE(lhs, rhs) => {
      let lhs_min = if logical_op_prec(rhs) == 2 { 3 } else { 2 }
      @pretty.concat_all([
        render_expr_ctx_with(ctx, lhs, lhs_min),
        @pretty.space(),
        @pretty.text("and"),
        @pretty.space(),
        render_expr_ctx_with(ctx, rhs, 2),
      ])
    }
    OrE(lhs, rhs) =>
      @pretty.concat_all([
        render_expr_ctx_with(ctx, lhs, 1),
        @pretty.space(),
        @pretty.text("or"),
        @pretty.space(),
        render_expr_ctx_with(ctx, rhs, 1),
      ])
    CallE(call) => render_call_doc_with(ctx, call)
    ClosureE(func) => render_func_doc_with(ctx, func)
  }
}

///|
fn render_expr_list_doc(
  ctx : RenderCtx,
  values : ArrayView[@expr.Expr],
  multi : @expr.Multi?,
) -> @pretty.Doc {
  let docs = values.map(fn(value) { render_expr_doc_with(ctx, value) })
  match multi {
    Some(next) => docs.push(render_multi_doc_with(ctx, next))
    None => ()
  }
  comma_sep_group(docs)
}

///|
fn render_cell_list_doc(
  ctx : RenderCtx,
  cells : ArrayView[@ssa.Cell],
) -> @pretty.Doc {
  comma_sep_group(
    cells.map(fn(cell) { @pretty.text(format_cell_with(ctx, cell)) }),
  )
}

///|
fn all_nil_exprs(values : ArrayView[@expr.Expr]) -> Bool {
  for value in values {
    match value {
      ConstE(Nil) => ()
      _ => return false
    }
  }
  true
}

///|
fn render_var_list_doc(
  ctx : RenderCtx,
  values : ArrayView[@ssa.Var],
) -> @pretty.Doc {
  comma_space_sep_docs(
    values.map(fn(value) { @pretty.text(format_value_with(ctx, value)) }),
  )
}

///|
fn render_function_name_doc_with(
  ctx : RenderCtx,
  expr : @expr.Expr,
) -> @pretty.Doc? {
  match expr {
    VarE(_) | CellE(_) => Some(render_expr_doc_with(ctx, expr))
    IndexE(target, ConstE(AsciiString(id, is_valid_identifier=true))) =>
      match render_function_name_doc_with(ctx, target) {
        Some(target_doc) =>
          Some(
            @pretty.concat_all([target_doc, @pretty.text("."), @pretty.text(id)]),
          )
        None => None
      }
    _ => None
  }
}

///|
fn function_param_name(ctx : RenderCtx, param : @ssa.Var) -> String {
  format_value_with(ctx, param)
}

///|
fn render_block_inside(ctx : RenderCtx, body : @expr.Block) -> @pretty.Doc {
  if body.is_empty() {
    @pretty.empty()
  } else {
    @pretty.nest(
      2,
      @pretty.concat(@pretty.hardline(), render_block_doc_with(ctx, body)),
    )
  }
}

///|
fn render_end_block(
  ctx : RenderCtx,
  keyword_doc : @pretty.Doc,
  body : @expr.Block,
) -> @pretty.Doc {
  @pretty.concat_all([
    keyword_doc,
    render_block_inside(ctx, body),
    @pretty.hardline(),
    @pretty.text("end"),
  ])
}

///|
fn is_one_expr(expr : @expr.Expr) -> Bool {
  match expr {
    ConstE(Integer(1L)) | ConstE(Number(1)) => true
    _ => false
  }
}

///|
fn render_while_doc_with(
  ctx : RenderCtx,
  cond : @expr.Expr,
  body : @expr.Block,
) -> @pretty.Doc {
  render_end_block(
    ctx,
    @pretty.concat_all([
      @pretty.text("while "),
      render_expr_doc_with(ctx, cond),
      @pretty.text(" do"),
    ]),
    body,
  )
}

///|
pub fn render_stmt_doc(stmt : @expr.Stmt) -> @pretty.Doc {
  render_stmt_doc_with(default_ctx(), stmt)
}

///|
fn render_stmt_doc_with(ctx : RenderCtx, stmt : @expr.Stmt) -> @pretty.Doc {
  match stmt {
    BindS(value, expr) =>
      @pretty.concat_all([
        @pretty.text("local "),
        @pretty.text(format_value_with(ctx, value)),
        @pretty.text(" = "),
        render_expr_doc_with(ctx, expr),
      ])
    BindMultiS(values, multi) =>
      if values.is_empty() {
        render_multi_doc_with(ctx, multi)
      } else {
        @pretty.concat_all([
          @pretty.text("local "),
          render_var_list_doc(ctx, values),
          @pretty.text(" = "),
          render_multi_doc_with(ctx, multi),
        ])
      }
    SetIndexS(target, ConstE(AsciiString(id, is_valid_identifier=true)), value) =>
      match value {
        ClosureE(func) =>
          match render_method_definition_doc_with(ctx, target, id, func) {
            Some(doc) => doc
            None => render_field_assignment_doc_with(ctx, target, id, value)
          }
        _ => render_field_assignment_doc_with(ctx, target, id, value)
      }
    SetIndexS(target, key, value) =>
      @pretty.concat_all([
        render_expr_doc_with(ctx, target),
        @pretty.brackets(render_expr_doc_with(ctx, key)),
        @pretty.text(" = "),
        render_expr_doc_with(ctx, value),
      ])
    SetListS(target, index, values, multi) => {
      let value_docs = values.map(fn(expr) { render_expr_doc_with(ctx, expr) })
      let tail_doc = match multi {
        Some(next) => render_multi_doc_with(ctx, next)
        None => @pretty.text("nil")
      }
      @pretty.concat_all([
        @pretty.text("__setlist"),
        paren_list([
          render_expr_doc_with(ctx, target),
          render_expr_doc_with(ctx, index),
          brace_list(value_docs),
          tail_doc,
        ]),
      ])
    }
    LocalS(cells, values) =>
      if values.is_empty() {
        @pretty.concat_all([
          @pretty.text("local "),
          render_cell_list_doc(ctx, cells),
        ])
      } else if cells.length() == values.length() && all_nil_exprs(values) {
        @pretty.concat_all([
          @pretty.text("local "),
          render_cell_list_doc(ctx, cells),
        ])
      } else {
        @pretty.concat_all([
          @pretty.text("local "),
          render_cell_list_doc(ctx, cells),
          @pretty.text(" = "),
          comma_sep_group(
            values.map(fn(value) { render_expr_doc_with(ctx, value) }),
          ),
        ])
      }
    ParallelAssignS(cells, values) =>
      @pretty.concat_all([
        render_cell_list_doc(ctx, cells),
        @pretty.text(" = "),
        comma_sep_group(
          values.map(fn(value) { render_expr_doc_with(ctx, value) }),
        ),
      ])
    ReturnS(values, multi) =>
      if values.is_empty() && multi is None {
        @pretty.text("return")
      } else {
        @pretty.concat(
          @pretty.text("return "),
          render_expr_list_doc(ctx, values, multi),
        )
      }
    DoS(body) => render_end_block(ctx, @pretty.text("do"), body)
    IfS(branches, else_body) => render_if_doc_with(ctx, branches, else_body)
    WhileS(cond, body) => render_while_doc_with(ctx, cond, body)
    NumericForS(value, start, stop, step, body) => {
      let header_docs : Array[@pretty.Doc] = [
        @pretty.text(format_value_with(ctx, value)),
        render_expr_doc_with(ctx, start),
        render_expr_doc_with(ctx, stop),
      ]
      match step {
        Some(value) if !is_one_expr(value) =>
          header_docs.push(render_expr_doc_with(ctx, value))
        Some(_) | None => ()
      }
      render_end_block(
        ctx,
        @pretty.concat_all([
          @pretty.text("for "),
          @pretty.join(@pretty.text(" = "), [
            header_docs[0],
            @pretty.join(@pretty.text(", "), header_docs[1:]),
          ]),
          @pretty.text(" do"),
        ]),
        body,
      )
    }
    GenericForS(values, iterators, multi, body) =>
      render_end_block(
        ctx,
        @pretty.concat_all([
          @pretty.text("for "),
          render_var_list_doc(ctx, values),
          @pretty.text(" in "),
          render_expr_list_doc(ctx, iterators, multi),
          @pretty.text(" do"),
        ]),
        body,
      )
    BreakS => @pretty.text("break")
  }
}

///|
fn render_field_assignment_doc_with(
  ctx : RenderCtx,
  target : @expr.Expr,
  id : String,
  value : @expr.Expr,
) -> @pretty.Doc {
  if target is CellE(c) && c.is_env() && is_not_generated_identifier(id) {
    @pretty.concat_all([
      @pretty.text(id),
      @pretty.text(" = "),
      render_expr_doc_with(ctx, value),
    ])
  } else {
    @pretty.concat_all([
      render_expr_doc_with(ctx, target),
      @pretty.text("."),
      @pretty.text(id),
      @pretty.text(" = "),
      render_expr_doc_with(ctx, value),
    ])
  }
}

///|
fn render_method_definition_doc_with(
  ctx : RenderCtx,
  target : @expr.Expr,
  method_name : String,
  func : @expr.Func,
) -> @pretty.Doc? {
  guard !func.params.is_empty() else { return None }
  guard function_param_name(ctx, func.params[0]) == "self" else { return None }
  let args : Array[@pretty.Doc] = []
  for param in func.params[1:] {
    args.push(@pretty.text(function_param_name(ctx, param)))
  }
  if func.vararg {
    args.push(@pretty.text("..."))
  }
  match render_function_name_doc_with(ctx, target) {
    Some(target_doc) =>
      Some(
        @pretty.concat_all([
          @pretty.text("function "),
          target_doc,
          @pretty.text(":"),
          @pretty.text(method_name),
          paren_list(args),
          render_block_inside(ctx, func.body),
          @pretty.hardline(),
          @pretty.text("end"),
        ]),
      )
    None => None
  }
}

///|
fn render_if_doc_with(
  ctx : RenderCtx,
  branches : Array[(@expr.Expr, @expr.Block)],
  else_body : @expr.Block?,
) -> @pretty.Doc {
  guard !branches.is_empty() else { panic() }
  let else_body = match else_body {
    Some([]) => None
    _ => else_body
  }
  let docs : Array[@pretty.Doc] = []
  for i in 0..<branches.length() {
    let (cond, body) = branches[i]
    let keyword = if i == 0 { "if " } else { "elseif " }
    docs.push(
      @pretty.concat_all([
        @pretty.text(keyword),
        render_expr_doc_with(ctx, cond),
        @pretty.text(" then"),
        render_block_inside(ctx, body),
      ]),
    )
  }
  match else_body {
    Some(body) =>
      docs.push(
        @pretty.concat_all([
          @pretty.text("else"),
          render_block_inside(ctx, body),
        ]),
      )
    None => ()
  }
  docs.push(@pretty.text("end"))
  line_docs(docs)
}

///|
fn render_block_docs_with(
  ctx : RenderCtx,
  body : @expr.Block,
) -> Array[@pretty.Doc] {
  let docs : Array[@pretty.Doc] = []
  for stmt in body {
    docs.push(render_stmt_doc_with(ctx, stmt))
  }
  docs
}

///|
pub fn render_block_doc(body : @expr.Block) -> @pretty.Doc {
  render_block_doc_with(default_ctx(), body)
}

///|
fn render_block_doc_with(ctx : RenderCtx, body : @expr.Block) -> @pretty.Doc {
  line_docs(render_block_docs_with(ctx, body))
}

///|
fn render_func_header_doc_with(
  ctx : RenderCtx,
  func : @expr.Func,
) -> @pretty.Doc {
  let args : Array[@pretty.Doc] = []
  for param in func.params {
    args.push(@pretty.text(format_value_with(ctx, param)))
  }
  if func.vararg {
    args.push(@pretty.text("..."))
  }
  @pretty.concat(@pretty.text("function"), paren_list(args))
}

///|
pub fn render_func_doc(func : @expr.Func) -> @pretty.Doc {
  render_func_doc_with(default_ctx(), func)
}

///|
fn render_func_doc_with(ctx : RenderCtx, func : @expr.Func) -> @pretty.Doc {
  @pretty.concat_all([
    render_func_header_doc_with(ctx, func),
    render_block_inside(ctx, func.body),
    @pretty.hardline(),
    @pretty.text("end"),
  ])
}

///|
pub fn render(program : @expr.Program) -> String {
  render_with(default_ctx(), program)
}

///|
fn render_with(ctx : RenderCtx, program : @expr.Program) -> String {
  @pretty.print(block_docs([render_block_doc_with(ctx, program)]), width=100)
}

///|
pub fn render_named(named : @expr.NamedProgram) -> String {
  render_with({ names: Some(named.names) }, named.program)
}
