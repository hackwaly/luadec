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
fn bool(value : Bool) -> @ssa.Expr {
  @ssa.ConstE(Boolean(value))
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
fn normalize_render(body : @structured.Region) -> String {
  @structured/render.render(normalize_if(program_with(body)))
}

///|
test "normalize_if folds direct return branch into guard" {
  let cond = value(0)
  let body = @structured.Branch(
    VarE(cond),
    Return([bool(false)], None),
    Linear([BindS(value(1), int(1))], Return([bool(true)], None)),
  )

  assert_eq(
    normalize_render(body),
    (
      #|if v0 {
      #|  return false
      #|}
      #|cont B0 {
      #|  local v1 = 1
      #|  return true
      #|}
    ),
  )
}

///|
test "normalize_if prefers positive equality in return chains" {
  let side = value(0)
  let body = @structured.If(
    BinaryE(Neq, VarE(side), int(1)),
    Return([int(2)], None),
    None,
    (label(10), Return([int(1)], None)),
  )

  assert_eq(
    normalize_render(body),
    (
      #|if v0 == 1 {
      #|  return 1
      #|}
      #|cont B0 {
      #|  return 2
      #|}
    ),
  )
}

///|
test "normalize_if prunes unused continuation params" {
  let cond = value(0)
  let dead_outer = value(1)
  let dead_inner = value(2)
  let live = value(3)
  let then_effect = value(4)
  let else_effect = value(5)
  let outer_join = label(10, params=[dead_outer])
  let inner_join = label(11, params=[dead_inner])
  let body = @structured.If(
    VarE(cond),
    @structured.If(
      VarE(cond),
      Linear([BindS(then_effect, int(10))], Goto(Target(inner_join, [int(1)]))),
      Some(
        Linear(
          [BindS(else_effect, int(20))],
          Goto(Target(inner_join, [int(2)])),
        ),
      ),
      (inner_join, Goto(Target(outer_join, [VarE(dead_inner)]))),
    ),
    Some(Goto(Target(outer_join, [int(3)]))),
    (outer_join, Linear([BindS(live, int(4))], Return([VarE(live)], None))),
  )

  assert_eq(
    normalize_render(body),
    (
      #|if v0 {
      #|  if v0 {
      #|    local v4 = 10
      #|    goto B11
      #|  } else {
      #|    local v5 = 20
      #|    goto B11
      #|  }
      #|  cont B11 {
      #|    goto B10
      #|  }
      #|}
      #|cont B10 {
      #|  local v3 = 4
      #|  return v3
      #|}
    ),
  )
}

///|
test "normalize_if folds loop exit branch after loop shape recognition" {
  let header = label(10)
  let exit = label(11)
  let next = label(12)
  let cond = value(0)
  let body = @structured.Loop(
    header,
    [],
    UnknownLS,
    @structured.If(
      VarE(cond),
      Goto(Target(exit, [])),
      Some(Linear([BindS(value(1), int(1))], Goto(Target(header, [])))),
      (next, Goto(Target(header, []))),
    ),
    Some((exit, Return([], None))),
  )

  assert_eq(
    normalize_render(body),
    (
      #|loop B10 init () shape unknown {
      #|  if v0 {
      #|    goto B11
      #|  }
      #|  cont B0 {
      #|    local v1 = 1
      #|    goto B10
      #|  }
      #|}
      #|exit B11 {
      #|  return
      #|}
    ),
  )
}

///|
test "normalize_if keeps loop continue in join tail" {
  let state = value(1)
  let next_state = value(2)
  let cond = value(3)
  let found = value(4)
  let header = label(20, params=[state])
  let exit = label(21)
  let join = label(22, params=[next_state])
  let body = @structured.Loop(
    header,
    [int(0)],
    UnknownLS,
    @structured.If(
      VarE(cond),
      Linear([BindS(found, bool(true))], Goto(Target(exit, []))),
      Some(
        Linear(
          [BindS(next_state, BinaryE(Add, VarE(state), int(1)))],
          Goto(Target(join, [VarE(next_state)])),
        ),
      ),
      (join, Goto(Target(header, [VarE(next_state)]))),
    ),
    Some((exit, Return([], None))),
  )

  assert_eq(
    normalize_render(body),
    (
      #|loop B20(v1) init (0) shape unknown {
      #|  if v3 {
      #|    local v4 = true
      #|    goto B21
      #|  }
      #|  cont B0 {
      #|    local v2 = v1 + 1
      #|    goto B20(v2)
      #|  }
      #|}
      #|exit B21 {
      #|  return
      #|}
    ),
  )
}
