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
local menubar = require("menubar")
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

-- This is used later as the default terminal and editor to run.
terminal = "alacritty"
editor = os.getenv("EDITOR") or "nano"
editor_cmd = terminal .. " -e " .. editor

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
modkey = "Mod4"

-- Table of layouts to cover with awful.layout.inc, order matters.
awful.layout.layouts = {
    awful.layout.suit.floating,
    awful.layout.suit.tile,
    awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    awful.layout.suit.tile.top,
    awful.layout.suit.fair,
    awful.layout.suit.fair.horizontal,
    awful.layout.suit.spiral,
    awful.layout.suit.spiral.dwindle,
    awful.layout.suit.max,
    awful.layout.suit.max.fullscreen,
    awful.layout.suit.magnifier,
    awful.layout.suit.corner.nw,
    -- awful.layout.suit.corner.ne,
    -- awful.layout.suit.corner.sw,
    -- awful.layout.suit.corner.se,
}
-- }}}

-- {{{ Menu
-- Create a launcher widget and a main menu
myawesomemenu = {
   { "hotkeys", function() hotkeys_popup.show_help(nil, awful.screen.focused()) end },
   { "manual", terminal .. " -e man awesome" },
   { "edit config", editor_cmd .. " " .. awesome.conffile },
   { "restart", awesome.restart },
   { "quit", function() awesome.quit() end },
}

mymainmenu = awful.menu({ items = { { "awesome", myawesomemenu, beautiful.awesome_icon },
                                    { "open terminal", terminal }
                                  }
                        })

mylauncher = awful.widget.launcher({ image = beautiful.awesome_icon,
                                     menu = mymainmenu })

-- Menubar configuration
menubar.utils.terminal = terminal -- Set the terminal for applications that require it
-- }}}

-- Keyboard map indicator and switcher
mykeyboardlayout = awful.widget.keyboardlayout()

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

local function set_wallpaper(s)
    -- Wallpaper
    if beautiful.wallpaper then
        local wallpaper = beautiful.wallpaper
        -- If wallpaper is a function, call it with the screen
        if type(wallpaper) == "function" then
            wallpaper = wallpaper(s)
        end
        gears.wallpaper.maximized(wallpaper, s, true)
    end
end

-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
screen.connect_signal("property::geometry", set_wallpaper)

awful.screen.connect_for_each_screen(function(s)
    -- Wallpaper
    set_wallpaper(s)

    -- Each screen has its own tag table.
    awful.tag({ "1", "2", "3", "4", "5", "6", "7", "8", "9" }, s, awful.layout.layouts[1])

    -- Create a promptbox for each screen
    s.mypromptbox = awful.widget.prompt()
    -- Create an imagebox widget which will contain an icon indicating which layout we're using.
    -- We need one layoutbox per screen.
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
            mylauncher,
            s.mytaglist,
            s.mypromptbox,
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
            mykeyboardlayout,
            mytextclock,
            s.mylayoutbox,
        },
    }
end)
-- }}}

