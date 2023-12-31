--@noindex

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

local function ParameterSwitch(a, label, parm)
  local rv = r.TrackFX_GetParam(track, Pad[a].RS5k_Instances[WhichRS5k], parm)
  local switch
  if rv == 1 then -- on
    switch = true
  else -- off
    switch = false
  end
  --r.ImGui_PushFont(ctx, FONT)
  local rv, switch = r.ImGui_Checkbox(ctx, label, switch)
  --r.ImGui_PopFont(ctx)
  if rv and SELECTED then
    for k, v in pairs(SELECTED) do
      UpdatePadID()
      local k = tonumber(k)
      if Pad[k] and Pad[k].RS5k_ID then 
        local rv = r.TrackFX_GetParam(track, Pad[k].RS5k_ID, parm)
        if rv == 0 then
          r.TrackFX_SetParam(track, Pad[k].RS5k_ID, parm, 1) -- obey note offs on
        else
          r.TrackFX_SetParam(track, Pad[k].RS5k_ID, parm, 0)
        end
      end
    end
    SELECTED = nil
  else
    if rv and not switch then -- rv == true at the moment when clicking it and toggle note_offs boolean
      r.TrackFX_SetParam(track, Pad[a].RS5k_Instances[WhichRS5k], parm, 0) -- off
    elseif rv and switch then
      r.TrackFX_SetParam(track, Pad[a].RS5k_Instances[WhichRS5k], parm, 1) -- on
    end
  end
end

local function DrawKnobs(p_value, v_min, v_max, Radius)
  local draw_list = r.ImGui_GetWindowDrawList(ctx)
  local pos          = {r.ImGui_GetCursorScreenPos(ctx)}
  local Radius       = Radius or 0
  local radius_outer = Radius
  local t = (p_value - v_min) / (v_max - v_min)
  local ANGLE_MIN = 3.141592 * 0.75
  local ANGLE_MAX = 3.141592 * 2.25
  local angle = ANGLE_MIN + (ANGLE_MAX - ANGLE_MIN) * t
  local angle_cos, angle_sin = math.cos(angle), math.sin(angle)
  local radius_inner = radius_outer * 0.40
  local center       = {pos[1] + radius_outer, pos[2] + radius_outer}
  r.ImGui_DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_outer,
            r.ImGui_GetColor(ctx, r.ImGui_Col_Button()))
  r.ImGui_DrawList_AddLine(draw_list, center[1] + angle_cos * radius_inner,
            center[2] + angle_sin * radius_inner,
            center[1] + angle_cos * (radius_outer - 2), center[2] + angle_sin * (radius_outer - 2),
            0x123456ff, 2)
  r.ImGui_DrawList_PathArcTo(draw_list, center[1], center[2], radius_outer / 2, ANGLE_MIN, angle)
  r.ImGui_DrawList_PathStroke(draw_list, 0x99999922, nil, radius_outer * 0.6)
  r.ImGui_DrawList_PathClear(draw_list)
  r.ImGui_DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_inner,
  r.ImGui_GetColor(ctx, r.ImGui_IsItemActive(ctx) and r.ImGui_Col_FrameBgActive() or r.ImGui_IsItemHovered(ctx) and r.ImGui_Col_FrameBgHovered() or r.ImGui_Col_FrameBg()))
end

local function SetMinMax(Input, Min, Max)
  if Input >= Max then
      Input = Max
  elseif Input <= Min then
      Input = Min
  else
      Input = Input
  end
  return Input
end

local function CalculateStripUV(img, V)
  local V = V or 0 
  local w, h = r.ImGui_Image_GetSize(img)
  local FrameNum = h / w
  local StepizedV = (SetMinMax(math.floor(V * FrameNum), 0, FrameNum - 1) / FrameNum)
  local uvmin = (1 / FrameNum) * StepizedV * FrameNum
  local uvmax = 1 / FrameNum + (1 / FrameNum) * StepizedV * FrameNum
  return uvmin, uvmax, w, h
end

