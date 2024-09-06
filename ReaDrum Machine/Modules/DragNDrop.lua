--@noindex

local function GetPayload()
  local retval, dndtype, payload = im.GetDragDropPayload(ctx)
  if retval then
    return dndtype, payload
  end
end
  
function CheckDNDType()
  local dnd_type = GetPayload()
  DND_ADD_FX = dnd_type == "DND ADD FX"
  DND_MOVE_FX = dnd_type == "DND MOVE FX"
  -- DND_ADD_SAMPLE = dnd_type == "DND ADD SAMPLE"
  -- DND_MOVE_SAMPLE = dnd_type == "DND MOVE SAMPLE"
  FX_DRAG = dnd_type == "FX_Drag" -- For FX Devices
end

function AddNoteFilter(notenum, pad_num)
  local retval, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. pad_num - 1) -- 0 based
  local filter_id = ConvertPathToNestedPath(pad_id, 1)
  local filter_id = tonumber(filter_id)
  r.TrackFX_AddByName(track, 'JS: RDM MIDI Utility', false, filter_id)
  r.TrackFX_Show(track, filter_id, 2)
  r.TrackFX_SetParam(track, filter_id, 0, notenum)                        -- key for filter, pad number = midi note
end

function DndAddFX_SRC(fx)
  if im.BeginDragDropSource(ctx, im.DragDropFlags_AcceptBeforeDelivery) then
    im.SetDragDropPayload(ctx, 'DND ADD FX', fx)
    im.Text(ctx, fx)
    im.EndDragDropSource(ctx)
  end
end

function DndMoveFX_SRC(a)
  -- if CTRL then return end
  if Pad[a] then
    if im.BeginDragDropSource(ctx, im.DragDropFlags_AcceptBeforeDelivery | im.DragDropFlags_SourceNoPreviewTooltip) then
      local data = Pad[a].TblIdx
      im.SetDragDropPayload(ctx, 'DND MOVE FX', data)
      -- Display preview (could be anything, e.g. when dragging an image we could decide to display
      -- the filename and a small preview of the image, etc.)
      -- CreateCustomPreviewData(tbl,i)
      -- im.Text(ctx, Pad[a].Note_Num)
      im.EndDragDropSource(ctx)
    end
  end
end
  
