///|
enum CaptureMode {
  ValueCapture
  CellCapture
} derive(Debug)

///|
struct CapturePlan {
  places : Map[@canonical_cfg.Local, CaptureMode]
} derive(Debug)

///|
struct LocalCaptureSite {
  label : @canonical_cfg.Label
  index : Int
  place : @canonical_cfg.Local
} derive(Debug)

///|
struct FreshRebindInfo {
  sites_by_place : Map[@canonical_cfg.Local, Array[FreshRebindSite]]
} derive(Debug)

///|
/// Loop protocols rebind their iteration locals on each trip around the loop.
/// These writes create a fresh binding for the next iteration instead of
/// mutating the binding seen by closures created in the current iteration.
/// Capture analysis must ignore only these exact def-sites.
struct FreshRebindSite {
  label : @canonical_cfg.Label
  index : Int
  place : @canonical_cfg.Local
} derive(Debug)

///|
fn collect_local_captures(
  program : @canonical_cfg.Program,
  func : @canonical_cfg.Func,
  cfg : CfgInfo,
) -> Array[LocalCaptureSite] {
  let items : Array[LocalCaptureSite] = []
  for label in cfg.labels {
    match func.blocks.get(label) {
      Some(block) =>
        for capture in block_captures(block) {
          let child = program.funcs[capture.callee.index]
          for up in child.upvalues {
            if up.func == { index: func.index } {
              items.push({ label, index: capture.index, place: up })
            }
          }
        }
      None => ()
    }
  }
  items
}

///|
fn nested_mutated_places(
  program : @canonical_cfg.Program,
  func : @canonical_cfg.Func,
) -> Map[@canonical_cfg.Local, Bool] {
  let mutated : Map[@canonical_cfg.Local, Bool] = {}
  for other in program.funcs {
    if other.index == func.index {
      continue
    }
    for place in func_writes(other) {
      if place.func == { index: func.index } {
        mutated[place] = true
      }
    }
  }
  mutated
}

///|
fn contains_fresh_site(
  items : Array[FreshRebindSite],
  target : FreshRebindSite,
) -> Bool {
  let mut found = false
  for item in items {
    if item.label == target.label &&
      item.place == target.place &&
      item.index == target.index {
      found = true
    }
  }
  found
}

///|
fn add_fresh_rebind_site(
  sites_by_place : Map[@canonical_cfg.Local, Array[FreshRebindSite]],
  place : @canonical_cfg.Local,
  label : @canonical_cfg.Label,
  index : Int,
) -> Unit {
  let site : FreshRebindSite = { label, place, index }
  match sites_by_place.get(place) {
    Some(sites) => if !contains_fresh_site(sites, site) { sites.push(site) }
    None => sites_by_place[place] = [site]
  }
}

///|
fn fresh_rebind_site(
  label : @canonical_cfg.Label,
  place : @canonical_cfg.Local,
  index : Int,
) -> FreshRebindSite {
  { label, place, index }
}

///|
fn is_fresh_rebind_site(
  fresh_rebinds : FreshRebindInfo,
  site : FreshRebindSite,
) -> Bool {
  match fresh_rebinds.sites_by_place.get(site.place) {
    Some(sites) => contains_fresh_site(sites, site)
    None => false
  }
}

