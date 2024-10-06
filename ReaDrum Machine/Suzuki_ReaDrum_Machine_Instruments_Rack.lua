-- @description Suzuki ReaDrum Machine
-- @author Suzuki
-- @license GPL v3
-- @version 1.7.6
-- @changelog
--   + Add paste action. Click a pad and Ctrl for windows (cmd for mac) + V pastes a sample file from the clipboard.
-- @link https://forum.cockos.com/showthread.php?t=284566
-- @about
--   # ReaDrum Machine
--   ReaDrum Machine is a script which loads samples and FX from browser/arrange into subcontainers inside a container named ReaDrum Machine.
--   ### Prerequisites
--   REAPER v7.06+, ReaImGui v0.9.3.1, S&M extension, js extension, tilr's SK filter, lewloiwc's Sound Design Suite and Sexan's FX Browser. Scan for new plugins to make sure RDM utility JSFX shows up in the native FX browser.
--   ### CAUTIONS
--   ReaDrum Machine utilizes a parallel FX feature in REAPER. If you use the script as it is, there's no problem, but if you want to place the audio (like VSTi or audio file in arrange) before RDM for some reason, beware of the volume because it adds up by design.
--   Use dry/wet knob in each container or shift+drag each pad to adjust each container's volume.
--   ### Usage
--   #### FX Browser
--   - Right click - Open FX Browser
--   You can drag/drop FX from the browser to the pad. Rescan FX list if you want to reflect your latest plugins.
--   - Ctrl + double click - Select all pads in the page
--   - Shift + double click - Select all pads in the script
--   #### Settings
--   "Apply pitch as a RS5k parameter" option is to apply pitch in the Media Explorer/Arrange as a RS5k parameter. 
--   If it's unticked, the script renders samples to reflect the pitch. The default is on.
--   #### Pad
--   - Click - Open/close each pad's floating window
--   - Alt + click - Remove pad
--   - Ctrl + click - Select pad
--   - Right click - Open RS5k UI
--   - Ctrl + right click - Open menu
--   - Left drag - Move/swap pads
--   - Ctrl + left drag - Copy pad/copy pad fx
--   - Shift + left drag - Turn up/down volume of each pad
--   - Ctrl + V - Paste samples from clipboard
--   #### Menu
--   Set choke group - Sending notes in the same channel (group) mutes the note. Obey note-offs needs to be on for it to work.                                                                                                                                                                                                               
-- @provides
--   Fonts/*.ttf
--   FXChains/*.RfxChain
--   Images/*.png
--   Modules/*.lua
--   [effect] JSFX/*.jsfx
--   [main] Suzuki_ReaDrum_Machine_Instruments_Rack_(Scrollable Layout).lua
--   [main] Scripts/*.lua

r                      = reaper

OS = r.GetOS()

if not r.ImGui_GetBuiltinPath then
  r.ShowMessageBox("ReaImGui is required.\nPlease install or update it in the next window", "MISSING DEPENDENCIES", 0)
  return r.ReaPack_BrowsePackages('dear imgui')
end

package.path = r.ImGui_GetBuiltinPath() .. '/?.lua'
im = require 'imgui' '0.9.3.1'

os_separator                 = package.config:sub(1, 1)
package.path                 = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] ..
    "?.lua;" -- GET DIRECTORY FOR REQUIRE

script_path = r.GetResourcePath() .. "/Scripts/Suzuki Scripts/ReaDrum Machine/"

--[[local profiler = dofile(r.GetResourcePath() ..
  '/Scripts/ReaTeam Scripts/Development/cfillion_Lua profiler.lua')
reaper.defer = profiler.defer]]

Pad                          = {}
OnPad                        = {}

COLOR                        = {
  ["n"]           = 0xff,
  ["Container"]   = 0x123456FF,
  ["dnd"]         = 0x00b4d8ff,
  ["dnd_replace"] = 0xdc5454ff,
  ["dnd_swap"]    = 0xcd6dc6ff,
  ["selected"]    = 0x9400d3ff,
  ["bg"]          = 0x141414ff
}

--- PRE-REQUISITES ---
local function ThirdPartyDeps() -- FX Browser
  local version = tonumber(string.sub(r.GetAppVersion(), 0, 4))
  --reaper.ShowConsoleMsg((version))

  local midi_trigger_envelope = r.GetResourcePath() ..
      "/Effects/Suzuki Scripts/lewloiwc's Sound Design Suite/lewloiwc_midi_trigger_envelope.jsfx"
  local sk_filter = r.GetResourcePath() .. "/Effects/Tilr/Filter/skfilter.jsfx"
  local sk_filter2 = r.GetResourcePath() .. "/Effects/tilr_jsfx/Filter/skfilter.jsfx"

  local fx_browser_path
  local n, arch = r.GetAppVersion():match("(.+)/(.+)")

  if n:match("^7%.") then
    fx_browser = r.GetResourcePath() .. "/Scripts/Sexan_Scripts/FX/Sexan_FX_Browser_ParserV7.lua"
    fx_browser_reapack = 'sexan fx browser parser v7'
  elseif not r.GetAppVersion():match("^7%.") then
    r.ShowMessageBox("This script requires Reaper V7", "WRONG REAPER VERSION", 0)
    return
  end
  --local fx_browser_v7_path = reaper.GetResourcePath() .. "/Scripts/Sexan_Scripts/FX/Sexan_FX_Browser_ParserV7.lua"

  local reapack_process
  local repos = {
    { name = "Sexan_Scripts", url = 'https://github.com/GoranKovac/ReaScripts/raw/master/index.xml' },
    { name = "Tilr",          url = 'https://raw.githubusercontent.com/tiagolr/tilr_jsfx/master/index.xml' }
  }

  for i = 1, #repos do
    local retinfo, url, enabled, autoInstall = r.ReaPack_GetRepositoryInfo(repos[i].name)
    if not retinfo then
      retval, error = r.ReaPack_AddSetRepository(repos[i].name, repos[i].url, true, 0)
      reapack_process = true
    end
  end

  -- ADD NEEDED REPOSITORIES
  if reapack_process then
    r.ShowMessageBox("Added Third-Party ReaPack Repositories", "ADDING REPACK REPOSITORIES", 0)
    r.ReaPack_ProcessQueue(true)
    reapack_process = nil
  end

  if not reapack_process then
    local deps = {}
    -- FX BROWSER
    if r.file_exists(fx_browser) then
      dofile(fx_browser)
    else
      deps[#deps + 1] = '"FX Browser Parser V7"'
    end
    -- lewloiwc Sound Design Suite
    if not r.file_exists(midi_trigger_envelope) then
      deps[#deps + 1] = [['"lewloiwc's Sound Design Suite"']]
    end
    -- tilr SKFilter
    if not r.file_exists(sk_filter) and not r.file_exists(sk_filter2) then
      deps[#deps + 1] = '"SKFilter"'
    end
    -- js extension
    if not r.APIExists("JS_ReaScriptAPI_Version") then
      deps[#deps + 1] = '"js_ReascriptAPI"'
    end
    -- SWS/S&M
    if not r.CF_CreatePreview then
      deps[#deps + 1] = '"SWS/S&M"'
    end

    if #deps ~= 0 then
      r.ShowMessageBox("Need Additional Packages.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
      r.ReaPack_BrowsePackages(table.concat(deps, " OR "))
      return true
    end
  end
end

if ThirdPartyDeps() then return end

----------------------
ctx = im.CreateContext('ReaDrum Machine')

draw_list = im.GetWindowDrawList(ctx)

ICONS_FONT = im.CreateFont(script_path .. 'Fonts/Icons.ttf', 14)
antonio_light = im.CreateFont(script_path .. 'Fonts/Antonio-Light.ttf', 22)
antonio_semibold = im.CreateFont(script_path .. 'Fonts/Antonio-SemiBold.ttf', 16)
antonio_semibold_mini = im.CreateFont(script_path .. 'Fonts/Antonio-SemiBold.ttf', 13)
antonio_semibold_large = im.CreateFont(script_path .. 'Fonts/Antonio-SemiBold.ttf', 22)
system_font = im.CreateFont("sans-serif", 13)
im.Attach(ctx, ICONS_FONT)
im.Attach(ctx, antonio_light)
im.Attach(ctx, antonio_semibold)
im.Attach(ctx, antonio_semibold_mini)
im.Attach(ctx, antonio_semibold_large)
im.Attach(ctx, system_font)

FLT_MIN, FLT_MAX = im.NumericLimits_Float()

require("Modules/DragNDrop")
require("Modules/Drawing")
require("Modules/FX List")
require("Modules/General Functions")
require("Modules/Pad Actions")

local posx, posy = im.GetCursorScreenPos(ctx)

if r.HasExtState("ReaDrum Machine", "pitch_settings") then
  pitch_as_parameter = r.GetExtState("ReaDrum Machine", "pitch_settings")
  if pitch_as_parameter == "true" then
    pitch_as_parameter = true
  elseif pitch_as_parameter == "false" then
    pitch_as_parameter = false
  end
else
  pitch_as_parameter = true
end

local function PrintTraceback(err)
  local byLine = "([^\r\n]*)\r?\n?"
  local trimPath = "[\\/]([^\\/]-:%d+:.+)$"
  local stack = {}
  for line in string.gmatch(err, byLine) do
      local str = string.match(line, trimPath) or line
      stack[#stack + 1] = str
  end
  r.ShowConsoleMsg(
      "Error: " .. stack[1] .. "\n\n" ..
      "Stack traceback:\n\t" .. table.concat(stack, "\n\t", 3) .. "\n\n" ..
      "Reaper:       \t" .. r.GetAppVersion() .. "\n" ..
      "Platform:     \t" .. r.GetOS()
  )
end

local function PDefer(func)
  r.defer(function()
      local status, err = xpcall(func, debug.traceback)
      if not status then
          PrintTraceback(err)
      end
  end)
end

----------------------------------------------------------------------
-- GUI --
----------------------------------------------------------------------

function ButtonDrawlist(name, color, a)
  --im.DrawListSplitter_SetCurrentChannel(splitter, 0)
  color = im.IsItemHovered(ctx) and IncreaseDecreaseBrightness(color, 30) or color
  local xs, ys = im.GetItemRectMin(ctx)
  local xe, ye = im.GetItemRectMax(ctx)

  im.DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, im.GetColorEx(ctx, color))
  if im.IsItemActive(ctx) then
    im.DrawList_AddRect(draw_list, xs, ys, xe, ye, 0x22FF44FF)
  end
  if DND_MOVE_FX and im.IsMouseHoveringRect(ctx, xs, ys, xe, ye) then
    local x_offset = 2
    im.DrawList_AddRect(f_draw_list, xs - x_offset, ys - x_offset, xe + x_offset, ye + x_offset, 0xFF0000FF, 2,
      nil, 2)
  end
  if DND_ADD_FX and im.IsMouseHoveringRect(ctx, xs, ys, xe, ye) then
    local x_offset = 2
    im.DrawList_AddRect(f_draw_list, xs - x_offset, ys - x_offset, xe + x_offset, ye + x_offset, COLOR["dnd"], 2,
      nil, 2)
  end
  if SELECTED and SELECTED[tostring(a)] then
    local x_offset = 1
    im.DrawList_AddRect(f_draw_list, xs - x_offset, ys - x_offset, xe + x_offset, ye + x_offset, COLOR["selected"],
      2,
      nil, 1)
  end

  local font_size = im.GetFontSize(ctx)
  local char_size_w, char_size_h = im.CalcTextSize(ctx, "A")
  local font_color = CalculateFontColor(color)

  im.DrawList_AddTextEx(draw_list, nil, font_size, xs, ys + char_size_h, im.GetColorEx(ctx, font_color), name,
    xe - xs)
  im.DrawList_AddText(draw_list, xs, ys, 0xffffffff, note_name)

  if Pad[a] and OPEN_PAD == a then -- open FX UI
    Highlight_Itm(f_draw_list, 0x256BB155, 0x256BB1ff)
  end
  if Pad[a] and Pad[a].Filter_ID then -- flash pad
    local rv = r.TrackFX_GetParam(track, Pad[a].Filter_ID, 1)
    if rv == 1 then
      local L, T = im.GetItemRectMin(ctx)
      local R, B = im.GetItemRectMax(ctx)
      im.DrawList_AddRectFilled(f_draw_list, L, T, R, B + 25, 0xfde58372, rounding)
    end
  end
end

function DrawListButton(name, color, round_side, icon, hover, offset)
  local multi_color = IS_DRAGGING_RIGHT_CANVAS and color or ColorToHex(color, hover and 50 or 0)
  local xs, ys = im.GetItemRectMin(ctx)
  local xe, ye = im.GetItemRectMax(ctx)
  local w = xe - xs
  local h = ye - ys

  local round_flag = round_side and ROUND_FLAG[round_side] or nil
  local round_amt = round_flag and ROUND_CORNER or 0

  im.DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, im.GetColorEx(ctx, multi_color), round_amt,
    round_flag)
  if im.IsItemActive(ctx) then
    im.DrawList_AddRect(f_draw_list, xs - 2, ys - 2, xe + 2, ye + 2, 0x22FF44FF, 3, nil, 2)
  end

  if icon then im.PushFont(ctx, ICONS_FONT) end

  local label_size = im.CalcTextSize(ctx, name)
  local FONT_SIZE = im.GetFontSize(ctx)
  local font_color = CalculateFontColor(color)

  im.DrawList_AddTextEx(draw_list, nil, FONT_SIZE, xs + (w / 2) - (label_size / 2) + (offset or 0),
    ys + ((h / 2)) - FONT_SIZE / 2, im.GetColorEx(ctx, font_color), name)
  if icon then im.PopFont(ctx) end
end

function DrawPads(loopmin, loopmax)
  CheckDNDType()
  FXLIST()
  DoubleClickActions(loopmin, loopmax)

  for a = loopmin, loopmax do
    notenum = a - 1
    note_name = getNoteName(notenum + midi_oct_offs)

    if Pad[a] then
      if Pad[a].Rename then
        pad_name = Pad[a].Rename
      elseif Pad[a].Name then
        pad_name = Pad[a].Name
      else
        pad_name = ""
      end
    else
      pad_name = ""
    end
    local y = 230 + math.floor((a - loopmin) / 4) * - 75 -- start position + math.floor * - row offset
    local x = 5 + (a - 1) % 4 * 95

    im.SetCursorPos(ctx, x, y)
    local ret = im.InvisibleButton(ctx, pad_name .. "##" .. a, 90, 50)
    ButtonDrawlist(pad_name, Pad[a] and COLOR["Container"] or COLOR["n"], a)
    DndAddFX_TARGET(a)
    DndAddSample_TARGET(a)
    -- DndAddMultipleSamples_TARGET(a)
    DndMoveFX_TARGET_SWAP(a)
    PadMenu(a, note_name)
    if im.IsItemHovered(ctx) then
      OnPad = true
      if im.Shortcut(ctx, im.Mod_Ctrl | im.Key_V) then
        PasteSamplesFromClipboard(a)
      end
    end
    if ret then
      ClickPadActions(a)
    elseif im.IsItemClicked(ctx, 1) and Pad[a] and not CTRL then
      OPEN_PAD = toggle2(OPEN_PAD, a)
    elseif SHIFT and im.IsMouseDragging(ctx, 0) and im.IsItemActive(ctx) then
      AdjustPadVolume(a)
    else
      DndMoveFX_SRC(a)
    end

    im.SetCursorPos(ctx, x, y + 50)
    im.InvisibleButton(ctx, "▶##play" .. a, 30, 25)
    SendMidiNote(a)
    DrawListButton("-", COLOR["n"], nil, true)

    im.SetCursorPos(ctx, x + 30, y + 50)
    if im.InvisibleButton(ctx, "S##solo" .. a, 30, 25) then
      if SELECTED then
        Unmuted = 0
        CountSelected = 0
        for k, v in pairs(SELECTED) do
          local k = tonumber(k)
          if Pad[k] then
            CountSelected = CountSelected + 1
            if r.TrackFX_GetEnabled(track, Pad[k].Pad_ID) then
              Unmuted = Unmuted + 1
            end
          end
        end
        if CountSelected == Unmuted then
          AllUnmuted = true
        end
        CountPads() -- pads_idx
        HowManyMuted = 0
        for i = 1, pads_idx do
          local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. i - 1)
          local rv = r.TrackFX_GetEnabled(track, pad_id)
          if not rv then
            HowManyMuted = HowManyMuted + 1
          end
        end
        if AllUnmuted and pads_idx - HowManyMuted == CountSelected then
          for i = 1, pads_idx do                                                                         -- unmute all
            local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. i - 1) -- 0 based
            r.TrackFX_SetEnabled(track, pad_id, true)
          end
        else
          for i = 1, pads_idx do                                                                         -- mute all
            local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. i - 1) -- 0 based
            r.TrackFX_SetEnabled(track, pad_id, false)
          end
          for k, v in pairs(SELECTED) do
            local k = tonumber(k)
            if Pad[k] then
              r.TrackFX_SetEnabled(track, Pad[k].Pad_ID, true)
            end
          end
        end
        SELECTED = nil
      else
        if Pad[a] then
          CountPads() -- pads_idx
          if Pad[a].Pad_Num == 1 then
            retval1 = false
          else
            retval1 = r.TrackFX_GetEnabled(track, Pad[a].Previous_Pad_ID)
          end
          local retval2 = r.TrackFX_GetEnabled(track, Pad[a].Next_Pad_ID)
          if retval1 == false and retval2 == false then                                                    -- unsolo
            for i = 1, pads_idx do
              local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. i - 1) -- 0 based
              r.TrackFX_SetEnabled(track, pad_id, true)
            end
          else                                                                                             -- solo
            for i = 1, pads_idx do
              local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. i - 1) -- 0 based
              r.TrackFX_SetEnabled(track, pad_id, false)
            end
            r.TrackFX_SetEnabled(track, Pad[a].Pad_ID, true)
          end
        end
      end
    end
    --if Pad[a] then
    --  local ok = r.TrackFX_GetEnabled(track, Pad[a].Pad_ID)
    --  DrawListButton("S", ok and 0xff or 0xf1c524ff, nil, nil)
    --else
    DrawListButton("S", COLOR["n"], nil, nil)
    --end

    im.SetCursorPos(ctx, x + 60, y + 50)
    if im.InvisibleButton(ctx, "M##mute" .. a, 30, 25) then
      if SELECTED then
        for k, v in pairs(SELECTED) do
          local k = tonumber(k)
          if Pad[k] and Pad[k].RS5k_ID then
            local retval = r.TrackFX_GetEnabled(track, Pad[k].Pad_ID)
            if retval == true then
              r.TrackFX_SetEnabled(track, Pad[k].Pad_ID, false)
            else
              r.TrackFX_SetEnabled(track, Pad[k].Pad_ID, true)
            end
          end
        end
        SELECTED = nil
      else
        if Pad[a] then
          local retval = r.TrackFX_GetEnabled(track, Pad[a].Pad_ID)
          if retval == true then
            r.TrackFX_SetEnabled(track, Pad[a].Pad_ID, false)
          else
            r.TrackFX_SetEnabled(track, Pad[a].Pad_ID, true)
          end
        end
      end
    end
    if Pad[a] then
      mute_color = r.TrackFX_GetEnabled(track, Pad[a].Pad_ID)
      DrawListButton("M", mute_color == true and COLOR["n"] or 0xff2222ff, nil, nil)
    else
      DrawListButton("M", COLOR["n"], nil, nil)
    end
  end
end

----------------------------------------------------------------------
-- OTHER --
----------------------------------------------------------------------
local s_window_x, s_window_y = im.GetStyleVar(ctx, im.StyleVar_WindowPadding)
local s_frame_x, s_frame_y = im.GetStyleVar(ctx, im.StyleVar_FramePadding)

local tw, th = im.CalcTextSize(ctx, "A") -- just single letter
local iw, ih = tw + (s_frame_x * 2), th + (s_frame_y * 2)

local def_btn_h = tw

local w_open, w_closed = 250, def_btn_h + (s_window_x * 2)

----------------------------------------------------------------------
-- RUN --
----------------------------------------------------------------------
function Main()
  local wx, wy = im.GetWindowPos(ctx)
  local w_open, w_closed = 250, def_btn_h + s_window_x * 2 + 10
  local h = 220
  local hh = h + 100
  local hy = hh / 8
  if im.IsWindowDocked(ctx) then
    button_offset = 6
  else
    button_offset = 25
  end

  im.PushStyleColor(ctx, im.Col_ChildBg, COLOR["bg"])
  im.BeginGroup(ctx)

  draw_list = im.GetWindowDrawList(ctx) -- 4 x 4 left vertical tab drawing
  f_draw_list = im.GetForegroundDrawList(ctx)

  local x, y = im.GetCursorPos(ctx)

  if im.BeginChild(ctx, 'BUTTON_SECTION', w_closed + 10, h + 100) then -- vertical tab
    for i = 1, 8 do
      im.SetCursorPos(ctx, 0, y + 250 - (i - 1) * 35 - button_offset)
      
      rv = im.InvisibleButton(ctx, "B" .. i, 31, 31)
      local xs, ys = im.GetItemRectMin(ctx)
      local xe, ye = im.GetItemRectMax(ctx)
      for hi = 1, 4 do
        for vi = 1, 4 do
          local num = (i - 1) * 16 + (hi - 1) * 4 + vi
          if Pad[num] and Pad[num].Filter_ID then -- flash pad
            local rv = r.TrackFX_GetParam(track, Pad[num].Filter_ID, 1)
            if rv == 1 then
              rect_color = 0xffd700ff
            else
              rect_color = 0xffffffff
            end
          else
            rect_color = 0x252525ff
          end
          im.DrawList_AddRectFilled(draw_list, xs + 8 * (vi - 1), ye - 8 * (hi - 1), xs + 7 + 8 * (vi - 1), ye - 7 - 8 * (hi - 1), rect_color)
        end
      end
      if rv then
        LAST_MENU = RememberTab(LAST_MENU, i)
      end
      im.PushStyleColor(ctx, im.Col_DragDropTarget, 0)
      if im.BeginDragDropTarget(ctx) then
        local ret, payload = im.AcceptDragDropPayload(ctx, 'DND ADD FX')
        im.EndDragDropTarget(ctx)
      end
      im.PopStyleColor(ctx)
      im.PushStyleColor(ctx, im.Col_DragDropTarget, 0)
      if im.BeginDragDropTarget(ctx) then
        local ret, payload = im.AcceptDragDropPayload(ctx, 'DND MOVE FX')
        im.EndDragDropTarget(ctx)
      end
      im.PopStyleColor(ctx)
      if (DND_ADD_FX or DND_MOVE_FX or im.IsMouseDragging(ctx, 0)) and im.IsMouseHoveringRect(ctx, xs, ys, xe, ye) then
        LAST_MENU = i
        r.SetProjExtState(0, "ReaDrum Machine", track_guid .. "LAST_MENU", i)
      end
      HighlightHvredItem()
      if LAST_MENU == i then
        Highlight_Itm(draw_list, 0x12345655, 0x184673ff)
      end
    end
    im.EndChild(ctx)
  end
  local openpad
  if LAST_MENU then -- Open pads manu
    im.SetCursorPos(ctx, x + w_closed, y)
    if im.BeginChild(ctx, "child_menu", w_open + 135, h + 88) then
      local high = 0 + 16 * (LAST_MENU)
      local low = 0 + 16 * (LAST_MENU - 1) + 1
      openpad = DrawPads(low, high)
      im.EndChild(ctx)
    end
  end
  if OPEN_PAD ~= nil then
    im.SetCursorPos(ctx, 40, 0)
    OpenRS5kInsidePad(OPEN_PAD, 0)
  end
  im.Dummy(ctx, w_closed + 10, h + 100)
  im.EndGroup(ctx)
  im.PopStyleColor(ctx)
end

function Run()
  track = r.GetSelectedTrack2(0, 0, false)
  TRACK = track
  midi_oct_offs = GetMidiOctOffsSettings()
  if track then
    trackidx = r.CSurf_TrackToID(track, false)
    track_guid = r.GetTrackGUID(track)
    _, track_name = r.GetTrackName(track)
  end
  if set_dock_id then
    im.SetNextWindowDockID(ctx, set_dock_id)
    set_dock_id = nil
  end

  if track_guid then
    local _, n = r.GetProjExtState(0, "ReaDrum Machine", track_guid .. "LAST_MENU")
    if n ~= nil then
      LAST_MENU = tonumber(n)
    end
  end
  if OPEN_PAD ~= nil then
    main_w = 800
  else
    main_w = 450
  end
  im.SetNextWindowSizeConstraints(ctx, 450, 360, FLT_MAX, FLT_MAX)
  im.SetNextWindowSize(ctx, main_w, 300)
  im.PushStyleColor(ctx, im.Col_WindowBg, COLOR["bg"])
  imgui_visible, imgui_open = im.Begin(ctx, 'ReaDrum Machine', true,
    im.WindowFlags_NoScrollWithMouse | im.WindowFlags_NoScrollbar | im.WindowFlags_NoTitleBar)
  im.PopStyleColor(ctx, 1)

  if imgui_visible then
    imgui_width, imgui_height = im.GetWindowSize(ctx)
    CustomTitleBar(390)
    if not TRACK then
      --im.PushFont(ctx, antonio_semibold)
      im.TextDisabled(ctx, 'No track selected')
      --im.PopFont(ctx)
    else
      CheckKeys()
      --im.PushFont(ctx, antonio_semibold)
      Main()
      --im.PopFont(ctx)
    end
    im.End(ctx)
  end

  if process or not imgui_open then
    imgui_open = nil
  else
    PDefer(Run)
  end
  CheckStaleData()
  if TRACK then UpdateFxData() end
end

function Init()
  SetButtonState(1)
  r.atexit(Exit)

  Run()
end

Init()

-- profiler.attachToWorld() -- after all functions have been defined
-- profiler.run()