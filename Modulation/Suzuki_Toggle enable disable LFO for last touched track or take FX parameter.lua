-- @description Toggle enable/disable LFO for last touched track or take FX parameter
-- @author Suzuki
-- @license GPL v3
-- @version 1.0
-- @changelog Initial Release

local r = reaper

local track = r.GetSelectedTrack2(0, 0, true)
local retval, trackidx, itemidx, takeidx, fxidx, parm = r.GetTouchedOrFocusedFX(0)

if itemidx ~= -1 then
    local item = r.GetMediaItem(0, itemidx)
    local take = r.GetMediaItemTake(item, takeidx)
    local retval, buf = r.TakeFX_GetNamedConfigParm(take, takeidx, "param."..parm..".lfo.active")
    if retval and buf == "1" then
        r.TakeFX_SetNamedConfigParm(take, takeidx, "param."..parm..".lfo.active", 0)
    else
        r.TakeFX_SetNamedConfigParm(take, takeidx, "param."..parm..".lfo.active", 1)
        r.TakeFX_SetNamedConfigParm(take, takeidx, "param."..parm..".mod.visible", 1)
    end
else
    local retval, buf = r.TrackFX_GetNamedConfigParm(track, fxidx, "param."..parm..".lfo.active") -- Active(true, 1), Deactivated(true, 0), UnsetYet(false) 
    if retval and buf == "1" then -- Toggle
        r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".lfo.active", 0)
    else
        r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".lfo.active", 1)
        r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".mod.visible", 1)
    end
end
