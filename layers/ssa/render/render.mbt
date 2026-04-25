///|
fn is_not_generated_identifier(id : StringView) -> Bool {
  match id {
    ['v' | 'c', '0'..='9', ..] => false
    _ => true
  }
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
    return @pretty.text("()")
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
  if docs.length() == 0 {
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
      @pretty.nest(2, @pretty.concat(@pretty.linebreak(), comma_sep_docs(docs))),
      @pretty.linebreak(),
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
pub fn format_cell(cell : @ssa.Cell) -> String {
  if cell.id.0 == -1 {
    "_ENV"
  } else {
    "c\{cell.id.0}"
  }
}

///|
fn format_label(label : @ssa.Label) -> String {
  "B\{label.id.0}"
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
fn logical_op_prec(expr : @ssa.Expr) -> Int {
  match expr {
    @ssa.OrE(_, _) => 1
    @ssa.AndE(_, _) => 2
    _ => 100
  }
}

///|
fn expr_prec(expr : @ssa.Expr) -> Int {
  match expr {
    ConstE(_)
    | VarE(_)
    | CellE(_)
    | CallE(_)
    | TableE(_)
    | ClosureE(_, _)
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
  expr : @ssa.Expr,
  min_prec : Int,
  render_closure : (@ssa.FuncId) -> @pretty.Doc,
) -> @pretty.Doc {
  let doc = render_expr_doc_with(expr, render_closure)
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
fn target_doc_with(
  target : @ssa.Target,
  render_closure : (@ssa.FuncId) -> @pretty.Doc,
) -> @pretty.Doc {
  let @ssa.Target(label, args) = target
  if args.length() == 0 {
    @pretty.text(format_label(label))
  } else {
    let arg_docs = args.map(fn(value) {
      render_expr_doc_with(value, render_closure)
    })
    @pretty.concat(@pretty.text(format_label(label)), paren_list(arg_docs))
  }
}

///|
fn target_doc(target : @ssa.Target, program : @ssa.Program) -> @pretty.Doc {
  target_doc_with(target, fn(id) { render_closure_doc(id, program) })
}

///|
pub fn render_multi_doc_with(
  multi : @ssa.Multi,
  render_closure : (@ssa.FuncId) -> @pretty.Doc,
) -> @pretty.Doc {
  match multi {
    VarargM => @pretty.text("...")
    CallM(call) => render_call_doc_with(call, render_closure)
  }
}

///|
fn render_multi_doc(multi : @ssa.Multi, program : @ssa.Program) -> @pretty.Doc {
  render_multi_doc_with(multi, fn(id) { render_closure_doc(id, program) })
}

///|
fn render_callee_doc_with(
  expr : @ssa.Expr,
  render_closure : (@ssa.FuncId) -> @pretty.Doc,
) -> @pretty.Doc {
  match expr {
    @ssa.ConstE(_)
    | @ssa.VarE(_)
    | @ssa.CellE(_)
    | @ssa.IndexE(_, _)
    | @ssa.CallE(_) => render_expr_doc_with(expr, render_closure)
    _ => @pretty.parens(render_expr_doc_with(expr, render_closure))
  }
}

///|
fn has_closure_arg(args : ArrayView[@ssa.Expr]) -> Bool {
  for arg in args {
    if arg is ClosureE(_, _) {
      return true
    }
  }
  false
}

///|
fn call_paren_list(
  arg_docs : ArrayView[@pretty.Doc],
  args : ArrayView[@ssa.Expr],
) -> @pretty.Doc {
  if has_closure_arg(args) {
    paren_list_with_closure_args(arg_docs)
  } else {
    paren_list(arg_docs)
  }
}

///|
fn render_call_doc_with(
  call : @ssa.Call,
  render_closure : (@ssa.FuncId) -> @pretty.Doc,
) -> @pretty.Doc {
  match call {
    NormalC(callee, args, multi) => {
      let arg_docs : Array[@pretty.Doc] = []
      for arg in args {
        arg_docs.push(render_expr_doc_with(arg, render_closure))
      }
      match multi {
        Some(next) => arg_docs.push(render_multi_doc_with(next, render_closure))
        None => ()
      }
      @pretty.concat(
        render_callee_doc_with(callee, render_closure),
        call_paren_list(arg_docs, args),
      )
    }
    MethodC(target, method_name, args, multi) => {
      let arg_docs : Array[@pretty.Doc] = []
      for arg in args {
        arg_docs.push(render_expr_doc_with(arg, render_closure))
      }
      match multi {
        Some(next) => arg_docs.push(render_multi_doc_with(next, render_closure))
        None => ()
      }
      @pretty.concat(
        @pretty.concat_all([
          render_callee_doc_with(target, render_closure),
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
  init : @ssa.TableInit,
  render_closure : (@ssa.FuncId) -> @pretty.Doc,
) -> @pretty.Doc {
  match init {
    EmptyTI => @pretty.text("{}")
    ArrayTI(items, multi) => {
      let docs = items.map(fn(item) {
        render_expr_doc_with(item, render_closure)
      })
      match multi {
        Some(multi) => docs.push(render_multi_doc_with(multi, render_closure))
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
                render_expr_doc_with(value, render_closure),
              ]),
            )
          _ =>
            docs.push(
              @pretty.concat_all([
                @pretty.text("["),
                render_expr_doc_with(key, render_closure),
                @pretty.text("] = "),
                render_expr_doc_with(value, render_closure),
              ]),
            )
        }
      }
      brace_list(docs)
    }
  }
}

///|
pub fn render_expr_doc_with(
  expr : @ssa.Expr,
  render_closure : (@ssa.FuncId) -> @pretty.Doc,
) -> @pretty.Doc {
  match expr {
    ConstE(constant) => @pretty.text(render_constant(constant))
    VarE(value) => @pretty.text(format_value(value))
    CellE(cell) => @pretty.text(format_cell(cell))
    NumericForCheckE(ctrl, limit, step) =>
      @pretty.concat(
        @pretty.text("numeric_for_check"),
        paren_list([
          render_expr_doc_with(ctrl, render_closure),
          render_expr_doc_with(limit, render_closure),
          render_expr_doc_with(step, render_closure),
        ]),
      )
    IndexE(target, ConstE(AsciiString(id, is_valid_identifier=true))) =>
      if target is CellE(c) && c.is_env() && is_not_generated_identifier(id) {
        @pretty.text(id)
      } else {
        @pretty.concat_all([
          render_callee_doc_with(target, render_closure),
          @pretty.text("."),
          @pretty.text(id),
        ])
      }
    IndexE(target, key) =>
      @pretty.concat(
        render_callee_doc_with(target, render_closure),
        @pretty.brackets(render_expr_doc_with(key, render_closure)),
      )
    TableE(init) => render_table_init_doc_with(init, render_closure)
    UnaryE(op, inner) =>
      @pretty.concat(
        @pretty.text(unary_op_text(op)),
        render_expr_ctx_with(inner, 11, render_closure),
      )
    BinaryE(op, lhs, rhs) => {
      let p = binary_op_prec(op)
      let right_assoc = binary_op_right_assoc(op)
      let lhs_min = if right_assoc { p + 1 } else { p }
      let rhs_min = if right_assoc { p } else { p + 1 }
      @pretty.concat_all([
        render_expr_ctx_with(lhs, lhs_min, render_closure),
        @pretty.space(),
        @pretty.text(binary_op_text(op)),
        @pretty.space(),
        render_expr_ctx_with(rhs, rhs_min, render_closure),
      ])
    }
    AndE(lhs, rhs) => {
      let lhs_min = if logical_op_prec(rhs) == 2 { 3 } else { 2 }
      @pretty.concat_all([
        render_expr_ctx_with(lhs, lhs_min, render_closure),
        @pretty.space(),
        @pretty.text("and"),
        @pretty.space(),
        render_expr_ctx_with(rhs, 2, render_closure),
      ])
    }
    OrE(lhs, rhs) =>
      @pretty.concat_all([
        render_expr_ctx_with(lhs, 1, render_closure),
        @pretty.space(),
        @pretty.text("or"),
        @pretty.space(),
        render_expr_ctx_with(rhs, 1, render_closure),
      ])
    CallE(call) => render_call_doc_with(call, render_closure)
    ClosureE(id, _capture_vars) => render_closure(id)
  }
}

///|
pub fn render_expr_doc(expr : @ssa.Expr, program : @ssa.Program) -> @pretty.Doc {
  render_expr_doc_with(expr, fn(id) { render_closure_doc(id, program) })
}

///|
fn params_suffix_doc(params : Array[@ssa.Var]) -> @pretty.Doc {
  if params.length() == 0 {
    @pretty.empty()
  } else {
    let docs = params.map(fn(value) { @pretty.text(format_value(value)) })
    paren_list(docs)
  }
}

///|
pub fn render_stmt_doc_with(
  stmt : @ssa.Stmt,
  render_closure : (@ssa.FuncId) -> @pretty.Doc,
) -> @pretty.Doc {
  match stmt {
    BindS(value, expr) =>
      @pretty.concat_all([
        @pretty.text("local "),
        @pretty.text(format_value(value)),
        @pretty.text(" = "),
        render_expr_doc_with(expr, render_closure),
      ])
    StoreCellS(cell, expr) =>
      @pretty.concat_all([
        @pretty.text(format_cell(cell)),
        @pretty.text(" = "),
        render_expr_doc_with(expr, render_closure),
      ])
    SetIndexS(target, ConstE(AsciiString(id, is_valid_identifier=true)), value) =>
      if target is CellE(c) && c.is_env() && is_not_generated_identifier(id) {
        @pretty.text(id)
      } else {
        @pretty.concat_all([
          render_expr_doc_with(target, render_closure),
          @pretty.text("."),
          @pretty.text(id),
          @pretty.text(" = "),
          render_expr_doc_with(value, render_closure),
        ])
      }
    SetIndexS(target, key, value) =>
      @pretty.concat_all([
        render_expr_doc_with(target, render_closure),
        @pretty.brackets(render_expr_doc_with(key, render_closure)),
        @pretty.text(" = "),
        render_expr_doc_with(value, render_closure),
      ])
    BindMultiS(values, multi) =>
      if values.length() == 0 {
        render_multi_doc_with(multi, render_closure)
      } else {
        let lhs_docs = values.map(fn(value) {
          @pretty.text(format_value(value))
        })
        @pretty.concat_all([
          @pretty.text("local "),
          @pretty.nest(2, comma_sep_group(lhs_docs)),
          @pretty.text(" = "),
          render_multi_doc_with(multi, render_closure),
        ])
      }
    SetListS(target, index, values, multi) => {
      let value_docs = values.map(fn(expr) {
        render_expr_doc_with(expr, render_closure)
      })
      let tail_doc = match multi {
        Some(next) => render_multi_doc_with(next, render_closure)
        None => @pretty.text("nil")
      }
      @pretty.concat_all([
        @pretty.text("__setlist"),
        paren_list([
          render_expr_doc_with(target, render_closure),
          render_expr_doc_with(index, render_closure),
          brace_list(value_docs),
          tail_doc,
        ]),
      ])
    }
  }
}

///|
pub fn render_stmt_doc(stmt : @ssa.Stmt, program : @ssa.Program) -> @pretty.Doc {
  render_stmt_doc_with(stmt, fn(id) { render_closure_doc(id, program) })
}

///|
fn render_term_doc(term : @ssa.Term, program : @ssa.Program) -> @pretty.Doc {
  match term {
    JumpT(target) =>
      @pretty.concat(@pretty.text("goto "), target_doc(target, program))
    CondT(cond, true_target, false_target) =>
      @pretty.concat_all([
        @pretty.concat(
          @pretty.text("if "),
          @pretty.concat(render_expr_doc(cond, program), @pretty.text(" then")),
        ),
        @pretty.nest(
          2,
          @pretty.concat(
            @pretty.hardline(),
            @pretty.concat(
              @pretty.text("goto "),
              target_doc(true_target, program),
            ),
          ),
        ),
        @pretty.hardline(),
        @pretty.text("else"),
        @pretty.nest(
          2,
          @pretty.concat(
            @pretty.hardline(),
            @pretty.concat(
              @pretty.text("goto "),
              target_doc(false_target, program),
            ),
          ),
        ),
        @pretty.hardline(),
        @pretty.text("end"),
      ])
    ReturnT(values, multi) => {
      let docs : Array[@pretty.Doc] = []
      for value in values {
        docs.push(render_expr_doc(value, program))
      }
      match multi {
        Some(next) => docs.push(render_multi_doc(next, program))
        None => ()
      }
      if docs.length() == 0 {
        @pretty.text("return")
      } else {
        @pretty.concat(
          @pretty.text("return "),
          @pretty.nest(2, comma_sep_group(docs)),
        )
      }
    }
  }
}

///|
fn render_block_doc(
  block : @ssa.Block,
  label : @ssa.Label,
  program : @ssa.Program,
) -> @pretty.Doc {
  let lines : Array[@pretty.Doc] = []
  let label_doc = @pretty.concat_all([
    @pretty.text("::"),
    @pretty.text(format_label(label)),
    params_suffix_doc(label.params),
    @pretty.text("::"),
  ])
  lines.push(label_doc)
  for stmt in block.stmts {
    lines.push(render_stmt_doc(stmt, program))
  }
  lines.push(render_term_doc(block.term, program))
  line_docs(lines)
}

///|
fn render_func_body_doc(
  func : @ssa.Func,
  program : @ssa.Program,
) -> @pretty.Doc {
  let docs : Array[@pretty.Doc] = []
  if func.cells.length() > 0 {
    let cell_docs = func.cells.map(fn(cell) { @pretty.text(format_cell(cell)) })
    docs.push(
      @pretty.concat_all([@pretty.text("local "), comma_sep_docs(cell_docs)]),
    )
  }
  for label, block in func.blocks {
    docs.push(render_block_doc(block, label, program))
  }
  block_docs(docs)
}

///|
fn render_func_header_doc(func : @ssa.Func) -> @pretty.Doc {
  let args : Array[@pretty.Doc] = []
  for param in func.params {
    args.push(@pretty.text(format_value(param)))
  }
  if func.vararg {
    args.push(@pretty.text("..."))
  }
  @pretty.concat_all([@pretty.text("function"), paren_list(args)])
}

///|
fn render_closure_doc(id : @ssa.FuncId, program : @ssa.Program) -> @pretty.Doc {
  let func = program.funcs[id.index]
  @pretty.concat_all([
    render_func_header_doc(func),
    @pretty.nest(
      2,
      @pretty.concat(@pretty.hardline(), render_func_body_doc(func, program)),
    ),
    @pretty.hardline(),
    @pretty.text("end"),
  ])
}

///|
pub fn render(program : @ssa.Program) -> String {
  let main = program.funcs[program.main.index]
  let body_doc = render_func_body_doc(main, program)
  let doc = block_docs([body_doc])
  @pretty.print(doc, width=100)
}
