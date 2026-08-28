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
fn fresh_label_with_params(
  id_gen : @ssa.IdGen,
  params : Array[@ssa.Var],
) -> @ssa.Label {
  { id: id_gen.next(), params, }
}

///|
fn int_expr(value : Int) -> @ssa.Expr {
  @ssa.ConstE(Integer(value.to_int64()))
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
test "materialize rewrites jump target expressions in predecessor block" {
  let id_gen = @ssa.IdGen()
  let entry = fresh_label(id_gen)
  let param = fresh_var(id_gen)
  let merge = fresh_label_with_params(id_gen, [param])
  let value = fresh_var(id_gen)
  let mut blocks : SortedMap[@ssa.Label, @ssa.Block] = SortedMap::new()
  blocks = blocks.add(entry, {
    stmts: [],
    term: @ssa.JumpT(
      @ssa.Target(merge, [@ssa.BinaryE(Add, @ssa.VarE(value), int_expr(1))]),
    ),
  })
  blocks = blocks.add(merge, {
    stmts: [],
    term: @ssa.ReturnT([@ssa.VarE(param)], None),
  })

  let materialized = materialize_target_args(
    program_with(id_gen, blocks, entry),
  )
  match materialized.funcs[0].blocks[entry] {
    {
      stmts: [
        @ssa.BindS(
          tmp,
          @ssa.BinaryE(Add, @ssa.VarE(actual_value), @ssa.ConstE(Integer(1L)))
        ),
      ],
      term: @ssa.JumpT(@ssa.Target(actual_merge, [@ssa.VarE(actual_arg)])),
    } => {
      guard actual_value == value else { panic() }
      guard actual_merge == merge else { panic() }
      guard actual_arg == tmp else { panic() }
    }
    _ => panic()
  }
}

///|
test "materialize inserts conditional bridge blocks for expression args" {
  let id_gen = @ssa.IdGen()
  let entry = fresh_label(id_gen)
  let result = fresh_var(id_gen)
  let merge = fresh_label_with_params(id_gen, [result])
  let cond = fresh_var(id_gen)
  let lhs = fresh_var(id_gen)
  let rhs = fresh_var(id_gen)
  let mut blocks : SortedMap[@ssa.Label, @ssa.Block] = SortedMap::new()
  blocks = blocks.add(entry, {
    stmts: [],
    term: @ssa.CondT(
      @ssa.VarE(cond),
      @ssa.Target(merge, [@ssa.BinaryE(Add, @ssa.VarE(lhs), int_expr(1))]),
      @ssa.Target(merge, [@ssa.BinaryE(Sub, @ssa.VarE(rhs), int_expr(1))]),
    ),
  })
  blocks = blocks.add(merge, {
    stmts: [],
    term: @ssa.ReturnT([@ssa.VarE(result)], None),
  })

  let materialized = materialize_target_args(
    program_with(id_gen, blocks, entry),
  )
  match materialized.funcs[0].blocks[entry].term {
    @ssa.CondT(
      @ssa.VarE(actual_cond),
      @ssa.Target(true_bridge, []),
      @ssa.Target(false_bridge, [])
    ) => {
      guard actual_cond == cond else { panic() }
      match materialized.funcs[0].blocks[true_bridge] {
        {
          stmts: [@ssa.BindS(tmp, @ssa.BinaryE(Add, @ssa.VarE(actual_lhs), _))],
          term: @ssa.JumpT(@ssa.Target(actual_merge, [@ssa.VarE(actual_arg)])),
        } => {
          guard actual_lhs == lhs else { panic() }
          guard actual_merge == merge else { panic() }
          guard actual_arg == tmp else { panic() }
        }
        _ => panic()
      }
      match materialized.funcs[0].blocks[false_bridge] {
        {
          stmts: [@ssa.BindS(tmp, @ssa.BinaryE(Sub, @ssa.VarE(actual_rhs), _))],
          term: @ssa.JumpT(@ssa.Target(actual_merge, [@ssa.VarE(actual_arg)])),
        } => {
          guard actual_rhs == rhs else { panic() }
          guard actual_merge == merge else { panic() }
          guard actual_arg == tmp else { panic() }
        }
        _ => panic()
      }
    }
    _ => panic()
  }
}
