-- If LuaRocks is installed, make sure that packages installed through it are
-- found (e.g. lgi). If LuaRocks is not installed, do nothing.
pcall(require, "luarocks.loader")

-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
local naughty = require("naughty")
local hotkeys_popup = require("awful.hotkeys_popup")
-- Enable hotkeys help widget for VIM and other apps
-- when client with a matching name is opened:
require("awful.hotkeys_popup.keys")

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = tostring(err) })
        in_error = false
    end)
end
-- }}}

-- {{{ Variable definitions
-- Themes define colours, icons, font and wallpapers.
beautiful.init(gears.filesystem.get_configuration_dir() .. "theme.lua")

terminal = "alacritty"
editor = os.getenv("EDITOR") or "nano"
editor_cmd = terminal .. " -e " .. editor

-- Default modkey. Usually Mod4 is the key with a logo between Control and Alt.
modkey = "Mod4"

awful.layout.layouts = {
    awful.layout.suit.floating,
    awful.layout.suit.tile,
}
-- }}}

-- {{{ Wibar
-- Date / time with seconds
mytextclock = wibox.widget.textclock(
    "<span foreground='#f0dfaf'>󰃭 </span>%a %d %b  <span foreground='#f0dfaf'>󰥔 </span>%H:%M  ",
    20)

-- Pure-Lua file readers replace awful.widget.watch's subprocess polling for
-- everything we can read directly from /proc or /sys. Saves a fork+exec per
-- widget per tick; the wibar used to burn 4 shells every 2-10 seconds.
local function read_first_line(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local line = f:read("*l")
    f:close()
    return line
end

-- CPU widget (averages over /proc/stat deltas, read directly from Lua)
local _cpu_prev = { idle = 0, total = 0 }
local cpuwidget = wibox.widget.textbox()
local function update_cpu()
    local line = read_first_line("/proc/stat")
    if not line then cpuwidget.markup = "󰻠 ?% " return end
    local user, nice, system, idle, iowait, irq, softirq, steal =
        line:match("cpu%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)")
    if not user then cpuwidget.markup = "󰻠 ?% " return end
    user, nice, system, idle = tonumber(user), tonumber(nice), tonumber(system), tonumber(idle)
    iowait, irq, softirq, steal = tonumber(iowait), tonumber(irq), tonumber(softirq), tonumber(steal)
    local total = user + nice + system + idle + iowait + irq + softirq + steal
    local d_total = total - _cpu_prev.total
    local d_idle  = idle  - _cpu_prev.idle
    _cpu_prev.total, _cpu_prev.idle = total, idle
    local pct = d_total > 0 and math.floor(100 * (d_total - d_idle) / d_total) or 0
    cpuwidget.markup = string.format("<span foreground='#f0dfaf'>󰻠 </span>%2d%%  ", pct)
end
gears.timer { timeout = 2, autostart = true, call_now = true, callback = update_cpu }

-- RAM widget (MiB used / total, via /proc/meminfo)
local memwidget = wibox.widget.textbox()
local function update_mem()
    local f = io.open("/proc/meminfo", "r")
    if not f then return end
    local total_kb, avail_kb
    for line in f:lines() do
        local k, v = line:match("(%S+):%s+(%d+) kB")
        if k == "MemTotal" then total_kb = tonumber(v)
        elseif k == "MemAvailable" then avail_kb = tonumber(v) end
        if total_kb and avail_kb then break end
    end
    f:close()
    if total_kb and avail_kb then
        memwidget.markup = string.format(
            "<span foreground='#f0dfaf'>󰍛 </span>%d/%d MiB  ",
            math.floor((total_kb - avail_kb) / 1024),
            math.floor(total_kb / 1024))
    end
end
gears.timer { timeout = 5, autostart = true, call_now = true, callback = update_mem }

-- Network rate widget (rx/tx Bps via /proc/net/dev for default-route iface)
local _net_prev = { rx = 0, tx = 0, t = os.time() }
local function fmt_rate(b)
    if b > 1024*1024 then return string.format("%.1fM", b/1024/1024) end
    if b > 1024 then return string.format("%.0fK", b/1024) end
    return string.format("%dB", b)
end
local function default_iface()
    local f = io.open("/proc/net/route", "r")
    if not f then return nil end
    f:read("*l") -- header
    for line in f:lines() do
        local iface, dest = line:match("(%S+)%s+(%S+)")
        if dest == "00000000" then f:close() return iface end
    end
    f:close()
    return nil
end
local netwidget = wibox.widget.textbox()
local function update_net()
    local iface = default_iface()
    if not iface then netwidget.markup = "󰖩 -- " return end
    local f = io.open("/proc/net/dev", "r")
    if not f then return end
    local rx, tx
    for line in f:lines() do
        local ifn, rest = line:match("^%s*(%S+):%s*(.+)$")
        if ifn == iface then
            local nums = {}
            for n in rest:gmatch("(%d+)") do nums[#nums+1] = tonumber(n) end
            rx, tx = nums[1], nums[9]
            break
        end
    end
    f:close()
    if not rx then netwidget.markup = "󰖩 -- " return end
    local now = os.time()
    local dt = math.max(now - _net_prev.t, 1)
    local drx = (rx - _net_prev.rx) / dt
    local dtx = (tx - _net_prev.tx) / dt
    _net_prev.rx, _net_prev.tx, _net_prev.t = rx, tx, now
    if drx < 0 or dtx < 0 then drx, dtx = 0, 0 end
    netwidget.markup = string.format(
        "<span foreground='#f0dfaf'>󰇚 </span>%s <span foreground='#f0dfaf'>󰕒 </span>%s  ",
        fmt_rate(drx), fmt_rate(dtx))
end
gears.timer { timeout = 2, autostart = true, call_now = true, callback = update_net }

-- Volume widget (pamixer-driven, click to toggle mute). Kept as a subprocess
-- poll because PulseAudio/PipeWire state has no clean kernel-side file to read.
local volwidget = awful.widget.watch(
    "sh -c 'pamixer --get-volume-human 2>/dev/null || echo n/a'", 2,
    function(widget, stdout)
        local v = stdout:gsub("%s+$", "")
        local icon = v:find("muted") and "󰝟" or "󰕾"
        widget.markup = string.format(
            "<span foreground='#f0dfaf'>%s </span>%s  ", icon, v)
    end)
volwidget:buttons(gears.table.join(
    awful.button({}, 1, function() awful.spawn("pamixer -t") end),
    awful.button({}, 4, function() awful.spawn("pamixer -i 5") end),
    awful.button({}, 5, function() awful.spawn("pamixer -d 5") end)
))

-- Battery widget (sysfs; gracefully shows "AC" when no BAT* present)
local batwidget = wibox.widget.textbox()
local function update_bat()
    local cap, status
    for _, name in ipairs({"BAT0", "BAT1", "BAT2"}) do
        local c = read_first_line("/sys/class/power_supply/" .. name .. "/capacity")
        if c then
            cap = c
            status = read_first_line("/sys/class/power_supply/" .. name .. "/status")
            break
        end
    end
    if not cap then
        batwidget.markup = "<span foreground='#f0dfaf'>󰚥 </span>AC  "
        return
    end
    local icon = (status == "Charging") and "󰂄" or "󰁹"
    local color = (tonumber(cap) <= 15) and "#cc4444" or "#f0dfaf"
    batwidget.markup = string.format(
        "<span foreground='%s'>%s </span>%s%%  ", color, icon, cap)
end
gears.timer { timeout = 10, autostart = true, call_now = true, callback = update_bat }

-- Create a wibox for each screen and add it
local taglist_buttons = gears.table.join(
                    awful.button({ }, 1, function(t) t:view_only() end),
                    awful.button({ modkey }, 1, function(t)
                                              if client.focus then
                                                  client.focus:move_to_tag(t)
                                              end
                                          end),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ modkey }, 3, function(t)
                                              if client.focus then
                                                  client.focus:toggle_tag(t)
                                              end
                                          end),
                    awful.button({ }, 4, function(t) awful.tag.viewnext(t.screen) end),
                    awful.button({ }, 5, function(t) awful.tag.viewprev(t.screen) end)
                )

local tasklist_buttons = gears.table.join(
                     awful.button({ }, 1, function (c)
                                              if c == client.focus then
                                                  c.minimized = true
                                              else
                                                  c:emit_signal(
                                                      "request::activate",
                                                      "tasklist",
                                                      {raise = true}
                                                  )
                                              end
                                          end),
                     awful.button({ }, 3, function()
                                              awful.menu.client_list({ theme = { width = 250 } })
                                          end),
                     awful.button({ }, 4, function ()
                                              awful.client.focus.byidx(1)
                                          end),
                     awful.button({ }, 5, function ()
                                              awful.client.focus.byidx(-1)
                                          end))

awful.screen.connect_for_each_screen(function(s)
    -- Each screen has its own tag table.
    awful.tag({ "1", "2", "3", "4", "5", "6", "7", "8", "9" }, s, awful.layout.layouts[1])

    -- Create an imagebox widget which will contain an icon indicating which layout we're using.
    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(gears.table.join(
                           awful.button({ }, 1, function () awful.layout.inc( 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(-1) end),
                           awful.button({ }, 4, function () awful.layout.inc( 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(-1) end)))
    -- Create a taglist widget
    s.mytaglist = awful.widget.taglist {
        screen  = s,
        filter  = awful.widget.taglist.filter.all,
        buttons = taglist_buttons
    }

    -- Create a tasklist widget
    s.mytasklist = awful.widget.tasklist {
        screen  = s,
        filter  = awful.widget.tasklist.filter.currenttags,
        buttons = tasklist_buttons
    }

    -- Create the wibox
    s.mywibox = awful.wibar({ position = "bottom", screen = s })

    -- Add widgets to the wibox
    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        { -- Left widgets
            layout = wibox.layout.fixed.horizontal,
            s.mytaglist,
        },
        s.mytasklist, -- Middle widget
        { -- Right widgets
            layout = wibox.layout.fixed.horizontal,
            spacing = 4,
            wibox.widget.systray(),
            cpuwidget,
            memwidget,
            netwidget,
            volwidget,
            batwidget,
            mytextclock,
            s.mylayoutbox,
        },
    }
end)
-- }}}

-- {{{ Mouse bindings
root.buttons(gears.table.join(
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings
globalkeys = gears.table.join(
    awful.key({ modkey,           }, "s",      hotkeys_popup.show_help,
              {description="show help", group="awesome"}),

    awful.key({ modkey,           }, "j",
        function ()
            awful.client.focus.byidx( 1)
        end,
        {description = "focus next by index", group = "client"}
    ),
    awful.key({ modkey,           }, "k",
        function ()
            awful.client.focus.byidx(-1)
        end,
        {description = "focus previous by index", group = "client"}
    ),

    -- Layout manipulation
    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end,
              {description = "swap with next client by index", group = "client"}),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end,
              {description = "swap with previous client by index", group = "client"}),

    -- Standard program
    awful.key({ modkey,           }, "Return", function () awful.spawn(terminal) end,
              {description = "open a terminal", group = "launcher"}),
    awful.key({ modkey, "Control" }, "r", awesome.restart,
              {description = "reload awesome", group = "awesome"}),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit,
              {description = "quit awesome", group = "awesome"}),

    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)          end,
              {description = "increase master width factor", group = "layout"}),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)          end,
              {description = "decrease master width factor", group = "layout"}),
    awful.key({ modkey,           }, "space", function () awful.layout.inc( 1)                end,
              {description = "toggle layout (tile / floating)", group = "layout"}),

    -- Rofi launcher
    awful.key({ modkey }, "d",
              function() awful.spawn("rofi -show drun") end,
              {description = "rofi: applications", group = "launcher"}),

    -- Audio media keys (pamixer / playerctl)
    awful.key({}, "XF86AudioRaiseVolume",
              function() awful.spawn("pamixer -i 5") end,
              {description = "volume up", group = "media"}),
    awful.key({}, "XF86AudioLowerVolume",
              function() awful.spawn("pamixer -d 5") end,
              {description = "volume down", group = "media"}),
    awful.key({}, "XF86AudioMute",
              function() awful.spawn("pamixer -t") end,
              {description = "toggle mute", group = "media"}),
    awful.key({}, "XF86AudioMicMute",
              function() awful.spawn("pamixer --default-source -t") end,
              {description = "toggle mic mute", group = "media"}),
    awful.key({}, "XF86AudioPlay",
              function() awful.spawn("playerctl play-pause") end,
              {description = "play/pause", group = "media"}),
    awful.key({}, "XF86AudioNext",
              function() awful.spawn("playerctl next") end,
              {description = "next track", group = "media"}),
    awful.key({}, "XF86AudioPrev",
              function() awful.spawn("playerctl previous") end,
              {description = "prev track", group = "media"}),

    -- Brightness
    awful.key({}, "XF86MonBrightnessUp",
              function() awful.spawn("brightnessctl set +10%") end,
              {description = "brightness up", group = "media"}),
    awful.key({}, "XF86MonBrightnessDown",
              function() awful.spawn("brightnessctl set 10%-") end,
              {description = "brightness down", group = "media"}),

    -- Screenshots (flameshot region-select)
    awful.key({}, "Print",
              function() awful.spawn("flameshot gui") end,
              {description = "screenshot (region)", group = "media"}),
    awful.key({ modkey }, "Print",
              function() awful.spawn("flameshot screen -c") end,
              {description = "screenshot (full screen)", group = "media"})
)

