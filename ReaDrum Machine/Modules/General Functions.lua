--@noindex

function msg(...)
  for i, v in ipairs({ ... }) do
      r.ShowConsoleMsg(tostring(v) .. "\n")
  end
end

function SetButtonState(set) -- Set ToolBar Button State
  local is_new_value, filename, sec, cmd, mode, resolution, val = r.get_action_context()
  r.SetToggleCommandState(sec, cmd, set or 0)
  r.RefreshToolbar2(sec, cmd)
end

function Exit()
  SetButtonState()
  if preview and r.EnumProjects(0) then
    r.CF_Preview_Stop(preview)
  end
end

function CheckKeys()
  ALT = im.GetKeyMods(ctx) == im.Mod_Alt
  CTRL = im.GetKeyMods(ctx) == im.Mod_Ctrl
  SHIFT = im.GetKeyMods(ctx) == im.Mod_Shift

  HOME = im.IsKeyPressed(ctx, im.Key_Home)
  SPACE = im.IsKeyPressed(ctx, im.Key_Space)
  ESC = im.IsKeyPressed(ctx, im.Key_Escape)

  UpArrow = im.IsKeyPressed(ctx, im.Key_UpArrow)
  DownArrow = im.IsKeyPressed(ctx, im.Key_DownArrow)
  
  UpArrowReleased = im.IsKeyReleased(ctx, im.Key_UpArrow)
  DownArrowReleased = im.IsKeyReleased(ctx, im.Key_DownArrow)

  Z = im.IsKeyPressed(ctx, im.Key_Z)
  --R = im.IsKeyPressed(ctx, im.Key_R)

  if HOME then CANVAS.off_x, CANVAS.off_y = 0, def_vertical_y_center end

  if CTRL and Z then
    r.Main_OnCommand(40029, 0)
    UpdatePadID()
    -- CHECK IF TRACK CHANGED
    TRACK = r.GetSelectedTrack2(0, 0, true)
  end                            -- UNDO
  if im.GetKeyMods(ctx) == im.Mod_Ctrl | im.Mod_Shift and Z then
    r.Main_OnCommand(40030, 0)   -- REDO
  end

  if SPACE and (not FX_OPENED and not RENAME_OPENED and not FILE_MANAGER_OPENED) then r.Main_OnCommand(40044, 0) end -- PLAY STOP

  -- ACTIVATE CTRL ONLY IF NOT PREVIOUSLY DRAGGING
  if not CTRL_DRAG then
    CTRL_DRAG = (not MOUSE_DRAG and CTRL) and im.IsMouseDragging(ctx, 0)
  end
  MOUSE_DRAG = im.IsMouseDragging(ctx, 0)
end

function CheckStaleData()
  if im.IsMouseReleased(ctx, 0) then
      CTRL_DRAG = nil
  --    DRAG_PREVIEW = nil
  end
  --if not PEAK_INTO_TOOLTIP then
  --    if PREVIEW_TOOLTIP then PREVIEW_TOOLTIP = nil end
  --end
end

function GetMidiOctOffsSettings()
  local midi_octave_offset = r.SNM_GetIntConfigVar("midioctoffs", 0)
  if not midi_octave_offset then midi_octave_offset = 0 end
  local midi_oct_offs = (midi_octave_offset - 1) * 12
  return midi_oct_offs
end

