///|
pub(all) struct CfgInfo {
  labels : Array[Label]
  succs : Map[Label, Array[Label]]
  preds : Map[Label, Array[Label]]
} derive(Debug)

///|
pub fn target_label(target : Target) -> Label {
  match target {
    Target(label, _) => label
  }
}

///|
fn push_unique_label(out : Array[Label], label : Label) -> Unit {
  for existing in out {
    if existing == label {
      return
    }
  }
  out.push(label)
}

///|
fn successor_labels(term : Term) -> Array[Label] {
  match term {
    JumpT(target) => [target_label(target)]
    CondT(_, true_target, false_target) => {
      let out : Array[Label] = []
      push_unique_label(out, target_label(true_target))
      push_unique_label(out, target_label(false_target))
      out
    }
    ReturnT(_, _) => []
  }
}

///|
pub fn build_cfg(func : Func) -> CfgInfo {
  let labels : Array[Label] = []
  let succs : Map[Label, Array[Label]] = Map([])
  let preds : Map[Label, Array[Label]] = Map([])
  let visited : Map[Label, Bool] = Map([])
  let worklist : Array[Label] = [func.entry]
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
            Some(items) => push_unique_label(items, label)
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
  { labels, succs, preds, }
}
