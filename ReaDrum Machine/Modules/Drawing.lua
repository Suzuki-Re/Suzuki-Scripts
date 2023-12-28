--@noindex
--NoIndex: true

r = reaper

local min, max = math.min, math.max
function IncreaseDecreaseBrightness(color, amt, no_alpha)
  function AdjustBrightness(channel, delta)
    return min(255, max(0, channel + delta))
  end

  local alpha = color & 0xFF
  local blue = (color >> 8) & 0xFF
  local green = (color >> 16) & 0xFF
  local red = (color >> 24) & 0xFF

  red = AdjustBrightness(red, amt)
  green = AdjustBrightness(green, amt)
  blue = AdjustBrightness(blue, amt)
  alpha = no_alpha and alpha or AdjustBrightness(alpha, amt)

  return (alpha) | (blue << 8) | (green << 16) | (red << 24)
end

function CalculateFontColor(color)
  local alpha = color & 0xFF
  local blue = (color >> 8) & 0xFF
  local green = (color >> 16) & 0xFF
  local red = (color >> 24) & 0xFF

  local luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255
  return luminance > 0.5 and 0xFF or 0xFFFFFFFF
end

function adjustBrightness(channel, delta)
  return math.min(255, math.max(0, channel + delta))
end

function SplitColorChannels(color)
  local alpha = color & 0xFF
  local blue = (color >> 8) & 0xFF
  local green = (color >> 16) & 0xFF
  local red = (color >> 24) & 0xFF
  return red, green, blue, alpha
end

function ColorToHex(color, amt)
  local red, green, blue, alpha = SplitColorChannels(color)
  alpha = adjustBrightness(alpha, amt)
  blue = adjustBrightness(blue, amt)
  green = adjustBrightness(green, amt)
  red = adjustBrightness(red, amt)
  return (alpha) | (blue << 8) | (green << 16) | (red << 24)
end

function toggle2(a, b)
  if a == b then return nil else return b end 
end

function RememberTab(a, b) -- toggle + remember the last state of tab menu
  if a == b then r.SetProjExtState(0, "ReaDrum Machine", track_guid .. "LAST_MENU", "") return nil else r.SetProjExtState(0, "ReaDrum Machine", track_guid .. "LAST_MENU", b) return b end 
end

function HighlightHvredItem()
  local DL = r.ImGui_GetForegroundDrawList(ctx)
  L, T = r.ImGui_GetItemRectMin(ctx)
  R, B = r.ImGui_GetItemRectMax(ctx)
  if r.ImGui_IsMouseHoveringRect(ctx, L, T, R, B) then
      r.ImGui_DrawList_AddRect(DL, L, T, R, B, 0x99999999)
      r.ImGui_DrawList_AddRectFilled(DL, L, T, R, B, 0x99999933)
      if IsLBtnClicked then
          r.ImGui_DrawList_AddRect(DL, L, T, R, B, 0x999999dd)
          r.ImGui_DrawList_AddRectFilled(DL, L, T, R, B, 0xffffff66)
          return true
      end
  end
end

function Highlight_Itm(drawlist, FillClr, OutlineClr)
  local L, T = r.ImGui_GetItemRectMin(ctx);
  local R, B = r.ImGui_GetItemRectMax(ctx);
  
  if FillClr then r.ImGui_DrawList_AddRectFilled(drawlist, L, T, R, B, FillClr, rounding) end
  if OutlineClr then r.ImGui_DrawList_AddRect(drawlist, L, T, R, B, OutlineClr, rounding) end
end

