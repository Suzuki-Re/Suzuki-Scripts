-- @description Toggle map to the root container parameter for last touched track or take FX parameter
-- @author Suzuki
-- @license GPL v3
-- @version 1.0
-- @changelog Initial Release
-- @about Using v7.06+ API

local r = reaper

local retval, trackidx, itemidx, takeidx, fxidx, parm = r.GetTouchedOrFocusedFX(0)
local track = r.CSurf_TrackFromID(trackidx + 1, false) -- 1 based
local last_touched_fx = fxidx -- storing the original fx id

if itemidx ~= -1 then
    local item = r.GetMediaItem(0, itemidx)
    local take = r.GetMediaItemTake(item, takeidx)
    local ret, _ = r.TakeFX_GetNamedConfigParm(take, last_touched_fx, "parent_container") 
    local rev = ret                       
    while rev do -- to get root parent container id
    root_container = fxidx
    rev, fxidx = r.TakeFX_GetNamedConfigParm(take, fxidx, "parent_container")
    end
    if ret then       -- toggle map parameter to container 
        local retval, buf = r.TakeFX_GetNamedConfigParm(take, root_container, "container_map.get." .. last_touched_fx .. "." .. parm)
        if retval then
            local rv, container_id = r.TakeFX_GetNamedConfigParm(take, last_touched_fx, "parent_container")
            while rv do
                _, buf = r.TakeFX_GetNamedConfigParm(take, container_id, "container_map.get." .. last_touched_fx .. "." .. parm)
                r.TakeFX_GetNamedConfigParm(take, container_id, "param." .. buf .. ".container_map.delete")
                rv, container_id = r.TakeFX_GetNamedConfigParm(take, container_id, "parent_container")
            end
        else               
            r.TakeFX_GetNamedConfigParm(take, root_container, "container_map.add." .. last_touched_fx .. "." .. parm)
        end
    end
else
    local ret, _ = r.TrackFX_GetNamedConfigParm(track, last_touched_fx, "parent_container") 
    local rev = ret                       
    while rev do -- to get root parent container id
    root_container = fxidx
    rev, fxidx = r.TrackFX_GetNamedConfigParm(track, fxidx, "parent_container")
    end
    if ret then       -- map parameter to container   
        local retval, buf = r.TrackFX_GetNamedConfigParm(track, root_container, "container_map.get." .. last_touched_fx .. "." .. parm)                  
        if retval then
            local rv, container_id = r.TrackFX_GetNamedConfigParm(track, last_touched_fx, "parent_container")
            while rv do
            _, buf = r.TrackFX_GetNamedConfigParm(track, container_id, "container_map.get." .. last_touched_fx .. "." .. parm)
            r.TrackFX_GetNamedConfigParm(track, container_id, "param." .. buf .. ".container_map.delete")
            rv, container_id = r.TrackFX_GetNamedConfigParm(track, container_id, "parent_container")
            end
        else               
            r.TrackFX_GetNamedConfigParm(track, root_container, "container_map.add." .. last_touched_fx .. "." .. parm)
        end
    end
end