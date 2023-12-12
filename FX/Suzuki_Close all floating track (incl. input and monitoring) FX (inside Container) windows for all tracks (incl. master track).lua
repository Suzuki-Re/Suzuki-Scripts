-- @description Close all floating track (incl. input and monitoring) FX (inside Container) windows for all tracks (incl. master track)
-- @author Suzuki
-- @license GPL v3
-- @version 1.0
-- @changelog Initial Release
-- @about REAPER v7 script

local r = reaper

function CloseFloatingFXWindows(track, fxid, scale)
  local ccok, container_count = r.TrackFX_GetNamedConfigParm(track, fxid, 'container_count')
  local isopen = r.TrackFX_GetOpen(track, fxid)

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
  local reccnt = r.TrackFX_GetRecCount(track) -- for input FX and monitoring FX
  for i = 1, reccnt do 
    CloseFloatingFXWindows(track, 0x2000000+i+0x1000000, reccnt+1)
  end
end

function Main()
  r.Undo_BeginBlock()
  for i = 0, r.CountTracks(0) do -- 1 based
    if i == 0 then
      track = r.GetMasterTrack(0)
    else;
      track = r.GetTrack(0, i - 1) -- 0 based
    end
  CountFX(track)
  end
  r.Undo_EndBlock('Close all floating track FX (inside Container) windows (incl. master track)', 2)
end

Main()
