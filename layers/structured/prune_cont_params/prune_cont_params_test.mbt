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
fn prune_render(body : @structured.Region) -> String {
  @structured/render.render(prune_cont_params(program_with(body)))
}

///|
test "prune_cont_params removes unused nested if continuation params" {
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

  inspect(
    prune_render(body),
    content=(
      #|if v0 {
      #|  branch v0 {
      #|    local v4 = 10
      #|    goto B10
      #|  } else {
      #|    local v5 = 20
      #|    goto B10
      #|  }
      #|} else {
      #|  goto B10
      #|}
      #|cont B10 {
      #|  local v3 = 4
      #|  return v3
      #|}
    ),
  )
}

///|
test "prune_cont_params redirects identity forwarding continuation params" {
  let cond = value(0)
  let value_a = value(1)
  let value_b = value(2)
  let forwarded = value(3)
  let live = value(4)
  let outer = label(10, params=[live])
  let inner = label(11, params=[forwarded])
  let body = @structured.If(
    VarE(cond),
    Goto(Target(inner, [VarE(value_a)])),
    Some(Goto(Target(inner, [VarE(value_b)]))),
    (inner, Goto(Target(outer, [VarE(forwarded)]))),
  )

  inspect(
    prune_render(body),
    content=(
      #|branch v0 {
      #|  goto B10(v1)
      #|} else {
      #|  goto B10(v2)
      #|}
    ),
  )
}

///|
test "prune_cont_params keeps used continuation params" {
  let cond = value(0)
  let live = value(1)
  let join = label(10, params=[live])
  let body = @structured.If(
    VarE(cond),
    Goto(Target(join, [int(1)])),
    Some(Goto(Target(join, [int(2)]))),
    (join, Return([VarE(live)], None)),
  )

  inspect(
    prune_render(body),
    content=(
      #|if v0 {
      #|  goto B10(1)
      #|} else {
      #|  goto B10(2)
      #|}
      #|cont B10(v1) {
      #|  return v1
      #|}
    ),
  )
}

///|
test "prune_cont_params removes unused loop exit params" {
  let header = label(10)
  let exit_param = value(1)
  let exit = label(11, params=[exit_param])
  let body = @structured.Loop(
    header,
    [],
    @structured.UnknownLS,
    Goto(Target(exit, [int(1)])),
    Some((exit, Return([], None))),
  )

  inspect(
    prune_render(body),
    content=(
      #|loop B10 init () shape unknown {
      #|  goto B11
      #|}
      #|exit B11 {
      #|  return
      #|}
    ),
  )
}