function DndMoveFX_TARGET_SWAP(a) -- Swap whole pads  -> modulation is kept
  if not DND_MOVE_FX then return end
  im.PushStyleColor(ctx, im.Col_DragDropTarget, 0)
  if im.BeginDragDropTarget(ctx) then
    local ret, payload = im.AcceptDragDropPayload(ctx, 'DND MOVE FX')
    im.EndDragDropTarget(ctx)
    r.Undo_BeginBlock()
    r.PreventUIRefresh(1)
    GetDrumMachineIdx(track)
    if ret then
      local is_move = (not CTRL_DRAG) and true or false
      if is_move then    -- move
        if Pad[a] then   -- swap
          local b = payload
          local b = tonumber(b)
          local src_pad = Pad[b].Pad_ID
          local src_num = Pad[b].Pad_Num
          local src_note = Pad[b].Note_Num
          local out_low32l = Pad[b].Out_Low32L
          local out_low32r = Pad[b].Out_Low32R
          local out_high32l = Pad[b].Out_High32L
          local out_high32r = Pad[b].Out_High32R
          local out_n_low32l = Pad[b].Out_N_Low32L
          local out_n_low32r = Pad[b].Out_N_Low32R
          local out_n_high32l = Pad[b].Out_N_High32L
          local out_n_high32r = Pad[b].Out_N_High32R
          local dst_pad = Pad[a].Pad_ID
          local dst_num = Pad[a].Pad_Num
          local dst_name = Pad[a].Name
          local dst_rename = Pad[a].Rename
          -- dst_guid = Pad[a].Pad_GUID
          srcfx_idx = CountPadFX(src_num)
          dstfx_idx = CountPadFX(dst_num)
          if Pad[b].Rename then 
            src_renamed_name = getNoteName(notenum) .. ": " .. Pad[b].Rename
            r.SetProjExtState(0, 'ReaDrum Machine', 'Rename' .. a, Pad[b].Rename)
            r.SetProjExtState(0, 'ReaDrum Machine', 'Rename' .. b, "")
          elseif Pad[b].Name then 
            src_renamed_name = getNoteName(notenum) .. ": " .. Pad[b].Name
          else 
            src_renamed_name = getNoteName(notenum) 
          end
          r.TrackFX_SetNamedConfigParm(track, src_pad, "renamed_name", src_renamed_name)
          if Pad[a].Rename then 
            dst_renamed_name = getNoteName(src_note) .. ": " .. Pad[a].Rename
            r.SetProjExtState(0, 'ReaDrum Machine', 'Rename' .. b, Pad[a].Rename)
            r.SetProjExtState(0, 'ReaDrum Machine', 'Rename' .. a, "")
          elseif Pad[a].Name then 
            dst_renamed_name = getNoteName(src_note) .. ": " .. Pad[a].Name
          else 
            dst_renamed_name = getNoteName(src_note)
          end
          r.TrackFX_SetNamedConfigParm(track, Pad[a].Pad_ID, "renamed_name", dst_renamed_name)
          r.TrackFX_CopyToTrack(track, src_pad, track, dst_pad, true) -- true = move
          local src_num = tonumber(src_num)
          if dst_num > src_num then
            _, dst_pad_new = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. dst_num - 2) -- 0 based
          end
          if src_num > dst_num then
            _, dst_pad_new = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. dst_num) -- 0 based
          end
          r.TrackFX_CopyToTrack(track, dst_pad_new, track, src_pad, true)
          FindNoteFilter(dst_num)
          local _, dst_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. dst_num - 1) -- 0 based
          local _, src_filter = r.TrackFX_GetNamedConfigParm(track, dst_id, "container_item." .. fi - 1) -- 0 based
          r.TrackFX_SetParam(track, src_filter, 0, notenum)  -- lowest key for filter, pad number = midi note drag
          --r.TrackFX_SetParam(track, src_filter, 1, notenum)  -- highest key for filter
          FindNoteFilter(src_num)
          local _, src_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. src_num - 1) -- 0 based
          local _, dst_filter = r.TrackFX_GetNamedConfigParm(track, src_id, "container_item." .. fi - 1) -- 0 based
          r.TrackFX_SetParam(track, dst_filter, 0, src_note) -- lowest key for filter, pad number = midi note drop
          --r.TrackFX_SetParam(track, dst_filter, 1, src_note) -- highest key for filter
          -- SwapRS5kNoteRange(srcfx_idx, dst_num, notenum)
          -- SwapRS5kNoteRange(dstfx_idx, src_num, src_note)
          r.TrackFX_SetPinMappings(track, Pad[b].Pad_ID, 1, 0, Pad[a].Out_Low32L, Pad[a].Out_High32L) -- #3 output 1, #4 pin 0 left
          r.TrackFX_SetPinMappings(track, Pad[b].Pad_ID, 1, 1, Pad[a].Out_Low32R, Pad[a].Out_High32R) -- #4 pin 1 right
          r.TrackFX_SetPinMappings(track, Pad[b].Pad_ID, 1, 0 + 0x1000000, Pad[a].Out_N_Low32L, Pad[a].Out_N_High32L) -- #3 output 1, #4 pin 0 left and add 0x1000000 to #4 for the second half blocks
          r.TrackFX_SetPinMappings(track, Pad[b].Pad_ID, 1, 1 + 0x1000000, Pad[a].Out_N_Low32R, Pad[a].Out_N_High32R) -- #4 pin 1 right
          r.TrackFX_SetPinMappings(track, Pad[a].Pad_ID, 1, 0, out_low32l, out_high32l) -- #3 output 1, #4 pin 0 left
          r.TrackFX_SetPinMappings(track, Pad[a].Pad_ID, 1, 1, out_low32r, out_high32r) -- #4 pin 1 right
          r.TrackFX_SetPinMappings(track, Pad[a].Pad_ID, 1, 0 + 0x1000000, out_n_low32l, out_n_high32l) -- #3 output 1, #4 pin 0 left and add 0x1000000 to #4 for the second half blocks
          r.TrackFX_SetPinMappings(track, Pad[a].Pad_ID, 1, 1 + 0x1000000, out_n_low32r, out_n_high32r) -- #4 pin 1 right
          UpdatePadID()
          r.PreventUIRefresh(-1)
          EndUndoBlock("SWAP/EXCHANGE PAD FX")          
        elseif not Pad[a] then   -- move
          local b = payload
          local b = tonumber(b)
          local src_num = Pad[b].Pad_Num
          CountPads()
          AddPad(note_name, a) -- dst
          src_note = Pad[b].Note_Num
          Pad[a].Name = Pad[b].Name
          r.TrackFX_SetPinMappings(track, Pad[a].Pad_ID, 1, 0, Pad[b].Out_Low32L, Pad[b].Out_High32L) -- #3 output 1, #4 pin 0 left
          r.TrackFX_SetPinMappings(track, Pad[a].Pad_ID, 1, 1, Pad[b].Out_Low32R, Pad[b].Out_High32R) -- #4 pin 1 right
          r.TrackFX_SetPinMappings(track, Pad[a].Pad_ID, 1, 0 + 0x1000000, Pad[b].Out_N_Low32L, Pad[b].Out_N_High32L) -- #3 output 1, #4 pin 0 left and add 0x1000000 to #4 for the second half blocks
          r.TrackFX_SetPinMappings(track, Pad[a].Pad_ID, 1, 1 + 0x1000000, Pad[b].Out_N_Low32R, Pad[b].Out_N_High32R) -- #4 pin 1 right
          if Pad[b].Rename then
            Pad[a].Rename = Pad[b].Rename
            r.SetProjExtState(0, 'ReaDrum Machine', 'Rename' .. a, Pad[b].Rename)
          end
          rev, value = r.GetProjExtState(0, 'ReaDrum Machine', 'Rename' .. b)
          if rev == 1 then
            r.SetProjExtState(0, 'ReaDrum Machine', 'Rename' .. b, "")
            Pad[b].Rename = nil
          end
          if Pad[a].Rename then 
            renamed_name = note_name .. ": " .. Pad[a].Rename
          elseif Pad[a].Name then 
            renamed_name = note_name .. ": " .. Pad[a].Name
          else 
            renamed_name = note_name 
          end
          r.TrackFX_SetNamedConfigParm(track, Pad[a].Pad_ID, "renamed_name", renamed_name)
          r.SetTrackMIDINoteNameEx(0, track, src_note, -1, "")
          local srcfx_idx = CountPadFX(src_num)
          local dstfx_pos = CountPadFX(Pad[a].Pad_Num)
          for m = 1, srcfx_idx do
            dstfx_pos = dstfx_pos + 1                                                             -- the last slot being offset by 1
            local _, src_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. src_num - 1) -- 0 based
            local _, srcfx = r.TrackFX_GetNamedConfigParm(track, src_id, "container_item." .. 0) -- 1st slot * srcfx_idx times
            local _, dst_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. Pad[a].Pad_Num - 1) -- 0 based
            local dst_last = ConvertPathToNestedPath(dst_id, dstfx_pos) -- add FX
            r.TrackFX_CopyToTrack(track, srcfx, track, dst_last, true)                            -- true = move
          end
          FindNoteFilter(Pad[a].Pad_Num)
          local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. Pad[a].Pad_Num - 1) -- 0 based
          local _, filter_id = r.TrackFX_GetNamedConfigParm(track, pad_id, "container_item." .. fi - 1)
          r.TrackFX_SetParam(track, filter_id, 0, notenum)                        -- lowest key for filter, pad number = midi note
          --r.TrackFX_SetParam(track, filter_id, 1, notenum)                        -- highest key for filter
          ClearPad(b, src_num) -- remove source pad
          UpdatePadID()
          r.PreventUIRefresh(-1)
          EndUndoBlock("MOVE PAD")
        end
      elseif not is_move then               -- copy
        if Pad[a] then   -- add fx to target
          local b = payload
          local b = tonumber(b)
          local src_num = Pad[b].Pad_Num
          local dst_pad = Pad[a].Pad_ID
          local dst_num = Pad[a].Pad_Num
          -- dst_guid = Pad[a].Pad_GUID
          local srcfx_idx = CountPadFX(src_num)
          local dstfx_idx = CountPadFX(dst_num)
          for c = 1, srcfx_idx do   -- skip filter
            FindNoteFilter(src_num)
            if c == fi then goto NEXT end
            dstfx_idx = dstfx_idx + 1 -- the last slot being offset by 1
            local _, src_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. src_num - 1) -- 0 based
            local _, srcfx = r.TrackFX_GetNamedConfigParm(track, src_id, "container_item." .. c - 1) -- 1st slot * srcfx_idx times
            local _, dst_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. dst_num - 1) -- 0 based
            local dst_last = ConvertPathToNestedPath(dst_id, dstfx_idx) -- add FX
            r.TrackFX_CopyToTrack(track, srcfx, track, dst_last, false) -- false = copy
            ::NEXT::
          end
          r.PreventUIRefresh(-1)
          EndUndoBlock("COPY PAD FX")
        elseif not Pad[a] and not is_move then   -- create target and add fx to it
          local b = payload
          local b = tonumber(b)
          local src_num = Pad[b].Pad_Num
          CountPads()
          AddPad(note_name, a) -- dst
          Pad[a].Name = Pad[b].Name  -- dst
          r.TrackFX_SetPinMappings(track, Pad[a].Pad_ID, 1, 0, Pad[b].Out_Low32L, Pad[b].Out_High32L) -- #3 output 1, #4 pin 0 left
          r.TrackFX_SetPinMappings(track, Pad[a].Pad_ID, 1, 1, Pad[b].Out_Low32R, Pad[b].Out_High32R) -- #4 pin 1 right
          r.TrackFX_SetPinMappings(track, Pad[a].Pad_ID, 1, 0 + 0x1000000, Pad[b].Out_N_Low32L, Pad[b].Out_N_High32L) -- #3 output 1, #4 pin 0 left and add 0x1000000 to #4 for the second half blocks
          r.TrackFX_SetPinMappings(track, Pad[a].Pad_ID, 1, 1 + 0x1000000, Pad[b].Out_N_Low32R, Pad[b].Out_N_High32R) -- #4 pin 1 right
          if Pad[b].Rename then 
            renamed_name = note_name .. ": " .. Pad[b].Rename
            Pad[a].Rename = Pad[b].Rename
            r.SetProjExtState(0, 'ReaDrum Machine', 'Rename' .. a, Pad[b].Rename)
          elseif Pad[b].Name then 
            renamed_name = note_name .. ": " .. Pad[b].Name
            Pad[a].Name = Pad[b].Name
          else 
            renamed_name = note_name 
          end
          r.TrackFX_SetNamedConfigParm(track, Pad[a].Pad_ID, "renamed_name", renamed_name)
          local srcfx_idx = CountPadFX(src_num)
          local dstfx_idx = CountPadFX(pad_num)
          for c = 1, srcfx_idx do    
            dstfx_idx = dstfx_idx + 1 -- the last slot being offset by 1
            local _, src_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. src_num - 1) -- 0 based
            local _, srcfx = r.TrackFX_GetNamedConfigParm(track, src_id, "container_item." .. c - 1) 
            local _, dst_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. pad_num - 1) -- 0 based
            local dst_last = ConvertPathToNestedPath(dst_id, dstfx_idx) -- add FX
            r.TrackFX_CopyToTrack(track, srcfx, track, dst_last, false) -- false = copy
          end
          FindNoteFilter(pad_num)
          local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. pad_num - 1) -- 0 based
          local _, filter_id = r.TrackFX_GetNamedConfigParm(track, pad_id, "container_item." .. fi - 1) 
          r.TrackFX_SetParam(track, filter_id, 0, notenum)
          --r.TrackFX_SetParam(track, filter_id, 1, notenum)
          r.PreventUIRefresh(-1)
          EndUndoBlock("COPY PAD")
        end
      end
    end
  end
  im.PopStyleColor(ctx)
