-- @description Set last touched track or take FX (inside Container) parameter as a lead parameter for parameter link
-- @author Suzuki
-- @license GPL v3
-- @version 1.0
-- @changelog Initial Release
-- @about Using v7.06+ API, run link action after this script

local r = reaper

local retval, trackidx, itemidx, takeidx, fxidx, parm = r.GetTouchedOrFocusedFX(0)
local track = r.CSurf_TrackFromID(trackidx + 1, false) -- 1 based
lead_fxid = fxidx -- storing the original fx id
lead_paramnumber = parm  

if itemidx ~= -1 then -- take fx
    local item = r.GetMediaItem(0, itemidx)
    local take = r.GetMediaItemTake(item, takeidx)
    local ret, _ = r.TakeFX_GetNamedConfigParm(take, lead_fxid, "parent_container") 
    local rev = ret                       
    while rev do -- to get root parent container id
    root_container = fxidx
    rev, fxidx = r.TakeFX_GetNamedConfigParm(take, fxidx, "parent_container")
    end     
    if ret then       -- new fx and parameter                   
    local rv, buf = r.TakeFX_GetNamedConfigParm(take, root_container, "container_map.add." .. lead_fxid .. "." .. lead_paramnumber)
        lead_fxid = root_container
        lead_paramnumber = buf
    end
else    
    local ret, _ = r.TrackFX_GetNamedConfigParm(track, lead_fxid, "parent_container") 
    local rev = ret                       
    while rev do -- to get root parent container id
    root_container = fxidx
    rev, fxidx = r.TrackFX_GetNamedConfigParm(track, fxidx, "parent_container")
    end     
    if ret then       -- new fx and parameter                   
    local rv, buf = r.TrackFX_GetNamedConfigParm(track, root_container, "container_map.add." .. lead_fxid .. "." .. lead_paramnumber)
        lead_fxid = root_container
        lead_paramnumber = buf
    end
end

r.SetProjExtState(0, 'Suzuki_plink', 'lead_fx', lead_fxid)
r.SetProjExtState(0, 'Suzuki_plink', 'lead_parm', lead_paramnumber)