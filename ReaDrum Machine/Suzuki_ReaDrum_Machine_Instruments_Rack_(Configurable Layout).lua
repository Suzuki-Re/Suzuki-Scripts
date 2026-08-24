-- @description Suzuki ReaDrum Machine (Configurable Layout)
-- @author Suzuki, koeHnik
-- @license GPL v3
-- @version 1.7.7
-- @changelog
--   + new script with LayoutManager and configurable layout
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

local preset_metadata = {}
local preset_metadata_file = script_path .. "LayoutConfigs/presetMetadata.lua"
if r.file_exists(preset_metadata_file) then
  preset_metadata = dofile(preset_metadata_file)
end

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

-- Cache variables - persist across frames, invalidate on change
local cache_track_guid = nil           -- Track change detection
local cache_fx_count = nil             -- FX chain change detection
local cache_current_layout = nil       -- Cached layout table
local cache_layout_id = nil            -- Cached layout ID string (loaded at track change only)
local cache_pad_data_valid = false     -- Track if Pad[] is current

is_edit_mode = true -- Global for edit/play mode

require("Modules/LayoutManager")
require("Modules/DragNDrop")
require("Modules/Drawing_Configurable")
require("Modules/FX List")
require("Modules/General Functions")
require("Modules/Pad Actions")

-- Load and validate layouts
layouts_data, layouts_error = LayoutManager_LoadLayouts()
if layouts_error then
  -- r.ShowConsoleMsg("ReaDrum Machine - Layout System: " .. layouts_error .. "\n")
else
  local all_errors = LayoutManager_ValidateAll(layouts_data)
  if #all_errors > 0 then
    local error_msg = "ReaDrum Machine - Layout Validation Errors:\n\n" .. table.concat(all_errors, "\n\n")
    -- r.ShowConsoleMsg(error_msg .. "\n\n(Copy errors above and paste into a text editor for easier viewing)\n")
  end
end

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

function ButtonDrawlist(name, color, a, note_label)
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
  im.DrawList_AddText(draw_list, xs, ys, 0xffffffff, note_label or note_name)

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

function DrawSinglePad(pad_idx, note_num, pad_label, x, y, pad_width, pad_height, relative_note)
  local a = pad_idx
  notenum = note_num  -- Set as GLOBAL for use in DndAddSample_TARGET and other functions
  
  -- Get current layout to check for custom note names
  local current_layout = GetCurrentLayout()
  
  -- Use layout-specific note name if available, otherwise use chromatic
  if relative_note ~= nil and current_layout and current_layout.noteNames then
    local pitch_class = current_layout.noteNames[tostring(relative_note)]
    if pitch_class then
      -- Append octave number to pitch class: MIDI octave = note_num // 12 - 1
      local octave_num = note_num // 12 - 1
      note_name = pitch_class .. octave_num
    else
      note_name = LayoutManager_GetNoteName(note_num, current_layout)
    end
  else
    note_name = LayoutManager_GetNoteName(note_num, current_layout)
  end
  
  im.SetCursorPos(ctx, x, y)
  local ret = im.InvisibleButton(ctx, pad_label .. "##" .. a, pad_width, pad_height)
  
  -- Determine pad color: use container color if pad exists, otherwise empty/neutral
  local pad_color = (Pad[a] and COLOR["Container"]) or 0x555555ff
  
  -- Generate the dynamic note label: layout-specific name (with octave) + MIDI number
  local note_display = note_name .. " (" .. note_num .. ")"
  ButtonDrawlist(pad_label, pad_color, a, note_display)
  
  -- Only do advanced interactions if pad actually exists
  if Pad[a] then
    DndAddFX_TARGET(a)
    DndAddSample_TARGET(a)
    UpdatePadID()
    DndMoveFX_TARGET_SWAP(a)
    PadMenu(a, LayoutManager_GetNoteName(note_num, GetCurrentLayout()))
    
    if im.IsItemHovered(ctx) then
      OnPad = true
      if im.Shortcut(ctx, im.Mod_Ctrl | im.Key_V) then
        PasteSamplesFromClipboard(a)
      end
    end
    
    if ret then
      ClickPadActions(a)
    elseif im.IsItemClicked(ctx, 1) and not CTRL then
      OPEN_PAD = toggle2(OPEN_PAD, a)
    elseif SHIFT and im.IsMouseDragging(ctx, 0) and im.IsItemActive(ctx) then
      AdjustPadVolume(a)
    else
      DndMoveFX_SRC(a)
    end

    -- Play button
    im.SetCursorPos(ctx, x, y + pad_height + 5)
    im.InvisibleButton(ctx, "▶##play" .. a, pad_width / 3, 25)  -- im.InvisibleButton returns true when clicked THIS FRAME, false otherwise
    
    SendMidiNote(a)  -- is always executed but checks for mouse clicks internally
    DrawListButton("-", COLOR["n"], nil, true)

    -- Solo button
    im.SetCursorPos(ctx, x + pad_width / 3, y + pad_height + 5)
    if im.InvisibleButton(ctx, "S##solo" .. a, pad_width / 3, 25) then
      HandleSoloButton(a)
    end
    DrawListButton("S", COLOR["n"], nil, nil)

    -- Mute button
    im.SetCursorPos(ctx, x + 2 * (pad_width / 3), y + pad_height + 5)
    if im.InvisibleButton(ctx, "M##mute" .. a, pad_width / 3, 25) then
      HandleMuteButton(a)
    end
    if Pad[a] then
      mute_color = r.TrackFX_GetEnabled(track, Pad[a].Pad_ID)
      DrawListButton("M", mute_color == true and COLOR["n"] or 0xff2222ff, nil, nil)
    else
      DrawListButton("M", COLOR["n"], nil, nil)
    end
  else
    -- Empty pad - allow drag and drop to add samples
    if im.IsItemHovered(ctx) then
      OnPad = true
    end
    -- Drag-drop targets must be registered for all pads (empty and full)
    DndAddFX_TARGET(a)
    DndAddSample_TARGET(a)
    DndMoveFX_TARGET_SWAP(a)
    UpdatePadID()
  end
