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
fn materialize_target(
  id_gen : @ssa.IdGen,
  target : @ssa.Target,
) -> (Array[@ssa.Stmt], @ssa.Target) {
  let @ssa.Target(label, args) = target
  let stmts : Array[@ssa.Stmt] = []
  let materialized_args : Array[@ssa.Expr] = []
  for arg in args {
    match arg {
      @ssa.VarE(_) => materialized_args.push(arg)
      _ => {
        let value = fresh_var(id_gen)
        stmts.push(@ssa.BindS(value, arg))
        materialized_args.push(@ssa.VarE(value))
      }
    }
  }
  (stmts, @ssa.Target(label, materialized_args))
}

///|
fn add_bridge_block(
  id_gen : @ssa.IdGen,
  out_blocks : Map[@ssa.Label, @ssa.Block],
  target : @ssa.Target,
) -> @ssa.Target {
  let (stmts, target) = materialize_target(id_gen, target)
  if stmts.is_empty() {
    target
  } else {
    let bridge = fresh_label(id_gen)
    out_blocks[bridge] = { stmts, term: @ssa.JumpT(target) }
    @ssa.Target(bridge, [])
  }
}

///|
fn materialize_block(
  id_gen : @ssa.IdGen,
  out_blocks : Map[@ssa.Label, @ssa.Block],
  block : @ssa.Block,
) -> @ssa.Block {
  match block.term {
    @ssa.JumpT(target) => {
      let (stmts, target) = materialize_target(id_gen, target)
      { stmts: [..block.stmts, ..stmts], term: @ssa.JumpT(target) }
    }
    @ssa.CondT(cond, true_target, false_target) => {
      let true_target = add_bridge_block(id_gen, out_blocks, true_target)
      let false_target = add_bridge_block(id_gen, out_blocks, false_target)
      { stmts: block.stmts, term: @ssa.CondT(cond, true_target, false_target) }
    }
    @ssa.ReturnT(_, _) => block
  }
}

///|
fn materialize_func(id_gen : @ssa.IdGen, func : @ssa.Func) -> @ssa.Func {
  let out_blocks : Map[@ssa.Label, @ssa.Block] = {}
  for label, block in func.blocks {
    out_blocks[label] = materialize_block(id_gen, out_blocks, block)
  }
  let mut sorted_blocks : SortedMap[@ssa.Label, @ssa.Block] = SortedMap::new()
  for label, block in out_blocks {
    sorted_blocks = sorted_blocks.add(label, block)
  }
  { ..func, blocks: sorted_blocks }
}

///|
/// Normalize SSA edge arguments so later structured lowering can assume every
/// `Target.args` item is a `VarE`. Non-variable jump arguments are bound in the
/// predecessor block. Conditional edges get bridge blocks because each edge may
/// need different bindings.
pub fn materialize_target_args(program : @ssa.Program) -> @ssa.Program {
  {
    _id_gen: program._id_gen,
    funcs: program.funcs.map(fn(func) {
      materialize_func(program._id_gen, func)
    }),
    main: program.main,
  }
}
