--@noindex
--NoIndex: true

r = reaper


function SetButtonState(set) -- Set ToolBar Button State
  local is_new_value, filename, sec, cmd, mode, resolution, val = r.get_action_context()
  r.SetToggleCommandState(sec, cmd, set or 0)
  r.RefreshToolbar2(sec, cmd)
end

function Exit()
  SetButtonState()
end

function CheckKeys()
  ALT = r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Alt()
  CTRL = r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Shortcut()
  SHIFT = r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Shift()

  HOME = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Home())
  SPACE = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Space())
  ESC = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape())

  Z = r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Z())

  if HOME then CANVAS.off_x, CANVAS.off_y = 0, def_vertical_y_center end

  if CTRL and Z then
    r.Main_OnCommand(40029, 0)
    UpdatePadID()
    -- CHECK IF TRACK CHANGED
    TRACK = r.GetSelectedTrack2(0, 0, true)
  end                            -- UNDO
  if r.ImGui_GetKeyMods(ctx) == r.ImGui_Mod_Shortcut() | r.ImGui_Mod_Shift() and Z then
    r.Main_OnCommand(40030, 0)   -- REDO
  end

  if SPACE and (not FX_OPENED and not RENAME_OPENED and not FILE_MANAGER_OPENED) then r.Main_OnCommand(40044, 0) end -- PLAY STOP

  -- ACTIVATE CTRL ONLY IF NOT PREVIOUSLY DRAGGING
  if not CTRL_DRAG then
    CTRL_DRAG = (not MOUSE_DRAG and CTRL) and r.ImGui_IsMouseDragging(ctx, 0)
  end
  MOUSE_DRAG = r.ImGui_IsMouseDragging(ctx, 0)
end

function CheckStaleData()
  if r.ImGui_IsMouseReleased(ctx, 0) then
      CTRL_DRAG = nil
  --    DRAG_PREVIEW = nil
  end
  --if not PEAK_INTO_TOOLTIP then
  --    if PREVIEW_TOOLTIP then PREVIEW_TOOLTIP = nil end
  --end
end

