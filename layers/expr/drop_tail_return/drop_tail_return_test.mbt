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
fn bool(value : Bool) -> @expr.Expr {
  @expr.ConstE(Boolean(value))
}

///|
fn render_drop(body : @expr.Program) -> String {
  @expr/render.render(drop_tail_return(body))
}

///|
test "drop_tail_return removes function body trailing empty return" {
  inspect(
    render_drop([
      @expr.IfS(
        [(@expr.VarE(value(0)), [@expr.ReturnS([bool(true)], None)])],
        None,
      ),
      @expr.ReturnS([], None),
    ]),
    content=(
      #|if v0 then
      #|  return true
      #|end
    ),
  )
}

///|
test "drop_tail_return preserves nested block empty return" {
  inspect(
    render_drop([
      @expr.IfS([(@expr.VarE(value(0)), [@expr.ReturnS([], None)])], None),
    ]),
    content=(
      #|if v0 then
      #|  return
      #|end
    ),
  )
}

///|
test "drop_tail_return recurses into closure function body" {
  inspect(
    render_drop([
      @expr.ReturnS(
        [
          @expr.ClosureE({
            params: [],
            vararg: false,
            body: [@expr.ReturnS([], None)],
          }),
        ],
        None,
      ),
    ]),
    content=(
      #|return function()
      #|end
    ),
  )
}
