--@noindex
--NoIndex: true

r = reaper

local function GetPayload()
    local retval, dndtype, payload = r.ImGui_GetDragDropPayload(ctx)
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
  filter_id = get_fx_id_from_container_path(track, parent_id, pad_num, 1) -- 1 based, num
  r.TrackFX_AddByName(track, 'RDM MIDI Note Filter', false, filter_id)
  r.TrackFX_SetParam(track, filter_id, 0, notenum)                        -- lowest key for filter, pad number = midi note
  r.TrackFX_SetParam(track, filter_id, 1, notenum)                        -- highest key for filter
end
  
function DndAddFX_SRC(fx)
  if r.ImGui_BeginDragDropSource(ctx, r.ImGui_DragDropFlags_AcceptBeforeDelivery()) then
      r.ImGui_SetDragDropPayload(ctx, 'DND ADD FX', fx)
      r.ImGui_Text(ctx, fx)
      r.ImGui_EndDragDropSource(ctx)
    end
end
  
function DndMoveFX_SRC(a)
    -- if CTRL then return end
    if Pad[a] then
      if r.ImGui_BeginDragDropSource(ctx, r.ImGui_DragDropFlags_AcceptBeforeDelivery() | r.ImGui_DragDropFlags_SourceNoPreviewTooltip()) then
        local data = Pad[a].TblIdx
        r.ImGui_SetDragDropPayload(ctx, 'DND MOVE FX', data)
        -- Display preview (could be anything, e.g. when dragging an image we could decide to display
        -- the filename and a small preview of the image, etc.)
        -- CreateCustomPreviewData(tbl,i)
        -- r.ImGui_Text(ctx, Pad[a].Note_Num)
        r.ImGui_EndDragDropSource(ctx)
      end
    end
