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

///|
test "expr normalize_if folds following return into nested guard chain" {
  let first = value(0)
  let second = value(1)
  let third = value(2)
  let v3 = value(3)
  let v4 = value(4)
  let v5 = value(5)
  let body : @expr.Program = [
    @expr.IfS(
      [
        (
          @expr.BinaryE(Neq, @expr.VarE(first), @expr.ConstE(Nil)),
          [
            @expr.BindS(v3, int(3)),
            @expr.IfS(
              [
                (
                  @expr.BinaryE(Neq, @expr.VarE(second), @expr.ConstE(Nil)),
                  [
                    @expr.BindS(v4, int(4)),
                    @expr.IfS(
                      [
                        (
                          @expr.BinaryE(
                            Neq,
                            @expr.VarE(third),
                            @expr.ConstE(Nil),
                          ),
                          [
                            @expr.BindS(v5, int(5)),
                            @expr.ReturnS([int(6)], None),
                          ],
                        ),
                      ],
                      None,
                    ),
                    @expr.ReturnS([], None),
                  ],
                ),
              ],
              None,
            ),
            @expr.ReturnS([], None),
          ],
        ),
      ],
      None,
    ),
    @expr.ReturnS([], None),
  ]

  inspect(
    normalize_render(body),
    content=(
      #|if v0 == nil then
      #|  return
      #|end
      #|local v3 = 3
      #|if v1 == nil then
      #|  return
      #|end
      #|local v4 = 4
      #|if v2 == nil then
      #|  return
      #|end
      #|local v5 = 5
      #|return 6
    ),
  )
}

///|
test "expr normalize_if lifts repeated default cell assignment through guards" {
  let cond1 = value(0)
  let cond2 = value(1)
  let cond3 = value(2)
  let target = cell(3)
  let default = value(4)
  let success = value(5)
  let body : @expr.Program = [
    @expr.IfS(
      [
        (
          @expr.VarE(cond1),
          [@expr.ParallelAssignS([target], [@expr.VarE(default)])],
        ),
      ],
      Some([
        @expr.BindS(value(6), int(6)),
        @expr.IfS(
          [
            (
              @expr.VarE(cond2),
              [@expr.ParallelAssignS([target], [@expr.VarE(default)])],
            ),
          ],
          Some([
            @expr.BindS(value(7), int(7)),
            @expr.IfS(
              [
                (
                  @expr.VarE(cond3),
                  [@expr.ParallelAssignS([target], [@expr.VarE(default)])],
                ),
              ],
              Some([@expr.ParallelAssignS([target], [@expr.VarE(success)])]),
            ),
          ]),
        ),
      ]),
    ),
    @expr.ReturnS([@expr.CellE(target)], None),
  ]

  inspect(
    normalize_render(body),
    content=(
      #|c3 = v4
      #|if not v0 then
      #|  local v6 = 6
      #|  if not v1 then
      #|    local v7 = 7
      #|    if not v2 then
      #|      c3 = v5
      #|    end
      #|  end
      #|end
      #|return c3
    ),
  )
}

///|
test "expr normalize_if does not lift default assignment with call rhs" {
  let cond = value(0)
  let target = cell(1)
  let callee = value(2)
  let body : @expr.Program = [
    @expr.IfS(
      [
        (
          @expr.VarE(cond),
          [
            @expr.BindS(value(3), int(3)),
            @expr.ParallelAssignS([target], [@expr.VarE(value(4))]),
          ],
        ),
      ],
      Some([
        @expr.ParallelAssignS([target], [
          @expr.CallE(@expr.NormalC(@expr.VarE(callee), [], None)),
        ]),
      ]),
    ),
  ]

  inspect(
    normalize_render(body),
    content=(
      #|if v0 then
      #|  local v3 = 3
      #|  c1 = v4
      #|else
      #|  c1 = v2()
      #|end
    ),
  )
}

///|
test "expr normalize_if pulls leading return branch out of elseif chain" {
  let started = value(0)
  let prepared = value(1)
  let body : @expr.Program = [
    @expr.IfS(
      [
        (@expr.VarE(started), [@expr.ReturnS([bool(false)], None)]),
        (
          @expr.VarE(prepared),
          [@expr.BindS(value(2), int(2)), @expr.ReturnS([bool(true)], None)],
        ),
      ],
      Some([@expr.BindS(value(3), int(3)), @expr.ReturnS([bool(false)], None)]),
    ),
  ]

  inspect(
    normalize_render(body),
    content=(
      #|if v0 then
      #|  return false
      #|end
      #|if v1 then
      #|  local v2 = 2
      #|  return true
      #|end
      #|local v3 = 3
      #|return false
    ),
  )
}

///|
test "expr normalize_if inverts nested return else into guards" {
  let first = value(0)
  let second = value(1)
  let body : @expr.Program = [
    @expr.IfS(
      [
        (
          @expr.VarE(first),
          [
            @expr.IfS(
              [
                (
                  @expr.VarE(second),
                  [
                    @expr.BindS(value(2), int(2)),
                    @expr.ReturnS([bool(true)], None),
                  ],
                ),
              ],
              Some([@expr.ReturnS([bool(false)], None)]),
            ),
          ],
        ),
      ],
      Some([@expr.ReturnS([bool(false)], None)]),
    ),
  ]

  inspect(
    normalize_render(body),
    content=(
      #|if not v0 then
      #|  return false
      #|end
      #|if not v1 then
      #|  return false
      #|end
      #|local v2 = 2
      #|return true
    ),
  )
}
