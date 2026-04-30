///|
priv enum TransferKind {
  MergeK
  ContinueK
  BreakK
}

///|
priv struct Transfer {
  label : @ssa.Label
  kind : TransferKind
  loop_depth : Int
}

///|
priv struct LowerCtx {
  program : @structured.Program
  param_cells : Map[@ssa.Var, @ssa.Cell]
  declared_cells : Map[@ssa.Cell, Bool]
  transfers : Array[Transfer]
  current_continue : @ssa.Label?
  loop_depth : Int
}

///|
fn cell_of_var(value : @ssa.Var) -> @ssa.Cell {
  { id: value.id }
}

///|
fn collect_label_params(
  cells : Map[@ssa.Var, @ssa.Cell],
  label : @ssa.Label,
) -> Unit {
  for param in label.params {
    cells[param] = cell_of_var(param)
  }
}

///|
fn collect_target_params(
  cells : Map[@ssa.Var, @ssa.Cell],
  target : @ssa.Target,
) -> Unit {
  let @ssa.Target(label, _) = target
  collect_label_params(cells, label)
}

///|
fn collect_region_params(
  cells : Map[@ssa.Var, @ssa.Cell],
  region : @structured.Region,
) -> Unit {
  match region {
    Linear(_, next) => collect_region_params(cells, next)
    Return(_, _) => ()
    Branch(_, then_region, else_region) => {
      collect_region_params(cells, then_region)
      collect_region_params(cells, else_region)
    }
    If(_, then_region, else_region, cont) => {
      collect_region_params(cells, then_region)
      match else_region {
        Some(region) => collect_region_params(cells, region)
        None => ()
      }
      let (label, cont_region) = cont
      collect_label_params(cells, label)
      collect_region_params(cells, cont_region)
    }
    Loop(header, _, _, body, exit_region) => {
      collect_label_params(cells, header)
      collect_region_params(cells, body)
      match exit_region {
        Some((label, region)) => {
          collect_label_params(cells, label)
          collect_region_params(cells, region)
        }
        None => ()
      }
    }
    Goto(target) => collect_target_params(cells, target)
  }
}

///|
fn with_transfer(
  ctx : LowerCtx,
  label : @ssa.Label,
  kind : TransferKind,
) -> LowerCtx {
  {
    ..ctx,
    transfers: [
      Transfer::{ label, kind, loop_depth: ctx.loop_depth },
      ..ctx.transfers,
    ],
  }
}

///|
fn find_transfer(ctx : LowerCtx, label : @ssa.Label) -> Transfer? {
  for transfer in ctx.transfers {
    if transfer.label == label {
      return Some(transfer)
    }
  }
  None
}

///|
fn lower_multi(ctx : LowerCtx, multi : @ssa.Multi) -> @expr.Multi {
  match multi {
    VarargM => @expr.VarargM
    CallM(call) => @expr.CallM(lower_call(ctx, call))
  }
}

///|
fn lower_call(ctx : LowerCtx, call : @ssa.Call) -> @expr.Call {
  match call {
    NormalC(callee, args, multi) =>
      @expr.NormalC(
        lower_expr(ctx, callee),
        args.map(fn(arg) { lower_expr(ctx, arg) }),
        multi.map(fn(next) { lower_multi(ctx, next) }),
      )
    MethodC(target, method_name, args, multi) =>
      @expr.MethodC(
        lower_expr(ctx, target),
        method_name,
        args.map(fn(arg) { lower_expr(ctx, arg) }),
        multi.map(fn(next) { lower_multi(ctx, next) }),
      )
  }
}

///|
fn lower_table_init(ctx : LowerCtx, init : @ssa.TableInit) -> @expr.TableInit {
  match init {
    EmptyTI => @expr.EmptyTI
    ArrayTI(items, multi) =>
      @expr.ArrayTI(
        items.map(fn(item) { lower_expr(ctx, item) }),
        multi.map(fn(next) { lower_multi(ctx, next) }),
      )
    TableTI(fields) =>
      @expr.TableTI(
        fields.map(fn(field) {
          let (key, value) = field
          (lower_expr(ctx, key), lower_expr(ctx, value))
        }),
      )
  }
}

