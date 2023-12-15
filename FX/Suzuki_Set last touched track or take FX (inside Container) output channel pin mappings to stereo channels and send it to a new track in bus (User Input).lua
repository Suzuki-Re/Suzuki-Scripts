-- @description Set last touched track or take FX (inside Container) output channel pin mappings to stereo channels and send it to a new track in bus (User Input)
-- @author Suzuki
-- @license GPL v3
-- @version 1.0
-- @changelog Initial Release
-- @about Using v7.07+ API. Set FX's output and send it to a new track in a bus track via user input. If there's already the same channel send, it won't create a new track.

local r = reaper

local retval, trackidx, itemidx, takeidx, fxidx, parm = r.GetTouchedOrFocusedFX(0) -- 0 based
local track = r.CSurf_TrackFromID(trackidx + 1, false) -- 1 based
local track_guid = r.GetTrackGUID(track)

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

local retval, chan_num = r.GetUserInputs('Set Stereo Output Channel', 1, 'Left or Right Output Channel Number', '2')

local num = tonumber(chan_num)
if num == nil then
  error("Channel number must be a number") 
end

local chan_num = math.floor(tonumber(chan_num) + 0.5)  
local chan_num = math.max(1, math.min(tonumber(chan_num), 128))
local block_num = math.floor((chan_num - 1) / 32) + 1 -- channels can be divided into 4 blocks, 1)1-32, 2)33-64, 3)65-96, 4)97-128
local ch_num = chan_num
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
  r.SetMediaTrackInfo_Value(track, 'B_MAINSEND', 0) -- turn off master send
end

r.Undo_BeginBlock()
if itemidx ~= -1 then -- take FX
  local item = r.GetMediaItem(0, itemidx)
  local take = r.GetMediaItemTake(item, takeidx)
  local isincontainer, parent_container = r.TakeFX_GetNamedConfigParm(take, fxidx, 'parent_container')
  if isincontainer then
    local _, hm_cch = r.TakeFX_GetNamedConfigParm(take, parent_container, 'container_nch')
    local _, hm_cch_out = r.TakeFX_GetNamedConfigParm(take, parent_container, 'container_nch_out')
    if ch_num > tonumber(hm_cch) or ch_num > tonumber(hm_cch_out) then
      r.SetMediaItemTakeInfo_Value(track, 'I_TAKEFX_NCH', ch_num)
      r.TakeFX_SetNamedConfigParm(take, parent_container, 'container_nch', ch_num)
      r.TakeFX_SetNamedConfigParm(take, parent_container, 'container_nch_out', ch_num)
    end
  else
    local hm_ch = r.GetMediaItemTakeInfo_Value(take, 'I_TAKEFX_NCH')
    if ch_num > tonumber(hm_ch) then
      r.SetMediaItemTakeInfo_Value(take, 'I_TAKEFX_NCH', ch_num)
    end
  end
  r.TakeFX_SetPinMappings(take, fxidx, 1, 0, 0, 0) -- remove the current mappings
  r.TakeFX_SetPinMappings(take, fxidx, 1, 1, 0, 0)
  r.TakeFX_SetPinMappings(take, fxidx, 1, 0 + 0x1000000, 0, 0)
  r.TakeFX_SetPinMappings(take, fxidx, 1, 1 + 0x1000000, 0, 0)

  if block_num % 2 == 1 then -- odd number blocks -> #5 = low32bits and #6 = 0
    r.TakeFX_SetPinMappings(take, fxidx, 1, 0 + is_secondhalf, 2^left, 0) -- #3 input 0, #4 pin 0 left
    r.TakeFX_SetPinMappings(take, fxidx, 1, 1 + is_secondhalf, 2^right, 0) -- #4 pin 1 right
  else -- even number blocks -> #5 = 0 and #6 = high32bits 
    r.TakeFX_SetPinMappings(take, fxidx, 1, 0 + is_secondhalf, 0, 2^left) -- #3 input 0, #4 pin 0 left
    r.TakeFX_SetPinMappings(take, fxidx, 1, 1 + is_secondhalf, 0, 2^right) -- #4 pin 1 right
  end
