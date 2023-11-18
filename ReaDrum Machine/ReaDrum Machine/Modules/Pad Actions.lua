--@noindex
--NoIndex: true

r = reaper

-- Left Click --
function SendMidiNote(notenum) -- Thanks Sexan!
    if not r.ImGui_IsItemHovered(ctx) then return end
    if r.ImGui_IsMouseClicked(ctx, 0) then
      r.StuffMIDIMessage(0, 0x90, notenum, 96) -- send note_p -- mode, note on, note, velocity
    elseif r.ImGui_IsMouseReleased(ctx, 0) then
      r.StuffMIDIMessage(0, 0x80, notenum, 96) -- send note_r
    end
  end
 
  
local function AdjustPadVolume(a)
    if not r.ImGui_IsItemHovered(ctx) then return end
    if r.ImGui_IsMouseDragging(ctx, 0) then
      if Pad[a] then
        local wet = r.TrackFX_GetParamFromIdent(track, Pad[a].Pad_ID, ":wet")
        local volume = r.TrackFX_GetParam(track, Pad[a].Pad_ID, wet)
        r.TrackFX_SetParam(track, Pad[a].Pad_ID, volume, v / 100)
      end
    end
  end
  

function ClearPad(a, pad_num)
    clear_pad = get_fx_id_from_container_path(track, parent_id, pad_num) -- remove whole pad
    r.SetTrackMIDINoteNameEx(0, track, notenum, 0, "")                   -- remove note name
    r.TrackFX_Delete(track, clear_pad)
    Pad[a] = nil
  end

function ClickPadActions(a)
    -- if not r.ImGui_IsItemHovered(ctx) then return end
    if Pad[a] then
        if ALT then
          r.Undo_BeginBlock()
          r.PreventUIRefresh(1)
          ClearPad(a, Pad[a].Pad_Num)
          rev, value = r.GetProjExtState(0, 'ReaDrum Machine', 'Rename' .. a)
          if rev == 1 then
          r.SetProjExtState(0, 'ReaDrum Machine', 'Rename' .. a, "")
          end
          UpdatePadID()
          r.PreventUIRefresh(-1)
          EndUndoBlock("CLEAR PAD")
        else
          r.Undo_BeginBlock()
          r.PreventUIRefresh(1)
          local open =  r.TrackFX_GetOpen(track, Pad[a].Pad_ID) -- 0 based
          r.TrackFX_Show(track, Pad[a].Pad_ID, open and 2 or 3)           -- show/hide floating window   
          r.PreventUIRefresh(-1)
          EndUndoBlock("OPEN FX WINDOW")
        end
    end
  end
  
