-- @description Suzuki ReaDrum Machine (Scrollable Layout)
-- @author Suzuki
-- @license GPL v3
-- @version 1.5.0
-- @noindex
-- @changelog 
--   + Added ReaImGui backward compatibility
-- @link https://forum.cockos.com/showthread.php?t=284566
-- @about ReaDrum Machine is a script which loads samples and FX from browser/arrange into subcontainers inside a container named ReaDrum Machine. This is a version which lets users scroll vertically.

local r            = reaper
os_separator = package.config:sub(1, 1)
package.path       = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] ..
    "?.lua;" -- GET DIRECTORY FOR REQUIRE
package.path       = package.path ..
    debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "../ImGui_Tools/?.lua;"
local reaimgui_force_version = "0.8.7.6"
script_path  = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]];
PATH         = debug.getinfo(1).source:match("@?(.*[\\|/])")
Pad          = {}

COLOR              = {
  ["n"]           = 0xff,
  ["Container"]   = 0x123456FF,
  ["dnd"]         = 0x00b4d8ff,
  ["dnd_replace"] = 0xdc5454ff,
  ["dnd_swap"]    = 0xcd6dc6ff,
  ["selected"]    = 0x9400d3ff,
  ["bg"] = 0x141414ff
}

--- PRE-REQUISITES ---
if not r.ImGui_GetVersion then
  r.ShowMessageBox("ReaImGui is required.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
  return r.ReaPack_BrowsePackages('dear imgui')
end

if reaimgui_force_version then
  local reaimgui_shim_file_path = r.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua'
  if r.file_exists(reaimgui_shim_file_path) then
    dofile(reaimgui_shim_file_path)(reaimgui_force_version)
  end
end

function ThirdPartyDeps() -- FX Browser
  local version = tonumber(string.sub(r.GetAppVersion(), 0, 4))
  --reaper.ShowConsoleMsg((version))

  local fx_browser_path
  local n, arch = r.GetAppVersion():match("(.+)/(.+)")

  local midi_trigger_envelope = r.GetResourcePath() .. "/Effects/Suzuki Scripts/lewloiwc's Sound Design Suite/lewloiwc_midi_trigger_envelope.jsfx"
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
    {name = "Tilr", url = 'https://raw.githubusercontent.com/tiagolr/tilr_jsfx/master/index.xml'}
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
    if r.file_exists(midi_trigger_envelope) then
      local found_midi_envelope = true
    else
      r.ShowMessageBox("lewloiwc Sound Design Suite is needed.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
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
    -- SWS/S&M
    if r.APIExists("CF_GetSWSVersion") then
      local SWS_SnM = true
    else
      r.ShowMessageBox("SWS/S&M Extension is needed.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
      r.ReaPack_BrowsePackages('SWS/S&M')
      return 'error SWS/S&M'
    end
  end
end

if ThirdPartyDeps() then return end

----------------------
ctx = r.ImGui_CreateContext('ReaDrum Machine')

draw_list = r.ImGui_GetWindowDrawList(ctx)

ICONS_FONT = r.ImGui_CreateFont(script_path .. 'Fonts/Icons.ttf', 11)
FONT = r.ImGui_CreateFont(script_path .. 'Fonts/Antonio-SemiBold.ttf', 16)
r.ImGui_Attach(ctx, ICONS_FONT)
r.ImGui_Attach(ctx, FONT)

FLT_MIN, FLT_MAX = r.ImGui_NumericLimits_Float()

require("Modules/DragNDrop")
require("Modules/Drawing")
require("Modules/FX List")
require("Modules/General Functions")
require("Modules/Pad Actions")

local posx, posy = r.ImGui_GetCursorScreenPos(ctx)

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

function ButtonDrawlist(splitter, name, color, a)
  r.ImGui_DrawListSplitter_SetCurrentChannel(splitter, 0)
  color = r.ImGui_IsItemHovered(ctx) and IncreaseDecreaseBrightness(color, 30) or color
  local xs, ys = r.ImGui_GetItemRectMin(ctx)
  local xe, ye = r.ImGui_GetItemRectMax(ctx)

  r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, r.ImGui_GetColorEx(ctx, color))
  if r.ImGui_IsItemActive(ctx) then
    r.ImGui_DrawList_AddRect(draw_list, xs, ys, xe, ye, 0x22FF44FF)
  end
  if DND_MOVE_FX and r.ImGui_IsMouseHoveringRect(ctx,xs,ys,xe,ye) then
    local x_offset = 2
    r.ImGui_DrawList_AddRect(f_draw_list, xs - x_offset, ys - x_offset, xe + x_offset, ye + x_offset, 0xFF0000FF, 2,
        nil, 2)
  end
  if DND_ADD_FX and r.ImGui_IsMouseHoveringRect(ctx,xs,ys,xe,ye) then
    local x_offset = 2
    r.ImGui_DrawList_AddRect(f_draw_list, xs - x_offset, ys - x_offset, xe + x_offset, ye + x_offset, COLOR["dnd"], 2,
        nil, 2)
  end
  if SELECTED and SELECTED[tostring(a)] then
    local x_offset = 1
    r.ImGui_DrawList_AddRect(f_draw_list, xs - x_offset, ys - x_offset, xe + x_offset, ye + x_offset, COLOR["selected"], 2,
      nil, 1)
  end

  local font_size = r.ImGui_GetFontSize(ctx)
  local char_size_w,char_size_h = r.ImGui_CalcTextSize(ctx, "A")
  local font_color = CalculateFontColor(color)

  r.ImGui_DrawList_AddTextEx(draw_list, nil, font_size, xs, ys + char_size_h, r.ImGui_GetColorEx(ctx, font_color), name, xe-xs)
  r.ImGui_DrawList_AddText(draw_list, xs, ys, 0xffffffff, note_name)

  if Pad[a] and OPEN_PAD == a then -- open FX UI
    Highlight_Itm(f_draw_list, 0x256BB155, 0x256BB1ff)
  end
  if Pad[a] and Pad[a].Filter_ID then -- flash pad
    local rv = r.TrackFX_GetParam(track, Pad[a].Filter_ID, 1)
    if rv == 1 then   
      local L, T = r.ImGui_GetItemRectMin(ctx)
      local R, B = r.ImGui_GetItemRectMax(ctx)
      r.ImGui_DrawList_AddRectFilled(f_draw_list, L, T, R, B + 25, 0xfde58372, rounding)
    end
  end
end

function DrawListButton(splitter, name, color, round_side, icon, hover, offset)
  r.ImGui_DrawListSplitter_SetCurrentChannel(splitter, 1)
  local multi_color = IS_DRAGGING_RIGHT_CANVAS and color or ColorToHex(color, hover and 50 or 0)
  local xs, ys = r.ImGui_GetItemRectMin(ctx)
  local xe, ye = r.ImGui_GetItemRectMax(ctx)
  local w = xe - xs
  local h = ye - ys

  local round_flag = round_side and ROUND_FLAG[round_side] or nil
  local round_amt = round_flag and ROUND_CORNER or 0

  r.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, r.ImGui_GetColorEx(ctx, multi_color), round_amt,
    round_flag)
  if r.ImGui_IsItemActive(ctx) then
    r.ImGui_DrawList_AddRect(f_draw_list, xs - 2, ys - 2, xe + 2, ye + 2, 0x22FF44FF, 3, nil, 2)
  end

  if icon then r.ImGui_PushFont(ctx, ICONS_FONT) end

  local label_size = r.ImGui_CalcTextSize(ctx, name)
  local FONT_SIZE = r.ImGui_GetFontSize(ctx)
  local font_color = CalculateFontColor(color)

  r.ImGui_DrawList_AddTextEx(draw_list, nil, FONT_SIZE, xs + (w / 2) - (label_size / 2) + (offset or 0),
    ys + ((h / 2)) - FONT_SIZE / 2, r.ImGui_GetColorEx(ctx, font_color), name)
  if icon then r.ImGui_PopFont(ctx) end
end

function DrawPads(loopmin, loopmax)
  local SPLITTER = r.ImGui_CreateDrawListSplitter(draw_list)
  r.ImGui_DrawListSplitter_Split(SPLITTER, 2)
  CheckDNDType()
  FXLIST()
  DoubleClickActions(false, false)

  for a = loopmin, loopmax do
    local midi_octave_offset = r.SNM_GetIntConfigVar("midioctoffs", 0)
    midi_oct_offs = (midi_octave_offset - 1) * 12
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

    r.ImGui_SetCursorPos(ctx, x, y)
    local ret = r.ImGui_InvisibleButton(ctx, pad_name .. "##" .. a, 90, 50)
    ButtonDrawlist(SPLITTER, pad_name, Pad[a] and COLOR["Container"] or COLOR["n"], a)
    --DrawNoteName(x, y)
    DndAddFX_TARGET(a)
    DndAddSample_TARGET(a)
    -- DndAddMultipleSamples_TARGET(a)
    DndMoveFX_TARGET_SWAP(a)
    PadMenu(a, note_name)
    if r.ImGui_IsItemHovered(ctx) then
      OnPad = true
    end
    if ret then 
      ClickPadActions(a)
    elseif r.ImGui_IsItemClicked(ctx, 1) and Pad[a] and not CTRL then
      OPEN_PAD = toggle2(OPEN_PAD, a)
    elseif SHIFT and r.ImGui_IsMouseDragging(ctx, 0) and r.ImGui_IsItemActive(ctx) then
      AdjustPadVolume(a)
    else
      DndMoveFX_SRC(a)
    end

    r.ImGui_SetCursorPos(ctx, x, y + 50)
    r.ImGui_InvisibleButton(ctx, "▶##play" .. a, 30, 25)
    SendMidiNote(notenum)
    DrawListButton(SPLITTER,"-", COLOR["n"], nil, true)

    r.ImGui_SetCursorPos(ctx, x + 30, y + 50)
    if r.ImGui_InvisibleButton(ctx, "S##solo" .. a, 30, 25) then
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
          for i = 1, pads_idx do -- unmute all
            local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. i - 1) -- 0 based
            r.TrackFX_SetEnabled(track, pad_id, true)
          end
        else
          for i = 1, pads_idx do -- mute all
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
          if retval1 == false and retval2 == false then -- unsolo
            for i = 1, pads_idx do
              local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. i - 1) -- 0 based
              r.TrackFX_SetEnabled(track, pad_id, true)
            end
          else -- solo
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
    DrawListButton(SPLITTER, "S", COLOR["n"], nil, nil)
    --end

    r.ImGui_SetCursorPos(ctx, x + 60, y + 50)
    if r.ImGui_InvisibleButton(ctx, "M##mute" .. a, 30, 25) then
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
      DrawListButton(SPLITTER, "M", mute_color == true and COLOR["n"] or 0xff2222ff, nil, nil)
    else
      DrawListButton(SPLITTER, "M", COLOR["n"], nil, nil)
    end
  end
  r.ImGui_DrawListSplitter_Merge(SPLITTER)
