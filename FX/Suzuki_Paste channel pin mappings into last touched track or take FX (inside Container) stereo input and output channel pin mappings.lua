-- @description Paste channel pin mappings into last touched track or take FX (inside Container) stereo input and output channel pin mappings
-- @author Suzuki
-- @license GPL v3
-- @version 1.0
-- @changelog Initial Release
-- @about Using 7.07+ API, up to 128 channels

local r = reaper

local retval, trackidx, itemidx, takeidx, fxidx, parm = r.GetTouchedOrFocusedFX(0) -- 0 based
local track = r.CSurf_TrackFromID(trackidx + 1, false) -- 1 based

local rv, ch_num = r.GetProjExtState(0, 'Suzuki_copy_ch', 'ioch_count')
local ch_num = tonumber(ch_num)
local rv, left = r.GetProjExtState(0, 'Suzuki_copy_ch', 'io_left')
local low32inl, high32inl, n_low32inl, n_high32inl, low32outl, high32outl, n_low32outl, n_high32outl = string.match(left, "(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+)")
local low32inl, high32inl, n_low32inl, n_high32inl, low32outl, high32outl, n_low32outl, n_high32outl = 
tonumber(low32inl), tonumber(high32inl), tonumber(n_low32inl), tonumber(n_high32inl), tonumber(low32outl), tonumber(high32outl), tonumber(n_low32outl), tonumber(n_high32outl)
local rv, right = r.GetProjExtState(0, 'Suzuki_copy_ch', 'io_right')
local low32inr, high32inr, n_low32inr, n_high32inr, low32outr, high32outr, n_low32outr, n_high32outr = string.match(right, "(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%d+)")
local low32inr, high32inr, n_low32inr, n_high32inr, low32outr, high32outr, n_low32outr, n_high32outr = 
tonumber(low32inr), tonumber(high32inr), tonumber(n_low32inr), tonumber(n_high32inr), tonumber(low32outr), tonumber(high32outr), tonumber(n_low32outr), tonumber(n_high32outr)

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
    r.TakeFX_SetPinMappings(take, fxidx, 0, 0, low32inl, high32inl) -- #3 input 0, #4 pin 0 left
    r.TakeFX_SetPinMappings(take, fxidx, 0, 1, low32inr, high32inr) -- #4 pin 1 right
    r.TakeFX_SetPinMappings(take, fxidx, 0, 0 + 0x1000000, n_low32inl, n_high32inl) -- #3 input 0, #4 pin 0 left
    r.TakeFX_SetPinMappings(take, fxidx, 0, 1 + 0x1000000, n_low32inr, n_high32inr) -- #4 pin 1 right
    r.TakeFX_SetPinMappings(take, fxidx, 1, 0, low32outl, high32outl) -- #3 output 1, #4 pin 0 left
    r.TakeFX_SetPinMappings(take, fxidx, 1, 1, low32outr, high32outr) -- #4 pin 1 righ
    r.TakeFX_SetPinMappings(take, fxidx, 1, 0 + 0x1000000, n_low32outl, n_high32outl) -- #3 output 1, #4 pin 0 left
    r.TakeFX_SetPinMappings(take, fxidx, 1, 1 + 0x1000000, n_low32outr, n_high32outr) -- #4 pin 1 right
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
    r.TrackFX_SetPinMappings(track, fxidx, 0, 0, low32inl, high32inl) -- #3 input 0, #4 pin 0 left
    r.TrackFX_SetPinMappings(track, fxidx, 0, 1, low32inr, high32inr) -- #4 pin 1 right
    r.TrackFX_SetPinMappings(track, fxidx, 0, 0 + 0x1000000, n_low32inl, n_high32inl) -- #3 input 0, #4 pin 0 left
    r.TrackFX_SetPinMappings(track, fxidx, 0, 1 + 0x1000000, n_low32inr, n_high32inr) -- #4 pin 1 right
    r.TrackFX_SetPinMappings(track, fxidx, 1, 0, low32outl, high32outl) -- #3 output 1, #4 pin 0 left
    r.TrackFX_SetPinMappings(track, fxidx, 1, 1, low32outr, high32outr) -- #4 pin 1 righ
    r.TrackFX_SetPinMappings(track, fxidx, 1, 0 + 0x1000000, n_low32outl, n_high32outl) -- #3 output 1, #4 pin 0 left
    r.TrackFX_SetPinMappings(track, fxidx, 1, 1 + 0x1000000, n_low32outr, n_high32outr) -- #4 pin 1 right
end
r.Undo_EndBlock("Paste channel pin mappings into last touched FX's stereo input/output channel mappings", -1)