--@noindex

r = reaper

local track_guid_cache = {};

local function track_from_guid_str(proj, g) -- https://forum.cockos.com/showthread.php?t=220734
  local c = track_guid_cache[g];
  if c ~= nil and reaper.GetTrack(proj,c.idx) == c.ptr then
    -- cached!
    return c.ptr;
  end
  
  -- find guid in project
  local x = 0
  while true do
    local t = reaper.GetTrack(proj,x)
    if t == nil then
      -- not found in project, remove from cache and return error
      if c ~= nil then track_guid_cache[g] = nil end
      return nil
    end
    if g == reaper.GetTrackGUID(t) then
      -- found, add to cache
      track_guid_cache[g] = { idx = x, ptr = t }
      return t
    end
    x = x + 1
  end
end

--------------------------------------------------------------------------------
-- Pickle table serialization - Steve Dekorte, http://www.dekorte.com, Apr 2000 -- https://forum.cockos.com/showpost.php?p=2592436&postcount=7
--------------------------------------------------------------------------------
local function pickle(t)
	return Pickle:clone():pickle_(t)
end

Pickle = {
	clone = function (t) local nt = {}
	for i, v in pairs(t) do 
		nt[i] = v 
	end
	return nt 
end 
}

function Pickle:pickle_(root)
	if type(root) ~= "table" then 
		error("can only pickle tables, not " .. type(root) .. "s")
	end
	self._tableToRef = {}
	self._refToTable = {}
	local savecount = 0
	self:ref_(root)
	local s = ""
	while #self._refToTable > savecount do
		savecount = savecount + 1
		local t = self._refToTable[savecount]
		s = s .. "{\n"
		for i, v in pairs(t) do
			s = string.format("%s[%s]=%s,\n", s, self:value_(i), self:value_(v))
		end
	s = s .. "},\n"
	end
	return string.format("{%s}", s)
end

function Pickle:value_(v)
	local vtype = type(v)
	if     vtype == "string" then return string.format("%q", v)
	elseif vtype == "number" then return v
	elseif vtype == "boolean" then return tostring(v)
	elseif vtype == "table" then return "{"..self:ref_(v).."}"
	else error("pickle a " .. type(v) .. " is not supported")
	end 
end

function Pickle:ref_(t)
	local ref = self._tableToRef[t]
	if not ref then 
		if t == self then error("can't pickle the pickle class") end
		table.insert(self._refToTable, t)
		ref = #self._refToTable
		self._tableToRef[t] = ref
	end
	return ref
end

local function unpickle(s)
	if type(s) ~= "string" then
		error("can't unpickle a " .. type(s) .. ", only strings")
	end
	local gentables = load("return " .. s)
	local tables = gentables()
	for tnum = 1, #tables do
		local t = tables[tnum]
		local tcopy = {}
		for i, v in pairs(t) do tcopy[i] = v end
		for i, v in pairs(tcopy) do
			local ni, nv
			if type(i) == "table" then ni = tables[i[1]] else ni = i end
			if type(v) == "table" then nv = tables[v[1]] else nv = v end
			t[i] = nil
			t[ni] = nv
		end
	end
	return tables[1]
end