-- {{{ Mouse bindings
root.buttons(gears.table.join(
    awful.button({ }, 3, function () mymainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings
globalkeys = gears.table.join(
    awful.key({ modkey,           }, "s",      hotkeys_popup.show_help,
              {description="show help", group="awesome"}),
    awful.key({ modkey,           }, "Left",   awful.tag.viewprev,
              {description = "view previous", group = "tag"}),
    awful.key({ modkey,           }, "Right",  awful.tag.viewnext,
              {description = "view next", group = "tag"}),
    awful.key({ modkey,           }, "Escape", awful.tag.history.restore,
              {description = "go back", group = "tag"}),

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
    awful.key({ modkey,           }, "w", function () mymainmenu:show() end,
              {description = "show main menu", group = "awesome"}),

    -- Layout manipulation
    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end,
              {description = "swap with next client by index", group = "client"}),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end,
              {description = "swap with previous client by index", group = "client"}),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end,
              {description = "focus the next screen", group = "screen"}),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end,
              {description = "focus the previous screen", group = "screen"}),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto,
              {description = "jump to urgent client", group = "client"}),
    awful.key({ modkey,           }, "Tab",
        function ()
            awful.client.focus.history.previous()
            if client.focus then
                client.focus:raise()
            end
        end,
        {description = "go back", group = "client"}),

    -- Standard program
    awful.key({ modkey,           }, "Return", function () awful.spawn(terminal) end,
              {description = "open a terminal", group = "launcher"}),
    awful.key({ "Control", "Mod1" }, "t", function () awful.spawn(terminal) end,
              {description = "open a terminal", group = "launcher"}),
    awful.key({ "Control", "Shift" }, "t", function () awful.spawn(terminal) end,
              {description = "open a terminal", group = "launcher"}),
    awful.key({ modkey, "Control" }, "r", awesome.restart,
              {description = "reload awesome", group = "awesome"}),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit,
              {description = "quit awesome", group = "awesome"}),

    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)          end,
              {description = "increase master width factor", group = "layout"}),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)          end,
              {description = "decrease master width factor", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1, nil, true) end,
              {description = "increase the number of master clients", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1, nil, true) end,
              {description = "decrease the number of master clients", group = "layout"}),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1, nil, true)    end,
              {description = "increase the number of columns", group = "layout"}),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1, nil, true)    end,
              {description = "decrease the number of columns", group = "layout"}),
    awful.key({ modkey,           }, "space", function () awful.layout.inc( 1)                end,
              {description = "select next", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(-1)                end,
              {description = "select previous", group = "layout"}),

    awful.key({ modkey, "Control" }, "n",
              function ()
                  local c = awful.client.restore()
                  -- Focus restored client
                  if c then
                    c:emit_signal(
                        "request::activate", "key.unminimize", {raise = true}
                    )
                  end
              end,
              {description = "restore minimized", group = "client"}),

    -- Prompt
    awful.key({ modkey },            "r",     function () awful.screen.focused().mypromptbox:run() end,
              {description = "run prompt", group = "launcher"}),

    awful.key({ modkey }, "x",
              function ()
                  awful.prompt.run {
                    prompt       = "Run Lua code: ",
                    textbox      = awful.screen.focused().mypromptbox.widget,
                    exe_callback = awful.util.eval,
                    history_path = awful.util.get_cache_dir() .. "/history_eval"
                  }
              end,
              {description = "lua execute prompt", group = "awesome"}),
    -- Menubar
    awful.key({ modkey }, "p", function() menubar.show() end,
              {description = "show the menubar", group = "launcher"}),

    -- Rofi launcher (Mod+d = drun; Mod+Tab handled below for window switch)
    awful.key({ modkey }, "d",
              function() awful.spawn("rofi -show drun") end,
              {description = "rofi: applications", group = "launcher"}),
    awful.key({ modkey, "Shift" }, "d",
              function() awful.spawn("rofi -show run") end,
              {description = "rofi: run command", group = "launcher"}),

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
              {description = "screenshot (full screen)", group = "media"}),

    -- Lock screen (xss-lock + i3lock not configured; fallback to xset dpms off — placeholder)
    awful.key({ modkey, "Shift" }, "l",
              function() awful.spawn("sh -c 'xset s activate'") end,
              {description = "blank screen", group = "awesome"})
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
              {description = "toggle floating", group = "client"}),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end,
              {description = "move to master", group = "client"}),
    awful.key({ modkey,           }, "o",      function (c) c:move_to_screen()               end,
              {description = "move to screen", group = "client"}),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end,
              {description = "toggle keep on top", group = "client"}),
    awful.key({ modkey,           }, "n",
        function (c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
        end ,
        {description = "minimize", group = "client"}),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized = not c.maximized
            c:raise()
        end ,
        {description = "(un)maximize", group = "client"}),
    awful.key({ modkey, "Control" }, "m",
        function (c)
            c.maximized_vertical = not c.maximized_vertical
            c:raise()
        end ,
        {description = "(un)maximize vertically", group = "client"}),
    awful.key({ modkey, "Shift"   }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c:raise()
        end ,
        {description = "(un)maximize horizontally", group = "client"})
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
        -- Toggle tag display.
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = awful.screen.focused()
                      local tag = screen.tags[i]
                      if tag then
                         awful.tag.viewtoggle(tag)
                      end
                  end,
                  {description = "toggle tag #" .. i, group = "tag"}),
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
                  {description = "move focused client to tag #"..i, group = "tag"}),
        -- Toggle tag on focused client.
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:toggle_tag(tag)
                          end
                      end
                  end,
                  {description = "toggle focused client on tag #" .. i, group = "tag"})
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
        instance = {
          "DTA",  -- Firefox addon DownThemAll.
          "copyq",  -- Includes session name in class.
          "pinentry",
        },
        class = {
          "Arandr",
          "Blueman-manager",
          "Gpick",
          "Kruler",
          "MessageWin",  -- kalarm.
          "Sxiv",
          "Tor Browser", -- Needs a fixed window size to avoid fingerprinting by screen size.
          "Wpa_gui",
          "veromix",
          "xtightvncviewer"},

        -- Note that the name property shown in xprop might be set slightly after creation of the client
        -- and the name shown there might not match defined rules here.
        name = {
          "Event Tester",  -- xev.
        },
        role = {
          "AlarmWindow",  -- Thunderbird's calendar.
          "ConfigManager",  -- Thunderbird's about:config.
          "pop-up",       -- e.g. Google Chrome's (detached) Developer Tools.
        }
      }, properties = { floating = true }},

    -- Add titlebars to normal clients and dialogs
    { rule_any = {type = { "normal", "dialog" }
      }, properties = { titlebars_enabled = true }
    },

    -- Set Firefox to always map on the tag named "2" on screen 1.
    -- { rule = { class = "Firefox" },
    --   properties = { screen = 1, tag = "2" } },
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c)
    -- Set the windows at the slave,
    -- i.e. put it at the end of others instead of setting it master.
    -- if not awesome.startup then awful.client.setslave(c) end

    if awesome.startup
      and not c.size_hints.user_position
      and not c.size_hints.program_position then
        -- Prevent clients from being unreachable after screen count changes.
        awful.placement.no_offscreen(c)
    end
