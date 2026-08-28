///|
fn lower_func_id(id : @raw_cfg.FuncId) -> FuncId {
  { index: id.index, }
}

///|
fn lower_local(local_ : @raw_cfg.Local) -> Local {
  if local_.is_env() {
    Local::env()
  } else {
    { func: lower_func_id(local_.func), index: local_.slot, }
  }
}

///|
fn lower_expr(expr : @raw_cfg.Expr) -> Expr {
  match expr {
    ConstE(c) => ConstE(c)
    LocalE(local_) => LocalE(lower_local(local_))
    IndexE(target, key) => IndexE(lower_expr(target), lower_expr(key))
    NewTableE => NewTableE
    UnaryE(op, inner) => UnaryE(op, lower_expr(inner))
    BinaryE(op, lhs, rhs) => BinaryE(op, lower_expr(lhs), lower_expr(rhs))
    CallE(callee, args, multi) =>
      CallE(lower_expr(callee), args.map(lower_expr), multi.map(lower_multi))
    ClosureE(id) => ClosureE(lower_func_id(id))
  }
}

///|
fn lower_multi(multi : @raw_cfg.Multi) -> Multi {
  match multi {
    VarargM => VarargM
    CallM(callee, args, tail) =>
      CallM(lower_expr(callee), args.map(lower_expr), tail.map(lower_multi))
  }
}

///|
fn lower_stmt(stmt : @raw_cfg.Stmt) -> Stmt {
  match stmt {
    SetS(local_, expr) => AssignS(lower_local(local_), lower_expr(expr))
    SetIndexS(target, key, value) =>
      SetIndexS(lower_expr(target), lower_expr(key), lower_expr(value))
    SetMultiS(locals, multi) =>
      AssignMultiS(locals.map(lower_local), lower_multi(multi))
    SetListS(target, index, values, multi) =>
      SetListS(
        lower_expr(target),
        lower_expr(index),
        values.map(lower_expr),
        multi.map(lower_multi),
      )
  }
}

///|
priv struct LowerState {
  func : @raw_cfg.Func
  label_map : Map[@raw_cfg.Label, Label]
  mut blocks : SortedMap[Label, Block]
  mut next_label_index : Int
}

///|
fn lower_label(state : LowerState, label : @raw_cfg.Label) -> Label {
  match state.label_map.get(label) {
    Some(canon) => canon
    None => panic()
  }
}

///|
fn contains_raw_label(
  labels : Array[@raw_cfg.Label],
  target : @raw_cfg.Label,
) -> Bool {
  let mut found = false
  for label in labels {
    if label == target {
      found = true
    }
  }
  found
}

///|
fn successor_labels(term : @raw_cfg.Term) -> Array[@raw_cfg.Label] {
  match term {
    JumpT(label) => [label]
    CondT(_, true_label, false_label) => [true_label, false_label]
    CondSetT(_, _, _, true_label, false_label) => [true_label, false_label]
    ForPrepT(_, _, label) => [label]
    ForLoopT(_, _, _, _, body, exit) => [body, exit]
    GenericForT(_, _, _, _, body, exit) => [body, exit]
    ReturnT(_, _) => []
  }
}

///|
fn reachable_labels(func : @raw_cfg.Func) -> Array[@raw_cfg.Label] {
  let order : Array[@raw_cfg.Label] = []
  let worklist : Array[@raw_cfg.Label] = [func.entry]
  while worklist.pop() is Some(label) {
    if contains_raw_label(order, label) {
      continue
    }
    order.push(label)
    match func.blocks.get(label) {
      Some(block) =>
        for next in successor_labels(block.term) {
          if !contains_raw_label(order, next) &&
            !contains_raw_label(worklist, next) {
            worklist.push(next)
          }
        }
      None => panic()
    }
  }
  order
}

