-- @description Suzuki ReaDrum Machine (Scrollable Layout)
-- @author Suzuki
-- @license GPL v3
-- @version 1.6.7
-- @noindex
-- @changelog
--   + Added a loop start line and XFade line
--   # ReaImGui version check
-- @link https://forum.cockos.com/showthread.php?t=284566
-- @about
--   # ReaDrum Machine
--   ReaDrum Machine is a script which loads samples and FX from browser/arrange into subcontainers inside a container named ReaDrum Machine.
--   ### Prerequisites
--   REAPER v7.06+, ReaImGui v0.9.1, S&M extension, js extension and Sexan's FX Browser. Scan for new plugins to make sure RDM utility JSFX shows up in the native FX browser.
--   ### CAUTIONS
--   ReaDrum Machine utilizes a prallel FX feature in REAPER. If you use the script as it is, there's no problem, but if you want to place the audio (like VSTi or audio file in arrange) before RDM for some reason, beware of the volume because it adds up by design.
--   Use dry/wet knob in each container or shift+drag each pad to adjust each container's volume.

r                      = reaper

OS = r.GetOS()

local imgui_ver = "0.9.1"

if not r.APIExists("ImGui_GetVersion") then
  r.ShowMessageBox("ReaImGui is required.\nPlease install it in next window", "MISSING DEPENDENCIES", 0)
  return r.ReaPack_BrowsePackages('dear imgui')
else
  local _, _, reaimgui_version = r.ImGui_GetVersion()
  if reaimgui_version ~= imgui_ver then
    r.ShowMessageBox("ReaImGui " .. imgui_ver .. " is required.\nPlease update it in next window", "MISSING DEPENDENCIES", 0)
    return r.ReaPack_BrowsePackages('dear imgui')
  end
end

package.path = r.ImGui_GetBuiltinPath() .. '/?.lua'
im = require 'imgui' '0.9.1'

os_separator                 = package.config:sub(1, 1)
package.path                 = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] ..
    "?.lua;" -- GET DIRECTORY FOR REQUIRE

script_path = r.GetResourcePath() .. "/Scripts/Suzuki Scripts/ReaDrum Machine/"

