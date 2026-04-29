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
fn cell(value : Int) -> @ssa.Cell {
  { id: nth_id(@ssa.IdGen(), value) }
}

///|
fn int(value : Int) -> @expr.Expr {
  @expr.ConstE(Integer(value.to_int64()))
}

///|
fn bool(value : Bool) -> @expr.Expr {
  @expr.ConstE(Boolean(value))
}

///|
fn normalize_render(body : @expr.Program) -> String {
  @expr/render.render(normalize_if(body))
}

///|
test "expr normalize_if folds direct return branch into guard" {
  let cond = value(0)
  let body : @expr.Program = [
    @expr.IfS(
      [(@expr.VarE(cond), [@expr.ReturnS([bool(false)], None)])],
      Some([@expr.BindS(value(1), int(1)), @expr.ReturnS([bool(true)], None)]),
    ),
  ]

  inspect(
    normalize_render(body),
    content=(
      #|if v0 then
      #|  return false
      #|end
      #|local v1 = 1
      #|return true
    ),
  )
}

///|
test "expr normalize_if prefers positive equality in return chains" {
  let side = value(0)
  let body : @expr.Program = [
    @expr.IfS(
      [
        (
          @expr.BinaryE(Neq, @expr.VarE(side), int(1)),
          [@expr.ReturnS([int(2)], None)],
        ),
      ],
      Some([@expr.ReturnS([int(1)], None)]),
    ),
  ]

  inspect(
    normalize_render(body),
    content=(
      #|if v0 == 1 then
      #|  return 1
      #|end
      #|return 2
    ),
  )
}

///|
test "expr normalize_if inverts empty then with else body" {
  let cond = value(0)
  let target = cell(1)
  let body : @expr.Program = [
    @expr.IfS(
      [(@expr.UnaryE(Not, @expr.VarE(cond)), [])],
      Some([@expr.ParallelAssignS([target], [int(1)])]),
    ),
  ]

  inspect(
    normalize_render(body),
    content=(
      #|if v0 then
      #|  c1 = 1
      #|end
    ),
  )
}

///|
test "expr normalize_if pulls returning else into inverted guard" {
  let cond = value(0)
  let target = cell(1)
  let body : @expr.Program = [
    @expr.IfS(
      [(@expr.VarE(cond), [@expr.ParallelAssignS([target], [int(1)])])],
      Some([@expr.ReturnS([], None)]),
    ),
  ]

  inspect(
    normalize_render(body),
    content=(
      #|if not v0 then
      #|  return
      #|end
      #|c1 = 1
    ),
  )
}

///|
test "expr normalize_if turns break branch with else into guard" {
  let cond = value(0)
  let target = cell(1)
  let body : @expr.Program = [
    @expr.WhileS(@expr.ConstE(Boolean(true)), [
      @expr.IfS(
        [(@expr.VarE(cond), [@expr.BreakS])],
        Some([@expr.ParallelAssignS([target], [int(1)])]),
      ),
    ]),
  ]

  inspect(
    normalize_render(body),
    content=(
      #|while true do
      #|  if v0 then
      #|    break
      #|  end
      #|  c1 = 1
      #|end
    ),
  )
}

///|
test "expr normalize_if turns break else into inverted guard" {
  let cond = value(0)
  let target = cell(1)
  let body : @expr.Program = [
    @expr.WhileS(@expr.ConstE(Boolean(true)), [
      @expr.IfS(
        [(@expr.VarE(cond), [@expr.ParallelAssignS([target], [int(1)])])],
        Some([@expr.BreakS]),
      ),
    ]),
  ]

  inspect(
    normalize_render(body),
    content=(
      #|while true do
      #|  if not v0 then
      #|    break
      #|  end
      #|  c1 = 1
      #|end
    ),
  )
}
