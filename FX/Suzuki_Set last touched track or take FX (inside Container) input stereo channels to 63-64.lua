-- @description Set last touched track or take FX (inside Container) input stereo channels to 63-64
-- @author Suzuki
-- @license GPL v3
-- @version 1.1
-- @changelog Forgot to add container fx and take fx

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
    if 64 > tonumber(hm_cch) then
        r.TakeFX_SetNamedConfigParm(take, parent_container, 'container_nch', 64)
    end
  else
    local hm_ch = r.GetMediaItemTakeInfo_Value(take, 'I_TAKEFX_NCH')
    if 64 > tonumber(hm_ch) then
        r.SetMediaItemTakeInfo_Value(take, 'I_TAKEFX_NCH', 64)
    end
  end
    r.TakeFX_SetPinMappings(take, fxidx, 0, 0, 0, 2^left) -- remove the current mappings
    r.TakeFX_SetPinMappings(take, fxidx, 0, 1, 0, 2^right)
    r.TakeFX_SetPinMappings(take, fxidx, 0, 0 + 0x1000000, 0, 0) -- #3 output 1, #4 pin 0 left (add 0x1000000 for 3) and 4)), #6 set hi32bits for even number blocks, 2) and 4)
    r.TakeFX_SetPinMappings(take, fxidx, 0, 1 + 0x1000000, 0, 0) -- #4 pin 1 right
else --  track FX
  local isincontainer, parent_container = r.TrackFX_GetNamedConfigParm(track, fxidx, 'parent_container')  
  if isincontainer then
    local _, hm_cch = r.TrackFX_GetNamedConfigParm(track, parent_container, 'container_nch')
    if 64 > tonumber(hm_cch) then
          r.TrackFX_SetNamedConfigParm(track, parent_container, 'container_nch', 64)
    end
  else
    local hm_ch = r.GetMediaTrackInfo_Value(track, 'I_NCHAN')
    if 64 > tonumber(hm_ch) then
          r.SetMediaTrackInfo_Value(track, 'I_NCHAN', 64)
    end
  end
  r.TrackFX_SetPinMappings(track, fxidx, 0, 0, 0, 2^left) -- remove the current mappings
  r.TrackFX_SetPinMappings(track, fxidx, 0, 1, 0, 2^right)
  r.TrackFX_SetPinMappings(track, fxidx, 0, 0 + 0x1000000, 0, 0) -- #3 output 1, #4 pin 0 left (add 0x1000000 for 3) and 4)), #6 set hi32bits for even number blocks, 2) and 4)
  r.TrackFX_SetPinMappings(track, fxidx, 0, 1 + 0x1000000, 0, 0) -- #4 pin 1 right
end
r.Undo_EndBlock("Set last touched FX input stereo channels to 63-64", -1)