end

function DndAddFX_TARGET(a)
  if not DND_ADD_FX then return end
  InsertDrumMachine()
  im.PushStyleColor(ctx, im.Col_DragDropTarget, 0)
  if im.BeginDragDropTarget(ctx) then
    local ret, payload = im.AcceptDragDropPayload(ctx, 'DND ADD FX')
    im.EndDragDropTarget(ctx)
    if ret and SELECTED then
      r.Undo_BeginBlock()
      for k, v in pairs(SELECTED) do
        UpdatePadID()
        local k = tonumber(k)       
        if Pad[k] then
          local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. Pad[k].Pad_Num - 1) -- 0 based
          local InsertFXPos = ConvertPathToNestedPath(pad_id, Pad[k].FX_Num + 1) -- 1 based
          r.TrackFX_AddByName(track, payload, false, InsertFXPos)
        else
          local notenum = k - 1
          local note_name = getNoteName(notenum)
          AddPad(note_name, k)     -- pad_id = loc, pad_num = num
          AddNoteFilter(notenum, Pad[k].Pad_Num)
          local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. Pad[k].Pad_Num - 1) -- 0 based
          local InsertFXPos = ConvertPathToNestedPath(pad_id, 2) -- 1 based
          r.TrackFX_AddByName(track, payload, false, InsertFXPos)
        end
      end
      EndUndoBlock("ADD FX") 
      SELECTED = nil
    else
      if ret and not Pad[a] then
        GetDrumMachineIdx(track)     -- parent_id = num
        CountPads()             -- pads_idx = num
        r.Undo_BeginBlock()
        r.PreventUIRefresh(1)
        AddPad(note_name, a)     -- pad_id = loc, pad_num = num
        CountPadFX(Pad[a].Pad_Num)                                                             -- padfx_idx = num
        AddNoteFilter(notenum, pad_num)
        local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. pad_num - 1) -- 0 based
        local padfx_id = ConvertPathToNestedPath(pad_id, padfx_idx + 2) -- 1 based
        r.TrackFX_AddByName(track, payload, false, padfx_id)
        r.PreventUIRefresh(-1)
        EndUndoBlock("ADD FX") 
      elseif ret and Pad[a].Pad_Num then
        GetDrumMachineIdx(track)   -- parent_id = num
        CountPadFX(Pad[a].Pad_Num)
        local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. Pad[a].Pad_Num - 1) -- 0 based
        local padfx_id = ConvertPathToNestedPath(pad_id, padfx_idx + 1) -- 1 based
        r.Undo_BeginBlock()
        r.PreventUIRefresh(1)
        r.TrackFX_AddByName(track, payload, false, padfx_id)
        r.PreventUIRefresh(-1)
        EndUndoBlock("ADD FX")
      end
    end
  end
  im.PopStyleColor(ctx)
