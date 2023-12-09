-- @description Paste channel pin mappings into last touched track or take FX (inside Container) stereo output channel pin mappings
-- @author Suzuki
-- @license GPL v3
-- @version 1.1
-- @changelog Bug fix for container FX
-- @about Using 7.07+ API, up to 128 channels

local r = reaper

local retval, trackidx, itemidx, takeidx, fxidx, parm = r.GetTouchedOrFocusedFX(0) -- 0 based
local track = r.CSurf_TrackFromID(trackidx + 1, false) -- 1 based

local rv, ch_num = r.GetProjExtState(0, 'Suzuki_copy_ch', 'ch_count')
local ch_num = tonumber(ch_num)
local rv, left = r.GetProjExtState(0, 'Suzuki_copy_ch', 'left')
local low32l, high32l, n_low32l, n_high32l = string.match(left, "(%d+),(%d+),(%d+),(%d+)")
local low32l, high32l, n_low32l, n_high32l = tonumber(low32l), tonumber(high32l), tonumber(n_low32l), tonumber(n_high32l)
local rv, right = r.GetProjExtState(0, 'Suzuki_copy_ch', 'right')
local low32r, high32r, n_low32r, n_high32r = string.match(right, "(%d+),(%d+),(%d+),(%d+)")
local low32r, high32r, n_low32r, n_high32r = tonumber(low32r), tonumber(high32r), tonumber(n_low32r), tonumber(n_high32r)

r.Undo_BeginBlock()
if itemidx ~= -1 then -- take FX
    local item = r.GetMediaItem(0, itemidx)
    local take = r.GetMediaItemTake(item, takeidx)
    local isincontainer, parent_container = r.TakeFX_GetNamedConfigParm(take, fxidx, 'parent_container')
    if isincontainer then -- for container FX
        local _, hm_ch = r.TakeFX_GetNamedConfigParm(take, parent_container, 'container_nch')
        if ch_num > tonumber(hm_ch) then
            if ch_num % 2 == 1 then
                r.TakeFX_SetNamedConfigParm(take, parent_container, 'container_nch', ch_num + 1)
            else
                r.TakeFX_SetNamedConfigParm(take, parent_container, 'container_nch', ch_num)
            end
        end
    else -- To adjust track channel number
    local hm_ch = r.GetMediaItemTakeInfo_Value(take, 'I_TAKEFX_NCH')
        if ch_num > hm_ch then
            if ch_num % 2 == 1 then
                r.SetMediaItemTakeInfo_Value(take, 'I_TAKEFX_NCH', ch_num + 1)
            else
                r.SetMediaItemTakeInfo_Value(take, 'I_TAKEFX_NCH', ch_num)
            end
        end
    end
    r.TakeFX_SetPinMappings(take, fxidx, 1, 0, low32l, high32l) -- #3 output 1, #4 pin 0 left
    r.TakeFX_SetPinMappings(take, fxidx, 1, 1, low32r, high32r) -- #4 pin 1 righ
    r.TakeFX_SetPinMappings(take, fxidx, 1, 0 + 0x1000000, n_low32l, n_high32l) -- #3 output 1, #4 pin 0 left
    r.TakeFX_SetPinMappings(take, fxidx, 1, 1 + 0x1000000, n_low32r, n_high32r) -- #4 pin 1 right
else --  track FX
    local isincontainer, parent_container = r.TrackFX_GetNamedConfigParm(track, fxidx, 'parent_container')  
    if isincontainer then -- for container FX
      local _, hm_ch = r.TrackFX_GetNamedConfigParm(track, parent_container, 'container_nch')
      if ch_num > tonumber(hm_ch) then
        if ch_num % 2 == 1 then
            r.TrackFX_SetNamedConfigParm(track, parent_container, 'container_nch', ch_num + 1)
        else
            r.TrackFX_SetNamedConfigParm(track, parent_container, 'container_nch', ch_num)
        end
      end
    else -- To adjust track channel number
      local hm_ch = r.GetMediaTrackInfo_Value(track, 'I_NCHAN')
      if ch_num > hm_ch then
        if ch_num % 2 == 1 then
            r.SetMediaTrackInfo_Value(track, 'I_NCHAN', ch_num + 1)
        else
            r.SetMediaTrackInfo_Value(track, 'I_NCHAN', ch_num)
        end
      end
    end
    r.TrackFX_SetPinMappings(track, fxidx, 1, 0, low32l, high32l) -- #3 output 1, #4 pin 0 left
    r.TrackFX_SetPinMappings(track, fxidx, 1, 1, low32r, high32r) -- #4 pin 1 righ
    r.TrackFX_SetPinMappings(track, fxidx, 1, 0 + 0x1000000, n_low32l, n_high32l) -- #3 output 1, #4 pin 0 left
    r.TrackFX_SetPinMappings(track, fxidx, 1, 1 + 0x1000000, n_low32r, n_high32r) -- #4 pin 1 right
end
r.Undo_EndBlock("Paste channel pin mappings into last touched FX's stereo output channel mappings ", -1)