----------------------------------------------------------------------------

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
  local _, clear_pad = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. pad_num - 1) -- 0 based
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
      if SELECTED then
        ClearPad(a, Pad[a].Pad_Num)
        for k, v in pairs(SELECTED) do
          UpdatePadID()
          local k = tonumber(k)
          if Pad[k] ~= Pad[a] then
            ClearPad(k, Pad[k].Pad_Num)
          end
        end
        SELECTED = nil
      else
        ClearPad(a, Pad[a].Pad_Num)
      end
      rev, value = r.GetProjExtState(0, 'ReaDrum Machine', 'Rename' .. a)
      if rev == 1 then
        r.SetProjExtState(0, 'ReaDrum Machine', 'Rename' .. a, "")
      end
      UpdatePadID()
      r.PreventUIRefresh(-1)
      EndUndoBlock("CLEAR PAD")
    elseif SHIFT and not r.ImGui_IsMouseDoubleClicked(ctx, 0) then
      if SELECTED and SELECTED[tostring(a)] then -- unselect
        SELECTED[tostring(a)] = nil
      else
        if not SELECTED then
          SELECTED = {}
        end
        SELECTED[tostring(a)] = true
      end
    else
      if SELECTED then
        r.Undo_BeginBlock()      
        for k, v in pairs(SELECTED) do
          local k = tonumber(k)
          if Pad[k] then -- open/close the rest
            local open = r.TrackFX_GetOpen(track, Pad[k].Pad_ID) -- 0 based
            if open then
              r.TrackFX_Show(track, Pad[k].Pad_ID, 2)           -- hide floating window
            else
              r.TrackFX_Show(track, Pad[k].Pad_ID, 3)           -- show floating window
              local _, fx_id = r.TrackFX_GetNamedConfigParm(track, Pad[k].Pad_ID, "container_item." .. 1)
              local isfilter_visible = r.TrackFX_GetOpen(track,  Pad[k].Filter_ID)
              if isfilter_visible then
                r.PreventUIRefresh(1)
                r.TrackFX_SetOpen(track, fx_id, 1)
                r.UpdateArrange()
                r.PreventUIRefresh(-1)
              end
            end
          end
        end
        SELECTED = nil
        EndUndoBlock("OPEN FX WINDOW")
      else
        local open = r.TrackFX_GetOpen(track, Pad[a].Pad_ID) -- 0 based
        if open then
          r.Undo_BeginBlock()
          r.TrackFX_Show(track, Pad[a].Pad_ID, 2)           -- hide floating window
          EndUndoBlock("HIDE FX WINDOW")
        else
          r.Undo_BeginBlock()
          r.TrackFX_Show(track, Pad[a].Pad_ID, 3)           -- show floating window
          EndUndoBlock("OPEN FX WINDOW")
          local _, fx_id = r.TrackFX_GetNamedConfigParm(track, Pad[a].Pad_ID, "container_item." .. 1)
          local isfilter_visible = r.TrackFX_GetOpen(track,  Pad[a].Filter_ID)
          if isfilter_visible then
            r.TrackFX_SetOpen(track, fx_id, 1)
          end
        end
      end
    end
  else
    if SHIFT then
      if SELECTED and SELECTED[tostring(a)] then
        SELECTED[tostring(a)] = nil
      else
        if not SELECTED then
          SELECTED = {}
        end
        SELECTED[tostring(a)] = true -- ipairs is for sereal numbers
      end
    else
      SELECTED = nil
    end
  end
end

-- right click --
function OpenRS5kInsidePad(a, w_open)
  if not Pad[a] then return end 
  if not WhichRS5k then
    WhichRS5k = 1
  end
  UpdatePadID()
  --r.ShowConsoleMsg(RS5k_instances[1])
  r.ImGui_SameLine(ctx, nil, 0)
  if r.ImGui_BeginChild(ctx, "open_pad", 250 + 50, 220 + 88, false) then
    FXUI(a)
    r.ImGui_EndChild(ctx)
  end
end

-- Ctrl + right click
local function CreateNewChildTrack(insert_loc, child_num)
  r.InsertTrackAtIndex(insert_loc, false)
  local child_track = r.CSurf_TrackFromID(insert_loc + 1, false)
  local child_guid = r.GetTrackGUID(child_track)
  if Children_GUID then
    Children_GUID.child_guid[child_num] = child_guid
  else
    Children_GUID = {}
    Children_GUID.child_guid = {}
    Children_GUID.child_guid[child_num] = child_guid
  end
end

local function SetTrackSend(bus_track, child_track)
  local send = r.CreateTrackSend(track, child_track)
  local send_info = ch_num - 2
  r.SetTrackSendInfo_Value(track, 0, send, 'I_SRCCHAN', send_info) -- set send channel
  r.SetMediaTrackInfo_Value(bus_track, 'I_FOLDERCOMPACT', 1) -- collapse folder
  r.SetMediaTrackInfo_Value(track, 'I_SELECTED', 1) -- select drum track
  -- r.SetMediaTrackInfo_Value(track, 'B_MAINSEND', 0) -- turn off master send
  r.SetMediaTrackInfo_Value(track, 'C_MAINSEND_NCH', 2)