end

local function MX_GetVolume(mx)
  local vol_hwnd = r.JS_Window_FindChildByID(mx, 1047) -- Use Spy++ in order to check Control ID
  local volume = r.JS_Window_GetTitle(vol_hwnd)
  return tonumber(volume:match('[^%a]+'))
end

local function MX_GetPitch(mx)
  local pitch_hwnd = r.JS_Window_FindChildByID(mx, 1021)
  local pitch = r.JS_Window_GetTitle(pitch_hwnd)
  return tonumber(pitch)
end

local function MX_GetRate(mx)
  local rate_hwnd = r.JS_Window_FindChildByID(mx, 1454)
  local rate = r.JS_Window_GetTitle(rate_hwnd)
  return tonumber(rate)
end

local function MX_ApplyRate(mx)
  r.SelectAllMediaItems(0, false)    -- unselect all
  local insert_sel = r.GetToggleCommandStateEx(32063, 40063) -- Options: Insert media on selected track
  if insert_sel ~= 1 then
    insert_new = true
    r.JS_WindowMessage_Send(mx, "WM_COMMAND", 40063, 0, 0, 0) -- Options: Insert media on selected track
  end
  r.JS_WindowMessage_Send(mx, "WM_COMMAND", 41010, 0, 0, 0) -- insert media loop disabled
  local selectedmedia_num = r.CountSelectedMediaItems(0)
  for c = 1, selectedmedia_num do -- storing info about which items are selected
    local item = r.GetSelectedMediaItem(0, c - 1)                  -- 0 based
    local item_guid = r.BR_GetMediaItemGUID(item)
    if not payload_num then
      payload_num = {}
    end
    payload_num[c] = item_guid
  end
  r.SelectAllMediaItems(0, false)    -- unselect all
  for c = 1, selectedmedia_num do -- glue and store a new source name one by one
    local item = r.BR_GetMediaItemByGUID(0, payload_num[c])
    r.SetMediaItemSelected(item, true)
    r.Main_OnCommand(41588, 0) -- glue
    local item = r.GetSelectedMediaItem(0, 0)                  -- 0 based
    local take = r.GetActiveTake(item)
    local take_src = r.GetMediaItemTake_Source(take)
    if not payload_name then
      payload_name = {}
    end
    payload_name[c] = r.GetMediaSourceFileName(take_src)
    r.DeleteTrackMediaItem(track, item)
  end
  if insert_new then
    r.JS_WindowMessage_Send(mx, "WM_COMMAND", 40054, 0, 0, 0) -- Options: Insert media on new track
    insert_new = false
  end
