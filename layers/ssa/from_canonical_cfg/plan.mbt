///|
struct OwnedCells {
  places : Array[@canonical_cfg.Local]
  cells : Array[Cell]
  cell_map : Map[@canonical_cfg.Local, Cell]
} derive(Debug)

///|
struct FuncPlan {
  cfg : CfgInfo
  captures : CapturePlan
  labels : Map[@canonical_cfg.Label, Label]
  cell_places : Array[@canonical_cfg.Local]
  cells : Array[Cell]
  cell_map : Map[@canonical_cfg.Local, Cell]
} derive(Debug)

///|
struct ProgramPlan {
  funcs : Array[FuncPlan]
} derive(Debug)

///|
fn contains_place(
  places : Array[@canonical_cfg.Local],
  target : @canonical_cfg.Local,
) -> Bool {
  let mut found = false
  for place in places {
    if place == target {
      found = true
    }
  }
  found
}

///|
fn build_owned_cells(
  func : @canonical_cfg.Func,
  cfg : CfgInfo,
  captures : CapturePlan,
  id_gen : IdGen,
) -> OwnedCells {
  let owned : Array[@canonical_cfg.Local] = []
  let add_owned = fn(place : @canonical_cfg.Local) -> Unit {
    match captures.places.get(place) {
      Some(CellCapture) =>
        if place.func == { index: func.index } && !contains_place(owned, place) {
          owned.push(place)
        }
      _ => ()
    }
  }

  for place in func.params {
    add_owned(place)
  }
  for label in cfg.labels {
    match func.blocks.get(label) {
      Some(block) =>
        for def in block_defs(block) {
          add_owned(def.place)
        }
      None => ()
    }
  }

  let cells : Array[Cell] = []
  let cell_map : Map[@canonical_cfg.Local, Cell] = {}
  for i in 0..<owned.length() {
    let cell : Cell = { id: id_gen.next() }
    cells.push(cell)
    cell_map[owned[i]] = cell
  }
  { places: owned, cells, cell_map }
}

///|
fn build_labels(
  cfg : CfgInfo,
  id_gen : IdGen,
) -> Map[@canonical_cfg.Label, Label] {
  let labels : Map[@canonical_cfg.Label, Label] = {}
  for label in cfg.labels {
    labels[label] = { id: id_gen.next(), params: [] }
  }
  labels
}

///|
fn plan_func(
  program : @canonical_cfg.Program,
  func : @canonical_cfg.Func,
  id_gen : IdGen,
) -> FuncPlan {
  let cfg = build_cfg_info(func)
  let captures = analyze_capture_plan(program, func, cfg)
  let owned = build_owned_cells(func, cfg, captures, id_gen)
  let labels = build_labels(cfg, id_gen)
  {
    cfg,
    captures,
    labels,
    cell_places: owned.places,
    cells: owned.cells,
    cell_map: owned.cell_map,
  }
}

///|
fn plan_program(
  program : @canonical_cfg.Program,
  id_gen : IdGen,
) -> ProgramPlan {
  { funcs: program.funcs.map(fn(func) { plan_func(program, func, id_gen) }) }
}