end)

-- Add a titlebar if titlebars_enabled is set to true in the rules.
client.connect_signal("request::titlebars", function(c)
    -- buttons for the titlebar
    local buttons = gears.table.join(
        awful.button({ }, 1, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.move(c)
        end),
        awful.button({ }, 3, function()
            c:emit_signal("request::activate", "titlebar", {raise = true})
            awful.mouse.client.resize(c)
        end)
    )

    -- Edge resize handles: thin invisible strips on left/right/bottom that
    -- start awful.mouse.client.resize() on left-click drag. Works for both
    -- floating clients (free-form geometry) and tiled clients (adjusts ratios).
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

    awful.titlebar(c) : setup {
        { -- Left
            awful.titlebar.widget.iconwidget(c),
            buttons = buttons,
            layout  = wibox.layout.fixed.horizontal
        },
        { -- Middle
            { -- Title
                align  = "center",
                widget = awful.titlebar.widget.titlewidget(c)
            },
            buttons = buttons,
            layout  = wibox.layout.flex.horizontal
        },
        { -- Right
            awful.titlebar.widget.floatingbutton (c),
            awful.titlebar.widget.maximizedbutton(c),
            awful.titlebar.widget.stickybutton   (c),
            awful.titlebar.widget.ontopbutton    (c),
            awful.titlebar.widget.closebutton    (c),
            layout = wibox.layout.fixed.horizontal()
        },
        layout = wibox.layout.align.horizontal
    }
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
run_once("flameshot",            "flameshot")
run_once("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1", "polkit-gnome-au")
-- PRIME render-offload hint (no-op when NVIDIA isn't there)
awful.spawn.with_shell(
    "xrandr --setprovideroutputsource modesetting NVIDIA-0 2>/dev/null; "
    .. "[ -f ~/.fehbg ] && ~/.fehbg")
-- }}}