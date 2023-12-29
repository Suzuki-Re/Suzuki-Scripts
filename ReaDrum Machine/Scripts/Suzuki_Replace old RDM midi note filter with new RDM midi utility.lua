-- @noindex
-- @description Replace old RDM midi note filter with new RDM midi utility
-- @author Suzuki
-- @license GPL v3
-- @version 1.0
-- @changelog Initial Release
-- @about 
-- For anyone who save preset or project using the old RDM midi note filter.
-- Simply run the script in the track which has old RDM midi note filters. It replaces all RDM midi note filters with new RDM midi Utility.

local r = reaper

dofile(r.GetResourcePath() .. "/Scripts/Suzuki Scripts/ReaDrum Machine/Modules/General Functions.lua")

function FindAndReplaceFilterRecursively(track, fxid, scale)
    local ccok, container_count = r.TrackFX_GetNamedConfigParm(track, fxid, 'container_count')
    local _, isfilter = r.TrackFX_GetNamedConfigParm(track, fxid, 'fx_name')
  
    if isfilter == "JS: RDM MIDI Note Filter" then
        local notenum = r.TrackFX_GetParam(track, fxid, 0)
        local _, pad_id = r.TrackFX_GetNamedConfigParm(track, fxid, 'parent_container')
        local _, utility_id = r.TrackFX_GetNamedConfigParm(track, pad_id, "container_item." .. 0) -- 0 based
        r.TrackFX_Delete(track, fxid)
        r.TrackFX_AddByName(track, 'RDM MIDI Utility', false, utility_id)
        r.TrackFX_Show(track, utility_id, 2)
        r.TrackFX_SetParam(track, utility_id, 0, notenum)                        -- key for filter, pad number = midi note
    end
  
    if ccok then -- next layer
      local newscale = scale * (tonumber(container_count)+1)
      for child = 1, tonumber(container_count) do
        FindAndReplaceFilterRecursively(track, fxid + scale * child, newscale)
      end
    end
end
  
function FindFilter(track)
    if not track then return end
    local cnt = r.TrackFX_GetCount(track)
    for i = 1, cnt do
        FindAndReplaceFilterRecursively(track, 0x2000000+i, cnt+1)
    end
end
  
function Main()
    r.Undo_BeginBlock()
    for i = 0, r.CountTracks(0) - 1 do -- 1 based
    local track = r.GetTrack(0, i) -- 0 based
    FindFilter(track)
    end
    r.Undo_EndBlock('Close all floating track FX (inside Container) windows (excl. master track)', 2)
end
  
Main()
