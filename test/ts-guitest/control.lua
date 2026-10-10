-- real client: the slot on the inventory window, delete keys through remote, docking, drop cells; screenshots
local out = {}
local function check(name, ok, detail) out[#out + 1] = (ok and "PASS " or "FAIL ") .. name .. (detail and (" :: " .. tostring(detail)) or "") end
local R = function(...) return remote.call("trash-slot", ...) end
local IRON = { base_type = "item", derived_type = "item", name = "iron-plate", quality = "normal" }

script.on_init(function()
  if remote.interfaces.freeplay then
    remote.call("freeplay", "set_skip_intro", true)
    remote.call("freeplay", "set_disable_crashsite", true)
  end
end)

local function shot(p, file)
  game.take_screenshot({ player = p, show_gui = true, path = file, resolution = { 1920, 1080 }, zoom = 1 })
end
local function button(p, a)
  local f = p.gui.relative["trash-slot-" .. (a or "controller_gui")]
  return f and f["trash-slot-frame"]["trash-slot-inner"]["trash-slot-button"]
end

script.on_event(defines.events.on_tick, function(e)
  local p = game.get_player(1)
  if not (p and p.character) then return end
  local t = e.tick
  local main = p.get_main_inventory()
  if t == 30 then
    main.clear()
    main.insert({ name = "iron-plate", count = 250 })
    main.insert({ name = "copper-plate", count = 30 })
    p.opened = defines.gui_type.controller
  elseif t == 40 then
    check("inventory open", p.opened_gui_type == defines.gui_type.controller, p.opened_gui_type)
    R("press", 1, false, IRON)
    check("delete moved one stack", R("count", R("trash", 1)) == 50 and main.get_item_count("iron-plate") == 200)
    local b = button(p)
    check("slot shows it", b and b.sprite == "item/iron-plate" and b.number == 50, b and b.sprite)
    shot(p, "ts-gui-1-left.png")
  elseif t == 60 then
    R("hover", 1, true)
    R("press", 1, false, IRON) -- (the game reports the hovered slot's item too)
    R("hover", 1, false)
    check("delete on the slot destroys it", R("count", R("trash", 1)) == 0 and main.get_item_count("iron-plate") == 200)
    check("slot empty again", button(p).sprite == "utility/trash" and button(p).number == nil)
    R("press", 1, true, IRON)
    check("shift-delete took all iron", R("count", R("trash", 1)) == 200 and main.get_item_count("iron-plate") == 0)
    R("dock", 1, 2)
    check("docked bottom", button(p) ~= nil and p.gui.relative["trash-slot-controller_gui"].anchor.position
      == defines.relative_gui_position.bottom and button(p).number == 200)
    shot(p, "ts-gui-2-bottom.png")
  elseif t == 80 then
    R("dock", 1, 3)
    shot(p, "ts-gui-3-right.png")
  elseif t == 100 then
    R("dock", 1, 5, 300, 250)
    local f = p.gui.screen["trash-slot-float"]
    check("floating: no anchored frames, own frame shown", f and f.visible and f.location.x == 300
      and p.gui.relative["trash-slot-controller_gui"] == nil and f["trash-slot-inner"]["trash-slot-button"].number == 200)
    shot(p, "ts-gui-4-float.png")
  elseif t == 110 then
    p.opened = nil
  elseif t == 112 then
    check("floating slot hides with the inventory", not p.gui.screen["trash-slot-float"].visible)
    p.opened = defines.gui_type.controller
  elseif t == 114 then
    check("and comes back", p.gui.screen["trash-slot-float"].visible)
  elseif t == 120 then
    local chest = p.surface.create_entity({ name = "steel-chest", position = { p.position.x + 2, p.position.y }, force = p.force })
    chest.insert({ name = "coal", count = 50 })
    R("dock", 1, 1)
    p.opened = chest
  elseif t == 140 then
    R("press", 1, false, { base_type = "item", derived_type = "item", name = "coal", quality = "normal" })
    check("from the opened chest", R("count", R("trash", 1)) == 50 and p.opened.get_item_count("coal") == 0)
    shot(p, "ts-gui-5-chest.png")
  elseif t == 170 then
    helpers.write_file("ts-gui.txt", table.concat(out, "\n") .. "\n")
    helpers.write_file("ts-gui-done.txt", "done")
  end
end)
