-- @description Toggle link last touched track or take FX (inside Container) parameter as a follower to the lead parameter
-- @author Suzuki
-- @license GPL v3
-- @version 1.0
-- @changelog Initial Release
-- @about Using v7.06+ API, run set action before using this

local r = reaper

local retval, trackidx, itemidx, takeidx, fxidx, parm = r.GetTouchedOrFocusedFX(0)
local track = r.CSurf_TrackFromID(trackidx + 1, false) -- 1 based
local rev, lead_fxid = r.GetProjExtState(0, 'Suzuki_plink', 'lead_fx')
local rev, lead_paramnumber = r.GetProjExtState(0, 'Suzuki_plink', 'lead_parm')

if lead_fxid ~= nil then   
    follow_fxid = fxidx -- storing the original fx id
    follow_paramnumber = parm
    if itemidx ~= -1 then -- take fx
        local item = r.GetMediaItem(0, itemidx)
        local take = r.GetMediaItemTake(item, takeidx)
        local ret, _ = r.TakeFX_GetNamedConfigParm(take, follow_fxid, "parent_container") 
        local rev = ret                       
        while rev do -- to get root parent container id
            root_container = fxidx
            rev, fxidx = r.TakeFX_GetNamedConfigParm(take, fxidx, "parent_container")
        end
        if ret then  -- fx inside container
            local retval, buf = r.TakeFX_GetNamedConfigParm(take, root_container, "container_map.get." .. follow_fxid .. "." .. follow_paramnumber)                  
            if retval then -- toggle off and remove map
                r.TakeFX_SetNamedConfigParm(take, root_container, "param."..buf..".plink.active", 0)
                r.TakeFX_SetNamedConfigParm(take, root_container, "param."..buf..".plink.effect", -1) 
                r.TakeFX_SetNamedConfigParm(take, root_container, "param."..buf..".plink.param", -1) 
                local rv, container_id = r.TakeFX_GetNamedConfigParm(take, follow_fxid, "parent_container")
                while rv do -- removing map
                _, buf = r.TakeFX_GetNamedConfigParm(take, container_id, "container_map.get." .. follow_fxid .. "." .. follow_paramnumber)
                r.TakeFX_GetNamedConfigParm(take, container_id, "param." .. buf .. ".container_map.delete")
                rv, container_id = r.TakeFX_GetNamedConfigParm(take, container_id, "parent_container")
                end
            else  -- new fx and parameter                
                local rv, buf = r.TakeFX_GetNamedConfigParm(take, root_container, "container_map.add." .. follow_fxid .. "." .. follow_paramnumber) -- map to the root
                r.TakeFX_SetNamedConfigParm(take, root_container, "param."..buf..".plink.active", 1)
                r.TakeFX_SetNamedConfigParm(take, root_container, "param."..buf..".plink.effect", lead_fxid) 
                r.TakeFX_SetNamedConfigParm(take, root_container, "param."..buf..".plink.param", lead_paramnumber) 
            end
        else -- not inside container
            local retval, buf = r.TakeFX_GetNamedConfigParm(take, follow_fxid, "param."..follow_paramnumber..".plink.active") -- Active(true, 1), Deactivated(true, 0), UnsetYet(false)
            if retval and buf == "1" then -- toggle off
                value = 0
                lead_fxid = -1
                lead_paramnumber = -1
            else
                value = 1
            end
            r.TakeFX_SetNamedConfigParm(take, follow_fxid, "param."..follow_paramnumber..".plink.active", value)
            r.TakeFX_SetNamedConfigParm(take, follow_fxid, "param."..follow_paramnumber..".plink.effect", lead_fxid) 
            r.TakeFX_SetNamedConfigParm(take, follow_fxid, "param."..follow_paramnumber..".plink.param", lead_paramnumber) 
        end  
    else -- track fx
        ret, _ = r.TrackFX_GetNamedConfigParm(track, follow_fxid, "parent_container") 
        local rev = ret                             
        while rev do -- to get root parent container id
        root_container = fxidx
        rev, fxidx = r.TrackFX_GetNamedConfigParm(track, fxidx, "parent_container")
        end
        if ret then  -- fx inside container
            local retval, buf = r.TrackFX_GetNamedConfigParm(track, root_container, "container_map.get." .. follow_fxid .. "." .. follow_paramnumber)                  
            if retval then -- toggle off and remove map
                r.TrackFX_SetNamedConfigParm(track, root_container, "param."..buf..".plink.active", 0)
                r.TrackFX_SetNamedConfigParm(track, root_container, "param."..buf..".plink.effect", -1) 
                r.TrackFX_SetNamedConfigParm(track, root_container, "param."..buf..".plink.param", -1) 
                local rv, container_id = r.TrackFX_GetNamedConfigParm(track, follow_fxid, "parent_container")
                while rv do -- removing map
                _, buf = r.TrackFX_GetNamedConfigParm(track, container_id, "container_map.get." .. follow_fxid .. "." .. follow_paramnumber)
                r.TrackFX_GetNamedConfigParm(track, container_id, "param." .. buf .. ".container_map.delete")
                rv, container_id = r.TrackFX_GetNamedConfigParm(track, container_id, "parent_container")
                end
            else  -- new fx and parameter                
                local rv, buf = r.TrackFX_GetNamedConfigParm(track, root_container, "container_map.add." .. follow_fxid .. "." .. follow_paramnumber) -- map to the root
                r.TrackFX_SetNamedConfigParm(track, root_container, "param."..buf..".plink.active", 1)
                r.TrackFX_SetNamedConfigParm(track, root_container, "param."..buf..".plink.effect", lead_fxid) 
                r.TrackFX_SetNamedConfigParm(track, root_container, "param."..buf..".plink.param", lead_paramnumber) 
            end
        else -- not inside container
            local retval, buf = r.TrackFX_GetNamedConfigParm(track, follow_fxid, "param."..follow_paramnumber..".plink.active") -- Active(true, 1), Deactivated(true, 0), UnsetYet(false)
            if retval and buf == "1" then -- toggle off
                value = 0
                lead_fxid = -1
                lead_paramnumber = -1
            else
                value = 1
            end
            r.TrackFX_SetNamedConfigParm(track, follow_fxid, "param."..follow_paramnumber..".plink.active", value)
            r.TrackFX_SetNamedConfigParm(track, follow_fxid, "param."..follow_paramnumber..".plink.effect", lead_fxid) 
            r.TrackFX_SetNamedConfigParm(track, follow_fxid, "param."..follow_paramnumber..".plink.param", lead_paramnumber) 
        end  
    end                                                                                          
end