///|
enum PlaceStorage {
  VarPS
  CellPS(Cell)
} derive(Debug)

///|
enum Binding {
  VarB(Var)
  CellB(Cell)
} derive(Debug)

///|
struct ScanSummary {
  tracked_places : Array[@canonical_cfg.Local]
  def_blocks : Map[@canonical_cfg.Local, Array[@canonical_cfg.Label]]
  block_defs : Map[@canonical_cfg.Label, Array[@canonical_cfg.Local]]
  upward_uses : Map[@canonical_cfg.Label, Array[@canonical_cfg.Local]]
} derive(Debug)

///|
fn contains_cfg_label(
  items : Array[@canonical_cfg.Label],
  target : @canonical_cfg.Label,
) -> Bool {
  let mut found = false
  for item in items {
    if item == target {
      found = true
    }
  }
  found
}

///|
fn push_unique_cfg_label(
  items : Array[@canonical_cfg.Label],
  target : @canonical_cfg.Label,
) -> Unit {
  if !contains_cfg_label(items, target) {
    items.push(target)
  }
}

///|
fn push_unique_place(
  items : Array[@canonical_cfg.Local],
  target : @canonical_cfg.Local,
) -> Unit {
  if !contains_place(items, target) {
    items.push(target)
  }
}

///|
fn ssa_func_id(id : @canonical_cfg.FuncId) -> FuncId {
  { index: id.index }
}

///|
fn ssa_label(plans : ProgramPlan, label : @canonical_cfg.Label) -> Label {
  match plans.funcs[label.func.index].labels.get(label) {
    Some(label) => label
    None => panic()
  }
}

///|
fn resolve_storage(
  plans : ProgramPlan,
  place : @canonical_cfg.Local,
) -> PlaceStorage {
  if place.is_env() {
    CellPS(Cell::env())
  } else {
    let owner = plans.funcs[place.func.index]
    match owner.captures.places.get(place) {
      Some(CellCapture) =>
        match owner.cell_map.get(place) {
          Some(cell) => CellPS(cell)
          None => panic()
        }
      _ => VarPS
    }
  }
}

///|
fn expr_use_places(
  program : @canonical_cfg.Program,
  plans : ProgramPlan,
  expr : @canonical_cfg.Expr,
  out : Array[@canonical_cfg.Local],
) -> Unit {
  match expr {
    ConstE(_) | NewTableE => ()
    LocalE(place) =>
      if resolve_storage(plans, place) is VarPS {
        push_unique_place(out, place)
      }
    NumericForCheckE(ctrl, limit, step) => {
      expr_use_places(program, plans, ctrl, out)
      expr_use_places(program, plans, limit, out)
      expr_use_places(program, plans, step, out)
    }
    IndexE(target, key) => {
      expr_use_places(program, plans, target, out)
      expr_use_places(program, plans, key, out)
    }
    UnaryE(_, inner) => expr_use_places(program, plans, inner, out)
    BinaryE(_, lhs, rhs) => {
      expr_use_places(program, plans, lhs, out)
      expr_use_places(program, plans, rhs, out)
    }
    CallE(callee, args, multi) => {
      expr_use_places(program, plans, callee, out)
      for arg in args {
        expr_use_places(program, plans, arg, out)
      }
      match multi {
        Some(multi) => multi_use_places(program, plans, multi, out)
        None => ()
      }
    }
    ClosureE(id) => {
      let child = program.funcs[id.index]
      for place in child.upvalues {
        if resolve_storage(plans, place) is VarPS {
          push_unique_place(out, place)
        }
      }
    }
  }
}

///|
fn multi_use_places(
  program : @canonical_cfg.Program,
  plans : ProgramPlan,
  multi : @canonical_cfg.Multi,
  out : Array[@canonical_cfg.Local],
) -> Unit {
  match multi {
    VarargM => ()
    CallM(callee, args, tail) => {
      expr_use_places(program, plans, callee, out)
      for arg in args {
        expr_use_places(program, plans, arg, out)
      }
      match tail {
        Some(next) => multi_use_places(program, plans, next, out)
        None => ()
      }
    }
  }
}