-- right click --
local function SetLowChannel(e)
    local left = (e - 1) * 2
    local right = left + 1 
    left_low = 2^left
    left_high = 0
    right_low = 2^right
    right_high = 0
  end
  
  local function SetHighChannel(e)
    local left = (e - 1) * 2
    local right = left + 1 
    left_low = 0
    left_high = 2^left
    right_low = 0
    right_high = 2^right
  end
  
  local function ExplodePadsToTracks()
    CountPads()
    r.SetMediaTrackInfo_Value(track, 'I_NCHAN', 128)
    local drum_id = get_fx_id_from_container_path(track, parent_id)
    r.TrackFX_SetNamedConfigParm(track, drum_id, 'container_nch', 128)
    r.TrackFX_SetNamedConfigParm(track, drum_id, 'container_nch_out', 128)
    local drum_track = track
    local track_id = r.CSurf_TrackToID(track, false)
    r.Main_OnCommand(40001, 0)
    for e = 1, pads_idx do
      if e > 64 then last_child = r.CSurf_TrackFromID(track_id + 1 + e, false) break end
      local pad_id = get_fx_id_from_container_path(track, parent_id, e)
      r.Main_OnCommand(40001, 0)
      local retval, pad_name = r.TrackFX_GetNamedConfigParm(drum_track, pad_id, 'renamed_name')
      local child = r.CSurf_TrackFromID(track_id + 1 + e, false)
      r.GetSetMediaTrackInfo_String(child, 'P_NAME', pad_name, true) -- change child track's name to pad name
      local send = r.CreateTrackSend(drum_track, child)
      local channel_offset = (e - 1) * 2 -- even number
      local num_channels = 0 -- stereo
      local send_info = (num_channels << 9) | channel_offset
      r.SetTrackSendInfo_Value(drum_track, 0, send, 'I_SRCCHAN', send_info) -- set send channel
      if e <= 32 then
        l_pin_idx = 0 --left 
        r_pin_idx = 1 -- right
        if e <= 16 then -- use low for 1~16
          SetLowChannel(e)
        elseif e > 16 then -- use high for 17~32
          local e = e - 16
          SetHighChannel(e)
        end
      elseif e > 32 then
        l_pin_idx = 0 + 0x1000000 -- add 0x1000000 for 64~
        r_pin_idx = 1 + 0x1000000
        if e <= 48 then -- use low for 33~48
        local e = e - 32
        SetLowChannel(e)
        elseif e > 48 then -- use high for 49~64
        local e = e - 48
        SetHighChannel(e)
        end
      end
      r.TrackFX_SetPinMappings(track, pad_id, 1, l_pin_idx, left_low, left_high) -- left
      r.TrackFX_SetPinMappings(track, pad_id, 1, r_pin_idx, right_low, right_high) -- right
      last_child = r.CSurf_TrackFromID(track_id + 1 + pads_idx, false)
    end
    local bus_track = r.CSurf_TrackFromID(track_id + 1, false)
    r.SetMediaTrackInfo_Value(bus_track, 'I_FOLDERDEPTH', 1) -- parent folder
    r.GetSetMediaTrackInfo_String(bus_track, 'P_NAME', "ReaDrum Bus", true)
    r.SetMediaTrackInfo_Value(last_child, 'I_FOLDERDEPTH', -1) -- last child track
    r.SetMediaTrackInfo_Value(bus_track, 'I_FOLDERCOMPACT', 1) -- collapse folder
    r.SetMediaTrackInfo_Value(drum_track, 'I_SELECTED', 1) -- select drum track
    r.SetMediaTrackInfo_Value(drum_track, 'B_MAINSEND', 0) -- turn off master send
  end
  
  local function RenameWindow(a, note_name)
    local center = { r.ImGui_Viewport_GetCenter(r.ImGui_GetWindowViewport(ctx)) }
    r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
    if r.ImGui_BeginPopupModal(ctx, 'Rename a pad?##' .. a, nil, r.ImGui_WindowFlags_AlwaysAutoResize()) then
      if r.ImGui_IsWindowAppearing(ctx) then
        r.ImGui_SetKeyboardFocusHere(ctx)
      end
      rv, new_name = r.ImGui_InputTextWithHint(ctx, '##Pad Name', 'PAD NAME', new_name,
        r.ImGui_InputTextFlags_AutoSelectAll())
      IsInputEdited = r.ImGui_IsItemActive(ctx)
      if r.ImGui_Button(ctx, 'OK', 120, 0) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) or
          r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_KeypadEnter()) then
        if not Pad[a] then
          r.ShowConsoleMsg("There's no pad. Insert FX or sample first.")
        elseif Pad[a] then
          r.Undo_BeginBlock()
          r.PreventUIRefresh(1)
          if #new_name ~= 0 then renamed_name = note_name .. ": " .. new_name else renamed_name = note_name end
          if renamed_name then
          r.TrackFX_SetNamedConfigParm(track, Pad[a].Pad_ID, "renamed_name", renamed_name)
          r.SetTrackMIDINoteNameEx(0, track, notenum, 0, new_name)
          Pad[a].Rename = new_name
          r.SetProjExtState(0, 'ReaDrum Machine', 'Rename' .. a, new_name)
          end
          r.PreventUIRefresh(-1)
          EndUndoBlock("RENAME PAD") 
        end
        r.ImGui_CloseCurrentPopup(ctx)
      end
      r.ImGui_SetItemDefaultFocus(ctx)
      r.ImGui_SameLine(ctx)
      if r.ImGui_Button(ctx, 'Cancel', 120, 0) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
        r.ImGui_CloseCurrentPopup(ctx)
      end
      r.ImGui_EndPopup(ctx)
    end
  end

  local function AddSampleFromArrange(pad_num, add_pos, a, filenamebuf, start_offset, end_offset)
    rs5k_id = get_fx_id_from_container_path(track, parent_id, pad_num, add_pos)
    r.TrackFX_AddByName(track, 'ReaSamplomatic5000', false, rs5k_id)
    Pad[a].RS5k_ID = rs5k_id
    r.TrackFX_Show(track, rs5k_id, 2)
    r.TrackFX_SetNamedConfigParm(track, rs5k_id, 'MODE', 1)             -- Sample mode
    r.TrackFX_SetNamedConfigParm(track, rs5k_id, '-FILE*', '')
    r.TrackFX_SetNamedConfigParm(track, rs5k_id, 'FILE', filenamebuf) -- add file
    r.TrackFX_SetNamedConfigParm(track, rs5k_id, 'DONE', '')            -- always necessary
    --r.TrackFX_SetParam(track, rs5k_id, 11, 1)                           -- obey note offs
    r.TrackFX_SetParam(track, rs5k_id, 13, start_offset)                -- Sample start offset
    r.TrackFX_SetParam(track, rs5k_id, 14, end_offset)                  -- Sample end offset
    -- r.TrackFX_SetParam(track, rs5k_id, 15, take_pitch)                  -- Pitch offset
  end
  
   function LoadItemsFromArrange(a)
    InsertDrumMachine()
    GetDrumMachineIdx()                                              -- parent_id = num
    r.Undo_BeginBlock()
    r.PreventUIRefresh(1)
    for c = 1, r.CountSelectedMediaItems(0) do                       -- 1 based
      local item = r.GetSelectedMediaItem(0, c - 1)                  -- 0 based
      local take = r.GetActiveTake(item)
      local item_length = r.GetMediaItemInfo_Value(item, 'D_LENGTH') -- double
      d = 0
      if not take or r.TakeIsMIDI(take) then
        d = d + 1
        goto NEXT
      end
      local take_src = r.GetMediaItemTake_Source(take)
      local start_offs = r.GetMediaItemTakeInfo_Value(take, 'D_STARTOFFS')
      local take_pitch = r.GetMediaItemTakeInfo_Value(take, 'D_PITCH') 
      local take_playrate = r.GetMediaItemTakeInfo_Value(take, 'D_PLAYRATE')
      local take_pan = r.GetMediaItemTakeInfo_Value(take, 'D_PAN')
      local src_length = r.GetMediaSourceLength(take_src)
      local filenamebuf = r.GetMediaSourceFileName(take_src, '')
      local start_offset = start_offs / src_length
      local end_offset = (start_offs + item_length) / src_length
      if not Pad[a + c - 1 - d] then
        CountPads()                                             -- pads_idx = num
        AddPad(getNoteName(notenum + c - 1 - d), a + c - 1 - d) -- pad_id = loc, pad_num = num
        previous_pad_id = get_fx_id_from_container_path(track, parent_id, pad_num - 1)
        next_pad_id = get_fx_id_from_container_path(track, parent_id, pad_num + 1)
        Pad[a + c - 1 - d] = {
          Previous_Pad_ID = previous_pad_id,
          Pad_ID = pad_id,
          Next_Pad_ID = next_pad_id,
          Pad_Num = pad_num,
          TblIdx = a + c - 1 - d,
          Note_Num = a + c - 1 - d
        }
        AddNoteFilter(notenum + c - 1 - d, pad_num)
        AddSampleFromArrange(Pad[a + c - 1 - d].Pad_Num, 2, a + c - 1 - d, filenamebuf, start_offset, end_offset)
      elseif Pad[a + c - 1 - d].Pad_Num then
        CountPadFX(Pad[a + c - 1 - d].Pad_Num) -- padfx_idx = num
        local found = false
        for rs5k_pos = 1, padfx_idx do
          find_rs5k = get_fx_id_from_container_path(track, parent_id, Pad[a + c - 1 - d].Pad_Num, rs5k_pos)
          retval, buf = r.TrackFX_GetNamedConfigParm(track, find_rs5k, 'original_name')
          if buf == "VSTi: ReaSamplOmatic5000 (Cockos)" then
            found = true
            r.TrackFX_SetNamedConfigParm(track, find_rs5k, 'FILE0', filenamebuf)   -- change file
            r.TrackFX_SetNamedConfigParm(track, find_rs5k, 'DONE', '')
            --r.TrackFX_SetParam(track, find_rs5k, 11, 1)                            -- obey note offs
            r.TrackFX_SetParam(track, find_rs5k, 13, start_offset)                 -- Sample start offset
            r.TrackFX_SetParam(track, find_rs5k, 14, end_offset)                   -- Sample end offset
          end
        end
        if not found then
          AddSampleFromArrange(Pad[a + c - 1 - d].Pad_Num, padfx_idx + 1, a + c - 1 - d, filenamebuf, start_offset,
            end_offset)
        end
      end
      r.SetTrackMIDINoteNameEx(0, track, notenum + c - 1 - d, 0, 'test' .. notenum + c - 1 - d) -- rename in ME
      ::NEXT::
    end
    r.PreventUIRefresh(-1)
    EndUndoBlock("LOAD ITEMS FROM ARRANGE")
  end

   function PadMenu(a, note_name)
    if r.ImGui_IsItemClicked(ctx, 1) and CTRL then
      r.ImGui_OpenPopup(ctx, "RIGHT_CLICK_MENU##" .. a)
    end
    local open_settings = false
    if r.ImGui_BeginPopup(ctx, "RIGHT_CLICK_MENU##" .. a, r.ImGui_WindowFlags_NoMove()) then
      if r.ImGui_MenuItem(ctx, 'Load Selected Items from Arrange##' .. a) then
        LoadItemsFromArrange(a)
      end
      if r.ImGui_MenuItem(ctx, 'Rename Pad##' .. a) then
        open_settings = true
      end
      if r.ImGui_MenuItem(ctx, 'Toggle Obey note offs##' .. a) then
        if Pad[a] and Pad[a].RS5k_ID then
          rv = r.TrackFX_GetParam(track, Pad[a].RS5k_ID, 11)
          if rv == 0 then
            r.TrackFX_SetParam(track, Pad[a].RS5k_ID, 11, 1) -- obey note offs on
          else
            r.TrackFX_SetParam(track, Pad[a].RS5k_ID, 11, 0)
          end
        end
      end
      if r.ImGui_MenuItem(ctx, 'Toggle Loop##' .. a) then
        if Pad[a] and Pad[a].RS5k_ID then
          rv = r.TrackFX_GetParam(track, Pad[a].RS5k_ID, 12)
          if rv == 0 then
            no = r.TrackFX_GetParam(track, Pad[a].RS5k_ID, 11)
            if no == 0 then
            r.TrackFX_SetParam(track, Pad[a].RS5k_ID, 11, 1) -- obey note offs on
            end
            r.TrackFX_SetParam(track, Pad[a].RS5k_ID, 12, 1) -- Loop on
          else
            r.TrackFX_SetParam(track, Pad[a].RS5k_ID, 12, 0)
          end
        end
      end
      r.ImGui_Separator(ctx)
      if r.ImGui_MenuItem(ctx, 'Explode All Pads to Tracks##' .. a) then
      r.Undo_BeginBlock()
      r.PreventUIRefresh(1)
      ExplodePadsToTracks()
      r.PreventUIRefresh(-1)
      EndUndoBlock("EXPLODE ALL PADS") 
      end
      if r.ImGui_MenuItem(ctx, 'Clear All Pads##' .. a) then
        GetDrumMachineIdx()
        CountPads()                                                          -- pads_idx = num
        r.Undo_BeginBlock()
        r.PreventUIRefresh(1)
        for i = 1, pads_idx do
          local clear_pad = get_fx_id_from_container_path(track, parent_id, 1) -- remove whole pad
          r.TrackFX_Delete(track, clear_pad)
        end
        Pad = {}
        r.SetProjExtState(0, 'ReaDrum Machine', "", "")
        local IsMidiOpen = r.MIDIEditor_LastFocused_OnCommand(40412, false)
        if not IsMidiOpen then
          r.Main_OnCommand(40716, 0)
          r.MIDIEditor_OnCommand(r.MIDIEditor_GetActive(), 40412)
          r.Main_OnCommand(40716, 0)
        else
          r.MIDIEditor_OnCommand(r.MIDIEditor_GetActive(), 40412)
        end
        r.PreventUIRefresh(-1)
        EndUndoBlock("CLEAR ALL PADS") 
      end
      -- if r.ImGui_BeginMenu(ctx, 'Context menu') then
      --  r.ImGui_EndMenu(ctx)
      -- end
      r.ImGui_EndPopup(ctx)
    end
    if open_settings then
      r.ImGui_OpenPopup(ctx, 'Rename a pad?##' .. a)
    end
    RenameWindow(a, note_name)
  end
  
   function FXLIST()
    if r.ImGui_IsMouseClicked(ctx, 1) then
      if not r.ImGui_IsPopupOpen(ctx, "FX LIST") then
        r.ImGui_OpenPopup(ctx, "FX LIST")
      end
    end
  
    if r.ImGui_BeginPopup(ctx, "FX LIST") then
      Frame()
      r.ImGui_EndPopup(ctx)
    end
  end