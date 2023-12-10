-- @description Add stereo channels to last touched track or take FX (inside Container) input and output channel mappings (User Input)
-- @author Suzuki
-- @license GPL v3
-- @version 1.1
-- @changelog fixed wording
-- @about Using v7.07+ API

local r = reaper

local retval, trackidx, itemidx, takeidx, fxidx, parm = r.GetTouchedOrFocusedFX(0) -- 0 based
local track = r.CSurf_TrackFromID(trackidx + 1, false) -- 1 based

local retval, chan_num = r.GetUserInputs('Add Stereo Input/Output Channels', 2, 'Left or Right Input Channel Number,Left or Right Output Channel Number', '2,2')
local inchan_num, outchan_num = chan_num:match("([^,]+),([^,]+)")

local innum = tonumber(inchan_num)
local outnum = tonumber(outchan_num)
if innum == nil or outnum == nil then
  error("Channel number must be a number") 
end

local inchan_num = math.floor(tonumber(inchan_num) + 0.5)  
local inchan_num = math.max(1, math.min(tonumber(inchan_num), 128))
local inblock_num = math.floor((inchan_num - 1) / 32) + 1 -- channels can be divided into 4 blocks, 1)1-32, 2)33-64, 3)65-96, 4)97-128
local inch_num = inchan_num

local outchan_num = math.floor(tonumber(outchan_num) + 0.5)  
local outchan_num = math.max(1, math.min(tonumber(outchan_num), 128))
local outblock_num = math.floor((outchan_num - 1) / 32) + 1 -- channels can be divided into 4 blocks, 1)1-32, 2)33-64, 3)65-96, 4)97-128
local outch_num = outchan_num

local ch_num = inch_num > outch_num and inch_num or outch_num

if inblock_num == 2 then
  inchan_num = inchan_num - 32
elseif inblock_num == 3 then
  inchan_num = inchan_num - 64
elseif inblock_num == 4 then
  inchan_num = inchan_num - 96
end

if outblock_num == 2 then
  outchan_num = outchan_num - 32
elseif outblock_num == 3 then
  outchan_num = outchan_num - 64
elseif outblock_num == 4 then
  outchan_num = outchan_num - 96
end

if inchan_num % 2 == 1 then -- odd
  inchan_num = math.floor(inchan_num / 2) + 1
else -- even
  inchan_num = math.floor(inchan_num / 2)  
end

if outchan_num % 2 == 1 then -- odd
  outchan_num = math.floor(outchan_num / 2) + 1
else -- even
  outchan_num = math.floor(outchan_num / 2)  
end

local in_left = (inchan_num - 1) * 2 -- each block has 16 stereo channel, which one?
local in_right = in_left + 1

local out_left = (outchan_num - 1) * 2 -- each block has 16 stereo channel, which one?
local out_right = out_left + 1

local function TakeFX_SetInPin(a, b, c, d, e, f, g, h)
  r.TakeFX_SetPinMappings(take, fxidx, 0, 0, low32inl + a, high32inl + e) -- #3 output 1, #4 pin 0 left
  r.TakeFX_SetPinMappings(take, fxidx, 0, 1, low32inr + b, high32inr + f) -- #4 pin 1 righ
  r.TakeFX_SetPinMappings(take, fxidx, 0, 0 + 0x1000000, n_low32inl + c, n_high32inl + g) -- #3 output 1, #4 pin 0 left and add 0x1000000 to #4 for the second half blocks
  r.TakeFX_SetPinMappings(take, fxidx, 0, 1 + 0x1000000, n_low32inr + d, n_high32inr + h) -- #4 pin 1 right
end

local function TrackFX_SetInPin(a, b, c, d, e, f, g, h)
  r.TrackFX_SetPinMappings(track, fxidx, 0, 0, low32inl + a, high32inl + e) -- #3 output 1, #4 pin 0 left
  r.TrackFX_SetPinMappings(track, fxidx, 0, 1, low32inr + b, high32inr + f) -- #4 pin 1 righ
  r.TrackFX_SetPinMappings(track, fxidx, 0, 0 + 0x1000000, n_low32inl + c, n_high32inl + g) -- #3 output 1, #4 pin 0 left and add 0x1000000 to #4 for the second half blocks
  r.TrackFX_SetPinMappings(track, fxidx, 0, 1 + 0x1000000, n_low32inr + d, n_high32inr + h) -- #4 pin 1 right
end

