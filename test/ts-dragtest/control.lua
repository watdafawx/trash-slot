-- through the fse launcher with a mocked mouse (std.mock): drag the slot itself onto a drop cell; screenshots
local out = {}
local function check(name, ok, detail) out[#out + 1] = (ok and "PASS " or "FAIL ") .. name .. (detail and (" :: " .. tostring(detail)) or "") end
local R = function(...) return remote.call("trash-slot", ...) end
local function rect()
  local w = native.read(native.root().game, "gameView.activeWindow")
  local at, size = native.read(w, "location"), native.read(w, "size")
  return { x = at.x, y = at.y, w = size.width, h = size.height }
end
local function mock(t) native.call("std", "mock", helpers.table_to_json(t)) end
-- where to let go so the slot floats: below the open window, clear of it (fixed pixels land on the window at a
-- big UI scale, and the slot docks there); dx: from the window's left edge
local drop = {}
local function below(dx)
  local w = rect()
  return { math.floor(w.x + dx), math.floor(w.y + w.h + 150) }
end

script.on_init(function()
  if remote.interfaces.freeplay then
    remote.call("freeplay", "set_skip_intro", true)
    remote.call("freeplay", "set_disable_crashsite", true)
  end
end)

local function shot(p, file)
  game.take_screenshot({ player = p, show_gui = true, path = file, resolution = { p.display_resolution.width, p.display_resolution.height }, zoom = 1 })
end

script.on_event(defines.events.on_tick, function(e)
  local p = game.get_player(1)
  if not (p and p.character) then return end
  local t, rel = e.tick, p.gui.relative
  if t == 60 then
    check("fse native mouse there", native ~= nil and native.plugins().std ~= nil)
    p.opened = defines.gui_type.controller
    R("dock", 1, 1, 0) -- (rebuild now the mouse plugin is known: the slot itself is draggable)
    mock({ left = false, x = 200, y = 200, focused = true })
  elseif t == 66 then
    check("docked slot has a drag bar", R("point", 1, "bar") and rel["trash-slot-controller_gui"]["trash-slot-frame"]["trash-slot-bar"].tags.fstd_drag ~= nil)
    check("slot is draggable", R("point", 1, true)
      and rel["trash-slot-controller_gui"]["trash-slot-frame"]["trash-slot-inner"]["trash-slot-button"].tags.fstd_drag ~= nil)
    R("point", 1, "bar")
  elseif t == 70 then
    mock({ left = true })
  elseif t == 74 then
    R("point", 1, false)
    mock({ x = 400, y = 300 })
  elseif t == 80 then
    check("dragging from the bar: a ghost follows the cursor", p.gui.screen["fstd_dnd_ghost_wx-trash-slot"] ~= nil)
    check("no extra slots shown", #p.gui.relative.children == 9, #p.gui.relative.children)
    drop[1] = below(300)
    mock({ x = drop[1][1], y = drop[1][2] })
  elseif t == 84 then
    shot(p, "ts-drag-1-dragging.png")
  elseif t == 88 then
    mock({ left = false })
  elseif t == 94 then
    local w, f = R("where", 1), p.gui.screen["trash-slot-float"]
    check("floats where let go", w.side == 5 and f and f.visible and math.abs(f.location.x - (drop[1][1] - 58 * p.display_scale)) < 2
      and math.abs(f.location.y - (drop[1][2] - 36 * p.display_scale)) < 2, w.side .. " " .. (f and (f.location.x .. "," .. f.location.y) or "no frame"))
    check("anchored copies and ghost gone", rel["trash-slot-controller_gui"] == nil
      and p.gui.screen["fstd_dnd_ghost_wx-trash-slot"] == nil)
    shot(p, "ts-drag-2-dropped.png")
  elseif t == 100 then
    R("point", 1, true)
    mock({ left = true })
  elseif t == 102 then
    R("point", 1, false)
    drop[2] = below(100)
    mock({ x = drop[2][1], y = drop[2][2] })
  elseif t == 106 then
    mock({ left = false })
  elseif t == 108 then
    local f = p.gui.screen["trash-slot-float"]
    check("dragged again from floating", f and math.abs(f.location.x - (drop[2][1] - 58 * p.display_scale)) < 2
      and math.abs(f.location.y - (drop[2][2] - 36 * p.display_scale)) < 2,
      f and (f.location.x .. "," .. f.location.y))
  elseif t == 110 or t == 130 or t == 150 then
    R("point", 1, true)
    mock({ left = true })
  elseif t == 112 or t == 132 or t == 152 then
    R("point", 1, false)
    local w = rect()
    local sc = p.display_scale
    -- the dragged copy spans cursor-20 .. cursor-20+40*scale
    local at = ({ [112] = { w.x - 1 + 20 - 40 * sc, w.y + 120 },          -- 1 px left of the window
                  [132] = { w.x + 300, w.y + w.h + 1 + 20 },              -- 1 px below it
                  [152] = { w.x - 10 + 20 - 40 * sc, w.y + 120 } })[t]    -- 10 px left: too far
    mock({ x = at[1], y = at[2] })
  elseif t == 116 or t == 136 or t == 156 then
    mock({ left = false })
  elseif t == 120 then
    check("1 px from the left edge docks left", R("where", 1).side == 1, R("where", 1).side)
  elseif t == 140 then
    check("1 px below docks bottom", R("where", 1).side == 2, R("where", 1).side)
    shot(p, "ts-drag-3-snapped.png")
  elseif t == 160 then
    check("10 px away floats", R("where", 1).side == 5, R("where", 1).side)
  elseif t == 162 then
    -- fse-std's window scale (150 %): the floating slot grows; dragged, it still lands centred under the cursor
    remote.call("fse-std", "set_window_scale", 1, 150)
  elseif t == 164 then
    R("point", 1, true)
    mock({ left = true })
  elseif t == 166 then
    R("point", 1, false)
    drop[3] = below(500)
    mock({ x = drop[3][1], y = drop[3][2] })
  elseif t == 170 then
    mock({ left = false })
  elseif t == 174 then
    local f, s = p.gui.screen["trash-slot-float"], p.display_scale * 1.5
    local res = p.display_resolution
    check("scale 150 %: floats centred under the cursor", f and R("where", 1).side == 5 and f.tags.fstd_scale == 1.5
      and math.abs(f.location.x - (drop[3][1] - 58 * s)) < 2 and math.abs(f.location.y - (drop[3][2] - 36 * s)) < 2,
      f and (f.location.x .. "," .. f.location.y .. " scale " .. tostring(f.tags.fstd_scale)))
    check("scale 150 %: on the screen", f and f.location.x >= 0 and f.location.x + 144 * s <= res.width
      and f.location.y + 56 * s <= res.height)
    shot(p, "ts-drag-4-scale.png")
  elseif t == 200 then
    remote.call("fse-std", "set_window_scale", 1, 100)
    native.call("std", "mock", "")
    helpers.write_file("ts-drag.txt", table.concat(out, "\n") .. "\n")
    helpers.write_file("ts-drag-done.txt", "done")
  end
end)
