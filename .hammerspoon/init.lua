require("hs.ipc")
hs.window.animationDuration = 0

local HOLD_SECONDS = 2
local WINDOWS_PER_SPACE = 6
local FREE_SPACE_MAX_WINDOWS = 1

-- Visible standard windows on the active space of the screen (default: the
-- focused one), in reading order so windows stay near where they already were.
local function screenWindows(screen)
  if not screen then
    local focused = hs.window.focusedWindow()
    screen = focused and focused:screen() or hs.mouse.getCurrentScreen()
  end
  local space = hs.spaces.activeSpaceOnScreen(screen)

  -- hs.window can report windows on inactive spaces as visible.
  local wins = hs.fnutils.filter(hs.window.visibleWindows(), function(w)
    return w:isStandard() and not w:isFullScreen() and w:screen() == screen
      and hs.fnutils.contains(hs.spaces.windowSpaces(w) or {}, space)
  end)
  table.sort(wins, function(a, b)
    local fa, fb = a:frame(), b:frame()
    if fa.y ~= fb.y then return fa.y < fb.y end
    return fa.x < fb.x
  end)
  return wins, screen
end

-- Even grid: rows (columns on a portrait screen) = floor(sqrt(n)); windows are
-- spread across them as evenly as possible, each line splitting its span equally.
local function tile(wins, area)
  local n = #wins
  if n == 0 then return end

  local portrait = area.h > area.w
  local lines = math.max(1, math.floor(math.sqrt(n)))
  local base, extra = n // lines, n % lines

  local i = 1
  for line = 0, lines - 1 do
    local count = base + (line < extra and 1 or 0)
    for slot = 0, count - 1 do
      local f
      if portrait then
        local w = area.w / lines
        local h = area.h / count
        f = { x = area.x + line * w, y = area.y + slot * h, w = w, h = h }
      else
        local w = area.w / count
        local h = area.h / lines
        f = { x = area.x + slot * w, y = area.y + line * h, w = w, h = h }
      end
      wins[i]:setFrame(f)
      i = i + 1
    end
  end
end

local function tileScreen()
  local wins, screen = screenWindows()
  tile(wins, screen:frame())
end

local function waitFor(predicate, seconds)
  local deadline = hs.timer.secondsSinceEpoch() + seconds
  repeat
    local value = predicate()
    if value then return value end
    hs.timer.usleep(20000)
  until hs.timer.secondsSinceEpoch() > deadline
end

local function axChild(element, id)
  for _, c in ipairs(element.AXChildren or {}) do
    if c.AXIdentifier == id then return c end
  end
end

-- Nil while closed. macOS 27 moved it from the Dock (under an "mc" group),
-- where hs.spaces.addSpaceToScreen looks, to WindowManager.
local function missionControl(screen)
  for _, bundleID in ipairs({ "com.apple.WindowManager", "com.apple.dock" }) do
    local app = hs.application.applicationsForBundleID(bundleID)[1]
    local root = app and hs.axuielement.applicationElement(app)
    for _, display in ipairs(root and (axChild(root, "mc") or root).AXChildren or {}) do
      if display.AXIdentifier == "mc.display" and display.AXDisplayID == screen:id() then
        return display
      end
    end
  end
end

local function addSpace(screen)
  hs.application.launchOrFocusByBundleID("com.apple.exposelauncher")
  local mc = waitFor(function() return missionControl(screen) end, 2)
  if not mc then return end
  -- It ignores presses until done opening.
  hs.timer.usleep(300000)
  local existing = {}
  for _, id in ipairs(hs.spaces.spacesForScreen(screen)) do existing[id] = true end
  axChild(axChild(mc, "mc.spaces"), "mc.spaces.add"):doAXPress()
  local added = waitFor(function()
    for _, id in ipairs(hs.spaces.spacesForScreen(screen)) do
      if not existing[id] then return id end
    end
  end, 2)
  hs.eventtap.keyStroke({}, "escape")
  -- Its tree vanishes at once, but windows can't be grabbed until it's closed.
  hs.timer.usleep(500000)
  return added
end

-- Via the "Move left/right a space" shortcuts, which synthetic arrows only
-- trigger with fn. One switch at a time: carrying a window drops presses made
-- mid-switch.
local function walkTo(screen, space)
  local spaces = hs.spaces.spacesForScreen(screen)
  local target = hs.fnutils.indexOf(spaces, space)
  local E = hs.eventtap.event
  while true do
    local active = hs.spaces.activeSpaceOnScreen(screen)
    if active == space then return true end
    local key = target < hs.fnutils.indexOf(spaces, active) and "left" or "right"
    E.newKeyEvent({ "ctrl", "fn" }, key, true):post()
    E.newKeyEvent({ "ctrl", "fn" }, key, false):post()
    if not waitFor(function() return hs.spaces.activeSpaceOnScreen(screen) ~= active end, 2) then
      return false
    end
  end
end