end

-- Handle solo button click logic
function HandleSoloButton(a)
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

-- Handle mute button click logic
function HandleMuteButton(a)
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

-- Get current layout from cache - zero function calls, pure lookup
function GetCurrentLayout()
  if not layouts_data then 
    return nil 
  end
  return cache_current_layout
end

-- Invalidate layout cache to force reload on next render
function InvalidateLayoutCache()
  cache_current_layout = nil
  cache_layout_id = nil
end

function DrawPads(loopmin, loopmax)
  CheckDNDType()
  FXLIST()
  DoubleClickActions(loopmin, loopmax)

  local current_layout = GetCurrentLayout()
  local spacing = 5
  local start_y = 230
  local start_x = 5
  
  -- Get window width - crucial for responsive layout
  local window_width = im.GetWindowWidth(ctx) or 385
  
  -- Get octave offset for current track (default to octave 2 if not set)
  -- LAST_MENU now ranges from -1 to 9 (octaves), so octave_offset = LAST_MENU + 1 (gives 0-10 for MIDI calculation)
  local octave_offset
  if LAST_MENU == nil then
    octave_offset = 3  -- Default to octave 2 (octave_offset = 3)
  else
    octave_offset = LAST_MENU + 1
  end
  
  -- Calculate responsive pad size based on layout and available space
  local cols = 4
  local rows = 2
  local pad_w = 90
  local pad_h = 50
  
  if current_layout and current_layout.cols and current_layout.rows then
    cols = current_layout.cols
    rows = current_layout.rows
    
    -- Calculate width to fit all columns with spacing
    local available_width = window_width - spacing * (cols + 1) - 20
    pad_w = math.max(current_layout.minPadWidth or 40, available_width / cols)
    -- For layouts with many columns, also apply a maximum pad width
    if cols > 8 then
      pad_w = math.min(pad_w, 65)
    end
    pad_h = 50
  end
  
  -- Render pads in the requested range, arranged by layout grid if available
  local pad_idx = loopmin
  
  if current_layout and current_layout.grid then
    -- Reverse grid rows for correct visual order (top to bottom matches layout definition)
    local reversed_grid = {}
    for i = #current_layout.grid, 1, -1 do
      table.insert(reversed_grid, current_layout.grid[i])
    end

    -- Iterate grid positions and render pads in sequence
    for row_idx, row in ipairs(reversed_grid) do
      for col_idx, relative_note in ipairs(row) do
        if pad_idx <= loopmax then
          -- Calculate final MIDI note with octave offset
          local final_midi = relative_note + (octave_offset * 12)
          
          -- Skip if exceeds MIDI range
          if final_midi < 0 or final_midi > 127 then
            if pad_idx == loopmin then
            end
            pad_idx = pad_idx + 1
            goto continue_loop
          end
          
          local notenum = final_midi

          local pad_name = ""
          if Pad[final_midi + 1] then
            if Pad[final_midi + 1].Rename then
              pad_name = Pad[final_midi + 1].Rename
            elseif Pad[final_midi + 1].Name then
              pad_name = Pad[final_midi + 1].Name
            end
          end
          
          -- Calculate position from grid (account for button space below pads)
          local x = start_x + (col_idx - 1) * (pad_w + spacing)
          local y = start_y + (row_idx - 1) * -(pad_h + 30 + spacing)  -- 30 = pad (25) + small gap (5)
          
          -- Pass relative_note to DrawSinglePad for layout-specific name lookup
          DrawSinglePad(final_midi + 1, notenum, pad_name, x, y, pad_w, pad_h, relative_note)
          pad_idx = pad_idx + 1
          ::continue_loop::
        end
      end
    end
  else
    -- Fallback: render pads in fixed 4-column grid
    for a = loopmin, loopmax do
      local relative_note = (a - 1) % 12  -- Compute relative note within octave for layout lookup
      notenum = (a - 1) + (octave_offset * 12)  -- Add octave offset to get actual MIDI note

      if Pad[notenum + 1] then
        if Pad[notenum + 1].Rename then
          pad_name = Pad[notenum + 1].Rename
        elseif Pad[notenum + 1].Name then
          pad_name = Pad[notenum + 1].Name
        else
          pad_name = ""
        end
      else
        pad_name = ""
      end
      
      local x = start_x + (a - loopmin) % 4 * 95
      local y = start_y + math.floor((a - loopmin) / 4) * -75
      
      -- Pass notenum + 1 as pad_idx (for Pad lookup), and notenum as the MIDI note
      DrawSinglePad(notenum + 1, notenum, pad_name, x, y, pad_w, pad_h, relative_note)
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
-- RenderOctaveButtons() - Render left sidebar with all octaves
----------------------------------------------------------------------
function SetOctaveDisplay(set_octave)
  LAST_MENU = set_octave
  r.SetProjExtState(0, "ReaDrum Machine", track_guid .. "LAST_MENU", tostring(set_octave))