else --  track FX
  local isincontainer, parent_container = r.TrackFX_GetNamedConfigParm(track, fxidx, 'parent_container')
  if isincontainer then
    local _, hm_cch = r.TrackFX_GetNamedConfigParm(track, parent_container, 'container_nch')
    local _, hm_cch_out = r.TrackFX_GetNamedConfigParm(track, parent_container, 'container_nch_out')
    if ch_num > tonumber(hm_cch) or ch_num > tonumber(hm_cch_out) then
      r.SetMediaTrackInfo_Value(track, 'I_NCHAN', ch_num)
      r.TrackFX_SetNamedConfigParm(track, parent_container, 'container_nch', ch_num)
      r.TrackFX_SetNamedConfigParm(track, parent_container, 'container_nch_out', ch_num)
    end
  else
    local hm_ch = r.GetMediaTrackInfo_Value(track, 'I_NCHAN')
    if ch_num > tonumber(hm_ch) then
      r.SetMediaTrackInfo_Value(track, 'I_NCHAN', ch_num)
    end
  end

  r.TrackFX_SetPinMappings(track, fxidx, 1, 0, 0, 0) -- remove the current mappings
  r.TrackFX_SetPinMappings(track, fxidx, 1, 1, 0, 0)
  r.TrackFX_SetPinMappings(track, fxidx, 1, 0 + 0x1000000, 0, 0)
  r.TrackFX_SetPinMappings(track, fxidx, 1, 1 + 0x1000000, 0, 0)

  if block_num % 2 == 1 then -- odd number blocks -> #5 = low32bits and #6 = 0
    r.TrackFX_SetPinMappings(track, fxidx, 1, 0 + is_secondhalf, 2^left, 0) -- #3 output 1, #4 pin 0 left
    r.TrackFX_SetPinMappings(track, fxidx, 1, 1 + is_secondhalf, 2^right, 0) -- #4 pin 1 right
  else -- even number blocks -> #5 = 0 and #6 = high32bits 
    r.TrackFX_SetPinMappings(track, fxidx, 1, 0 + is_secondhalf, 0, 2^left) -- #3 output 1, #4 pin 0 left
    r.TrackFX_SetPinMappings(track, fxidx, 1, 1 + is_secondhalf, 0, 2^right) -- #4 pin 1 right
  end
end

local rv, bus_guid = r.GetProjExtState(0, 'Suzuki_SetNSend_ch', track_guid .. 'bus_guid')
local find_bus = track_from_guid_str(0, bus_guid)