-- macOS ignores hs.spaces.moveWindowToSpace, so the window is dragged by its
-- title bar, beside the zoom button, while switching.
local function carryTo(win, space)
  local zoom = win:zoomButtonRect()
  if not zoom then return false end
  local screen, frame = win:screen(), win:frame()
  local E = hs.eventtap.event
  local at = { x = zoom.x + zoom.w + 5, y = zoom.y + zoom.h / 2 }
  local mouse = hs.mouse.absolutePosition()
  win:focus()
  waitFor(function()
    local focused = hs.window.focusedWindow()
    return focused and focused:id() == win:id()
  end, 1)
  E.newMouseEvent(E.types.leftMouseDown, at):post()
  -- A nudge shows whether the grab took.
  for _ = 1, 4 do
    at.x = at.x + 2
    E.newMouseEvent(E.types.leftMouseDragged, at):post()
    hs.timer.usleep(20000)
  end
  local carried = waitFor(function() return win:frame().x ~= frame.x end, 0.5)
    and walkTo(screen, space)
  E.newMouseEvent(E.types.leftMouseUp, at):post()
  hs.mouse.absolutePosition(mouse)
  win:setFrame(frame)
  return carried and waitFor(function()
    return hs.fnutils.contains(hs.spaces.windowSpaces(win) or {}, space)
  end, 1) or false
end

-- Tile the windows WINDOWS_PER_SPACE at a time: the first group stays on the
-- current space, each further group goes to a newly added space.
local function spreadAcrossSpaces()
  local wins, screen = screenWindows()
  local area = screen:frame()

  local groups = {}
  for i = 1, #wins, WINDOWS_PER_SPACE do
    groups[#groups + 1] = table.move(wins, i, i + WINDOWS_PER_SPACE - 1, 1, {})
  end
  for _, group in ipairs(groups) do tile(group, area) end

  local home = hs.spaces.activeSpaceOnScreen(screen)
  local focused = hs.window.focusedWindow()
  local stuck = {}
  for g = 2, #groups do
    local space = addSpace(screen)
    if not space then
      hs.alert.show("Adding a desktop failed")
      break
    end
    for _, w in ipairs(groups[g]) do
      if not carryTo(w, space) then stuck[#stuck + 1] = w:title() or "?" end
      if not walkTo(screen, home) then
        hs.alert.show("Switching desktop failed")
        return
      end
    end
  end
  if #stuck > 0 then hs.alert.show("Couldn't move: " .. table.concat(stuck, ", ")) end
  -- Focus left with the carried windows.
  if #groups > 1 then
    local keep = hs.fnutils.find(groups[1], function(w) return focused and w:id() == focused:id() end)
      or groups[1][1]
    keep:focus()
  end
end

-- First user space after the screen's active one, wrapping, that holds at most
-- FREE_SPACE_MAX_WINDOWS windows. hs.window only sees windows on visible spaces,
-- so windows are counted from CoreGraphics: normal layer, not transparent.
local function nextFreeSpace(screen)
  local ok, ids = hs.osascript.javascript([[
    ObjC.import("CoreGraphics");
    ObjC.deepUnwrap(ObjC.castRefToObject($.CGWindowListCopyWindowInfo($.kCGWindowListOptionAll, 0)))
      .filter(w => w.kCGWindowLayer === 0 && w.kCGWindowAlpha > 0)
      .map(w => w.kCGWindowNumber)
  ]])
  if not ok then return nil, "Listing windows failed" end
  local normal = {}
  for _, id in ipairs(ids) do normal[id] = true end

  local spaces = hs.spaces.spacesForScreen(screen)
  local current = hs.fnutils.indexOf(spaces, hs.spaces.activeSpaceOnScreen(screen))
  for i = 1, #spaces - 1 do
    local space = spaces[(current + i - 1) % #spaces + 1]
    if hs.spaces.spaceType(space) == "user" then
      local count = #hs.fnutils.filter(hs.spaces.windowsForSpace(space), function(id)
        return normal[id]
      end)
      if count <= FREE_SPACE_MAX_WINDOWS then return space end
    end
  end
end

-- Move the focused window to the next free space (adding one if there is none),
-- tile the windows it left, then follow it and tile its new space.
local function moveToFreeSpace()
  local focused = hs.window.focusedWindow()
  local screen = focused and focused:screen() or hs.mouse.getCurrentScreen()
  local win = focused and focused:isStandard() and not focused:isFullScreen() and focused or nil

  local target, err = nextFreeSpace(screen)
  if err then
    hs.alert.show(err)
    return
  end
  target = target or addSpace(screen)
  if not target then
    hs.alert.show("Adding a desktop failed")
    return
  end

  if win then
    local rest = hs.fnutils.filter(screenWindows(screen), function(w) return w:id() ~= win:id() end)
    if not carryTo(win, target) then
      hs.alert.show("Couldn't move " .. (win:title() or "window"))
      return
    end
    tile(rest, screen:frame())
  elseif not walkTo(screen, target) then
    hs.alert.show("Switching desktop failed")
    return
  end
  tile(screenWindows(screen), screen:frame())
end

-- Cmd+U: tap tiles the focused screen; hold for HOLD_SECONDS to spread its
-- windows across desktops instead.
local holdTimer
hs.hotkey.bind({ "cmd" }, "u", function()
  holdTimer = hs.timer.doAfter(HOLD_SECONDS, function()
    holdTimer = nil
    spreadAcrossSpaces()
  end)
end, function()
  if holdTimer then
    holdTimer:stop()
    holdTimer = nil
    tileScreen()
  end
end)

hs.hotkey.bind({ "ctrl" }, "o", moveToFreeSpace)