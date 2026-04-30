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
test "simplify_temps drops unused nil bindings" {
  let unused1 = value(0)
  let unused2 = value(1)
  let used = value(2)
  inspect(
    simplify_render([
      @expr.BindS(unused1, @expr.ConstE(Nil)),
      @expr.BindS(unused2, @expr.ConstE(Nil)),
      @expr.BindS(used, int(3)),
      @expr.ReturnS([@expr.VarE(used)], None),
    ]),
    content=(
      #|return 3
    ),
  )
}

///|
test "simplify_temps keeps used nil binding" {
  let used = value(0)
  inspect(
    simplify_render([
      @expr.BindS(used, @expr.ConstE(Nil)),
      @expr.ReturnS([@expr.VarE(used)], None),
    ]),
    content=(
      #|return nil
    ),
  )
}

///|
test "simplify_temps inlines nil binding with multiple uses" {
  let nil_value = value(0)
  let first = cell(1)
  let second = cell(2)
  inspect(
    simplify_render([
      @expr.BindS(nil_value, @expr.ConstE(Nil)),
      @expr.ParallelAssignS([first], [@expr.VarE(nil_value)]),
      @expr.ParallelAssignS([second], [@expr.VarE(nil_value)]),
    ]),
    content=(
      #|c1 = nil
      #|c2 = nil
    ),
  )
}

///|
test "simplify_temps keeps nil binding captured by closure body" {
  let nil_value = value(0)
  let target = cell(1)
  inspect(
    simplify_render([
      @expr.BindS(nil_value, @expr.ConstE(Nil)),
      @expr.ParallelAssignS([target], [@expr.VarE(nil_value)]),
      @expr.ReturnS(
        [
          @expr.ClosureE({
            params: [],
            vararg: false,
            body: [@expr.ReturnS([@expr.VarE(nil_value)], None)],
          }),
        ],
        None,
      ),
    ]),
    content=(
      #|local v0 = nil
      #|c1 = nil
      #|return function()
      #|  return v0
      #|end
    ),
  )
}

///|
test "simplify_temps inlines single-use cell temp assignment" {
  let source = cell(0)
  let tmp = cell(1)
  let target = cell(2)
  inspect(
    simplify_render([
      @expr.LocalS([tmp], []),
      @expr.ParallelAssignS([tmp], [@expr.CellE(source)]),
      @expr.ParallelAssignS([target], [@expr.CellE(tmp)]),
    ]),
    content=(
      #|c2 = c0
    ),
  )
}

///|
test "simplify_temps keeps cell temp with later reads" {
  let source = cell(0)
  let tmp = cell(1)
  let target = cell(2)
  inspect(
    simplify_render([
      @expr.LocalS([tmp], []),
      @expr.ParallelAssignS([tmp], [@expr.CellE(source)]),
      @expr.ParallelAssignS([target], [@expr.CellE(tmp)]),
      @expr.ReturnS([@expr.CellE(tmp)], None),
    ]),
    content=(
      #|local c1
      #|c1 = c0
      #|c2 = c1
      #|return c1
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

///|
test "simplify_temps aliases loop accumulator cell back to source" {
  let source = cell(0)
  let tmp = cell(1)
  inspect(
    simplify_render([
      @expr.LocalS([tmp], []),
      @expr.ParallelAssignS([tmp], [@expr.CellE(source)]),
      @expr.GenericForS([value(2), value(3)], [@expr.VarE(value(4))], None, [
        @expr.ParallelAssignS([tmp], [
          @expr.BinaryE(Add, @expr.CellE(tmp), int(1)),
        ]),
      ]),
      @expr.ParallelAssignS([source], [@expr.CellE(tmp)]),
    ]),
    content=(
      #|for v2, v3 in v4 do
      #|  c0 = c0 + 1
      #|end
    ),
  )
}

///|
test "simplify_temps inlines deferred single-use aliases across statements" {
  let manager = value(0)
  let event = value(1)
  let report = value(2)
  let half = value(3)
  let result = cell(4)
  inspect(
    simplify_render([
      @expr.BindS(manager, @expr.CellE(@ssa.Cell::env())),
      @expr.BindS(
        event,
        @expr.IndexE(
          @expr.IndexE(
            @expr.CellE(@ssa.Cell::env()),
            @expr.ConstE(AsciiString("BATTLE_EVENT", is_valid_identifier=true)),
          ),
          @expr.ConstE(AsciiString("BATTLE_END", is_valid_identifier=true)),
        ),
      ),
      @expr.BindS(
        report,
        @expr.IndexE(
          @expr.CellE(@ssa.Cell::env()),
          @expr.ConstE(AsciiString("combatReport", is_valid_identifier=true)),
        ),
      ),
      @expr.ParallelAssignS([result], [@expr.ConstE(Boolean(false))]),
      @expr.BindS(
        half,
        @expr.IndexE(
          @expr.CellE(@ssa.Cell::env()),
          @expr.ConstE(AsciiString("isHalfBattle", is_valid_identifier=true)),
        ),
      ),
      @expr.BindMultiS(
        [],
        @expr.CallM(
          @expr.MethodC(
            @expr.VarE(manager),
            "dispatchEvent",
            [@expr.VarE(event), @expr.VarE(report), @expr.VarE(half)],
            None,
          ),
        ),
      ),
    ]),
    content=(
      #|c4 = false
      #|_ENV:dispatchEvent(BATTLE_EVENT.BATTLE_END, combatReport, isHalfBattle)
    ),
  )
}

///|
test "simplify_temps keeps index temp when same slot is overwritten before use" {
  let obj = value(0)
  let tmp = value(1)
  let key = @expr.ConstE(AsciiString("callback", is_valid_identifier=true))
  inspect(
    simplify_render([
      @expr.BindS(tmp, @expr.IndexE(@expr.VarE(obj), key)),
      @expr.SetIndexS(@expr.VarE(obj), key, @expr.ConstE(Nil)),
      @expr.BindMultiS(
        [],
        @expr.CallM(@expr.NormalC(@expr.VarE(tmp), [], None)),
      ),
    ]),
    content=(
      #|local v1 = v0.callback
      #|v0.callback = nil
      #|v1()
    ),
  )
}

///|
test "simplify_temps does not inline deferred aliases into closure body" {
  let capture = value(0)
  inspect(
    simplify_render([
      @expr.BindS(capture, @expr.CellE(@ssa.Cell::env())),
      @expr.ReturnS(
        [
          @expr.ClosureE({
            params: [],
            vararg: false,
            body: [@expr.ReturnS([@expr.VarE(capture)], None)],
          }),
        ],
        None,
      ),
    ]),
    content=(
      #|local v0 = _ENV
      #|return function()
      #|  return v0
      #|end
    ),
  )
}
