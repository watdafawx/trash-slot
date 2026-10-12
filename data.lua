data:extend({
  { type = "custom-input", name = "trash-slot-delete", key_sequence = "DELETE", include_selected_prototype = true,
    order = "a" },
  { type = "custom-input", name = "trash-slot-delete-all", key_sequence = "SHIFT + DELETE",
    include_selected_prototype = true, order = "b" },
  -- (the grip's icon: four arrows, "move"; white for the game's dark buttons, black on light themes)
  { type = "sprite", name = "trash-slot-move", filename = "__wx-trash-slot__/graphics/move.png",
    priority = "extra-high-no-scale", size = 32, mipmap_count = 2, scale = 0.5, flags = { "gui-icon" } },
  { type = "sprite", name = "trash-slot-move-dark", filename = "__wx-trash-slot__/graphics/move.png",
    priority = "extra-high-no-scale", size = 32, mipmap_count = 2, scale = 0.5, flags = { "gui-icon" }, tint = { 0, 0, 0 } },
})
