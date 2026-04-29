///|
fn fresh_label(id_gen : @ssa.IdGen, params : Array[@ssa.Var]) -> @ssa.Label {
  { id: id_gen.next(), params }
}

///|
fn fresh_var(id_gen : @ssa.IdGen) -> @ssa.Var {
  { id: id_gen.next() }
}

///|
fn fresh_label_like(id_gen : @ssa.IdGen, source : @ssa.Label) -> @ssa.Label {
  let params : Array[@ssa.Var] = []
  for _ in 0..<source.params.length() {
    params.push(fresh_var(id_gen))
  }
  fresh_label(id_gen, params)
}

///|
priv struct LoweringContext {
  id_gen : @ssa.IdGen
  synthetic_exit : @ssa.Label
  dom_tree : @ssa/cfg_info.DomTree
  postdom_tree : @ssa/cfg_info.DomTree
  loop_forest : @ssa/cfg_info.LoopForest
  cfg_info : @ssa/cfg_info.CfgInfo
  blocks : SortedMap[@ssa.Label, @ssa.Block]
  conts : SortedSet[@ssa.Label]
  cont_redirects : SortedMap[@ssa.Label, @ssa.Target]
}

///|
fn target_with_label_args(label : @ssa.Label) -> @ssa.Target {
  Target(label, label.params.map(fn(param) { VarE(param) }))
}

///|
fn build_param_subst(
  params : Array[@ssa.Var],
  args : Array[@ssa.Expr],
) -> Map[@ssa.Var, @ssa.Expr] {
  guard params.length() == args.length() else { panic() }
  let subst : Map[@ssa.Var, @ssa.Expr] = {}
  for i in 0..<params.length() {
    subst[params[i]] = args[i]
  }
  subst
}

///|
priv struct SubstituteVars {
  subst : Map[@ssa.Var, @ssa.Expr]
}

///|
impl @ssa.MapVisitor for SubstituteVars with visit_Expr_VarE(self, value~) {
  match self.subst.get(value) {
    Some(expr) => expr
    None => VarE(value)
  }
}

///|
impl @ssa.MapVisitor for SubstituteVars with visit_Expr_ClosureE(
  self,
  func~,
  captures~,
) {
  let captures = captures.map(fn(capture) {
    match self.subst.get(capture) {
      Some(VarE(value)) => value
      _ => capture
    }
  })
  ClosureE(func, captures)
}

///|
impl @structured.MapVisitor for SubstituteVars with visit_Expr(self, expr) {
  match expr {
    VarE(value) => self.visit_Expr_VarE(value~)
    ClosureE(func, captures) => self.visit_Expr_ClosureE(func~, captures~)
    _ =>
      @structured.MapVisitorBase::visit_Expr(
        @structured.MapVisitorBase::MapVisitorBase(self),
        expr,
      )
  }
}

///|
fn substitute_region(
  subst : Map[@ssa.Var, @ssa.Expr],
  region : Region,
) -> Region {
  let visitor : SubstituteVars = { subst, }
  visitor.visit_Region(region)
}

///|
fn substitute_target(
  subst : Map[@ssa.Var, @ssa.Expr],
  target : @ssa.Target,
) -> @ssa.Target {
  let visitor : SubstituteVars = { subst, }
  @structured.MapVisitor::visit_Target(visitor, target)
}

///|
fn redirect_target(
  source_label : @ssa.Label,
  source_args : Array[@ssa.Expr],
  template : @ssa.Target,
) -> @ssa.Target {
  substitute_target(
    build_param_subst(source_label.params, source_args),
    template,
  )
}

///|
fn bridge_redirect_template(
  source_label : @ssa.Label,
  bridge_label : @ssa.Label,
) -> @ssa.Target {
  Target(bridge_label, source_label.params.map(fn(param) { VarE(param) }))
}

///|
fn bridge_cont_target(
  ctx : LoweringContext,
  source_label : @ssa.Label,
  bridge_label : @ssa.Label,
) -> @ssa.Target {
  let template = match ctx.cont_redirects.get(source_label) {
    Some(template) => template
    None => target_with_label_args(source_label)
  }
  redirect_target(
    source_label,
    bridge_label.params.map(fn(param) { VarE(param) }),
    template,
  )
}

///|
priv struct GotoArgCollector {
  label : @ssa.Label
  args : Array[Array[@ssa.Expr]]
  malformed : Array[Bool]
}

