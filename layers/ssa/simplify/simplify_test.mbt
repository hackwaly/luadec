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
fn int_expr(value : Int) -> @ssa.Expr {
  @ssa.ConstE(Integer(value.to_int64()))
}

///|
test "simplify keeps parameterized forwarding blocks" {
  let id_gen = @ssa.IdGen()
  let entry = fresh_label(id_gen)
  let from_wave_time = fresh_label(id_gen)
  let carry_duration = fresh_label(id_gen)
  let merge = fresh_label(id_gen)
  let cond = fresh_var(id_gen)
  let zero = fresh_var(id_gen)
  let wave_duration = fresh_var(id_gen)
  let total_duration = fresh_var(id_gen)
  let result = fresh_var(id_gen)

  let mut blocks : SortedMap[@ssa.Label, @ssa.Block] = SortedMap::new()
  let carry_duration = { ..carry_duration, params: [result] }
  let merge = { ..merge, params: [total_duration, result] }
  blocks = blocks.add(entry, {
    stmts: [@ssa.BindS(zero, int_expr(0))],
    term: @ssa.CondT(
      @ssa.VarE(cond),
      @ssa.Target(carry_duration, [@ssa.VarE(zero)]),
      @ssa.Target(from_wave_time, []),
    ),
  })
  blocks = blocks.add(from_wave_time, {
    stmts: [],
    term: @ssa.JumpT(@ssa.Target(carry_duration, [@ssa.VarE(wave_duration)])),
  })
  blocks = blocks.add(carry_duration, {
    stmts: [],
    term: @ssa.JumpT(
      @ssa.Target(merge, [@ssa.VarE(total_duration), @ssa.VarE(result)]),
    ),
  })
  blocks = blocks.add(merge, {
    stmts: [],
    term: @ssa.ReturnT([@ssa.VarE(total_duration), @ssa.VarE(result)], None),
  })

  let program : @ssa.Program = {
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

  let simplified = simplify(program, index_as_side_effect=false)
  let simplified_func = simplified.funcs[0]
  let simplified_entry = simplified_func.blocks[simplified_func.entry]
  match simplified_entry.term {
    @ssa.CondT(
      @ssa.VarE(actual_cond),
      @ssa.Target(actual_true, [@ssa.ConstE(Integer(0L))]),
      @ssa.Target(actual_false, [@ssa.VarE(actual_wave_duration)])
    ) => {
      guard actual_cond == cond else { panic() }
      guard actual_true == carry_duration else { panic() }
      guard actual_false == carry_duration else { panic() }
      guard actual_wave_duration == wave_duration else { panic() }
    }
    _ => panic()
  }

  guard carry_duration.params.length() == 1 else { panic() }
  guard carry_duration.params[0] == result else { panic() }
}

///|
test "simplify preserves cond values also used as target args" {
  let id_gen = @ssa.IdGen()
  let entry = fresh_label(id_gen)
  let else_label = fresh_label(id_gen)
  let value = fresh_var(id_gen)
  let merged_value = fresh_var(id_gen)
  let merge = { ..fresh_label(id_gen), params: [merged_value] }

  let mut blocks : SortedMap[@ssa.Label, @ssa.Block] = SortedMap::new()
  blocks = blocks.add(entry, {
    stmts: [@ssa.BindS(value, int_expr(1))],
    term: @ssa.CondT(
      @ssa.VarE(value),
      @ssa.Target(merge, [@ssa.VarE(value)]),
      @ssa.Target(else_label, []),
    ),
  })
  blocks = blocks.add(else_label, {
    stmts: [],
    term: @ssa.JumpT(@ssa.Target(merge, [@ssa.VarE(value)])),
  })
  blocks = blocks.add(merge, {
    stmts: [],
    term: @ssa.ReturnT([@ssa.VarE(merged_value)], None),
  })

  let program : @ssa.Program = {
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

  let simplified = simplify(program, index_as_side_effect=false)
  let simplified_entry = simplified.funcs[0].blocks[entry]
  guard simplified_entry.stmts.length() == 1 else { panic() }
  match simplified_entry.term {
    @ssa.CondT(
      @ssa.VarE(actual_cond),
      @ssa.Target(actual_true, [@ssa.VarE(actual_true_arg)]),
      @ssa.Target(actual_false, [@ssa.VarE(actual_false_arg)])
    ) => {
      guard actual_cond == value else { panic() }
      guard actual_true == merge else { panic() }
      guard actual_true_arg == value else { panic() }
      guard actual_false == merge else { panic() }
      guard actual_false_arg == value else { panic() }
    }
    _ => panic()
  }
}

///|
test "simplify inlines single-use expression into jump target args" {
  let id_gen = @ssa.IdGen()
  let param = fresh_var(id_gen)
  let entry = { ..fresh_label(id_gen), params: [param] }
  let expr_pred = fresh_label(id_gen)
  let exit = fresh_label(id_gen)
  let object = fresh_var(id_gen)
  let field = fresh_var(id_gen)
  let cond = fresh_var(id_gen)
  let value = fresh_var(id_gen)

  let mut blocks : SortedMap[@ssa.Label, @ssa.Block] = SortedMap::new()
  blocks = blocks.add(entry, {
    stmts: [],
    term: @ssa.CondT(
      @ssa.VarE(cond),
      @ssa.Target(expr_pred, []),
      @ssa.Target(exit, []),
    ),
  })
  blocks = blocks.add(expr_pred, {
    stmts: [@ssa.BindS(value, @ssa.IndexE(@ssa.VarE(object), @ssa.VarE(field)))],
    term: @ssa.JumpT(@ssa.Target(entry, [@ssa.VarE(value)])),
  })
  blocks = blocks.add(exit, {
    stmts: [],
    term: @ssa.ReturnT([@ssa.VarE(param)], None),
  })

  let program : @ssa.Program = {
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

  let simplified = simplify(program, index_as_side_effect=false)
  let simplified_entry = simplified.funcs[0].blocks[entry]
  match simplified_entry.term {
    @ssa.CondT(
      @ssa.VarE(actual_cond),
      @ssa.Target(
        actual_entry,
        [@ssa.IndexE(@ssa.VarE(actual_object), @ssa.VarE(actual_field))]
      ),
      @ssa.Target(actual_exit, [])
    ) => {
      guard actual_cond == cond else { panic() }
      guard actual_entry == entry else { panic() }
      guard actual_object == object else { panic() }
      guard actual_field == field else { panic() }
      guard actual_exit == exit else { panic() }
    }
    _ => panic()
  }
}

///|
test "simplify does not inline table creation into setlist target" {
  let id_gen = @ssa.IdGen()
  let entry = fresh_label(id_gen)
  let table = fresh_var(id_gen)
  let item = fresh_var(id_gen)

  let mut blocks : SortedMap[@ssa.Label, @ssa.Block] = SortedMap::new()
  blocks = blocks.add(entry, {
    stmts: [
      @ssa.BindS(table, @ssa.TableE(EmptyTI)),
      @ssa.BindS(
        item,
        @ssa.ConstE(AsciiString("light", is_valid_identifier=false)),
      ),
      @ssa.SetListS(
        @ssa.VarE(table),
        @ssa.ConstE(Integer(0L)),
        [@ssa.VarE(item)],
        None,
      ),
    ],
    term: @ssa.ReturnT([@ssa.VarE(table)], None),
  })

  let program : @ssa.Program = {
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

  let simplified = simplify(program, index_as_side_effect=false)
  let simplified_entry = simplified.funcs[0].blocks[entry]
  match simplified_entry.stmts {
    [
      @ssa.BindS(actual_table, @ssa.TableE(EmptyTI)),
      @ssa.SetListS(
        @ssa.VarE(actual_target),
        @ssa.ConstE(Integer(0L)),
        [@ssa.ConstE(AsciiString("light", ..))],
        None
      ),
    ] => {
      guard actual_table == table else { panic() }
      guard actual_target == table else { panic() }
    }
    _ => panic()
  }
}
