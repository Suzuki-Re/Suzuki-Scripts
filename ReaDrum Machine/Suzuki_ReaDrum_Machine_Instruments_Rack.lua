-- @description Suzuki ReaDrum Machine
-- @author Suzuki
-- @license GPL v3
-- @version 1.2.3
-- @changelog 
--  + Added support for ReaDrum Machine inside container. Beware that only one RDM instance per track is allowed, just like it's been up to now.
-- @link https://forum.cockos.com/showthread.php?t=284566
-- @about ReaDrum Machine is a script which loads samples and FX from browser/arrange into subcontainers inside a container named ReaDrum Machine.
-- @provides
--   Fonts/Icons.ttf
--   Modules/*.lua
--   [effect] JSFX/*.jsfx
--   [main] Suzuki_ReaDrum_Machine_Instruments_Rack_(Scrollable Layout).lua

local r            = reaper
os_separator = package.config:sub(1, 1)
package.path       = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] ..
    "?.lua;" -- GET DIRECTORY FOR REQUIRE
package.path       = package.path ..
    debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "../ImGui_Tools/?.lua;"
script_path  = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]];
PATH         = debug.getinfo(1).source:match("@?(.*[\\|/])")
Pad          = {}

COLOR              = {
  ["n"]           = 0xff,
  ["Container"]   = 0x123456FF,
  ["dnd"]         = 0x00b4d8ff,
  ["dnd_replace"] = 0xdc5454ff,
  ["dnd_swap"]    = 0xcd6dc6ff,
  ["bg"] = 0x141414ff
}

--- PRE-REQUISITES ---
if not r.ImGui_GetVersion then
  r.ShowMessageBox("ReaImGui is required.\nPlease Install it in next window", "MISSING DEPENDENCIES", 0)
  return r.ReaPack_BrowsePackages('dear imgui')
end

function ThirdPartyDeps() -- FX Browser
  local version = tonumber(string.sub(r.GetAppVersion(), 0, 4))
  --reaper.ShowConsoleMsg((version))

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
    { name = "Sexan_Scripts", url = 'https://github.com/GoranKovac/ReaScripts/raw/master/index.xml' }
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
  end
end

if ThirdPartyDeps() then return end

----------------------
ctx = r.ImGui_CreateContext('ReaDrum Machine')

draw_list = r.ImGui_GetWindowDrawList(ctx)

ICONS_FONT = r.ImGui_CreateFont(script_path .. 'Fonts/Icons.ttf', 11)
r.ImGui_Attach(ctx, ICONS_FONT)

FLT_MIN, FLT_MAX = r.ImGui_NumericLimits_Float()

require("Modules/DragNDrop")
require("Modules/Drawing")
require("Modules/FX List")
require("Modules/General Functions")
require("Modules/Pad Actions")

local posx, posy = r.ImGui_GetCursorScreenPos(ctx)

----------------------------------------------------------------------
-- GUI --
----------------------------------------------------------------------

function ButtonDrawlist(splitter, name, color)
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

  local font_size = r.ImGui_GetFontSize(ctx)
  local char_size_w, char_size_h = r.ImGui_CalcTextSize(ctx, "A")
  local font_color = CalculateFontColor(color)

  r.ImGui_DrawList_AddTextEx( draw_list, nil, font_size, xs, ys + char_size_h, r.ImGui_GetColorEx(ctx, font_color), name, xe-xs)
  r.ImGui_DrawList_AddText(draw_list, xs, ys, 0xffffffff, note_name)
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

  for a = loopmin, loopmax do
    notenum = a - 1
    note_name = getNoteName(notenum)

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
    local y = 230 + math.floor((a - loopmin) / 4) * -75 -- start position + math.floor * - row offset
    local x = 5 + (a - 1) % 4 * 95

    r.ImGui_SetCursorPos(ctx, x, y)
    local ret = r.ImGui_InvisibleButton(ctx, pad_name .. "##" .. a, 90, 50)
    ButtonDrawlist(SPLITTER, pad_name, Pad[a] and COLOR["Container"] or COLOR["n"])
    DndAddFX_TARGET(a)
    DndAddSample_TARGET(a)
    -- DndAddMultipleSamples_TARGET(a)
    DndMoveFX_TARGET_SWAP(a)
    PadMenu(a, note_name)
    if ret then 
      ClickPadActions(a)
    else
      DndMoveFX_SRC(a)
    end

    r.ImGui_SetCursorPos(ctx, x, y + 50)
    r.ImGui_InvisibleButton(ctx, "▶##play" .. a, 30, 25)
    SendMidiNote(notenum)
    DrawListButton(SPLITTER,"-", COLOR["n"], nil, true)

    r.ImGui_SetCursorPos(ctx, x + 30, y + 50)
    if r.ImGui_InvisibleButton(ctx, "S##solo" .. a, 30, 25) then
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
    --if Pad[a] then
    --  local ok = r.TrackFX_GetEnabled(track, Pad[a].Pad_ID)
    --  DrawListButton("S", ok and 0xff or 0xf1c524ff, nil, nil)
    --else
    DrawListButton(SPLITTER, "S", COLOR["n"], nil, nil)
    --end

    r.ImGui_SetCursorPos(ctx, x + 60, y + 50)
    if r.ImGui_InvisibleButton(ctx, "M##mute" .. a, 30, 25) then
      if Pad[a] then
        local retval = r.TrackFX_GetEnabled(track, Pad[a].Pad_ID)
        if retval == true then
          r.TrackFX_SetEnabled(track, Pad[a].Pad_ID, false)
        else
          r.TrackFX_SetEnabled(track, Pad[a].Pad_ID, true)
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
  r.ImGui_BeginGroup(ctx)
  
  draw_list = r.ImGui_GetWindowDrawList(ctx)                  -- 4 x 4 left vertical tab drawing
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
  for ci = 0, hh - hy, hy - 4.5 do
    for bi = 0, 24, 8 do
      for i = 0, 24, 8 do
        r.ImGui_DrawList_AddRectFilled(f_draw_list, wx + x + i, wy + y + bi + ci, wx + x + 7 + i, wy + y + 7 + bi + ci,
          0x252525FF)
      end
    end
  end
  r.ImGui_DrawListSplitter_Merge(SPLITTER)       -- MERGE EVERYTHING FOR RENDER

  if r.ImGui_BeginChild(ctx, 'BUTTON_SECTION', w_closed + 10, h + 100, false) then   -- vertical tab
    for i = 1, 8 do
      r.ImGui_SetCursorPos(ctx, 0, y + (i - 1) * 35 - button_offset)
      
      rv = r.ImGui_InvisibleButton(ctx, "B" .. i, 31, 31)
      local xs, ys = r.ImGui_GetItemRectMin(ctx)
      local xe, ye = r.ImGui_GetItemRectMax(ctx)
      if rv then
        LAST_MENU = RememberTab(LAST_MENU, i)
      end
      r.ImGui_PushStyleColor(ctx, r.ImGui_Col_DragDropTarget(), 0)
      if r.ImGui_BeginDragDropTarget(ctx) then
        local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'DND ADD FX')
        r.ImGui_EndDragDropTarget(ctx)
      end
      r.ImGui_PopStyleColor(ctx)
      r.ImGui_PushStyleColor(ctx, r.ImGui_Col_DragDropTarget(), 0)
      if r.ImGui_BeginDragDropTarget(ctx) then
        local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'DND MOVE FX')
        r.ImGui_EndDragDropTarget(ctx)
      end
      r.ImGui_PopStyleColor(ctx)
      if (DND_ADD_FX or DND_MOVE_FX or r.ImGui_IsMouseDragging(ctx, 0)) and r.ImGui_IsMouseHoveringRect(ctx, xs, ys, xe, ye) then
        LAST_MENU = i
        r.SetProjExtState(0, "ReaDrum Machine", track_guid .. "LAST_MENU", i)
      end
      HighlightHvredItem()
      if LAST_MENU == i then 
        Highlight_Itm(f_draw_list, 0x12345655, 0x184673ff)
      end
    end
    r.ImGui_EndChild(ctx)
  end
  local openpad 
  if LAST_MENU then       -- Open pads manu
    r.ImGui_SetCursorPos(ctx, x + w_closed, y)
    if r.ImGui_BeginChild(ctx, "child_menu", w_open + 250, h + 88) then
      local high = 128 - 16 * (LAST_MENU - 1 )
      local low = 128 - 16 * (LAST_MENU) + 1
      openpad = DrawPads(low, high)
      r.ImGui_EndChild(ctx)
    end
  end
  r.ImGui_Dummy(ctx, w_closed + 10, h + 100)
  r.ImGui_EndGroup(ctx)
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

  if track_guid then
  local _, n = r.GetProjExtState(0, "ReaDrum Machine", track_guid .. "LAST_MENU")
    if n ~= nil then
      LAST_MENU = tonumber(n)
    end
  end

  r.ImGui_SetNextWindowSizeConstraints(ctx, 500, 360, FLT_MAX, FLT_MAX)
  r.ImGui_SetNextWindowSize(ctx, 400, 300, r.ImGui_Cond_FirstUseEver())
  
  r.ImGui_PushStyleColor(ctx, r.ImGui_Col_WindowBg(), COLOR["bg"])
  r.ImGui_PushStyleColor(ctx, r.ImGui_Col_TitleBg(), COLOR["bg"])
  r.ImGui_PushStyleColor(ctx, r.ImGui_Col_TitleBgActive(), COLOR["bg"])
  local imgui_visible, imgui_open = r.ImGui_Begin(ctx, 'ReaDrum Machine', true, r.ImGui_WindowFlags_NoScrollWithMouse() | r.ImGui_WindowFlags_NoScrollbar() | r.ImGui_WindowFlags_NoCollapse())
  r.ImGui_PopStyleColor(ctx)
  r.ImGui_PopStyleColor(ctx)
  r.ImGui_PopStyleColor(ctx)

  if imgui_visible then
    imgui_width, imgui_height = r.ImGui_GetWindowSize(ctx)

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
