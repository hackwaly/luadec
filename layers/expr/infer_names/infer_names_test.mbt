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
fn infer_render_with_filename(body : @expr.Block, filename : String) -> String {
  @expr/render.render_named(infer_names_with_filename(body, filename~))
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
      #|local BattleHelper = require("app/module/battle_new/logic/helper/battle_helper")
      #|return BattleHelper
    ),
  )
}

///|
test "infer_names names top-level returned module table from filename" {
  let table = value(0)
  inspect(
    infer_render_with_filename(
      [
        @expr.BindS(table, @expr.TableE(@expr.EmptyTI)),
        @expr.SetIndexS(
          @expr.VarE(table),
          key("init"),
          @expr.ClosureE({ params: [], vararg: false, body: [] }),
        ),
        @expr.ReturnS([@expr.VarE(table)], None),
      ],
      "app/module/report_ad.lua",
    ),
    content=(
      #|local ReportAd = {}
      #|ReportAd.init = function()
      #|end
      #|return ReportAd
    ),
  )
}

///|
test "infer_names keeps class constructor name ahead of filename fallback" {
  let class_value = value(0)
  let base_object = value(1)
  inspect(
    infer_render_with_filename(
      [
        @expr.BindS(
          class_value,
          @expr.CallE(
            @expr.NormalC(
              @expr.IndexE(@expr.CellE(@ssa.Cell::env()), key("class")),
              [
                @expr.ConstE(
                  AsciiString("UIPrefabObject", is_valid_identifier=true),
                ),
                @expr.VarE(base_object),
              ],
              None,
            ),
          ),
        ),
        @expr.ReturnS([@expr.VarE(class_value)], None),
      ],
      "app/bf/unity/uiprefab_object.lua",
    ),
    content=(
      #|local UIPrefabObject = class("UIPrefabObject", v1)
      #|return UIPrefabObject
    ),
  )
}

///|
test "infer_names names require modules in PascalCase" {
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
                  "app/bf/unity/mesh_spine_object",
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
      #|local MeshSpineObject = require("app/bf/unity/mesh_spine_object")
      #|return MeshSpineObject
    ),
  )
}

///|
test "infer_names names class constructors from class string" {
  let controller = value(0)
  let base_ui = value(1)
  let gm_tool_ui = value(2)
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
      @expr.BindS(
        gm_tool_ui,
        @expr.CallE(
          @expr.NormalC(
            @expr.IndexE(@expr.CellE(@ssa.Cell::env()), key("class")),
            [
              @expr.ConstE(AsciiString("GMToolUI", is_valid_identifier=true)),
              @expr.VarE(base_ui),
            ],
            None,
          ),
        ),
      ),
      @expr.ReturnS([@expr.VarE(controller), @expr.VarE(gm_tool_ui)], None),
    ]),
    content=(
      #|local BattleBaseController = class("BattleBaseController")
      #|local GMToolUI = class("GMToolUI", v1)
      #|return BattleBaseController, GMToolUI
    ),
  )
}

///|
test "infer_names names class method receiver as self" {
  let controller = value(0)
  let first_self = value(1)
  let arg = value(2)
  let second_self = value(3)
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
      @expr.SetIndexS(
        @expr.VarE(controller),
        key("init"),
        @expr.ClosureE({
          params: [first_self, arg],
          vararg: false,
          body: [
            @expr.SetIndexS(
              @expr.VarE(first_self),
              key("params"),
              @expr.VarE(arg),
            ),
          ],
        }),
      ),
      @expr.SetIndexS(
        @expr.VarE(controller),
        key("reset"),
        @expr.ClosureE({
          params: [second_self],
          vararg: false,
          body: [
            @expr.SetIndexS(
              @expr.VarE(second_self),
              key("params"),
              @expr.ConstE(Nil),
            ),
          ],
        }),
      ),
      @expr.ReturnS([@expr.VarE(controller)], None),
    ]),
    content=(
      #|local BattleBaseController = class("BattleBaseController")
      #|function BattleBaseController:init(params)
      #|  self.params = params
      #|end
      #|function BattleBaseController:reset()
      #|  self.params = nil
      #|end
      #|return BattleBaseController
    ),
  )
}

///|
test "infer_names names values from field assignments" {
  let object = value(0)
  let callback = value(1)
  let result = value(2)
  inspect(
    infer_render([
      @expr.SetIndexS(
        @expr.VarE(object),
        key("isSelectingSkillCall"),
        @expr.VarE(callback),
      ),
      @expr.SetIndexS(
        @expr.CellE(@ssa.Cell::env()),
        key("GLOBAL_NAME"),
        @expr.VarE(result),
      ),
      @expr.ReturnS([@expr.VarE(callback), @expr.VarE(result)], None),
    ]),
    content=(
      #|v0.isSelectingSkillCall = isSelectingSkillCall
      #|GLOBAL_NAME = v2
      #|return isSelectingSkillCall, v2
    ),
  )
}

///|
test "infer_names propagates default alias name to source value" {
  let source = value(0)
  let params = value(1)
  let object = value(2)
  inspect(
    infer_render([
      @expr.BindS(params, @expr.OrE(@expr.VarE(source), @expr.TableE(EmptyTI))),
      @expr.SetIndexS(@expr.VarE(object), key("params"), @expr.VarE(params)),
      @expr.ReturnS([@expr.VarE(source), @expr.VarE(params)], None),
    ]),
    content=(
      #|local params = params2 or {}
      #|v2.params = params
      #|return params2, params
    ),
  )
}

