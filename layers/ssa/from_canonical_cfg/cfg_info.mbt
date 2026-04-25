///|
struct CfgInfo {
  labels : Array[@canonical_cfg.Label]
  succs : Map[@canonical_cfg.Label, Array[@canonical_cfg.Label]]
  preds : Map[@canonical_cfg.Label, Array[@canonical_cfg.Label]]
} derive(Debug)

///|
fn successor_labels(term : @canonical_cfg.Term) -> Array[@canonical_cfg.Label] {
  match term {
    @canonical_cfg.JumpT(label) => [label]
    @canonical_cfg.CondT(_, true_label, false_label) =>
      [true_label, false_label]
    @canonical_cfg.ReturnT(_, _) => []
  }
}

///|
fn build_cfg_info(func : @canonical_cfg.Func) -> CfgInfo {
  let labels : Array[@canonical_cfg.Label] = []
  let succs : Map[@canonical_cfg.Label, Array[@canonical_cfg.Label]] = {}
  let preds : Map[@canonical_cfg.Label, Array[@canonical_cfg.Label]] = {}
  let visited : Map[@canonical_cfg.Label, Bool] = {}
  let worklist : Array[@canonical_cfg.Label] = [func.entry]
  while worklist.pop() is Some(label) {
    if visited.get(label) is Some(true) {
      continue
    }
    visited[label] = true
    labels.push(label)
    match func.blocks.get(label) {
      Some(block) => {
        let nexts = successor_labels(block.term)
        succs[label] = nexts
        match preds.get(label) {
          Some(_) => ()
          None => preds[label] = []
        }
        for next in nexts {
          match preds.get(next) {
            Some(items) => items.push(label)
            None => preds[next] = [label]
          }
          if visited.get(next) is None {
            worklist.push(next)
          }
        }
      }
      None => panic()
    }
  }
  for label in labels {
    match succs.get(label) {
      Some(_) => ()
      None => succs[label] = []
    }
    match preds.get(label) {
      Some(_) => ()
      None => preds[label] = []
    }
  }
  { labels, succs, preds }
}
