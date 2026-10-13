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
  game.take_screenshot({ player = p, show_gui = true, path = file, resolution = { p.display_resolution.width, p.display_resolution.height }, zoom = 1 })
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
    local undo = button(p).parent.parent["trash-slot-undo"]
    check("undo button shows what was destroyed", undo.visible and R("count", R("undo", 1)) == 50
      and undo.tooltip ~= nil)
    R("click", 1, "undo")
    check("undo puts it back", main.get_item_count("iron-plate") == 250 and R("undo", 1).is_empty() and not undo.visible)
    local space = undo.parent["trash-slot-undo-space"]
    check("undo's place kept while hidden (the frame keeps its size)", space and space.visible
      and space.style.minimal_width == undo.style.minimal_width)
    check("grip shows the move icon", undo.parent["trash-slot-move"].sprite:find("trash%-slot%-move") ~= nil,
      undo.parent["trash-slot-move"].sprite)
    R("press", 1, true, IRON)
    check("shift-delete took all iron", R("count", R("trash", 1)) == 250 and main.get_item_count("iron-plate") == 0)
    R("dock", 1, 2)
    check("docked bottom", button(p) ~= nil and p.gui.relative["trash-slot-controller_gui"].anchor.position
      == defines.relative_gui_position.bottom and button(p).number == 250)
    shot(p, "ts-gui-2-bottom.png")
  elseif t == 80 then
    R("dock", 1, 3)
    shot(p, "ts-gui-3-right.png")
  elseif t == 90 then
    -- (right-click destroys: the undo button comes back)
    R("press", 1, false, { base_type = "item", derived_type = "item", name = "copper-plate", quality = "normal" })
    check("trashing again destroys the previous, undoable", R("count", R("undo", 1)) == 250)
    R("dock", 1, 5) -- (first float: no place yet)
    local f = p.gui.screen["trash-slot-float"]
    local res, sc = p.display_resolution, p.display_scale
    -- (left of the inventory when there is room for it there; a screen the inventory fills: at its left edge)
    local room = res.width / 2 - 470 * sc > 170 * sc
    check("first float sits left of the centred inventory", f and f.location.x >= 0
      and (not room or (f.location.x > 0 and f.location.x + 120 * sc < res.width / 2 - 400 * sc))
      and math.abs(f.location.y - res.height / 2) < 120 * sc,
      f and (f.location.x .. "," .. f.location.y .. " of " .. res.width .. "x" .. res.height .. " @" .. sc))
    shot(p, "ts-gui-4a-float-default.png")
  elseif t == 100 then
    R("dock", 1, 5, 300, 250)
    local f = p.gui.screen["trash-slot-float"]
    check("floating: no anchored frames, own frame shown", f and f.visible and f.location.x == 300
      and p.gui.relative["trash-slot-controller_gui"] == nil and f["trash-slot-inner"]["trash-slot-button"].number == 30)
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
  elseif t == 160 then
    -- fse-std's window scale (150 %): the docked slot keeps the game's scale (it lines up with the inventory's own
    -- slots); the floating one grows, and stays on the screen
    remote.call("fse-std", "set_window_scale", 1, 150)
  elseif t == 162 then
    local r = p.gui.relative["trash-slot-controller_gui"]
    local cr = p.gui.relative["trash-slot-container_gui"]
    check("scale: docked slot keeps the game's scale", r and cr and (r.tags.fstd_scale or 1) == 1
      and (cr.tags.fstd_scale or 1) == 1 and cr["trash-slot-frame"]["trash-slot-move"].style.minimal_width == 24,
      cr and (tostring(cr.tags.fstd_scale) .. " grip " .. tostring(cr["trash-slot-frame"]["trash-slot-move"].style.minimal_width)))
    shot(p, "ts-gui-6-scale-docked.png")
  elseif t == 185 then
    p.opened = defines.gui_type.controller
    R("dock", 1, 5, 100, 300)
  elseif t == 187 then
    local f = p.gui.screen["trash-slot-float"]
    check("scale: floating slot drawn at 150 %", f and f.tags.fstd_scale == 1.5 and R("scale", 1) == 1.5
      and f["trash-slot-move"].style.minimal_width == 36 and f["trash-slot-undo"].style.minimal_width == 36,
      f and (tostring(f.tags.fstd_scale) .. " grip " .. tostring(f["trash-slot-move"].style.minimal_width)))
    shot(p, "ts-gui-7-scale-float.png")
  elseif t == 210 then
    -- put at the screen's bottom right corner: kept on it at its scaled size
    local res = p.display_resolution
    R("dock", 1, 5, res.width - 5, res.height - 5)
  elseif t == 212 then
    local f, res, sc = p.gui.screen["trash-slot-float"], p.display_resolution, p.display_scale * 1.5
    check("scale: floating slot kept on the screen", f and f.location.x >= 0 and f.location.y >= 0
      and f.location.x + 144 * sc <= res.width and f.location.y + 56 * sc <= res.height,
      f and (f.location.x .. "," .. f.location.y .. " of " .. res.width .. "x" .. res.height .. " @" .. p.display_scale))
    shot(p, "ts-gui-8-scale-corner.png")
  elseif t == 240 then
    remote.call("fse-std", "set_window_scale", 1, 100)
    helpers.write_file("ts-gui.txt", table.concat(out, "\n") .. "\n")
    helpers.write_file("ts-gui-done.txt", "done")
  end
end)