end

local function MX_GetTimeSelection() -- https://forum.cockos.com/showpost.php?p=2473651&postcount=1601
  local mx_title = r.JS_Localize('Media Explorer', 'common')
  local mx = r.JS_Window_Find(mx_title, true)
  if not mx then return false end

  -- Simulate mouse event on waveform to read out time selection
  local x, y = r.GetMousePosition()
  local wave_hwnd = r.JS_Window_FindChildByID(mx, 1046)
  local c_x, c_y = r.JS_Window_ScreenToClient(wave_hwnd, x, y)
  r.JS_WindowMessage_Send(wave_hwnd, 'WM_MOUSEFIRST', c_y, 0, c_x, 0)

  -- If a time selection exists, it will be shown in the wave info window
  local wave_info_hwnd = r.JS_Window_FindChildByID(mx, 1014)
  local wave_info = r.JS_Window_GetTitle(wave_info_hwnd)
  local pattern = ': ([^%s]+) .-: ([^%s]+)'
  local start_timecode, end_timecode = wave_info:match(pattern)

  if not start_timecode then return false end

  -- Convert timecode to seconds
  local start_mins, start_secs = start_timecode:match('^(.-):(.-)$')
  start_secs = tonumber(start_secs) + tonumber(start_mins) * 60

  local end_mins, end_secs = end_timecode:match('^(.-):(.-)$')
  end_secs = tonumber(end_secs) + tonumber(end_mins) * 60

  -- Note: When no media file is loaded, start and end are both 0
  return start_secs ~= end_secs, start_secs, end_secs
