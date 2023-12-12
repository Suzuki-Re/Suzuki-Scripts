-- @description Close last touched floating track or take FX (inside Container) window
-- @author Suzuki
-- @license GPL v3
-- @version 1.0
-- @changelog Initial Release
-- @about Using v7.07+ API. It works for all kinds of floating FX window, such as input FX, monitoring FX, track FX, take FX, and FX in container

local r = reaper

local retval, trackidx, itemidx, takeidx, fxidx, parm = r.GetTouchedOrFocusedFX(0) -- 0 based
local track = r.CSurf_TrackFromID(trackidx + 1, false) -- 1 based

local function Main()
  r.Undo_BeginBlock()
  if itemidx ~= -1 then
    local item = r.GetMediaItem(0, itemidx)
    local take = r.GetMediaItemTake(item, takeidx)
    local isopen = r.TakeFX_GetOpen(take, fxidx)
    if isopen then
      r.TakeFX_Show(take, fxidx, 2)
    end
  else
    local isopen = r.TrackFX_GetOpen(track, fxidx)
    if isopen then
      r.TrackFX_Show(track, fxidx, 2)
    end
  end
  r.Undo_EndBlock('Close last touched floating FX window', -1)
end

Main()