-- @description Toggle enable/disable LFO for last touched track or take FX (inside Container) parameter
-- @author Suzuki
-- @license GPL v3
-- @version 1.1
-- @changelog Fixed a mistake I don't know why I did
-- @about Using v7.0+ API

local r = reaper

local retval, trackidx, itemidx, takeidx, fxidx, parm = r.GetTouchedOrFocusedFX(0)
local track = r.CSurf_TrackFromID(trackidx + 1, false) -- 1 based

if itemidx ~= -1 then
    local item = r.GetMediaItem(0, itemidx)
    local take = r.GetMediaItemTake(item, takeidx)
    local retval, buf = r.TakeFX_GetNamedConfigParm(take, fxidx, "param."..parm..".lfo.active")
    if retval and buf == "1" then
        r.TakeFX_SetNamedConfigParm(take, fxidx, "param."..parm..".lfo.active", 0)
    else
        r.TakeFX_SetNamedConfigParm(take, fxidx, "param."..parm..".lfo.active", 1)
        r.TakeFX_SetNamedConfigParm(take, fxidx, "param."..parm..".mod.visible", 1)
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