Pad                          = {}

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

  local fx_browser_path
  local n, arch = r.GetAppVersion():match("(.+)/(.+)")

  local midi_trigger_envelope = r.GetResourcePath() ..
      "/Effects/Suzuki Scripts/lewloiwc's Sound Design Suite/lewloiwc_midi_trigger_envelope.jsfx"
  local sk_filter = r.GetResourcePath() .. "/Effects/Tilr/Filter/skfilter.jsfx"
  local sk_filter2 = r.GetResourcePath() .. "/Effects/tilr_jsfx/Filter/skfilter.jsfx"

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
    -- FX BROWSER
    if r.file_exists(fx_browser) then
      dofile(fx_browser)
    else
      r.ShowMessageBox("Sexan FX BROWSER is needed.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
      r.ReaPack_BrowsePackages(fx_browser_reapack)
      return 'error Sexan FX BROWSER'
    end
    -- lewloiwc Sound Design Suite
    if not r.file_exists(midi_trigger_envelope) then
      r.ShowMessageBox("lewloiwc Sound Design Suite is needed.\nPlease Install it in next window", "MISSING DEPENDENCIES",
        0)
      r.ReaPack_BrowsePackages('lewloiwc Sound Design Suite')
      return 'error lewloiwc Sound Design Suite'
    end
    -- tilr SKFilter
    if r.file_exists(sk_filter) or r.file_exists(sk_filter2) then
      local found_filter = true
    else
      r.ShowMessageBox("tilr SKFilter is needed.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
      r.ReaPack_BrowsePackages('tilr SKFilter')
      return 'error tilr SKFilter'
    end
    -- js extension
    if not r.APIExists("JS_ReaScriptAPI_Version") then
      r.ShowMessageBox("js Extension is needed.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
      r.ReaPack_BrowsePackages('js_ReascriptAPI')
      return 'error js Extension'
    end
    -- SWS/S&M
    if r.APIExists("CF_GetSWSVersion") then
      local sws_version = r.CF_GetSWSVersion()
      local major_minor = sws_version:match("^(%d+%.%d+)")
      local version_number = major_minor:gsub("%.","")
      local version_number = tonumber(version_number)
      if version_number < 214 then
        r.ShowMessageBox("SWS/S&M Extension v2.14.0 or higher is needed.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
        r.ReaPack_BrowsePackages('SWS/S&M')
        return 'error SWS/S&M'
      end
    else
      r.ShowMessageBox("SWS/S&M Extension v2.14.0 or higher is needed.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
      r.ReaPack_BrowsePackages('SWS/S&M')
      return 'error SWS/S&M'
    end
  end
end

if ThirdPartyDeps() then return end

----------------------
ctx = im.CreateContext('ReaDrum Machine')

draw_list = im.GetWindowDrawList(ctx)

ICONS_FONT = im.CreateFont(script_path .. 'Fonts/Icons.ttf', 11)
antonio_semibold = im.CreateFont(script_path .. 'Fonts/Antonio-SemiBold.ttf', 16)
antonio_semibold_mini = im.CreateFont(script_path .. 'Fonts/Antonio-SemiBold.ttf', 13)
system_font = im.CreateFont("sans-serif", 13)
im.Attach(ctx, ICONS_FONT)
im.Attach(ctx, antonio_semibold)
im.Attach(ctx, antonio_semibold_mini)
im.Attach(ctx, system_font)

FLT_MIN, FLT_MAX = im.NumericLimits_Float()

require("Modules/DragNDrop")
require("Modules/Drawing")
require("Modules/FX List")
require("Modules/General Functions")
require("Modules/Pad Actions")

local posx, posy = im.GetCursorScreenPos(ctx)

function SetButtonState(set) -- Set ToolBar Button State
  local is_new_value, filename, sec, cmd, mode, resolution, val = r.get_action_context()
  r.SetToggleCommandState(sec, cmd, set or 0)
  r.RefreshToolbar2(sec, cmd)
end

function Exit()
  SetButtonState()
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
  --im.DrawListSplitter_SetCurrentChannel(splitter, 1)
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
  --local SPLITTER = im.CreateDrawListSplitter(draw_list)
  --im.DrawListSplitter_Split(SPLITTER, 2)
  CheckDNDType()
  FXLIST()
  DoubleClickActions(false, false)

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
    local y = 2350 + math.floor((a - loopmin) / 4) * -75 -- start position + math.floor * - row offset
    local x = 5 + (a - 1) % 4 * 95

    im.SetCursorPos(ctx, x, y)
    local ret = im.InvisibleButton(ctx, pad_name .. "##" .. a, 90, 50)
    ButtonDrawlist(pad_name, Pad[a] and COLOR["Container"] or COLOR["n"], a)
    --DrawNoteName(x, y)
    DndAddFX_TARGET(a)
    DndAddSample_TARGET(a)
    -- DndAddMultipleSamples_TARGET(a)
    DndMoveFX_TARGET_SWAP(a)
    PadMenu(a, note_name)
    if im.IsItemHovered(ctx) then
      OnPad = true
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
    SendMidiNote(notenum)
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
  --im.DrawListSplitter_Merge(SPLITTER)
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

local setscroll = true

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


  draw_list = im.GetWindowDrawList(ctx) -- 4 x 4 left veertical bar drawing
  f_draw_list = im.GetForegroundDrawList(ctx)

  DrawPads(1, 128)
  if OPEN_PAD ~= nil then
    im.SetCursorPos(ctx, 40, 0)
    local y = im.GetScrollY(ctx)
    y = y + 100
    OpenRS5kInsidePad(OPEN_PAD, y - 155)
  end
  im.PopStyleColor(ctx)
end

function Run()
  track = r.GetSelectedTrack2(0, 0, false)
  TRACK = track
  midi_oct_offs = GetMidiOctOffsSettings()
  if track then
    trackidx = r.CSurf_TrackToID(track, false)
    track_guid = r.GetTrackGUID(track)
  end
  if set_dock_id then
    im.SetNextWindowDockID(ctx, set_dock_id)
    set_dock_id = nil
  end
  if OPEN_PAD ~= nil then
    main_w = 800
  else
    main_w = 400
  end
  im.SetNextWindowSizeConstraints(ctx, 400, 320, FLT_MAX, FLT_MAX)
  im.SetNextWindowSize(ctx, main_w, 300)

  im.PushStyleColor(ctx, im.Col_WindowBg, COLOR["bg"])
  im.PushStyleColor(ctx, im.Col_TitleBg, COLOR["bg"])
  im.PushStyleColor(ctx, im.Col_TitleBgActive, COLOR["bg"])
  local imgui_visible, imgui_open = im.Begin(ctx, 'ReaDrum Machine', true)
  im.PopStyleColor(ctx, 3)

  if imgui_visible then
    imgui_width, imgui_height = im.GetWindowSize(ctx)

    if setscroll then
      local stored_y = r.GetExtState("ReaDrum Machine", "Scroll_Pos")
      if tonumber(stored_y) ~= nil then
        im.SetScrollY(ctx, tonumber(stored_y))
      end
      setscroll = false
    end

    if not setscroll then
      local scroll_y = im.GetScrollY(ctx)
      r.SetExtState("ReaDrum Machine", "Scroll_Pos", scroll_y, true)
    end

    if not TRACK then
      im.TextDisabled(ctx, 'No track selected')
    else
      CheckKeys()
      Main()
    end
    im.End(ctx)
  end

  if process or not imgui_open then
    imgui_open = nil
  else
    r.defer(Run)
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