local function DrawImageKnob(label, label_id, fxidx, parm, Radius, offset)
  local p_value = r.TrackFX_GetParamNormalized(track, fxidx, parm)
  local draw_list = r.ImGui_GetWindowDrawList(ctx)
  local Image = r.ImGui_CreateImage(r.GetResourcePath() .. "/Scripts/Suzuki Scripts/ReaDrum Machine/Images/FancyBlueKnob.png")
  local pos          = {r.ImGui_GetCursorScreenPos(ctx)}
  local Radius       = Radius or 0
  local radius_outer = Radius
  local center       = {pos[1] + radius_outer, pos[2] + radius_outer}
  local line_height = r.ImGui_GetTextLineHeight(ctx)
  r.ImGui_InvisibleButton(ctx, label .. "##" .. label_id, radius_outer * 2, radius_outer * 2 + line_height + 0 + (-line_height or 0))
  local BtnL, BtnT = r.ImGui_GetItemRectMin(ctx)
  local BtnR, BtnB = r.ImGui_GetItemRectMax(ctx)
  
  r.ImGui_DrawList_AddTextEx(draw_list, FONT, 16, pos[1] + offset, BtnB, 0xffffffff, label) -- parameter name
  if r.ImGui_IsItemActive(ctx) then -- when dragging parameter
    local mouse_delta = { r.ImGui_GetMouseDelta(ctx) }
    if -mouse_delta[2] ~= 0.0 then
      local stepscale = 1
      if SHIFT then stepscale = 3 end
      local step = (1 - 0) / (200.0 * stepscale)
      local p_value = p_value + (-mouse_delta[2] * step)
      if p_value < 0 then p_value = 0 end
      if p_value > 1 then p_value = 1 end
      if SELECTED then
        for k, v in pairs(SELECTED) do
          --UpdatePadID()
          local k = tonumber(k)
          if Pad[k] and Pad[k].RS5k_ID then
            r.TrackFX_SetParamNormalized(track, Pad[k].RS5k_ID, parm, p_value)
          end
        end
      else
        r.TrackFX_SetParamNormalized(track, fxidx, parm, p_value)
      end
    end
    local _, Y_Pos = r.ImGui_GetCursorScreenPos(ctx)
    local window_padding = { r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()) }
            r.ImGui_SetNextWindowPos(ctx, pos[1] + radius_outer / 2,
                Y_Pos or pos[2] - line_height - window_padding[2] - 8)

    if r.ImGui_BeginTooltip(ctx) then -- show parameter value
      local _, parm_v = r.TrackFX_GetFormattedParamValue(track, fxidx, parm)
      r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
      r.ImGui_PushFont(ctx, FONT)
      r.ImGui_Text(ctx, parm_v)
      r.ImGui_PopFont(ctx)
      r.ImGui_PopTextWrapPos(ctx)
      r.ImGui_EndTooltip(ctx)
    end
  end

  if Image then
    local w, h = r.ImGui_Image_GetSize(Image)
    if h > w * 5 then -- It's probably a strip knob file
      local scale = 2
      local sz = radius_outer * scale
      uvmin, uvmax = CalculateStripUV(Image, r.TrackFX_GetParamNormalized(track, fxidx, parm))
      r.ImGui_DrawList_AddImage(draw_list, Image, center[1] - sz / 2, center[2] - sz / 2, center[1] + sz / 2,
              center[2] + sz / 2, 0, uvmin, 1, uvmax, 0xffffffff)
    end
  end
end

local function PositionOffset(x_offset, y_offset)
  local x, y = r.ImGui_GetCursorScreenPos(ctx)
  r.ImGui_SetCursorScreenPos(ctx, x + x_offset, y + y_offset)
end

local function LoopSwitch(a)
  local rv = r.TrackFX_GetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 12) -- Loop Switch
  local loop
  if rv == 1 then
    loop = true
  else
    loop = false
  end
  --r.ImGui_PushFont(ctx, FONT)
  local rv, loop = r.ImGui_Checkbox(ctx, "Loop", loop)
  --r.ImGui_PopFont(ctx)
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
  if loop then
    r.ImGui_SameLine(ctx, nil, 8)
    DrawImageKnob("XFade", a, Pad[a].RS5k_Instances[WhichRS5k], 22, 15, 0)
    r.ImGui_SameLine(ctx, nil, 8)
    DrawImageKnob("Start Pos", "Loop", Pad[a].RS5k_Instances[WhichRS5k], 23, 15, -3)
  end
end

local function ArrowButtons(a)
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
end

