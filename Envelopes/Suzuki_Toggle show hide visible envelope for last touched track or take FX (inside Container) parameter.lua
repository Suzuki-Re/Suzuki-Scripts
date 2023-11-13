-- @description Toggle show/hide visible envelope for last touched track or take FX (inside Container) parameter
-- @author Suzuki
-- @license GPL v3
-- @version 1.0
-- @changelog Initial Release

local r = reaper

function get_fx_id_from_container_path(tr, idx1, ...) -- returns a fx-address from a list of 1-based IDs
    local sc,rv = reaper.TrackFX_GetCount(tr)+1, 0x2000000 + idx1
    for i,v in ipairs({...}) do
      local ccok, cc = reaper.TrackFX_GetNamedConfigParm(tr, rv, 'container_count')
      if ccok ~= true then return nil end
      rv = rv + sc * v
      sc = sc * (1+tonumber(cc))
    end
    return rv
end

function get_take_fx_id_from_container_path(tr, idx1, ...) -- returns a fx-address from a list of 1-based IDs
  local sc,rv = reaper.TakeFX_GetCount(tr)+1, 0x2000000 + idx1
  for i,v in ipairs({...}) do
    local ccok, cc = reaper.TakeFX_GetNamedConfigParm(tr, rv, 'container_count')
    if ccok ~= true then return nil end
    rv = rv + sc * v
    sc = sc * (1+tonumber(cc))
  end
  return rv
end

function get_container_path_from_fx_id(tr, fxidx) -- returns a list of 1-based IDs from a fx-address
    if fxidx & 0x2000000 then
      local ret = { }
      local n = reaper.TrackFX_GetCount(tr)
      local curidx = (fxidx - 0x2000000) % (n+1)
      local remain = math.floor((fxidx - 0x2000000) / (n+1))
      if curidx < 1 then return nil end -- bad address
      local addr, addr_sc = curidx + 0x2000000, n + 1
      while true do
        local ccok, cc = reaper.TrackFX_GetNamedConfigParm(tr, addr, 'container_count')
        if not ccok then return nil end -- not a container
        ret[#ret+1] = curidx
        n = tonumber(cc)
        if remain <= n then if remain > 0 then ret[#ret+1] = remain end return ret end
        curidx = remain % (n+1)
        remain = math.floor(remain / (n+1))
        if curidx < 1 then return nil end -- bad address
        addr = addr + addr_sc * curidx
        addr_sc = addr_sc * (n+1)
      end
    end
    return { fxid+1 }
end

function get_container_path_from_take_fx_id(tr, fxidx) -- returns a list of 1-based IDs from a fx-address
  if fxidx & 0x2000000 then
    local ret = { }
    local n = reaper.TakeFX_GetCount(tr)
    local curidx = (fxidx - 0x2000000) % (n+1)
    local remain = math.floor((fxidx - 0x2000000) / (n+1))
    if curidx < 1 then return nil end -- bad address
    local addr, addr_sc = curidx + 0x2000000, n + 1
    while true do
      local ccok, cc = reaper.TakeFX_GetNamedConfigParm(tr, addr, 'container_count')
      if not ccok then return nil end -- not a container
      ret[#ret+1] = curidx
      n = tonumber(cc)
      if remain <= n then if remain > 0 then ret[#ret+1] = remain end return ret end
      curidx = remain % (n+1)
      remain = math.floor(remain / (n+1))
      if curidx < 1 then return nil end -- bad address
      addr = addr + addr_sc * curidx
      addr_sc = addr_sc * (n+1)
    end
  end
  return { fxid+1 }
end

function fx_map_parameter(tr, fxidx, parmidx) -- maps a parameter to the top level parent, returns { fxidx, parmidx }
    local path = get_container_path_from_fx_id(tr, fxidx)
    if not path then return nil end
    while #path > 1 do
      fxidx = path[#path]
      table.remove(path)
      local cidx = get_fx_id_from_container_path(tr,table.unpack(path))
      if cidx == nil then return nil end
      local i, found = 0, nil
      while true do
        local rok, r = reaper.TrackFX_GetNamedConfigParm(tr,cidx,string.format("param.%d.container_map.fx_index",i))
        if not rok then break end
        if tonumber(r) == fxidx - 1 then
          rok, r = reaper.TrackFX_GetNamedConfigParm(tr,cidx,string.format("param.%d.container_map.fx_parm",i))
          if not rok then break end
          if tonumber(r) == parmidx then found = true parmidx = i break end
        end
        i = i + 1
      end
      if not found then
        -- add a new mapping
        local rok, r = reaper.TrackFX_GetNamedConfigParm(tr,cidx,"container_map.add")
        if not rok then return nil end
        r = tonumber(r)
        reaper.TrackFX_SetNamedConfigParm(tr,cidx,string.format("param.%d.container_map.fx_index",r),tostring(fxidx - 1))
        reaper.TrackFX_SetNamedConfigParm(tr,cidx,string.format("param.%d.container_map.fx_parm",r),tostring(parmidx))
        parmidx = r
      end
    end
    return fxidx, parmidx
end

function take_fx_map_parameter(tr, fxidx, parmidx) -- maps a parameter to the top level parent, returns { fxidx, parmidx }
  local path = get_container_path_from_take_fx_id(tr, fxidx)
  if not path then return nil end
  while #path > 1 do
    fxidx = path[#path]
    table.remove(path)
    local cidx = get_take_fx_id_from_container_path(tr,table.unpack(path))
    if cidx == nil then return nil end
    local i, found = 0, nil
    while true do
      local rok, r = reaper.TakeFX_GetNamedConfigParm(tr,cidx,string.format("param.%d.container_map.fx_index",i))
      if not rok then break end
      if tonumber(r) == fxidx - 1 then
        rok, r = reaper.TakeFX_GetNamedConfigParm(tr,cidx,string.format("param.%d.container_map.fx_parm",i))
        if not rok then break end
        if tonumber(r) == parmidx then found = true parmidx = i break end
      end
      i = i + 1
    end
    if not found then
      -- add a new mapping
      local rok, r = reaper.TakeFX_GetNamedConfigParm(tr,cidx,"container_map.add")
      if not rok then return nil end
      r = tonumber(r)
      reaper.TakeFX_SetNamedConfigParm(tr,cidx,string.format("param.%d.container_map.fx_index",r),tostring(fxidx - 1))
      reaper.TakeFX_SetNamedConfigParm(tr,cidx,string.format("param.%d.container_map.fx_parm",r),tostring(parmidx))
      parmidx = r
    end
  end
  return fxidx, parmidx
end

local retval, trackidx, itemidx, takeidx, fxidx, parm = r.GetTouchedOrFocusedFX(0) -- 0 based
local track = r.CSurf_TrackFromID(trackidx + 1, false) -- 1 based

if itemidx ~= -1 then
    local item = r.GetMediaItem(0, itemidx)
    local take = r.GetMediaItemTake(item, takeidx)
    local path = get_container_path_from_take_fx_id(take, fxidx)
    if path then
    fxidx, parm = take_fx_map_parameter(take, fxidx, parm)
    end
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
    local path = get_container_path_from_fx_id(track, fxidx)
    if path then
    fxidx, parm = fx_map_parameter(track, fxidx, parm)
    end
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