///|
fn lower_expr(ctx : LowerCtx, expr : @ssa.Expr) -> @expr.Expr {
  match expr {
    ConstE(value) => @expr.ConstE(value)
    VarE(value) =>
      match ctx.param_cells.get(value) {
        Some(cell) => @expr.CellE(cell)
        None => @expr.VarE(value)
      }
    CellE(cell) => @expr.CellE(cell)
    NumericForCheckE(ctrl, limit, step) =>
      @expr.NumericForCheckE(
        lower_expr(ctx, ctrl),
        lower_expr(ctx, limit),
        lower_expr(ctx, step),
      )
    IndexE(target, key) =>
      @expr.IndexE(lower_expr(ctx, target), lower_expr(ctx, key))
    TableE(init) => @expr.TableE(lower_table_init(ctx, init))
    UnaryE(op, inner) => @expr.UnaryE(op, lower_expr(ctx, inner))
    BinaryE(op, lhs, rhs) =>
      @expr.BinaryE(op, lower_expr(ctx, lhs), lower_expr(ctx, rhs))
    AndE(lhs, rhs) => @expr.AndE(lower_expr(ctx, lhs), lower_expr(ctx, rhs))
    OrE(lhs, rhs) => @expr.OrE(lower_expr(ctx, lhs), lower_expr(ctx, rhs))
    CallE(call) => @expr.CallE(lower_call(ctx, call))
    ClosureE(func, _) =>
      @expr.ClosureE(lower_func(ctx.program, func, parent_ctx=ctx))
  }
}

///|
fn is_zero_expr(expr : @expr.Expr) -> Bool {
  match expr {
    ConstE(Integer(0L)) => true
    _ => false
  }
}

///|
fn expr_with_offset(expr : @expr.Expr, offset : Int) -> @expr.Expr {
  if offset == 0 {
    expr
  } else {
    match expr {
      ConstE(Integer(value)) => @expr.ConstE(Integer(value + offset.to_int64()))
      _ => @expr.BinaryE(Add, expr, @expr.ConstE(Integer(offset.to_int64())))
    }
  }
}

///|
fn lower_setlist(
  ctx : LowerCtx,
  target : @ssa.Expr,
  index : @ssa.Expr,
  values : Array[@ssa.Expr],
  multi : @ssa.Multi?,
) -> @expr.Block {
  let target = lower_expr(ctx, target)
  let index = lower_expr(ctx, index)
  let out : @expr.Block = []
  for i in 0..<values.length() {
    out.push(
      @expr.SetIndexS(
        target,
        expr_with_offset(index, i + 1),
        lower_expr(ctx, values[i]),
      ),
    )
  }
  match multi {
    Some(next) => {
      let key : @ssa.Var = { id: ctx.program._id_gen.next() }
      let value : @ssa.Var = { id: ctx.program._id_gen.next() }
      let iter_expr = @expr.CallE(
        @expr.NormalC(
          @expr.IndexE(
            @expr.CellE(@ssa.Cell::env()),
            @expr.ConstE(AsciiString("ipairs", is_valid_identifier=true)),
          ),
          [@expr.TableE(@expr.ArrayTI([], Some(lower_multi(ctx, next))))],
          None,
        ),
      )
      out.push(
        @expr.GenericForS([key, value], [iter_expr], None, [
          @expr.SetIndexS(
            target,
            expr_with_offset(@expr.VarE(key), values.length()),
            @expr.VarE(value),
          ),
        ]),
      )
    }
    None => ()
  }
  out
}

