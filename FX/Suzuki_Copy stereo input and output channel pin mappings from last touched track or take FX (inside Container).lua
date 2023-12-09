-- @description Copy stereo input and output channel pin mappings from last touched track or take FX (inside Container)
-- @author Suzuki
-- @license GPL v3
-- @version 1.0
-- @changelog Initial Release
-- @about Using 7.07+ API, up to 128 channels

local r = reaper

local retval, trackidx, itemidx, takeidx, fxidx, parm = r.GetTouchedOrFocusedFX(0) -- 0 based
local track = r.CSurf_TrackFromID(trackidx + 1, false) -- 1 based

r.Undo_BeginBlock()
if itemidx ~= -1 then -- take FX
    local item = r.GetMediaItem(0, itemidx)
    local take = r.GetMediaItemTake(item, takeidx)
    local isincontainer, parent_container = r.TakeFX_GetNamedConfigParm(take, fxidx, 'parent_container')
    if isincontainer then
        _, hm_ch = r.TakeFX_GetNamedConfigParm(take, parent_container, 'container_nch')
    else
        hm_ch = r.GetMediaItemTakeInfo_Value(take, 'I_TAKEFX_NCH')
    end
    low32inl, high32inl = r.TakeFX_GetPinMappings(take, fxidx, 0, 0) -- #3 0 for input, #4 0 for left and for surround increase the value accordingly
    low32inr, high32inr = r.TakeFX_GetPinMappings(take, fxidx, 0, 1) -- #3 0 for input, #4 1 for right and for surround increase the value accordingly
    n_low32inl, n_high32inl = r.TakeFX_GetPinMappings(take, fxidx, 0, 0 + 0x1000000) -- #3 0 for input, #4 0 for left + 0x1000000 for another 64bits
    n_low32inr, n_high32inr = r.TakeFX_GetPinMappings(take, fxidx, 0, 1 + 0x1000000) -- #3 0 for input, #4 1 for right
    low32outl, high32outl = r.TakeFX_GetPinMappings(take, fxidx, 1, 0) -- #3 1 for output, #4 0 for left and for surround increase the value accordingly
    low32outr, high32outr = r.TakeFX_GetPinMappings(take, fxidx, 1, 1) -- #3 1 for output, #4 1 for right and for surround increase the value accordingly
    n_low32outl, n_high32outl = r.TakeFX_GetPinMappings(take, fxidx, 1, 0 + 0x1000000) -- #3 1 for output, #4 0 for left + 0x1000000 for another 64bits
    n_low32outr, n_high32outr = r.TakeFX_GetPinMappings(take, fxidx, 1, 1 + 0x1000000) -- #3 1 for output, #4 1 for right
else --  track FX
    local isincontainer, parent_container = r.TrackFX_GetNamedConfigParm(track, fxidx, 'parent_container')  
    if isincontainer then
      _, hm_ch = r.TrackFX_GetNamedConfigParm(track, parent_container, 'container_nch')
    else
      hm_ch = r.GetMediaTrackInfo_Value(track, 'I_NCHAN')
    end
    low32inl, high32inl = r.TrackFX_GetPinMappings(track, fxidx, 0, 0) -- #3 0 for input, #4 0 for left
    low32inr, high32inr = r.TrackFX_GetPinMappings(track, fxidx, 0, 1) -- #3 0 for input, #4 1 for right
    n_low32inl, n_high32inl = r.TrackFX_GetPinMappings(track, fxidx, 0, 0 + 0x1000000) -- #3 0 for input, #4 0 for left + 0x1000000 for another 64bits
    n_low32inr, n_high32inr = r.TrackFX_GetPinMappings(track, fxidx, 0, 1 + 0x1000000) -- #3 0 for input, #4 1 for right
    low32outl, high32outl = r.TrackFX_GetPinMappings(track, fxidx, 1, 0) -- #3 1 for output, #4 0 for left
    low32outr, high32outr = r.TrackFX_GetPinMappings(track, fxidx, 1, 1) -- #3 1 for output, #4 1 for right
    n_low32outl, n_high32outl = r.TrackFX_GetPinMappings(track, fxidx, 1, 0 + 0x1000000) -- #3 1 for output, #4 0 for left + 0x1000000 for another 64bits
    n_low32outr, n_high32outr = r.TrackFX_GetPinMappings(track, fxidx, 1, 1 + 0x1000000) -- #3 1 for output, #4 1 for right
end

local left = low32inl .. "," .. high32inl .. "," .. n_low32inl .. "," .. n_high32inl .. "," .. low32outl .. "," .. high32outl .. "," .. n_low32outl .. "," .. n_high32outl
local right = low32inr .. "," .. high32inr .. "," .. n_low32inr .. "," .. n_high32inr .. "," .. low32outr .. "," .. high32outr .. "," .. n_low32outr .. "," .. n_high32outr

r.SetProjExtState(0, 'Suzuki_copy_ch', 'ioch_count', hm_ch)
r.SetProjExtState(0, 'Suzuki_copy_ch', 'io_left', left)
r.SetProjExtState(0, 'Suzuki_copy_ch', 'io_right', right)
r.Undo_EndBlock("Copy stereo input/output pin mappings from last touched FX", -1)