local function TakeFX_SetOutPin(a, b, c, d, e, f, g, h)
  r.TakeFX_SetPinMappings(take, fxidx, 1, 0, low32outl + a, high32outl + e) -- #3 output 1, #4 pin 0 left
  r.TakeFX_SetPinMappings(take, fxidx, 1, 1, low32outr + b, high32outr + f) -- #4 pin 1 righ
  r.TakeFX_SetPinMappings(take, fxidx, 1, 0 + 0x1000000, n_low32outl + c, n_high32outl + g) -- #3 output 1, #4 pin 0 left and add 0x1000000 to #4 for the second half blocks
  r.TakeFX_SetPinMappings(take, fxidx, 1, 1 + 0x1000000, n_low32outr + d, n_high32outr + h) -- #4 pin 1 right
end

local function TrackFX_SetOutPin(a, b, c, d, e, f, g, h)
  r.TrackFX_SetPinMappings(track, fxidx, 1, 0, low32outl + a, high32outl + e) -- #3 output 1, #4 pin 0 left
  r.TrackFX_SetPinMappings(track, fxidx, 1, 1, low32outr + b, high32outr + f) -- #4 pin 1 righ
  r.TrackFX_SetPinMappings(track, fxidx, 1, 0 + 0x1000000, n_low32outl + c, n_high32outl + g) -- #3 output 1, #4 pin 0 left and add 0x1000000 to #4 for the second half blocks
  r.TrackFX_SetPinMappings(track, fxidx, 1, 1 + 0x1000000, n_low32outr + d, n_high32outr + h) -- #4 pin 1 right
end

r.Undo_BeginBlock()
if itemidx ~= -1 then -- take FX
  local item = r.GetMediaItem(0, itemidx)
  local take = r.GetMediaItemTake(item, takeidx)
  local isincontainer, parent_container = r.TakeFX_GetNamedConfigParm(take, fxidx, 'parent_container')
  if isincontainer then
    local _, hm_cch = r.TakeFX_GetNamedConfigParm(take, parent_container, 'container_nch')
    if ch_num > tonumber(hm_cch) then
      if ch_num % 2 == 1 then
        r.TakeFX_SetNamedConfigParm(take, parent_container, 'container_nch', ch_num + 1)
      else
        r.TakeFX_SetNamedConfigParm(take, parent_container, 'container_nch', ch_num)
      end
    end
  else
    local hm_ch = r.GetMediaItemTakeInfo_Value(take, 'I_TAKEFX_NCH')
    if ch_num > tonumber(hm_ch) then
      if ch_num % 2 == 1 then
        r.SetMediaItemTakeInfo_Value(take, 'I_TAKEFX_NCH', ch_num + 1)
      else
        r.SetMediaItemTakeInfo_Value(take, 'I_TAKEFX_NCH', ch_num)
      end
    end
  end
  low32inl, high32inl = r.TakeFX_GetPinMappings(take, fxidx, 0, 0) -- #3 0 for input, #4 0 for left and for surround increase the value accordingly
  low32inr, high32inr = r.TakeFX_GetPinMappings(take, fxidx, 0, 1) -- #3 0 for input, #4 1 for right and for surround increase the value accordingly
  n_low32inl, n_high32inl = r.TakeFX_GetPinMappings(take, fxidx, 0, 0 + 0x1000000) -- #3 0 for input, #4 0 for left + 0x1000000 for another 64bits
  n_low32inr, n_high32inr = r.TakeFX_GetPinMappings(take, fxidx, 0, 1 + 0x1000000) -- #3 0 for input, #4 1 for right
  if inblock_num % 2 == 1 then -- odd number blocks -> #5 = low32bits
    if inblock_num == 1 then -- add 0x1000000 to #4 for the second half blocks
      TakeFX_SetInPin(2^in_left, 2^in_right, 0, 0, 0, 0, 0, 0)
    else -- 3
      TakeFX_SetInPin(0, 0, 2^in_left, 2^in_right, 0, 0, 0, 0)
    end
  else -- even number blocks -> #6 = high32bits 
    if inblock_num == 2 then
      TakeFX_SetInPin(0, 0, 0, 0, 2^in_left, 2^in_right, 0, 0)
    else -- 4
      TakeFX_SetInPin(0, 0, 0, 0, 0, 0, 2^in_left, 2^in_right)
    end
  end
  low32outl, high32outl = r.TakeFX_GetPinMappings(take, fxidx, 1, 0) -- #3 1 for output, #4 0 for left and for surround increase the value accordingly
  low32outr, high32outr = r.TakeFX_GetPinMappings(take, fxidx, 1, 1) -- #3 1 for output, #4 1 for right and for surround increase the value accordingly
  n_low32outl, n_high32outl = r.TakeFX_GetPinMappings(take, fxidx, 1, 0 + 0x1000000) -- #3 1 for output, #4 0 for left + 0x1000000 for another 64bits
  n_low32outr, n_high32outr = r.TakeFX_GetPinMappings(take, fxidx, 1, 1 + 0x1000000) -- #3 1 for output, #4 1 for right
  if outblock_num % 2 == 1 then -- odd number blocks -> #5 = low32bits
    if outblock_num == 1 then -- add 0x1000000 to #4 for the second half blocks
      TakeFX_SetOutPin(2^out_left, 2^out_right, 0, 0, 0, 0, 0, 0)
    else -- 3
      TakeFX_SetOutPin(0, 0, 2^out_left, 2^out_right, 0, 0, 0, 0)
    end
  else -- even number blocks -> #6 = high32bits 
    if outblock_num == 2 then
      TakeFX_SetOutPin(0, 0, 0, 0, 2^out_left, 2^out_right, 0, 0)
    else -- 4
      TakeFX_SetOutPin(0, 0, 0, 0, 0, 0, 2^out_left, 2^out_right)
    end
  end
