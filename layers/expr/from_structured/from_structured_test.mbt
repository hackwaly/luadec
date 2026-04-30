///|
fn fresh_var(id_gen : @ssa.IdGen) -> @ssa.Var {
  { id: id_gen.next() }
}

///|
fn fresh_label(id_gen : @ssa.IdGen, params : Array[@ssa.Var]) -> @ssa.Label {
  { id: id_gen.next(), params }
}

///|
fn int_expr(value : Int) -> @ssa.Expr {
  @ssa.ConstE(Integer(value.to_int64()))
}

///|
fn program_with(
  id_gen : @ssa.IdGen,
  body : @structured.Region,
) -> @structured.Program {
  {
    _id_gen: id_gen,
    funcs: [{ index: 0, params: [], cells: [], vararg: false, body }],
    main: { index: 0 },
  }
}

///|
test "from_structured lowers if merge params to local cell and parallel assign" {
  let id_gen = @ssa.IdGen::IdGen()
  let cond = fresh_var(id_gen)
  let then_value = fresh_var(id_gen)
  let else_value = fresh_var(id_gen)
  let result = fresh_var(id_gen)
  let join = fresh_label(id_gen, [result])
  let body = @structured.If(
    @ssa.VarE(cond),
    @structured.Goto(@ssa.Target(join, [@ssa.VarE(then_value)])),
    Some(@structured.Goto(@ssa.Target(join, [@ssa.VarE(else_value)]))),
    (join, @structured.Return([@ssa.VarE(result)], None)),
  )

  match from_program(program_with(id_gen, body)) {
    [
      @expr.LocalS([cell], []),
      @expr.IfS(
        [
          (
            @expr.VarE(actual_cond),
            [@expr.ParallelAssignS([then_cell], [@expr.VarE(actual_then)])],
          ),
        ],
        Some([@expr.ParallelAssignS([else_cell], [@expr.VarE(actual_else)])])
      ),
      @expr.ReturnS([@expr.CellE(return_cell)], None),
    ] => {
      guard actual_cond == cond else { panic() }
      guard actual_then == then_value else { panic() }
      guard actual_else == else_value else { panic() }
      guard cell == then_cell && cell == else_cell && cell == return_cell else {
        panic()
      }
      guard cell == { id: result.id } else { panic() }
    }
    _ => panic()
  }
}

///|
test "from_structured lowers loop continue to tail assignment without redeclaring cell" {
  let id_gen = @ssa.IdGen::IdGen()
  let value = fresh_var(id_gen)
  let next = fresh_var(id_gen)
  let iter = fresh_var(id_gen)
  let header = fresh_label(id_gen, [iter])
  let body = @structured.Loop(
    header,
    [@ssa.VarE(value)],
    @structured.UnknownLS,
    @structured.Linear(
      [@ssa.BindS(next, @ssa.BinaryE(Add, @ssa.VarE(iter), int_expr(1)))],
      @structured.Goto(@ssa.Target(header, [@ssa.VarE(next)])),
    ),
    None,
  )

  match from_program(program_with(id_gen, body)) {
    [
      @expr.LocalS([cell], []),
      @expr.ParallelAssignS([init_cell], [@expr.VarE(actual_value)]),
      @expr.WhileS(
        @expr.ConstE(Boolean(true)),
        [
          @expr.BindS(
            actual_next,
            @expr.BinaryE(
              Add,
              @expr.CellE(iter_cell),
              @expr.ConstE(Integer(1L))
            )
          ),
          @expr.ParallelAssignS([next_cell], [@expr.VarE(assign_next)]),
        ]
      ),
    ] => {
      guard actual_value == value else { panic() }
      guard actual_next == next && assign_next == next else { panic() }
      guard cell == iter_cell && cell == next_cell else { panic() }
      guard init_cell == cell else { panic() }
      guard cell == { id: iter.id } else { panic() }
    }
    _ => panic()
  }
}