end

----------------------------------------------------------------------
-- OTHER --
----------------------------------------------------------------------
local s_window_x, s_window_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding())
local s_frame_x, s_frame_y = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_FramePadding())

local tw, th = r.ImGui_CalcTextSize(ctx, "A") -- just single letter
local iw, ih = tw + (s_frame_x * 2), th + (s_frame_y * 2)

local def_btn_h = tw

local w_open, w_closed = 250, def_btn_h + (s_window_x * 2)

local setscroll = true

----------------------------------------------------------------------
-- RUN --
----------------------------------------------------------------------
function Main()
  local wx, wy = r.ImGui_GetWindowPos(ctx)
  local w_open, w_closed = 250, def_btn_h + s_window_x * 2 + 10
  local h = 220
  local hh = h + 100
  local hy = hh / 8
  if r.ImGui_IsWindowDocked(ctx) then
    button_offset = 6
  else
    button_offset = 25
  end

  r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ChildBg(), COLOR["bg"])

  
  draw_list = r.ImGui_GetWindowDrawList(ctx)                  -- 4 x 4 left veertical bar drawing
  f_draw_list = r.ImGui_GetForegroundDrawList(ctx) 
  local SPLITTER = r.ImGui_CreateDrawListSplitter(f_draw_list)
  r.ImGui_DrawListSplitter_Split(SPLITTER, 2)                     -- NUMBER OF Z ORDER CHANNELS
  --if Pad[a] then
  --  r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 1)       -- SET HIGHER PRIORITY TO DRAW FIRST
  --  local x, y = r.ImGui_GetCursorPos(ctx)
  --  r.ImGui_DrawList_AddRectFilled(f_draw_list, 100, 100, 100, 100, 0x654321FF)
  --end
  r.ImGui_DrawListSplitter_SetCurrentChannel(SPLITTER, 0)       -- SET LOWER PRIORITY TO DRAW AFTER
  local x, y = r.ImGui_GetCursorPos(ctx)
  --  r.ImGui_DrawList_AddRect(draw_list, wx+x-2, wy+y-2+33 * (i-1), wx+x+33, wy+y+33 * i, 0xFFFFFFFF)  -- white box when selected

  DrawPads(1, 128)
  if OPEN_PAD ~= nil then
    r.ImGui_SetCursorPos(ctx, 40, 0)
    local y = r.ImGui_GetScrollY(ctx)
    y = y + 100
    OpenRS5kInsidePad(OPEN_PAD, y - 155)
  end
  r.ImGui_PopStyleColor(ctx)
