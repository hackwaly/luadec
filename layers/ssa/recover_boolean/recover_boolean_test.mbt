///|
using @immut/sorted_map {type SortedMap}

///|
fn fresh_var(id_gen : @ssa.IdGen) -> @ssa.Var {
  { id: id_gen.next() }
}

///|
fn fresh_label(id_gen : @ssa.IdGen) -> @ssa.Label {
  { id: id_gen.next(), params: [] }
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
    main: { index: 0 },
  }
}

///|
test "recover folds nested conditional into and expression" {
  let id_gen = @ssa.IdGen()
  let entry = fresh_label(id_gen)
  let rhs_label = fresh_label(id_gen)
  let true_label = fresh_label(id_gen)
  let false_label = fresh_label(id_gen)
  let lhs = fresh_var(id_gen)
  let rhs = fresh_var(id_gen)

  let mut blocks : SortedMap[@ssa.Label, @ssa.Block] = SortedMap::new()
  blocks = blocks.add(entry, {
    stmts: [],
    term: @ssa.CondT(
      @ssa.VarE(lhs),
      @ssa.Target(rhs_label, []),
      @ssa.Target(false_label, []),
    ),
  })
  blocks = blocks.add(rhs_label, {
    stmts: [],
    term: @ssa.CondT(
      @ssa.VarE(rhs),
      @ssa.Target(true_label, []),
      @ssa.Target(false_label, []),
    ),
  })
  blocks = blocks.add(true_label, {
    stmts: [],
    term: @ssa.ReturnT([@ssa.ConstE(Boolean(true))], None),
  })
  blocks = blocks.add(false_label, {
    stmts: [],
    term: @ssa.ReturnT([@ssa.ConstE(Boolean(false))], None),
  })

  let recovered = recover_boolean(program_with(id_gen, blocks, entry))
  let func = recovered.funcs[0]
  guard func.blocks.get(rhs_label) is None else { panic() }
  match func.blocks[entry].term {
    @ssa.CondT(
      @ssa.AndE(@ssa.VarE(actual_lhs), @ssa.VarE(actual_rhs)),
      @ssa.Target(actual_true, []),
      @ssa.Target(actual_false, [])
    ) => {
      guard actual_lhs == lhs else { panic() }
      guard actual_rhs == rhs else { panic() }
      guard actual_true == true_label else { panic() }
      guard actual_false == false_label else { panic() }
    }
    _ => panic()
  }
}

///|
test "recover normalizes negated and condition" {
  let id_gen = @ssa.IdGen()
  let entry = fresh_label(id_gen)
  let rhs_label = fresh_label(id_gen)
  let true_label = fresh_label(id_gen)
  let false_label = fresh_label(id_gen)
  let lhs = fresh_var(id_gen)
  let rhs = fresh_var(id_gen)

  let mut blocks : SortedMap[@ssa.Label, @ssa.Block] = SortedMap::new()
  blocks = blocks.add(entry, {
    stmts: [],
    term: @ssa.CondT(
      @ssa.UnaryE(Not, @ssa.VarE(lhs)),
      @ssa.Target(false_label, []),
      @ssa.Target(rhs_label, []),
    ),
  })
  blocks = blocks.add(rhs_label, {
    stmts: [],
    term: @ssa.CondT(
      @ssa.UnaryE(Not, @ssa.VarE(rhs)),
      @ssa.Target(false_label, []),
      @ssa.Target(true_label, []),
    ),
  })
  blocks = blocks.add(true_label, {
    stmts: [],
    term: @ssa.ReturnT([@ssa.ConstE(Boolean(true))], None),
  })
  blocks = blocks.add(false_label, {
    stmts: [],
    term: @ssa.ReturnT([@ssa.ConstE(Boolean(false))], None),
  })

  let recovered = recover_boolean(program_with(id_gen, blocks, entry))
  match recovered.funcs[0].blocks[entry].term {
    @ssa.CondT(
      @ssa.UnaryE(Not, @ssa.AndE(@ssa.VarE(actual_lhs), @ssa.VarE(actual_rhs))),
      @ssa.Target(actual_false, []),
      @ssa.Target(actual_true, [])
    ) => {
      guard actual_lhs == lhs else { panic() }
      guard actual_rhs == rhs else { panic() }
      guard actual_false == false_label else { panic() }
      guard actual_true == true_label else { panic() }
    }
    _ => panic()
  }
}

