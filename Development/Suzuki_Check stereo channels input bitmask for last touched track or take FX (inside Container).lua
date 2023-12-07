-- @description Check stereo channels input bitmask for last touched track or take FX (inside Container)
-- @author Suzuki
-- @license GPL v3
-- @version 1.0
-- @changelog Initial Release
-- @about Up to 128 channels

local r = reaper

local retval, trackidx, itemidx, takeidx, fxidx, parm = r.GetTouchedOrFocusedFX(0) -- 0 based
local track = r.CSurf_TrackFromID(trackidx + 1, false) -- 1 based

if itemidx ~= -1 then -- take FX
    local item = r.GetMediaItem(0, itemidx)
    local take = r.GetMediaItemTake(item, takeidx)
    local low32l, high32l = r.TakeFX_GetPinMappings(take, fxidx, 0, 0) -- #3 1 for input, #4 0 for left and for surround increase the value accordingly
    local low32r, high32r = r.TakeFX_GetPinMappings(take, fxidx, 0, 1) -- #3 1 for input, #4 1 for right and for surround increase the value accordingly
    local n_low32l, n_high32l = r.TakeFX_GetPinMappings(take, fxidx, 0, 0 + 0x1000000) -- #3 1 for input, #4 0 for left + 0x1000000 for another 64bits
    local n_low32r, n_high32r = r.TakeFX_GetPinMappings(take, fxidx, 0, 1 + 0x1000000) -- #3 1 for input, #4 1 for right
    r.ShowConsoleMsg(
        "Left input low32 (for 1-32 channels) for take FX is " .. low32l .. " and high32 (for 33-64 channels) is " .. high32l .. 
        " and low32 (for 65-96 channels) is " .. n_low32l .. " and high32 (for 97-128 channels) is " .. n_high32l .. 
        "; Right input low32 (for 1-32 channels) for track FX is " .. low32r .. " and high32 (for 33-64 channels) is " .. high32r .. 
        " and low32 (for 65-96 channels) is " .. n_low32r .. " and high32 (for 97-128 channels) is " .. n_high32r
    )
else --  track FX
    local low32l, high32l = r.TrackFX_GetPinMappings(track, fxidx, 0, 0) -- #3 1 for input, #4 0 for left
    local low32r, high32r = r.TrackFX_GetPinMappings(track, fxidx, 0, 1) -- #3 1 for input, #4 1 for right
    local n_low32l, n_high32l = r.TrackFX_GetPinMappings(track, fxidx, 0, 0 + 0x1000000) -- #3 1 for input, #4 0 for left + 0x1000000 for another 64bits
    local n_low32r, n_high32r = r.TrackFX_GetPinMappings(track, fxidx, 0, 1 + 0x1000000) -- #3 1 for input, #4 1 for right
    r.ShowConsoleMsg(
        "Left input low32 (for 1-32 channels) for track FX is " .. low32l .. " and high32 (for 33-64 channels) is " .. high32l .. 
        " and low32 (for 65-96 channels) is " .. n_low32l .. " and high32 (for 97-128 channels) is " .. n_high32l .. 
        "; Right input low32 (for 1-32 channels) for track FX is " .. low32r .. " and high32 (for 33-64 channels) is " .. high32r .. 
        " and low32 (for 65-96 channels) is " .. n_low32r .. " and high32 (for 97-128 channels) is " .. n_high32r
    )
end