///|
fn scan_func(
  program : @canonical_cfg.Program,
  plans : ProgramPlan,
  func : @canonical_cfg.Func,
) -> ScanSummary {
  let cfg = plans.funcs[func.index].cfg
  let tracked_places : Array[@canonical_cfg.Local] = []
  let def_blocks : Map[@canonical_cfg.Local, Array[@canonical_cfg.Label]] = {}
  let block_defs : Map[@canonical_cfg.Label, Array[@canonical_cfg.Local]] = {}
  let upward_uses : Map[@canonical_cfg.Label, Array[@canonical_cfg.Local]] = {}

  let add_tracked = fn(place : @canonical_cfg.Local) -> Unit {
    if resolve_storage(plans, place) is VarPS {
      push_unique_place(tracked_places, place)
    }
  }

  let add_def_block = fn(
    place : @canonical_cfg.Local,
    label : @canonical_cfg.Label,
  ) -> Unit {
    add_tracked(place)
    if resolve_storage(plans, place) is VarPS {
      match def_blocks.get(place) {
        Some(labels) => push_unique_cfg_label(labels, label)
        None => def_blocks[place] = [label]
      }
    }
  }

  for place in func.params {
    add_def_block(place, func.entry)
  }
  for place in func.upvalues {
    add_def_block(place, func.entry)
  }

  let consume_place = fn(
    place : @canonical_cfg.Local,
    defined_here : Map[@canonical_cfg.Local, Bool],
    upward : Array[@canonical_cfg.Local],
  ) -> Unit {
    add_tracked(place)
    if resolve_storage(plans, place) is VarPS && defined_here.get(place) is None {
      push_unique_place(upward, place)
    }
  }

  for label in cfg.labels {
    let defs : Array[@canonical_cfg.Local] = []
    let upward : Array[@canonical_cfg.Local] = []
    let defined_here : Map[@canonical_cfg.Local, Bool] = {}
    match func.blocks.get(label) {
      Some(block) => {
        for stmt in block.stmts {
          match stmt {
            AssignS(place, expr) => {
              let used_places : Array[@canonical_cfg.Local] = []
              expr_use_places(program, plans, expr, used_places)
              for used_place in used_places {
                consume_place(used_place, defined_here, upward)
              }
              if resolve_storage(plans, place) is VarPS {
                push_unique_place(defs, place)
                defined_here[place] = true
                add_def_block(place, label)
              }
            }
            SetIndexS(target, key, value) => {
              let used_places : Array[@canonical_cfg.Local] = []
              expr_use_places(program, plans, target, used_places)
              expr_use_places(program, plans, key, used_places)
              expr_use_places(program, plans, value, used_places)
              for used_place in used_places {
                consume_place(used_place, defined_here, upward)
              }
            }
            AssignMultiS(places, multi) => {
              let used_places : Array[@canonical_cfg.Local] = []
              multi_use_places(program, plans, multi, used_places)
              for used_place in used_places {
                consume_place(used_place, defined_here, upward)
              }
              for place in places {
                if resolve_storage(plans, place) is VarPS {
                  push_unique_place(defs, place)
                  defined_here[place] = true
                  add_def_block(place, label)
                }
              }
            }
            SetListS(target, index, values, multi) => {
              let used_places : Array[@canonical_cfg.Local] = []
              expr_use_places(program, plans, target, used_places)
              expr_use_places(program, plans, index, used_places)
              for value in values {
                expr_use_places(program, plans, value, used_places)
              }
              match multi {
                Some(multi) =>
                  multi_use_places(program, plans, multi, used_places)
                None => ()
              }
              for used_place in used_places {
                consume_place(used_place, defined_here, upward)
              }
            }
          }
        }
        match block.term {
          JumpT(_) => ()
          CondT(expr, _, _) => {
            let used_places : Array[@canonical_cfg.Local] = []
            expr_use_places(program, plans, expr, used_places)
            for used_place in used_places {
              consume_place(used_place, defined_here, upward)
            }
          }
          ReturnT(values, multi) => {
            let used_places : Array[@canonical_cfg.Local] = []
            for value in values {
              expr_use_places(program, plans, value, used_places)
            }
            match multi {
              Some(multi) =>
                multi_use_places(program, plans, multi, used_places)
              None => ()
            }
            for used_place in used_places {
              consume_place(used_place, defined_here, upward)
            }
          }
        }
      }
      None => panic()
    }
    block_defs[label] = defs
    upward_uses[label] = upward
  }

  { tracked_places, def_blocks, block_defs, upward_uses }
}

