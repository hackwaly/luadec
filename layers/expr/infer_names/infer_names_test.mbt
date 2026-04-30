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
  { id: nth_id(@ssa.IdGen(), value) }
}

///|
fn cell(value : Int) -> @ssa.Cell {
  { id: nth_id(@ssa.IdGen(), value) }
}

///|
fn key(name : String) -> @expr.Expr {
  @expr.ConstE(AsciiString(name, is_valid_identifier=true))
}

///|
fn infer_render(body : @expr.Block) -> String {
  @expr/render.render_named(infer_names(body))
}

///|
test "infer_names names vars from field reads and method calls" {
  let source = value(0)
  let battle_data = value(1)
  let atk_team = value(2)
  inspect(
    infer_render([
      @expr.BindS(
        battle_data,
        @expr.IndexE(@expr.VarE(source), key("battleData")),
      ),
      @expr.BindS(
        atk_team,
        @expr.CallE(
          @expr.MethodC(@expr.VarE(battle_data), "getAtkTeam", [], None),
        ),
      ),
      @expr.ReturnS([@expr.VarE(atk_team)], None),
    ]),
    content=(
      #|local battleData = v0.battleData
      #|local atkTeam = battleData:getAtkTeam()
      #|return atkTeam
    ),
  )
}

///|
test "infer_names names require modules from path basename" {
  let loaded = value(0)
  inspect(
    infer_render([
      @expr.BindS(
        loaded,
        @expr.CallE(
          @expr.NormalC(
            @expr.IndexE(@expr.CellE(@ssa.Cell::env()), key("require")),
            [
              @expr.ConstE(
                AsciiString(
                  "app/module/battle_new/logic/helper/battle_helper",
                  is_valid_identifier=false,
                ),
              ),
            ],
            None,
          ),
        ),
      ),
      @expr.ReturnS([@expr.VarE(loaded)], None),
    ]),
    content=(
      #|local battleHelper = require("app/module/battle_new/logic/helper/battle_helper")
      #|return battleHelper
    ),
  )
}

///|
test "infer_names names class constructors from class string" {
  let controller = value(0)
  inspect(
    infer_render([
      @expr.BindS(
        controller,
        @expr.CallE(
          @expr.NormalC(
            @expr.IndexE(@expr.CellE(@ssa.Cell::env()), key("class")),
            [
              @expr.ConstE(
                AsciiString("BattleBaseController", is_valid_identifier=true),
              ),
            ],
            None,
          ),
        ),
      ),
      @expr.ReturnS([@expr.VarE(controller)], None),
    ]),
    content=(
      #|local BattleBaseController = class("BattleBaseController")
      #|return BattleBaseController
    ),
  )
}

///|
test "infer_names derives method result names from accessors" {
  let source = value(0)
  let manager = value(1)
  inspect(
    infer_render([
      @expr.BindS(
        manager,
        @expr.CallE(
          @expr.MethodC(@expr.VarE(source), "getInventoryManager", [], None),
        ),
      ),
      @expr.ReturnS([@expr.VarE(manager)], None),
    ]),
    content=(
      #|local inventoryManager = v0:getInventoryManager()
      #|return inventoryManager
    ),
  )
}

///|
test "infer_names names require modules from generic paths" {
  let loaded = value(0)
  inspect(
    infer_render([
      @expr.BindS(
        loaded,
        @expr.CallE(
          @expr.NormalC(
            @expr.IndexE(@expr.CellE(@ssa.Cell::env()), key("require")),
            [
              @expr.ConstE(
                AsciiString(
                  "gameplay/inventory/item_config_loader",
                  is_valid_identifier=false,
                ),
              ),
            ],
            None,
          ),
        ),
      ),
      @expr.ReturnS([@expr.VarE(loaded)], None),
    ]),
    content=(
      #|local itemConfigLoader = require("gameplay/inventory/item_config_loader")
      #|return itemConfigLoader
    ),
  )
}

///|
test "infer_names names cells and disambiguates conflicts" {
  let first = cell(0)
  let second = cell(1)
  let source = value(2)
  inspect(
    infer_render([
      @expr.LocalS([first], [@expr.IndexE(@expr.VarE(source), key("team"))]),
      @expr.LocalS([second], [@expr.IndexE(@expr.VarE(source), key("team"))]),
      @expr.ReturnS([@expr.CellE(first), @expr.CellE(second)], None),
    ]),
    content=(
      #|local team = v2.team
      #|local team2 = v2.team
      #|return team, team2
    ),
  )
}
