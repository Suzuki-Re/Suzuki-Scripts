-- @description Close all floating take FX (inside Container) windows
-- @author Suzuki
-- @license GPL v3
-- @version 1.0
-- @changelog Initial Release
-- @about v7.07+ script

local r = reaper

local function CloseFloatingFXWindows(take, fxid, scale)
  local ccok, container_count = r.TakeFX_GetNamedConfigParm(take, fxid, 'container_count')
  local isopen = r.TakeFX_GetOpen(take, fxid)
  if isopen then
    r.TakeFX_Show(take, fxid, 2)
  end

  if ccok then -- next layer
    local newscale = scale * (tonumber(container_count)+1)
    for child = 1, tonumber(container_count) do
      CloseFloatingFXWindows(take, fxid + scale * child, newscale)
    end
  end
end

local function CountFX(take)
  if not take then return end
  local cnt = r.TakeFX_GetCount(take)
  for i = 1, cnt do
    CloseFloatingFXWindows(take, 0x2000000+i, cnt+1)
  end
end

local function Main()
  r.Undo_BeginBlock()
  for i = 0, r.CountMediaItems(0) - 1 do -- 1 based
  local item = r.GetMediaItem(0, i) -- 0 based
  local takes_num = r.GetMediaItemNumTakes(item)
    for t = 1, takes_num do
      local take = r.GetTake(item, t - 1)
      CountFX(take)
    end
  end
  r.Undo_EndBlock('Close all floating take FX (inside Container) windows', -1)
end

Main()
