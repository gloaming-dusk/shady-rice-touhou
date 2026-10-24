-- Gensokyo: shady-shell as a shoot-'em-up at dusk over the Hakurei Shrine.
--
-- The wallpaper is the sky over the shrine (shaders/gensokyo.frag). On the
-- right runs the side panel of a Touhou game: the clock, the system as
-- Player, Bomb, Power, Graze and Point, the workspaces as stages and the
-- music as the BGM. The launcher declares a spell card, notifications are
-- Bunbunmaru extras, urgent ones cut in across the screen like a spell
-- card, and a new song is announced like a stage's BGM. The API is
-- documented in Shady's docs/SHELL_LUA_API.md.

local RED, RED_LIGHT, PAPER = "#C8283C", "#E86A7A", "#F4EEE3"
local GOLD, VIOLET, NIGHT = "#E8B84A", "#7A5CC9", "#120E2A"
local LACQUER, INK, DIM = "#160A1C", "#1A0E18", "#B8AFC8"
local GREEN, BLUE = "#7FD1A0", "#8FB4F0"
local a = shell.alpha

local PANEL_W = 300

shell.fonts("fonts")

local function mincho(size) return "Shippori Mincho B1 ExtraBold " .. size end
local function mincho_semi(size) return "Shippori Mincho B1 SemiBold " .. size end
local function gothic(size) return "Zen Kaku Gothic New Medium " .. size end
local function gothic_bold(size) return "Zen Kaku Gothic New Bold " .. size end

local function text(s, props)
    props = props or {}
    props.color = props.color or PAPER
    return shell.text(s, props)
end

