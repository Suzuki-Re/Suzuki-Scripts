-- @description Set last touched track or take FX (inside Container) input channel pin mappings to stereo channels (User Input)
-- @author Suzuki
-- @license GPL v3
-- @version 1.0
-- @changelog Initial Release
-- @about Using v7.07+ API

local r = reaper

local retval, trackidx, itemidx, takeidx, fxidx, parm = r.GetTouchedOrFocusedFX(0) -- 0 based
local track = r.CSurf_TrackFromID(trackidx + 1, false) -- 1 based

local retval, chan_num = r.GetUserInputs('Set Stereo Input Channel', 1, 'Left or Right Input Channel Number', '2')

local num = tonumber(chan_num)
if num == nil then
  error("Channel number must be a number") 
end

local chan_num = math.floor(tonumber(chan_num) + 0.5)  
local chan_num = math.max(1, math.min(tonumber(chan_num), 128))
local block_num = math.floor((chan_num - 1) / 32) + 1 -- channels can be divided into 4 blocks, 1)1-32, 2)33-64, 3)65-96, 4)97-128
local ch_num = chan_num
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

  r.TakeFX_SetPinMappings(take, fxidx, 0, 0, 0, 0) -- remove the current mappings
  r.TakeFX_SetPinMappings(take, fxidx, 0, 1, 0, 0)
  r.TakeFX_SetPinMappings(take, fxidx, 0, 0 + 0x1000000, 0, 0)
  r.TakeFX_SetPinMappings(take, fxidx, 0, 1 + 0x1000000, 0, 0)

  if block_num % 2 == 1 then -- odd number blocks -> #5 = low32bits and #6 = 0
    r.TakeFX_SetPinMappings(take, fxidx, 0, 0 + is_secondhalf, 2^left, 0) -- #3 input 0, #4 pin 0 left
    r.TakeFX_SetPinMappings(take, fxidx, 0, 1 + is_secondhalf, 2^right, 0) -- #4 pin 1 right
  else -- even number blocks -> #5 = 0 and #6 = high32bits 
    r.TakeFX_SetPinMappings(take, fxidx, 0, 0 + is_secondhalf, 0, 2^left) -- #3 input 0, #4 pin 0 left
    r.TakeFX_SetPinMappings(take, fxidx, 0, 1 + is_secondhalf, 0, 2^right) -- #4 pin 1 right
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

  r.TrackFX_SetPinMappings(track, fxidx, 0, 0, 0, 0) -- remove the current mappings
  r.TrackFX_SetPinMappings(track, fxidx, 0, 1, 0, 0)
  r.TrackFX_SetPinMappings(track, fxidx, 0, 0 + 0x1000000, 0, 0)
  r.TrackFX_SetPinMappings(track, fxidx, 0, 1 + 0x1000000, 0, 0)

  if block_num % 2 == 1 then -- odd number blocks -> #5 = low32bits and #6 = 0
    r.TrackFX_SetPinMappings(track, fxidx, 0, 0 + is_secondhalf, 2^left, 0) -- #3 input 0, #4 pin 0 left
    r.TrackFX_SetPinMappings(track, fxidx, 0, 1 + is_secondhalf, 2^right, 0) -- #4 pin 1 right
  else -- even number blocks -> #5 = 0 and #6 = high32bits 
    r.TrackFX_SetPinMappings(track, fxidx, 0, 0 + is_secondhalf, 0, 2^left) -- #3 input 0, #4 pin 0 left
    r.TrackFX_SetPinMappings(track, fxidx, 0, 1 + is_secondhalf, 0, 2^right) -- #4 pin 1 right
  end
end
r.Undo_EndBlock("Set last touched FX input channel pin mappings to stereo", -1)