///|
fn comma_sep_docs(docs : ArrayView[@pretty.Doc]) -> @pretty.Doc {
  @pretty.join(@pretty.concat(@pretty.text(","), @pretty.line()), docs)
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
fn brace_block(prefix : @pretty.Doc, body : @pretty.Doc) -> @pretty.Doc {
  @pretty.concat_all([
    prefix,
    @pretty.text(" {"),
    indent_block(body),
    @pretty.hardline(),
    @pretty.text("}"),
  ])
}

///|
fn format_label(label : @ssa.Label) -> String {
  "B\{label.id.0}"
}

///|
fn label_doc(label : @ssa.Label) -> @pretty.Doc {
  if label.params.is_empty() {
    @pretty.text(format_label(label))
  } else {
    let param_docs = label.params.map(fn(value) {
      @pretty.text(@ssa_render.format_value(value))
    })
    @pretty.concat(@pretty.text(format_label(label)), paren_list(param_docs))
  }
}

///|
fn render_closure_doc(
  id : @ssa.FuncId,
  program : @structured.Program,
) -> @pretty.Doc {
  let func = program.funcs[id.index]
  @pretty.concat_all([
    render_func_header_doc(func, program),
    @pretty.nest(
      2,
      @pretty.concat(@pretty.hardline(), render_func_body_doc(func, program)),
    ),
    @pretty.hardline(),
    @pretty.text("end"),
  ])
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
fn render_region_doc(
  region : @structured.Region,
  program : @structured.Program,
) -> @pretty.Doc {
  match region {
    Linear(stmts, next) => {
      let docs : Array[@pretty.Doc] = []
      for stmt in stmts {
        docs.push(render_stmt_doc(stmt, program))
      }
      docs.push(render_region_doc(next, program))
      line_docs(docs)
    }
    Return(values, multi) => render_return_doc(values, multi, program)
    If(cond, then_region, else_region, cont) => {
      let docs : Array[@pretty.Doc] = [
        @pretty.concat_all([
          @pretty.text("if "),
          render_expr_doc(cond, program),
          @pretty.text(" {"),
          indent_block(render_region_doc(then_region, program)),
          @pretty.hardline(),
          @pretty.text("} else {"),
          indent_block(render_region_doc(else_region, program)),
          @pretty.hardline(),
          @pretty.text("}"),
        ]),
      ]
      match cont {
        Some((cont_label, cont_region)) =>
          docs.push(
            brace_block(
              @pretty.concat_all([@pretty.text("cont "), label_doc(cont_label)]),
              render_region_doc(cont_region, program),
            ),
          )
        None => ()
      }
      line_docs(docs)
    }
    Loop(header, init_args, body, exit_region) => {
      let init_docs = init_args.map(fn(value) {
        render_expr_doc(value, program)
      })
      let docs : Array[@pretty.Doc] = [
        brace_block(
          @pretty.concat_all([
            @pretty.text("loop "),
            label_doc(header),
            @pretty.text(" init "),
            paren_list(init_docs),
          ]),
          render_region_doc(body, program),
        ),
      ]
      match exit_region {
        Some((exit_label, exit_region)) =>
          docs.push(
            brace_block(
              @pretty.concat_all([@pretty.text("exit "), label_doc(exit_label)]),
              render_region_doc(exit_region, program),
            ),
          )
        None => ()
      }
      line_docs(docs)
    }
    Goto(target) =>
      @pretty.concat_all([@pretty.text("goto "), target_doc(target, program)])
  }
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
  docs.push(render_region_doc(func.body, program))
  block_docs(docs)
}

///|
pub fn render(program : @structured.Program) -> String {
  let main = program.funcs[program.main.index]
  let doc = render_func_body_doc(main, program)
  @pretty.print(block_docs([doc]), width=100)
}