///|
impl @structured.IterVisitor for GotoArgCollector with visit_Region_Goto(
  self,
  target~,
) {
  let Target(label, args) = target
  if label == self.label {
    if args.length() == self.label.params.length() {
      self.args.push(args)
    } else {
      self.malformed[0] = true
    }
  }
  self.visit_Target(target)
}

///|
priv struct DefinedVarCollector {
  defined : Map[@ssa.Var, Bool]
}

///|
fn record_defined_var(
  collector : DefinedVarCollector,
  value : @ssa.Var,
) -> Unit {
  collector.defined[value] = true
}

///|
fn record_label_params(
  collector : DefinedVarCollector,
  label : @ssa.Label,
) -> Unit {
  for param in label.params {
    record_defined_var(collector, param)
  }
}

///|
fn record_loop_shape_defs(
  collector : DefinedVarCollector,
  shape : @structured.LoopShape,
) -> Unit {
  match shape {
    NumericForLS(value, _, _, _) => record_defined_var(collector, value)
    GenericForLS(values, _, _) =>
      for value in values {
        record_defined_var(collector, value)
      }
    UnknownLS => ()
  }
}

///|
impl @structured.IterVisitor for DefinedVarCollector with visit_Stmt(self, stmt) {
  match stmt {
    BindS(value, expr) => {
      record_defined_var(self, value)
      self.visit_Expr(expr)
    }
    BindMultiS(values, multi) => {
      for value in values {
        record_defined_var(self, value)
      }
      self.visit_Multi(multi)
    }
    _ => self.base().visit_Stmt(stmt)
  }
}

///|
impl @structured.IterVisitor for DefinedVarCollector with visit_Region_If(
  self,
  cond~,
  then_~,
  else_~,
  cont~,
) {
  self.visit_Expr(cond)
  self.visit_Region(then_)
  match else_ {
    Some(region) => self.visit_Region(region)
    None => ()
  }
  let (label, region) = cont
  record_label_params(self, label)
  self.visit_Region(region)
}

///|
impl @structured.IterVisitor for DefinedVarCollector with visit_Region_Loop(
  self,
  header~,
  init_args~,
  shape~,
  body~,
  exit_region~,
) {
  record_label_params(self, header)
  for arg in init_args {
    self.visit_Expr(arg)
  }
  record_loop_shape_defs(self, shape)
  self.visit_LoopShape(shape)
  self.visit_Region(body)
  match exit_region {
    Some((label, region)) => {
      record_label_params(self, label)
      self.visit_Region(region)
    }
    None => ()
  }
}

///|
priv struct VarUse {
  value : @ssa.Var
  found : Array[Bool]
}

///|
impl @structured.IterVisitor for VarUse with visit_Expr(self, expr) {
  match expr {
    VarE(value) if value == self.value => self.found[0] = true
    ClosureE(_, captures) =>
      for capture in captures {
        if capture == self.value {
          self.found[0] = true
        }
      }
    _ => self.base().visit_Expr(expr)
  }
}

///|
priv struct ExprVarUse {
  values : Map[@ssa.Var, Bool]
  found : Array[Bool]
}

///|
impl @ssa.IterVisitor for ExprVarUse with visit_Expr_VarE(self, value~) {
  if self.values.get(value) is Some(true) {
    self.found[0] = true
  }
}

///|
impl @ssa.IterVisitor for ExprVarUse with visit_Expr_ClosureE(
  self,
  func~,
  captures~,
) {
  ignore(func)
  for capture in captures {
    if self.values.get(capture) is Some(true) {
      self.found[0] = true
    }
  }
}

///|
fn expr_mentions_any(expr : @ssa.Expr, values : Map[@ssa.Var, Bool]) -> Bool {
  let found = [false]
  let visitor : ExprVarUse = { values, found }
  visitor.visit_Expr(expr)
  found[0]
}

///|
fn region_mentions_var(region : Region, value : @ssa.Var) -> Bool {
  let found = [false]
  let visitor : VarUse = { value, found }
  visitor.visit_Region(region)
  found[0]
}

///|
fn collect_goto_args(
  regions : ArrayView[Region],
  label : @ssa.Label,
) -> (Array[Array[@ssa.Expr]], Bool) {
  let collector : GotoArgCollector = { label, args: [], malformed: [false] }
  for region in regions {
    collector.visit_Region(region)
  }
  (collector.args, collector.malformed[0])
}

