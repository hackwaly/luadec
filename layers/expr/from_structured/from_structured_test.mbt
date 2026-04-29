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
