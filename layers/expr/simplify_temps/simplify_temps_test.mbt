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
fn simplify_render(body : @expr.Block) -> String {
  @expr/render.render(simplify_temps(body))
}

///|
test "simplify_temps inlines adjacent local into cell assignment" {
  let tmp = value(0)
  let target = cell(1)
  inspect(
    simplify_render([
      @expr.BindS(tmp, int(1)),
      @expr.ParallelAssignS([target], [@expr.VarE(tmp)]),
    ]),
    content=(
      #|c1 = 1
    ),
  )
}

///|
test "simplify_temps inlines adjacent local into local binding" {
  let tmp = value(0)
  let target = value(1)
  inspect(
    simplify_render([
      @expr.BindS(tmp, int(1)),
      @expr.BindS(target, @expr.VarE(tmp)),
    ]),
    content=(
      #|local v1 = 1
    ),
  )
}

///|
test "simplify_temps repeats until return temp is inlined" {
  let first = value(0)
  let second = value(1)
  inspect(
    simplify_render([
      @expr.BindS(first, @expr.BinaryE(Lt, @expr.VarE(value(2)), int(10))),
      @expr.BindS(second, @expr.VarE(first)),
      @expr.ReturnS([@expr.VarE(second)], None),
    ]),
    content=(
      #|return v2 < 10
    ),
  )
}

///|
test "simplify_temps keeps call temp before return to preserve multivalue" {
  let tmp = value(0)
  let callee = value(1)
  inspect(
    simplify_render([
      @expr.BindS(tmp, @expr.CallE(@expr.NormalC(@expr.VarE(callee), [], None))),
      @expr.ReturnS([@expr.VarE(tmp)], None),
    ]),
    content=(
      #|local v0 = v1()
      #|return v0
    ),
  )
}

///|
test "simplify_temps keeps temp with later uses" {
  let tmp = value(0)
  let target = cell(1)
  inspect(
    simplify_render([
      @expr.BindS(tmp, int(1)),
      @expr.ParallelAssignS([target], [@expr.VarE(tmp)]),
      @expr.ReturnS([@expr.VarE(tmp)], None),
    ]),
    content=(
      #|local v0 = 1
      #|c1 = v0
      #|return v0
    ),
  )
}

///|
test "simplify_temps recurses into nested blocks" {
  let tmp = value(0)
  let target = cell(1)
  inspect(
    simplify_render([
      @expr.IfS(
        [
          (
            @expr.VarE(value(2)),
            [
              @expr.BindS(tmp, int(1)),
              @expr.ParallelAssignS([target], [@expr.VarE(tmp)]),
            ],
          ),
        ],
        None,
      ),
    ]),
    content=(
      #|if v2 then
      #|  c1 = 1
      #|end
    ),
  )
}