///|
test "from_structured lowers loop leading exit guard to while condition" {
  let id_gen = @ssa.IdGen::IdGen()
  let value = fresh_var(id_gen)
  let next = fresh_var(id_gen)
  let iter = fresh_var(id_gen)
  let limit = fresh_var(id_gen)
  let header = fresh_label(id_gen, [iter])
  let exit = fresh_label(id_gen, [])
  let exit_cond = @ssa.BinaryE(Geq, @ssa.VarE(iter), @ssa.VarE(limit))
  let body = @structured.Loop(
    header,
    [@ssa.VarE(value)],
    @structured.UnknownLS,
    @structured.Branch(
      exit_cond,
      @structured.Goto(@ssa.Target(exit, [])),
      @structured.Linear(
        [@ssa.BindS(next, @ssa.BinaryE(Add, @ssa.VarE(iter), int_expr(1)))],
        @structured.Goto(@ssa.Target(header, [@ssa.VarE(next)])),
      ),
    ),
    Some((exit, @structured.Return([], None))),
  )

  match from_program(program_with(id_gen, body)) {
    [
      @expr.LocalS([cell], []),
      @expr.ParallelAssignS([init_cell], [@expr.VarE(actual_value)]),
      @expr.WhileS(
        @expr.UnaryE(
          Not,
          @expr.BinaryE(Geq, @expr.CellE(cond_cell), @expr.VarE(actual_limit))
        ),
        [
          @expr.BindS(
            actual_next,
            @expr.BinaryE(
              Add,
              @expr.CellE(body_cell),
              @expr.ConstE(Integer(1L))
            )
          ),
          @expr.ParallelAssignS([next_cell], [@expr.VarE(assign_next)]),
        ]
      ),
      @expr.ReturnS([], None),
    ] => {
      guard actual_value == value else { panic() }
      guard actual_limit == limit else { panic() }
      guard actual_next == next && assign_next == next else { panic() }
      guard cell == init_cell &&
        cell == cond_cell &&
        cell == body_cell &&
        cell == next_cell else {
        panic()
      }
      guard cell == { id: iter.id } else { panic() }
    }
    _ => panic()
  }
}

///|
test "from_structured lowers recognized numeric for shape" {
  let id_gen = @ssa.IdGen::IdGen()
  let value = fresh_var(id_gen)
  let header = fresh_label(id_gen, [])
  let body = @structured.Loop(
    header,
    [],
    @structured.NumericForLS(value, int_expr(1), int_expr(3), int_expr(1)),
    @structured.Return([], None),
    None,
  )

  match from_program(program_with(id_gen, body)) {
    [
      @expr.NumericForS(
        actual_value,
        @expr.ConstE(Integer(1L)),
        @expr.ConstE(Integer(3L)),
        Some(@expr.ConstE(Integer(1L))),
        [@expr.ReturnS([], None)]
      ),
    ] => {
      guard actual_value == value else { panic() }
    }
    _ => panic()
  }
}

///|
test "from_structured preserves trailing empty return in function body" {
  let id_gen = @ssa.IdGen::IdGen()
  match from_program(program_with(id_gen, @structured.Return([], None))) {
    [@expr.ReturnS([], None)] => ()
    _ => panic()
  }
}

///|
test "from_structured preserves trailing empty return in closure body" {
  let id_gen = @ssa.IdGen::IdGen()
  let func_id : @ssa.FuncId = { index: 1 }
  let result = fresh_var(id_gen)
  let program : @structured.Program = {
    _id_gen: id_gen,
    funcs: [
      {
        index: 0,
        params: [],
        cells: [],
        vararg: false,
        body: @structured.Return([@ssa.ClosureE(func_id, [])], None),
      },
      {
        index: 1,
        params: [result],
        cells: [],
        vararg: false,
        body: @structured.Return([], None),
      },
    ],
    main: { index: 0 },
  }

  match from_program(program) {
    [
      @expr.ReturnS(
        [
          @expr.ClosureE(
            {
              params: [actual_param],
              vararg: false,
              body: [@expr.ReturnS([], None)],
            }
          ),
        ],
        None
      ),
    ] => {
      guard actual_param == result else { panic() }
    }
    _ => panic()
  }
}