///|
fn collect_defined_vars(regions : ArrayView[Region]) -> Map[@ssa.Var, Bool] {
  let collector : DefinedVarCollector = { defined: {} }
  for region in regions {
    collector.visit_Region(region)
  }
  collector.defined
}

///|
fn label_params_map(label : @ssa.Label) -> Map[@ssa.Var, Bool] {
  let out : Map[@ssa.Var, Bool] = {}
  for param in label.params {
    out[param] = true
  }
  out
}

///|
fn matching_label_params_map(
  source : @ssa.Label,
  target : @ssa.Label,
) -> Map[@ssa.Var, Bool] {
  let out : Map[@ssa.Var, Bool] = {}
  let len = if source.params.length() < target.params.length() {
    source.params.length()
  } else {
    target.params.length()
  }
  for i in 0..<len {
    out[source.params[i]] = true
  }
  out
}

///|
fn expr_allowed_despite_protection(
  expr : @ssa.Expr,
  protected_values : Map[@ssa.Var, Bool],
  allowed_values : Map[@ssa.Var, Bool],
) -> Bool {
  guard expr_mentions_any(expr, protected_values) else { return true }
  match expr {
    VarE(value) => allowed_values.get(value) == Some(true)
    _ => false
  }
}

///|
fn expr_equal(lhs : @ssa.Expr, rhs : @ssa.Expr) -> Bool {
  match (lhs, rhs) {
    (VarE(lhs), VarE(rhs)) => lhs == rhs
    (ConstE(lhs), ConstE(rhs)) => lhs == rhs
    _ => false
  }
}

///|
fn common_goto_args(
  args : Array[Array[@ssa.Expr]],
  arity : Int,
) -> (Array[@ssa.Expr], Array[Bool]) {
  let common : Array[@ssa.Expr] = []
  let valid : Array[Bool] = []
  guard args.length() > 0 else { return (common, valid) }
  for i in 0..<arity {
    common.push(args[0][i])
    valid.push(true)
  }
  for edge_args in args {
    for i in 0..<arity {
      if valid[i] && !expr_equal(common[i], edge_args[i]) {
        valid[i] = false
      }
    }
  }
  (common, valid)
}

///|
priv struct DropContParams {
  old_label : @ssa.Label
  new_label : @ssa.Label
  keep_indices : Array[Int]
}

///|
impl @structured.MapVisitor for DropContParams with visit_Region_Goto(
  self,
  target~,
) {
  let Target(label, args) = target
  if label == self.old_label && args.length() == self.old_label.params.length() {
    let kept_args : Array[@ssa.Expr] = []
    for index in self.keep_indices {
      kept_args.push(args[index])
    }
    Goto(
      Target(self.new_label, kept_args.map(fn(arg) { self.visit_Expr(arg) })),
    )
  } else {
    Goto(self.visit_Target(target))
  }
}

///|
fn shrink_cont_params(
  sources : Array[Region],
  cont : (@ssa.Label, Region),
  allow_single_common : Bool,
  protected_common_values : Map[@ssa.Var, Bool],
  allowed_common_values? : Map[@ssa.Var, Bool] = {},
) -> (Array[Region], (@ssa.Label, Region)) {
  let (old_label, cont_region) = cont
  guard old_label.params.length() > 0 else { return (sources, cont) }
  let (args, malformed) = collect_goto_args(sources, old_label)
  guard !malformed && args.length() > 0 else { return (sources, cont) }
  let (common, common_valid) = common_goto_args(args, old_label.params.length())
  let defined_inside = collect_defined_vars(sources)
  let label_params = label_params_map(old_label)
  let subst : Map[@ssa.Var, @ssa.Expr] = {}
  let keep_indices : Array[Int] = []
  let kept_params : Array[@ssa.Var] = []
  for i in 0..<old_label.params.length() {
    let param = old_label.params[i]
    if !region_mentions_var(cont_region, param) {
      continue
    }
    if (allow_single_common || args.length() > 1) &&
      common_valid[i] &&
      !expr_mentions_any(common[i], defined_inside) &&
      !expr_mentions_any(common[i], label_params) &&
      expr_allowed_despite_protection(
        common[i],
        protected_common_values,
        allowed_common_values,
      ) {
      subst[param] = common[i]
    } else {
      keep_indices.push(i)
      kept_params.push(param)
    }
  }
  guard kept_params.length() < old_label.params.length() else {
    return (sources, cont)
  }
  let new_label = { ..old_label, params: kept_params }
  let dropper : DropContParams = { old_label, new_label, keep_indices }
  let new_sources = sources.map(fn(region) { dropper.visit_Region(region) })
  let new_cont_region = dropper.visit_Region(
    substitute_region(subst, cont_region),
  )
  (new_sources, (new_label, new_cont_region))
}