///|
fn fresh_label(state : LowerState) -> Label {
  let label = Label::new(
    func=lower_func_id({ index: state.func.index, }),
    index=state.next_label_index,
  )
  state.next_label_index += 1
  label
}

///|
fn add_bridge_block(
  state : LowerState,
  stmts : Array[Stmt],
  term : Term,
) -> Label {
  let label = fresh_label(state)
  state.blocks = state.blocks.add(label, { stmts, term, })
  label
}

///|
fn lower_func(func : @raw_cfg.Func) -> Func {
  let label_map : Map[@raw_cfg.Label, Label] = Map([])
  let state : LowerState = {
    func,
    label_map,
    blocks: SortedMap::new(),
    next_label_index: 0,
  }
  let labels = reachable_labels(func)

  for label in labels {
    let canon = fresh_label(state)
    state.label_map[label] = canon
  }

  let lower_term = fn(block : @raw_cfg.Block, stmts : Array[Stmt]) -> Term {
    match block.term {
      JumpT(label) => JumpT(lower_label(state, label))
      CondT(expr, true_label, false_label) =>
        CondT(
          lower_expr(expr),
          lower_label(state, true_label),
          lower_label(state, false_label),
        )
      CondSetT(expr, local_, value, true_label, false_label) => {
        let bridge = add_bridge_block(
          state,
          [AssignS(lower_local(local_), lower_expr(value))],
          JumpT(lower_label(state, true_label)),
        )
        CondT(lower_expr(expr), bridge, lower_label(state, false_label))
      }
      ForPrepT(ctrl, step, next) => {
        stmts.push(
          AssignS(
            lower_local(ctrl),
            BinaryE(Sub, LocalE(lower_local(ctrl)), lower_expr(step)),
          ),
        )
        JumpT(lower_label(state, next))
      }
      ForLoopT(index, limit, step, slot, body, exit) => {
        let canon_index = lower_local(index)
        stmts.push(
          AssignS(
            canon_index,
            BinaryE(Add, LocalE(canon_index), lower_expr(step)),
          ),
        )
        let bridge = add_bridge_block(
          state,
          [AssignS(lower_local(slot), LocalE(canon_index))],
          JumpT(lower_label(state, body)),
        )
        CondT(
          NumericForCheckE(
            LocalE(canon_index),
            lower_expr(limit),
            lower_expr(step),
          ),
          bridge,
          lower_label(state, exit),
        )
      }
      GenericForT(generator, state_arg, control, slots, body, exit) => {
        guard slots.length() > 0 else { panic() }
        stmts.push(
          AssignMultiS(
            slots.map(lower_local),
            CallM(
              lower_expr(generator),
              [lower_expr(state_arg), LocalE(lower_local(control))],
              None,
            ),
          ),
        )
        let first_slot = lower_local(slots[0])
        let bridge = add_bridge_block(
          state,
          [AssignS(lower_local(control), LocalE(first_slot))],
          JumpT(lower_label(state, body)),
        )
        CondT(
          BinaryE(Neq, LocalE(first_slot), ConstE(Nil)),
          bridge,
          lower_label(state, exit),
        )
      }
      ReturnT(values, multi) =>
        ReturnT(values.map(lower_expr), multi.map(lower_multi))
    }
  }

  for label in labels {
    match func.blocks.get(label) {
      Some(block) => {
        let canon_label = lower_label(state, label)
        let stmts = block.stmts.map(lower_stmt)
        let term = lower_term(block, stmts)
        state.blocks = state.blocks.add(canon_label, { stmts, term, })
      }
      None => panic()
    }
  }

  {
    index: func.index,
    params: func.params.map(lower_local),
    upvalues: func.upvalues.map(lower_local),
    vararg: func.vararg,
    blocks: state.blocks,
    entry: lower_label(state, func.entry),
  }
}

///|
pub fn from_raw_cfg(prog : @raw_cfg.Program) -> Program {
  { funcs: prog.funcs.map(lower_func), main: lower_func_id(prog.main), }
}