///|
fn lower_stmt(ctx : LowerCtx, stmt : @ssa.Stmt) -> @expr.Block {
  match stmt {
    BindS(value, expr) =>
      match ctx.param_cells.get(value) {
        Some(cell) => [@expr.ParallelAssignS([cell], [lower_expr(ctx, expr)])]
        None => [@expr.BindS(value, lower_expr(ctx, expr))]
      }
    StoreCellS(cell, expr) =>
      [@expr.ParallelAssignS([cell], [lower_expr(ctx, expr)])]
    SetIndexS(target, key, value) =>
      [
        @expr.SetIndexS(
          lower_expr(ctx, target),
          lower_expr(ctx, key),
          lower_expr(ctx, value),
        ),
      ]
    BindMultiS(values, multi) =>
      [@expr.BindMultiS(values, lower_multi(ctx, multi))]
    SetListS(target, index, values, multi) => {
      let lowered_index = lower_expr(ctx, index)
      if is_zero_expr(lowered_index) {
        lower_setlist(ctx, target, index, values, multi)
      } else {
        [
          @expr.SetListS(
            lower_expr(ctx, target),
            lowered_index,
            values.map(fn(value) { lower_expr(ctx, value) }),
            multi.map(fn(next) { lower_multi(ctx, next) }),
          ),
        ]
      }
    }
  }
}

///|
fn append_all(target : Array[@expr.Stmt], source : Array[@expr.Stmt]) -> Unit {
  for stmt in source {
    target.push(stmt)
  }
}

///|
fn local_stmt_for_label(ctx : LowerCtx, label : @ssa.Label) -> @expr.Stmt? {
  let cells : Array[@ssa.Cell] = []
  for param in label.params {
    let cell = ctx.param_cells[param]
    if ctx.declared_cells.get(cell) != Some(true) {
      ctx.declared_cells[cell] = true
      cells.push(cell)
    }
  }
  if cells.is_empty() {
    None
  } else {
    Some(@expr.LocalS(cells, []))
  }
}

///|
fn same_cell_expr(expr : @expr.Expr, cell : @ssa.Cell) -> Bool {
  match expr {
    CellE(other) => other == cell
    _ => false
  }
}

///|
fn materialize_target(
  ctx : LowerCtx,
  label : @ssa.Label,
  args : Array[@ssa.Expr],
) -> @expr.Block {
  guard label.params.length() == args.length() else { panic() }
  let cells : Array[@ssa.Cell] = []
  let values : Array[@expr.Expr] = []
  for i in 0..<args.length() {
    let cell = ctx.param_cells[label.params[i]]
    let value = lower_expr(ctx, args[i])
    if !same_cell_expr(value, cell) {
      cells.push(cell)
      values.push(value)
    }
  }
  if cells.is_empty() {
    []
  } else {
    [@expr.ParallelAssignS(cells, values)]
  }
}

///|
fn materialize_loop_exit_params(
  ctx : LowerCtx,
  header : @ssa.Label,
  exit_label : @ssa.Label,
) -> @expr.Block {
  guard header.params.length() == exit_label.params.length() else { return [] }
  let args = header.params.map(fn(param) { @ssa.VarE(param) })
  materialize_target(ctx, exit_label, args)
}

///|
fn is_plain_loop_break(ctx : LowerCtx, region : @structured.Region) -> Bool {
  match region {
    Goto(@ssa.Target(label, args)) => {
      guard args.is_empty() && label.params.is_empty() else { return false }
      match find_transfer(ctx, label) {
        Some({ kind: BreakK, .. }) => true
        Some({ kind: MergeK, loop_depth, .. }) => loop_depth < ctx.loop_depth
        _ => false
      }
    }
    _ => false
  }
}

///|
fn lower_pretest_loop_body(
  ctx : LowerCtx,
  body : @structured.Region,
) -> (@expr.Expr, @expr.Block)? {
  match body {
    Branch(cond, then_region, else_region) =>
      if is_plain_loop_break(ctx, then_region) {
        Some(
          (
            @expr.UnaryE(Not, lower_expr(ctx, cond)),
            lower_region(ctx, else_region),
          ),
        )
      } else if is_plain_loop_break(ctx, else_region) {
        Some((lower_expr(ctx, cond), lower_region(ctx, then_region)))
      } else {
        None
      }
    _ => None
  }
}

