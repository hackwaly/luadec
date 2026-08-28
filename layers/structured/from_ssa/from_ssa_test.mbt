///|
using @immut/sorted_map {type SortedMap}

///|
fn fresh_var(id_gen : @ssa.IdGen) -> @ssa.Var {
  { id: id_gen.next(), }
}

///|
fn fresh_label(id_gen : @ssa.IdGen) -> @ssa.Label {
  { id: id_gen.next(), params: [], }
}

///|
fn program_with(
  id_gen : @ssa.IdGen,
  blocks : SortedMap[@ssa.Label, @ssa.Block],
  entry : @ssa.Label,
) -> @ssa.Program {
  {
    _id_gen: id_gen,
    funcs: [
      {
        index: 0,
        params: [],
        capture_vars: [],
        capture_cells: [],
        cells: [],
        vararg: false,
        blocks,
        entry,
      },
    ],
    main: { index: 0, },
  }
}

///|
fn call_stmt(callee : @ssa.Var) -> @ssa.Stmt {
  @ssa.BindMultiS([], @ssa.CallM(@ssa.NormalC(@ssa.VarE(callee), [], None)))
}

///|
test "from_ssa preserves side effects in branch ending at shared empty return" {
  let id_gen = @ssa.IdGen()
  let entry = fresh_label(id_gen)
  let then_label = fresh_label(id_gen)
  let else_label = fresh_label(id_gen)
  let ret_label = fresh_label(id_gen)
  let cond = fresh_var(id_gen)
  let then_call = fresh_var(id_gen)
  let else_call = fresh_var(id_gen)
  let mut blocks : SortedMap[@ssa.Label, @ssa.Block] = SortedMap::new()
  blocks = blocks.add(entry, {
    stmts: [],
    term: @ssa.CondT(
      @ssa.VarE(cond),
      @ssa.Target(then_label, []),
      @ssa.Target(else_label, []),
    ),
  })
  blocks = blocks.add(then_label, {
    stmts: [call_stmt(then_call)],
    term: @ssa.JumpT(@ssa.Target(ret_label, [])),
  })
  blocks = blocks.add(else_label, {
    stmts: [call_stmt(else_call)],
    term: @ssa.ReturnT([], None),
  })
  blocks = blocks.add(ret_label, { stmts: [], term: @ssa.ReturnT([], None), })

  let structured = from_ssa(program_with(id_gen, blocks, entry))
  match structured.funcs[0].body {
    @structured.If(
      @ssa.VarE(actual_cond),
      @structured.Linear([@ssa.BindMultiS([], @ssa.CallM(_))], _),
      Some(@structured.Linear([@ssa.BindMultiS([], @ssa.CallM(_))], _)),
      _
    ) => {
      guard actual_cond == cond else { panic() }
    }
    _ => panic()
  }
}
