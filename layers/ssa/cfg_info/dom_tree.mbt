///|
pub(all) struct DomTree {
  entry : Label
  idom : Map[Label, Label]
  preorder : Array[Label]
  pre_index : Map[Label, Int]
  post_index : Map[Label, Int]
} derive(Debug)

///|
pub fn build_dom_tree(entry : Label, cfg : CfgInfo) -> DomTree {
  let vertex : Array[Label] = []
  let parent : Array[Int] = []
  let semi : Array[Int] = []
  let ancestor : Array[Int] = []
  let best : Array[Int] = []
  let idom_idx : Array[Int] = []
  let bucket : Array[Array[Int]] = []
  let index_of : Map[Label, Int] = {}

  letrec dfs = fn(label : Label, parent_idx : Int) -> Unit {
    let idx = vertex.length()
    index_of[label] = idx
    vertex.push(label)
    parent.push(parent_idx)
    semi.push(idx)
    ancestor.push(-1)
    best.push(idx)
    idom_idx.push(-1)
    bucket.push([])
    match cfg.succs.get(label) {
      Some(nexts) =>
        for next in nexts {
          if index_of.get(next) is None {
            dfs(next, idx)
          }
        }
      None => ()
    }
  }

  letrec compress = fn(v : Int) -> Unit {
    let a = ancestor[v]
    if a >= 0 && ancestor[a] >= 0 {
      compress(a)
      if semi[best[a]] < semi[best[v]] {
        best[v] = best[a]
      }
      ancestor[v] = ancestor[a]
    }
  }

  let eval = fn(v : Int) -> Int {
    if ancestor[v] < 0 {
      v
    } else {
      compress(v)
      best[v]
    }
  }

  let link = fn(parent_idx : Int, child_idx : Int) -> Unit {
    ancestor[child_idx] = parent_idx
  }

  dfs(entry, 0)

  if vertex.length() == 0 {
    return { entry, idom: {}, preorder: [], pre_index: {}, post_index: {} }
  }

  for i = vertex.length() - 1; i >= 1; i = i - 1 {
    let w = vertex[i]
    match cfg.preds.get(w) {
      Some(preds) =>
        for pred in preds {
          match index_of.get(pred) {
            Some(pred_idx) => {
              let u = eval(pred_idx)
              if semi[u] < semi[i] {
                semi[i] = semi[u]
              }
            }
            None => ()
          }
        }
      None => ()
    }
    bucket[semi[i]].push(i)
    let p = parent[i]
    link(p, i)
    for v in bucket[p] {
      let u = eval(v)
      if semi[u] < semi[v] {
        idom_idx[v] = u
      } else {
        idom_idx[v] = p
      }
    }
    bucket[p] = []
  }

  let idom : Map[Label, Label] = {}
  idom[vertex[0]] = vertex[0]
  for i in 1..<vertex.length() {
    if idom_idx[i] != semi[i] {
      idom_idx[i] = idom_idx[idom_idx[i]]
    }
    idom[vertex[i]] = vertex[idom_idx[i]]
  }

  let children : Map[Label, Array[Label]] = {}
  for label in vertex {
    children[label] = []
  }
  for i in 1..<vertex.length() {
    let label = vertex[i]
    let parent_label = idom[label]
    children[parent_label].push(label)
  }

  let pre_index : Map[Label, Int] = {}
  let post_index : Map[Label, Int] = {}
  let mut clock = 0
  letrec stamp = fn(label : Label) -> Unit {
    pre_index[label] = clock
    clock += 1
    for child in children[label] {
      stamp(child)
    }
    post_index[label] = clock
    clock += 1
  }
  stamp(entry)
  { entry, idom, preorder: vertex, pre_index, post_index }
}

///|
pub fn dominates(dom : DomTree, lhs : Label, rhs : Label) -> Bool {
  match
    (
      dom.pre_index.get(lhs),
      dom.post_index.get(lhs),
      dom.pre_index.get(rhs),
      dom.post_index.get(rhs),
    ) {
    (Some(lhs_pre), Some(lhs_post), Some(rhs_pre), Some(rhs_post)) =>
      lhs_pre <= rhs_pre && rhs_post <= lhs_post
    _ => false
  }
}
