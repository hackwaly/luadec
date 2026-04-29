///|
using @immut/sorted_map {type SortedMap}

///|
fn fresh_var(id_gen : @ssa.IdGen) -> @ssa.Var {
  { id: id_gen.next() }
}

///|
fn fresh_label(id_gen : @ssa.IdGen) -> @ssa.Label {
  { id: id_gen.next(), params: [] }
}

///|
fn program_with(
  id_gen : @ssa.IdGen,
  entry : @ssa.Label,
  blocks : SortedMap[@ssa.Label, @ssa.Block],
) -> @ssa.Program {
  {
    _id_gen: id_gen,
    funcs: [
      {
        index: 0,
        params: [],
        capture_vars: [],
        capture_cells: [],
        cells: [],
        vararg: false,
        blocks,
        entry,
      },
    ],
    main: { index: 0 },
  }
}

///|
test "recover_method_call drops method bind defined in predecessor block" {
  let id_gen = @ssa.IdGen::IdGen()
  let entry = fresh_label(id_gen)
  let join = fresh_label(id_gen)
  let receiver = fresh_var(id_gen)
  let method_var = fresh_var(id_gen)
  let arg = fresh_var(id_gen)
  let mut blocks : SortedMap[@ssa.Label, @ssa.Block] = SortedMap::new()
  blocks = blocks.add(entry, {
    stmts: [
      @ssa.BindS(
        method_var,
        @ssa.IndexE(
          @ssa.VarE(receiver),
          @ssa.ConstE(AsciiString("dispatchEvent", is_valid_identifier=true)),
        ),
      ),
    ],
    term: @ssa.JumpT(@ssa.Target(join, [])),
  })
  blocks = blocks.add(join, {
    stmts: [
      @ssa.BindMultiS(
        [],
        @ssa.CallM(
          @ssa.NormalC(
            @ssa.VarE(method_var),
            [@ssa.VarE(receiver), @ssa.VarE(arg)],
            None,
          ),
        ),
      ),
    ],
    term: @ssa.ReturnT([], None),
  })

  let recovered = recover_method_call(program_with(id_gen, entry, blocks))
  let func = recovered.funcs[0]
  guard func.blocks[entry].stmts.is_empty() else { panic() }
  match func.blocks[join].stmts {
    [
      @ssa.BindMultiS(
        [],
        @ssa.CallM(
          @ssa.MethodC(
            @ssa.VarE(actual_receiver),
            method_name,
            [@ssa.VarE(actual_arg)],
            None
          )
        )
      ),
    ] => {
      guard actual_receiver == receiver else { panic() }
      guard method_name == "dispatchEvent" else { panic() }
      guard actual_arg == arg else { panic() }
    }
    _ => panic()
  }
}