end

function Run()
  track = r.GetSelectedTrack2(0, 0, false)
  TRACK = track
  if track then
    trackidx = r.CSurf_TrackToID(track, false)
    track_guid = r.GetTrackGUID(track)
  end
  if set_dock_id then
    r.ImGui_SetNextWindowDockID(ctx, set_dock_id)
    set_dock_id = nil
  end
  if OPEN_PAD ~= nil then
    main_w = 800
  else
    main_w = 400
  end
  r.ImGui_SetNextWindowSizeConstraints(ctx, 400, 320, FLT_MAX, FLT_MAX)
  r.ImGui_SetNextWindowSize(ctx, main_w, 300)
  
  r.ImGui_PushStyleColor(ctx, r.ImGui_Col_WindowBg(), COLOR["bg"])
  r.ImGui_PushStyleColor(ctx, r.ImGui_Col_TitleBg(), COLOR["bg"])
  r.ImGui_PushStyleColor(ctx, r.ImGui_Col_TitleBgActive(), COLOR["bg"])
  local imgui_visible, imgui_open = r.ImGui_Begin(ctx, 'ReaDrum Machine', true)
  r.ImGui_PopStyleColor(ctx)
  r.ImGui_PopStyleColor(ctx)
  r.ImGui_PopStyleColor(ctx)

  if imgui_visible then
    imgui_width, imgui_height = r.ImGui_GetWindowSize(ctx)

    if setscroll then
      local stored_y = r.GetExtState("ReaDrum Machine", "Scroll_Pos")
      if tonumber(stored_y) ~= nil then
        r.ImGui_SetScrollY(ctx, tonumber(stored_y))
      end
      setscroll = false
    end

    if not setscroll then
      local scroll_y = r.ImGui_GetScrollY(ctx)
      r.SetExtState("ReaDrum Machine", "Scroll_Pos", scroll_y, true)
    end

    if not TRACK then r.ImGui_TextDisabled(ctx, 'No track selected')
    else
    CheckKeys()
    Main()
    end
    r.ImGui_End(ctx)
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