function FXUI(a)
  -- integer reaper.PCM_Source_GetPeaks(PCM_source src, number peakrate, number starttime, integer numchannels, integer numsamplesperchannel, integer want_extra_type, reaper.array buf)

  ArrowButtons(a)
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
  --r.ImGui_PushFont(ctx, FONT)
  local rv = r.ImGui_Button(ctx, "RS5k[" .. ('%d'):format(WhichRS5k) .. "] " .. sample_name) -- RS5k instance number + Sample name
  --r.ImGui_PopFont(ctx)
  if rv then
    local open = r.TrackFX_GetOpen(track, Pad[a].RS5k_Instances[WhichRS5k]) -- 0 based
    if open then
      r.TrackFX_Show(track, Pad[a].RS5k_Instances[WhichRS5k], 2)           -- hide floating window
    else
      r.TrackFX_Show(track, Pad[a].RS5k_Instances[WhichRS5k], 3)           -- show floating window
    end
  end
  r.ImGui_PopStyleColor(ctx, 3)

  ParameterSwitch(a, "Obey note-offs", 11)
  r.ImGui_SameLine(ctx, nil, 10)
  LoopSwitch(a)
  PositionOffset(0, 10)
  r.ImGui_Separator(ctx)
  PositionOffset(20, 10)
  DrawImageKnob("Volume", a, Pad[a].RS5k_Instances[WhichRS5k], 0, 19, 3)
  r.ImGui_SameLine(ctx, nil, 15)
  DrawImageKnob("Min Vol.", a, Pad[a].RS5k_Instances[WhichRS5k], 2, 19, 2)
  r.ImGui_SameLine(ctx, nil, 15)
  DrawImageKnob("Pan", a, Pad[a].RS5k_Instances[WhichRS5k], 1, 19, 10)
  r.ImGui_SameLine(ctx, nil, 15)
  DrawImageKnob("Min Velocity", a, Pad[a].RS5k_Instances[WhichRS5k], 17, 19, -13)
  r.ImGui_SameLine(ctx, nil, 20)
  DrawImageKnob("Max Velocity", a, Pad[a].RS5k_Instances[WhichRS5k], 18, 19, -10)
  PositionOffset(0, 30)
  r.ImGui_Separator(ctx)
  PositionOffset(10, 10)
  DrawImageKnob("A", a, Pad[a].RS5k_Instances[WhichRS5k], 9, 19, 17)
  r.ImGui_SameLine(ctx, nil, 8)
  DrawImageKnob("D", a, Pad[a].RS5k_Instances[WhichRS5k], 24, 19, 17)
  r.ImGui_SameLine(ctx, nil, 8)
  DrawImageKnob("S", a, Pad[a].RS5k_Instances[WhichRS5k], 25, 19, 17)
  r.ImGui_SameLine(ctx, nil, 8)
  DrawImageKnob("R", a, Pad[a].RS5k_Instances[WhichRS5k], 10, 19, 17)
  r.ImGui_SameLine(ctx, nil, 14)
  DrawImageKnob("Pitch", a, Pad[a].RS5k_Instances[WhichRS5k], 15, 19, 10)
  r.ImGui_SameLine(ctx, nil, 8)
  DrawImageKnob("Bend", a, Pad[a].RS5k_Instances[WhichRS5k], 16, 19, 10)
  r.ImGui_SameLine(ctx, nil, 8)
  DrawImageKnob("Portament", a, Pad[a].RS5k_Instances[WhichRS5k], 29, 19, -3)
  PositionOffset(0, 30)
  r.ImGui_Separator(ctx)
  PositionOffset(10, 10)
  DrawImageKnob("Start Pos", "Sample", Pad[a].RS5k_Instances[WhichRS5k], 13, 19, -3)
  r.ImGui_SameLine(ctx, nil, 14)
  DrawImageKnob("End Pos", a, Pad[a].RS5k_Instances[WhichRS5k], 14, 19, 0)
  r.ImGui_SameLine(ctx, nil, 14)
  DrawImageKnob("Probability", a, Pad[a].RS5k_Instances[WhichRS5k], 19, 19, -10)
  r.ImGui_SameLine(ctx, nil, 20)
  PositionOffset(0, 10)
  ParameterSwitch(a, "Round-Robin", 20)
  --r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(),        0x99999900)
  --r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), 0x9999993c)
  --r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(),  0x9999996f)
  --r.ImGui_Button(ctx, "Volume", 50, 50)
  --if r.ImGui_IsItemActive(ctx) then
    --r.TrackFX_SetParam(track, RS5k, 0, v)
  --end
  --r.ImGui_PopStyleColor(ctx, 3)
  --DrawKnobs(p_value, 0, 1, 20)
  
end