///|
fn comma_sep_docs(docs : ArrayView[@pretty.Doc]) -> @pretty.Doc {
  @pretty.join(@pretty.concat(@pretty.text(","), @pretty.line()), docs)
}

///|
fn comma_space_sep_docs(docs : ArrayView[@pretty.Doc]) -> @pretty.Doc {
  @pretty.join(@pretty.text(", "), docs)
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
fn line_docs(docs : ArrayView[@pretty.Doc]) -> @pretty.Doc {
  @pretty.join(@pretty.hardline(), docs)
}

///|
fn block_docs(docs : ArrayView[@pretty.Doc]) -> @pretty.Doc {
  @pretty.join(@pretty.concat(@pretty.hardline(), @pretty.hardline()), docs)
}

///|
fn indent_block(doc : @pretty.Doc) -> @pretty.Doc {
  @pretty.nest(2, @pretty.concat(@pretty.hardline(), doc))
}

///|
fn is_empty_doc(doc : @pretty.Doc) -> Bool {
  match doc {
    @pretty.EmptyD => true
    _ => false
  }
}

///|
fn push_doc(docs : Array[@pretty.Doc], doc : @pretty.Doc) -> Unit {
  if !is_empty_doc(doc) {
    docs.push(doc)
  }
}

///|
fn append_docs(docs : Array[@pretty.Doc], more : Array[@pretty.Doc]) -> Unit {
  for doc in more {
    push_doc(docs, doc)
  }
}

///|
fn brace_block(prefix : @pretty.Doc, body : @pretty.Doc) -> @pretty.Doc {
  if is_empty_doc(body) {
    @pretty.concat_all([
      prefix,
      @pretty.text(" {"),
      @pretty.hardline(),
      @pretty.text("}"),
    ])
  } else {
    @pretty.concat_all([
      prefix,
      @pretty.text(" {"),
      indent_block(body),
      @pretty.hardline(),
      @pretty.text("}"),
    ])
  }
}

///|
fn format_label(label : @ssa.Label) -> String {
  "B\{label.id.0}"
}

///|
priv struct TailTarget {
  label : @ssa.Label
  params : Array[@ssa.Var]
  break_on_jump : Bool
}

///|
fn render_closure_doc(
  id : @ssa.FuncId,
  program : @structured.Program,
) -> @pretty.Doc {
  let func = program.funcs[id.index]
  let body = render_func_body_doc(func, program)
  if is_empty_doc(body) {
    @pretty.concat_all([
      render_func_header_doc(func, program),
      @pretty.text(" end"),
    ])
  } else {
    @pretty.concat_all([
      render_func_header_doc(func, program),
      @pretty.nest(2, @pretty.concat(@pretty.hardline(), body)),
      @pretty.hardline(),
      @pretty.text("end"),
    ])
  }
}

///|
fn render_expr_doc(
  expr : @ssa.Expr,
  program : @structured.Program,
) -> @pretty.Doc {
  @ssa_render.render_expr_doc_with(expr, fn(id) {
    render_closure_doc(id, program)
  })
}

///|
fn render_stmt_doc(
  stmt : @ssa.Stmt,
  program : @structured.Program,
) -> @pretty.Doc {
  @ssa_render.render_stmt_doc_with(stmt, fn(id) {
    render_closure_doc(id, program)
  })
}

///|
fn render_multi_doc(
  multi : @ssa.Multi,
  program : @structured.Program,
) -> @pretty.Doc {
  @ssa_render.render_multi_doc_with(multi, fn(id) {
    render_closure_doc(id, program)
  })
}

///|
fn target_doc(
  target : @ssa.Target,
  program : @structured.Program,
) -> @pretty.Doc {
  let @ssa.Target(label, args) = target
  if args.is_empty() {
    @pretty.text(format_label(label))
  } else {
    let arg_docs = args.map(fn(value) { render_expr_doc(value, program) })
    @pretty.concat(@pretty.text(format_label(label)), paren_list(arg_docs))
  }
}

///|
fn render_return_doc(
  values : Array[@ssa.Expr],
  multi : @ssa.Multi?,
  program : @structured.Program,
) -> @pretty.Doc {
  let docs : Array[@pretty.Doc] = []
  for value in values {
    docs.push(render_expr_doc(value, program))
  }
  match multi {
    Some(next) => docs.push(render_multi_doc(next, program))
    None => ()
  }
  if docs.is_empty() {
    @pretty.text("return")
  } else {
    @pretty.concat(
      @pretty.text("return "),
      @pretty.join(@pretty.text(", "), docs),
    )
  }
}

///|
fn var_docs(vars : ArrayView[@ssa.Var]) -> Array[@pretty.Doc] {
  vars.map(fn(value) { @pretty.text(@ssa_render.format_value(value)) })
}

///|
fn expr_docs(
  exprs : ArrayView[@ssa.Expr],
  program : @structured.Program,
) -> Array[@pretty.Doc] {
  exprs.map(fn(expr) { render_expr_doc(expr, program) })
}

///|
fn is_identity_args(params : Array[@ssa.Var], args : Array[@ssa.Expr]) -> Bool {
  guard params.length() == args.length() else { return false }
  for i in 0..<args.length() {
    match args[i] {
      VarE(value) if value == params[i] => ()
      _ => return false
    }
  }
  true
}

///|
fn local_vars_doc(vars : Array[@ssa.Var]) -> @pretty.Doc {
  if vars.is_empty() {
    @pretty.empty()
  } else {
    @pretty.concat_all([
      @pretty.text("local "),
      comma_space_sep_docs(var_docs(vars)),
    ])
  }
}

///|
fn local_vars_init_doc(
  vars : Array[@ssa.Var],
  args : Array[@ssa.Expr],
  program : @structured.Program,
) -> @pretty.Doc {
  if vars.is_empty() {
    @pretty.empty()
  } else if args.is_empty() {
    local_vars_doc(vars)
  } else {
    @pretty.concat_all([
      @pretty.text("local "),
      comma_space_sep_docs(var_docs(vars)),
      @pretty.text(" = "),
      comma_space_sep_docs(expr_docs(args, program)),
    ])
  }
}

///|
fn assignment_doc(
  vars : Array[@ssa.Var],
  args : Array[@ssa.Expr],
  program : @structured.Program,
) -> @pretty.Doc {
  if vars.is_empty() || is_identity_args(vars, args) {
    @pretty.empty()
  } else {
    @pretty.concat_all([
      comma_space_sep_docs(var_docs(vars)),
      @pretty.text(" = "),
      comma_space_sep_docs(expr_docs(args, program)),
    ])
  }
}

///|
fn find_tail_target(
  tail_targets : ArrayView[TailTarget],
  label : @ssa.Label,
) -> TailTarget? {
  for target in tail_targets {
    if target.label == label {
      return Some(target)
    }
  }
  None
}

///|
fn with_tail_target(
  tail_targets : ArrayView[TailTarget],
  target : TailTarget,
) -> Array[TailTarget] {
  let out : Array[TailTarget] = [target]
  for item in tail_targets {
    out.push(item)
  }
  out
}

///|
fn render_goto_doc(
  target : @ssa.Target,
  tail_targets : ArrayView[TailTarget],
  program : @structured.Program,
) -> @pretty.Doc {
  let Target(label, args) = target
  match find_tail_target(tail_targets, label) {
    Some(tail) =>
      if tail.params.length() == args.length() {
        let assign = assignment_doc(tail.params, args, program)
        if tail.break_on_jump {
          if is_empty_doc(assign) {
            @pretty.text("break")
          } else {
            line_docs([assign, @pretty.text("break")])
          }
        } else {
          assign
        }
      } else {
        @pretty.concat_all([@pretty.text("goto "), target_doc(target, program)])
      }
    None =>
      @pretty.concat_all([@pretty.text("goto "), target_doc(target, program)])
  }
}

///|
fn render_if_doc(
  cond : @ssa.Expr,
  then_region : @structured.Region,
  else_region : @structured.Region?,
  branch_targets : ArrayView[TailTarget],
  tail_empty_return : Bool,
  program : @structured.Program,
) -> @pretty.Doc {
  let then_doc = render_region_doc_with(
    then_region, branch_targets, tail_empty_return, program,
  )
  let prefix = @pretty.concat_all([
    @pretty.text("if "),
    render_expr_doc(cond, program),
  ])
  match else_region {
    Some(else_region) => {
      let else_doc = render_region_doc_with(
        else_region, branch_targets, tail_empty_return, program,
      )
      @pretty.concat_all([
        brace_block(prefix, then_doc),
        @pretty.text(" else"),
        brace_block(@pretty.empty(), else_doc),
      ])
    }
    None => brace_block(prefix, then_doc)
  }
}

///|
fn render_structured_if_docs(
  cond : @ssa.Expr,
  then_region : @structured.Region,
  else_region : @structured.Region?,
  cont : (@ssa.Label, @structured.Region),
  tail_targets : ArrayView[TailTarget],
  tail_empty_return : Bool,
  program : @structured.Program,
) -> Array[@pretty.Doc] {
  let docs : Array[@pretty.Doc] = []
  let (cont_label, cont_region) = cont
  push_doc(docs, local_vars_doc(cont_label.params))
  let cont_target = {
    label: cont_label,
    params: cont_label.params,
    break_on_jump: false,
  }
  let branch_targets = with_tail_target(tail_targets, cont_target)
  push_doc(
    docs,
    render_if_doc(
      cond, then_region, else_region, branch_targets, false, program,
    ),
  )
  append_docs(
    docs,
    render_region_docs(cont_region, tail_targets, tail_empty_return, program),
  )
  docs
}

///|
fn is_default_numeric_step(step : @ssa.Expr) -> Bool {
  match step {
    ConstE(Integer(1L)) => true
    _ => false
  }
}

///|
fn loop_prefix_doc(
  shape : @structured.LoopShape,
  program : @structured.Program,
) -> @pretty.Doc {
  match shape {
    UnknownLS => @pretty.text("while true")
    NumericForLS(value, init, limit, step) => {
      let docs = [
        @pretty.text("for "),
        render_expr_doc(VarE(value), program),
        @pretty.text(" = "),
        render_expr_doc(init, program),
        @pretty.text(", "),
        render_expr_doc(limit, program),
      ]
      if !is_default_numeric_step(step) {
        docs.push(@pretty.text(", "))
        docs.push(render_expr_doc(step, program))
      }
      @pretty.concat_all(docs)
    }
    GenericForLS(values, exprs, multi) => {
      let value_docs = values.map(fn(value) {
        render_expr_doc(VarE(value), program)
      })
      let arg_docs : Array[@pretty.Doc] = exprs.map(fn(expr) {
        render_expr_doc(expr, program)
      })
      match multi {
        Some(multi) => arg_docs.push(render_multi_doc(multi, program))
        None => ()
      }
      @pretty.concat_all([
        @pretty.text("for "),
        comma_space_sep_docs(value_docs),
        @pretty.text(" in "),
        comma_space_sep_docs(arg_docs),
      ])
    }
  }
}

///|
fn render_loop_docs(
  header : @ssa.Label,
  init_args : Array[@ssa.Expr],
  shape : @structured.LoopShape,
  body : @structured.Region,
  exit_region : (@ssa.Label, @structured.Region)?,
  tail_targets : ArrayView[TailTarget],
  tail_empty_return : Bool,
  program : @structured.Program,
) -> Array[@pretty.Doc] {
  let docs : Array[@pretty.Doc] = []
  push_doc(docs, local_vars_init_doc(header.params, init_args, program))
  let mut body_targets = with_tail_target(tail_targets, {
    label: header,
    params: header.params,
    break_on_jump: false,
  })
  match exit_region {
    Some((exit_label, exit_body)) => {
      ignore(exit_body)
      push_doc(docs, local_vars_doc(exit_label.params))
      body_targets = with_tail_target(body_targets, {
        label: exit_label,
        params: exit_label.params,
        break_on_jump: true,
      })
    }
    None => ()
  }
  push_doc(
    docs,
    brace_block(
      loop_prefix_doc(shape, program),
      render_region_doc_with(body, body_targets, false, program),
    ),
  )
  match exit_region {
    Some((_, exit_body)) =>
      append_docs(
        docs,
        render_region_docs(exit_body, tail_targets, tail_empty_return, program),
      )
    None => ()
  }
  docs
}

///|
fn render_region_docs(
  region : @structured.Region,
  tail_targets : ArrayView[TailTarget],
  tail_empty_return : Bool,
  program : @structured.Program,
) -> Array[@pretty.Doc] {
  let docs : Array[@pretty.Doc] = []
  match region {
    Linear(stmts, next) => {
      for stmt in stmts {
        push_doc(docs, render_stmt_doc(stmt, program))
      }
      append_docs(
        docs,
        render_region_docs(next, tail_targets, tail_empty_return, program),
      )
    }
    Return([], None) if tail_empty_return => ()
    Return(values, multi) =>
      push_doc(docs, render_return_doc(values, multi, program))
    Branch(cond, then_region, else_region) =>
      push_doc(
        docs,
        render_if_doc(
          cond,
          then_region,
          Some(else_region),
          tail_targets,
          tail_empty_return,
          program,
        ),
      )
    If(cond, then_region, else_region, cont) =>
      append_docs(
        docs,
        render_structured_if_docs(
          cond, then_region, else_region, cont, tail_targets, tail_empty_return,
          program,
        ),
      )
    Loop(header, init_args, shape, body, exit_region) =>
      append_docs(
        docs,
        render_loop_docs(
          header, init_args, shape, body, exit_region, tail_targets, tail_empty_return,
          program,
        ),
      )
    Goto(target) =>
      push_doc(docs, render_goto_doc(target, tail_targets, program))
  }
  docs
}

///|
fn render_region_doc_with(
  region : @structured.Region,
  tail_targets : ArrayView[TailTarget],
  tail_empty_return : Bool,
  program : @structured.Program,
) -> @pretty.Doc {
  line_docs(
    render_region_docs(region, tail_targets, tail_empty_return, program),
  )
}

///|
fn render_func_header_doc(
  func : @structured.Func,
  program : @structured.Program,
) -> @pretty.Doc {
  let args : Array[@pretty.Doc] = []
  for param in func.params {
    args.push(render_expr_doc(VarE(param), program))
  }
  if func.vararg {
    args.push(@pretty.text("..."))
  }
  @pretty.concat_all([@pretty.text("function"), paren_list(args)])
}

///|
fn render_func_body_doc(
  func : @structured.Func,
  program : @structured.Program,
) -> @pretty.Doc {
  let docs : Array[@pretty.Doc] = []
  if func.cells.length() > 0 {
    let cell_docs = func.cells.map(fn(cell) {
      @pretty.text(@ssa_render.format_cell(cell))
    })
    docs.push(
      @pretty.concat_all([@pretty.text("local "), comma_sep_docs(cell_docs)]),
    )
  }
  push_doc(docs, render_region_doc_with(func.body, [], true, program))
  block_docs(docs)
}

///|
pub fn render(program : @structured.Program) -> String {
  let main = program.funcs[program.main.index]
  let doc = render_func_body_doc(main, program)
  @pretty.print(block_docs([doc]), width=100)
}