end

local function RS5k_File()
  local OS = r.GetOS()
  if OS == 'Win32' or OS == 'Win64' then
    file_name = 'reasamplomatic.dll'
  elseif OS == 'OSX32' or OS == 'OSX64' or OS == 'macOS-arm64' then
    file_name = 'reasamplomatic.vst.dylib'
  else
    file_name = 'reasamplomatic.vst.so'
  end
  return file_name
end

local function AddSamplesToRS5k(pad_num, add_pos, i, a, notenum, note_name, mx, pitch, rate, volume, apply_pr, assign_p)
  local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. pad_num - 1) -- 0 based
  local rs5k_id = ConvertPathToNestedPath(pad_id, add_pos)
  local _, payload = im.GetDragDropPayloadFile(ctx, i) -- 0 based
  local src = r.PCM_Source_CreateFromFile(payload)
  local src_length = r.GetMediaSourceLength(src)
  --r.PCM_Source_Destroy(src)
  --local start_offset = start_offs / src_length
  --local end_offset = end_offs / src_length
  local tempomatch = (r.GetToggleCommandStateEx(32063, 40021) == 1) or (r.GetToggleCommandStateEx(32063, 40022) == 1) or (r.GetToggleCommandStateEx(32063, 40023) == 1)
  if i == 0 and (rate ~= 1 and apply_pr == 1) or (src_length > 3 and tempomatch) or (not pitch_as_parameter and pitch ~= 0) then -- Apply rate in MX and glue it when settings is on and ignore if the rate is 1.
    MX_ApplyRate(mx)
    pitch = 0
  end
  local rs5k_id = tonumber(rs5k_id)
  local rs5k_name = RS5k_File()
  r.TrackFX_AddByName(track, rs5k_name, false, rs5k_id)
  Pad[a].RS5k_ID = rs5k_id
  r.TrackFX_Show(track, rs5k_id, 2)
  local ext = payload:match("([^%.]+)$")
  if r.IsMediaExtension(ext, false) and #ext <= 4 and ext ~= "mid" then
    r.TrackFX_SetNamedConfigParm(track, rs5k_id, 'MODE', 1)         -- Sample mode
    r.TrackFX_SetNamedConfigParm(track, rs5k_id, '-FILE*', '') -- remove file list
    if (rate ~= 1 and apply_pr == 1) or (src_length > 3 and tempomatch) or (not pitch_as_parameter and pitch ~= 0) then 
      payload = payload_name[i + 1] -- i = 0 based
    end
    r.TrackFX_SetNamedConfigParm(track, rs5k_id, 'FILE', payload) -- add file
    r.TrackFX_SetNamedConfigParm(track, rs5k_id, 'DONE', '')        -- always necessary
    r.SetExtState("ReaDrum Machine", "preview_file", payload, true)
    --r.TrackFX_SetParam(track, rs5k_id, 13, start_offset) -- Sample start offset
    --r.TrackFX_SetParam(track, rs5k_id, 14, end_offset) -- Sample end offset
    if pitch_as_parameter and (apply_pr == 1 or assign_p == 1) then -- Apply pitch in MX when settings is on
      r.TrackFX_SetParam(track, rs5k_id, 15, (pitch + 80) / 160) -- apply mx pitch
    end
    local filename = payload:match("([^\\/]+)%.%w%w*$")
    r.SetTrackMIDINoteNameEx(0, track, notenum, -1, filename)
    if Pad[a].Rename then renamed_name = note_name .. ": " .. Pad[a].Rename elseif filename then renamed_name = note_name .. ": " .. filename else renamed_name = note_name end
    r.TrackFX_SetNamedConfigParm(track, Pad[a].Pad_ID, "renamed_name", renamed_name)
    Pad[a].Name = filename
  end