local function trim(s)
    return ((s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- ---- the calendar, the old way ------------------------------------------

local MONTHS = { "睦月", "如月", "弥生", "卯月", "皐月", "水無月",
                 "文月", "葉月", "長月", "神無月", "霜月", "師走" }
local WEEKDAYS = { "日", "月", "火", "水", "木", "金", "土" }
local DIGITS = { "一", "二", "三", "四", "五", "六", "七", "八", "九" }
-- The twelve double hours, each starting at an odd hour (子 at 23:00).
local HOURS = { "子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥" }

local function kanji_number(n)
    if n < 10 then return DIGITS[n] end
    local tens, ones = n // 10, n % 10
    return (tens > 1 and DIGITS[tens] or "") .. "十" .. (ones > 0 and DIGITS[ones] or "")
end

local function old_date()
    local month = tonumber(shell.date("%m"))
    local day = tonumber(shell.date("%d"))
    local weekday = tonumber(shell.date("%w")) + 1
    local hour = tonumber(shell.date("%H"))
    local double_hour = HOURS[((hour + 1) // 2) % 12 + 1] .. "の刻"
    -- Dusk, when one meets the youkai.
    if hour >= 17 and hour < 19 then double_hour = "逢魔時" end
    return MONTHS[month] .. " " .. kanji_number(day) .. "日 · " ..
        WEEKDAYS[weekday] .. "曜 · " .. double_hour
end

-- ---- system state --------------------------------------------------------
-- Polled through ordinary commands; each is optional and its row hides
-- when the tool is missing.

local sys = {}

function sys.volume()
    local out = shell.poll("wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null", 2000)
    local v = tonumber(out:match("Volume:%s*([%d%.]+)") or "")
    return v and math.floor(v * 100 + 0.5), out:find("MUTED") ~= nil
end

function sys.battery()
    return tonumber(trim(shell.poll("cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1", 30000)))
end

function sys.wifi()
    local out = shell.poll("nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes:' | head -n1", 10000)
    local ssid = out:match("^yes:(.*)$")
    return ssid and trim(ssid) or nil
end

function sys.uptime()
    return tonumber(shell.poll("cut -d' ' -f1 /proc/uptime", 1000):match("^[%d%.]+") or "")
end

-- CPU use from two readings of /proc/stat, 0..1.
local cpu_last = { busy = nil, total = nil, use = nil, line = nil }
function sys.cpu()
    local line = shell.poll("head -n1 /proc/stat", 2000)
    if line ~= cpu_last.line then
        local n = {}
        for v in line:gmatch("%d+") do n[#n + 1] = tonumber(v) end
        if #n >= 4 then
            local idle = n[4] + (n[5] or 0)
            local total = 0
            for _, v in ipairs(n) do total = total + v end
            if cpu_last.total and total > cpu_last.total then
                cpu_last.use = 1 - (idle - cpu_last.idle) / (total - cpu_last.total)
            end
            cpu_last.idle, cpu_last.total = idle, total
        end
        cpu_last.line = line
    end
    return cpu_last.use
end

function sys.media()
    local out = shell.poll("playerctl metadata --format '{{status}}\t{{title}}\t{{artist}}\t{{duration(position)}}\t{{duration(mpris:length)}}' 2>/dev/null", 1000)
    local status, title, artist, pos, len = out:match("^(%a+)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\n]*)")
    if not status or title == "" then return nil end
    return { playing = status == "Playing", title = title, artist = trim(artist), position = pos, length = trim(len) }
end

-- ---- the sky -------------------------------------------------------------

shell.popup {
    name = "gensokyo-sky",
    layer = "background",
    fill = true,
    persistent = true,
    outputs = "all",
    shader = shell.shader("shaders/gensokyo.frag"),
    uniforms = function()
        local m = sys.media()
        return { panel = PANEL_W, beat = (m and m.playing) and 1 or 0 }
    end,
    view = function()
        return shell.stack { background = NIGHT }
    end,
}

-- ---- the side panel ------------------------------------------------------

local STAGES = {
    { name = "hakurei", title = "博麗神社" },
    { name = "forest", title = "魔法の森" },
    { name = "scarlet", title = "紅魔館" },
    { name = "netherworld", title = "白玉楼" },
    { name = "eientei", title = "永遠亭" },
    { name = "moriya", title = "守矢神社" },
}

local function window_count(name)
    local n = 0
    for _, w in ipairs(shell.windows()) do
        if w.workspace == name then n = n + 1 end
    end
    return n
end

local function stage_list()
    local known, list = {}, {}
    for _, name in ipairs(shell.workspaces()) do known[name] = true end
    for _, stage in ipairs(STAGES) do
        if known[stage.name] then list[#list + 1] = stage; known[stage.name] = nil end
    end
    -- Workspaces the rice does not know are Extra stages, shown while they
    -- hold windows or are the current one (Shady always has a "main").
    local active = shell.active_workspace()
    for _, name in ipairs(shell.workspaces()) do
        if known[name] and (name == active or window_count(name) > 0) then
            list[#list + 1] = { name = name, title = name, extra = true }
        end
    end
    return list
end

-- A score as the games print it: ten digits in groups of three.
local function score(n)
    local s = string.format("%010d", math.floor(n))
    return s:sub(1, 1) .. "," .. s:sub(2, 4) .. "," .. s:sub(5, 7) .. "," .. s:sub(8, 10)
end

local started = os.time()

local function stars(filled, color)
    local row = {}
    for i = 1, 5 do
        row[#row + 1] = text(i <= filled and "★" or "☆", {
            font = gothic_bold(12), color = i <= filled and color or a(color, 0.35), letter_spacing = 0,
        })
    end
    return shell.row { gap = 2, row }
end

local function hud_row(label, color, value, detail)
    return shell.row {
        gap = 10, align = "center",
        text(label, { font = mincho_semi(12), color = color, width = 62 }),
        shell.row { grow = 1, align = "center", value },
        detail and text(detail, { font = gothic(10), color = DIM, text_align = 1, width = 64 }) or false,
    }
end

local function power_bar(use)
    return shell.stack {
        width = 112, height = 6, radius = 3, background = a(PAPER, 0.12), clip = true,
        shell.box {
            left = 0, top = 0, bottom = 0, width = math.max(2, 112 * use), radius = 3,
            background = shell.gradient("horizontal", RED, GOLD), animate = "smooth",
        },
    }
end

local function hud(compact)
    local rows = {}
    local up = sys.uptime()
    if up and not compact then
        rows[#rows + 1] = hud_row("HiScore", DIM, text(score(up * 10), { font = mincho_semi(12), letter_spacing = 1 }))
    end
    if not compact then
        rows[#rows + 1] = hud_row("Score", PAPER, text(score((os.time() - started) * 10), { font = mincho_semi(12), letter_spacing = 1 }))
    end
    local battery = sys.battery()
    if battery then
        rows[#rows + 1] = hud_row("Player", RED_LIGHT, stars(math.ceil(battery / 20), RED_LIGHT), battery .. "%")
    end
    local volume, muted = sys.volume()
    if volume then
        rows[#rows + 1] = hud_row("Bomb", GREEN, stars(muted and 0 or math.ceil(volume / 20), GREEN),
            muted and "消音" or ("音 " .. volume))
    end
    local cpu = sys.cpu()
    if cpu then
        rows[#rows + 1] = hud_row("Power", GOLD, power_bar(cpu), string.format("%.2f", cpu * 4))
    end
    local graze = #shell.notifications()
    rows[#rows + 1] = hud_row("Graze", BLUE, text(tostring(graze), { font = mincho_semi(12) }), "通知")
    local wifi = sys.wifi()
    if wifi then
        rows[#rows + 1] = hud_row("Point", BLUE, text(wifi, { font = gothic(11), max_width = 120 }))
    end
    return shell.column { gap = 9, align = "stretch", rows }
end

local function stages(compact)
    local active = shell.active_workspace()
    local rows = {}
    for i, stage in ipairs(stage_list()) do
        local on = stage.name == active
        local count = window_count(stage.name)
        local dots = {}
        for _ = 1, math.min(count, 5) do
            dots[#dots + 1] = shell.box { width = 5, height = 5, radius = 1, rotate = 45,
                background = on and PAPER or a(PAPER, 0.5) }
        end
        rows[#rows + 1] = shell.row {
            id = "stage:" .. stage.name, gap = 10, align = "center", padding = { compact and 4 or 7, 12 }, radius = 3,
            background = on and shell.gradient("horizontal", a(RED, 0.75), a(RED, 0.0)) or nil,
            hover = { background = shell.gradient("horizontal", a(RED, 0.3), a(RED, 0.0)) },
            animate = "snappy",
            on_click = function(button) if button == "left" then shell.workspace(stage.name) end end,
            text(stage.extra and "Extra" or ("Stage " .. i), {
                font = gothic(9), color = on and PAPER or DIM, width = 48, letter_spacing = 0.5,
            }),
            text(stage.title, {
                font = mincho_semi(14), grow = 1, max_width = 150,
                color = on and "#FFFFFF" or (count > 0 and "#D9D0EA" or a(DIM, 0.7)),
            }),
            shell.row { gap = 4, dots },
        }
    end
    return shell.column { gap = 2, align = "stretch", rows }
end

local function bgm(compact)
    local m = sys.media()
    if not m then
        return shell.column {
            gap = 4, align = "start",
            text("♪ BGM", { font = gothic(9), color = DIM, letter_spacing = 3 }),
            text("静寂", { font = mincho_semi(13), color = a(PAPER, 0.5) }),
        }
    end
    local function button(id, icon, cmd)
        return shell.row {
            id = id, width = 30, height = 26, radius = 3, justify = "center",
            background = a(PAPER, 0.06), hover = { background = a(RED, 0.45) },
            on_click = function() shell.spawn(cmd) end,
            shell.icon(icon, { size = 13, color = PAPER }),
        }
    end
    return shell.column {
        gap = 5, align = "stretch",
        text("♪ BGM", { font = gothic(9), color = GOLD, letter_spacing = 3 }),
        text(m.title, { font = mincho_semi(compact and 12 or 14), max_width = 244, wrap = true, max_lines = compact and 1 or 2 }),
        m.artist ~= "" and not compact and text(m.artist, { font = gothic(10), color = DIM, max_width = 244 }) or false,
        shell.row {
            gap = 6, align = "center",
            button("bgm:prev", "previous", "playerctl previous"),
            button("bgm:play", m.playing and "pause" or "play", "playerctl play-pause"),
            button("bgm:next", "next", "playerctl next"),
            shell.spacer(),
            m.length ~= "" and text(m.position .. " / " .. m.length, { font = gothic(9), color = DIM }) or false,
        },
    }
end

-- Your own picture for the panel: tools/portrait.sh puts one here. None
-- ships with the rice.
local PORTRAIT = os.getenv("SHADY_TOUHOU_PORTRAIT") or
    ((os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")) .. "/shady/touhou/portrait.png")

local function portrait()
    local f = io.open(PORTRAIT, "rb")
    if not f then return false end
    f:close()
    return shell.stack {
        width = 244, height = 150, radius = 2, background = RED, padding = 2,
        shell.image { path = PORTRAIT, width = 240, height = 146 },
    }
end

local toggle_spellcard -- defined with the launcher below

shell.popup {
    name = "gensokyo-panel",
    layer = "top",
    anchor = { "top", "right", "bottom" },
    width = PANEL_W,
    exclusive = PANEL_W,
    persistent = true,
    outputs = "all",
    view = function(ctx)
        -- Tall outputs get everything; shorter ones drop the picture, then
        -- the scores, and tighten up.
        local h = (ctx.height or 0) > 0 and ctx.height or 1080
        local roomy, compact = h >= 1000, h < 860
        return shell.stack {
            background = shell.gradient("vertical", a(LACQUER, 0.88), a("#22091E", 0.92)),
            shell.box { left = 0, top = 0, bottom = 0, width = 2, background = RED },
            shell.box { left = 2, top = 0, bottom = 0, width = 4, background = a(PAPER, 0.05) },
            shell.column {
                left = 0, top = 0, right = 0, bottom = 0,
                padding = { compact and 18 or 28, 26, compact and 14 or 22, 30 },
                gap = compact and 11 or 15, align = "stretch",
                enter = { opacity = 0, translate = { 40, 0 } }, animate = "gentle",
                -- The title opens the spell cards, like Super+D.
                shell.row {
                    id = "title", align = "end", gap = 4, opacity = 1,
                    hover = { opacity = 0.8 },
                    on_click = function() toggle_spellcard() end,
                    text("東方", { font = mincho(21), shrink = 0 }),
                    text("幻想郷", { font = mincho(21), color = RED, shrink = 0 }),
                    shell.spacer(),
                    text("GENSOKYO", { font = gothic(7), color = DIM, letter_spacing = 2.5 }),
                },
                roomy and portrait() or false,
                shell.column {
                    gap = compact and 0 or 4, align = "start",
                    text(shell.date("%H:%M"), { font = mincho(compact and 40 or 52), letter_spacing = 1 }),
                    text(old_date(), { font = gothic(10), color = "#CFC6DD" }),
                },
                hud(compact),
                shell.box { height = 1, background = shell.gradient("horizontal", a(RED, 0), RED, a(RED, 0)) },
                stages(compact),
                shell.spacer(),
                shell.box { height = 1, background = a(PAPER, 0.12) },
                bgm(compact),
            },
        }
    end,
}

-- ---- the spell card: the launcher ----------------------------------------

-- Each application is declared under a sign that follows its categories.
local SIGNS = {
    { "TerminalEmulator", "霊符", RED_LIGHT },
    { "WebBrowser", "風符", GREEN },
    { "Network", "風符", GREEN },
    { "Chat", "伝符", BLUE },
    { "InstantMessaging", "伝符", BLUE },
    { "Development", "秘術", BLUE },
    { "TextEditor", "秘術", BLUE },
    { "Graphics", "彩符", GOLD },
    { "Audio", "音符", GREEN },
    { "Video", "幻符", VIOLET },
    { "AudioVideo", "音符", GREEN },
    { "Game", "遊符", "#B49AF0" },
    { "Office", "文符", PAPER },
    { "FileManager", "境符", VIOLET },
    { "Settings", "神符", GOLD },
    { "System", "霊符", RED_LIGHT },
    { "Utility", "宝符", GOLD },
}
local FALLBACK_SIGNS = { "夢符", "恋符", "魔符", "星符", "幻符", "奇術" }

local function sign_of(app)
    local cats = app.categories or ""
    for _, s in ipairs(SIGNS) do
        if cats:find(s[1] .. ";", 1, true) or cats:sub(-#s[1]) == s[1] then
            return s[2], s[3], s[1]
        end
    end
    local h = 0
    for i = 1, #app.name do h = (h * 31 + app.name:byte(i)) % 997 end
    return FALLBACK_SIGNS[h % #FALLBACK_SIGNS + 1], RED_LIGHT, nil
end

local spell = { query = "", selected = 1 }
local CARDS = 7

local function launch(app)
    shell.close("gensokyo-spellcard")
    shell.launch(app)
end

toggle_spellcard = function()
    spell.query, spell.selected = "", 1
    shell.toggle("gensokyo-spellcard")
end

shell.on("launcher", function() toggle_spellcard() end)

local function declared(app)
    local sign, color, category = sign_of(app)
    return shell.column {
        id = "card:" .. app.name, key = "declared",
        gap = 2, align = "start", padding = { 22, 26 }, radius = 2,
        background = shell.gradient("horizontal", PAPER, "#EADFCB"),
        shadow = { 0, 10, a(RED, 0.35) },
        enter = { opacity = 0, translate = { 60, 0 } }, animate = "gentle",
        on_click = function() launch(app) end,
        shell.row {
            align = "center", gap = 10,
            text(sign, { font = mincho_semi(15), color = "#8A2030" }),
            shell.spacer(),
            category and text(category, { font = gothic(9), color = "#8A2030", letter_spacing = 1 }) or false,
        },
        text("「" .. app.name .. "」", { font = mincho(38), color = INK, max_width = 560 }),
        text(app.exec, { font = gothic(10), color = "#5A4652", max_width = 560 }),
        shell.box { width = 1, height = 4 },
        text("↵ 宣言 · Tab 次のカード · Esc 取消", { font = gothic(9), color = a("#5A4652", 0.8) }),
    }, sign, color
end

local function card_row(app, i)
    local sign, color = sign_of(app)
    return shell.row {
        id = "card:" .. app.name, gap = 14, align = "center", padding = { 9, 18 },
        background = a(PAPER, 0.05), hover = { background = a(PAPER, 0.12) },
        enter = { opacity = 0, translate = { 40, 0 } }, animate = "snappy",
        on_click = function() launch(app) end,
        shell.box { width = 3, height = 22, background = color },
        text(sign, { font = mincho_semi(12), color = color, width = 34 }),
        text("「" .. app.name .. "」", { font = mincho_semi(17), grow = 1, max_width = 440 }),
        text(tostring(i), { font = gothic(9), color = DIM }),
    }
end

shell.popup {
    name = "gensokyo-spellcard",
    keyboard = "exclusive",
    text_input = true,
    fill = true,
    layer = "overlay",
    shader = shell.shader("shaders/spellcard.frag"),
    uniforms = { red = RED, glow = RED_LIGHT },
    view = function(ctx)
        local apps = shell.apps(spell.query, CARDS)
        if spell.selected > #apps then spell.selected = math.max(1, #apps) end
        local w, h = ctx.width or 1280, ctx.height or 720

        local big, sign = false, "符"
        local rest = {}
        for i, app in ipairs(apps) do
            if i == spell.selected then big, sign = declared(app)
            else rest[#rest + 1] = card_row(app, i) end
        end
        if #apps == 0 then
            big = text("「" .. spell.query .. "」に応える符は無い", {
                key = "empty", font = mincho_semi(18), color = DIM, padding = { 16, 4 },
            })
        end

        local query = (spell.query ~= "" or ctx.preedit) and shell.row {
            gap = 2, align = "center", grow = 1,
            text(spell.query, { font = mincho_semi(24) }),
            ctx.preedit and text(ctx.preedit, { font = mincho_semi(24), color = RED_LIGHT }) or false,
            shell.box { width = 2, height = 26, background = RED_LIGHT, caret = true },
        } or shell.row {
            grow = 1,
            shell.box { width = 0, height = 26, caret = true },
            text("スペルカード名を…", { font = mincho_semi(22), color = a(PAPER, 0.35) }),
        }

        local circle = math.floor(0.30 * h * 0.7)
        return shell.stack {
            -- The sign, at the heart of the magic circle (spellcard.frag).
            shell.box {
                left = math.floor(0.24 * w - circle / 2), top = math.floor(0.52 * h - circle / 2),
                width = circle, height = circle, justify = "center",
                text(sign:sub(1, 3), {
                    key = "sign", font = mincho(math.floor(circle * 0.42)), color = RED,
                    enter = { opacity = 0, scale = 1.6 }, animate = "bouncy",
                }),
            },
            shell.column {
                right = math.floor(w * 0.06), top = math.floor(h * 0.09),
                width = math.min(680, math.floor(w * 0.5)), gap = 14, align = "stretch",
                enter = { opacity = 0, translate = { 80, 0 } }, exit = { opacity = 0, translate = { 80, 0 } },
                animate = "gentle",
                text("SUPER + D · スペルカード宣言", { font = gothic(10), color = RED_LIGHT, letter_spacing = 4 }),
                shell.row {
                    gap = 12, align = "center", padding = { 12, 18 }, radius = 3,
                    background = a("#0A0612", 0.7), border = a(PAPER, 0.4),
                    text("「", { font = mincho(26), color = RED }),
                    query,
                    text("」", { font = mincho(26), color = RED }),
                },
                big or false,
                shell.column { gap = 4, align = "stretch", rest },
            },
        }
    end,
    on_key = function(key, typed)
        local apps = shell.apps(spell.query, CARDS)
        if key == "Escape" then
            shell.close("gensokyo-spellcard")
        elseif key == "Return" or key == "KP_Enter" then
            if apps[spell.selected] then launch(apps[spell.selected]) end
        elseif key == "Up" or key == "ISO_Left_Tab" then
            spell.selected = spell.selected > 1 and spell.selected - 1 or math.max(1, #apps)
        elseif key == "Down" or key == "Tab" then
            spell.selected = spell.selected < #apps and spell.selected + 1 or 1
        elseif key == "BackSpace" then
            local cut = utf8.offset(spell.query, -1)
            if cut then spell.query = spell.query:sub(1, cut - 1) end
            spell.selected = 1
        elseif typed ~= "" and #spell.query + #typed < 64 then
            spell.query = spell.query .. typed
            spell.selected = 1
        end
        shell.redraw()
    end,
}

-- ---- notifications: Bunbunmaru extras, and spell card cut-ins -----------

shell.notification_server()

local function sync_toasts()
    local normal, critical = false, false
    for _, n in ipairs(shell.notifications()) do
        if n.active then
            if n.urgency == "critical" then critical = true else normal = true end
        end
    end
    if normal ~= shell.is_open("gensokyo-toasts") then
        if normal then shell.open("gensokyo-toasts") else shell.close("gensokyo-toasts") end
    end
    if critical ~= shell.is_open("gensokyo-cutin") then
        if critical then shell.open("gensokyo-cutin") else shell.close("gensokyo-cutin") end
    end
end
shell.on("notifications", sync_toasts)

local function ago(t)
    local s = os.time() - (t or os.time())
    if s < 60 then return "今" end
    if s < 3600 then return (s // 60) .. "分前" end
    return (s // 3600) .. "時間前"
end

shell.popup {
    name = "gensokyo-toasts",
    anchor = { "top", "right" },
    margin = { top = 26, right = PANEL_W + 26 },
    width = 380,
    input = "widgets",
    view = function()
        local cards = {}
        for _, n in ipairs(shell.notifications()) do
            if n.active and n.urgency ~= "critical" and #cards < 3 then
                local tilt = (n.id % 3 - 1) * 1.2
                cards[#cards + 1] = shell.column {
                    id = "extra:" .. n.id, gap = 4, align = "stretch", padding = { 14, 18, 16, 18 },
                    radius = 1, background = #cards == 0 and PAPER or "#EADFCB",
                    shadow = { 0, 8, a("#000000", 0.35) }, rotate = tilt,
                    enter = { opacity = 0, translate = { 60, -10 }, rotate = tilt + 8 },
                    exit = { opacity = 0, translate = { 60, 0 } }, animate = "gentle",
                    on_click = function() shell.invoke_notification(n.id, "default") end,
                    shell.row {
                        align = "end", gap = 8,
                        text("号外", { font = mincho(18), color = INK }),
                        text(n.app ~= "" and n.app or "文々。新聞", { font = gothic(9), color = "#6B5A66", grow = 1, max_width = 200 }),
                        text(ago(n.time), { font = gothic(9), color = "#6B5A66" }),
                    },
                    shell.box { height = 2, background = INK },
                    text(n.summary ~= "" and n.summary or n.app, {
                        font = mincho_semi(15), color = INK, max_width = 340, wrap = true, max_lines = 2,
                    }),
                    n.body ~= "" and text(n.body, {
                        font = gothic(10), color = "#4A3A44", wrap = true, max_lines = 3, max_width = 340,
                    }) or false,
                }
            end
        end
        return shell.column { gap = 14, align = "stretch", padding = 8, cards }
    end,
}

shell.popup {
    name = "gensokyo-cutin",
    layer = "overlay",
    anchor = { "top", "left", "right" },
    margin = { top = 120, right = PANEL_W },
    height = 170,
    input = "widgets",
    view = function(ctx)
        local n
        for _, it in ipairs(shell.notifications()) do
            if it.active and it.urgency == "critical" then n = it; break end
        end
        if not n then return shell.box { width = 1, height = 1 } end
        -- Measured before the compositor gives it a width: assume one.
        local w = (ctx.width or 0) > 0 and ctx.width or 1280
        return shell.stack {
            width = w, height = 170,
            shell.stack {
                id = "cutin:" .. n.id, left = -60, right = 40, top = 30, height = 112, rotate = -3,
                background = shell.gradient("horizontal", a(RED, 0.96), a(RED, 0.9), a(RED, 0.6), a(RED, 0.0)),
                enter = { opacity = 0, translate = { -w, 0 } }, exit = { opacity = 0, translate = { w, 0 } },
                animate = "snappy",
                on_click = function() shell.dismiss_notification(n.id) end,
                shell.box { left = 0, right = 0, top = 0, height = 2,
                    background = shell.gradient("horizontal", PAPER, PAPER, a(PAPER, 0.5), a(PAPER, 0)) },
                shell.box { left = 0, right = 0, bottom = 0, height = 2,
                    background = shell.gradient("horizontal", PAPER, PAPER, a(PAPER, 0.5), a(PAPER, 0)) },
                shell.column {
                    left = 150, top = 12, gap = 2, align = "start",
                    shell.row {
                        gap = 14, align = "end",
                        text("警符", { font = mincho_semi(16) }),
                        text("「" .. (n.summary ~= "" and n.summary or n.app) .. "」", {
                            font = mincho(32), max_width = math.floor(w * 0.6),
                        }),
                    },
                    n.body ~= "" and text(n.body, {
                        font = gothic(10), color = a(PAPER, 0.85), max_width = math.floor(w * 0.6), padding = { 0, 0, 0, 58 },
                    }) or false,
                },
            },
        }
    end,
}

-- ---- BGM: a new song is announced like a stage's music -------------------

local bgm_seen = { title = nil, at = 0 }

shell.popup {
    name = "gensokyo-bgm",
    layer = "top",
    anchor = { "bottom", "left" },
    margin = { bottom = 36, left = 0 },
    persistent = true,
    input = "widgets",
    view = function()
        local m = sys.media()
        local title = m and m.title or nil
        if title ~= bgm_seen.title then
            bgm_seen.title, bgm_seen.at = title, os.time()
        end
        local showing = title and os.time() - bgm_seen.at < 7
        if not showing then return shell.box { width = 1, height = 1 } end
        shell.date("%S") -- repaint every second while the title is up
        return shell.row {
            key = "bgm:" .. title, gap = 12, align = "center", padding = { 12, 28, 12, 22 },
            background = shell.gradient("horizontal", a("#0A0612", 0.88), a("#0A0612", 0.0)),
            enter = { opacity = 0, translate = { -40, 0 } }, exit = { opacity = 0 }, animate = "gentle",
            shell.box { width = 3, height = 26, background = GOLD },
            text("♪", { font = mincho(18), color = GOLD }),
            text("BGM:", { font = mincho_semi(18) }),
            text(title, { font = mincho_semi(18), max_width = 560 }),
        }
    end,
}

-- ---- shortcuts (Super+Shift+/) -------------------------------------------

require("shortcut_overlay").install {
    name = "gensokyo-shortcuts",
    palette = { text = PAPER, text_dim = DIM, accent = RED_LIGHT, surface = a(LACQUER, 0.9) },
    title = "操作説明 · Shortcuts",
    title_font = mincho(18),
    font = gothic(10),
    bold = gothic_bold(10),
    cap = function()
        return { radius = 2, font = gothic_bold(9), color = PAPER, background = a(RED, 0.35), border = a(RED_LIGHT, 0.6) }
    end,
    frame = function(body)
        return shell.column {
            radius = 2, padding = 28, align = "stretch", background = a(LACQUER, 0.92), border = RED,
            enter = { opacity = 0, scale = 0.95 }, exit = { opacity = 0 }, animate = "gentle",
            body,
        }
    end,
}
