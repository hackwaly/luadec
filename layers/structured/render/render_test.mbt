///|
fn nth_id(id_gen : @ssa.IdGen, value : Int) -> @ssa.Id {
  let mut out = id_gen.next()
  for _ in 0..<value {
    out = id_gen.next()
  }
  out
}

///|
fn value(value : Int) -> @ssa.Var {
  { id: nth_id(@ssa.IdGen(), value) }
}

///|
fn label(value : Int, params? : Array[@ssa.Var] = []) -> @ssa.Label {
  { id: nth_id(@ssa.IdGen(), value), params }
}

///|
fn int(value : Int) -> @ssa.Expr {
  @ssa.ConstE(Integer(value.to_int64()))
}

///|
fn program_with(body : @structured.Region) -> @structured.Program {
  {
    _id_gen: @ssa.IdGen(),
    funcs: [{ index: 0, params: [], cells: [], vararg: false, body }],
    main: { index: 0 },
  }
}

///|
test "structured render prints empty closures on one line" {
  let program : @structured.Program = {
    _id_gen: @ssa.IdGen(),
    funcs: [
      {
        index: 0,
        params: [],
        cells: [],
        vararg: false,
        body: Linear(
          [BindS(value(1), ClosureE({ index: 1 }, []))],
          Return([], None),
        ),
      },
      {
        index: 1,
        params: [value(0)],
        cells: [],
        vararg: false,
        body: Return([], None),
      },
    ],
    main: { index: 0 },
  }

  assert_eq(render(program), "local v1 = function(v0) end")
}

///|
test "structured render lowers if join params to locals and assignments" {
  let cond = value(0)
  let result = value(1)
  let join = label(10, params=[result])
  let body = @structured.If(
    VarE(cond),
    Goto(Target(join, [int(1)])),
    Some(Goto(Target(join, [int(2)]))),
    (join, Return([VarE(result)], None)),
  )

  assert_eq(
    render(program_with(body)),
    (
      #|local v1
      #|if v0 {
      #|  v1 = 1
      #|} else {
      #|  v1 = 2
      #|}
      #|return v1
    ),
  )
}

///|
test "structured render prints branch as if and suppresses tail empty return" {
  let cond = value(0)
  let body = @structured.Branch(
    VarE(cond),
    Linear([BindS(value(1), int(1))], Return([], None)),
    Linear([BindS(value(2), int(2))], Return([], None)),
  )

  assert_eq(
    render(program_with(body)),
    (
      #|if v0 {
      #|  local v1 = 1
      #|} else {
      #|  local v2 = 2
      #|}
    ),
  )
}

///|
test "structured render lowers loop carried state and exit to lua loop" {
  let state = value(0)
  let next = value(1)
  let done = value(2)
  let exit = label(30)
  let header = label(20, params=[state])
  let body = @structured.Loop(
    header,
    [int(0)],
    UnknownLS,
    @structured.If(
      VarE(done),
      Goto(Target(exit, [])),
      Some(
        Linear(
          [BindS(next, BinaryE(Add, VarE(state), int(1)))],
          Goto(Target(header, [VarE(next)])),
        ),
      ),
      (label(21), Goto(Target(header, [VarE(state)]))),
    ),
    Some((exit, Return([], None))),
  )

  assert_eq(
    render(program_with(body)),
    (
      #|local v0 = 0
      #|while true {
      #|  if v2 {
      #|    break
      #|  } else {
      #|    local v1 = v0 + 1
      #|    v0 = v1
      #|  }
      #|}
    ),
  )
}

///|
test "structured render prints recognized for loop shapes" {
  let numeric_header = label(40)
  let numeric = @structured.Loop(
    numeric_header,
    [],
    NumericForLS(value(0), int(1), int(3), int(1)),
    Goto(Target(numeric_header, [])),
    None,
  )
  assert_eq(
    render(program_with(numeric)),
    (
      #|for v0 = 1, 3 {
      #|}
    ),
  )

  let generic_header = label(41)
  let generic = @structured.Loop(
    generic_header,
    [],
    GenericForLS([value(1), value(2)], [VarE(value(3))], None),
    Goto(Target(generic_header, [])),
    None,
  )
  assert_eq(
    render(program_with(generic)),
    (
      #|for v1, v2 in v3 {
      #|}
    ),
  )
}