function get_fx_id_from_container_path(tr, idx1, ...) -- 1based
  local sc, rv = r.TrackFX_GetCount(tr) + 1, 0x2000000 + idx1
  local vararg = {}
  for i, v in ipairs({ ... }) do
    local ccok, cc = r.TrackFX_GetNamedConfigParm(tr, rv, 'container_count')
    vararg[i] = v
    if ccok ~= true then return nil end
    rv = rv + sc * v
    sc = sc * (1 + tonumber(cc))
  end
  local new_sc, new_rv 
  if NestedPath then -- if Drum Machine is nested
    new_vararg = {}
   for i = 1, #NestedPath do
    new_vararg[i] = NestedPath[i]
   end  
    new_vararg[#new_vararg + 1] = idx1
   for i = 1, #vararg do
    new_vararg[#new_vararg + 1] = vararg[i]
   end
   local new_sc, new_rv = r.TrackFX_GetCount(track)+1, 0x2000000 + new_vararg[1]
    for i = 2, #new_vararg do
    local new_v = new_vararg[i]
    local new_ccok, new_cc = r.TrackFX_GetNamedConfigParm(track, new_rv, 'container_count')
    new_ccok = tostring(new_ccok)
    new_rv = new_rv + new_sc * new_v
    new_sc = new_sc * (1+tonumber(new_cc))  
    end
    return new_rv
  else
    return rv
  end
end

local function get_container_path_from_fx_id(tr, fxidx) -- returns a list of 1-based FXIDs as a table from a fx-address, e.g. 1, 2, 4
  if fxidx & 0x2000000 then
    local ret = { }
    local n = reaper.TrackFX_GetCount(tr)
    local curidx = (fxidx - 0x2000000) % (n+1)
    local remain = math.floor((fxidx - 0x2000000) / (n+1))
    if curidx < 1 then return nil end -- bad address

    local addr, addr_sc = curidx + 0x2000000, n + 1
    while true do
      local ccok, cc = reaper.TrackFX_GetNamedConfigParm(tr, addr, 'container_count')
      if not ccok then return nil end -- not a container
      ret[#ret+1] = curidx
      n = tonumber(cc)
      if remain <= n then if remain > 0 then ret[#ret+1] = remain end return ret end
      curidx = remain % (n+1)
      remain = math.floor(remain / (n+1))
      if curidx < 1 then return nil end -- bad address
      addr = addr + addr_sc * curidx
      addr_sc = addr_sc * (n+1)
    end
  end
  return { fxid+1 }
end

function ConvertPathToNestedPath(path_id, target_pos)
  NestedPath = get_container_path_from_fx_id(track, tonumber(path_id))
  target_id = get_fx_id_from_container_path(track, target_pos) -- parent -> #1 track, #2 child of parent
  NestedPath = nil --reset
  return target_id
end

local function FindRDMRecursively(track, fxid, scale)
  local ccok, container_count = r.TrackFX_GetNamedConfigParm(track, fxid, 'container_count')
  local rv, rename = r.TrackFX_GetNamedConfigParm(track, fxid, 'renamed_name') -- 0 based

  if rename == 'ReaDrum Machine' then
    found = true
    parent_id = fxid
  end

  if ccok then -- next layer
    local newscale = scale * (tonumber(container_count)+1)
    for child = 1, tonumber(container_count) do
      FindRDMRecursively(track, fxid + scale * child, newscale)
    end
  end
  if not found then
    parent_id = nil
  end
  return parent_id
end

function GetDrumMachineIdx(track)
  if not track then return end
  found = false
  count = r.TrackFX_GetCount(track)
  for i = 1, count do
    parent_id = FindRDMRecursively(track, 0x2000000+i, count+1)
  end
  return parent_id
end

function InsertDrumMachine()
  GetDrumMachineIdx(track)
  if not found then
    r.Undo_BeginBlock()
    r.PreventUIRefresh(1)
    r.TrackFX_AddByName(track, "Container", false, -1000 - count)                 -- 0 based + count(1 based) = the last slot
    r.TrackFX_Show(track, count, 2)
    r.TrackFX_SetNamedConfigParm(track, count, 'renamed_name', 'ReaDrum Machine') -- 0 based + count(1 based) = the last slot
    r.PreventUIRefresh(-1)
    EndUndoBlock("ADD DRUM MACHINE")
  end
end
  
function AddPad(note_name, a) -- pad_id, pad_num
  local pad_id = ConvertPathToNestedPath(parent_id, pads_idx + 1)
  local pad_id = tonumber(pad_id)
  r.TrackFX_AddByName(track, 'Container', false, pad_id)      -- Add a pad
  r.TrackFX_Show(track, pad_id, 2)
  r.TrackFX_SetNamedConfigParm(track, pad_id, 'renamed_name', note_name)
  r.TrackFX_SetNamedConfigParm(track, pad_id, 'parallel', 1)          -- set parallel
  local previous_pad_id = ConvertPathToNestedPath(parent_id, pads_idx)
  local next_pad_id = ConvertPathToNestedPath(parent_id, pads_idx + 2)
  pad_num = pads_idx + 1
  Pad[a] = {
    Previous_Pad_ID = previous_pad_id,
    Pad_ID = pad_id,
    Next_Pad_ID = next_pad_id,
    Pad_Num = pads_idx + 1,
    Pad_GUID = r.TrackFX_GetFXGUID(track, pad_id),
    TblIdx = a,
    Note_Num = notenum
  }
end
  
function CountPads()                                                                   -- pads_idx
  GetDrumMachineIdx(track)
  if parent_id == nil then return end
  rv, pads_idx = r.TrackFX_GetNamedConfigParm(track, parent_id, 'container_count') -- 0 based
  pads_idx = tonumber(pads_idx)
  return pads_idx
end
  
local function GetPadGUID()
  CountPads()
  for p = 1, pads_idx do
    local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. p - 1) -- 0 based
    local pad_guid = r.TrackFX_GetFXGUID(track, pad_id)
  end
end
  
function CountPadFX(pad_num)                                                        -- padfx_idx
  local _, which_pad = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. pad_num - 1) -- 0 based
  rv, padfx_idx = r.TrackFX_GetNamedConfigParm(track, tonumber(which_pad), 'container_count') -- 0 based
  return padfx_idx
end
  
function EndUndoBlock(str)
  r.Undo_EndBlock("ReaDrum Machine: " .. str, -1)
end

function getNoteName(notenum) -- Thanks Fabian https://forum.cockos.com/showpost.php?p=2521073&postcount=5
  local notes = { "A", "A#", "B", "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#" }
  local octave = math.floor(notenum / 12) - 1
  local notename = notes[((notenum - 21) % 12) + 1]  -- 21 A0, 22 A#0, 23 B0, 24 C1, ... 35 B1, 36 C2, ...
  
  return notename .. octave
end
  
  local function getNoteNumber(note) -- Assumes capital letters, only use '#' (not 'b')
    local notes = { A = 9, ["A#"] = 10, B = 11, C = 0, ["C#"] = 1, D = 2, ["D#"] = 3, E = 4, F = 5, ["F#"] = 6, G = 7,
      ["G#"] = 8 }
  
    local num = (string.byte(note, 2) == string.byte("#") and 2) or 1
    local base = notes[note:sub(1, num)]
    local oct = string.byte(note, num + 1) - string.byte('0') - 1
  
    return base + 12 * oct + 24 -- C1 = 24
  end

function FindNoteFilter(pad_num)
  CountPadFX(pad_num) 
  local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. pad_num - 1) -- 0 based
  if padfx_idx ~= 0 then
    for f = 1, padfx_idx do      
      local _, find_filter = r.TrackFX_GetNamedConfigParm(track, pad_id, "container_item." .. f - 1) -- 0 based
      local retval, buf = r.TrackFX_GetNamedConfigParm(track, find_filter, 'fx_name')
      if buf == "JS: RDM MIDI Utility" or "JS: RDM MIDI Utility [Suzuki Scripts/ReaDrum Machine/JSFX/RDM_midi_utility.jsfx]" then
        fi = f
        filter_id = find_filter
        break
      end
    end
  end
  return fi, filter_id
end
  

function UpdatePadID()
  if not track then return end
  Pad = {}
  GetDrumMachineIdx(track)
  if not parent_id then return end
  local pads_idx = CountPads()
  local tr_ch = r.GetMediaTrackInfo_Value(track, "I_NCHAN")
  local isnested, n_pc = r.TrackFX_GetNamedConfigParm(track, parent_id, 'parent_container')
  if isnested then
    r.TrackFX_SetNamedConfigParm(track, n_pc, 'container_nch', tr_ch)
    r.TrackFX_SetNamedConfigParm(track, n_pc, 'container_nch_out', tr_ch)
  end
  if pads_idx == nil then return end
  for p = 1, pads_idx do -- 1 based
    local fi = FindNoteFilter(p)
    if not fi then return end
    local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. p - 1) -- 0 based
    local _, filter_id = r.TrackFX_GetNamedConfigParm(track, pad_id, "container_item." .. fi - 1) -- 0 based
    local rv = r.TrackFX_GetParam(track, filter_id, 0)
    local rv = math.floor(tonumber(rv))
    local previous_pad_id = ConvertPathToNestedPath(parent_id, p - 1)
    local next_pad_id = ConvertPathToNestedPath(parent_id, p + 1)
    local fx_num = CountPadFX(p)
    local out_low32l, out_high32l = r.TrackFX_GetPinMappings(track, pad_id, 1, 0)
    local out_low32r, out_high32r = r.TrackFX_GetPinMappings(track, pad_id, 1, 1)
    local out_n_low32l, out_n_high32l = r.TrackFX_GetPinMappings(track, pad_id, 1, 0 + 0x1000000)
    local out_n_low32r, out_n_high32r = r.TrackFX_GetPinMappings(track, pad_id, 1, 1 + 0x1000000)
    Pad[rv + 1] = {
      Previous_Pad_ID = previous_pad_id,
      Pad_ID = pad_id,
      Next_Pad_ID = next_pad_id,
      Pad_Num = p,
      Filter_ID = filter_id,
      FX_Num = fx_num,
      Pad_GUID = r.TrackFX_GetFXGUID(track, pad_id),
      TblIdx = rv + 1,
      Note_Num = rv,
      Out_Low32L = out_low32l,
      Out_Low32R = out_low32r,
      Out_High32L = out_high32l,
      Out_High32R = out_high32r,
      Out_N_Low32L = out_n_low32l,
      Out_N_Low32R = out_n_low32r,
      Out_N_High32L = out_n_high32l,
      Out_N_High32R = out_n_high32r,
      RS5k_Instances = {},
      Sample_Name = {}
    }
    rev, value = r.GetProjExtState(0, 'ReaDrum Machine', 'Rename' .. rv + 1)
    if rev == 1 then
      Pad[rv + 1].Rename = value
    end
    CountPadFX(p) -- Set Pad[a].Name
    local found = false
    for f = 1, padfx_idx do
      if f == 1 then
        found_RS5k = 0
      end
      local _, find_rs5k = r.TrackFX_GetNamedConfigParm(track, pad_id, "container_item." .. f - 1) -- 0 based
      local _, buf = r.TrackFX_GetNamedConfigParm(track, find_rs5k, 'fx_ident')
      if buf:find("1920167789") then
        Pad[rv + 1].RS5k_ID = find_rs5k
        found_RS5k = found_RS5k + 1
        Pad[rv + 1].RS5k_Instances[found_RS5k] = find_rs5k
        found = true
        local _, bf = r.TrackFX_GetNamedConfigParm(track, find_rs5k, 'FILE0')  
        local filename = bf:match("([^\\/]+)%.%w%w*$")
        Pad[rv + 1].Sample_Name[found_RS5k] = filename
        Pad[rv + 1].Name = filename
        if Pad[rv + 1].Rename then
          r.SetTrackMIDINoteNameEx(0, track, rv, -1, Pad[rv + 1].Rename)
        elseif Pad[rv + 1].Name then
          r.SetTrackMIDINoteNameEx(0, track, rv, -1, Pad[rv + 1].Name)
        else
          r.SetTrackMIDINoteNameEx(0, track, rv, -1, "")
        end
      end
      if not found then
        Pad[rv + 1].Name = nil
        r.SetTrackMIDINoteNameEx(0, track, rv, -1, "")
      end
    end
  end
