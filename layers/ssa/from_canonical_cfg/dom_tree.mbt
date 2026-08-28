///|
struct DomTree {
  entry : @canonical_cfg.Label
  idom : Map[@canonical_cfg.Label, @canonical_cfg.Label]
  preorder : Array[@canonical_cfg.Label]
} derive(Debug)

///|
fn build_dom_tree(func : @canonical_cfg.Func, cfg : CfgInfo) -> DomTree {
  let vertex : Array[@canonical_cfg.Label] = []
  let parent : Array[Int] = []
  let semi : Array[Int] = []
  let ancestor : Array[Int] = []
  let best : Array[Int] = []
  let idom_idx : Array[Int] = []
  let bucket : Array[Array[Int]] = []
  let index_of : Map[@canonical_cfg.Label, Int] = Map([])

  letrec dfs = fn(label : @canonical_cfg.Label, parent_idx : Int) -> Unit {
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

  dfs(func.entry, 0)

  if vertex.length() == 0 {
    return { entry: func.entry, idom: {}, preorder: [], }
  }

  for i = vertex.length() - 1; i >= 1; i = i - 1 {
    let w = vertex[i]
    match cfg.preds.get(w) {
      Some(preds) =>
        for v in preds {
          match index_of.get(v) {
            Some(v_idx) => {
              let u = eval(v_idx)
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

  let idom : Map[@canonical_cfg.Label, @canonical_cfg.Label] = Map([])
  idom[vertex[0]] = vertex[0]
  for i in 1..<vertex.length() {
    if idom_idx[i] != semi[i] {
      idom_idx[i] = idom_idx[idom_idx[i]]
    }
    idom[vertex[i]] = vertex[idom_idx[i]]
  }
  { entry: func.entry, idom, preorder: vertex, }
}