end

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

local function SetOutputPin(a, chan_num)
  if not Pad[a] or chan_num == nil then return end
  
  local num = tonumber(chan_num)
  if num == nil then
    error("Channel number must be a number") 
  end
  
  local chan_num = math.floor(tonumber(chan_num) + 0.5)  
  local chan_num = math.max(1, math.min(tonumber(chan_num), 128))
  local block_num = math.floor((chan_num - 1) / 32) + 1 -- channels can be divided into 4 blocks, 1)1-32, 2)33-64, 3)65-96, 4)97-128
  ch_num = chan_num
  if ch_num % 2 == 1 then
    ch_num = ch_num + 1
  else
    ch_num = ch_num
  end
  
  local is_secondhalf = 0
  
  if block_num >= 3 then -- add 0x1000000 to #4 for the second half blocks
    is_secondhalf = 0x1000000 
  end
  
  if block_num == 2 then
    chan_num = chan_num - 32
  elseif block_num == 3 then
    chan_num = chan_num - 64
  elseif block_num == 4 then
    chan_num = chan_num - 96
  end
  
  if chan_num % 2 == 1 then -- odd
    chan_num = math.floor(chan_num / 2) + 1
  else -- even
    chan_num = math.floor(chan_num / 2)  
  end
  
  local left = (chan_num - 1) * 2 -- each block has 16 stereo channel, which one?
  local right = left + 1
  

  local isincontainer, parent_container = r.TrackFX_GetNamedConfigParm(track, Pad[a].Pad_ID, 'parent_container')
  if isincontainer then
    local _, hm_cch = r.TrackFX_GetNamedConfigParm(track, parent_container, 'container_nch')
    local isnested, n_pc = r.TrackFX_GetNamedConfigParm(track, parent_container, 'parent_container')
    if ch_num > tonumber(hm_cch) then
      r.SetMediaTrackInfo_Value(track, 'I_NCHAN', ch_num)
      r.TrackFX_SetNamedConfigParm(track, parent_container, 'container_nch', ch_num)
      r.TrackFX_SetNamedConfigParm(track, parent_container, 'container_nch_out', ch_num)
      if isnested then
        r.TrackFX_SetNamedConfigParm(track, n_pc, 'container_nch', ch_num)
        r.TrackFX_SetNamedConfigParm(track, n_pc, 'container_nch_out', ch_num)
      end
    end
  else
    local hm_ch = r.GetMediaTrackInfo_Value(track, 'I_NCHAN')
    if ch_num > tonumber(hm_ch) then
      r.SetMediaTrackInfo_Value(track, 'I_NCHAN', ch_num)
    end
  end
  
  r.TrackFX_SetPinMappings(track, Pad[a].Pad_ID, 1, 0, 0, 0) -- remove the current mappings
  r.TrackFX_SetPinMappings(track, Pad[a].Pad_ID, 1, 1, 0, 0)
  r.TrackFX_SetPinMappings(track, Pad[a].Pad_ID, 1, 0 + 0x1000000, 0, 0)
  r.TrackFX_SetPinMappings(track, Pad[a].Pad_ID, 1, 1 + 0x1000000, 0, 0)
  
  if block_num % 2 == 1 then -- odd number blocks -> #5 = low32bits and #6 = 0
    r.TrackFX_SetPinMappings(track, Pad[a].Pad_ID, 1, 0 + is_secondhalf, 2^left, 0) -- #3 output 1, #4 pin 0 left
    r.TrackFX_SetPinMappings(track, Pad[a].Pad_ID, 1, 1 + is_secondhalf, 2^right, 0) -- #4 pin 1 right
  else -- even number blocks -> #5 = 0 and #6 = high32bits 
    r.TrackFX_SetPinMappings(track, Pad[a].Pad_ID, 1, 0 + is_secondhalf, 0, 2^left) -- #3 output 1, #4 pin 0 left
    r.TrackFX_SetPinMappings(track, Pad[a].Pad_ID, 1, 1 + is_secondhalf, 0, 2^right) -- #4 pin 1 right
  end
end

