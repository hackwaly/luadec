///|
fn nth_id(id_gen : @ssa.IdGen, value : Int) -> @ssa.Id {
  let mut out = id_gen.next()
  for _ in 0..<value {
    out = id_gen.next()
  }
  out
}

///|
fn value(value : Int) -> @ssa.Var {
  { id: nth_id(@ssa.IdGen(), value), }
}

///|
fn cell(value : Int) -> @ssa.Cell {
  { id: nth_id(@ssa.IdGen(), value), }
}

///|
fn int(value : Int) -> @expr.Expr {
  @expr.ConstE(Integer(value.to_int64()))
}

///|
fn bool(value : Bool) -> @expr.Expr {
  @expr.ConstE(Boolean(value))
}

///|
fn key(name : String) -> @expr.Expr {
  @expr.ConstE(AsciiString(name, is_valid_identifier=true))
}

///|
fn fold_render(body : @expr.Block) -> String {
  @expr/render.render(fold_table_init(body))
}

///|
test "fold_table_init folds local empty table field assignments" {
  let table = value(0)
  inspect(
    fold_render([
      @expr.BindS(table, @expr.TableE(@expr.ArrayTI([], None))),
      @expr.SetIndexS(@expr.VarE(table), key("total_output_hurt"), int(1)),
      @expr.SetIndexS(
        @expr.VarE(table),
        key("battle_trace_id"),
        @expr.VarE(value(1)),
      ),
      @expr.ReturnS([@expr.VarE(table)], None),
    ]),
    content=(
      #|local v0 = { total_output_hurt = 1, battle_trace_id = v1 }
      #|return v0
    ),
  )
}

///|
test "fold_table_init folds consecutive integer keys into array init" {
  let table = value(0)
  inspect(
    fold_render([
      @expr.BindS(table, @expr.TableE(@expr.EmptyTI)),
      @expr.SetIndexS(@expr.VarE(table), int(1), @expr.VarE(value(1))),
      @expr.SetIndexS(@expr.VarE(table), int(2), @expr.VarE(value(2))),
      @expr.ReturnS([@expr.VarE(table)], None),
    ]),
    content=(
      #|local v0 = { v1, v2 }
      #|return v0
    ),
  )
}

///|
test "fold_table_init keeps non-consecutive integer keys as table fields" {
  let table = value(0)
  inspect(
    fold_render([
      @expr.BindS(table, @expr.TableE(@expr.EmptyTI)),
      @expr.SetIndexS(@expr.VarE(table), int(2), @expr.VarE(value(1))),
      @expr.ReturnS([@expr.VarE(table)], None),
    ]),
    content=(
      #|local v0 = { [2] = v1 }
      #|return v0
    ),
  )
}

///|
test "fold_table_init folds cell empty table field assignments" {
  let table = cell(0)
  inspect(
    fold_render([
      @expr.LocalS([table], [@expr.TableE(@expr.EmptyTI)]),
      @expr.SetIndexS(@expr.CellE(table), key("total_output_hurt"), int(1)),
      @expr.SetIndexS(
        @expr.CellE(table),
        key("battle_trace_id"),
        @expr.VarE(value(1)),
      ),
      @expr.ReturnS([@expr.CellE(table)], None),
    ]),
    content=(
      #|local c0 = { total_output_hurt = 1, battle_trace_id = v1 }
      #|return c0
    ),
  )
}

///|
test "fold_table_init stops before field assignment that reads table" {
  let table = cell(0)
  inspect(
    fold_render([
      @expr.LocalS([table], [@expr.TableE(@expr.EmptyTI)]),
      @expr.SetIndexS(@expr.CellE(table), key("a"), int(1)),
      @expr.SetIndexS(
        @expr.CellE(table),
        key("b"),
        @expr.IndexE(@expr.CellE(table), key("a")),
      ),
      @expr.ReturnS([@expr.CellE(table)], None),
    ]),
    content=(
      #|local c0 = { a = 1 }
      #|c0.b = c0.a
      #|return c0
    ),
  )
}

///|
test "fold_table_init folds interleaved single-use table temp into field" {
  let table = value(0)
  let temp = value(1)
  inspect(
    fold_render([
      @expr.BindS(table, @expr.TableE(@expr.EmptyTI)),
      @expr.SetIndexS(@expr.VarE(table), key("chapter_id"), int(7)),
      @expr.BindS(temp, @expr.TableE(@expr.EmptyTI)),
      @expr.SetIndexS(@expr.VarE(temp), key("victory"), bool(true)),
      @expr.SetIndexS(@expr.VarE(table), key("combatReport"), @expr.VarE(temp)),
      @expr.SetIndexS(@expr.VarE(table), key("win"), bool(true)),
      @expr.ReturnS([@expr.VarE(table)], None),
    ]),
    content=(
      #|local v0 = { chapter_id = 7, combatReport = { victory = true }, win = true }
      #|return v0
    ),
  )
}

///|
test "fold_table_init keeps interleaved temp that is used after field assignment" {
  let table = value(0)
  let temp = value(1)
  inspect(
    fold_render([
      @expr.BindS(table, @expr.TableE(@expr.EmptyTI)),
      @expr.SetIndexS(@expr.VarE(table), key("chapter_id"), int(7)),
      @expr.BindS(temp, @expr.TableE(@expr.EmptyTI)),
      @expr.SetIndexS(@expr.VarE(temp), key("victory"), bool(true)),
      @expr.SetIndexS(@expr.VarE(table), key("combatReport"), @expr.VarE(temp)),
      @expr.ReturnS([@expr.VarE(table), @expr.VarE(temp)], None),
    ]),
    content=(
      #|local v0 = { chapter_id = 7 }
      #|local v1 = { victory = true }
      #|v0.combatReport = v1
      #|return v0, v1
    ),
  )
}

///|
test "fold_table_init folds nested block table assignments" {
  let table = cell(0)
  inspect(
    fold_render([
      @expr.IfS(
        [
          (
            @expr.VarE(value(1)),
            [
              @expr.LocalS([table], [@expr.TableE(@expr.EmptyTI)]),
              @expr.SetIndexS(@expr.CellE(table), key("a"), int(1)),
            ],
          ),
        ],
        None,
      ),
    ]),
    content=(
      #|if v1 then
      #|  local c0 = { a = 1 }
      #|end
    ),
  )
}

///|
test "fold_table_init recurses into set-index closure body" {
  let table = value(0)
  inspect(
    fold_render([
      @expr.SetIndexS(
        @expr.CellE(@ssa.Cell::env()),
        key("make"),
        @expr.ClosureE({
          params: [],
          vararg: false,
          body: [
            @expr.BindS(table, @expr.TableE(@expr.EmptyTI)),
            @expr.SetIndexS(@expr.VarE(table), key("a"), int(1)),
            @expr.ReturnS([@expr.VarE(table)], None),
          ],
        }),
      ),
    ]),
    content=(
      #|make = function()
      #|  local v0 = { a = 1 }
      #|  return v0
      #|end
    ),
  )
}
