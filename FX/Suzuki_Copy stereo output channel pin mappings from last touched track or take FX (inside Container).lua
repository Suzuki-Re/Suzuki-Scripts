-- @description Copy stereo output channel pin mappings from last touched track or take FX (inside Container)
-- @author Suzuki
-- @license GPL v3
-- @version 1.0
-- @changelog Initial Release
-- @about Using 7.07+ API, up to 128 channels

local r = reaper

local retval, trackidx, itemidx, takeidx, fxidx, parm = r.GetTouchedOrFocusedFX(0) -- 0 based
local track = r.CSurf_TrackFromID(trackidx + 1, false) -- 1 based

if itemidx ~= -1 then -- take FX
    local item = r.GetMediaItem(0, itemidx)
    local take = r.GetMediaItemTake(item, takeidx)
    local isincontainer, parent_container = r.TakeFX_GetNamedConfigParm(take, fxidx, 'parent_container')
    if isincontainer then
        _, hm_ch = r.TakeFX_GetNamedConfigParm(take, parent_container, 'container_nch')
    else
        hm_ch = r.GetMediaItemTakeInfo_Value(take, 'I_TAKEFX_NCH')
    end
    low32l, high32l = r.TakeFX_GetPinMappings(take, fxidx, 1, 0) -- #3 1 for output, #4 0 for left and for surround increase the value accordingly
    low32r, high32r = r.TakeFX_GetPinMappings(take, fxidx, 1, 1) -- #3 1 for output, #4 1 for right and for surround increase the value accordingly
    n_low32l, n_high32l = r.TakeFX_GetPinMappings(take, fxidx, 1, 0 + 0x1000000) -- #3 1 for output, #4 0 for left + 0x1000000 for another 64bits
    n_low32r, n_high32r = r.TakeFX_GetPinMappings(take, fxidx, 1, 1 + 0x1000000) -- #3 1 for output, #4 1 for right
else --  track FX
    local isincontainer, parent_container = r.TrackFX_GetNamedConfigParm(track, fxidx, 'parent_container')  
    if isincontainer then
      _, hm_ch = r.TrackFX_GetNamedConfigParm(track, parent_container, 'container_nch')
    else
      hm_ch = r.GetMediaTrackInfo_Value(track, 'I_NCHAN')
    end
    low32l, high32l = r.TrackFX_GetPinMappings(track, fxidx, 1, 0) -- #3 1 for output, #4 0 for left
    low32r, high32r = r.TrackFX_GetPinMappings(track, fxidx, 1, 1) -- #3 1 for output, #4 1 for right
    n_low32l, n_high32l = r.TrackFX_GetPinMappings(track, fxidx, 1, 0 + 0x1000000) -- #3 1 for output, #4 0 for left + 0x1000000 for another 64bits
    n_low32r, n_high32r = r.TrackFX_GetPinMappings(track, fxidx, 1, 1 + 0x1000000) -- #3 1 for output, #4 1 for right
end

local left = low32l .. "," .. high32l .. "," .. n_low32l .. "," .. n_high32l
local right = low32r .. "," .. high32r .. "," .. n_low32r .. "," .. n_high32r

r.SetProjExtState(0, 'Suzuki_copy_ch', 'ch_count', hm_ch)
r.SetProjExtState(0, 'Suzuki_copy_ch', 'left', left)
r.SetProjExtState(0, 'Suzuki_copy_ch', 'right', right)