local function ExplodePadToTrackViaInput(chan_num)
  if chan_num == nil then return end
  r.Undo_BeginBlock()
  local rv, bus_guid = r.GetProjExtState(0, 'Suzuki_SetNSend_ch', track_guid .. 'bus_guid')
  local find_bus = track_from_guid_str(0, bus_guid)
  
  if rv ~= 0 and find_bus ~= nil then -- Sending signal to new track, 2nd+ times
    local bus_track = track_from_guid_str(0, bus_guid)
    local bus_idx = r.CSurf_TrackToID(bus_track, false)
    local rv, pExtStateStr = r.GetProjExtState(0, "Suzuki_SetNSend_ch", track_guid .. "child_guid") -- read pickled table string value from project extended states
    Children_GUID = unpickle(pExtStateStr) -- unpickle extended state string value back into a table
    local first_child_track_guid = Children_GUID.child_guid[1]
    local first_child_track = track_from_guid_str(0, first_child_track_guid)
    local count = 0
    local rcv_input = tonumber(ch_num - 2)
    for i = 1, #Children_GUID.child_guid do -- remove nonexist child track's info
      local child_track_guid = Children_GUID.child_guid[i]
      local child_track = track_from_guid_str(0, child_track_guid)
      if not child_track then
        table.remove(Children_GUID.child_guid, i)
        table.remove(Children_GUID.rcv_ch, i)
        i = i - 1 
      end
    end
    if first_child_track ~= nil then
      for i = 1, r.GetTrackNumSends(track, 0) do -- 1 based
        local children = r.CSurf_TrackFromID(bus_idx + i, false)
        if children == nil then match = false goto dokoka end
        if Children_GUID.rcv_ch[i] == rcv_input then -- match src number
          match = true
          break
        end
        local src_chan = r.GetTrackSendInfo_Value(track, 0, i - 1, 'I_SRCCHAN') -- 0 based
        Children_GUID.rcv_ch[i] = src_chan
        local dest_track = r.GetTrackSendInfo_Value(track, 0, i - 1, 'P_DESTTRACK') -- 0 based
        local child_guid = r.GetTrackGUID(dest_track)
        Children_GUID.child_guid[i] = child_guid
        count = count + 1
      end
      ::dokoka::
      if not match then
        r.SetMediaTrackInfo_Value(bus_track, 'I_FOLDERDEPTH', 0) -- reset to 1st depth
        CreateNewChildTrack(bus_idx + count, count)
        local dst_track = r.CSurf_TrackFromID(bus_idx + 1 + count, false)
        SetTrackSend(bus_track, dst_track)
        local send_num = r.GetTrackNumSends(track, 0) 
        r.SetTrackSendInfo_Value(track, 0, send_num - 1, 'D_VOL', 1.0) -- 0 for sends
        local rcv_ch = r.GetTrackSendInfo_Value(dst_track, -1, 0, 'I_SRCCHAN')
        local rcv_num = r.GetTrackNumSends(track, -1) 
        r.SetTrackSendInfo_Value(dst_track, -1, rcv_num - 1, 'D_VOL', 1.0) -- -1 for receives
        Children_GUID.rcv_ch[count + 1] = rcv_ch
        local child_guid = r.GetTrackGUID(dst_track)
        Children_GUID.child_guid[count + 1] = child_guid
        r.SetMediaTrackInfo_Value(bus_track, 'I_FOLDERDEPTH', 1) -- parent folder
        for i = 1, count + 1 do
          local reset_track = r.CSurf_TrackFromID(bus_idx + i, false)
          r.SetMediaTrackInfo_Value(reset_track, 'I_FOLDERDEPTH', 0) -- last child track
        end
        r.SetMediaTrackInfo_Value(dst_track, 'I_FOLDERDEPTH', -1) -- last child track
      end
    else -- no child
      CreateNewChildTrack(trackidx + 1, 1)
      local child_track = r.CSurf_TrackFromID(trackidx + 2, false)
      SetTrackSend(bus_track, child_track)
      r.SetTrackSendInfo_Value(track, 0, 0, 'D_VOL', 1.0)
      local rcv_ch = r.GetTrackSendInfo_Value(child_track, -1, 0, 'I_SRCCHAN')
      r.SetTrackSendInfo_Value(child_track, -1, 0, 'D_VOL', 1.0)
      Children_GUID.rcv_ch[1] = rcv_ch
      local child_guid = r.GetTrackGUID(child_track)
      Children_GUID.child_guid[1] = child_guid
      r.SetMediaTrackInfo_Value(bus_track, 'I_FOLDERDEPTH', 1) -- parent folder
      r.SetMediaTrackInfo_Value(child_track, 'I_FOLDERDEPTH', -1) -- last child track
    end
    r.SetProjExtState(0, 'Suzuki_SetNSend_ch', track_guid .. 'bus_guid', bus_guid)
  else -- no "bus" track in the project
    r.InsertTrackAtIndex(trackidx, false)
    local bus_track = r.CSurf_TrackFromID(trackidx + 1, false)
    r.GetSetMediaTrackInfo_String(bus_track, 'P_NAME', "RDM Bus", true)
    local bus_guid = r.GetTrackGUID(bus_track)
    r.SetProjExtState(0, 'Suzuki_SetNSend_ch', track_guid .. 'bus_guid', bus_guid)
    CreateNewChildTrack(trackidx + 1, 1)
    local child_track = r.CSurf_TrackFromID(trackidx + 2, false)
    SetTrackSend(bus_track, child_track)
    r.SetTrackSendInfo_Value(track, 0, 0, 'D_VOL', 1.0) -- 0 based
    local rcv_ch = r.GetTrackSendInfo_Value(child_track, -1, 0, 'I_SRCCHAN')
    r.SetTrackSendInfo_Value(child_track, -1, 0, 'D_VOL', 1.0)
    Children_GUID.rcv_ch = {}
    Children_GUID.rcv_ch[1] = rcv_ch
    r.SetMediaTrackInfo_Value(bus_track, 'I_FOLDERDEPTH', 1) -- parent folder
    r.SetMediaTrackInfo_Value(child_track, 'I_FOLDERDEPTH', -1) -- last child track
  end
  local pExtStateStr = pickle(Children_GUID) -- pickle table to string
  r.SetProjExtState(0, "Suzuki_SetNSend_ch", track_guid .. "child_guid", pExtStateStr) -- write pickled table as string to project extended state
  EndUndoBlock("SET OUTPUT CHANNEL PINS AND SEND IT TO NEW TRACK")