end
  
function IterateContainerUpdate(depth, track, container_id, parent_fx_count, previous_diff, container_guid)
    local c_ok, c_fx_count = r.TrackFX_GetNamedConfigParm(track, 0x2000000 + container_id, "container_count")
    if not c_ok then return end
    local diff = depth == 0 and parent_fx_count + 1 or (parent_fx_count + 1) * previous_diff
    local child_guids = {}
  
    for i = 1, c_fx_count do
      local fx_id = container_id + diff * i
      local fx_guid = r.TrackFX_GetFXGUID(TRACK, 0x2000000 + fx_id)
      local _, fx_type = r.TrackFX_GetNamedConfigParm(track, 0x2000000 + fx_id, "fx_type")
  
      FX_DATA[fx_guid] = {
        type = fx_type,
        IDX = i,
        pid = container_guid,
        guid = fx_guid,
      }
      child_guids[#child_guids + 1] = { guid = fx_guid }
      if fx_type == "Container" then
        FX_DATA[fx_guid].depth = depth + 1
        FX_DATA[fx_guid].DIFF = diff * (c_fx_count + 1)
        IterateContainerUpdate(depth + 1, track, fx_id, c_fx_count, diff, fx_guid)
        FX_DATA[fx_guid].ID = fx_id
      end
    end
    return child_guids
end
  
function UpdateFxData()
  if not TRACK then return end
    FX_DATA = {}
    FX_DATA = {
      ["ROOT"] = {
        type = "ROOT",
        pid = "ROOT",
        guid = "ROOT",
      }
    }
    local row = 1
    local total_fx_count = r.TrackFX_GetCount(TRACK)
    for i = 1, total_fx_count do
      local _, fx_type = r.TrackFX_GetNamedConfigParm(TRACK, i - 1, "fx_type")
      local fx_guid = r.TrackFX_GetFXGUID(TRACK, i - 1)
  
      FX_DATA[fx_guid] = {
        type = fx_type,
        IDX = i,
        pid = "ROOT",
        guid = fx_guid,
      }
    if fx_type == "Container" then
        FX_DATA[fx_guid].depth = 0
        FX_DATA[fx_guid].DIFF = (total_fx_count + 1)
        FX_DATA[fx_guid].ID = i
        IterateContainerUpdate(0, TRACK, i, total_fx_count, 0, fx_guid)
    end
  end
  UpdatePadID()
end