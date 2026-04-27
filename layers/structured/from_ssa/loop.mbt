///|
fn get_loop_exit(
  ctx : LoweringContext,
  loop_info : @ssa/cfg_info.LoopInfo,
) -> @ssa.Label {
  let mut label = match ctx.postdom_tree.idom.get(loop_info.header) {
    Some(label) => label
    None => ctx.synthetic_exit
  }
  while label != ctx.synthetic_exit && loop_info.members.contains(label) {
    label = match ctx.postdom_tree.idom.get(label) {
      Some(next) => next
      None => ctx.synthetic_exit
    }
  }
  label
}

///|
fn get_header_direct_loop_exit(
  ctx : LoweringContext,
  loop_info : @ssa/cfg_info.LoopInfo,
) -> @ssa.Label? {
  let exits : Array[@ssa.Label] = []
  match ctx.cfg_info.succs.get(loop_info.header) {
    Some(nexts) =>
      for next in nexts {
        if !loop_info.members.contains(next) {
          exits.push(next)
        }
      }
    None => ()
  }
  match exits {
    [exit] => Some(exit)
    _ => None
  }
}

///|
fn get_structured_loop_exit(
  ctx : LoweringContext,
  loop_info : @ssa/cfg_info.LoopInfo,
) -> @ssa.Label {
  let exit_label = get_loop_exit(ctx, loop_info)
  if exit_label != ctx.synthetic_exit {
    exit_label
  } else {
    match get_header_direct_loop_exit(ctx, loop_info) {
      Some(label) => label
      None => ctx.synthetic_exit
    }
  }
}

///|
fn build_loop_region(
  ctx : LoweringContext,
  header : @ssa.Label,
  init : Array[@ssa.Expr],
  loop_info : @ssa/cfg_info.LoopInfo,
) -> Region {
  let exit_label = get_structured_loop_exit(ctx, loop_info)
  let (body_ctx, exit_region) : (LoweringContext, (@ssa.Label, Region)?) = if exit_label ==
    ctx.synthetic_exit {
    ({ ..ctx, conts: ctx.conts.add(header).add(exit_label) }, None)
  } else if ctx.conts.contains(exit_label) {
    let bridge_label = fresh_label(ctx.id_gen, exit_label.params)
    (
      {
        ..ctx,
        conts: ctx.conts.add(header).add(exit_label).add(bridge_label),
        cont_redirects: ctx.cont_redirects.add(exit_label, bridge_label),
      },
      Some((bridge_label, Goto(target_with_label_args(exit_label)))),
    )
  } else {
    (
      { ..ctx, conts: ctx.conts.add(header).add(exit_label) },
      Some((exit_label, build_region(ctx, exit_label))),
    )
  }
  Loop(header, init, UnknownLS, build_region(body_ctx, header), exit_region)
}
