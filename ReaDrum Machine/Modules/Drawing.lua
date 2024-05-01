--@noindex

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

local function RecallInfo(Str, ID)
  if Str then
    local value, LineChange
    local Start, End = Str:find(ID)
    LineChange = Str:find('\n', Start)
    
    if End and Str and LineChange then
      value = tonumber(string.sub(Str, End + 1, LineChange - 1))
    end
    if value == '' then value = nil end
    return value
  end
end

local function Saveini(fxidx)
  local file_path = script_path .. 'RS5k Default Values.ini'
  os.remove(file_path)
  local file = io.open(file_path, 'a+')

  if file then
    for parm = 0, 25 do
      local value = r.TrackFX_GetParam(track, fxidx, parm)
      local _, name = r.TrackFX_GetParamName(track, fxidx, parm)
      file:write(parm, '. ', name, ' = ', value or '', '\n')
    end
  file:write('\n')
  file:close()
  end
end

local function Readini(fxidx, parm)
  local file_path = script_path .. 'RS5k Default Values.ini'
  local file = io.open(file_path, 'r')

  if file then
    Content = file:read('*a')
    local _, name = r.TrackFX_GetParamName(track, fxidx, parm)
    local value = RecallInfo(Content, parm .. '. ' .. name .. ' = ')
    if value then
      r.TrackFX_SetParam(track, fxidx, parm, value)
    end
  end
end

local function DefaultValueWindow(label, fxidx)
  local center = { r.ImGui_Viewport_GetCenter(r.ImGui_GetWindowViewport(ctx)) }
  r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
  if r.ImGui_BeginPopupModal(ctx, 'Do you want to save default value?##' .. label, nil, r.ImGui_WindowFlags_AlwaysAutoResize()) then
    if r.ImGui_IsWindowAppearing(ctx) then
      r.ImGui_SetKeyboardFocusHere(ctx)
    end
    if r.ImGui_Button(ctx, 'YES', 120, 0) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) or
        r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_KeypadEnter()) then
        Saveini(fxidx)
      r.ImGui_CloseCurrentPopup(ctx)
    end
    r.ImGui_SetItemDefaultFocus(ctx)
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, 'NO', 120, 0) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Escape()) then
      r.ImGui_CloseCurrentPopup(ctx)
    end
    r.ImGui_EndPopup(ctx)
  end
end

function ParameterTooltip(fxidx, parm)
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

local function VAL2DB(x)
  if x < 0.0000000298023223876953125 then
    return -150
  else
    return math.max(-150, math.log(x) * 8.6858896380650365530225783783321)
  end
end

function GetSetParamValues(fxidx, parm, drag_delta, step)
  local p_value = r.TrackFX_GetParamNormalized(track, fxidx, parm)
  local p_value = p_value + (drag_delta * step)
  if p_value < 0 then p_value = 0 end
  if p_value > 1 then p_value = 1 end
  r.TrackFX_SetParamNormalized(track, fxidx, parm, p_value)
  local p_value = r.TrackFX_GetParamNormalized(track, fxidx, parm)
  local _, f_value = r.TrackFX_GetFormattedParamValue(track, fxidx, parm)
  if parm == 0 then r.CF_Preview_SetValue(preview, 'D_VOLUME', p_value * 2) end -- 0 to 2
  if parm == 1 then r.CF_Preview_SetValue(preview, 'D_PAN', p_value * 2 - 1) end -- -1 to 1
  if parm == 15 then r.CF_Preview_SetValue(preview, 'D_PITCH', f_value) end
end