end

local function ExplodePadsToTracks()
    CountPads()
    r.SetMediaTrackInfo_Value(track, 'I_NCHAN', 128)
    local drum_id = parent_id
    r.TrackFX_SetNamedConfigParm(track, drum_id, 'container_nch', 128)
    r.TrackFX_SetNamedConfigParm(track, drum_id, 'container_nch_out', 128)
    local drum_track = track
    local track_id = r.CSurf_TrackToID(track, false)
    r.Main_OnCommand(40001, 0)
    for e = 1, pads_idx do
      if e > 64 then last_child = r.CSurf_TrackFromID(track_id + 1 + e, false) break end
      local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. e - 1) -- 0 based
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
      if not Pad[a] and not SELECTED then
        r.ShowConsoleMsg("There's no pad. Insert FX or sample first.")
      else
        r.Undo_BeginBlock()
        r.PreventUIRefresh(1)
        if #new_name ~= 0 then renamed_name = note_name .. ": " .. new_name else renamed_name = note_name end
        if renamed_name then
          if SELECTED then
            for k, v in pairs(SELECTED) do
              UpdatePadID()
              local notenum = k - 1
              local note_name = getNoteName(notenum)
              if #new_name ~= 0 then renamed_name = note_name .. ": " .. new_name else renamed_name = note_name end
              local k = tonumber(k)
              if Pad[k] then 
                r.TrackFX_SetNamedConfigParm(track, Pad[k].Pad_ID, "renamed_name", renamed_name)
                r.SetTrackMIDINoteNameEx(0, track, notenum, 0, new_name)
                Pad[k].Rename = new_name
                r.SetProjExtState(0, 'ReaDrum Machine', 'Rename' .. k, new_name)
              end
            end
            SELECTED = nil
          else
            r.TrackFX_SetNamedConfigParm(track, Pad[a].Pad_ID, "renamed_name", renamed_name)
            r.SetTrackMIDINoteNameEx(0, track, notenum, 0, new_name)
            Pad[a].Rename = new_name
            r.SetProjExtState(0, 'ReaDrum Machine', 'Rename' .. a, new_name)
          end
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