clientkeys = gears.table.join(
    awful.key({ modkey,           }, "f",
        function (c)
            c.fullscreen = not c.fullscreen
            c:raise()
        end,
        {description = "toggle fullscreen", group = "client"}),
    awful.key({ modkey, "Shift"   }, "c",      function (c) c:kill()                         end,
              {description = "close", group = "client"}),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ,
              {description = "toggle floating", group = "client"})
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it work on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 9 do
    globalkeys = gears.table.join(globalkeys,
        -- View tag only.
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = awful.screen.focused()
                        local tag = screen.tags[i]
                        if tag then
                           tag:view_only()
                        end
                  end,
                  {description = "view tag #"..i, group = "tag"}),
        -- Move client to tag.
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:move_to_tag(tag)
                          end
                     end
                  end,
                  {description = "move focused client to tag #"..i, group = "tag"})
    )
end

-- Guarded resize: titlebar strips and clientbuttons can both fire on
-- the same click; the second mousegrabber start would log an error.
local function safe_resize(c, corner)
    if mousegrabber.isrunning() then return end
    if corner then awful.mouse.client.resize(c, corner)
    else           awful.mouse.client.resize(c) end
end

-- Detect which edge/corner of `c` the pointer is near; return an
-- awful.placement direction string ("top_left", "right", ...) or nil
-- if the pointer is in the interior of the window.
local function edge_under_pointer(c, margin)
    margin = margin or 12
    local g = c:geometry()
    local m = mouse.coords()
    local on_left   = m.x - g.x < margin
    local on_right  = (g.x + g.width)  - m.x < margin
    local on_top    = m.y - g.y < margin
    local on_bottom = (g.y + g.height) - m.y < margin
    if on_top    and on_left  then return "top_left"     end
    if on_top    and on_right then return "top_right"    end
    if on_bottom and on_left  then return "bottom_left"  end
    if on_bottom and on_right then return "bottom_right" end
    if on_top    then return "top"    end
    if on_bottom then return "bottom" end
    if on_left   then return "left"   end
    if on_right  then return "right"  end
    return nil