function FXUI(a)
  -- integer reaper.PCM_Source_GetPeaks(PCM_source src, number peakrate, number starttime, integer numchannels, integer numsamplesperchannel, integer want_extra_type, reaper.array buf)

  local spacing = r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemInnerSpacing())
  r.ImGui_PushButtonRepeat(ctx, true)
  if r.ImGui_ArrowButton(ctx, '##left', r.ImGui_Dir_Left()) then
    WhichRS5k = WhichRS5k - 1
    if WhichRS5k < 1 then
      WhichRS5k = #Pad[a].RS5k_Instances
    end 
  end
  r.ImGui_SameLine(ctx, 0.0, spacing)
  if r.ImGui_ArrowButton(ctx, '##right', r.ImGui_Dir_Right()) then
    WhichRS5k = WhichRS5k + 1
    if WhichRS5k > #Pad[a].RS5k_Instances then
      WhichRS5k = 1
    end 
  end
  r.ImGui_PopButtonRepeat(ctx)
  r.ImGui_SameLine(ctx)
  if Pad[a].Sample_Name[WhichRS5k] then
    sample_name = Pad[a].Sample_Name[WhichRS5k]
  else
    sample_name = "Empty"
  end
  r.ImGui_SameLine(ctx)
  r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        0x99999900)
  r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), 0x9999993c)
  r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  0x9999996f)
  local rv = r.ImGui_Button(ctx, "RS5k[" .. ('%d'):format(WhichRS5k) .. "] " .. sample_name)
  if rv then
    local open = r.TrackFX_GetOpen(track, Pad[a].RS5k_Instances[WhichRS5k]) -- 0 based
    if open then
      r.TrackFX_Show(track, Pad[a].RS5k_Instances[WhichRS5k], 2)           -- hide floating window
    else
      r.TrackFX_Show(track, Pad[a].RS5k_Instances[WhichRS5k], 3)           -- show floating window
    end
  end
  r.ImGui_PopStyleColor(ctx, 3)
  
  local rv = r.TrackFX_GetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 0) -- volume knob
  --r.ImGui_Button(ctx, "Volume", 50, 50)
  --if r.ImGui_IsItemActive(ctx) then
    --r.TrackFX_SetParam(track, RS5k, 0, v)
  --end

  local rv = r.TrackFX_GetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 11) -- Obey Note-Offs Switch
  if rv == 1 then -- on
    note_offs = true
  else -- off
    note_offs = false
  end
  local rv, note_offs = r.ImGui_Checkbox(ctx, "Obey note-offs", note_offs)
  if rv and SELECTED then
    for k, v in pairs(SELECTED) do
      UpdatePadID()
      local k = tonumber(k)
      if Pad[k] and Pad[k].RS5k_ID then 
        local rv = r.TrackFX_GetParam(track, Pad[k].RS5k_ID, 11)
        if rv == 0 then
          r.TrackFX_SetParam(track, Pad[k].RS5k_ID, 11, 1) -- obey note offs on
        else
          r.TrackFX_SetParam(track, Pad[k].RS5k_ID, 11, 0)
        end
      end
    end
    SELECTED = nil
  else
    if rv and not note_offs then -- rv == true at the moment when clicking it and toggle note_offs boolean
      r.TrackFX_SetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 11, 0) -- off
    elseif rv and note_offs then
      r.TrackFX_SetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 11, 1) -- on
    end
  end

  r.ImGui_SameLine(ctx, nil, 0)

  local rv = r.TrackFX_GetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 12) -- Loop Switch
  if rv == 1 then
    loop = true
  else
    loop = false
  end
  local rv, loop = r.ImGui_Checkbox(ctx, "Loop", loop)
  if rv and SELECTED then
    for k, v in pairs(SELECTED) do
      UpdatePadID()
      local k = tonumber(k)
      if Pad[k] and Pad[k].RS5k_ID then
        local rv = r.TrackFX_GetParam(track, Pad[k].RS5k_ID, 12)
        if rv == 0 then
          local no = r.TrackFX_GetParam(track, Pad[k].RS5k_ID, 11)
          if no == 0 then
            r.TrackFX_SetParam(track, Pad[k].RS5k_ID, 11, 1) -- obey note offs on
          end
          r.TrackFX_SetParam(track, Pad[k].RS5k_ID, 12, 1) -- Loop on
        else
          r.TrackFX_SetParam(track, Pad[k].RS5k_ID, 12, 0)
        end
      end
    end
  SELECTED = nil
  else
    if rv and not loop then -- rv == true at the moment when clicking it and toggle note_offs boolean
      r.TrackFX_SetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 12, 0)
    elseif rv and loop then
      local rv = r.TrackFX_GetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 11)
      if rv == 0 then
        r.TrackFX_SetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 11, 1)
      end
      r.TrackFX_SetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 12, 1)
    end
  end
end