///|
/// Recognize canonical loop protocol writes that rebind the next iteration's
/// locals. If canonical lowering changes shape, the analysis becomes
/// conservatively less precise and will fall back to CellCapture.
fn analyze_fresh_rebinds(func : @canonical_cfg.Func) -> FreshRebindInfo {
  let sites_by_place : Map[@canonical_cfg.Local, Array[FreshRebindSite]] = {}
  for label, block in func.blocks {
    match block.term {
      CondT(BinaryE(Neq, LocalE(first_slot), ConstE(Nil)), bridge, _) => {
        if block.stmts.length() == 0 {
          continue
        }
        match block.stmts[block.stmts.length() - 1] {
          AssignMultiS(slots, CallM(_, [_, LocalE(ctrl)], None)) => {
            if slots.length() == 0 || slots[0] != first_slot {
              continue
            }
            match func.blocks.get(bridge) {
              Some(
                { stmts: [AssignS(ctrl2, LocalE(first_slot2))], term: JumpT(_) }
              ) =>
                if ctrl == ctrl2 && first_slot == first_slot2 {
                  for slot in slots {
                    add_fresh_rebind_site(
                      sites_by_place,
                      slot,
                      label,
                      block.stmts.length() - 1,
                    )
                  }
                }
              _ => ()
            }
          }
          _ => ()
        }
      }
      CondT(NumericForCheckE(LocalE(index), _, _), bridge, _) =>
        match func.blocks.get(bridge) {
          Some({ stmts: [AssignS(slot, LocalE(index2))], term: JumpT(_) }) if index ==
            index2 => add_fresh_rebind_site(sites_by_place, slot, bridge, 0)
          _ => ()
        }
      _ => ()
    }
  }
  { sites_by_place, }
}

///|
fn block_or_descendants_write_place(
  func : @canonical_cfg.Func,
  cfg : CfgInfo,
  fresh_rebinds : FreshRebindInfo,
  start : @canonical_cfg.Label,
  place : @canonical_cfg.Local,
) -> Bool {
  let visited : Map[@canonical_cfg.Label, Bool] = {}
  let worklist : Array[@canonical_cfg.Label] = [start]
  while worklist.pop() is Some(label) {
    if visited.get(label) is Some(true) {
      continue
    }
    visited[label] = true
    match func.blocks.get(label) {
      Some(block) =>
        for def in block_defs(block) {
          if def.place == place &&
            !is_fresh_rebind_site(
              fresh_rebinds,
              fresh_rebind_site(label, place, def.index),
            ) {
            return true
          }
        }
      None => ()
    }
    match cfg.succs.get(label) {
      Some(nexts) =>
        for next in nexts {
          if visited.get(next) is None {
            worklist.push(next)
          }
        }
      None => ()
    }
  }
  false
}

///|
fn has_owner_write_after_capture(
  func : @canonical_cfg.Func,
  cfg : CfgInfo,
  fresh_rebinds : FreshRebindInfo,
  label : @canonical_cfg.Label,
  index : Int,
  place : @canonical_cfg.Local,
) -> Bool {
  match func.blocks.get(label) {
    Some(block) => {
      for def in block_defs(block) {
        if def.place == place &&
          def.index >= index &&
          !is_fresh_rebind_site(
            fresh_rebinds,
            fresh_rebind_site(label, place, def.index),
          ) {
          return true
        }
      }
      match cfg.succs.get(label) {
        Some(nexts) =>
          for next in nexts {
            if block_or_descendants_write_place(
                func, cfg, fresh_rebinds, next, place,
              ) {
              return true
            }
          }
        None => ()
      }
      false
    }
    None => false
  }
}

///|
fn analyze_capture_plan(
  program : @canonical_cfg.Program,
  func : @canonical_cfg.Func,
  cfg : CfgInfo,
) -> CapturePlan {
  let plan : Map[@canonical_cfg.Local, CaptureMode] = {}
  let mutated_by_inner = nested_mutated_places(program, func)
  let fresh_rebinds = analyze_fresh_rebinds(func)
  for capture in collect_local_captures(program, func, cfg) {
    if mutated_by_inner.get(capture.place) is Some(true) {
      plan[capture.place] = CellCapture
      continue
    }
    if has_owner_write_after_capture(
        func,
        cfg,
        fresh_rebinds,
        capture.label,
        capture.index,
        capture.place,
      ) {
      plan[capture.place] = CellCapture
    } else {
      match plan.get(capture.place) {
        Some(CellCapture) => ()
        _ => plan[capture.place] = ValueCapture
      }
    }
  }
  { places: plan }
}
