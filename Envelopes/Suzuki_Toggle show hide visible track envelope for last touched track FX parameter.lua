r = reaper

retval, trackidx, itemidx, takeidx, fxidx, parm = r.GetTouchedOrFocusedFX(0)
track = r.GetLastTouchedTrack()
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
r.UpdateArrange()