///|
fn block_defines(
  summary : ScanSummary,
  label : @canonical_cfg.Label,
  place : @canonical_cfg.Local,
) -> Bool {
  match summary.block_defs.get(label) {
    Some(places) => contains_place(places, place)
    None => false
  }
}

///|
fn compute_live_in(
  summary : ScanSummary,
  cfg : CfgInfo,
  place : @canonical_cfg.Local,
) -> Map[@canonical_cfg.Label, Bool] {
  let live_in : Map[@canonical_cfg.Label, Bool] = {}
  let worklist : Array[@canonical_cfg.Label] = []
  for label in cfg.labels {
    match summary.upward_uses.get(label) {
      Some(places) => if contains_place(places, place) { worklist.push(label) }
      None => ()
    }
  }
  while worklist.pop() is Some(label) {
    if live_in.get(label) is Some(true) {
      continue
    }
    live_in[label] = true
    match cfg.preds.get(label) {
      Some(preds) =>
        for pred in preds {
          if !block_defines(summary, pred, place) && live_in.get(pred) is None {
            worklist.push(pred)
          }
        }
      None => ()
    }
  }
  live_in
}

///|
fn build_dom_children(
  dom : DomTree,
) -> Map[@canonical_cfg.Label, Array[@canonical_cfg.Label]] {
  let children : Map[@canonical_cfg.Label, Array[@canonical_cfg.Label]] = {}
  for label in dom.preorder {
    children[label] = []
  }
  for label in dom.preorder {
    if label == dom.entry {
      continue
    }
    match dom.idom.get(label) {
      Some(parent) =>
        match children.get(parent) {
          Some(items) => items.push(label)
          None => children[parent] = [label]
        }
      None => panic()
    }
  }
  children
}

///|
fn build_dom_frontier(
  cfg : CfgInfo,
  dom : DomTree,
  children : Map[@canonical_cfg.Label, Array[@canonical_cfg.Label]],
) -> Map[@canonical_cfg.Label, Array[@canonical_cfg.Label]] {
  let frontier : Map[@canonical_cfg.Label, Array[@canonical_cfg.Label]] = {}

  letrec visit = fn(
    label : @canonical_cfg.Label,
  ) -> Array[@canonical_cfg.Label] {
    let df : Array[@canonical_cfg.Label] = []
    match cfg.succs.get(label) {
      Some(nexts) =>
        for next in nexts {
          match dom.idom.get(next) {
            Some(idom) => if idom != label { push_unique_cfg_label(df, next) }
            None => ()
          }
        }
      None => ()
    }
    match children.get(label) {
      Some(kids) =>
        for child in kids {
          let child_df = visit(child)
          for next in child_df {
            match dom.idom.get(next) {
              Some(idom) => if idom != label { push_unique_cfg_label(df, next) }
              None => push_unique_cfg_label(df, next)
            }
          }
        }
      None => ()
    }
    frontier[label] = df
    df
  }

  if dom.preorder.length() > 0 {
    ignore(visit(dom.entry))
  }
  frontier
}

///|
fn place_block_params(
  cfg : CfgInfo,
  summary : ScanSummary,
  frontier : Map[@canonical_cfg.Label, Array[@canonical_cfg.Label]],
) -> Map[@canonical_cfg.Label, Array[@canonical_cfg.Local]] {
  let params : Map[@canonical_cfg.Label, Array[@canonical_cfg.Local]] = {}
  for label in cfg.labels {
    params[label] = []
  }
  for place in summary.tracked_places {
    let live_in = compute_live_in(summary, cfg, place)
    let worklist : Array[@canonical_cfg.Label] = []
    let queued : Map[@canonical_cfg.Label, Bool] = {}
    let placed : Map[@canonical_cfg.Label, Bool] = {}
    match summary.def_blocks.get(place) {
      Some(labels) =>
        for label in labels {
          worklist.push(label)
          queued[label] = true
        }
      None => ()
    }
    while worklist.pop() is Some(label) {
      match frontier.get(label) {
        Some(fronts) =>
          for front in fronts {
            if live_in.get(front) is Some(true) && placed.get(front) is None {
              match params.get(front) {
                Some(places) => push_unique_place(places, place)
                None => params[front] = [place]
              }
              placed[front] = true
              if !block_defines(summary, front, place) &&
                queued.get(front) is None {
                worklist.push(front)
                queued[front] = true
              }
            }
          }
        None => ()
      }
    }
  }
  params
}