end
  
   function DndMoveFX_TARGET_SWAP(a) -- Swap whole pads  -> modulation is kept
    if not DND_MOVE_FX then return end
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_DragDropTarget(), 0)
    if r.ImGui_BeginDragDropTarget(ctx) then
      local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'DND MOVE FX')
      r.ImGui_EndDragDropTarget(ctx)
      r.Undo_BeginBlock()
      r.PreventUIRefresh(1)
      GetDrumMachineIdx()
      if ret then
        local is_move = (not CTRL_DRAG) and true or false
        if is_move then    -- move
          if Pad[a] then   -- swap
            local b = payload
            local b = tonumber(b)
            local src_pad = Pad[b].Pad_ID
            local src_num = Pad[b].Pad_Num
            local src_note = Pad[b].Note_Num
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
              dst_pad_new = get_fx_id_from_container_path(track, parent_id, dst_num - 1)
            end
            if src_num > dst_num then
              dst_pad_new = get_fx_id_from_container_path(track, parent_id, dst_num + 1)
            end
            r.TrackFX_CopyToTrack(track, dst_pad_new, track, src_pad, true)
            FindNoteFilter(dst_num)
            local src_filter = get_fx_id_from_container_path(track, parent_id, dst_num, fi)
            r.TrackFX_SetParam(track, src_filter, 0, notenum)  -- lowest key for filter, pad number = midi note drag
            r.TrackFX_SetParam(track, src_filter, 1, notenum)  -- highest key for filter
            FindNoteFilter(src_num)
            local dst_filter = get_fx_id_from_container_path(track, parent_id, src_num, fi)
            r.TrackFX_SetParam(track, dst_filter, 0, src_note) -- lowest key for filter, pad number = midi note drop
            r.TrackFX_SetParam(track, dst_filter, 1, src_note) -- highest key for filter
            -- SwapRS5kNoteRange(srcfx_idx, dst_num, notenum)
            -- SwapRS5kNoteRange(dstfx_idx, src_num, src_note)
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
            local previous_pad_id = get_fx_id_from_container_path(track, parent_id, pad_num - 1)
            local next_pad_id = get_fx_id_from_container_path(track, parent_id, pad_num + 1)
            Pad[a] = { -- dst
              Previous_Pad_ID = previous_pad_id,
              Pad_ID = pad_id,
              Next_Pad_ID = next_pad_id,
              Pad_Num = pad_num,
              TblIdx = a,
              Note_Num = notenum,
              Name = Pad[b].Name,
            }
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
            r.SetTrackMIDINoteNameEx(0, track, src_note, 0, "")
            local srcfx_idx = CountPadFX(src_num)
            local dstfx_pos = CountPadFX(Pad[a].Pad_Num)
            for m = 1, srcfx_idx do
              dstfx_pos = dstfx_pos + 1                                                             -- the last slot being offset by 1
              local srcfx = get_fx_id_from_container_path(track, parent_id, src_num, 1)                   -- 1st slot * srcfx_idx times
              local dst_last = get_fx_id_from_container_path(track, parent_id, Pad[a].Pad_Num, dstfx_pos) -- add FX
              r.TrackFX_CopyToTrack(track, srcfx, track, dst_last, true)                            -- true = move
            end
            FindNoteFilter(Pad[a].Pad_Num)
            local filter_id = get_fx_id_from_container_path(track, parent_id, Pad[a].Pad_Num, fi)
            r.TrackFX_SetParam(track, filter_id, 0, notenum)                        -- lowest key for filter, pad number = midi note
            r.TrackFX_SetParam(track, filter_id, 1, notenum)                        -- highest key for filter
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
              local dst_last = get_fx_id_from_container_path(track, parent_id, dst_num, dstfx_idx)
              local srcfx = get_fx_id_from_container_path(track, parent_id, src_num, c)
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
            local previous_pad_id = get_fx_id_from_container_path(track, parent_id, pad_num - 1)
            local next_pad_id = get_fx_id_from_container_path(track, parent_id, pad_num + 1)
            Pad[a] = { -- dst
              Previous_Pad_ID = previous_pad_id,
              Pad_ID = pad_id,
              Next_Pad_ID = next_pad_id,
              Pad_Num = pad_num,
              TblIdx = a,
              Note_Num = notenum,
              Name = Pad[b].Name,
            }
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
              local dst_last = get_fx_id_from_container_path(track, parent_id, pad_num, dstfx_idx)
              local srcfx = get_fx_id_from_container_path(track, parent_id, src_num, c)
              r.TrackFX_CopyToTrack(track, srcfx, track, dst_last, false) -- false = copy
            end
            FindNoteFilter(pad_num)
            local filter_id = get_fx_id_from_container_path(track, parent_id, pad_num, fi)
            r.TrackFX_SetParam(track, filter_id, 0, notenum)
            r.TrackFX_SetParam(track, filter_id, 1, notenum)
            r.PreventUIRefresh(-1)
            EndUndoBlock("COPY PAD")
          end
        end
      end
    end
    r.ImGui_PopStyleColor(ctx)
  end
  
   function DndAddSample_SRC(sample)
    if r.ImGui_BeginDragDropSource(ctx) then
      r.ImGui_SetDragDropPayload(ctx, 'DND ADD SAMPLE', sample)
      r.ImGui_Text(ctx, sample)
      r.ImGui_EndDragDropSource(ctx)
    end
    if dst_rename then
      r.SetTrackMIDINoteNameEx(0, track, src_note, 0, dst_rename)
    elseif dst_name then
      r.SetTrackMIDINoteNameEx(0, track, src_note, 0, dst_name)
    end
    if Pad[b].Rename then
      r.SetTrackMIDINoteNameEx(0, track, notenum, 0, Pad[b].Rename)
    elseif Pad[b].Name then
      r.SetTrackMIDINoteNameEx(0, track, notenum, 0, Pad[b].Name)
    end
  end
  
   function DndAddFX_TARGET(a)
    if not DND_ADD_FX then return end
    InsertDrumMachine()
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_DragDropTarget(), 0)
    if r.ImGui_BeginDragDropTarget(ctx) then
      local ret, payload = r.ImGui_AcceptDragDropPayload(ctx, 'DND ADD FX')
      r.ImGui_EndDragDropTarget(ctx)
      if ret and not Pad[a] then
        GetDrumMachineIdx()     -- parent_id = num
        CountPads()             -- pads_idx = num
        r.Undo_BeginBlock()
        r.PreventUIRefresh(1)
        AddPad(note_name, a)     -- pad_id = loc, pad_num = num
        previous_pad_id = get_fx_id_from_container_path(track, parent_id, pad_num - 1)
        next_pad_id = get_fx_id_from_container_path(track, parent_id, pad_num + 1)
        Pad[a] = {
          Previous_Pad_ID = previous_pad_id,
          Pad_ID = pad_id,
          Next_Pad_ID = next_pad_id,
          Pad_Num = pad_num,
          TblIdx = a,
          Note_Num = notenum
        }
        CountPadFX(Pad[a].Pad_Num)                                                             -- padfx_idx = num
        AddNoteFilter(notenum, pad_num)
        padfx_id = get_fx_id_from_container_path(track, parent_id, pad_num, padfx_idx + 2)     -- add FX
        r.TrackFX_AddByName(track, payload, false, padfx_id)
        r.PreventUIRefresh(-1)
        EndUndoBlock("ADD FX") 
      elseif ret and Pad[a].Pad_Num then
        GetDrumMachineIdx()   -- parent_id = num
        CountPadFX(Pad[a].Pad_Num)
        padfx_id = get_fx_id_from_container_path(track, parent_id, Pad[a].Pad_Num, padfx_idx + 1)
        r.Undo_BeginBlock()
        r.PreventUIRefresh(1)
        r.TrackFX_AddByName(track, payload, false, -1000 - padfx_id)
        r.PreventUIRefresh(-1)
        EndUndoBlock("ADD FX")
      end
    end
    r.ImGui_PopStyleColor(ctx)
  end
  
  local function AddSamplesToRS5k(pad_num, add_pos, i, a, notenum, note_name)
    rs5k_id = get_fx_id_from_container_path(track, parent_id, pad_num, add_pos)
    rv, payload = r.ImGui_GetDragDropPayloadFile(ctx, i) -- 0 based
    r.TrackFX_AddByName(track, 'ReaSamplomatic5000', false, rs5k_id)
    r.TrackFX_Show(track, rs5k_id, 2)
    r.TrackFX_SetNamedConfigParm(track, rs5k_id, 'MODE', 1)         -- Sample mode
    r.TrackFX_SetNamedConfigParm(track, rs5k_id, '-FILE*', '') -- remove file list
    r.TrackFX_SetNamedConfigParm(track, rs5k_id, 'FILE', payload) -- add file
    r.TrackFX_SetNamedConfigParm(track, rs5k_id, 'DONE', '')        -- always necessary
    -- r.TrackFX_SetParam(track, rs5k_id, 11, 1)                       -- obey note offs
    Pad[a].RS5k_ID = rs5k_id
    rv, buf = r.TrackFX_GetNamedConfigParm(track, rs5k_id, 'FILE')
    filename = buf:match("([^\\/]+)%.%w%w*$")
    r.SetTrackMIDINoteNameEx(0, track, notenum, 0, filename)
    if Pad[a].Rename then renamed_name = note_name .. ": " .. Pad[a].Rename elseif filename then renamed_name = note_name .. ": " .. filename else renamed_name = note_name end
    r.TrackFX_SetNamedConfigParm(track, Pad[a].Pad_ID, "renamed_name", renamed_name)
    Pad[a].Name = filename
  end

 function DndAddSample_TARGET(a)
    if r.ImGui_BeginDragDropTarget(ctx) then
      local rv, count = r.ImGui_AcceptDragDropPayloadFiles(ctx)
      if rv then
        InsertDrumMachine()
        GetDrumMachineIdx() -- parent_id = num
        r.Undo_BeginBlock()
        r.PreventUIRefresh(1)
        for i = 0, count - 1 do
          if not Pad[a + i] then
            CountPads()                           -- pads_idx = num
            AddPad(getNoteName(notenum + i), a + i) -- pad_id = loc, pad_num = num
            previous_pad_id = get_fx_id_from_container_path(track, parent_id, pad_num - 1)
            next_pad_id = get_fx_id_from_container_path(track, parent_id, pad_num + 1)
            Pad[a + i] = {
              Previous_Pad_ID = previous_pad_id,
              Pad_ID = pad_id,
              Next_Pad_ID = next_pad_id,
              Pad_Num = pad_num,
              TblIdx = a + i,
              Note_Num = notenum + i
            }
            AddNoteFilter(notenum + i, pad_num)
            AddSamplesToRS5k(pad_num, 2, i, a + i, notenum + i, getNoteName(notenum + i)) -- Pad[a].Name
          elseif Pad[a + i].Pad_Num then
            CountPadFX(Pad[a + i].Pad_Num) -- padfx_idx = num
            local found = false
            for rs5k_pos = 1, padfx_idx do
              find_rs5k = get_fx_id_from_container_path(track, parent_id, Pad[a + i].Pad_Num, rs5k_pos)
              retval, buf = r.TrackFX_GetNamedConfigParm(track, find_rs5k, 'original_name')
              if buf == "VSTi: ReaSamplOmatic5000 (Cockos)" then
                found = true
                rv, payload = r.ImGui_GetDragDropPayloadFile(ctx, i)
                r.TrackFX_SetNamedConfigParm(track, find_rs5k, 'FILE0', payload) -- change file
                r.TrackFX_SetNamedConfigParm(track, find_rs5k, 'DONE', '')
                filename = payload:match("([^\\/]+)%.%w%w*$")
                Pad[a].Name = filename
                if Pad[a].Rename then renamed_name = note_name .. ": " .. Pad[a].Rename elseif filename then renamed_name = note_name .. ": " .. filename else renamed_name = note_name end
                r.TrackFX_SetNamedConfigParm(track, Pad[a].Pad_ID, "renamed_name", renamed_name)
                r.SetTrackMIDINoteNameEx(0, track, notenum, 0, filename)
                r.TrackFX_SetParam(track, find_rs5k, 13, 0) -- Sample start offset, reset
                r.TrackFX_SetParam(track, find_rs5k, 14, 1) -- Sample end offset, reset
              end
            end
            if not found then
              AddSamplesToRS5k(Pad[a + i].Pad_Num, padfx_idx + 1, i, a + i, notenum + i, getNoteName(notenum + i))
            end
          end
        end
        r.PreventUIRefresh(-1)
        EndUndoBlock("ADD SAMPLES")
      end
      r.ImGui_EndDragDropTarget(ctx)
    end
  end
  
   function DndAddMultipleSamples_TARGET(a) -- several instances into one pad
    if r.ImGui_BeginDragDropTarget(ctx) then
      local rv, count = r.ImGui_AcceptDragDropPayloadFiles(ctx)
      if rv and not Pad[a] then
        InsertDrumMachine()
        GetDrumMachineIdx()  -- parent_id = num
        CountPads()          -- pads_idx = num
        AddPad(note_name, a) -- pad_id = loc, pad_num = num
        previous_pad_id = get_fx_id_from_container_path(track, parent_id, pad_num - 1)
        next_pad_id = get_fx_id_from_container_path(track, parent_id, pad_num + 1)
        Pad[a] = {
          Previous_Pad_ID = previous_pad_id,
          Pad_ID = pad_id,
          Next_Pad_ID = next_pad_id,
          Pad_Num = pad_num
        }
        CountPadFX(pad_num) -- padfx_idx = num
        AddNoteFilter(notenum, pad_num)
        for i = 0, count - 1 do
          rs5k_id = get_fx_id_from_container_path(track, parent_id, pad_num, padfx_idx + 2 + i)
          AddSamplesToRS5k(pad_num, padfx_idx + 2 + i, i, a, note_name)
        end
      elseif rv and Pad[a].Pad_Num then
        GetDrumMachineIdx() -- parent_id = num
        CountPadFX(Pad[a].Pad_Num)
        for i = 0, count - 1 do
          AddSamplesToRS5k(Pad[a].Pad_Num, padfx_idx + 1 + i, i, a, note_name)
        end
      end
      r.ImGui_EndDragDropTarget(ctx)
    end
  end
  
-- local function SetRS5kNoteRange(track, fx, note_start, note_end)
--    r.TrackFX_SetParamNormalized(track, fx, 3, note_start / 127)
--    r.TrackFX_SetParamNormalized(track, fx, 4, note_end / 127)
--  end

--function SwapRS5kNoteRange(padfx_idx, pad, NoteNum)
--    for rs5k_pos = 1, padfx_idx do
--      find_rs5k = get_fx_id_from_container_path(track, parent_id, pad, rs5k_pos)
--      retval, buf = r.TrackFX_GetNamedConfigParm(track, find_rs5k, 'original_name')
--      if buf == "VSTi: ReaSamplOmatic5000 (Cockos)" then
--        SetRS5kNoteRange(track, find_rs5k, NoteNum, NoteNum) -- Adjust RS5k note range to match a pad's note
--      end
--    end
--  end

--   function DndCopySample_TARGET() -- replace target sample file with source file
--  end
  
-- function DndSwapSample_TARGET() -- swap sample file  
--  end