if rv ~= 0 and find_bus ~= nil then -- 2nd+ times
  if not retval then return end
  local bus_track = track_from_guid_str(0, bus_guid)
  local bus_idx = r.CSurf_TrackToID(bus_track, false)
  local rv, pExtStateStr = r.GetProjExtState(0, "Suzuki_SetNSend_ch", track_guid .. "child_guid") -- read pickled table string value from project extended states
  Children_GUID = unpickle(pExtStateStr) -- unpickle extended state string value back into a table
  local first_child_track_guid = Children_GUID.child_guid[1]
  local first_child_track = track_from_guid_str(0, first_child_track_guid)
  local count = 0
  local rcv_input = tonumber(ch_num - 2)
  for i = 1, #Children_GUID.child_guid do
    local child_track_guid = Children_GUID.child_guid[i]
    local child_track = track_from_guid_str(0, child_track_guid)
    if not child_track then
      table.remove(Children_GUID.child_guid, i)
      table.remove(Children_GUID.rcv_num, i)
      i = i - 1 
    end
  end
  if first_child_track ~= nil then
    for i = 1, r.GetTrackNumSends(track, 0) do -- 1 based
      local children = r.CSurf_TrackFromID(bus_idx + i, false)
      if children == nil then match = false goto dokoka end
      if Children_GUID.rcv_num[i] == rcv_input then -- match src number
        match = true
        break
      end
      local src_chan = r.GetTrackSendInfo_Value(track, 0, i - 1, 'I_SRCCHAN') -- 0 based
      Children_GUID.rcv_num[i] = src_chan
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
      local rcv_num = r.GetTrackSendInfo_Value(dst_track, -1, 0, 'I_SRCCHAN')
      Children_GUID.rcv_num[count + 1] = rcv_num
      local child_guid = r.GetTrackGUID(dst_track)
      Children_GUID.child_guid[count + 1] = child_guid
      r.SetMediaTrackInfo_Value(bus_track, 'I_FOLDERDEPTH', 1) -- parent folder
      for i = 1, count + 1 do
        local reset_track = r.CSurf_TrackFromID(bus_idx + i, false)
        r.SetMediaTrackInfo_Value(reset_track, 'I_FOLDERDEPTH', 0) -- last child track
      end
      r.SetMediaTrackInfo_Value(dst_track, 'I_FOLDERDEPTH', -1) -- last child track
    end
    local pExtStateStr = pickle(Children_GUID) -- pickle table to string
    r.SetProjExtState(0, "Suzuki_SetNSend_ch", track_guid .. "child_guid", pExtStateStr) -- write pickled table as string to project extended state
  else -- no child
    CreateNewChildTrack(trackidx + 2, 1)
    local child_track = r.CSurf_TrackFromID(trackidx + 3, false)
    SetTrackSend(bus_track, child_track)
    local rcv_num = r.GetTrackSendInfo_Value(child_track, -1, 0, 'I_SRCCHAN')
    Children_GUID.rcv_num[1] = rcv_num
    local child_guid = r.GetTrackGUID(child_track)
    Children_GUID.child_guid[1] = child_guid
    r.SetMediaTrackInfo_Value(bus_track, 'I_FOLDERDEPTH', 1) -- parent folder
    r.SetMediaTrackInfo_Value(child_track, 'I_FOLDERDEPTH', -1) -- last child track
    local pExtStateStr = pickle(Children_GUID) -- pickle table to string
    r.SetProjExtState(0, "Suzuki_SetNSend_ch", track_guid .. "child_guid", pExtStateStr) -- write pickled table as string to project extended state
  end
  r.SetProjExtState(0, 'Suzuki_SetNSend_ch', track_guid .. 'bus_guid', bus_guid)
else -- no "bus" track in the project
  if not retval then return end
  r.InsertTrackAtIndex(trackidx + 1, false)
  local bus_track = r.CSurf_TrackFromID(trackidx + 2, false)
  r.GetSetMediaTrackInfo_String(bus_track, 'P_NAME', "Bus", true)
  local bus_guid = r.GetTrackGUID(bus_track)
  r.SetProjExtState(0, 'Suzuki_SetNSend_ch', track_guid .. 'bus_guid', bus_guid)
  CreateNewChildTrack(trackidx + 2, 1)
  local child_track = r.CSurf_TrackFromID(trackidx + 3, false)
  SetTrackSend(bus_track, child_track)
  local rcv_num = r.GetTrackSendInfo_Value(child_track, -1, 0, 'I_SRCCHAN')
  Children_GUID.rcv_num = {}
  Children_GUID.rcv_num[1] = rcv_num
  r.SetMediaTrackInfo_Value(bus_track, 'I_FOLDERDEPTH', 1) -- parent folder
  r.SetMediaTrackInfo_Value(child_track, 'I_FOLDERDEPTH', -1) -- last child track
  local pExtStateStr = pickle(Children_GUID) -- pickle table to string
  r.SetProjExtState(0, "Suzuki_SetNSend_ch", track_guid .. "child_guid", pExtStateStr) -- write pickled table as string to project extended state
end
r.Undo_EndBlock("Set last touched FX output channel pin mappings to stereo and route it to new track", -1)