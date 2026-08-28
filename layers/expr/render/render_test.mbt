///|
fn int_expr(value : Int) -> @expr.Expr {
  @expr.ConstE(Integer(value.to_int64()))
}

///|
test "render named program" {
  let id_gen = @ssa.IdGen::IdGen()
  let value : @ssa.Var = { id: id_gen.next(), }
  let cell : @ssa.Cell = { id: id_gen.next(), }
  let program : @expr.Program = [
    @expr.LocalS([cell], [@expr.VarE(value)]),
    @expr.ReturnS([@expr.CellE(cell)], None),
  ]
  let vars : Map[@ssa.Var, String] = Map([])
  vars[value] = "input"
  let cells : Map[@ssa.Cell, String] = Map([])
  cells[cell] = "result"
  let named : @expr.NamedProgram = { program, names: { vars, cells, }, }

  inspect(
    render_named(named),
    content=(
      #|local result = input
      #|return result
    ),
  )
}

///|
test "render block with local assign if and while" {
  let id_gen = @ssa.IdGen::IdGen()
  let cell : @ssa.Cell = { id: id_gen.next(), }
  let program : @expr.Program = [
    @expr.LocalS([cell], []),
    @expr.ParallelAssignS([cell], [int_expr(0)]),
    @expr.IfS(
      [
        (
          @expr.BinaryE(Lt, @expr.CellE(cell), int_expr(3)),
          [
            @expr.ParallelAssignS([cell], [
              @expr.BinaryE(Add, @expr.CellE(cell), int_expr(1)),
            ]),
          ],
        ),
      ],
      Some([@expr.BreakS]),
    ),
    @expr.WhileS(@expr.ConstE(Boolean(true)), [@expr.ReturnS([], None)]),
  ]

  inspect(
    render(program),
    content=(
      #|local c0
      #|c0 = 0
      #|if c0 < 3 then
      #|  c0 = c0 + 1
      #|else
      #|  break
      #|end
      #|while true do
      #|  return
      #|end
    ),
  )
}

///|
test "render closure call and global field syntax" {
  let id_gen = @ssa.IdGen::IdGen()
  let param : @ssa.Var = { id: id_gen.next(), }
  let callee = @expr.IndexE(
    @expr.CellE(@ssa.Cell::env()),
    @expr.ConstE(AsciiString("print", is_valid_identifier=true)),
  )
  let closure = @expr.ClosureE({
    params: [param],
    vararg: false,
    body: [
      @expr.ReturnS(
        [@expr.BinaryE(Add, @expr.VarE(param), @expr.ConstE(Integer(1L)))],
        None,
      ),
    ],
  })
  let program : @expr.Program = [
    @expr.BindMultiS([], @expr.CallM(@expr.NormalC(callee, [closure], None))),
  ]

  let expected =
    #|print(function(v0)
    #|  return v0 + 1
    #|end)
  inspect(render(program), content=expected)
}

///|
test "render generic for with multi tail" {
  let id_gen = @ssa.IdGen::IdGen()
  let key : @ssa.Var = { id: id_gen.next(), }
  let value : @ssa.Var = { id: id_gen.next(), }
  let callee : @ssa.Var = { id: id_gen.next(), }
  let program : @expr.Program = [
    @expr.GenericForS(
      [key, value],
      [],
      Some(@expr.CallM(@expr.NormalC(@expr.VarE(callee), [], None))),
      [@expr.ReturnS([], None)],
    ),
  ]

  inspect(
    render(program),
    content=(
      #|for v0, v1 in v2() do
      #|  return
      #|end
    ),
  )
}

///|
test "render named class method definition with self receiver" {
  let id_gen = @ssa.IdGen::IdGen()
  let class_var : @ssa.Var = { id: id_gen.next(), }
  let self_var : @ssa.Var = { id: id_gen.next(), }
  let arg : @ssa.Var = { id: id_gen.next(), }
  let program : @expr.Program = [
    @expr.SetIndexS(
      @expr.VarE(class_var),
      @expr.ConstE(AsciiString("init", is_valid_identifier=true)),
      @expr.ClosureE({
        params: [self_var, arg],
        vararg: false,
        body: [
          @expr.SetIndexS(
            @expr.VarE(self_var),
            @expr.ConstE(AsciiString("params", is_valid_identifier=true)),
            @expr.VarE(arg),
          ),
        ],
      }),
    ),
  ]
  let vars : Map[@ssa.Var, String] = Map([])
  vars[class_var] = "BattleBaseController"
  vars[self_var] = "self"
  let named : @expr.NamedProgram = { program, names: { vars, cells: {}, }, }

  inspect(
    render_named(named),
    content=(
      #|function BattleBaseController:init(v2)
      #|  self.params = v2
      #|end
    ),
  )
}

///|
test "render keeps closure field assignment when receiver is not self" {
  let id_gen = @ssa.IdGen::IdGen()
  let class_var : @ssa.Var = { id: id_gen.next(), }
  let receiver : @ssa.Var = { id: id_gen.next(), }
  let program : @expr.Program = [
    @expr.SetIndexS(
      @expr.VarE(class_var),
      @expr.ConstE(AsciiString("init", is_valid_identifier=true)),
      @expr.ClosureE({ params: [receiver], vararg: false, body: [], }),
    ),
  ]
  let vars : Map[@ssa.Var, String] = Map([])
  vars[class_var] = "BattleBaseController"
  let named : @expr.NamedProgram = { program, names: { vars, cells: {}, }, }

  inspect(
    render_named(named),
    content=(
      #|BattleBaseController.init = function(v1)
      #|end
    ),
  )
}
