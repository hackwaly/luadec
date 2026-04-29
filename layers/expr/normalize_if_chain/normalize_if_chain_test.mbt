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
fn normalize_render(body : @expr.Program) -> String {
  @expr/render.render(normalize_if_chain(body))
}

///|
test "expr normalize_if_chain flattens inverted nested elseif chain" {
  let side = value(0)
  let atk = value(1)
  let def = value(2)
  let multi = value(3)
  let body : @expr.Program = [
    @expr.IfS(
      [
        (
          @expr.BinaryE(Neq, @expr.VarE(side), @expr.VarE(atk)),
          [
            @expr.IfS(
              [
                (
                  @expr.BinaryE(Neq, @expr.VarE(side), @expr.VarE(def)),
                  [
                    @expr.IfS(
                      [
                        (
                          @expr.BinaryE(Eq, @expr.VarE(side), @expr.VarE(multi)),
                          [@expr.ReturnS([int(3)], None)],
                        ),
                      ],
                      None,
                    ),
                  ],
                ),
              ],
              Some([@expr.ReturnS([int(2)], None)]),
            ),
          ],
        ),
      ],
      Some([@expr.ReturnS([int(1)], None)]),
    ),
  ]

  inspect(
    normalize_render(body),
    content=(
      #|if v0 == v1 then
      #|  return 1
      #|elseif v0 == v2 then
      #|  return 2
      #|elseif v0 == v3 then
      #|  return 3
      #|end
    ),
  )
}

///|
test "expr normalize_if_chain preserves assignment selection as elseif chain" {
  let side = value(0)
  let atk = value(1)
  let def = value(2)
  let multi = value(3)
  let target = cell(4)
  let default = value(5)
  let atk_team = value(6)
  let def_team = value(7)
  let multi_team = value(8)
  let body : @expr.Program = [
    @expr.IfS(
      [
        (
          @expr.BinaryE(Neq, @expr.VarE(side), @expr.VarE(atk)),
          [
            @expr.IfS(
              [
                (
                  @expr.BinaryE(Neq, @expr.VarE(side), @expr.VarE(def)),
                  [
                    @expr.IfS(
                      [
                        (
                          @expr.BinaryE(
                            Neq,
                            @expr.VarE(side),
                            @expr.VarE(multi),
                          ),
                          [
                            @expr.ParallelAssignS([target], [
                              @expr.VarE(default),
                            ]),
                          ],
                        ),
                      ],
                      Some([
                        @expr.ParallelAssignS([target], [@expr.VarE(multi_team)]),
                      ]),
                    ),
                  ],
                ),
              ],
              Some([@expr.ParallelAssignS([target], [@expr.VarE(def_team)])]),
            ),
          ],
        ),
      ],
      Some([@expr.ParallelAssignS([target], [@expr.VarE(atk_team)])]),
    ),
  ]

  inspect(
    normalize_render(body),
    content=(
      #|if v0 == v1 then
      #|  c4 = v6
      #|elseif v0 == v2 then
      #|  c4 = v7
      #|elseif v0 == v3 then
      #|  c4 = v8
      #|else
      #|  c4 = v5
      #|end
    ),
  )
}
