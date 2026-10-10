-- drives trash-slot's throw/take on script inventories (no player in a benchmark run)
local out = {}
local function check(name, ok, detail) out[#out + 1] = (ok and "PASS " or "FAIL ") .. name .. (detail and (" :: " .. tostring(detail)) or "") end
script.on_event(defines.events.on_tick, function(e)
  if e.tick ~= 5 then return end
  local R = function(...) return remote.call("trash-slot", ...) end
  local trash, main, chest, hand = game.create_inventory(1), game.create_inventory(10), game.create_inventory(5), game.create_inventory(1)
  main.insert({ name = "iron-plate", count = 250 }) -- 100,100,50
  main.insert({ name = "copper-plate", count = 30 })
  main.insert({ name = "iron-plate", count = 7, quality = "rare" })
  chest.insert({ name = "coal", count = 20 })

  check("delete hovered: one stack in", R("throw", trash, { main }, nil, "iron-plate", "normal", false) and R("count", trash) == 50
    and main.get_item_count({ name = "iron-plate", quality = "normal" }) == 200, R("count", trash))
  R("throw", trash, { main }, nil, "copper-plate", "normal", false)
  check("next delete destroys the previous", R("count", trash) == 30 and trash[1].name == "copper-plate"
    and main.get_item_count({ name = "iron-plate", quality = "normal" }) == 200)
  check("quality kept apart", R("throw", trash, { main }, nil, "iron-plate", "rare", false) and R("count", trash) == 7
    and trash[1].quality.name == "rare" and main.get_item_count({ name = "iron-plate", quality = "normal" }) == 200)
  check("shift-delete takes all of the kind", R("throw", trash, { main }, nil, "iron-plate", "normal", true)
    and R("count", trash) == 200 and main.get_item_count("iron-plate") == 0, R("count", trash))
  check("missing item does nothing", not R("throw", trash, { main }, nil, "stone", "normal", false) and R("count", trash) == 200)
  check("falls through to the opened chest", R("throw", trash, { main, chest }, nil, "coal", "normal", false)
    and R("count", trash) == 20 and chest.is_empty())

  hand.insert({ name = "copper-plate", count = 5 })
  check("held stack wins over hover", R("throw", trash, { main }, hand[1], "stone", "normal", false)
    and R("count", trash) == 5 and hand.is_empty() and main.get_item_count("copper-plate") == 0)
  R("take", trash, hand[1], nil, false)
  check("click takes back to cursor", hand[1].valid_for_read and hand[1].count == 5 and R("count", trash) == 0)

  main.insert({ name = "iron-plate", count = 150 })
  main.insert({ name = "copper-plate", count = 40 })
  hand[1].count = 3
  check("shift-delete with held stack adds the rest", R("throw", trash, { main }, hand[1], nil, nil, true)
    and R("count", trash) == 43 and hand.is_empty(), R("count", trash))
  R("throw", trash, { main }, nil, "iron-plate", "normal", true)
  R("take", trash, nil, main, true)
  check("shift-click returns everything", R("count", trash) == 0 and main.get_item_count("iron-plate") == 150)

  local armor = game.create_inventory(1)
  armor[1].set_stack({ name = "blueprint" })
  armor[1].label = "keep me"
  R("throw", trash, { armor }, nil, "blueprint", "normal", false)
  check("item data survives the trash", trash[1].valid_for_read and trash[1].label == "keep me")
  helpers.write_file("ts-test.txt", table.concat(out, "\n") .. "\n")
end)