///|
test "from_structured preserves empty return in tail continuation" {
  let id_gen = @ssa.IdGen::IdGen()
  let cond = fresh_var(id_gen)
  let cont = fresh_label(id_gen, [])
  let body = @structured.If(
    @ssa.VarE(cond),
    @structured.Goto(@ssa.Target(cont, [])),
    None,
    (cont, @structured.Return([], None)),
  )

  match from_program(program_with(id_gen, body)) {
    [@expr.IfS([(@expr.VarE(actual_cond), [])], None), @expr.ReturnS([], None)] => {
      guard actual_cond == cond else { panic() }
    }
    _ => panic()
  }
}

///|
test "from_structured lowers goto outer join with abrupt local continuation as guard" {
  let id_gen = @ssa.IdGen::IdGen()
  let outer_cond = fresh_var(id_gen)
  let inner_cond = fresh_var(id_gen)
  let inner_cont = fresh_label(id_gen, [])
  let outer_cont = fresh_label(id_gen, [])
  let body = @structured.If(
    @ssa.VarE(outer_cond),
    @structured.If(
      @ssa.VarE(inner_cond),
      @structured.Goto(@ssa.Target(outer_cont, [])),
      None,
      (inner_cont, @structured.Return([], None)),
    ),
    None,
    (outer_cont, @structured.Return([int_expr(1)], None)),
  )

  match from_program(program_with(id_gen, body)) {
    [
      @expr.IfS(
        [
          (
            @expr.VarE(actual_outer),
            [
              @expr.IfS(
                [
                  (
                    @expr.UnaryE(Not, @expr.VarE(actual_inner)),
                    [@expr.ReturnS([], None)],
                  ),
                ],
                None
              ),
            ],
          ),
        ],
        None
      ),
      @expr.ReturnS([@expr.ConstE(Integer(1L))], None),
    ] => {
      guard actual_outer == outer_cond else { panic() }
      guard actual_inner == inner_cond else { panic() }
    }
    _ => panic()
  }
}

///|
test "from_structured keeps tail continuation after fallthrough single arm if" {
  let id_gen = @ssa.IdGen::IdGen()
  let cond = fresh_var(id_gen)
  let key = fresh_var(id_gen)
  let value = fresh_var(id_gen)
  let iter = fresh_var(id_gen)
  let cont = fresh_label(id_gen, [])
  let header = fresh_label(id_gen, [])
  let body = @structured.If(
    @ssa.VarE(cond),
    @structured.Loop(
      header,
      [],
      @structured.GenericForLS([key, value], [@ssa.VarE(iter)], None),
      @structured.Goto(@ssa.Target(header, [])),
      None,
    ),
    None,
    (cont, @structured.Return([int_expr(1)], None)),
  )

  match from_program(program_with(id_gen, body)) {
    [
      @expr.IfS(
        [
          (
            @expr.VarE(actual_cond),
            [
              @expr.GenericForS(
                [actual_key, actual_value],
                [@expr.VarE(actual_iter)],
                None,
                []
              ),
            ],
          ),
        ],
        None
      ),
      @expr.ReturnS([@expr.ConstE(Integer(1L))], None),
    ] => {
      guard actual_cond == cond else { panic() }
      guard actual_key == key && actual_value == value else { panic() }
      guard actual_iter == iter else { panic() }
    }
    _ => panic()
  }
}

///|
test "from_structured preserves empty return in loop exit tail continuation" {
  let id_gen = @ssa.IdGen::IdGen()
  let header = fresh_label(id_gen, [])
  let exit = fresh_label(id_gen, [])
  let body = @structured.Loop(
    header,
    [],
    @structured.UnknownLS,
    @structured.Goto(@ssa.Target(exit, [])),
    Some((exit, @structured.Return([], None))),
  )

  match from_program(program_with(id_gen, body)) {
    [
      @expr.WhileS(@expr.ConstE(Boolean(true)), [@expr.BreakS]),
      @expr.ReturnS([], None),
    ] => ()
    _ => panic()
  }
}

