-- @description Close all floating track FX (inside Container) windows for selected tracks (excl. master track)
-- @author Suzuki
-- @license GPL v3
-- @version 1.0
-- @changelog Initial Release
-- @about REAPER v7 script

local r = reaper

function CloseFloatingFXWindows(track, fxid, scale)
  local ccok, container_count = r.TrackFX_GetNamedConfigParm( track, fxid, 'container_count')
  local isopen = r.TrackFX_GetOpen( track, fxid )

  if isopen then
    r.TrackFX_Show(track, fxid, 2)
  end

  if ccok then -- next layer
    local newscale = scale * (tonumber(container_count)+1)
    for child = 1, tonumber(container_count) do
      CloseFloatingFXWindows(track, fxid + scale * child, newscale)
    end
  end
end

function CountFX(track)
  if not track then return end
  local cnt = r.TrackFX_GetCount(track)
  for i = 1, cnt do
    CloseFloatingFXWindows(track, 0x2000000+i, cnt+1)
  end
end

function Main()
  r.Undo_BeginBlock()
  for i = 0, r.CountSelectedTracks(0) - 1 do
  local track = r.GetSelectedTrack(0, i)
  CountFX(track)
  end
  r.Undo_EndBlock('Close all floating track FX (inside Container) windows for selected tracks (excl. master track)', 2)
end

Main()