else --  track FX
  local isincontainer, parent_container = r.TrackFX_GetNamedConfigParm(track, fxidx, 'parent_container')  
    if isincontainer then
      local _, hm_cch = r.TrackFX_GetNamedConfigParm(track, parent_container, 'container_nch')
      if ch_num > tonumber(hm_cch) then
        if ch_num % 2 == 1 then
          r.TrackFX_SetNamedConfigParm(track, parent_container, 'container_nch', ch_num + 1)
        else
          r.TrackFX_SetNamedConfigParm(track, parent_container, 'container_nch', ch_num)
        end
      end
    else
      local hm_ch = r.GetMediaTrackInfo_Value(track, 'I_NCHAN')
      if ch_num > tonumber(hm_ch) then
        if ch_num % 2 == 1 then
          r.SetMediaTrackInfo_Value(track, 'I_NCHAN', ch_num + 1)
        else
          r.SetMediaTrackInfo_Value(track, 'I_NCHAN', ch_num)
        end
      end
    end
  low32inl, high32inl = r.TrackFX_GetPinMappings(track, fxidx, 0, 0) -- #3 0 for input, #4 0 for left
  low32inr, high32inr = r.TrackFX_GetPinMappings(track, fxidx, 0, 1) -- #3 0 for input, #4 1 for right
  n_low32inl, n_high32inl = r.TrackFX_GetPinMappings(track, fxidx, 0, 0 + 0x1000000) -- #3 0 for input, #4 0 for left + 0x1000000 for another 64bits
  n_low32inr, n_high32inr = r.TrackFX_GetPinMappings(track, fxidx, 0, 1 + 0x1000000) -- #3 0 for input, #4 1 for right
  if inblock_num % 2 == 1 then -- odd number blocks -> #5 = low32bits
    if inblock_num == 1 then -- add 0x1000000 to #4 for the second half blocks
      TrackFX_SetInPin(2^in_left, 2^in_right, 0, 0, 0, 0, 0, 0)
    else -- 3
      TrackFX_SetInPin(0, 0, 2^in_left, 2^in_right, 0, 0, 0, 0)
    end
  else -- even number blocks -> #6 = high32bits 
    if inblock_num == 2 then -- add 0x1000000 to #4 for the second half blocks
      TrackFX_SetInPin(0, 0, 0, 0, 2^in_left, 2^in_right, 0, 0)
    else -- 4
      TrackFX_SetInPin(0, 0, 0, 0, 0, 0, 2^in_left, 2^in_right)
    end
  end 
  low32outl, high32outl = r.TrackFX_GetPinMappings(track, fxidx, 1, 0) -- #3 1 for output, #4 0 for left
  low32outr, high32outr = r.TrackFX_GetPinMappings(track, fxidx, 1, 1) -- #3 1 for output, #4 1 for right
  n_low32outl, n_high32outl = r.TrackFX_GetPinMappings(track, fxidx, 1, 0 + 0x1000000) -- #3 1 for output, #4 0 for left + 0x1000000 for another 64bits
  n_low32outr, n_high32outr = r.TrackFX_GetPinMappings(track, fxidx, 1, 1 + 0x1000000) -- #3 1 for output, #4 1 for right
  if outblock_num % 2 == 1 then -- odd number blocks -> #5 = low32bits
    if outblock_num == 1 then -- add 0x1000000 to #4 for the second half blocks
      TrackFX_SetOutPin(2^out_left, 2^out_right, 0, 0, 0, 0, 0, 0)
    else -- 3
      TrackFX_SetOutPin(0, 0, 2^out_left, 2^out_right, 0, 0, 0, 0)
    end
  else -- even number blocks -> #6 = high32bits 
    if outblock_num == 2 then -- add 0x1000000 to #4 for the second half blocks
      TrackFX_SetOutPin(0, 0, 0, 0, 2^out_left, 2^out_right, 0, 0)
    else -- 4
      TrackFX_SetOutPin(0, 0, 0, 0, 0, 0, 2^out_left, 2^out_right)
    end
  end
end
r.Undo_EndBlock("Add stereo channels to last touched FX input/output channel mappings", -1)