///|
fn lower_goto(ctx : LowerCtx, target : @ssa.Target) -> @expr.Block {
  let @ssa.Target(label, args) = target
  let stmts = materialize_target(ctx, label, args)
  match find_transfer(ctx, label) {
    Some({ kind: MergeK, loop_depth, .. }) =>
      if loop_depth < ctx.loop_depth {
        [..stmts, @expr.BreakS]
      } else {
        stmts
      }
    Some({ kind: ContinueK, .. }) =>
      if ctx.current_continue == Some(label) {
        stmts
      } else {
        [..stmts, @expr.BreakS]
      }
    Some({ kind: BreakK, .. }) => [..stmts, @expr.BreakS]
    None => panic()
  }
}

///|
fn region_targets_label(
  region : @structured.Region,
  label : @ssa.Label,
) -> Bool {
  match region {
    Linear(_, next) => region_targets_label(next, label)
    Return(_, _) => false
    Branch(_, then_region, else_region) =>
      region_targets_label(then_region, label) ||
      region_targets_label(else_region, label)
    If(_, then_region, else_region, cont) => {
      if region_targets_label(then_region, label) {
        return true
      }
      match else_region {
        Some(region) => if region_targets_label(region, label) { return true }
        None => ()
      }
      let (cont_label, cont_region) = cont
      cont_label == label || region_targets_label(cont_region, label)
    }
    Loop(header, _, _, body, exit_region) => {
      if header == label || region_targets_label(body, label) {
        return true
      }
      match exit_region {
        Some((exit_label, region)) =>
          exit_label == label || region_targets_label(region, label)
        None => false
      }
    }
    Goto(@ssa.Target(target, _)) => target == label
  }
}

///|
fn region_is_abrupt_exit(region : @structured.Region) -> Bool {
  match region {
    Linear(_, next) => region_is_abrupt_exit(next)
    Return(_, _) => true
    Branch(_, then_region, else_region) =>
      region_is_abrupt_exit(then_region) && region_is_abrupt_exit(else_region)
    If(_, then_region, else_region, cont) => {
      if !region_is_abrupt_exit(then_region) {
        return false
      }
      match else_region {
        Some(region) => if !region_is_abrupt_exit(region) { return false }
        None => return false
      }
      let (_, cont_region) = cont
      region_is_abrupt_exit(cont_region)
    }
    Loop(_, _, _, body, None) => region_is_abrupt_exit(body)
    Loop(_, _, _, body, Some((_, exit_region))) =>
      region_is_abrupt_exit(body) && region_is_abrupt_exit(exit_region)
    Goto(_) => false
  }
}

///|
fn region_can_fall_through(region : @structured.Region) -> Bool {
  match region {
    Linear(_, next) => region_can_fall_through(next)
    Return(_, _) => false
    Branch(_, then_region, else_region) =>
      region_can_fall_through(then_region) ||
      region_can_fall_through(else_region)
    If(_, then_region, else_region, cont) => {
      let (cont_label, cont_region) = cont
      guard region_can_fall_through(cont_region) else { return false }
      if region_can_fall_through(then_region) ||
        region_targets_label(then_region, cont_label) {
        return true
      }
      match else_region {
        Some(region) =>
          region_can_fall_through(region) ||
          region_targets_label(region, cont_label)
        None => true
      }
    }
    // Loops without an explicit exit continuation can still finish naturally
    // (for example, a generic-for with zero iterations) and then fall through
    // to the enclosing region.
    Loop(_, _, _, _, None) => true
    Loop(_, _, _, _, Some((_, exit_region))) =>
      region_can_fall_through(exit_region)
    Goto(_) => false
  }
}