local function DrawImageKnob(label, label_id, fxidx, parm, Radius, offset)
  local draw_list = r.ImGui_GetWindowDrawList(ctx)
  if not r.ImGui_ValidatePtr(Image, 'ImGui_Image*') then
    Image = r.ImGui_CreateImage(r.GetResourcePath() .. "/Scripts/Suzuki Scripts/ReaDrum Machine/Images/FancyBlueKnob.png")
  end
  local pos          = {r.ImGui_GetCursorScreenPos(ctx)}
  local Radius       = Radius or 0
  local radius_outer = Radius
  local center       = {pos[1] + radius_outer, pos[2] + radius_outer}
  local line_height = r.ImGui_GetTextLineHeight(ctx)
  local rv = r.ImGui_InvisibleButton(ctx, label .. "##" .. label_id, radius_outer * 2, radius_outer * 2 + line_height + 0 + (-line_height or 0))
  if r.ImGui_IsItemHovered(ctx) and not r.ImGui_IsItemActive(ctx) then -- mousewheel to change values
    local v, h = r.ImGui_GetMouseWheel(ctx)
    local stepscale = 1
    if SHIFT then stepscale = 6 end
    local step = (1 - 0) / (200.0 * stepscale)
    GetSetParamValues(fxidx, parm, (4 * v), step)
    ParameterTooltip(fxidx, parm)
  end
  local BtnL, BtnT = r.ImGui_GetItemRectMin(ctx)
  local BtnR, BtnB = r.ImGui_GetItemRectMax(ctx)

  r.ImGui_DrawList_AddTextEx(draw_list, FONT, 16, pos[1] + offset, BtnB, 0xffffffff, label) -- parameter name
  if r.ImGui_IsItemHovered(ctx) and r.ImGui_IsMouseDoubleClicked(ctx, 0) then -- reset value
    Readini(fxidx, parm)
  end
  if r.ImGui_IsItemClicked(ctx, 1) and CTRL then
    r.ImGui_OpenPopup(ctx, 'Do you want to save default value?##' .. label)
  --elseif r.ImGui_IsItemClicked(ctx, 0) and ALT then -- input box
    --r.ImGui_OpenPopup(ctx, 'input value##' .. label)
  elseif r.ImGui_IsItemActive(ctx) then -- when dragging parameter
    local mouse_delta = { r.ImGui_GetMouseDelta(ctx) }
    if -mouse_delta[2] ~= 0.0 then
      if label == "Pitch" then
        stepscale = 0.8
      else
        stepscale = 1
      end
      if SHIFT then stepscale = 3 end
      local step = (1 - 0) / (200.0 * stepscale)
      if SELECTED then
        for k, v in pairs(SELECTED) do
          local k = tonumber(k)
          if Pad[k] and Pad[k].RS5k_ID then
            GetSetParamValues(Pad[k].RS5k_ID, parm, -mouse_delta[2], step)
          end
        end
      else
        GetSetParamValues(fxidx, parm, -mouse_delta[2], step)
      end
    end
    local _, Y_Pos = r.ImGui_GetCursorScreenPos(ctx)
    local window_padding = { r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()) }
    r.ImGui_SetNextWindowPos(ctx, pos[1] + radius_outer / 2, Y_Pos or pos[2] - line_height - window_padding[2] - 8)
    ParameterTooltip(fxidx, parm)
  end
  if r.ImGui_BeginPopup(ctx, "input value##" .. label) then
    if r.ImGui_IsWindowAppearing(ctx) then
      r.ImGui_SetKeyboardFocusHere(ctx)
    end
    r.ImGui_Text(ctx, 'Put values:')
    rv, input = r.ImGui_InputText(ctx, label, input)
    if r.ImGui_Button(ctx, 'OK', 120, 0) or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_Enter()) or
      r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_KeypadEnter()) then
      for p = 0, 1 do
        local _, p_value = r.TrackFX_FormatParamValueNormalized(track, fxidx, parm, p, "")
        if p_value == input then
          r.TrackFX_SetParamNormalized(track, fxidx, parm, p)
          return
        end
      end
    end
    r.ImGui_SetItemDefaultFocus(ctx)
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, 'Close') then
      r.ImGui_CloseCurrentPopup(ctx)
    end
    r.ImGui_EndPopup(ctx)
  end
  DefaultValueWindow(label, fxidx)

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

function PositionOffset(x_offset, y_offset)
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
  r.CF_Preview_SetValue(preview, 'B_LOOP', loop and 1 or 0) 
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

local function PreviewSamples(file, a)
  if preview then
    r.CF_Preview_Stop(preview)
    preview = nil
  end
  local source = r.PCM_Source_CreateFromFile(file)
  if not source then return end

  preview = r.CF_CreatePreview(source)

  --r.CF_Preview_SetOutputTrack(preview, 0, track)
  r.CF_Preview_SetValue(preview, 'I_OUTCHAN', 0)

  local volume = r.TrackFX_GetParamNormalized(track, Pad[a].RS5k_Instances[WhichRS5k], 0) -- from 0 to 2
  r.CF_Preview_SetValue(preview, 'D_VOLUME', volume * 2) -- 0 to 2
  local _, pan = r.TrackFX_GetFormattedParamValue(track, Pad[a].RS5k_Instances[WhichRS5k], 1) -- from 0 to 1  
  r.CF_Preview_SetValue(preview, 'D_PAN', pan * 2 - 1) -- from -1 to 1 
  local loop = r.TrackFX_GetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 12)
  r.CF_Preview_SetValue(preview, 'B_LOOP', loop) -- from -1 to 1 
  local _, pitch = r.TrackFX_GetFormattedParamValue(track, Pad[a].RS5k_Instances[WhichRS5k], 15)
  r.CF_Preview_SetValue(preview, 'D_PITCH', pitch)
  r.CF_Preview_Play(preview)
  r.PCM_Source_Destroy(source)
end