///|
fn shrink_if_cont_params(
  then_region : Region,
  else_region : Region,
  cont : (@ssa.Label, Region),
) -> (Region, Region, (@ssa.Label, Region)) {
  let (sources, cont) = shrink_cont_params(
    [then_region, else_region],
    cont,
    false,
    {},
  )
  (sources[0], sources[1], cont)
}

///|
fn shrink_loop_exit_params(
  header : @ssa.Label,
  body : Region,
  exit_region : (@ssa.Label, Region)?,
) -> (Region, (@ssa.Label, Region)?) {
  match exit_region {
    Some(cont) => {
      let (sources, cont) = shrink_cont_params(
        [body],
        cont,
        true,
        label_params_map(header),
        allowed_common_values=matching_label_params_map(header, cont.0),
      )
      (sources[0], Some(cont))
    }
    None => (body, None)
  }
}

///|
fn build_region(ctx : LoweringContext, label : @ssa.Label) -> Region {
  let block = ctx.blocks[label]
  let tail = match block.term {
    JumpT(next_target) => build_entry_region(ctx, next_target)
    CondT(cond, then_target, else_target) =>
      build_cond_region(ctx, label, cond, then_target, else_target)
    ReturnT(exprs, multi) => Return(exprs, multi)
  }
  if block.stmts.is_empty() {
    tail
  } else {
    Linear(block.stmts, tail)
  }
}

///|
/// Structured lowering expects `Target.args` to have been normalized by
/// `@ssa/materialize_target_args`: every edge argument should be a `VarE`.
/// The fallback binding of arbitrary expressions below keeps the function total,
/// but callers must materialize first to preserve edge-local evaluation timing.
fn build_entry_region(ctx : LoweringContext, target : @ssa.Target) -> Region {
  let Target(label, args) = target
  guard args.length() == label.params.length() else { panic() }

  if ctx.conts.contains(label) {
    let target = match ctx.cont_redirects.get(label) {
      Some(template) => redirect_target(label, args, template)
      None => Target(label, args)
    }
    return Goto(target)
  }
  if ctx.loop_forest.loops.get(label) is Some(loop_info) {
    return build_loop_region(ctx, label, args, loop_info)
  }
  let body = build_region(ctx, label)
  let bindings : Array[@ssa.Stmt] = []
  for i in 0..<args.length() {
    let param = label.params[i]
    let arg = args[i]
    match arg {
      VarE(value) if value == param => ()
      _ => bindings.push(BindS(param, arg))
    }
  }
  if bindings.is_empty() {
    body
  } else {
    match body {
      Linear(stmts, tail) => Linear([..bindings, ..stmts], tail)
      _ => Linear(bindings, body)
    }
  }
}

///|
fn lower_func(id_gen : @ssa.IdGen, func : @ssa.Func) -> Func {
  let cfg_info = @ssa/cfg_info.build_cfg(func)
  let dom_tree = @ssa/cfg_info.build_dom_tree(func.entry, cfg_info)
  let synthetic_exit : @ssa.Label = fresh_label(id_gen, [])
  let postdom_cfg = @ssa/cfg_info.build_postdom_cfg(cfg_info, synthetic_exit)
  let postdom_tree = @ssa/cfg_info.build_dom_tree(synthetic_exit, postdom_cfg)
  let loop_forest = @ssa/cfg_info.build_loop_forest(cfg_info, dom_tree)
  let ctx : LoweringContext = {
    id_gen,
    synthetic_exit,
    dom_tree,
    postdom_tree,
    loop_forest,
    cfg_info,
    blocks: func.blocks,
    conts: SortedSet::new(),
    cont_redirects: SortedMap::new(),
  }
  {
    index: func.index,
    params: func.params,
    cells: func.cells,
    vararg: func.vararg,
    body: build_entry_region(ctx, @ssa.Target(func.entry, [])),
  }
}

///|
pub fn from_ssa(program : @ssa.Program) -> Program {
  {
    _id_gen: program._id_gen,
    funcs: program.funcs.map(func => lower_func(program._id_gen, func)),
    main: program.main,
  }
}
