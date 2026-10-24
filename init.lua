-- Gensokyo runtime layer: the stages (workspaces), key bindings, and the
-- glass and 3D placement of the shell's panels.

shady.log("Gensokyo: the barrier holds")

-- Each workspace is a stage of the game; shell.lua names them in kanji.
local stages = { "hakurei", "forest", "scarlet", "netherworld", "eientei", "moriya" }
local terminal = os.getenv("TERMINAL") or "foot"

for _, name in ipairs(stages) do shady.workspace(name) end
shady.workspace("hakurei")

if shady.layer_effect then
    -- The side panel is lacquer over the sky; the spell card and the
    -- shortcuts are frosted glass over the desktop.
    shady.layer_effect("gensokyo-panel", { blur = 20, saturation = 1.2, tint = "#12081E30" })
    shady.layer_effect("gensokyo-spellcard", { blur = 10, saturation = 1.1 })
    shady.layer_effect("gensokyo-shortcuts", { blur = 24, saturation = 1.2, tint = "#12081E40" })
end

shady.bind("Super+Shift+Escape", function() shady.quit() end)
shady.bind("Super+Return", function() shady.spawn(terminal) end, "Open a terminal")
shady.bind("Super+d", function() shady.toggle_launcher() end, "Declare a spell card (launcher)")
shady.bind("Print", function() shady.screenshot() end, "Save a screenshot to ~/Pictures")

shady.describe("Super+1…" .. #stages, "Go to stage (workspace)")
shady.describe("Super+Shift+1…" .. #stages, "Move window to stage")
for i, name in ipairs(stages) do
    shady.bind("Super+" .. i, function() shady.workspace(name) end)
    shady.bind("Super+Shift+" .. i, function()
        local window = shady.focused_window()
        if window and window:move_to_workspace(name) then
            shady.workspace(name)
            window:focus()
        end
    end)
end

shady.bind("Super+m", function()
    local window = shady.focused_window()
    if window then window:maximize() end
end, "Maximize the window")
shady.bind("Super+Shift+m", function()
    local window = shady.focused_window()
    if window then window:set_fullscreen() end
end, "Make the window fullscreen")