///|
test "infer_names derives setter parameter names for class methods" {
  let controller = value(0)
  let self_var = value(1)
  let side = value(2)
  let buffs_self = value(3)
  let buffs = value(4)
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
      @expr.SetIndexS(
        @expr.VarE(controller),
        key("setCurActionSide"),
        @expr.ClosureE({
          params: [self_var, side],
          vararg: false,
          body: [
            @expr.BindMultiS(
              [],
              @expr.CallM(
                @expr.MethodC(
                  @expr.IndexE(@expr.VarE(self_var), key("battleData")),
                  "setCurActionSide",
                  [@expr.VarE(side)],
                  None,
                ),
              ),
            ),
          ],
        }),
      ),
      @expr.SetIndexS(
        @expr.VarE(controller),
        key("settleBuffs"),
        @expr.ClosureE({
          params: [buffs_self, buffs],
          vararg: false,
          body: [@expr.ReturnS([@expr.VarE(buffs)], None)],
        }),
      ),
      @expr.ReturnS([@expr.VarE(controller)], None),
    ]),
    content=(
      #|local BattleBaseController = class("BattleBaseController")
      #|function BattleBaseController:setCurActionSide(curActionSide)
      #|  self.battleData:setCurActionSide(curActionSide)
      #|end
      #|function BattleBaseController:settleBuffs(v4)
      #|  return v4
      #|end
      #|return BattleBaseController
    ),
  )
}

///|
test "infer_names leaves directly-called unknown values unnamed" {
  let callback = value(0)
  let local_callback = value(1)
  inspect(
    infer_render([
      @expr.BindMultiS(
        [],
        @expr.CallM(@expr.NormalC(@expr.VarE(callback), [], None)),
      ),
      @expr.BindS(
        local_callback,
        @expr.IndexE(@expr.VarE(callback), key("next")),
      ),
      @expr.BindMultiS(
        [],
        @expr.CallM(@expr.NormalC(@expr.VarE(local_callback), [], None)),
      ),
      @expr.ReturnS([@expr.VarE(callback)], None),
    ]),
    content=(
      #|v0()
      #|local next = v0.next
      #|next()
      #|return v0
    ),
  )
}

///|
test "infer_names does not duplicate names for directly-called parameters" {
  let first = value(0)
  let second = value(1)
  inspect(
    infer_render([
      @expr.ReturnS(
        [
          @expr.ClosureE({
            params: [first, second],
            vararg: false,
            body: [
              @expr.BindMultiS(
                [],
                @expr.CallM(@expr.NormalC(@expr.VarE(first), [], None)),
              ),
              @expr.BindMultiS(
                [],
                @expr.CallM(@expr.NormalC(@expr.VarE(second), [], None)),
              ),
            ],
          }),
        ],
        None,
      ),
    ]),
    content=(
      #|return function(v0, v1)
      #|  v0()
      #|  v1()
      #|end
    ),
  )
}

///|
test "infer_names derives mutator argument names from method calls" {
  let object = value(0)
  let action_side = value(1)
  let ignored = value(2)
  inspect(
    infer_render([
      @expr.BindMultiS(
        [],
        @expr.CallM(
          @expr.MethodC(
            @expr.VarE(object),
            "setCurActionSide",
            [@expr.VarE(action_side)],
            None,
          ),
        ),
      ),
      @expr.BindMultiS(
        [],
        @expr.CallM(
          @expr.MethodC(
            @expr.VarE(object),
            "settleBuffs",
            [@expr.VarE(ignored)],
            None,
          ),
        ),
      ),
      @expr.ReturnS([@expr.VarE(action_side), @expr.VarE(ignored)], None),
    ]),
    content=(
      #|v0:setCurActionSide(curActionSide)
      #|v0:settleBuffs(v2)
      #|return curActionSide, v2
    ),
  )
}

///|
test "infer_names derives function parameter names from table fields" {
  let self_var = value(0)
  let win = value(1)
  let combat_report = value(2)
  let task_stat = value(3)
  let battle_data = value(4)
  let operate_unit_list = value(5)
  let verify_cheating = value(6)
  let request = value(7)
  let report = value(8)
  inspect(
    infer_render([
      @expr.ReturnS(
        [
          @expr.ClosureE({
            params: [
              self_var, win, combat_report, task_stat, battle_data, operate_unit_list,
              verify_cheating,
            ],
            vararg: false,
            body: [
              @expr.BindS(
                request,
                @expr.TableE(
                  @expr.TableTI([
                    (key("win"), @expr.VarE(win)),
                    (key("task_stat"), @expr.VarE(task_stat)),
                    (key("combatReport"), @expr.VarE(combat_report)),
                    (key("verify_cheating"), @expr.VarE(verify_cheating)),
                  ]),
                ),
              ),
              @expr.BindS(
                report,
                @expr.TableE(
                  @expr.TableTI([
                    (key("battle_data"), @expr.VarE(battle_data)),
                    (key("operate_unit_list"), @expr.VarE(operate_unit_list)),
                    (key("verify_cheating"), @expr.VarE(verify_cheating)),
                  ]),
                ),
              ),
              @expr.ReturnS([@expr.VarE(request), @expr.VarE(report)], None),
            ],
          }),
        ],
        None,
      ),
    ]),
    content=(
      #|return function(v0, win, combatReport, taskStat, battleData, operateUnitList, verifyCheating)
      #|  local v7 = { win = win, task_stat = taskStat, combatReport = combatReport, verify_cheating = verifyCheating }
      #|  local v8 = { battle_data = battleData, operate_unit_list = operateUnitList, verify_cheating = verifyCheating }
      #|  return v7, v8
      #|end
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
      #|local ItemConfigLoader = require("gameplay/inventory/item_config_loader")
      #|return ItemConfigLoader
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
