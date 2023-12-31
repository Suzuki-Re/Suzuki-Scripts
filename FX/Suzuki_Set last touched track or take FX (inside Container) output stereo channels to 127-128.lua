-- @description Set last touched track or take FX (inside Container) output stereo channels to 127-128
-- @author Suzuki
-- @license GPL v3
-- @version 1.0
-- @changelog Initial Release
-- @about Using v7.07 API

local r = reaper

local retval, trackidx, itemidx, takeidx, fxidx, parm = r.GetTouchedOrFocusedFX(0) -- 0 based
local track = r.CSurf_TrackFromID(trackidx + 1, false) -- 1 based

local left = (16 - 1) * 2 -- each block has 16 stereo channel, which one?
local right = left + 1

r.Undo_BeginBlock()
if itemidx ~= -1 then -- take FX
  local item = r.GetMediaItem(0, itemidx)
  local take = r.GetMediaItemTake(item, takeidx)
  local isincontainer, parent_container = r.TakeFX_GetNamedConfigParm(take, fxidx, 'parent_container')
  if isincontainer then
    local _, hm_cch = r.TakeFX_GetNamedConfigParm(take, parent_container, 'container_nch')
    if 128 > tonumber(hm_cch) then
        r.TakeFX_SetNamedConfigParm(take, parent_container, 'container_nch', 128)
    end
  else
    local hm_ch = r.GetMediaItemTakeInfo_Value(take, 'I_TAKEFX_NCH')
    if 128 > tonumber(hm_ch) then
        r.SetMediaItemTakeInfo_Value(take, 'I_TAKEFX_NCH', 128)
    end
  end
    r.TakeFX_SetPinMappings(take, fxidx, 1, 0, 0, 0) -- remove the current mappings
    r.TakeFX_SetPinMappings(take, fxidx, 1, 1, 0, 0)
    r.TakeFX_SetPinMappings(take, fxidx, 1, 0 + 0x1000000, 0, 2^left) -- #3 output 1, #4 pin 0 left (add 0x1000000 for 3) and 4)), #6 set hi32bits for even number blocks, 2) and 4)
    r.TakeFX_SetPinMappings(take, fxidx, 1, 1 + 0x1000000, 0, 2^right) -- #4 pin 1 right
else --  track FX
  local isincontainer, parent_container = r.TrackFX_GetNamedConfigParm(track, fxidx, 'parent_container')  
  if isincontainer then
    local _, hm_cch = r.TrackFX_GetNamedConfigParm(track, parent_container, 'container_nch')
    if 128 > tonumber(hm_cch) then
          r.TrackFX_SetNamedConfigParm(track, parent_container, 'container_nch', 128)
    end
  else
    local hm_ch = r.GetMediaTrackInfo_Value(track, 'I_NCHAN')
    if 128 > tonumber(hm_ch) then
          r.SetMediaTrackInfo_Value(track, 'I_NCHAN', 128)
    end
  end
    r.TrackFX_SetPinMappings(track, fxidx, 1, 0, 0, 0) -- remove the current mappings
    r.TrackFX_SetPinMappings(track, fxidx, 1, 1, 0, 0)
    r.TrackFX_SetPinMappings(track, fxidx, 1, 0 + 0x1000000, 0, 2^left) -- #3 output 1, #4 pin 0 left (add 0x1000000 for 3) and 4)), #6 set hi32bits for even number blocks, 2) and 4)
    r.TrackFX_SetPinMappings(track, fxidx, 1, 1 + 0x1000000, 0, 2^right) -- #4 pin 1 right
end
r.Undo_EndBlock("Set last touched FX output stereo channels to 127-128", -1)