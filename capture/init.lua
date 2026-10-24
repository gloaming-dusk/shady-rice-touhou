-- Driver for capture.sh: the real Gensokyo runtime layer and shell, two
-- terminals, then one still of each part of the rice.
local rice = assert(os.getenv("SHADY_TOUHOU_DIR"))
dofile(rice .. "/init.lua")

local out = assert(os.getenv("CAPTURE_OUT"))
local status = assert(os.getenv("CAPTURE_STATUS"))
local only = os.getenv("CAPTURE_ONLY")
local auto = shady.automation
local after = auto.after

local function mark(line)
    local f = assert(io.open(status, "a"))
    f:write(line, "\n")
    f:close()
end

local function park() auto.move_pointer(5, 5) end

-- CAPTURE_SIZE (1920x1080) sets the headless output's mode first.
local size = os.getenv("CAPTURE_SIZE") or "1280x720"
local W, H = size:match("^(%d+)x(%d+)$")
W, H = tonumber(W), tonumber(H)
if size ~= "1280x720" then
    shady.spawn("wlr-randr --output HEADLESS-1 --custom-mode " .. size)
end
-- New windows open in the middle of what the side panel leaves.
local cx, cy = (W - 300) // 2, H // 2

local foot = string.format("foot --config=%q", assert(os.getenv("CAPTURE_FOOT_INI")))
local mapped = 0
shady.on("window.mapped", function(window)
    mapped = mapped + 1
    if mapped < 2 then return end
    -- Spread them out by their title bars: the notes down and right, the
    -- fetch up and left, where its orb and its text both show.
    after(1500, function()
        auto.drag(cx + 28, cy - 95, cx + 150, cy + 45, "left", 16)
        after(400, function()
            auto.drag(cx, cy - 148, cx - 160, cy - 274, "left", 16)
            after(400, park)
            after(2500, function() mark("READY") end)
        end)
    end)
end)

shady.spawn(string.format("%q", assert(os.getenv("SHADY_SHELL_BIN"))))
after(900, function()
    shady.spawn(foot .. string.format(" --app-id=fetch --title=%q --window-size-pixels=640x300 sh -c %q",
        "foot — ~", "FETCH_USER=reimu FETCH_HOST=hakurei-jinja FETCH_OS='Gloam (NixOS)' FETCH_UPTIME='3h 12m' "
        .. string.format("%q", rice .. "/tools/fetch.sh") .. "; sleep 3600"))
end)
after(1600, function()
    shady.spawn(foot .. string.format(" --app-id=notes --title=%q --window-size-pixels=520x260 sh -c %q",
        "文々。新聞 — notes", "printf '\\n  \\033[1m境界の向こうに、三次元の窓が現る\\033[0m\\n\\n  Shady 0.1 · a 3D Wayland compositor\\n'; sleep 3600"))
end)

local function notify(summary, body, urgency)
    shady.spawn(string.format(
        "busctl --user call org.freedesktop.Notifications /org/freedesktop/Notifications "
        .. "org.freedesktop.Notifications Notify susssasa{sv}i %q 0 '' %q %q 0 1 urgency y %d 6000",
        "Vesktop", summary, body, urgency))
end

local function shoot(name)
    return function(k)
        if only and not only:find(name, 1, true) then return k() end
        auto.screenshot(out .. "/" .. name .. ".png", function(ok)
            assert(ok, "screenshot failed: " .. name)
            k()
        end)
    end
end
local function wait(ms) return function(k) after(ms, k) end end
local function key(shortcut) return function(k) assert(auto.key(shortcut)); k() end end
local function sequence(steps)
    local function run(i)
        if steps[i] then steps[i](function() run(i + 1) end) end
    end
    run(1)
end

local function wait_ready(fn)
    local function poll()
        local f = io.open(status, "r")
        local text = f and f:read("a") or ""
        if f then f:close() end
        if text:find("READY", 1, true) then fn() else after(50, poll) end
    end
    poll()
end

wait_ready(function()
    park()
    sequence {
        shoot("desktop"),
        key("Super+d"),
        wait(1000),
        function(k) assert(auto.type_text("f")); k() end,
        wait(1500),
        shoot("launcher"),
        key("Super+d"),
        wait(900),
        key("Super+q"),
        wait(520),
        shoot("close"),
        wait(1800),
        function(k) notify("魔理沙", "今夜、神社で宴会するぜ。酒は持ってくから、つまみ頼む。", 1); k() end,
        wait(1500),
        shoot("notification"),
        function(k) notify("バッテリー残量 5%", "電源に接続してください", 2); k() end,
        wait(1200),
        shoot("cutin"),
        wait(6000),
        key("Super+a"),
        wait(9000),
        shoot("bad-apple"),
        key("Super+a"),
        wait(1500),
        key("Super+Shift+slash"),
        wait(1200),
        shoot("shortcuts"),
        function() mark("DONE"); shady.quit() end,
    }
end)
after(120000, function() shady.quit() end)
