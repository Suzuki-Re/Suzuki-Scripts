--@noindex
-- LayoutManager.lua
-- Handles loading, validation, switching, and per-track persistence of layout configurations

local LAYOUT_CONFIG_FILE = script_path .. "LayoutConfigs/layouts.lua"
local LAYOUT_STATE_FILE = script_path .. "LayoutConfigs/layout_state.lua"
local LAYOUT_STATE_KEY = "_LAYOUT"
local LAYOUT_SCALE_KEY = "_LAYOUT_SCALE"

-- Load layout state from file
local function LoadLayoutState()
  if r.file_exists(LAYOUT_STATE_FILE) then
    local status, state = pcall(function()
      return dofile(LAYOUT_STATE_FILE)
    end)
    if status then
      return state
    end
  end
  return {}
end

-- Save layout state to file
local function SaveLayoutState(state)
  local file = io.open(LAYOUT_STATE_FILE, "w")
  if not file then
    r.ShowConsoleMsg("ERROR: Cannot write to " .. LAYOUT_STATE_FILE .. "\n")
    return false
  end
  
  file:write("return {\n")
  for guid, layout_id in pairs(state) do
    file:write('  ["' .. guid .. '"] = "' .. layout_id .. '",\n')
  end
  file:write("}\n")
  file:close()
  return true
end

local layout_state_cache = LoadLayoutState()


-- Load and parse layouts.lua file
function LayoutManager_LoadLayouts()
  if not r.file_exists(LAYOUT_CONFIG_FILE) then
    return nil, "ERROR: Layout config file not found at " .. LAYOUT_CONFIG_FILE
  end
  
  local status, layouts_data = pcall(function()
    return dofile(LAYOUT_CONFIG_FILE)
  end)
  
  if not status then
    return nil, "ERROR: Failed to load layouts.lua\n\nDetails: " .. tostring(layouts_data) .. "\n\nFile: " .. LAYOUT_CONFIG_FILE
  end
  
  return layouts_data, nil
end

-- Helper to count table length
function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