///|
fn lower_unknown_loop(
  ctx : LowerCtx,
  header : @ssa.Label,
  init_args : Array[@ssa.Expr],
  body : @structured.Region,
  exit_region : (@ssa.Label, @structured.Region)?,
) -> @expr.Block {
  let out : @expr.Block = []
  match local_stmt_for_label(ctx, header) {
    Some(stmt) => out.push(stmt)
    None => ()
  }
  append_all(out, materialize_target(ctx, header, init_args))
  let mut body_ctx = {
    ..with_transfer(ctx, header, ContinueK),
    current_continue: Some(header),
    loop_depth: ctx.loop_depth + 1,
  }
  match exit_region {
    Some((exit_label, _)) => {
      match local_stmt_for_label(ctx, exit_label) {
        Some(stmt) => out.push(stmt)
        None => ()
      }
      body_ctx = with_transfer(body_ctx, exit_label, BreakK)
    }
    None => ()
  }
  match lower_pretest_loop_body(body_ctx, body) {
    Some((cond, body)) => out.push(@expr.WhileS(cond, body))
    None =>
      out.push(
        @expr.WhileS(@expr.ConstE(Boolean(true)), lower_region(body_ctx, body)),
      )
  }
  match exit_region {
    Some((exit_label, region)) => {
      append_all(out, materialize_loop_exit_params(ctx, header, exit_label))
      append_all(out, lower_region(ctx, region))
    }
    None => ()
  }
  out
}

///|
fn lower_numeric_for_loop(
  ctx : LowerCtx,
  header : @ssa.Label,
  init_args : Array[@ssa.Expr],
  value : @ssa.Var,
  start : @ssa.Expr,
  limit : @ssa.Expr,
  step : @ssa.Expr,
  body : @structured.Region,
  exit_region : (@ssa.Label, @structured.Region)?,
) -> @expr.Block {
  let out : @expr.Block = []
  match local_stmt_for_label(ctx, header) {
    Some(stmt) => out.push(stmt)
    None => ()
  }
  append_all(out, materialize_target(ctx, header, init_args))
  let mut body_ctx = {
    ..with_transfer(ctx, header, ContinueK),
    current_continue: Some(header),
    loop_depth: ctx.loop_depth + 1,
  }
  match exit_region {
    Some((exit_label, _)) => {
      match local_stmt_for_label(ctx, exit_label) {
        Some(stmt) => out.push(stmt)
        None => ()
      }
      body_ctx = with_transfer(body_ctx, exit_label, BreakK)
    }
    None => ()
  }
  out.push(
    @expr.NumericForS(
      value,
      lower_expr(ctx, start),
      lower_expr(ctx, limit),
      Some(lower_expr(ctx, step)),
      lower_region(body_ctx, body),
    ),
  )
  match exit_region {
    Some((exit_label, region)) => {
      append_all(out, materialize_loop_exit_params(ctx, header, exit_label))
      append_all(out, lower_region(ctx, region))
    }
    None => ()
  }
  out
}

///|
fn lower_generic_for_loop(
  ctx : LowerCtx,
  header : @ssa.Label,
  init_args : Array[@ssa.Expr],
  vars : Array[@ssa.Var],
  exprs : Array[@ssa.Expr],
  multi : @ssa.Multi?,
  body : @structured.Region,
  exit_region : (@ssa.Label, @structured.Region)?,
) -> @expr.Block {
  let out : @expr.Block = []
  match local_stmt_for_label(ctx, header) {
    Some(stmt) => out.push(stmt)
    None => ()
  }
  append_all(out, materialize_target(ctx, header, init_args))
  let mut body_ctx = {
    ..with_transfer(ctx, header, ContinueK),
    current_continue: Some(header),
    loop_depth: ctx.loop_depth + 1,
  }
  match exit_region {
    Some((exit_label, _)) => {
      match local_stmt_for_label(ctx, exit_label) {
        Some(stmt) => out.push(stmt)
        None => ()
      }
      body_ctx = with_transfer(body_ctx, exit_label, BreakK)
    }
    None => ()
  }
  let iterators = exprs.map(fn(expr) { lower_expr(ctx, expr) })
  out.push(
    @expr.GenericForS(
      vars,
      iterators,
      multi.map(fn(next) { lower_multi(ctx, next) }),
      lower_region(body_ctx, body),
    ),
  )
  match exit_region {
    Some((exit_label, region)) => {
      append_all(out, materialize_loop_exit_params(ctx, header, exit_label))
      append_all(out, lower_region(ctx, region))
    }
    None => ()
  }
  out
}