///|
test "from_structured preserves empty return in numeric loop exit tail continuation" {
  let id_gen = @ssa.IdGen::IdGen()
  let value = fresh_var(id_gen)
  let header = fresh_label(id_gen, [])
  let exit = fresh_label(id_gen, [])
  let body = @structured.Loop(
    header,
    [],
    @structured.NumericForLS(value, int_expr(1), int_expr(3), int_expr(1)),
    @structured.Goto(@ssa.Target(exit, [])),
    Some((exit, @structured.Return([], None))),
  )

  match from_program(program_with(id_gen, body)) {
    [
      @expr.NumericForS(
        actual_value,
        @expr.ConstE(Integer(1L)),
        @expr.ConstE(Integer(3L)),
        Some(@expr.ConstE(Integer(1L))),
        [@expr.BreakS]
      ),
      @expr.ReturnS([], None),
    ] => {
      guard actual_value == value else { panic() }
    }
    _ => panic()
  }
}

///|
test "from_structured preserves empty return in generic loop exit tail continuation" {
  let id_gen = @ssa.IdGen::IdGen()
  let key = fresh_var(id_gen)
  let value = fresh_var(id_gen)
  let iter = fresh_var(id_gen)
  let header = fresh_label(id_gen, [])
  let exit = fresh_label(id_gen, [])
  let body = @structured.Loop(
    header,
    [],
    @structured.GenericForLS([key, value], [@ssa.VarE(iter)], None),
    @structured.Goto(@ssa.Target(exit, [])),
    Some((exit, @structured.Return([], None))),
  )

  match from_program(program_with(id_gen, body)) {
    [
      @expr.GenericForS(
        [actual_key, actual_value],
        [@expr.VarE(actual_iter)],
        None,
        [@expr.BreakS]
      ),
      @expr.ReturnS([], None),
    ] => {
      guard actual_key == key && actual_value == value else { panic() }
      guard actual_iter == iter else { panic() }
    }
    _ => panic()
  }
}

///|
test "from_structured materializes loop header params on natural exit" {
  let id_gen = @ssa.IdGen::IdGen()
  let key = fresh_var(id_gen)
  let value = fresh_var(id_gen)
  let iter = fresh_var(id_gen)
  let count = fresh_var(id_gen)
  let exit_count = fresh_var(id_gen)
  let header = fresh_label(id_gen, [count])
  let exit = fresh_label(id_gen, [exit_count])
  let body = @structured.Loop(
    header,
    [int_expr(0)],
    @structured.GenericForLS([key, value], [@ssa.VarE(iter)], None),
    @structured.Goto(@ssa.Target(header, [@ssa.VarE(count)])),
    Some((exit, @structured.Return([@ssa.VarE(exit_count)], None))),
  )

  match from_program(program_with(id_gen, body)) {
    [
      @expr.LocalS([header_cell], []),
      @expr.ParallelAssignS([init_cell], [@expr.ConstE(Integer(0L))]),
      @expr.LocalS([exit_cell], []),
      @expr.GenericForS(
        [actual_key, actual_value],
        [@expr.VarE(actual_iter)],
        None,
        []
      ),
      @expr.ParallelAssignS(
        [actual_exit_cell],
        [@expr.CellE(actual_current_cell)]
      ),
      @expr.ReturnS([@expr.CellE(return_cell)], None),
    ] => {
      guard actual_key == key && actual_value == value else { panic() }
      guard actual_iter == iter else { panic() }
      guard header_cell == init_cell else { panic() }
      guard exit_cell == actual_exit_cell && exit_cell == return_cell else {
        panic()
      }
      guard actual_current_cell == header_cell else { panic() }
    }
    _ => panic()
  }
}
