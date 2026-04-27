///|
pub(all) struct Backedge {
  source : Label
  header : Label
} derive(Debug)

///|
pub(all) struct LoopInfo {
  header : Label
  members : SortedSet[Label]
  backedges : SortedSet[Label]
  children : SortedSet[Label]
} derive(Debug)

///|
pub(all) struct LoopForest {
  loops : SortedMap[Label, LoopInfo]
  roots : SortedSet[Label]
}

///|
fn member_map(refs : Array[Label]) -> Map[Label, Bool] {
  let map : Map[Label, Bool] = {}
  for label in refs {
    map[label] = true
  }
  map
}

///|
fn label_set(refs : Array[Label]) -> SortedSet[Label] {
  let mut out : SortedSet[Label] = SortedSet::new()
  for label in refs {
    out = out.add(label)
  }
  out
}

///|
fn natural_loop_members(
  header : Label,
  sources : Array[Label],
  cfg : CfgInfo,
  dom : DomTree,
) -> Array[Label] {
  let members : Array[Label] = [header]
  let seen : Map[Label, Bool] = {}
  seen[header] = true
  let stack : Array[Label] = []
  for source in sources {
    if source != header && seen.get(source) is None {
      members.push(source)
      seen[source] = true
      stack.push(source)
    }
  }
  while stack.pop() is Some(label) {
    match cfg.preds.get(label) {
      Some(preds) =>
        for pred in preds {
          if !dominates(dom, header, pred) {
            continue
          }
          if seen.get(pred) is None {
            seen[pred] = true
            members.push(pred)
            if pred != header {
              stack.push(pred)
            }
          }
        }
      None => ()
    }
  }
  members
}

///|
pub fn find_backedges(cfg : CfgInfo, dom : DomTree) -> Array[Backedge] {
  let backedges : Array[Backedge] = []
  for source in cfg.labels {
    match cfg.succs.get(source) {
      Some(nexts) =>
        for header in nexts {
          if dominates(dom, header, source) {
            backedges.push({ source, header })
          }
        }
      None => ()
    }
  }
  backedges
}

///|
pub fn build_loop_forest(cfg : CfgInfo, dom : DomTree) -> LoopForest {
  let headers : Array[Label] = []
  let backedges_of : Array[Array[Label]] = []
  let header_index : Map[Label, Int] = {}

  for edge in find_backedges(cfg, dom) {
    match header_index.get(edge.header) {
      None => {
        let index = headers.length()
        headers.push(edge.header)
        backedges_of.push([edge.source])
        header_index[edge.header] = index
      }
      Some(index) => {
        let mut seen = false
        for backedge in backedges_of[index] {
          if backedge == edge.source {
            seen = true
          }
        }
        if !seen {
          backedges_of[index].push(edge.source)
        }
      }
    }
  }

  let members_of : Array[Array[Label]] = []
  let member_sets_of : Array[Map[Label, Bool]] = []
  for i in 0..<headers.length() {
    let members = natural_loop_members(headers[i], backedges_of[i], cfg, dom)
    members_of.push(members)
    member_sets_of.push(member_map(members))
  }

  let indices : Array[Int] = []
  for i in 0..<headers.length() {
    indices.push(i)
  }
  indices.sort_by(fn(lhs, rhs) {
    let lhs_len = members_of[lhs].length()
    let rhs_len = members_of[rhs].length()
    if lhs_len != rhs_len {
      lhs_len.compare(rhs_len)
    } else {
      headers[lhs].id.compare(headers[rhs].id)
    }
  })

  let parent : Array[Int] = []
  for _ in 0..<headers.length() {
    parent.push(-1)
  }
  for order_idx in 0..<indices.length() {
    let child = indices[order_idx]
    let child_header = headers[child]
    for parent_order in (order_idx + 1)..<indices.length() {
      let candidate = indices[parent_order]
      if member_sets_of[candidate].get(child_header) is Some(true) {
        parent[child] = candidate
        break
      }
    }
  }

  let children_of : Array[Array[Int]] = []
  for _ in 0..<headers.length() {
    children_of.push([])
  }
  for i in 0..<parent.length() {
    if parent[i] >= 0 {
      children_of[parent[i]].push(i)
    }
  }

  let mut loops : SortedMap[Label, LoopInfo] = SortedMap::new()
  for i in 0..<headers.length() {
    let child_headers : Array[Label] = []
    for child in children_of[i] {
      child_headers.push(headers[child])
    }
    loops = loops.add(headers[i], {
      header: headers[i],
      members: label_set(members_of[i]),
      backedges: label_set(backedges_of[i]),
      children: label_set(child_headers),
    })
  }

  let root_headers : Array[Label] = []
  for index in indices {
    if parent[index] == -1 {
      root_headers.push(headers[index])
    }
  }
  { loops, roots: label_set(root_headers) }
}
