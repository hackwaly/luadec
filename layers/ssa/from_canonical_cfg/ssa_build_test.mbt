///|
using @immut/sorted_map {type SortedMap}

///|
fn cfg_local(func : Int, index : Int) -> @canonical_cfg.Local {
  { func: { index: func, }, index, }
}

///|
fn label(func : Int, index : Int) -> @canonical_cfg.Label {
  { func: { index: func, }, index, }
}

///|
fn key(name : String) -> @canonical_cfg.Expr {
  ConstE(AsciiString(name, is_valid_identifier=true))
}

///|
fn int(value : Int) -> @canonical_cfg.Expr {
  ConstE(Integer(value.to_int64()))
}

///|
fn expr_uses_cell(expr : @ssa.Expr, cell : @ssa.Cell) -> Bool {
  match expr {
    CellE(actual) => actual == cell
    NumericForCheckE(ctrl, limit, step) =>
      expr_uses_cell(ctrl, cell) ||
      expr_uses_cell(limit, cell) ||
      expr_uses_cell(step, cell)
    IndexE(target, key) =>
      expr_uses_cell(target, cell) || expr_uses_cell(key, cell)
    TableE(_) => false
    UnaryE(_, inner) => expr_uses_cell(inner, cell)
    BinaryE(_, lhs, rhs) =>
      expr_uses_cell(lhs, cell) || expr_uses_cell(rhs, cell)
    AndE(lhs, rhs) | OrE(lhs, rhs) =>
      expr_uses_cell(lhs, cell) || expr_uses_cell(rhs, cell)
    CallE(NormalC(callee, args, _)) => {
      if expr_uses_cell(callee, cell) {
        return true
      }
      for arg in args {
        if expr_uses_cell(arg, cell) {
          return true
        }
      }
      false
    }
    CallE(MethodC(receiver, _, args, _)) => {
      if expr_uses_cell(receiver, cell) {
        return true
      }
      for arg in args {
        if expr_uses_cell(arg, cell) {
          return true
        }
      }
      false
    }
    ConstE(_) | VarE(_) | ClosureE(_, _) => false
  }
}

///|
test "cell-captured local stays SSA before closure capture" {
  let self = cfg_local(0, 0)
  let slot = cfg_local(0, 1)
  let method_value = cfg_local(0, 2)
  let closure = cfg_local(0, 3)
  let entry = label(0, 0)
  let child_entry = label(1, 0)

  let mut parent_blocks : SortedMap[@canonical_cfg.Label, @canonical_cfg.Block] = SortedMap::new()
  parent_blocks = parent_blocks.add(entry, {
    stmts: [
      AssignS(slot, LocalE(self)),
      AssignS(method_value, IndexE(LocalE(self), key("removeEventListener"))),
      AssignMultiS([], CallM(LocalE(method_value), [LocalE(slot)], None)),
      AssignS(slot, int(2)),
      AssignS(closure, ClosureE({ index: 1, })),
    ],
    term: ReturnT([LocalE(closure)], None),
  })

  let mut child_blocks : SortedMap[@canonical_cfg.Label, @canonical_cfg.Block] = SortedMap::new()
  child_blocks = child_blocks.add(child_entry, {
    stmts: [AssignS(slot, BinaryE(Sub, LocalE(slot), int(1)))],
    term: ReturnT([], None),
  })

  let program = @canonical_cfg.Program::{
    funcs: [
      {
        index: 0,
        params: [self],
        upvalues: [@canonical_cfg.Local::env()],
        vararg: false,
        blocks: parent_blocks,
        entry,
      },
      {
        index: 1,
        params: [],
        upvalues: [slot],
        vararg: false,
        blocks: child_blocks,
        entry: child_entry,
      },
    ],
    main: { index: 0, },
  }

  let ssa = from_canonical_cfg(program)
  let parent = ssa.funcs[0]
  guard parent.cells.length() == 1 else { panic() }
  let captured_cell = parent.cells[0]
  match parent.blocks[parent.entry].stmts {
    [
      BindS(_, VarE(_)),
      BindS(_, IndexE(VarE(_), ConstE(AsciiString("removeEventListener", ..)))),
      BindMultiS(_, CallM(NormalC(VarE(_), [VarE(_)], None))),
      BindS(counter, ConstE(Integer(2L))),
      StoreCellS(actual_cell, VarE(actual_counter)),
      BindS(_, ClosureE({ index: 1, }, [])),
    ] => {
      guard actual_cell == captured_cell else { panic() }
      guard actual_counter == counter else { panic() }
    }
    _ => panic()
  }
  for stmt in parent.blocks[parent.entry].stmts {
    match stmt {
      StoreCellS(_, _) => break
      BindS(_, expr) => {
        guard !expr_uses_cell(expr, captured_cell) else { panic() }
      }
      BindMultiS(_, CallM(NormalC(callee, args, _))) => {
        guard !expr_uses_cell(callee, captured_cell) else { panic() }
        for arg in args {
          guard !expr_uses_cell(arg, captured_cell) else { panic() }
        }
      }
      _ => ()
    }
  }
  guard ssa.funcs[1].capture_cells == [captured_cell] else { panic() }
}
