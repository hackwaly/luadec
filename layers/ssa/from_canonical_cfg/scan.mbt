///|
struct ClosureSite {
  index : Int
  callee : @canonical_cfg.FuncId
} derive(Debug)

///|
struct DefSite {
  index : Int
  place : @canonical_cfg.Local
} derive(Debug)

///|
fn expr_children(expr : @canonical_cfg.Expr) -> Array[@canonical_cfg.Expr] {
  match expr {
    @canonical_cfg.ConstE(_)
    | @canonical_cfg.LocalE(_)
    | @canonical_cfg.NewTableE
    | @canonical_cfg.ClosureE(_) => []
    @canonical_cfg.NumericForCheckE(ctrl, limit, step) => [ctrl, limit, step]
    @canonical_cfg.IndexE(lhs, rhs) => [lhs, rhs]
    @canonical_cfg.UnaryE(_, inner) => [inner]
    @canonical_cfg.BinaryE(_, lhs, rhs) => [lhs, rhs]
    @canonical_cfg.CallE(callee, args, multi) => {
      let children = [callee]
      for arg in args {
        children.push(arg)
      }
      match multi {
        Some(multi) =>
          for child in multi_children(multi) {
            children.push(child)
          }
        None => ()
      }
      children
    }
  }
}

///|
fn multi_children(multi : @canonical_cfg.Multi) -> Array[@canonical_cfg.Expr] {
  match multi {
    @canonical_cfg.VarargM => []
    @canonical_cfg.CallM(callee, args, tail) => {
      let children = [callee]
      for arg in args {
        children.push(arg)
      }
      match tail {
        Some(next) =>
          for child in multi_children(next) {
            children.push(child)
          }
        None => ()
      }
      children
    }
  }
}

///|
fn collect_closures_expr(
  expr : @canonical_cfg.Expr,
  out : Array[@canonical_cfg.FuncId],
) -> Unit {
  match expr {
    @canonical_cfg.ClosureE(id) => out.push(id)
    _ => ()
  }
  for child in expr_children(expr) {
    collect_closures_expr(child, out)
  }
}

///|
fn collect_closures_stmt(
  stmt : @canonical_cfg.Stmt,
  out : Array[@canonical_cfg.FuncId],
) -> Unit {
  match stmt {
    @canonical_cfg.AssignS(_, expr) => collect_closures_expr(expr, out)
    @canonical_cfg.SetIndexS(target, key, value) => {
      collect_closures_expr(target, out)
      collect_closures_expr(key, out)
      collect_closures_expr(value, out)
    }
    @canonical_cfg.AssignMultiS(_, multi) =>
      for child in multi_children(multi) {
        collect_closures_expr(child, out)
      }
    @canonical_cfg.SetListS(target, index, values, multi) => {
      collect_closures_expr(target, out)
      collect_closures_expr(index, out)
      for value in values {
        collect_closures_expr(value, out)
      }
      match multi {
        Some(multi) =>
          for child in multi_children(multi) {
            collect_closures_expr(child, out)
          }
        None => ()
      }
    }
  }
}

///|
fn collect_closures_term(
  term : @canonical_cfg.Term,
  out : Array[@canonical_cfg.FuncId],
) -> Unit {
  match term {
    @canonical_cfg.JumpT(_) => ()
    @canonical_cfg.CondT(expr, _, _) => collect_closures_expr(expr, out)
    @canonical_cfg.ReturnT(values, multi) => {
      for value in values {
        collect_closures_expr(value, out)
      }
      match multi {
        Some(multi) =>
          for child in multi_children(multi) {
            collect_closures_expr(child, out)
          }
        None => ()
      }
    }
  }
}

///|
fn stmt_defs(stmt : @canonical_cfg.Stmt) -> Array[@canonical_cfg.Local] {
  match stmt {
    @canonical_cfg.AssignS(place, _) => [place]
    @canonical_cfg.SetIndexS(_, _, _) => []
    @canonical_cfg.AssignMultiS(places, _) => places
    @canonical_cfg.SetListS(_, _, _, _) => []
  }
}

///|
fn block_captures(block : @canonical_cfg.Block) -> Array[ClosureSite] {
  let captures : Array[ClosureSite] = []
  for i in 0..<block.stmts.length() {
    let ids : Array[@canonical_cfg.FuncId] = []
    collect_closures_stmt(block.stmts[i], ids)
    for id in ids {
      captures.push({ index: i, callee: id })
    }
  }
  let ids : Array[@canonical_cfg.FuncId] = []
  collect_closures_term(block.term, ids)
  for id in ids {
    captures.push({ index: block.stmts.length(), callee: id })
  }
  captures
}

///|
fn block_defs(block : @canonical_cfg.Block) -> Array[DefSite] {
  let defs : Array[DefSite] = []
  for i in 0..<block.stmts.length() {
    for place in stmt_defs(block.stmts[i]) {
      defs.push({ index: i, place })
    }
  }
  defs
}

///|
fn func_writes(func : @canonical_cfg.Func) -> Array[@canonical_cfg.Local] {
  let places : Array[@canonical_cfg.Local] = []
  let cfg = build_cfg_info(func)
  for label in cfg.labels {
    match func.blocks.get(label) {
      Some(block) =>
        for def in block_defs(block) {
          places.push(def.place)
        }
      None => ()
    }
  }
  places
}
