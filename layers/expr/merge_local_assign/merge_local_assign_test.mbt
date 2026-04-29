///|
fn nth_id(id_gen : @ssa.IdGen, value : Int) -> @ssa.Id {
  let mut out = id_gen.next()
  for _ in 0..<value {
    out = id_gen.next()
  }
  out
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
fn merge_render(body : @expr.Block) -> String {
  @expr/render.render(merge_local_assign(body))
}

///|
test "merge_local_assign merges local cell declaration with first assignment" {
  let target = cell(0)
  inspect(
    merge_render([
      @expr.LocalS([target], []),
      @expr.ParallelAssignS([target], [int(1)]),
      @expr.ReturnS([@expr.CellE(target)], None),
    ]),
    content=(
      #|local c0 = 1
      #|return c0
    ),
  )
}

///|
test "merge_local_assign keeps assignment when initializer reads same cell" {
  let target = cell(0)
  inspect(
    merge_render([
      @expr.LocalS([target], []),
      @expr.ParallelAssignS([target], [
        @expr.BinaryE(Add, @expr.CellE(target), int(1)),
      ]),
      @expr.ReturnS([@expr.CellE(target)], None),
    ]),
    content=(
      #|local c0
      #|c0 = c0 + 1
      #|return c0
    ),
  )
}
