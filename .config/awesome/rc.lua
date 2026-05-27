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

-- CPU widget (averages over /proc/stat deltas)
local _cpu_prev = { idle = 0, total = 0 }
local cpuwidget = awful.widget.watch("cat /proc/stat", 2, function(widget, stdout)
    local user, nice, system, idle, iowait, irq, softirq, steal =
        stdout:match("cpu%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)")
    if not user then widget.markup = "󰻠 ?% " return end
    local total = user + nice + system + idle + iowait + irq + softirq + steal
    local d_total = total - _cpu_prev.total
    local d_idle  = idle  - _cpu_prev.idle
    _cpu_prev.total, _cpu_prev.idle = total, idle
    local pct = d_total > 0 and math.floor(100 * (d_total - d_idle) / d_total) or 0
    widget.markup = string.format("<span foreground='#f0dfaf'>󰻠 </span>%2d%%  ", pct)
end)

-- RAM widget (MiB used / total)
local memwidget = awful.widget.watch("free -m", 5, function(widget, stdout)
    local total, used = stdout:match("Mem:%s+(%d+)%s+(%d+)")
    if total then
        widget.markup = string.format(
            "<span foreground='#f0dfaf'>󰍛 </span>%s/%s MiB  ", used, total)
    end
end)

-- Network rate widget (rx/tx Bps via /proc/net/dev primary up iface)
local _net_prev = { rx = 0, tx = 0, t = os.time() }
local function fmt_rate(b)
    if b > 1024*1024 then return string.format("%.1fM", b/1024/1024) end
    if b > 1024 then return string.format("%.0fK", b/1024) end
    return string.format("%dB", b)
end
local netwidget = awful.widget.watch(
    [[sh -c "IF=$(ip route show default 2>/dev/null | awk '/^default/{print $5; exit}'); ]]
    .. [[awk -v IF=\"$IF\" '$1 ~ IF\":\" {sub(\":\",\"\",$1); print $1, $2, $10; exit}' /proc/net/dev"]],
    2, function(widget, stdout)
        local iface, rx, tx = stdout:match("(%S+)%s+(%d+)%s+(%d+)")
        if not rx then widget.markup = "󰖩 -- " return end
        local now = os.time()
        local dt = math.max(now - _net_prev.t, 1)
        local drx = (tonumber(rx) - _net_prev.rx) / dt
        local dtx = (tonumber(tx) - _net_prev.tx) / dt
        _net_prev.rx, _net_prev.tx, _net_prev.t = tonumber(rx), tonumber(tx), now
        if drx < 0 or dtx < 0 then drx, dtx = 0, 0 end
        widget.markup = string.format(
            "<span foreground='#f0dfaf'>󰇚 </span>%s <span foreground='#f0dfaf'>󰕒 </span>%s  ",
            fmt_rate(drx), fmt_rate(dtx))
    end)

-- Volume widget (pamixer-driven, click to toggle mute)
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

-- Battery widget (sysfs; gracefully shows "AC" on desktops)
local batwidget = awful.widget.watch(
    "sh -c 'for b in /sys/class/power_supply/BAT*; do [ -e \"$b\" ] && cat \"$b/capacity\" \"$b/status\"; done'",
    10, function(widget, stdout)
        local cap, status = stdout:match("(%d+)%s+(%a+)")
        if not cap then widget.markup = "<span foreground='#f0dfaf'>󰚥 </span>AC  " return end
        local icon = (status == "Charging") and "󰂄" or "󰁹"
        local color = (tonumber(cap) <= 15) and "#cc4444" or "#f0dfaf"
        widget.markup = string.format(
            "<span foreground='%s'>%s </span>%s%%  ", color, icon, cap)
    end)

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
              function() awful.spawn("flameshot screen") end,
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
            awful.mouse.client.resize(c, corner)
        end
    end),
    awful.button({ modkey }, 1, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.move(c)
    end),
    awful.button({ modkey }, 3, function (c)
        c:emit_signal("request::activate", "mouse_click", {raise = true})
        awful.mouse.client.resize(c)
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
                     placement = awful.placement.no_overlap+awful.placement.no_offscreen
     }
    },

    -- Floating clients.
    { rule_any = {
        instance = { "pinentry" },
        class    = { "Arandr" },
        role     = { "pop-up" }, -- e.g. Chrome's detached DevTools
      }, properties = { floating = true }},

    -- Enable titlebars on normal/dialog clients so the invisible
    -- edge-resize handles below have a surface to live on.
    { rule_any = {type = { "normal", "dialog" }
      }, properties = { titlebars_enabled = true }
    },
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

-- Invisible edge-resize handles: thin strips on left/right/bottom that
-- start awful.mouse.client.resize() on click. Works for both floating
-- (free-form geometry) and tiled clients (adjusts ratios). No top
-- titlebar -- title info lives in the wibar tasklist.
client.connect_signal("request::titlebars", function(c)
    local edge_resize_buttons = gears.table.join(
        awful.button({ }, 1, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.resize(c)
        end),
        awful.button({ }, 3, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.resize(c)
        end)
    )
    for _, pos in ipairs({"left", "right", "bottom"}) do
        awful.titlebar(c, { position = pos, size = 4, bg = "#1f1f1f" }) :setup {
            buttons = edge_resize_buttons,
            layout  = wibox.layout.flex.horizontal,
        }
    end
end)

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
