-- @description Close all FX windows
-- @author Suzuki
-- @license GPL v3
-- @version 1.0
-- @changelog Initial Release
-- @about Using v7.07+ API. Literally close all FX related windows including chain and floating windows for track FX, master track FX, take FX, monitoring FX, input FX, and FX in container

local r = reaper

local function CloseTrackFXChainWindows(track)
  if r.TrackFX_GetChainVisible(track) ~= -1 then
    r.TrackFX_Show(track, 0, 0)
  end
  if r.TrackFX_GetRecChainVisible(track) ~= -1 then
    r.TrackFX_Show(track, 0 + 0x1000000, 0)
  end
end

local function CloseFloatingTrackFXWindows(track, fxid, scale)
  local ccok, container_count = r.TrackFX_GetNamedConfigParm(track, fxid, 'container_count')
  local isopen = r.TrackFX_GetOpen(track, fxid)

  if isopen then
    r.TrackFX_Show(track, fxid, 2)
  end

  if ccok then -- next layer
    local newscale = scale * (tonumber(container_count)+1)
    for child = 1, tonumber(container_count) do
      CloseFloatingTrackFXWindows(track, fxid + scale * child, newscale)
    end
  end
end

local function CountTrackFX(track)
  if not track then return end
  local cnt = r.TrackFX_GetCount(track)
  for i = 1, cnt do
    CloseFloatingTrackFXWindows(track, 0x2000000+i, cnt+1)
  end
  local reccnt = r.TrackFX_GetRecCount(track) -- for input FX and monitoring FX
  for i = 1, reccnt do 
    CloseFloatingTrackFXWindows(track, 0x2000000+i+0x1000000, reccnt+1)
  end
end

local function CloseTakeFXChainWindows(take)
  if r.TakeFX_GetChainVisible(take) ~= -1 then
    r.TakeFX_Show(take, 0, 0)
  end
end

local function CloseFloatingTakeFXWindows(take, fxid, scale)
  local ccok, container_count = r.TakeFX_GetNamedConfigParm(take, fxid, 'container_count')
  local isopen = r.TakeFX_GetOpen(take, fxid)
  if isopen then
    r.TakeFX_Show(take, fxid, 2)
  end

  if ccok then -- next layer
    local newscale = scale * (tonumber(container_count)+1)
    for child = 1, tonumber(container_count) do
      CloseFloatingTakeFXWindows(take, fxid + scale * child, newscale)
    end
  end
end

local function CountTakeFX(take)
  if not take then return end
  local cnt = r.TakeFX_GetCount(take)
  for i = 1, cnt do
    CloseFloatingTakeFXWindows(take, 0x2000000+i, cnt+1)
  end
end

local function Main()
  r.Undo_BeginBlock()
  for i = 0, r.CountTracks(0) do -- 1 based
    if i == 0 then
      track = r.GetMasterTrack(0)
    else;
      track = r.GetTrack(0, i - 1) -- 0 based
    end
    CountTrackFX(track)
    CloseTrackFXChainWindows(track)
  end
  for i = 0, r.CountMediaItems(0) - 1 do -- 1 based
    local item = r.GetMediaItem(0, i) -- 0 based
    local takes_num = r.GetMediaItemNumTakes(item)
    for t = 1, takes_num do
      local take = r.GetTake(item, t - 1)
      CountTakeFX(take)
      CloseTakeFXChainWindows(take)
    end
  end
  r.Undo_EndBlock('Close all FX windows', -1)
end

Main()