local function ChangeSample(track, fxidx, a)
  local rv, sample = r.TrackFX_GetNamedConfigParm(track, fxidx, "FILE0")

  if not rv or sample == "" then return end

  local dir, file = sample:match("^(.-)([^/\\]+)$")
  if not dir or not file then return end

  local files = {}
  local i = 0
  while true do
    local file_name = r.EnumerateFiles(dir, i)
    if not file_name then
      break
    end
    local ext = file_name:match("([^%.]+)$")
    if r.IsMediaExtension(ext, false) and #ext <= 4 and ext ~= "mid" then
      table.insert(files, file_name)
    end
    i = i + 1
  end

  table.sort(files)

  local idx
  for i, file_name in ipairs(files) do
    if file_name == file then
      idx = i
      break
    end
  end
  
  local new_idx
  if UpArrow then
    new_idx = idx - 1
    if new_idx < 1 then
      new_idx = #files
    end
  elseif DownArrow then
    new_idx = idx + 1
    if new_idx > #files then
      new_idx = 1
    end
  elseif R then
    new_idx = math.random(#files)
    while new_idx == idx do
      new_idx = math.random(#files)
    end
  else
    return
  end

  local new_file = files[new_idx]
  if not new_file then
    return
  end

  local new_sample = dir .. new_file

  r.TrackFX_SetNamedConfigParm(track, fxidx, "FILE0", new_sample)
  r.TrackFX_SetNamedConfigParm(track, fxidx, "DONE", "")
  r.SetExtState("ReaDrum Machine", "preview_file", new_sample, true)
  PreviewSamples(new_sample, a)
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



function RS5kUI(a)
  -- integer reaper.PCM_Source_GetPeaks(PCM_source src, number peakrate, number starttime, integer numchannels, integer numsamplesperchannel, integer want_extra_type, reaper.array buf)
  if not Pad[a] then return end
  if not Pad[a].RS5k_Instances[WhichRS5k] and WhichRS5k > #Pad[a].RS5k_Instances then WhichRS5k = 1 end
  ArrowButtons(a)
  r.ImGui_SameLine(ctx)
  local rv = r.ImGui_Button(ctx, "##>", 19, 19) -- play button
  DrawListButton(">", 0xff, nil, true, true)
  SendMidiNote(Pad[a].Note_Num)
  r.ImGui_SameLine(ctx)
  local rv = r.ImGui_Button(ctx, "##/", 19, 19) -- stop button
  DrawListButton("/", 0xff, nil, true, true)
  if rv and preview then
    r.CF_Preview_Stop(preview)
    preview = nil
  elseif rv then
    r.StuffMIDIMessage(0, 0x80, Pad[a].Note_Num, 96) -- send note off
  end
  r.ImGui_SameLine(ctx)
  local rv = r.ImGui_Button(ctx, "##O", 19, 19) -- Browse samples
  DrawListButton("O", 0xff, nil, true, true)
  if rv then
    if r.HasExtState("ReaDrum Machine", "preview_file") then
      file = r.GetExtState("ReaDrum Machine", "preview_file")
    end
    local rv, new_sample = r.JS_Dialog_BrowseForOpenFiles('Select audio file', '', file, '', false)
    if rv and new_sample:len() > 0 then
      r.TrackFX_SetNamedConfigParm(track, Pad[a].RS5k_Instances[WhichRS5k], "FILE0", new_sample)
      r.TrackFX_SetNamedConfigParm(track, Pad[a].RS5k_Instances[WhichRS5k], "DONE", "")
      r.SetExtState("ReaDrum Machine", "preview_file", new_sample, true)
    end
  end
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
  DndAddSampleToEachRS5k_TARGET(a, Pad[a].RS5k_Instances[WhichRS5k], 0)
  if DownArrow or UpArrow or r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_R()) then
    ChangeSample(track, Pad[a].RS5k_Instances[WhichRS5k], a)
  end
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
  DrawImageKnob("Volume", "Volume", Pad[a].RS5k_Instances[WhichRS5k], 0, 19, 3)
  r.ImGui_SameLine(ctx, nil, 15)
  DrawImageKnob("Min Vol.", "Min Vol.", Pad[a].RS5k_Instances[WhichRS5k], 2, 19, 2)
  r.ImGui_SameLine(ctx, nil, 15)
  DrawImageKnob("Pan", "Pan", Pad[a].RS5k_Instances[WhichRS5k], 1, 19, 10)
  r.ImGui_SameLine(ctx, nil, 15)
  DrawImageKnob("Min Velocity", "Min Velocity", Pad[a].RS5k_Instances[WhichRS5k], 17, 19, -13)
  r.ImGui_SameLine(ctx, nil, 20)
  DrawImageKnob("Max Velocity", "Max Velocity", Pad[a].RS5k_Instances[WhichRS5k], 18, 19, -10)
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