///|
test "recover folds or condition with negated rhs branch" {
  let id_gen = @ssa.IdGen()
  let entry = fresh_label(id_gen)
  let rhs_label = fresh_label(id_gen)
  let body_label = fresh_label(id_gen)
  let join_label = fresh_label(id_gen)
  let lhs = fresh_var(id_gen)
  let rhs = fresh_var(id_gen)

  let mut blocks : SortedMap[@ssa.Label, @ssa.Block] = SortedMap::new()
  blocks = blocks.add(entry, {
    stmts: [],
    term: @ssa.CondT(
      @ssa.VarE(lhs),
      @ssa.Target(body_label, []),
      @ssa.Target(rhs_label, []),
    ),
  })
  blocks = blocks.add(rhs_label, {
    stmts: [],
    term: @ssa.CondT(
      @ssa.UnaryE(Not, @ssa.VarE(rhs)),
      @ssa.Target(join_label, []),
      @ssa.Target(body_label, []),
    ),
  })
  blocks = blocks.add(body_label, {
    stmts: [@ssa.BindS(fresh_var(id_gen), @ssa.ConstE(Boolean(true)))],
    term: @ssa.JumpT(@ssa.Target(join_label, [])),
  })
  blocks = blocks.add(join_label, { stmts: [], term: @ssa.ReturnT([], None) })

  let recovered = recover_boolean(program_with(id_gen, blocks, entry))
  let func = recovered.funcs[0]
  guard func.blocks.get(rhs_label) is None else { panic() }
  match func.blocks[entry].term {
    @ssa.CondT(
      @ssa.OrE(@ssa.VarE(actual_lhs), @ssa.VarE(actual_rhs)),
      @ssa.Target(actual_body, []),
      @ssa.Target(actual_join, [])
    ) => {
      guard actual_lhs == lhs else { panic() }
      guard actual_rhs == rhs else { panic() }
      guard actual_body == body_label else { panic() }
      guard actual_join == join_label else { panic() }
    }
    _ => panic()
  }
}

///|
test "recover folds or condition with matching target args" {
  let id_gen = @ssa.IdGen()
  let entry = fresh_label(id_gen)
  let rhs_label = fresh_label(id_gen)
  let join_label = fresh_label(id_gen)
  let lhs = fresh_var(id_gen)
  let rhs = fresh_var(id_gen)
  let arg = fresh_var(id_gen)
  let fallback = fresh_var(id_gen)
  let result = fresh_var(id_gen)
  let join = { ..join_label, params: [result] }
  let shared = @ssa.Target(join, [@ssa.VarE(arg)])
  let fallback_target = @ssa.Target(join, [@ssa.VarE(fallback)])

  let mut blocks : SortedMap[@ssa.Label, @ssa.Block] = SortedMap::new()
  blocks = blocks.add(entry, {
    stmts: [],
    term: @ssa.CondT(@ssa.VarE(lhs), shared, @ssa.Target(rhs_label, [])),
  })
  blocks = blocks.add(rhs_label, {
    stmts: [],
    term: @ssa.CondT(@ssa.VarE(rhs), shared, fallback_target),
  })
  blocks = blocks.add(join, {
    stmts: [],
    term: @ssa.ReturnT([@ssa.VarE(result)], None),
  })

  let recovered = recover_boolean(program_with(id_gen, blocks, entry))
  let func = recovered.funcs[0]
  guard func.blocks.get(rhs_label) is None else { panic() }
  match func.blocks[entry].term {
    @ssa.CondT(
      @ssa.OrE(@ssa.VarE(actual_lhs), @ssa.VarE(actual_rhs)),
      @ssa.Target(actual_join, [@ssa.VarE(actual_arg)]),
      @ssa.Target(actual_fallback_join, [@ssa.VarE(actual_fallback)])
    ) => {
      guard actual_lhs == lhs else { panic() }
      guard actual_rhs == rhs else { panic() }
      guard actual_join == join else { panic() }
      guard actual_arg == arg else { panic() }
      guard actual_fallback_join == join else { panic() }
      guard actual_fallback == fallback else { panic() }
    }
    _ => panic()
  }
}