end

function AddSampleToExistingRS5k(a, RS5k_ID, i, mx, apply_pr, rate, assign_p, pitch)
  local _, payload = im.GetDragDropPayloadFile(ctx, i)
  local src = r.PCM_Source_CreateFromFile(payload)
  local src_length = r.GetMediaSourceLength(src)
  local tempomatch = (r.GetToggleCommandStateEx(32063, 40021) == 1) or (r.GetToggleCommandStateEx(32063, 40022) == 1) or (r.GetToggleCommandStateEx(32063, 40023) == 1) -- Assign detected pitch when inserting into sampler
  if i == 0 and (rate ~= 1 and apply_pr == 1) or (src_length > 3 and tempomatch) or (not pitch_as_parameter and pitch ~= 0) then -- Apply rate in MX and glue it when settings is on and ignore if the rate is 1.
    MX_ApplyRate(mx)
    pitch = 0
  end
  if (rate ~= 1 and apply_pr == 1) or (src_length > 3 and tempomatch) or (not pitch_as_parameter and pitch ~= 0) then 
    payload = payload_name[i + 1] -- i = 0 based
  end
  local ext = payload:match("([^%.]+)$")
  if r.IsMediaExtension(ext, false) and #ext <= 4 and ext ~= "mid" then
    r.TrackFX_SetNamedConfigParm(track, RS5k_ID, 'FILE0', payload) -- change file
    r.TrackFX_SetNamedConfigParm(track, RS5k_ID, 'DONE', '')
    r.SetExtState("ReaDrum Machine", "preview_file", payload, true)
    local filename = payload:match("([^\\/]+)%.%w%w*$")
    Pad[a].Name = filename
    local note_name = getNoteName(notenum + i + midi_oct_offs)
    if Pad[a].Rename then renamed_name = note_name .. ": " .. Pad[a].Rename elseif filename then renamed_name = note_name .. ": " .. filename else renamed_name = note_name end
    r.TrackFX_SetNamedConfigParm(track, Pad[a].Pad_ID, "renamed_name", renamed_name)
    r.SetTrackMIDINoteNameEx(0, track, notenum, -1, filename)
    r.TrackFX_SetParam(track, RS5k_ID, 13, 0) -- Sample start offset, reset
    r.TrackFX_SetParam(track, RS5k_ID, 14, 1) -- Sample end offset, reset
    if pitch_as_parameter and (apply_pr == 1 or assign_p == 1) then -- Apply pitch in MX when settings is on
      r.TrackFX_SetParam(track, RS5k_ID, 15, (pitch + 80) / 160) -- apply mx pitch
    end
  end
end

function DndAddSampleToEachRS5k_TARGET(a, RS5k_ID, i)
  if im.BeginDragDropTarget(ctx) then
    local rv, count = im.AcceptDragDropPayloadFiles(ctx)
    if rv then
      local mx = r.OpenMediaExplorer('', false)
      local pitch = MX_GetPitch(mx)
      local rate = MX_GetRate(mx)
      local volume = MX_GetVolume(mx)
      local apply_pr = r.GetToggleCommandStateEx(32063, 42164) -- Apply preview pitch/rate to inserted media item
      local assign_p = r.GetToggleCommandStateEx(32063, 42318) -- Assign detected pitch when inserting into sampler
      AddSampleToExistingRS5k(a, RS5k_ID, i, mx, apply_pr, rate, assign_p, pitch)
    end
    im.EndDragDropTarget(ctx)
  end
end