///|
fn binding_value(binding : Binding) -> Var {
  match binding {
    VarB(value) => value
    CellB(_) => panic()
  }
}

///|
struct CaptureBinding {
  vars : Array[Var]
  cells : Array[Cell]
} derive(Debug)

///|
fn build_ssa_func(
  program : @canonical_cfg.Program,
  plans : ProgramPlan,
  func : @canonical_cfg.Func,
  id_gen : IdGen,
  closure_bindings : Map[@canonical_cfg.FuncId, CaptureBinding],
  registered_children : Array[@canonical_cfg.FuncId],
  capture_binding~ : CaptureBinding,
) -> Func {
  let func_plan = plans.funcs[func.index]
  let cfg = func_plan.cfg
  let dom = build_dom_tree(func, cfg)
  let summary = scan_func(program, plans, func)
  let children = build_dom_children(dom)
  let frontier = build_dom_frontier(cfg, dom, children)
  let block_param_places = place_block_params(cfg, summary, frontier)

  let fresh_value = fn() -> Var { { id: id_gen.next() } }

  let stacks : Map[@canonical_cfg.Local, Array[Binding]] = {}
  let push_binding = fn(
    place : @canonical_cfg.Local,
    binding : Binding,
  ) -> Unit {
    match stacks.get(place) {
      Some(items) => items.push(binding)
      None => stacks[place] = [binding]
    }
  }
  let pop_binding = fn(place : @canonical_cfg.Local) -> Unit {
    match stacks.get(place) {
      Some(items) =>
        if items.length() == 0 {
          panic()
        } else {
          ignore(items.pop())
        }
      None => panic()
    }
  }
  let current_binding = fn(place : @canonical_cfg.Local) -> Binding {
    match stacks.get(place) {
      Some(items) =>
        if items.length() == 0 {
          panic()
        } else {
          items[items.length() - 1]
        }
      None => panic()
    }
  }
  let current_binding_opt = fn(place : @canonical_cfg.Local) -> Binding? {
    match stacks.get(place) {
      Some(items) =>
        if items.length() == 0 {
          None
        } else {
          Some(items[items.length() - 1])
        }
      None => None
    }
  }
  let owned_cell = fn(place : @canonical_cfg.Local) -> Cell? {
    if place.func == { index: func.index } {
      func_plan.cell_map.get(place)
    } else {
      None
    }
  }

  let params : Array[Var] = []
  for place in func.params {
    let value = fresh_value()
    params.push(value)
    match resolve_storage(plans, place) {
      VarPS => push_binding(place, VarB(value))
      CellPS(_) => push_binding(place, VarB(value))
    }
  }

  let mut capture_var_index = 0
  let mut capture_cell_index = 0
  let capture_vars = capture_binding.vars
  let capture_cells = capture_binding.cells
  for place in func.upvalues {
    match resolve_storage(plans, place) {
      VarPS => {
        guard capture_var_index < capture_vars.length() else { panic() }
        let value = capture_vars[capture_var_index]
        capture_var_index += 1
        push_binding(place, VarB(value))
      }
      CellPS(cell) => {
        guard capture_cell_index < capture_cells.length() else { panic() }
        if capture_cells[capture_cell_index] != cell {
          panic()
        }
        capture_cell_index += 1
        if stacks.get(place) is None {
          push_binding(place, CellB(cell))
        }
      }
    }
  }
  guard capture_var_index == capture_vars.length() else { panic() }
  guard capture_cell_index == capture_cells.length() else { panic() }

  let block_param_values : Map[@canonical_cfg.Label, Array[Var]] = {}
  for label in cfg.labels {
    let values : Array[Var] = []
    match block_param_places.get(label) {
      Some(places) =>
        for _ in places {
          values.push(fresh_value())
        }
      None => ()
    }
    block_param_values[label] = values
  }

  let materialize_owned_cell = fn(
    place : @canonical_cfg.Local,
    stmts : Array[Stmt],
    pushed : Array[@canonical_cfg.Local],
  ) -> Unit {
    match owned_cell(place) {
      Some(cell) =>
        match current_binding_opt(place) {
          Some(VarB(value)) => {
            stmts.push(StoreCellS(cell, VarE(value)))
            push_binding(place, CellB(cell))
            pushed.push(place)
          }
          Some(CellB(_)) => ()
          None => {
            push_binding(place, CellB(cell))
            pushed.push(place)
          }
        }
      None => ()
    }
  }
  let materialize_all_owned_cells = fn(
    stmts : Array[Stmt],
    pushed : Array[@canonical_cfg.Local],
  ) -> Unit {
    for place in func_plan.cell_places {
      materialize_owned_cell(place, stmts, pushed)
    }
  }

  let register_closure_binding = fn(
    id : @canonical_cfg.FuncId,
    stmts : Array[Stmt],
    pushed : Array[@canonical_cfg.Local],
  ) -> Array[Var] {
    if closure_bindings.get(id) is Some(_) {
      panic()
    }
    let vars : Array[Var] = []
    let cells : Array[Cell] = []
    let child = program.funcs[id.index]
    for place in child.upvalues {
      match resolve_storage(plans, place) {
        VarPS => vars.push(binding_value(current_binding(place)))
        CellPS(cell) => {
          materialize_owned_cell(place, stmts, pushed)
          cells.push(cell)
        }
      }
    }
    closure_bindings[id] = { vars, cells }
    registered_children.push(id)
    vars
  }

  letrec lower_expr = fn(
    expr : @canonical_cfg.Expr,
    stmts : Array[Stmt],
    pushed : Array[@canonical_cfg.Local],
  ) -> Expr {
    match expr {
      ConstE(c) => ConstE(c)
      LocalE(place) =>
        match resolve_storage(plans, place) {
          VarPS => VarE(binding_value(current_binding(place)))
          CellPS(cell) =>
            match current_binding_opt(place) {
              Some(VarB(value)) => VarE(value)
              Some(CellB(_)) | None => CellE(cell)
            }
        }
      NumericForCheckE(ctrl, limit, step) =>
        NumericForCheckE(
          lower_expr(ctrl, stmts, pushed),
          lower_expr(limit, stmts, pushed),
          lower_expr(step, stmts, pushed),
        )
      IndexE(target, key) =>
        IndexE(
          lower_expr(target, stmts, pushed),
          lower_expr(key, stmts, pushed),
        )
      NewTableE => TableE(EmptyTI)
      UnaryE(op, inner) => UnaryE(op, lower_expr(inner, stmts, pushed))
      BinaryE(op, lhs, rhs) =>
        BinaryE(
          op,
          lower_expr(lhs, stmts, pushed),
          lower_expr(rhs, stmts, pushed),
        )
      CallE(callee, args, multi) =>
        CallE(
          NormalC(
            lower_expr(callee, stmts, pushed),
            args.map(fn(arg) { lower_expr(arg, stmts, pushed) }),
            multi.map(fn(value) { lower_multi(value, stmts, pushed) }),
          ),
        )
      ClosureE(id) =>
        ClosureE(ssa_func_id(id), register_closure_binding(id, stmts, pushed))
    }
  }
  and lower_multi = fn(
    multi : @canonical_cfg.Multi,
    stmts : Array[Stmt],
    pushed : Array[@canonical_cfg.Local],
  ) -> Multi {
    match multi {
      VarargM => VarargM
      CallM(callee, args, tail) =>
        CallM(
          NormalC(
            lower_expr(callee, stmts, pushed),
            args.map(fn(arg) { lower_expr(arg, stmts, pushed) }),
            tail.map(fn(value) { lower_multi(value, stmts, pushed) }),
          ),
        )
    }
  }
  let lower_cond = fn(
    expr : @canonical_cfg.Expr,
    stmts : Array[Stmt],
    pushed : Array[@canonical_cfg.Local],
  ) -> Expr {
    lower_expr(expr, stmts, pushed)
  }

  let lower_target = fn(label : @canonical_cfg.Label) -> Target {
    let args : Array[Expr] = []
    let params = match block_param_values.get(label) {
      Some(values) => values
      None => []
    }
    match block_param_places.get(label) {
      Some(places) =>
        for place in places {
          args.push(VarE(binding_value(current_binding(place))))
        }
      None => ()
    }
    let base_label = ssa_label(plans, label)
    Target({ id: base_label.id, params }, args)
  }

  let mut blocks : SortedMap[Label, Block] = SortedMap::new()
  letrec emit_block = fn(label : @canonical_cfg.Label) -> Unit {
    let pushed : Array[@canonical_cfg.Local] = []
    match block_param_places.get(label) {
      Some(places) =>
        match block_param_values.get(label) {
          Some(values) =>
            for i in 0..<places.length() {
              push_binding(places[i], VarB(values[i]))
              pushed.push(places[i])
            }
          None => panic()
        }
      None => ()
    }

    let stmts : Array[Stmt] = []

    match func.blocks.get(label) {
      Some(block) => {
        for stmt in block.stmts {
          match stmt {
            AssignS(place, expr) =>
              match resolve_storage(plans, place) {
                VarPS => {
                  let value = fresh_value()
                  stmts.push(BindS(value, lower_expr(expr, stmts, pushed)))
                  push_binding(place, VarB(value))
                  pushed.push(place)
                }
                CellPS(cell) =>
                  match owned_cell(place) {
                    Some(_) =>
                      match current_binding_opt(place) {
                        Some(CellB(_)) =>
                          stmts.push(
                            StoreCellS(cell, lower_expr(expr, stmts, pushed)),
                          )
                        Some(VarB(_)) | None => {
                          let value = fresh_value()
                          stmts.push(
                            BindS(value, lower_expr(expr, stmts, pushed)),
                          )
                          push_binding(place, VarB(value))
                          pushed.push(place)
                        }
                      }
                    None =>
                      stmts.push(
                        StoreCellS(cell, lower_expr(expr, stmts, pushed)),
                      )
                  }
              }
            SetIndexS(target, key, value) =>
              stmts.push(
                SetIndexS(
                  lower_expr(target, stmts, pushed),
                  lower_expr(key, stmts, pushed),
                  lower_expr(value, stmts, pushed),
                ),
              )
            AssignMultiS(places, multi) => {
              let values : Array[Var] = []
              for _ in places {
                values.push(fresh_value())
              }
              stmts.push(BindMultiS(values, lower_multi(multi, stmts, pushed)))
              for i in 0..<places.length() {
                match resolve_storage(plans, places[i]) {
                  VarPS => {
                    push_binding(places[i], VarB(values[i]))
                    pushed.push(places[i])
                  }
                  CellPS(cell) =>
                    match owned_cell(places[i]) {
                      Some(_) =>
                        match current_binding_opt(places[i]) {
                          Some(CellB(_)) =>
                            stmts.push(StoreCellS(cell, VarE(values[i])))
                          Some(VarB(_)) | None => {
                            push_binding(places[i], VarB(values[i]))
                            pushed.push(places[i])
                          }
                        }
                      None => stmts.push(StoreCellS(cell, VarE(values[i])))
                    }
                }
              }
            }
            SetListS(target, index, values, multi) =>
              stmts.push(
                SetListS(
                  lower_expr(target, stmts, pushed),
                  lower_expr(index, stmts, pushed),
                  values.map(fn(value) { lower_expr(value, stmts, pushed) }),
                  multi.map(fn(value) { lower_multi(value, stmts, pushed) }),
                ),
              )
          }
        }
        let term : Term = match block.term {
          JumpT(next) => {
            materialize_all_owned_cells(stmts, pushed)
            JumpT(lower_target(next))
          }
          CondT(expr, true_label, false_label) => {
            let cond = lower_cond(expr, stmts, pushed)
            materialize_all_owned_cells(stmts, pushed)
            CondT(cond, lower_target(true_label), lower_target(false_label))
          }
          ReturnT(values, multi) =>
            ReturnT(
              values.map(fn(value) { lower_expr(value, stmts, pushed) }),
              multi.map(fn(value) { lower_multi(value, stmts, pushed) }),
            )
        }
        let base_label = ssa_label(plans, label)
        let params = match block_param_values.get(label) {
          Some(values) => values
          None => []
        }
        let ssa_block_label : Label = { id: base_label.id, params }
        blocks = blocks.add(ssa_block_label, { stmts, term })
      }
      None => panic()
    }

    match children.get(label) {
      Some(kids) =>
        for child in kids {
          emit_block(child)
        }
      None => ()
    }

    for i in (pushed.length() - 1)>=..0 {
      pop_binding(pushed[i])
    }
  }

  if dom.preorder.length() > 0 {
    emit_block(dom.entry)
  }
  {
    index: func.index,
    params,
    capture_vars,
    capture_cells,
    cells: func_plan.cells,
    vararg: func.vararg,
    blocks,
    entry: ssa_label(plans, func.entry),
  }
}
