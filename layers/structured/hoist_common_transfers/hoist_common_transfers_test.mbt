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
  { id: nth_id(@ssa.IdGen(), value), }
}

///|
fn label(value : Int, params? : Array[@ssa.Var] = []) -> @ssa.Label {
  { id: nth_id(@ssa.IdGen(), value), params, }
}

///|
fn int(value : Int) -> @ssa.Expr {
  @ssa.ConstE(Integer(value.to_int64()))
}

///|
fn program_with(body : @structured.Region) -> @structured.Program {
  {
    _id_gen: @ssa.IdGen(),
    funcs: [{ index: 0, params: [], cells: [], vararg: false, body, }],
    main: { index: 0, },
  }
}

///|
fn hoist_render(body : @structured.Region) -> String {
  @structured/render.render(hoist_common_transfers(program_with(body)))
}

///|
test "hoist_common_transfers moves identical branch tail goto after branch" {
  let cond = value(0)
  let effect = value(1)
  let param = value(2)
  let join = label(10, params=[param])
  let body = @structured.Branch(
    VarE(cond),
    Linear([BindS(effect, int(1))], Goto(Target(join, [int(0)]))),
    Goto(Target(join, [int(0)])),
  )

  inspect(
    hoist_render(body),
    content=(
      #|if v0 {
      #|  local v1 = 1
      #|  goto B0
      #|} else {
      #|  goto B0
      #|}
      #|cont B0 {
      #|  goto B10(0)
      #|}
    ),
  )
}

///|
test "hoist_common_transfers materializes identical external join args once" {
  let cond = value(0)
  let effect = value(1)
  let param = value(2)
  let join = label(10, params=[param])
  let cont = label(11)
  let body = @structured.If(
    VarE(cond),
    Linear([BindS(effect, int(1))], Goto(Target(join, [int(0)]))),
    Some(Goto(Target(join, [int(0)]))),
    (cont, Return([], None)),
  )

  inspect(
    hoist_render(body),
    content=(
      #|if v0 {
      #|  local v1 = 1
      #|  goto B0
      #|} else {
      #|  goto B0
      #|}
      #|cont B0 {
      #|  local v2 = 0
      #|  return
      #|}
    ),
  )
}

///|
test "hoist_common_transfers keeps different tail args inside branches" {
  let cond = value(0)
  let param = value(1)
  let join = label(10, params=[param])
  let body = @structured.Branch(
    VarE(cond),
    Goto(Target(join, [int(1)])),
    Goto(Target(join, [int(2)])),
  )

  inspect(
    hoist_render(body),
    content=(
      #|branch v0 {
      #|  goto B10(1)
      #|} else {
      #|  goto B10(2)
      #|}
    ),
  )
}

///|
test "hoist_common_transfers materializes identical join args once" {
  let cond = value(0)
  let result = value(1)
  let join = label(10, params=[result])
  let body = @structured.If(
    VarE(cond),
    Goto(Target(join, [int(1)])),
    Some(Goto(Target(join, [int(1)]))),
    (join, Return([VarE(result)], None)),
  )

  inspect(
    hoist_render(body),
    content=(
      #|if v0 {
      #|  goto B0
      #|} else {
      #|  goto B0
      #|}
      #|cont B0 {
      #|  local v1 = 1
      #|  return v1
      #|}
    ),
  )
}

///|
test "hoist_common_transfers looks through loop exit continuation" {
  let cond = value(0)
  let header = label(10)
  let exit = label(11)
  let join = label(12)
  let body = @structured.Branch(
    VarE(cond),
    @structured.Loop(
      header,
      [],
      @structured.UnknownLS,
      Goto(Target(exit, [])),
      Some((exit, Goto(Target(join, [])))),
    ),
    Goto(Target(join, [])),
  )

  inspect(
    hoist_render(body),
    content=(
      #|if v0 {
      #|  loop B10 init () shape unknown {
      #|    goto B11
      #|  }
      #|  exit B11 {
      #|    goto B0
      #|  }
      #|} else {
      #|  goto B0
      #|}
      #|cont B0 {
      #|  goto B12
      #|}
    ),
  )
}

///|
test "hoist_common_transfers replaces nested if branch tail target" {
  let cond_outer = value(0)
  let cond_inner = value(1)
  let old_join = label(10)
  let inner_join = label(11)
  let body = @structured.If(
    VarE(cond_outer),
    @structured.If(
      VarE(cond_inner),
      Goto(Target(old_join, [])),
      None,
      (inner_join, Goto(Target(old_join, []))),
    ),
    Some(Goto(Target(old_join, []))),
    (old_join, Return([], None)),
  )

  inspect(
    hoist_render(body),
    content=(
      #|if v0 {
      #|  if v1 {
      #|    goto B0
      #|  }
      #|  cont B11 {
      #|    goto B0
      #|  }
      #|} else {
      #|  goto B0
      #|}
      #|cont B0 {
      #|  return
      #|}
    ),
  )
}