function DndAddSample_TARGET(a)
  if im.BeginDragDropTarget(ctx) then
    local rv, count = im.AcceptDragDropPayloadFiles(ctx)
    if rv then
      local mx = r.OpenMediaExplorer('', false)
      local pitch = MX_GetPitch(mx)
      local rate = MX_GetRate(mx)
      local volume = MX_GetVolume(mx)
      local apply_pr = r.GetToggleCommandStateEx(32063, 42164) -- Apply preview pitch/rate to inserted media item
      local assign_p = r.GetToggleCommandStateEx(32063, 42318) -- Assign detected pitch when inserting into sampler
      InsertDrumMachine()
      GetDrumMachineIdx(track) -- parent_id = num
      if not parent_id then return end
      r.Undo_BeginBlock()
      r.PreventUIRefresh(1)
      for i = 0, count - 1 do
        if not Pad[a + i] then
          CountPads()                           -- pads_idx = num
          if not pads_idx then return end
          AddPad(getNoteName(notenum + i), a + i) -- pad_id = loc, pad_num = num
          AddNoteFilter(notenum + i, pad_num)
          AddSamplesToRS5k(pad_num, 2, i, a + i, notenum + i, getNoteName(notenum + i + midi_oct_offs), mx, pitch, rate, volume, apply_pr, assign_p) -- Pad[a].Name
        elseif Pad[a + i].Pad_Num then
          CountPadFX(Pad[a + i].Pad_Num) -- padfx_idx = num
          found = false
          for rs5k_pos = 1, padfx_idx do
            local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. Pad[a + i].Pad_Num - 1) -- 0 based
            local _, find_rs5k = r.TrackFX_GetNamedConfigParm(track, pad_id, "container_item." .. rs5k_pos - 1)
            local _, buf = r.TrackFX_GetNamedConfigParm(track, find_rs5k, 'fx_ident') -- by default \\Plugins\\FX\\reasamplomatic.dll<1920167789 or /Applications/REAPER.app/Contents/Plugins/FX/reasamplomatic.vst.dylib<1920167789
            if buf:find("1920167789") then    
              found = true
              AddSampleToExistingRS5k(a, find_rs5k, i, mx, apply_pr, rate, assign_p, pitch)
            end
          end
        end
        if not found then
          AddSamplesToRS5k(Pad[a + i].Pad_Num, padfx_idx + 1, i, a + i, notenum + i, getNoteName(notenum + i + midi_oct_offs), mx, pitch, rate, volume, apply_pr, assign_p)
        end
      end
      r.PreventUIRefresh(-1)
      EndUndoBlock("ADD SAMPLES")
    end
    im.EndDragDropTarget(ctx)
  end
end

function DndAddMultipleSamples_TARGET(a) -- several instances into one pad
  if im.BeginDragDropTarget(ctx) then
    local rv, count = im.AcceptDragDropPayloadFiles(ctx)
    if rv and not Pad[a] then
      InsertDrumMachine()
      GetDrumMachineIdx(track)  -- parent_id = num
      CountPads()          -- pads_idx = num
      AddPad(note_name, a) -- pad_id = loc, pad_num = num
      local _, previous_pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. pad_num - 2) -- 0 based
      local _, next_pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. pad_num) -- 0 based
      Pad[a] = {
        Previous_Pad_ID = previous_pad_id,
        Pad_ID = pad_id,
        Next_Pad_ID = next_pad_id,
        Pad_Num = pad_num
      }
      CountPadFX(pad_num) -- padfx_idx = num
      AddNoteFilter(notenum, pad_num)
      for i = 0, count - 1 do
        local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. pad_num - 1) -- 0 based
        local _, rs5k_id = r.TrackFX_GetNamedConfigParm(track, pad_id, "container_item." .. padfx_idx + 1 + i)
        AddSamplesToRS5k(pad_num, padfx_idx + 2 + i, i, a, note_name, mx, pitch, rate, volume, apply_pr, assign_p)
      end
    elseif rv and Pad[a].Pad_Num then
      GetDrumMachineIdx(track) -- parent_id = num
      CountPadFX(Pad[a].Pad_Num)
      for i = 0, count - 1 do
        AddSamplesToRS5k(Pad[a].Pad_Num, padfx_idx + 1 + i, i, a, note_name, mx, pitch, rate, volume, apply_pr, assign_p)
      end
    end
    im.EndDragDropTarget(ctx)
  end
end
