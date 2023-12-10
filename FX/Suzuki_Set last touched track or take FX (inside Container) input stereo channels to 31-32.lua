-- @description Set last touched track or take FX (inside Container) input stereo channels to 31-32
-- @author Suzuki
-- @license GPL v3
-- @version 1.0
-- @changelog Initial Release

local r = reaper

local retval, trackidx, itemidx, takeidx, fxidx, parm = r.GetTouchedOrFocusedFX(0) -- 0 based
local track = r.CSurf_TrackFromID(trackidx + 1, false) -- 1 based

r.SetMediaTrackInfo_Value(track, 'I_NCHAN', 32) -- stereo channel has 4 block, 1)1-16, 2)17-32, 3)33-48, 4)49-64

local left = (16 - 1) * 2 -- each block has 16 stereo channel, which one?
local right = left + 1

r.Undo_BeginBlock()
r.TrackFX_SetPinMappings(track, fxidx, 0, 0, 2^left, 0) -- remove the current mappings
r.TrackFX_SetPinMappings(track, fxidx, 0, 1, 2^right, 0)
r.TrackFX_SetPinMappings(track, fxidx, 0, 0 + 0x1000000, 0, 0) -- #3 output 1, #4 pin 0 left (add 0x1000000 for 3) and 4)), #6 set hi32bits for even number blocks, 2) and 4)
r.TrackFX_SetPinMappings(track, fxidx, 0, 1 + 0x1000000, 0, 0) -- #4 pin 1 right
r.Undo_EndBlock("Set last touched FX input stereo channels to 31-32", -1)