///|
test "recover folds guard chain with equivalent empty return targets" {
  let id_gen = @ssa.IdGen()
  let entry = fresh_label(id_gen)
  let rhs_label = fresh_label(id_gen)
  let third_label = fresh_label(id_gen)
  let body_label = fresh_label(id_gen)
  let return_a = fresh_label(id_gen)
  let return_b = fresh_label(id_gen)
  let return_c = fresh_label(id_gen)
  let lhs = fresh_var(id_gen)
  let rhs = fresh_var(id_gen)
  let third = fresh_var(id_gen)
  let result = fresh_var(id_gen)

  let mut blocks : SortedMap[@ssa.Label, @ssa.Block] = SortedMap::new()
  blocks = blocks.add(entry, {
    stmts: [],
    term: @ssa.CondT(
      @ssa.VarE(lhs),
      @ssa.Target(rhs_label, []),
      @ssa.Target(return_a, []),
    ),
  })
  blocks = blocks.add(rhs_label, {
    stmts: [],
    term: @ssa.CondT(
      @ssa.VarE(rhs),
      @ssa.Target(third_label, []),
      @ssa.Target(return_b, []),
    ),
  })
  blocks = blocks.add(third_label, {
    stmts: [],
    term: @ssa.CondT(
      @ssa.VarE(third),
      @ssa.Target(body_label, []),
      @ssa.Target(return_c, []),
    ),
  })
  blocks = blocks.add(body_label, {
    stmts: [],
    term: @ssa.ReturnT([@ssa.VarE(result)], None),
  })
  blocks = blocks.add(return_a, { stmts: [], term: @ssa.ReturnT([], None) })
  blocks = blocks.add(return_b, { stmts: [], term: @ssa.ReturnT([], None) })
  blocks = blocks.add(return_c, { stmts: [], term: @ssa.ReturnT([], None) })

  let recovered = recover_boolean(program_with(id_gen, blocks, entry))
  let func = recovered.funcs[0]
  guard func.blocks.get(rhs_label) is None else { panic() }
  guard func.blocks.get(third_label) is None else { panic() }
  match func.blocks[entry].term {
    @ssa.CondT(
      @ssa.AndE(
        @ssa.AndE(@ssa.VarE(actual_lhs), @ssa.VarE(actual_rhs)),
        @ssa.VarE(actual_third)
      ),
      @ssa.Target(actual_body, []),
      @ssa.Target(actual_return, [])
    ) => {
      guard actual_lhs == lhs else { panic() }
      guard actual_rhs == rhs else { panic() }
      guard actual_third == third else { panic() }
      guard actual_body == body_label else { panic() }
      guard actual_return == return_a else { panic() }
    }
    _ => panic()
  }
}

///|
test "recover folds value branch into and expression" {
  let id_gen = @ssa.IdGen()
  let entry = fresh_label(id_gen)
  let join = fresh_label(id_gen)
  let lhs = fresh_var(id_gen)
  let rhs = fresh_var(id_gen)
  let result = fresh_var(id_gen)
  let join = { ..join, params: [result] }

  let mut blocks : SortedMap[@ssa.Label, @ssa.Block] = SortedMap::new()
  blocks = blocks.add(entry, {
    stmts: [],
    term: @ssa.CondT(
      @ssa.VarE(lhs),
      @ssa.Target(join, [@ssa.VarE(rhs)]),
      @ssa.Target(join, [@ssa.VarE(lhs)]),
    ),
  })
  blocks = blocks.add(join, {
    stmts: [],
    term: @ssa.ReturnT([@ssa.VarE(result)], None),
  })

  let recovered = recover_boolean(program_with(id_gen, blocks, entry))
  match recovered.funcs[0].blocks[entry] {
    {
      stmts: [
        @ssa.BindS(
          recovered_value,
          @ssa.AndE(@ssa.VarE(actual_lhs), @ssa.VarE(actual_rhs))
        ),
      ],
      term: @ssa.JumpT(@ssa.Target(actual_join, [@ssa.VarE(actual_arg)])),
    } => {
      guard actual_lhs == lhs else { panic() }
      guard actual_rhs == rhs else { panic() }
      guard actual_join == join else { panic() }
      guard actual_arg == recovered_value else { panic() }
    }
    _ => panic()
  }
}

///|
test "recover folds expression fallback branch into or expression" {
  let id_gen = @ssa.IdGen()
  let entry = fresh_label(id_gen)
  let join = fresh_label(id_gen)
  let cond = fresh_var(id_gen)
  let table = fresh_var(id_gen)
  let key = fresh_var(id_gen)
  let result = fresh_var(id_gen)
  let join = { ..join, params: [result] }
  let fallback = @ssa.IndexE(@ssa.VarE(table), @ssa.VarE(key))

  let mut blocks : SortedMap[@ssa.Label, @ssa.Block] = SortedMap::new()
  blocks = blocks.add(entry, {
    stmts: [],
    term: @ssa.CondT(
      @ssa.VarE(cond),
      @ssa.Target(join, [@ssa.VarE(cond)]),
      @ssa.Target(join, [fallback]),
    ),
  })
  blocks = blocks.add(join, {
    stmts: [],
    term: @ssa.ReturnT([@ssa.VarE(result)], None),
  })

  let recovered = recover_boolean(program_with(id_gen, blocks, entry))
  match recovered.funcs[0].blocks[entry] {
    {
      stmts: [
        @ssa.BindS(
          recovered_value,
          @ssa.OrE(
            @ssa.VarE(actual_cond),
            @ssa.IndexE(@ssa.VarE(actual_table), @ssa.VarE(actual_key))
          )
        ),
      ],
      term: @ssa.JumpT(@ssa.Target(actual_join, [@ssa.VarE(actual_arg)])),
    } => {
      guard actual_cond == cond else { panic() }
      guard actual_table == table else { panic() }
      guard actual_key == key else { panic() }
      guard actual_join == join else { panic() }
      guard actual_arg == recovered_value else { panic() }
    }
    _ => panic()
  }
}

