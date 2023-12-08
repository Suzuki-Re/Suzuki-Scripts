-- @description Add stereo channels to last touched track or take FX (inside Container) output channel mapping (User Input)
-- @author Suzuki
-- @license GPL v3
-- @version 1.0
-- @changelog Initial Release
-- @about Using v7.07+ API

local r = reaper

local retval, trackidx, itemidx, takeidx, fxidx, parm = r.GetTouchedOrFocusedFX(0) -- 0 based
local track = r.CSurf_TrackFromID(trackidx + 1, false) -- 1 based
local item = r.GetMediaItem(0, itemidx)
local take = r.GetMediaItemTake(item, takeidx)

local retval, chan_num = r.GetUserInputs('Set Stereo Output Channel', 1, 'Left or Right Output Channel Number', '2')

local num = tonumber(chan_num)
if num == nil then
  error("Channel number must be a number") 
end

local chan_num = math.floor(tonumber(chan_num) + 0.5)  
local chan_num = math.max(1, math.min(tonumber(chan_num), 128))
local block_num = math.floor((chan_num - 1) / 32) + 1 -- channels can be divided into 4 blocks, 1)1-32, 2)33-64, 3)65-96, 4)97-128
local ch_num = chan_num

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

local function TakeFX_SetPin(a, b, c, d, e, f, g, h)
  r.TakeFX_SetPinMappings(take, fxidx, 1, 0, low32l + a, high32l + e) -- #3 output 1, #4 pin 0 left
  r.TakeFX_SetPinMappings(take, fxidx, 1, 1, low32r + b, high32r + f) -- #4 pin 1 righ
  r.TakeFX_SetPinMappings(take, fxidx, 1, 0 + 0x1000000, n_low32l + c, n_high32l + g) -- #3 output 1, #4 pin 0 left and add 0x1000000 to #4 for the second half blocks
  r.TakeFX_SetPinMappings(take, fxidx, 1, 1 + 0x1000000, n_low32r + d, n_high32r + h) -- #4 pin 1 right
end

local function TrackFX_SetPin(a, b, c, d, e, f, g, h)
  r.TrackFX_SetPinMappings(track, fxidx, 1, 0, low32l + a, high32l + e) -- #3 output 1, #4 pin 0 left
  r.TrackFX_SetPinMappings(track, fxidx, 1, 1, low32r + b, high32r + f) -- #4 pin 1 righ
  r.TrackFX_SetPinMappings(track, fxidx, 1, 0 + 0x1000000, n_low32l + c, n_high32l + g) -- #3 output 1, #4 pin 0 left and add 0x1000000 to #4 for the second half blocks
  r.TrackFX_SetPinMappings(track, fxidx, 1, 1 + 0x1000000, n_low32r + d, n_high32r + h) -- #4 pin 1 right
end

if itemidx ~= -1 then -- take FX
  local isincontainer, parent_container = r.TakeFX_GetNamedConfigParm(take, fxidx, 'parent_container')
  if isincontainer then
    local _, hm_cch = r.TakeFX_GetNamedConfigParm(take, parent_container, 'container_nch')
    if ch_num > hm_cch then
      if ch_num % 2 == 1 then
        r.TakeFX_SetNamedConfigParm(take, parent_container, 'container_nch', ch_num + 1)
      else
        r.TakeFX_SetNamedConfigParm(take, parent_container, 'container_nch', ch_num)
      end
    end
  else
    local hm_ch = r.GetMediaItemTakeInfo_Value(take, 'I_TAKEFX_NCH')
    if ch_num > hm_ch then
      if ch_num % 2 == 1 then
        r.SetMediaItemTakeInfo_Value(take, 'I_TAKEFX_NCH', ch_num + 1)
      else
        r.SetMediaItemTakeInfo_Value(take, 'I_TAKEFX_NCH', ch_num)
      end
    end
  end
  low32l, high32l = r.TakeFX_GetPinMappings(take, fxidx, 1, 0) -- #3 1 for output, #4 0 for left and for surround increase the value accordingly
  low32r, high32r = r.TakeFX_GetPinMappings(take, fxidx, 1, 1) -- #3 1 for output, #4 1 for right and for surround increase the value accordingly
  n_low32l, n_high32l = r.TakeFX_GetPinMappings(take, fxidx, 1, 0 + 0x1000000) -- #3 1 for output, #4 0 for left + 0x1000000 for another 64bits
  n_low32r, n_high32r = r.TakeFX_GetPinMappings(take, fxidx, 1, 1 + 0x1000000) -- #3 1 for output, #4 1 for right
  if block_num % 2 == 1 then -- odd number blocks -> #5 = low32bits
    if block_num == 1 then -- add 0x1000000 to #4 for the second half blocks
      TakeFX_SetPin(2^left, 2^right, 0, 0, 0, 0, 0, 0)
    else -- 3
      TakeFX_SetPin(0, 0, 2^left, 2^right, 0, 0, 0, 0)
    end
  else -- even number blocks -> #6 = high32bits 
    if block_num == 2 then
      TakeFX_SetPin(0, 0, 0, 0, 2^left, 2^right, 0, 0)
    else -- 4
      TakeFX_SetPin(0, 0, 0, 0, 0, 0, 2^left, 2^right)
    end
  end
else --  track FX
  local isincontainer, parent_container = r.TrackFX_GetNamedConfigParm(track, fxidx, 'parent_container')  
    if isincontainer then
      local _, hm_cch = r.TrackFX_GetNamedConfigParm(track, parent_container, 'container_nch')
      if ch_num > hm_cch then
        if ch_num % 2 == 1 then
          r.TrackFX_SetNamedConfigParm(track, parent_container, 'container_nch', ch_num + 1)
        else
          r.TrackFX_SetNamedConfigParm(track, parent_container, 'container_nch', ch_num)
        end
      end
    else
      local hm_ch = r.GetMediaTrackInfo_Value(track, 'I_NCHAN')
      if ch_num > hm_ch then
        if ch_num % 2 == 1 then
          r.SetMediaTrackInfo_Value(track, 'I_NCHAN', ch_num + 1)
        else
          r.SetMediaTrackInfo_Value(track, 'I_NCHAN', ch_num)
        end
      end
    end
  low32l, high32l = r.TrackFX_GetPinMappings(track, fxidx, 1, 0) -- #3 1 for output, #4 0 for left
  low32r, high32r = r.TrackFX_GetPinMappings(track, fxidx, 1, 1) -- #3 1 for output, #4 1 for right
  n_low32l, n_high32l = r.TrackFX_GetPinMappings(track, fxidx, 1, 0 + 0x1000000) -- #3 1 for output, #4 0 for left + 0x1000000 for another 64bits
  n_low32r, n_high32r = r.TrackFX_GetPinMappings(track, fxidx, 1, 1 + 0x1000000) -- #3 1 for output, #4 1 for right
  if block_num % 2 == 1 then -- odd number blocks -> #5 = low32bits
    if block_num == 1 then -- add 0x1000000 to #4 for the second half blocks
      TrackFX_SetPin(2^left, 2^right, 0, 0, 0, 0, 0, 0)
    else -- 3
      TrackFX_SetPin(0, 0, 2^left, 2^right, 0, 0, 0, 0)
    end
  else -- even number blocks -> #6 = high32bits 
    if block_num == 2 then -- add 0x1000000 to #4 for the second half blocks
      TrackFX_SetPin(0, 0, 0, 0, 2^left, 2^right, 0, 0)
    else -- 4
      TrackFX_SetPin(0, 0, 0, 0, 0, 0, 2^left, 2^right)
    end
  end
end