end

function RenderOctaveButtons(start_x)
  local current_layout = GetCurrentLayout()
  if not current_layout then return end
  
  draw_list = im.GetWindowDrawList(ctx)
    -- Add space at top so selection border doesn't get clipped
  im.Spacing(ctx)

  -- get octave value from JSFX "MIDI_Router_octaves" in FxChain for current track (defaults to 2 if not set, which is standard piano octave 4)
  jsfx_octave = GetMidiRouterOctaveValue(track)

    -- 11 buttons for octaves 9 to -1 (full MIDI range 0-127)
  -- Render in reverse order so 9 is at top, -1 at bottom
  for octave = 9, -1, -1 do
    -- Let ImGui handle Y positioning (sequential layout)
    im.SetCursorPos(ctx, start_x, im.GetCursorPosY(ctx))
    
    local rv = im.InvisibleButton(ctx, "oct_" .. tostring(octave), 31, 31)
    local xs, ys = im.GetItemRectMin(ctx)
    local xe, ye = im.GetItemRectMax(ctx)
    
    -- Draw mini-grid matching current layout structure
    if current_layout.grid then
      local mini_pad_size = 7
      local mini_spacing = 1
      
      for row_idx, row in ipairs(current_layout.grid) do
        for col_idx, relative_note in ipairs(row) do
          -- Calculate MIDI note for this octave
          local midi_note = relative_note + ((octave+1) * 12)
          
          if midi_note >= 0 and midi_note <= 127 then
            -- Calculate mini-pad position within button
            local mini_x = xs + 2 + (col_idx - 1) * (mini_pad_size + mini_spacing)
            local mini_y = ys + 2 + (row_idx - 1) * (mini_pad_size + mini_spacing)
            
            -- Determine color: sample loaded (white) or empty (dark)
            local rect_color = 0x252525ff  -- dark gray default
            if Pad[midi_note + 1] and Pad[midi_note + 1].Filter_ID then
              local note_active = r.TrackFX_GetParam(track, Pad[midi_note + 1].Filter_ID, 1)
              rect_color = note_active == 1 and 0xffd700ff or 0xffffffff  -- gold or white if has sample
            end
            
            im.DrawList_AddRectFilled(draw_list, mini_x, mini_y, mini_x + mini_pad_size, mini_y + mini_pad_size, rect_color)
          end
        end
      end
    end
    
    -- In play mode, get octave from JSFX "MIDI_Router_octaves" in FxChain
    if not is_edit_mode then
      SetOctaveDisplay(jsfx_octave)
    end
    -- In edit mode, set octave display if octave button is clicked
    if (is_edit_mode and rv) then
      SetOctaveDisplay(octave)
    end
    
    -- Drag & drop support
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
    
    -- Highlight selected octave button
    if LAST_MENU == octave then
      im.DrawList_AddRect(draw_list, xs - 1, ys - 1, xe + 1, ye + 1, 0x184673ff, 0, nil, 2)
    end
  end
  
  -- Add space at bottom so selection border doesn't get clipped
  im.Spacing(ctx)
  im.Spacing(ctx)
  im.Spacing(ctx)
