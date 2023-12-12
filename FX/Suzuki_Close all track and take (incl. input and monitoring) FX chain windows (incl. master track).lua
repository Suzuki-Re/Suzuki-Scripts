-- @description Close all track and take (incl. input and monitoring) FX (inside Container) chain windows (incl. master track)
-- @author Suzuki
-- @license GPL v3
-- @version 1.0
-- @changelog Initial Release
-- @about Close literally all FX chain windows

local r = reaper

local function CloseTrackFXChainWindows(track)
  if r.TrackFX_GetChainVisible(track) ~= -1 then
    r.TrackFX_Show(track, 0, 0)
  end
  if r.TrackFX_GetRecChainVisible(track) ~= -1 then
    r.TrackFX_Show(track, 0 + 0x1000000, 0)
  end
end

local function CloseTakeFXChainWindows(take)
  if r.TakeFX_GetChainVisible(take) ~= -1 then
    r.TakeFX_Show(take, 0, 0)
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
    CloseTrackFXChainWindows(track)
  end
  for i = 0, r.CountMediaItems(0) - 1 do -- 1 based
    local item = r.GetMediaItem(0, i) -- 0 based
    local takes_num = r.GetMediaItemNumTakes(item)
    for t = 1, takes_num do
      local take = r.GetTake(item, t - 1)
      CloseTakeFXChainWindows(take)
    end
  end
  r.Undo_EndBlock('Close all track and take (incl. input and monitoring) FX Chain windows (incl. master track)', -1)
end

Main()