function InsertDrumMachine()
    local found = false
    count = r.TrackFX_GetCount(track) -- 1 based
    for i = 0, count - 1 do
      local rv, rename = r.TrackFX_GetNamedConfigParm(track, i, 'renamed_name') -- 0 based
      if rename == 'ReaDrum Machine' then
        found = true
        break
      end
    end
    if not found then
      r.Undo_BeginBlock()
      r.PreventUIRefresh(1)
      r.TrackFX_AddByName(track, "Container", false, -1000 - count)                 -- 0 based + count(1 based) = the last slot
      r.TrackFX_SetNamedConfigParm(track, count, 'renamed_name', 'ReaDrum Machine') -- 0 based + count(1 based) = the last slot
      r.PreventUIRefresh(-1)
      EndUndoBlock("ADD DRUM MACHINE")
    end
  end
  
  function GetDrumMachineIdx()
    local found = false
    fxcount = r.TrackFX_GetCount(track)                                        -- 1based
    for fx_idx = 0, fxcount - 1 do
      rv, rename = r.TrackFX_GetNamedConfigParm(track, fx_idx, 'renamed_name') -- 0 based
      if rename == 'ReaDrum Machine' then
        parent_id = fx_idx
        found = true
        break
      end
      if not found then
        parent_id = nil
      end
    end
    if parent_id ~= nil then
    parent_id = parent_id + 1 -- 1 based
    end
    return parent_id
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
    if DrumMachinePath then -- if Drum Machine is nested
      new_vararg = {}
     for i = 1,#DrumMachinePath do
      new_vararg[i] = DrumMachinePath[i]
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
  
  function AddPad(note_name, a) -- pad_id, pad_num
    if pads_idx == 0 then       -- no pads
      pad_num = 1
      pad_id = get_fx_id_from_container_path(track, parent_id, pad_num)
    else                                                                -- pads exist
      pad_num = pads_idx + 1
      pad_id = get_fx_id_from_container_path(track, parent_id, pad_num) -- the last slot after pads
    end
    r.TrackFX_AddByName(track, 'Container', false, -1000 - pad_id)      -- Add a pad
    r.TrackFX_SetNamedConfigParm(track, pad_id, 'renamed_name', note_name)
    r.TrackFX_SetNamedConfigParm(track, pad_id, 'parallel', 1)          -- set parallel
    local previous_pad_id = get_fx_id_from_container_path(track, parent_id, pad_num - 1)
    local next_pad_id = get_fx_id_from_container_path(track, parent_id, pad_num + 1)
    Pad[a] = {
      Previous_Pad_ID = previous_pad_id,
      Pad_ID = pad_id,
      Next_Pad_ID = next_pad_id,
      Pad_Num = pad_num,
      Pad_GUID = r.TrackFX_GetFXGUID(track, pad_id),
      TblIdx = a,
      Note_Num = notenum
    }
    return pad_id, pad_num
  end
  
  function CountPads()                                                                   -- pads_idx
    GetDrumMachineIdx()
    if parent_id == nil then return end
    rv, pads_idx = r.TrackFX_GetNamedConfigParm(track, parent_id - 1, 'container_count') -- 0 based
    pads_idx = tonumber(pads_idx)
    return pads_idx
  end
  
  function GetPadGUID()
    CountPads()
    for p = 1, pads_idx do
      pad_id   = get_fx_id_from_container_path(track, parent_id, p)
      pad_guid = r.TrackFX_GetFXGUID(track, pad_id)
    end
  end
  
  function CountPadFX(pad_num)                                                        -- padfx_idx
    which_pad = get_fx_id_from_container_path(track, parent_id, pad_num)
    rv, padfx_idx = r.TrackFX_GetNamedConfigParm(track, which_pad, 'container_count') -- 0 based
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
    if padfx_idx ~= 0 then
      for f = 1, padfx_idx do      
        local find_filter = get_fx_id_from_container_path(track, parent_id, pad_num, f)
        retval, buf = r.TrackFX_GetNamedConfigParm(track, find_filter, 'fx_ident')
        if r.GetOS() == 'Win32' or r.GetOS() == 'Win64' then
          buf = buf:gsub("Suzuki Scripts\\ReaDrum Machine\\JSFX\\", "")
        else
          buf = buf:gsub("Suzuki Scripts/ReaDrum Machine/JSFX/", "")
        end
        if buf == "RDM_midi_note_filter.jsfx" then
        fi = f
        break
        end
      end
    end
    return fi
  end
  
  function UpdatePadID()
    if not track then return end
    Pad = {}
    GetDrumMachineIdx()
    if not parent_id then return end
    CountPads()
    if pads_idx == nil then return end
    for p = 1, pads_idx do
      FindNoteFilter(p)
      local filter_id = get_fx_id_from_container_path(track, parent_id, p, fi)
      local rv = r.TrackFX_GetParam(track, filter_id, 0)
      local rv = math.floor(tonumber(rv))
      local previous_pad_id = get_fx_id_from_container_path(track, parent_id, p - 1)
      local next_pad_id = get_fx_id_from_container_path(track, parent_id, p + 1)
      local pad_id = get_fx_id_from_container_path(track, parent_id, p)
      Pad[rv + 1] = {
        Previous_Pad_ID = previous_pad_id,
        Pad_ID = pad_id,
        Next_Pad_ID = next_pad_id,
        Pad_Num = p,
        Pad_GUID = r.TrackFX_GetFXGUID(track, pad_id),
        TblIdx = rv + 1,
        Note_Num = rv
      }
      rev, value = r.GetProjExtState(0, 'ReaDrum Machine', 'Rename' .. rv + 1)
      if rev == 1 then
      Pad[rv + 1].Rename = value
      end
      CountPadFX(p) -- Set Pad[a].Name
      local found = false
      for f = 1, padfx_idx do
        local find_rs5k = get_fx_id_from_container_path(track, parent_id, p, f)
        retval, buf = r.TrackFX_GetNamedConfigParm(track, find_rs5k, 'original_name')
        if buf == "VSTi: ReaSamplOmatic5000 (Cockos)" then
          Pad[rv + 1].RS5k_ID = get_fx_id_from_container_path(track, parent_id, p, f)
          found = true
          _, bf = r.TrackFX_GetNamedConfigParm(track, find_rs5k, 'FILE0')  
          filename = bf:match("([^\\/]+)%.%w%w*$")
          Pad[rv + 1].Name = filename
          if Pad[rv + 1].Rename then
            r.SetTrackMIDINoteNameEx(0, track, rv, 0, Pad[rv + 1].Rename)
          elseif Pad[rv + 1].Name then
            r.SetTrackMIDINoteNameEx(0, track, rv, 0, Pad[rv + 1].Name)
          else
            r.SetTrackMIDINoteNameEx(0, track, rv, 0, "")
          end
        end
        if not found then
          Pad[rv + 1].Name = nil
          r.SetTrackMIDINoteNameEx(0, track, rv, 0, "")
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