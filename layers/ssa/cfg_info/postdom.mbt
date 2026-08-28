///|
pub fn build_postdom_cfg(cfg : CfgInfo, synthetic_exit : Label) -> CfgInfo {
  let labels : Array[Label] = []
  let succs : Map[Label, Array[Label]] = Map([])
  let preds : Map[Label, Array[Label]] = Map([])

  for label in cfg.labels {
    labels.push(label)
    preds[label] = []
  }
  labels.push(synthetic_exit)
  preds[synthetic_exit] = []

  for label in cfg.labels {
    let local_succs = match cfg.succs.get(label) {
      Some(local_succs) => local_succs
      None => []
    }
    let nexts = if local_succs.is_empty() {
      [synthetic_exit]
    } else {
      local_succs
    }
    succs[label] = nexts
    for next in nexts {
      match preds.get(next) {
        Some(items) => items.push(label)
        None => preds[next] = [label]
      }
    }
  }
  succs[synthetic_exit] = []

  let reverse_succs : Map[Label, Array[Label]] = Map([])
  let reverse_preds : Map[Label, Array[Label]] = Map([])
  for label in labels {
    reverse_succs[label] = match preds.get(label) {
      Some(items) => items
      None => []
    }
    reverse_preds[label] = match succs.get(label) {
      Some(items) => items
      None => []
    }
  }
  { labels, succs: reverse_succs, preds: reverse_preds, }
}