local function AddSampleFromArrange(pad_num, add_pos, a, filenamebuf, start_offset, end_offset, take_pitch, note_name)
  local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. pad_num - 1) -- 0 based
  local rs5k_id = ConvertPathToNestedPath(pad_id, add_pos)
  r.TrackFX_AddByName(track, 'ReaSamplomatic5000', false, rs5k_id)
  Pad[a].RS5k_ID = rs5k_id
  r.TrackFX_Show(track, rs5k_id, 2)
  r.TrackFX_SetNamedConfigParm(track, rs5k_id, 'MODE', 1)             -- Sample mode
  r.TrackFX_SetNamedConfigParm(track, rs5k_id, '-FILE*', '')
  r.TrackFX_SetNamedConfigParm(track, rs5k_id, 'FILE', filenamebuf) -- add file
  r.TrackFX_SetNamedConfigParm(track, rs5k_id, 'DONE', '')            -- always necessary
  --r.TrackFX_SetParam(track, rs5k_id, 0, take_vol)  -- volume 0 .. 1 ..  4
  r.TrackFX_SetParam(track, rs5k_id, 1, 0.5 + take_pan / 2)  -- pan 0 .. 1
  --r.TrackFX_SetParam(track, rs5k_id, 11, 1)                           -- obey note offs
  r.TrackFX_SetParam(track, rs5k_id, 13, start_offset)                -- Sample start offset
  r.TrackFX_SetParam(track, rs5k_id, 14, end_offset)                  -- Sample end offset
  r.TrackFX_SetParam(track, rs5k_id, 15, (take_pitch + 80) / 160)                  -- Pitch offset 0 .. 1
  local filename = filenamebuf:match("([^\\/]+)%.%w%w*$")
  if Pad[a].Rename then renamed_name = note_name .. ": " .. Pad[a].Rename elseif filename then renamed_name = note_name .. ": " .. filename else renamed_name = note_name end
  r.TrackFX_SetNamedConfigParm(track, Pad[a].Pad_ID, "renamed_name", renamed_name)
  Pad[a].Name = filename
end
  