end

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

  draw_list = im.GetWindowDrawList(ctx)
  f_draw_list = im.GetForegroundDrawList(ctx)

  local x, y = im.GetCursorPos(ctx)
  local window_width = im.GetWindowWidth(ctx) or 450
  local window_height = im.GetWindowHeight(ctx) or 360

  if im.BeginChild(ctx, 'BUTTON_SECTION', w_closed + 10, window_height - 20) then
    -- Call new RenderOctaveButtons function
    -- ImGui will handle scrolling automatically with sequential layout
    RenderOctaveButtons(0)
    im.EndChild(ctx)
  end
  
  local openpad
  if LAST_MENU ~= nil then
    im.SetCursorPos(ctx, x + w_closed, y)
    local pad_menu_width = math.max(w_open + 135, window_width - w_closed - 30)
    if im.BeginChild(ctx, "child_menu", pad_menu_width, window_height - 20) then
      -- Get layout dimensions to calculate loopmax
      local current_layout = GetCurrentLayout()
      local loopmax = 1
      if current_layout and current_layout.grid then
        loopmax = 0
        for _, row in ipairs(current_layout.grid) do
          loopmax = loopmax + #row
        end
      end
      openpad = DrawPads(1, loopmax)
      im.EndChild(ctx)
    end
  end
  if OPEN_PAD ~= nil then
    im.SetCursorPos(ctx, 40, 0)
    OpenRS5kInsidePad(OPEN_PAD, 0)
  end
  -- Dummy to account for SetCursorPos() calls that extend group boundaries
  im.Dummy(ctx, window_width, window_height)
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

    -- Detect track change and update cache with new track's layout
    if track_guid ~= cache_track_guid then
      -- r.ShowConsoleMsg("[Run] track_guid ~= cache_track_guid\n")
      cache_track_guid = track_guid
      cache_fx_count = nil           -- Reset FX count on track change
      
      -- Load layout ID from ext state at track change (only place we call LayoutManager_GetLayoutForTrack)
      -- r.ShowConsoleMsg("[Run] LayoutManager_GetLayoutForTrack(track)\n", track)
      cache_layout_id = LayoutManager_GetLayoutForTrack(track) or layouts_data.defaultLayout
      cache_current_layout = layouts_data.layouts[cache_layout_id]
      
      cache_pad_data_valid = false   -- Invalidate pad data
      UpdatePadID()                   -- Only reload on track change
    end
    
    -- If layout cache was invalidated (e.g., user changed layout in menu), reload it
    if cache_layout_id == nil and track_guid then
      -- r.ShowConsoleMsg("[Run] Layout cache invalidated, reloading layout\n")
      cache_layout_id = LayoutManager_GetLayoutForTrack(track) or layouts_data.defaultLayout
      cache_current_layout = layouts_data.layouts[cache_layout_id]
    end
    
    -- Detect FX chain changes and invalidate cache
    local current_fx_count = r.TrackFX_GetCount(track)
    if current_fx_count ~= cache_fx_count then
      cache_fx_count = current_fx_count
      UpdateFxData()                  -- Only reload on FX chain change
    end
  end
  if set_dock_id then
    im.SetNextWindowDockID(ctx, set_dock_id)
    set_dock_id = nil
  end

  if track_guid then
    local _, n = r.GetProjExtState(0, "ReaDrum Machine", track_guid .. "LAST_MENU")
    if n ~= nil and n ~= "" then
      LAST_MENU = tonumber(n)
    end
  end
  
  -- Ensure LAST_MENU is always set - CRITICAL for drawing pads
  -- LAST_MENU ranges from -1 to 9 (octaves), so octave_offset = LAST_MENU + 1
  if LAST_MENU == nil or LAST_MENU < -1 or LAST_MENU > 9 then
    LAST_MENU = 3  -- Default to octave 3 (MIDI 36-47, middle range)
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
    CustomTitleBar(preset_metadata, 390)
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
end

function Init()
  SetButtonState(1)
  r.atexit(Exit)

  Run()
end

Init()

-- profiler.attachToWorld() -- after all functions have been defined
-- profiler.run()