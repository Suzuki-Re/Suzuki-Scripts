-- @description Toggle show hide visible envelope for last touched track or take FX parameter
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
    local env = r.TakeFX_GetEnvelope(take, fxidx, parm, false)
    if env == nil then  -- Envelope is off
        local env = r.TakeFX_GetEnvelope(take, fxidx, parm, true) -- true = Create envelope
    else -- Envelope is on
        local rv, EnvelopeStateChunk = r.GetEnvelopeStateChunk(env, "", false) -- for both take and track envelope
        if string.find(EnvelopeStateChunk, "VIS 1") then -- VIS 1 = visible, VIS 0 = invisible
            EnvelopeStateChunk = string.gsub(EnvelopeStateChunk, "VIS 1", "VIS 0")
            r.SetEnvelopeStateChunk(env, EnvelopeStateChunk, false)
        else -- on but invisible
            EnvelopeStateChunk = string.gsub(EnvelopeStateChunk, "ACT 0", "ACT 1")
            EnvelopeStateChunk = string.gsub(EnvelopeStateChunk, "VIS 0", "VIS 1")
            EnvelopeStateChunk = string.gsub(EnvelopeStateChunk, "ARM 0", "ARM 1")
            r.SetEnvelopeStateChunk(env, EnvelopeStateChunk, false)
        end
    end
else
    local env = r.GetFXEnvelope(track, fxidx, parm, false) -- Check if envelope is on
    if env == nil then  -- Envelope is off
        local env = r.GetFXEnvelope(track, fxidx, parm, true) -- true = Create envelope
    else -- Envelope is on
        local rv, EnvelopeStateChunk = r.GetEnvelopeStateChunk(env, "", false)
        if string.find(EnvelopeStateChunk, "VIS 1") then -- VIS 1 = visible, VIS 0 = invisible
            EnvelopeStateChunk = string.gsub(EnvelopeStateChunk, "VIS 1", "VIS 0")
            r.SetEnvelopeStateChunk(env, EnvelopeStateChunk, false)
        else -- on but invisible
            EnvelopeStateChunk = string.gsub(EnvelopeStateChunk, "ACT 0", "ACT 1")
            EnvelopeStateChunk = string.gsub(EnvelopeStateChunk, "VIS 0", "VIS 1")
            EnvelopeStateChunk = string.gsub(EnvelopeStateChunk, "ARM 0", "ARM 1")
            r.SetEnvelopeStateChunk(env, EnvelopeStateChunk, false)
        end
    end
    r.TrackList_AdjustWindows(false)
end
r.UpdateArrange()