///|
test "recover folds truthy else value selected by negated condition into or expression" {
  let id_gen = @ssa.IdGen()
  let entry = fresh_label(id_gen)
  let join = fresh_label(id_gen)
  let side = fresh_var(id_gen)
  let teammate = fresh_var(id_gen)
  let fallback = fresh_var(id_gen)
  let default = fresh_var(id_gen)
  let result = fresh_var(id_gen)
  let join = { ..join, params: [result] }
  let cond = @ssa.OrE(
    @ssa.BinaryE(Neq, @ssa.VarE(side), @ssa.VarE(teammate)),
    @ssa.UnaryE(Not, @ssa.VarE(fallback)),
  )

  let mut blocks : SortedMap[@ssa.Label, @ssa.Block] = SortedMap::new()
  blocks = blocks.add(entry, {
    stmts: [],
    term: @ssa.CondT(
      cond,
      @ssa.Target(join, [@ssa.VarE(default)]),
      @ssa.Target(join, [@ssa.VarE(fallback)]),
    ),
  })
  blocks = blocks.add(join, {
    stmts: [],
    term: @ssa.ReturnT([@ssa.VarE(result)], None),
  })

  let recovered = recover_boolean(program_with(id_gen, blocks, entry))
  match recovered.funcs[0].blocks[entry] {
    {
      stmts: [
        @ssa.BindS(
          recovered_value,
          @ssa.OrE(
            @ssa.AndE(
              @ssa.BinaryE(
                Eq,
                @ssa.VarE(actual_side),
                @ssa.VarE(actual_teammate)
              ),
              @ssa.VarE(actual_fallback)
            ),
            @ssa.VarE(actual_default)
          )
        ),
      ],
      term: @ssa.JumpT(@ssa.Target(actual_join, [@ssa.VarE(actual_arg)])),
    } => {
      guard actual_side == side else { panic() }
      guard actual_teammate == teammate else { panic() }
      guard actual_fallback == fallback else { panic() }
      guard actual_default == default else { panic() }
      guard actual_join == join else { panic() }
      guard actual_arg == recovered_value else { panic() }
    }
    _ => panic()
  }
}

///|
test "recover folds boolean bridge values into condition" {
  let id_gen = @ssa.IdGen()
  let entry = fresh_label(id_gen)
  let true_bridge = fresh_label(id_gen)
  let false_bridge = fresh_label(id_gen)
  let join = fresh_label(id_gen)
  let cond = fresh_var(id_gen)
  let true_value = fresh_var(id_gen)
  let false_value = fresh_var(id_gen)
  let result = fresh_var(id_gen)
  let join = { ..join, params: [result] }

  let mut blocks : SortedMap[@ssa.Label, @ssa.Block] = SortedMap::new()
  blocks = blocks.add(entry, {
    stmts: [],
    term: @ssa.CondT(
      @ssa.VarE(cond),
      @ssa.Target(true_bridge, []),
      @ssa.Target(false_bridge, []),
    ),
  })
  blocks = blocks.add(true_bridge, {
    stmts: [@ssa.BindS(true_value, @ssa.ConstE(Boolean(true)))],
    term: @ssa.JumpT(@ssa.Target(join, [@ssa.VarE(true_value)])),
  })
  blocks = blocks.add(false_bridge, {
    stmts: [@ssa.BindS(false_value, @ssa.ConstE(Boolean(false)))],
    term: @ssa.JumpT(@ssa.Target(join, [@ssa.VarE(false_value)])),
  })
  blocks = blocks.add(join, {
    stmts: [],
    term: @ssa.ReturnT([@ssa.VarE(result)], None),
  })

  let recovered = recover_boolean(program_with(id_gen, blocks, entry))
  let func = recovered.funcs[0]
  guard func.blocks.get(true_bridge) is None else { panic() }
  guard func.blocks.get(false_bridge) is None else { panic() }
  match func.blocks[entry] {
    {
      stmts: [@ssa.BindS(recovered_value, @ssa.VarE(actual_cond))],
      term: @ssa.JumpT(@ssa.Target(actual_join, [@ssa.VarE(actual_arg)])),
    } => {
      guard actual_cond == cond else { panic() }
      guard actual_join == join else { panic() }
      guard actual_arg == recovered_value else { panic() }
    }
    _ => panic()
  }
}