local function LoadItemsFromArrange(a)
  InsertDrumMachine()
  GetDrumMachineIdx(track)                                              -- parent_id = num
  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)
  local SelectedMedia_Num = r.CountSelectedMediaItems(0)
  for c = 1, SelectedMedia_Num do -- storing info about which items are selected
    local item = r.GetSelectedMediaItem(0, c - 1)                  -- 0 based
    local take = r.GetActiveTake(item)
    local rv, take_guid = r.GetSetMediaItemTakeInfo_String(take, 'GUID', "", false)
    if not Take_GUID then
      Take_GUID = {}
    end
    Take_GUID[c] = take_guid
  end
  for c = 1, SelectedMedia_Num do                       -- 1 based
      local item = r.GetSelectedMediaItem(0, c - 1)                  -- 0 based
      local take = r.GetMediaItemTakeByGUID(0, Take_GUID[c])
      local item_length = r.GetMediaItemInfo_Value(item, 'D_LENGTH') -- double
      d = 0
      if not take or r.TakeIsMIDI(take) then
        d = d + 1
        goto NEXT
      end
      local take_src = r.GetMediaItemTake_Source(take)
      local start_offs = r.GetMediaItemTakeInfo_Value(take, 'D_STARTOFFS')
      local take_pitch = r.GetMediaItemTakeInfo_Value(take, 'D_PITCH') 
      if take_pitch > 80 then
        take_pitch = 80
      elseif take_pitch < -80 then
        take_pitch = -80
      end
      local take_playrate = r.GetMediaItemTakeInfo_Value(take, 'D_PLAYRATE') 
      --local take_vol = r.GetMediaItemTakeInfo_Value(take, 'D_VOL')
      --local test = r.GetMediaItemInfo_Value(item, 'D_VOL')
      --if take_vol < -120 then
      --  take_vol = -120
      --elseif take_vol > 12 then
      --  take_vol = 12
      --end
      --if take_vol > 0 then
      -- take_vol = take_vol / 3
      --elseif take_vol < 0 then
      --  take_vol = take_vol / 120 + 1
      --else
      --  take_vol = 1
      --end
      take_pan = r.GetMediaItemTakeInfo_Value(take, 'D_PAN')
      local src_length = r.GetMediaSourceLength(take_src)
      local filenamebuf = r.GetMediaSourceFileName(take_src) -- can't get a name from a reversed take
      local ret, offs, len, rvrs = r.PCM_Source_GetSectionInfo(take_src)
      local start_offset = start_offs / src_length
      local end_offset = (start_offs + item_length) / src_length
      if rvrs or take_playrate ~= 1.0 then
        r.SelectAllMediaItems(0, false)    -- unselect all
        r.SetMediaItemSelected(item, true)
        r.Main_OnCommand(41588, 0)
        --local target_filename = filenamebuf:match("([^\\/]+)%.%w%w*$")
        --r.RenderFileSection(filenamebuf, target_filename .. "_reversed", 0.0, 1.0, 1.0)
        local item = r.GetSelectedMediaItem(0, 0)                  -- 0 based
        local take = r.GetActiveTake(item)
        local rv, take_guid = r.GetSetMediaItemTakeInfo_String(take, 'GUID', "", false)
        Take_GUID[c] = take_guid
        for s = 1, #Take_GUID do -- reselect items
          if Take_GUID[s] then
            local take = r.GetMediaItemTakeByGUID(0, Take_GUID[s])
            local item = r.GetMediaItemTake_Item(take)
            r.SetMediaItemSelected(item, true)
          end
        end
        local take_src = r.GetMediaItemTake_Source(take)
        filenamebuf = r.GetMediaSourceFileName(take_src) -- new path
        start_offset = 0 -- overwriting them since the file is rendered as a new file
        end_offset = 1
      end
      if not Pad[a + c - 1 - d] then
        local pads_idx = CountPads()                                             -- pads_idx = num
        AddPad(getNoteName(notenum + c - 1 - d), a + c - 1 - d) -- pad_id = loc, pad_num = num
        AddNoteFilter(notenum + c - 1 - d, pad_num)
        AddSampleFromArrange(Pad[a + c - 1 - d].Pad_Num, 2, a + c - 1 - d, filenamebuf, start_offset, end_offset, take_pitch, getNoteName(notenum + c - 1 - d))
      elseif Pad[a + c - 1 - d].Pad_Num then
        CountPadFX(Pad[a + c - 1 - d].Pad_Num) -- padfx_idx = num
        local found = false
        for rs5k_pos = 1, padfx_idx do
          local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. Pad[a + c - 1 - d].Pad_Num - 1) -- 0 based
          local _, find_rs5k = r.TrackFX_GetNamedConfigParm(track, pad_id, "container_item." .. rs5k_pos - 1) -- 0 based
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
            end_offset, take_pitch, getNoteName(notenum + c - 1 - d))
        end
      end
    r.SetTrackMIDINoteNameEx(0, track, notenum + c - 1 - d, 0, 'test' .. notenum + c - 1 - d) -- rename in ME
    ::NEXT::
  end
  Take_GUID = nil
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
    if r.ImGui_MenuItem(ctx, "Set Pad's Output Pin Mappings##" .. a) then
      r.Undo_BeginBlock()
      local retval, chan_num = r.GetUserInputs('Set Stereo Output Channel', 1, 'Left or Right Output Channel Number', 2)
      if not retval then chan_num = nil end
      if SELECTED then
        for k, v in pairs(SELECTED) do
          UpdatePadID()
          local k = tonumber(k)
          if Pad[k] then 
            SetOutputPin(k, chan_num)
          end
        end
        SELECTED = nil
      else  
        SetOutputPin(a, chan_num)
      end
      EndUndoBlock("SET PAD'S OUTPUT PINS")
    end
    if r.ImGui_MenuItem(ctx, 'Explode Pad to Track##' .. a) then
      r.Undo_BeginBlock()
      local retval, chan_num = r.GetUserInputs('Set Stereo Output Channel', 1, 'Left or Right Output Channel Number', 4)
      if not retval then chan_num = nil end
      if SELECTED then
        SetOutputPin(a, chan_num)
        for k, v in pairs(SELECTED) do
          UpdatePadID()
          local k = tonumber(k)
          if Pad[k] then 
            SetOutputPin(k, chan_num)
            Explode = true
          end
        end
        if Explode then
          ExplodePadToTrackViaInput(chan_num)
        end
        SELECTED = nil
      elseif Pad[a] then
        SetOutputPin(a, chan_num)
        ExplodePadToTrackViaInput(chan_num)
      end
      EndUndoBlock("SET PAD'S OUTPUT PINS")
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
      GetDrumMachineIdx(track)
      CountPads()                                                          -- pads_idx = num
      r.Undo_BeginBlock()
      r.PreventUIRefresh(1)
      for i = 1, pads_idx do
        local _, clear_pad = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. 0) -- 0 based
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
      local rv, bus_guid = r.GetProjExtState(0, 'Suzuki_SetNSend_ch', track_guid .. 'bus_guid')
      local find_bus = track_from_guid_str(0, bus_guid)
      local snd_num = r.GetTrackNumSends(track, 0)
      local drum_track = track
      if find_bus ~= nil and snd_num > 0 then
        for i = snd_num, 1, -1 do -- 1 based
          local dst_track = r.GetTrackSendInfo_Value(track, 0, i - 1, 'P_DESTTRACK') -- 0 based
          r.DeleteTrack(dst_track)
        end
        Children_GUID = nil
        r.SetMediaTrackInfo_Value(drum_track, 'I_SELECTED', 1) -- select drum track
        r.DeleteTrack(find_bus)
      end
      r.PreventUIRefresh(-1)
      EndUndoBlock("CLEAR ALL PADS")
    end
    if r.ImGui_MenuItem(ctx, 'Toggle Open FX Chain Window') then
      local rv, pc = r.TrackFX_GetNamedConfigParm(track, parent_id, "parent_container")
      if not rv then
        if r.TrackFX_GetOpen(track, parent_id) then
          r.TrackFX_Show(track, parent_id, 0)
        else
          r.TrackFX_Show(track, parent_id, 1)
        end
      else
        if r.TrackFX_GetOpen(track, pc) then
          r.TrackFX_Show(track, pc, 2)
          while rv do -- to close fx chain until the root
            r.TrackFX_Show(track, pc, 0)
            rv, pc = r.TrackFX_GetNamedConfigParm(track, pc, "parent_container")
          end
        else
          r.TrackFX_Show(track, pc, 3)
        end
      end
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