///|
fn lower_region(ctx : LowerCtx, region : @structured.Region) -> @expr.Block {
  match region {
    Linear(stmts, next) => {
      let out : @expr.Block = []
      for stmt in stmts {
        append_all(out, lower_stmt(ctx, stmt))
      }
      append_all(out, lower_region(ctx, next))
      out
    }
    Return(values, multi) =>
      [
        @expr.ReturnS(
          values.map(fn(value) { lower_expr(ctx, value) }),
          multi.map(fn(next) { lower_multi(ctx, next) }),
        ),
      ]
    Branch(cond, then_region, else_region) =>
      [
        @expr.IfS(
          [(lower_expr(ctx, cond), lower_region(ctx, then_region))],
          Some(lower_region(ctx, else_region)),
        ),
      ]
    If(cond, then_region, else_region, cont) => {
      let out : @expr.Block = []
      let (label, cont_region) = cont
      let branch_ctx = with_transfer(ctx, label, MergeK)
      if else_region is None &&
        label.params.is_empty() &&
        region_is_abrupt_exit(cont_region) &&
        !region_can_fall_through(then_region) &&
        !region_targets_label(then_region, label) {
        out.push(
          @expr.IfS(
            [
              (
                @expr.UnaryE(Not, lower_expr(ctx, cond)),
                lower_region(ctx, cont_region),
              ),
            ],
            None,
          ),
        )
        append_all(out, lower_region(branch_ctx, then_region))
        return out
      }
      match local_stmt_for_label(ctx, label) {
        Some(stmt) => out.push(stmt)
        None => ()
      }
      out.push(
        @expr.IfS(
          [(lower_expr(ctx, cond), lower_region(branch_ctx, then_region))],
          else_region.map(fn(region) { lower_region(branch_ctx, region) }),
        ),
      )
      append_all(out, lower_region(ctx, cont_region))
      out
    }
    Loop(header, init_args, shape, body, exit_region) =>
      match shape {
        UnknownLS =>
          lower_unknown_loop(ctx, header, init_args, body, exit_region)
        NumericForLS(value, start, limit, step) =>
          lower_numeric_for_loop(
            ctx, header, init_args, value, start, limit, step, body, exit_region,
          )
        GenericForLS(vars, exprs, multi) =>
          lower_generic_for_loop(
            ctx, header, init_args, vars, exprs, multi, body, exit_region,
          )
      }
    Goto(target) => lower_goto(ctx, target)
  }
}

///|
fn lower_func(
  program : @structured.Program,
  id : @ssa.FuncId,
  parent_ctx? : LowerCtx,
) -> @expr.Func {
  let func = program.funcs[id.index]
  let param_cells : Map[@ssa.Var, @ssa.Cell] = {}
  match parent_ctx {
    Some(ctx) =>
      for entry in ctx.param_cells {
        let (value, cell) = entry
        param_cells[value] = cell
      }
    None => ()
  }
  collect_region_params(param_cells, func.body)
  let declared_cells : Map[@ssa.Cell, Bool] = {}
  let ctx : LowerCtx = {
    program,
    param_cells,
    declared_cells,
    transfers: [],
    current_continue: None,
    loop_depth: 0,
  }
  let body : @expr.Block = []
  if !func.cells.is_empty() {
    body.push(@expr.LocalS(func.cells, []))
    for cell in func.cells {
      declared_cells[cell] = true
    }
  }
  append_all(body, lower_region(ctx, func.body))
  { params: func.params, vararg: func.vararg, body }
}

///|
pub fn from_program(program : @structured.Program) -> @expr.Program {
  lower_func(program, program.main).body
}