-- Validate layout structure
function LayoutManager_ValidateLayout(layout_id, layout, all_layouts)
  local errors = {}
  
  if not layout.name then
    table.insert(errors, "Layout '" .. layout_id .. "': Missing 'name' field")
  end
  
  if not layout.rows or type(layout.rows) ~= "number" or layout.rows < 1 then
    table.insert(errors, "Layout '" .. layout_id .. "': 'rows' must be a positive number")
  end
  
  if not layout.cols or type(layout.cols) ~= "number" or layout.cols < 1 then
    table.insert(errors, "Layout '" .. layout_id .. "': 'cols' must be a positive number")
  end
  
  if not layout.grid or type(layout.grid) ~= "table" then
    table.insert(errors, "Layout '" .. layout_id .. "': Missing 'grid' array")
  else
    if #layout.grid ~= layout.rows then
      table.insert(errors, "Layout '" .. layout_id .. "': grid has " .. #layout.grid .. " rows, but 'rows' is set to " .. layout.rows)
    end
    
    local grid_notes = {}
    for row_idx, row in ipairs(layout.grid) do
      if type(row) ~= "table" then
        table.insert(errors, "Layout '" .. layout_id .. "': grid row " .. row_idx .. " is not an array")
      elseif #row ~= layout.cols then
        table.insert(errors, "Layout '" .. layout_id .. "': grid row " .. row_idx .. " has " .. #row .. " columns, but 'cols' is set to " .. layout.cols)
      else
        for col_idx, note_num in ipairs(row) do
          if type(note_num) ~= "number" then
            table.insert(errors, "Layout '" .. layout_id .. "': grid[" .. row_idx .. "][" .. col_idx .. "] is not a number (MIDI note), got " .. type(note_num))
          elseif note_num < 0 or note_num > 127 then
            table.insert(errors, "Layout '" .. layout_id .. "': grid[" .. row_idx .. "][" .. col_idx .. "] = " .. note_num .. " is not a valid MIDI note (0-127)")
          end
          grid_notes[tostring(note_num)] = true
        end
      end
    end
    
    -- Check for duplicates in grid
    if layout.grid then
      local seen_notes = {}
      for row_idx, row in ipairs(layout.grid) do
        for col_idx, note_num in ipairs(row) do
          if seen_notes[note_num] then
            table.insert(errors, "Layout '" .. layout_id .. "': Duplicate MIDI note " .. note_num .. " found in grid")
          end
          seen_notes[note_num] = { row = row_idx, col = col_idx }
        end
      end
    end
    
    -- Check if aliases reference notes that exist in grid
    if layout.aliases and type(layout.aliases) == "table" then
      for note_str, alias_name in pairs(layout.aliases) do
        if not grid_notes[note_str] then
          table.insert(errors, "Layout '" .. layout_id .. "': alias for note " .. note_str .. " doesn't exist in grid")
        end
      end
    end
  end
  
  return errors
end

-- Validate all layouts in the loaded data
function LayoutManager_ValidateAll(layouts_data)
  if not layouts_data or not layouts_data.layouts then
    return { "No layouts data provided" }
  end
  
  local all_errors = {}
  for layout_id, layout in pairs(layouts_data.layouts) do
    local layout_errors = LayoutManager_ValidateLayout(layout_id, layout, layouts_data.layouts)
    for _, error in ipairs(layout_errors) do
      table.insert(all_errors, error)
    end
  end
  
  return all_errors
end

-- Get layout ID for current track
function LayoutManager_GetLayoutForTrack(track_obj)
  if not track_obj then return nil end
  local track_guid = r.GetTrackGUID(track_obj)
  
  local layout_id = layout_state_cache[track_guid]
  
  if not layout_id or layout_id == "" then
    return nil  -- Use default
  end
  -- r.ShowConsoleMsg("[GetLayout] Reading " .. track_guid .. " -> layout: " .. tostring(layout_id) .. "\n")
  return layout_id
end

-- Set layout ID for current track
function LayoutManager_SetLayoutForTrack(track_obj, layout_id)
  if not track_obj then 
    return false 
  end
  local track_guid = r.GetTrackGUID(track_obj)
  
  layout_state_cache[track_guid] = layout_id
  local success = SaveLayoutState(layout_state_cache)
  -- r.ShowConsoleMsg("[SetLayout] Set " .. track_guid .. " to layout: " .. tostring(layout_id) .. "\n")
  
  return success
end

-- Get scale factor for current track
function LayoutManager_GetScaleForTrack(track_obj)
  if not track_obj then return 1.0 end
  local track_guid = r.GetTrackGUID(track_obj)
  local scale_str = r.GetProjExtState(0, "ReaDrum Machine", track_guid .. LAYOUT_SCALE_KEY)
  
  if scale_str == "" then
    return 1.0
  end
  return tonumber(scale_str) or 1.0
end

-- Set scale factor for current track
function LayoutManager_SetScaleForTrack(track_obj, scale)
  if not track_obj then return false end
  local track_guid = r.GetTrackGUID(track_obj)
  r.SetProjExtState(0, "ReaDrum Machine", track_guid .. LAYOUT_SCALE_KEY, tostring(scale))
  return true
end

-- List all available layouts
function LayoutManager_GetAvailableLayouts(layouts_data)
  if not layouts_data or not layouts_data.layouts then
    return {}
  end
  
  local layout_list = {}
  for layout_id, layout in pairs(layouts_data.layouts) do
    table.insert(layout_list, {
      id = layout_id,
      name = layout.name or layout_id,
      description = layout.description or "",
      is_default = layout_id == (layouts_data.defaultLayout or "chromatic_3x4")
    })
  end
  
  -- Sort: default layout first, then alphabetically by name
  table.sort(layout_list, function(a, b) 
    if a.is_default ~= b.is_default then
      return a.is_default  -- true comes first
    end
    return a.name < b.name 
  end)
  
  return layout_list
end

-- Find pad index by MIDI note number
function LayoutManager_FindPadByNote(note_num)
  for idx, pad_data in ipairs(Pad) do
    if pad_data and pad_data.Note_Num == note_num then
      return idx
    end
  end
  return nil
end

-- Get grid position for note (row, col)
-- Get grid position for a given pad index (0-127)
-- Returns col, row (1-based) or nil if not found in layout
function LayoutManager_GetGridPositionForPad(pad_idx, layout)
  if not layout or not layout.grid then
    return nil, nil
  end
  
  -- Map pad indices to MIDI notes they trigger
  -- Pads 0-15 = MIDI 36-51 (default drumkit)
  -- Pads 16-31 = MIDI 52-67, etc.
  local midi_note = 36 + pad_idx
  
  for row_idx, row in ipairs(layout.grid) do
    for col_idx, grid_note in ipairs(row) do
      if grid_note == midi_note then
        return col_idx, row_idx
      end
    end
  end
  
  return nil, nil
end

-- Get position for a given pad index
function LayoutManager_GetPadPosition(pad_idx, layout, start_x, start_y, pad_w, pad_h, spacing)
  if not layout or not layout.grid then
    return nil, nil
  end
  
  spacing = spacing or 5
  start_x = start_x or 5
  start_y = start_y or 230
  pad_w = pad_w or 90
  pad_h = pad_h or 50
  
  local col, row = LayoutManager_GetGridPositionForPad(pad_idx, layout)
  
  if not col or not row then
    return nil, nil
  end
  
  -- Calculate screen position based on grid position
  local x = start_x + (col - 1) * (pad_w + spacing)
  local y = start_y + (row - 1) * -(pad_h + spacing)
    
  return x, y
end

-- Get note name (with MIDI number)
function LayoutManager_GetNoteName(note_num, layout)
  local base_name = ""
  
  if layout and layout.noteNames and layout.noteNames[tostring(note_num)] then
    base_name = layout.noteNames[tostring(note_num)]
  else
    -- Fallback: generate from MIDI number
    local note_names = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }
    local octave = math.floor(note_num / 12) - 1
    local note_in_octave = note_num % 12 + 1
    base_name = note_names[note_in_octave] .. octave
  end
  
  return base_name
end

-- Format pad label with alias and note number
function LayoutManager_FormatPadLabel(note_num, alias, layout)
  local note_name = LayoutManager_GetNoteName(note_num, layout)
  local label = ""
  
  if alias and alias ~= "" then
    label = alias .. " [" .. note_num .. "]"
  else
    label = note_name .. " [" .. note_num .. "]"
  end
  
  return label
end