--- outside of pads click action
function FXLIST()
  if r.ImGui_IsMouseClicked(ctx, 1) and not OnPad then
    if not r.ImGui_IsPopupOpen(ctx, "FX LIST") then
      r.ImGui_OpenPopup(ctx, "FX LIST")
    end
  end

  if r.ImGui_BeginPopup(ctx, "FX LIST") then
    Frame()
    r.ImGui_EndPopup(ctx)
  end
  OnPad = false
end

-- Double Click
function DoubleClickActions(loopmin, loopmax)
  if r.ImGui_IsMouseDoubleClicked(ctx, 0) and not OnPad and ALT then
    if SELECTED then
      SELECTED = nil
    else
      SELECTED = {}
      for a = 1, 128 do
        SELECTED[tostring(a)] = true
      end
    end
  elseif SHIFT and r.ImGui_IsMouseDoubleClicked(ctx, 0) and loopmin then
    local found = false
    for f = loopmin, loopmax do
      if SELECTED and SELECTED[tostring(f)] then
        found = true
        break 
      end
    end
    if SELECTED and found then -- unselect
      for a = loopmin, loopmax do
        SELECTED[tostring(a)] = nil
      end
    else
      if not SELECTED then
        SELECTED = {}
      end
      for a = loopmin, loopmax do
        SELECTED[tostring(a)] = true
      end
    end
  end
  OnPad = false
end