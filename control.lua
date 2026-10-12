-- Trash Slot: a slot attached to the inventory window. Delete throws the held/hovered stack in (what was there is
-- destroyed), Shift+Delete throws in every stack of that item, clicking the slot takes it back, Delete on the slot
-- destroys it. The trash is a script inventory per player, so items keep their data (armor grids, spoilage,
-- blueprints).
-- Undo: what was destroyed last (one level) waits in a second script inventory per player. A flying text at the
-- cursor names it, and an undo button beside the slot (shown only while there is something to undo, its place kept
-- empty otherwise) puts it back into the inventory. The next destroy replaces it.

-- dragging the slot anywhere comes from fse-std (optional); without it the grip cycles sides and floating
local dnd, events, input, theme
if script.active_mods["fse-std"] then
  dnd, events, input = require("__fse-std__/dnd"), require("__fse-std__/events"), require("__fse-std__/input")
  -- (themes: fse-std 0.6+; the player's theme from fse-std's theme window)
  local ok, t = pcall(require, "__fse-std__/theme")
  theme = ok and t.adopt and t or nil
end

local SIDES = { "left", "bottom", "right", "top" }
-- windows that show the player's inventory; one anchored frame each
local ANCHORS = { "controller_gui", "container_gui", "linked_container_gui", "car_gui", "spider_vehicle_gui",
  "assembling_machine_gui", "furnace_gui", "cargo_landing_pad_gui", "space_platform_hub_gui" }

local function trash_of(player)
  storage.trash = storage.trash or {}
  local inv = storage.trash[player.index]
  if not (inv and inv.valid) then
    inv = game.create_inventory(1)
    storage.trash[player.index] = inv
  end
  return inv
end

