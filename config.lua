-- Gensokyo
-- An unofficial Touhou Project fan rice for Shady: the desktop at dusk over
-- the Hakurei Shrine, with a shoot-'em-up side panel, a spell card launcher,
-- Bunbunmaru extras for notifications and Bad Apple!! on Super+A. The
-- shrine, the sky and everything on them come from shady-shell (shell.lua).

local root = os.getenv("SHADY_ROOT") or "."
-- This repository, for the rice's own plugin.
local rice = os.getenv("SHADY_TOUHOU_DIR")
if not rice then
    -- Where this file really is: install.sh links it into ~/.config/shady.
    local here = debug.getinfo(1, "S").source:match("^@(.*)$") or "./config.lua"
    local pipe = io.popen("readlink -f '" .. here:gsub("'", "'\\''") .. "'")
    local real = pipe and pipe:read("l")
    if pipe then pipe:close() end
    rice = (real or here):match("^(.*)/[^/]*$") or "."
end

shady.log("loading rice: Gensokyo")

shady.set("spatial_mode", true)
shady.set("physics_enabled", false)
shady.set("window_gravity", false)
shady.set("window_wobble", false)
shady.set("window_sides", true)
-- The sky, the shrine and the barrier are a background layer drawn by the
-- shell; no floor, sky or projected shadows in front of it.
shady.set("shadows", false)
shady.set("floor", false)
shady.set("sky", false)
shady.set("environment", false)
shady.set("close_animation", true)
shady.set("fps_mode", false)

-- Shown only until the shell's sky arrives.
shady.set("background_top", "#120E2A")
shady.set("background_horizon", "#6B2546")
shady.set("background_bottom", "#170B1F")

-- Shrine paper and lacquer: the focused window gets a red-and-white
-- shrine maiden frame, the others a quiet violet one, like the border
-- between Gensokyo and the outside world.
shady.set("window_tint", "#FFF8F0")
shady.set("window_effect_strength", 0.0)
shady.set("window_brightness", 1.0)
shady.set("window_opacity", 0.96)
shady.set("window_corner_radius", 8.0)
shady.set("window_border_width", 2.0)
shady.set("window_border_color", "#4A3866")
shady.set("window_border_focus_color", "#E0303C")
shady.set("window_titlebar", true)
shady.set("window_titlebar_height", 28.0)
shady.set("window_titlebar_color", "#241A33")
shady.set("window_titlebar_focus_color", "#A81E30")
shady.set("window_titlebar_text_color", "#F4EEE3")

shady.modules({
    ["window-motion"] = true,
    ["physics"] = false,
    ["fps"] = false,
    ["close-animation"] = true,
    ["scene-effects"] = true,
    ["lua"] = true,
})

local function plugin(env, name)
    shady.plugin(os.getenv(env) or (root .. "/build/libshady-plugin-" .. name .. ".so"))
end

-- Closing windows turn into point and power items (./build.sh).
local items = os.getenv("SHADY_POINT_ITEMS_PLUGIN") or (rice .. "/build/libshady-plugin-point-items.so")
local found = io.open(items, "r")
if found then
    found:close()
    shady.plugin(items)
else
    shady.log("Gensokyo: no " .. items .. "; run ./build.sh for the item close animation")
end

-- Super+O: every window spread out over Gensokyo.
plugin("SHADY_OVERVIEW_PLUGIN", "spatial-overview")
-- Super+A: Bad Apple!! as flip-dot tiles, from your own copy of the video
-- (tools/bad-apple.sh in Shady).
plugin("SHADY_BAD_APPLE_PLUGIN", "bad-apple")
-- Super+H: the windows fall into one of Yukari's gaps and come back.
plugin("SHADY_BLACK_HOLE_PLUGIN", "black-hole")
-- Super+Z: Cirno freezes the window (Shift: the whole workspace).
plugin("SHADY_FROZEN_WINDOW_PLUGIN", "frozen-window")
-- Super+C: the other windows orbit the focused one like options.
plugin("SHADY_CONSTELLATION_PLUGIN", "window-constellation")
-- Super+BackSpace: scrub back through earlier layouts.
plugin("SHADY_REWIND_PLUGIN", "rewind")

shady.bind("quit", "Super+Shift+Escape")
shady.bind("cycle_windows", "Super+Tab")
shady.bind("close_window", "Super+q")