end

clientbuttons = gears.table.join(
    awful.button({ }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        local corner = edge_under_pointer(c)
        if corner then
            safe_resize(c, corner)
        end
    end),
    awful.button({ modkey }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.move(c)
    end),
    awful.button({ modkey }, 3, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        safe_resize(c)
    end)
)

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = awful.client.focus.filter,
                     raise = true,
                     keys = clientkeys,
                     buttons = clientbuttons,
                     screen = awful.screen.preferred,
                     -- no_overlap is O(n*m) over existing clients per spawn; the
                     -- visible cost on every new window wasn't worth it.
                     placement = awful.placement.no_offscreen
     }
    },

    -- Floating clients.
    { rule_any = {
        instance = { "pinentry" },
        class    = { "Arandr" },
        role     = { "pop-up" }, -- e.g. Chrome's detached DevTools
      }, properties = { floating = true }},

}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c)
    if awesome.startup
      and not c.size_hints.user_position
      and not c.size_hints.program_position then
        -- Prevent clients from being unreachable after screen count changes.
        awful.placement.no_offscreen(c)
    end
end)

-- Edge-resize via titlebar strips was removed: the strips rendered as a
-- visible dark frame on translucent windows. Use Mod+RightClick to resize.

-- Enable sloppy focus, so that focus follows mouse.
client.connect_signal("mouse::enter", function(c)
    c:emit_signal("request::activate", "mouse_enter", {raise = false})
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
-- }}}

-- {{{ Autostart
-- Each is guarded with `pgrep` so re-running rc.lua (Mod4+Ctrl+R) doesn't duplicate.
local function run_once(cmd, match)
    match = match or cmd:match("[^ ]+")
    awful.spawn.with_shell(string.format(
        "pgrep -u $USER -x %s > /dev/null || (%s)", match, cmd))
end

run_once("picom --daemon",       "picom")
run_once("nm-applet",            "nm-applet")
run_once("blueman-applet",       "blueman-applet")
run_once("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1", "polkit-gnome-au")
-- PRIME render-offload hint (no-op when NVIDIA isn't there); load wallpaper via feh.
awful.spawn.with_shell(
    "xrandr --setprovideroutputsource modesetting NVIDIA-0 2>/dev/null; "
    .. "[ -f ~/.fehbg ] && ~/.fehbg")
-- }}}