-- stacks of name/quality in inv, last slot first (the hovered slot isn't known to Lua; the last one is the usual pick)
local function matching(inv, name, quality, all, out)
  for i = #inv, 1, -1 do
    local s = inv[i]
    if s.valid_for_read and s.name == name and s.quality.name == quality then
      out[#out + 1] = s
      if not all then return end
    end
  end
end

local function undo_of(player)
  storage.undo = storage.undo or {}
  local inv = storage.undo[player.index]
  if not (inv and inv.valid) then
    inv = game.create_inventory(1)
    storage.undo[player.index] = inv
  end
  return inv
end

-- what an inventory holds, for a message: { name, quality, count (all stacks) } of its first stack, or nil
local function summary(inv)
  local first, n = nil, 0
  for i = 1, #inv do
    local s = inv[i]
    if s.valid_for_read then
      first = first or { name = s.name, quality = s.quality.name }
      n = n + s.count
    end
  end
  if first then first.count = n end
  return first
end

-- empties trash, then moves stacks into it (stacks: LuaItemStacks). What was in it is destroyed: with an undo
-- inventory it goes there instead (replacing the previous undo). Returns summary() of what was destroyed, or nil.
local function fill(trash, stacks, undo)
  local gone = summary(trash)
  if gone and undo then
    undo.clear()
    undo.resize(#trash)
    for i = 1, #trash do undo[i].transfer_stack(trash[i]) end
  end
  trash.clear()
  trash.resize(math.max(#stacks, 1))
  for i, s in ipairs(stacks) do trash[i].transfer_stack(s) end
  return gone
end

-- the delete key: cursor stack if held, else name/quality looked up in sources (first inventory that has it wins)
-- (returns true, and summary() of what that destroyed)
local function throw(trash, sources, cursor, name, quality, all, undo)
  local stacks = {}
  if cursor and cursor.valid_for_read then
    name, quality = cursor.name, cursor.quality.name
    stacks[1] = cursor
  end
  if name and (all or #stacks == 0) then
    for _, inv in ipairs(sources) do
      local n = #stacks
      matching(inv, name, quality, all, stacks)
      if #stacks > n then break end
    end
  end
  if #stacks == 0 then return false end
  return true, fill(trash, stacks, undo)
end

local function first(trash)
  for i = 1, #trash do if trash[i].valid_for_read then return trash[i] end end
end

local function count(trash)
  local n = 0
  for i = 1, #trash do if trash[i].valid_for_read then n = n + trash[i].count end end
  return n
end

-- take back: one stack to the cursor, or (all) everything into inv; what doesn't fit stays in the trash
local function take(trash, cursor, inv, all)
  if all then
    for i = 1, #trash do
      local s = trash[i]
      if s.valid_for_read then
        local n = inv.insert(s)
        if n >= s.count then s.clear() elseif n > 0 then s.count = s.count - n end
      end
    end
  else
    local s = first(trash)
    if s and cursor and not cursor.valid_for_read then cursor.transfer_stack(s) end
  end
end

local function sources(player)
  local list = {}
  local main = player.get_main_inventory()
  if main then list[1] = main end
  local e = player.opened_gui_type == defines.gui_type.entity and player.opened
  if e and e.valid and e.object_name == "LuaEntity" then
    for i = 1, e.get_max_inventory_index() do
      local inv = e.get_inventory(i)
      if inv then list[#list + 1] = inv end
    end
  end
  return list
end

-- where the slot is: { side = 1..4 } beside the window, or { side = 5, x, y } floating on the screen
local FLOAT = #SIDES + 1
local function dock_of(player)
  storage.dock = storage.dock or {}
  local d = storage.dock[player.index]
  if not d then
    d = { side = 1 }
    storage.dock[player.index] = d
  end
  return d
end

-- the frame(s) holding the slot: one per anchored window, or the floating one
local function frames(player)
  local list = {}
  for _, a in ipairs(ANCHORS) do
    local r = player.gui.relative["trash-slot-" .. a]
    if r and r.valid then list[#list + 1] = r["trash-slot-frame"] end
  end
  local f = player.gui.screen["trash-slot-float"]
  if f and f.valid then list[#list + 1] = f end
  return list
end

local GRIP = 24  -- (the grip, undo button and drag bar: big enough to hit)

-- "[item=x,quality=q] Name x n" for a summary()
local function what(g)
  local proto = prototypes.item[g.name]
  return { "trash-slot.stack", "[item=" .. g.name .. ",quality=" .. g.quality .. "]", proto and proto.localised_name or g.name,
    g.count }
end

local function refresh(player)
  local trash = trash_of(player)
  local s = first(trash)
  for _, f in ipairs(frames(player)) do
    local b = f["trash-slot-inner"]["trash-slot-button"]
    b.sprite = s and ("item/" .. s.name) or "utility/trash"
    b.number = s and count(trash) or nil
    b.quality = s and s.quality.name ~= "normal" and s.quality or nil
    b.elem_tooltip = s and { type = "item-with-quality", name = s.name, quality = s.quality.name } or nil
    local gone = summary(undo_of(player))
    local u = f["trash-slot-undo"]
    u.visible = gone ~= nil
    if f["trash-slot-undo-space"] then f["trash-slot-undo-space"].visible = gone == nil end
    u.tooltip = gone and { "trash-slot.undo-tooltip", what(gone) } or nil
  end
end

-- a destroy, told at the cursor (it can come back with the undo button)
local function told(player, gone)
  if gone then player.create_local_flying_text({ text = { "trash-slot.destroyed", what(gone) }, create_at_cursor = true }) end
end

-- the floating slot shows while a window with the inventory is open
local function show_float(player)
  local f = player.gui.screen["trash-slot-float"]
  if f and f.valid then
    local t = player.opened_gui_type
    f.visible = t == defines.gui_type.controller or t == defines.gui_type.entity
  end
end

-- the slot and its grip inside frame f (any extra element before them, like a drag bar, is the caller's)
local function fill_frame(f, vertical)
  f.style.padding = 6
  local inner = f.add({ type = "frame", name = "trash-slot-inner", style = "inside_shallow_frame" })
  -- (relative roots on top/bottom are stretched to the window's width: keep the slot its own size)
  for _, el in pairs({ f, inner }) do
    el.style.horizontally_stretchable, el.style.vertically_stretchable = false, false
  end
  -- with the mouse plugin the slot itself drags (a plain click still takes the stack)
  local drag = dnd and input.native()
  local slot = inner.add({ type = "sprite-button", name = "trash-slot-button", style = "inventory_slot",
    sprite = "utility/trash", tooltip = { drag and "trash-slot.slot-tooltip-drag" or "trash-slot.slot-tooltip" },
    raise_hover_events = true, mouse_button_filter = { "left", "right" } })
  local grip = f.add({ type = "sprite-button", name = "trash-slot-move", style = "frame_action_button",
    sprite = "trash-slot-move", tooltip = { "trash-slot.move-tooltip" } })
  grip.style.size = GRIP
  -- (shown while something destroyed can come back: refresh)
  local undo = f.add({ type = "sprite-button", name = "trash-slot-undo", style = "frame_action_button",
    sprite = "utility/reset_white", visible = false })
  undo.style.size = GRIP
  -- (its place kept while there's nothing to undo: the slot's frame doesn't change size when it comes and goes)
  local space = f.add({ type = "empty-widget", name = "trash-slot-undo-space" })
  space.style.size = GRIP
  if drag then
    dnd.draggable(slot, { kind = "trash-slot-move", preview = true, card_size = 40 })
  end
  if vertical then f.style.horizontal_align = "center" else f.style.vertical_align = "center" end
end

-- the grip's and undo button's icons: dark on a light theme (data.lua has the grip's both ways)
local function icons(f, player)
  local th = theme.of(player)
  local t = th and theme.themes and theme.themes.by_name[th.carrier]
  local light = t and t.light
  f["trash-slot-move"].sprite = light and "trash-slot-move-dark" or "trash-slot-move"
  f["trash-slot-undo"].sprite = light and "utility/reset" or "utility/reset_white"
end

-- themes frame f (fse-std); its padding and the grip's size go in as tweaks, so they outlast theme switches
local function adopt(f)
  theme.adopt(f)
  local tags = f.tags
  if tags.fstd_role then
    local t = tags.fstd_tweak or {}
    t.padding = 6
    theme.apply(f, tags.fstd_role, t)
  else
    f.style.padding = 6
  end
  -- (plain "close" buttons whose icons icons() picks: adopt()'s title-bar handling would put a white icon of a mod's
  -- own back on the game's dark button after a theme switch)
  for _, b in pairs({ f["trash-slot-move"], f["trash-slot-undo"] }) do
    local tags = b.tags
    tags.fstd_fab = nil
    b.tags = tags
    theme.apply(b, "close", { size = GRIP })
  end
  icons(f, game.get_player(f.player_index))
end

local function build(player)
  for _, a in ipairs(ANCHORS) do
    local r = player.gui.relative["trash-slot-" .. a]
    if r then r.destroy() end
  end
  if player.gui.screen["trash-slot-float"] then player.gui.screen["trash-slot-float"].destroy() end
  local d = dock_of(player)
  if d.side == FLOAT then
    local f = player.gui.screen.add({ type = "frame", name = "trash-slot-float", direction = "horizontal" })
    local bar = f.add({ type = "empty-widget", style = "draggable_space_header", tooltip = { "trash-slot.bar-tooltip" } })
    bar.style.width, bar.style.height = GRIP, 40
    bar.drag_target = f
    fill_frame(f, false)
    if theme then adopt(f) end
    if not d.x then
      -- (first time floating: left of the character screen, which the game centres; its left edge ~470 GUI units left of the middle; the slot is ~150 wide)
      local s, res = player.display_scale, player.display_resolution
      d.x = math.max(0, math.floor(res.width / 2 - 640 * s))
      d.y = math.max(0, math.floor(res.height / 2 - 60 * s))
    end
    f.location = { d.x, d.y }
    show_float(player)
  else
    local side = SIDES[d.side]
    local vertical = side == "left" or side == "right"
    for _, a in ipairs(ANCHORS) do
      local r = player.gui.relative.add({ type = "frame", name = "trash-slot-" .. a, style = "invisible_frame",
        anchor = { gui = defines.relative_gui_type[a], position = defines.relative_gui_position[side] } })
      local f = r.add({ type = "frame", name = "trash-slot-frame", direction = vertical and "vertical" or "horizontal" })
      if dnd and input.native() then -- a handle to pull it off the window (it floats where it's let go)
        local bar = f.add({ type = "empty-widget", name = "trash-slot-bar", style = "draggable_space_header",
          tooltip = { "trash-slot.bar-tooltip" } })
        if vertical then bar.style.width, bar.style.height = 40, GRIP else bar.style.width, bar.style.height = GRIP, 40 end
        dnd.draggable(bar, { kind = "trash-slot-move", preview = true, sprite = "utility/trash" })
      end
      fill_frame(f, vertical)
      if theme then adopt(f) end
    end
  end
  refresh(player)
end

local function float_at(player, x, y)
  local d = dock_of(player)
  d.side, d.x, d.y = FLOAT, math.floor(x), math.floor(y)
  build(player)
end

local function build_all()
  for _, p in pairs(game.players) do build(p) end
end

script.on_init(build_all)
script.on_configuration_changed(function()
  if storage.side then -- (0.1.x kept only a side)
    for i, side in pairs(storage.side) do
      local p = game.get_player(i)
      if p then dock_of(p).side = side end
    end
    storage.side = nil
  end
  build_all()
end)

local function on_delete(e, all)
  local p = game.get_player(e.player_index)
  if p.opened_gui_type == defines.gui_type.none then return end -- only with a window open, like the original
  local trash, cursor = trash_of(p), p.cursor_stack
  if storage.hover and storage.hover[p.index] and not (cursor and cursor.valid_for_read) then
    told(p, fill(trash, {}, undo_of(p))) -- Delete on the slot itself: destroyed (the undo button brings it back)
    return refresh(p)
  end
  local sp = e.selected_prototype
  local name = sp and sp.base_type == "item" and sp.name or nil
  local ok, gone = throw(trash, sources(p), cursor, name, sp and sp.quality or "normal", all, undo_of(p))
  if ok then
    told(p, gone)
    refresh(p)
  end
end

-- (in storage, not a local: Delete on the slot changes the game, so every peer must agree it was hovered)
local function hover(e, on)
  if e.element.name ~= "trash-slot-button" then return end
  storage.hover = storage.hover or {}
  storage.hover[e.player_index] = on or nil
end

local function opened(e)
  local p = game.get_player(e.player_index)
  show_float(p)
  refresh(p) -- (spoilage changes the trash on its own; cheap to redraw when a window opens)
end

local handlers = {
  [defines.events.on_player_created] = function(e) build(game.get_player(e.player_index)) end,
  [defines.events.on_player_removed] = function(e)
    local inv = storage.trash and storage.trash[e.player_index]
    if inv and inv.valid then inv.destroy() end
    local undo = storage.undo and storage.undo[e.player_index]
    if undo and undo.valid then undo.destroy() end
    for _, t in pairs({ storage.trash, storage.dock, storage.hover, storage.undo }) do
      if t then t[e.player_index] = nil end
    end
  end,
  [defines.events.on_gui_opened] = opened,
  [defines.events.on_gui_closed] = opened,
  [defines.events.on_gui_location_changed] = function(e)
    if e.element.name ~= "trash-slot-float" then return end
    local d = dock_of(game.get_player(e.player_index))
    d.x, d.y = e.element.location.x, e.element.location.y
  end,
  [defines.events.on_gui_hover] = function(e) hover(e, true) end,
  [defines.events.on_gui_leave] = function(e) hover(e, false) end,
  ["trash-slot-delete"] = function(e) on_delete(e, false) end,
  ["trash-slot-delete-all"] = function(e) on_delete(e, true) end,
  [defines.events.on_gui_click] = function(e)
    local el = e.element
    if not (el and el.valid) then return end
    local p = game.get_player(e.player_index)
    if el.name == "trash-slot-move" then
      -- left, bottom, right, top, floating (where it was last), left...
      local d = dock_of(p)
      d.side = d.side % FLOAT + 1
      build(p)
    elseif el.name == "trash-slot-button" then
      local trash, cursor = trash_of(p), p.cursor_stack
      if cursor and cursor.valid_for_read then
        told(p, fill(trash, { cursor }, undo_of(p)))
      elseif e.button == defines.mouse_button_type.right then
        told(p, fill(trash, {}, undo_of(p)))
      else
        local main = p.get_main_inventory()
        if e.shift and main then take(trash, cursor, main, true) else take(trash, cursor, nil, false) end
      end
      refresh(p)
    elseif el.name == "trash-slot-undo" then
      -- (back into the inventory; what doesn't fit stays undoable)
      local main, undo = p.get_main_inventory(), undo_of(p)
      if main then take(undo, nil, main, true) end
      if summary(undo) then p.create_local_flying_text({ text = { "trash-slot.undo-full" }, create_at_cursor = true }) end
      refresh(p)
    end
  end,
}

if dnd then
  -- the open window's rectangle on screen (pixels), read from the engine's own GUI; nil if it can't be read
  local function window_rect()
    local ok, r = pcall(function()
      local w = native.read(native.root().game, "gameView.activeWindow")
      local at, size = native.read(w, "location"), native.read(w, "size")
      return { x = at.x, y = at.y, w = size.width, h = size.height }
    end)
    return ok and r or nil
  end

  -- the side of window w that rectangle r touches (a gap of at most SNAP px, or over it), else nil
  local SNAP = 2
  local function touching(r, w)
    local gx = math.max(w.x - (r.x + r.w), r.x - (w.x + w.w)) -- (> 0: a gap beside, <= 0: overlapping columns)
    local gy = math.max(w.y - (r.y + r.h), r.y - (w.y + w.h))
    if gx > SNAP or gy > SNAP then return nil end
    local cx, cy = r.x + r.w / 2 - (w.x + w.w / 2), r.y + r.h / 2 - (w.y + w.h / 2)
    if gx > gy then return cx < 0 and 1 or 3 end -- left / right
    return cy < 0 and 4 or 2                      -- top / bottom
  end

  -- the slot dragged anywhere: it floats where it's let go, or docks when let go against the window's edge
  -- (the release is read on the tick it happens; this is this computer's mouse, so single player only, as dnd is)
  dnd.on_phase(function(player, phase, payload)
    if payload.kind ~= "trash-slot-move" or phase ~= "end" then return end
    local m = input.this_tick()
    if not m then return end
    local s = player.display_scale
    local w = window_rect()
    -- (the dragged copy: the slot, 40 px at scale 1, its corner 20 px up-left of the cursor; see dnd card_size)
    local side = w and touching({ x = m.x - 20, y = m.y - 20, w = 40 * s, h = 40 * s }, w)
    if side then
      dock_of(player).side = side
      build(player)
    else
      float_at(player, m.x - 58 * s, m.y - 36 * s) -- (the slot centred under the cursor)
    end
  end)
  -- (after fse-std's restyle: the grip's icon follows the theme)
  local retheme = theme and { ["fstd-theme-changed"] = function(e)
    local p = game.get_player(e.player_index)
    if not p then return end
    for _, f in ipairs(frames(p)) do icons(f, p) end
  end } or {}
  events.register({ input.handlers, dnd.handlers, theme and theme.handlers or {}, handlers, retheme })
else
  for ev, fn in pairs(handlers) do script.on_event(ev, fn) end
end

remote.add_interface("trash-slot", {
  -- for scripts and tests: throw(trash, {inventories}, cursor_stack|nil, name, quality, all, undo|nil) -> bool
  throw = function(...) return (throw(...)) end,
  undo = function(i) return undo_of(game.get_player(i)) end,
  -- what the mouse does, for tests: click(i, "slot"|"undo", {button = "left"|"right", shift})
  click = function(i, which, o)
    o = o or {}
    local f = frames(game.get_player(i))[1]
    local el = f and (which == "undo" and f["trash-slot-undo"] or f["trash-slot-inner"]["trash-slot-button"])
    if not el then return false end
    handlers[defines.events.on_gui_click]({ element = el, player_index = i, shift = o.shift,
      button = defines.mouse_button_type[o.button or "left"] })
    return true
  end,
  take = take,
  count = count,
  trash = function(i) return trash_of(game.get_player(i)) end,
  -- dock(i, side 1..4) beside the window, dock(i, 5, x, y) floating
  dock = function(i, side, x, y)
    local p = game.get_player(i)
    local d = dock_of(p)
    d.side, d.x, d.y = side, x or d.x, y or d.y
    build(p)
  end,
  where = function(i) local d = dock_of(game.get_player(i)) return { side = d.side, x = d.x, y = d.y } end,
  -- what the keys and the mouse do, for tests: press(i, all, selected_prototype), hover(i, on), point(i, what)
  press = function(i, all, sp) on_delete({ player_index = i, selected_prototype = sp }, all) end,
  hover = function(i, on) hover({ player_index = i, element = { name = "trash-slot-button" } }, on) end,
  -- point(i, nil | true (the slot) | "bar")
  point = function(i, what)
    local f = what and frames(game.get_player(i))[1]
    local el = f and (what == "bar" and f["trash-slot-bar"] or f["trash-slot-inner"]["trash-slot-button"])
    if input then input.hovered[i] = el end
    return el ~= nil
  end,
})
