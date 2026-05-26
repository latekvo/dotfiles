-- Custom theme: zenburn warmth + nerd font + tasteful gaps
local xresources = require("beautiful.xresources")
local dpi        = xresources.apply_dpi
local gfs        = require("gears.filesystem")
local themes_path = gfs.get_themes_dir()

local theme = dofile(themes_path .. "zenburn/theme.lua")

-- Typography: JetBrains Mono Nerd Font, slightly larger for HiDPI laptops
theme.font          = "JetBrainsMono Nerd Font 10"

-- Colors (zenburn warm dark, slightly punchier)
theme.bg_normal     = "#1f1f1f"
theme.bg_focus      = "#2a2a2a"
theme.bg_urgent     = "#cc4444"
theme.bg_minimize   = "#262626"
theme.bg_systray    = theme.bg_normal

theme.fg_normal     = "#dcdccc"
theme.fg_focus      = "#f0dfaf"
theme.fg_urgent     = "#ffffff"
theme.fg_minimize   = "#8f8f8f"

-- Borders and gaps — the heart of "rice"
theme.useless_gap         = dpi(6)
theme.border_width        = dpi(2)
theme.border_normal       = "#3f3f3f"
theme.border_focus        = "#f0dfaf"
theme.border_marked       = "#cc4444"

-- Taglist
theme.taglist_fg_focus    = "#f0dfaf"
theme.taglist_bg_focus    = "#3f3f3f"
theme.taglist_fg_occupied = "#dcdccc"
theme.taglist_fg_empty    = "#5f5f5f"

-- Tasklist
theme.tasklist_bg_focus   = "#2a2a2a"
theme.tasklist_fg_focus   = "#f0dfaf"
theme.tasklist_bg_normal  = theme.bg_normal
theme.tasklist_fg_normal  = "#9f9f9f"

-- Wallpaper (overridden by ~/.fehbg autostart anyway)
theme.wallpaper = os.getenv("HOME") .. "/Pictures/wallpapers/wall-midnight.png"

-- Notification (naughty / ruled)
theme.notification_font   = "JetBrainsMono Nerd Font 10"
theme.notification_bg     = "#1f1f1f"
theme.notification_fg     = "#dcdccc"
theme.notification_border_color = "#f0dfaf"
theme.notification_border_width = 1
theme.notification_max_width    = dpi(420)
theme.notification_icon_size    = dpi(48)

-- Hotkeys popup
theme.hotkeys_font        = "JetBrainsMono Nerd Font 10"
theme.hotkeys_description_font = "JetBrainsMono Nerd Font 10"

return theme
