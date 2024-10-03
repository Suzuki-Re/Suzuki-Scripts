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
  local DL = im.GetForegroundDrawList(ctx)
  L, T = im.GetItemRectMin(ctx)
  R, B = im.GetItemRectMax(ctx)
  if im.IsMouseHoveringRect(ctx, L, T, R, B) then
      im.DrawList_AddRect(DL, L, T, R, B, 0x99999999)
      im.DrawList_AddRectFilled(DL, L, T, R, B, 0x99999933)
      if IsLBtnClicked then
          im.DrawList_AddRect(DL, L, T, R, B, 0x999999dd)
          im.DrawList_AddRectFilled(DL, L, T, R, B, 0xffffff66)
          return true
      end
  end
end

function Highlight_Itm(drawlist, FillClr, OutlineClr)
  local L, T = im.GetItemRectMin(ctx);
  local R, B = im.GetItemRectMax(ctx);
  
  if FillClr then im.DrawList_AddRectFilled(drawlist, L, T, R, B, FillClr, rounding) end
  if OutlineClr then im.DrawList_AddRect(drawlist, L, T, R, B, OutlineClr, rounding) end
end

local function ColorIcon(name, color)
  local xs, ys = im.GetItemRectMin(ctx)
  local xe, ye = im.GetItemRectMax(ctx)
  im.PushFont(ctx, ICONS_FONT) 
  local w = xe - xs
  local h = ye - ys
  local label_size = im.CalcTextSize(ctx, name)
  local FONT_SIZE = im.GetFontSize(ctx)

  im.DrawList_AddTextEx(draw_list, nil, FONT_SIZE, xs + (w / 2) - (label_size / 2),
    ys + ((h / 2)) - FONT_SIZE / 2, color, name)
   im.PopFont(ctx) 
end

local function ParameterSwitchIcon(a, label, parm)
  local switch = r.TrackFX_GetParam(track, Pad[a].RS5k_Instances[WhichRS5k], parm)
  if switch == 1 then
    icon_color = 0xfffffffff
  elseif switch == 0 then
    icon_color = 0x999999e0
  end
  im.PushStyleColor(ctx, im.Col_Button,        0x00)
  im.PushStyleColor(ctx, im.Col_ButtonHovered, 0x9999993c)
  im.PushStyleColor(ctx, im.Col_ButtonActive,  0x9999996f)
  local rv = im.Button(ctx, "##" .. label, 30, 30)
  im.PopStyleColor(ctx, 3)
  ColorIcon("\\", icon_color)
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
    if rv and switch == 1 then -- rv == true at the moment when clicking it and toggle note_offs boolean
      r.TrackFX_SetParam(track, Pad[a].RS5k_Instances[WhichRS5k], parm, 0) -- off
    elseif rv and switch == 0 then
      r.TrackFX_SetParam(track, Pad[a].RS5k_Instances[WhichRS5k], parm, 1) -- on
    end
  end
end

local function ParameterSwitch(a, label, parm)
  local rv = r.TrackFX_GetParam(track, Pad[a].RS5k_Instances[WhichRS5k], parm)
  local switch
  if rv == 1 then -- on
    switch = true
  else -- off
    switch = false
  end
  --im.PushFont(ctx, antonio_semibold)
  local rv, switch = im.Checkbox(ctx, label, switch)
  --im.PopFont(ctx)
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
  local w, h = im.Image_GetSize(img)
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
  local center = { im.Viewport_GetCenter(im.GetWindowViewport(ctx)) }
  im.SetNextWindowPos(ctx, center[1], center[2], im.Cond_Appearing, 0.5, 0.5)
  if im.BeginPopupModal(ctx, 'Do you want to save default value?##' .. label, nil, im.WindowFlags_AlwaysAutoResize) then
    if im.IsWindowAppearing(ctx) then
      im.SetKeyboardFocusHere(ctx)
    end
    if im.Button(ctx, 'YES', 120, 0) or im.IsKeyPressed(ctx, im.Key_Enter) or
        im.IsKeyPressed(ctx, im.Key_KeypadEnter) then
        Saveini(fxidx)
      im.CloseCurrentPopup(ctx)
    end
    im.SetItemDefaultFocus(ctx)
    im.SameLine(ctx)
    if im.Button(ctx, 'NO', 120, 0) or im.IsKeyPressed(ctx, im.Key_Escape) then
      im.CloseCurrentPopup(ctx)
    end
    im.EndPopup(ctx)
  end
end

function ParameterTooltip(fxidx, parm)
  if im.BeginTooltip(ctx) then -- show parameter value
    local _, parm_v = r.TrackFX_GetFormattedParamValue(track, fxidx, parm)
    im.PushFont(ctx, antonio_semibold)
    im.PushTextWrapPos(ctx, im.GetFontSize(ctx) * 35.0)
    im.PopFont(ctx)
    im.Text(ctx, parm_v)
    im.PopTextWrapPos(ctx)
    im.EndTooltip(ctx)
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
  local draw_list = im.GetWindowDrawList(ctx)
  if not im.ValidatePtr(Image, 'ImGui_Image*') then
    Image = im.CreateImage(script_path .. "Images/FancyBlueKnob.png")
  end
  local pos          = {im.GetCursorScreenPos(ctx)}
  local Radius       = Radius or 0
  local radius_outer = Radius
  local center       = {pos[1] + radius_outer, pos[2] + radius_outer}
  local line_height = im.GetTextLineHeight(ctx)
  local rv = im.InvisibleButton(ctx, label .. "##" .. label_id, radius_outer * 2, radius_outer * 2 + line_height + 0 + (-line_height or 0))
  if im.IsItemHovered(ctx) and not im.IsItemActive(ctx) then -- mousewheel to change values
    local v, h = im.GetMouseWheel(ctx)
    local stepscale = 1
    if SHIFT then stepscale = 6 end
    local step = (1 - 0) / (200.0 * stepscale)
    GetSetParamValues(fxidx, parm, (4 * v), step)
    ParameterTooltip(fxidx, parm)
  end
  local BtnL, BtnT = im.GetItemRectMin(ctx)
  local BtnR, BtnB = im.GetItemRectMax(ctx)

  im.DrawList_AddTextEx(draw_list, antonio_semibold, 16, pos[1] + offset, BtnB, 0xffffffff, label) -- parameter name
  if im.IsItemHovered(ctx) and im.IsMouseDoubleClicked(ctx, 0) then -- reset value
    Readini(fxidx, parm)
  end
  if im.IsItemClicked(ctx, 1) and CTRL then
    im.OpenPopup(ctx, 'Do you want to save default value?##' .. label)
  --elseif im.IsItemClicked(ctx, 0) and ALT then -- input box
    --im.OpenPopup(ctx, 'input value##' .. label)
  elseif im.IsItemActive(ctx) then -- when dragging parameter
    local mouse_delta = { im.GetMouseDelta(ctx) }
    if -mouse_delta[2] ~= 0.0 then
      if label == "Pitch" then
        if SHIFT then 
          stepscale = 3 
        else
          stepscale = 0.8
        end
      elseif parm == 23 then -- loop start_pos
        if SHIFT then 
          stepscale = 50
        else
          stepscale = 30
        end
      elseif parm == 22 then -- xfade
        if SHIFT then 
          stepscale = 7
        else
          stepscale = 3
        end
      else
        if SHIFT then 
          stepscale = 3 
        else
          stepscale = 1
        end
      end
      local step = 1 / (200.0 * stepscale)
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
    local _, Y_Pos = im.GetCursorScreenPos(ctx)
    local window_padding = { im.GetStyleVar(ctx, im.StyleVar_WindowPadding) }
    im.SetNextWindowPos(ctx, pos[1] + radius_outer / 2, Y_Pos or pos[2] - line_height - window_padding[2] - 8)
    ParameterTooltip(fxidx, parm)
  end
  if im.BeginPopup(ctx, "input value##" .. label) then
    if im.IsWindowAppearing(ctx) then
      im.SetKeyboardFocusHere(ctx)
    end
    im.Text(ctx, 'Put values:')
    rv, input = im.InputText(ctx, label, input)
    if im.Button(ctx, 'OK', 120, 0) or im.IsKeyPressed(ctx, im.Key_Enter) or
      im.IsKeyPressed(ctx, im.Key_KeypadEnter) then
      for p = 0, 1 do
        local _, p_value = r.TrackFX_FormatParamValueNormalized(track, fxidx, parm, p, "")
        if p_value == input then
          r.TrackFX_SetParamNormalized(track, fxidx, parm, p)
          return
        end
      end
    end
    im.SetItemDefaultFocus(ctx)
    im.SameLine(ctx)
    if im.Button(ctx, 'Close') then
      im.CloseCurrentPopup(ctx)
    end
    im.EndPopup(ctx)
  end
  DefaultValueWindow(label, fxidx)

  if Image then
    local w, h = im.Image_GetSize(Image)
    if h > w * 5 then -- It's probably a strip knob file
      local scale = 2
      local sz = radius_outer * scale
      uvmin, uvmax = CalculateStripUV(Image, r.TrackFX_GetParamNormalized(track, fxidx, parm))
      im.DrawList_AddImage(draw_list, Image, center[1] - sz / 2, center[2] - sz / 2, center[1] + sz / 2,
              center[2] + sz / 2, 0, uvmin, 1, uvmax, 0xffffffff)
    end
  end
end

function PositionOffset(x_offset, y_offset)
  local x, y = im.GetCursorScreenPos(ctx)
  im.SetCursorScreenPos(ctx, x + x_offset, y + y_offset)
end

local function LoopSwitch(a)
  local loop = r.TrackFX_GetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 12) -- Loop Switch
  if loop == 1 then
    loop_color = 0xfffffffff
  elseif loop == 0 then
    loop_color = 0x999999e0
  end
  --im.PushFont(ctx, antonio_semibold)
  --local rv, loop = im.Checkbox(ctx, "Loop", loop)
  --im.PopFont(ctx)
  im.PushStyleColor(ctx, im.Col_Button,        0x00)
  im.PushStyleColor(ctx, im.Col_ButtonHovered, 0x9999993c)
  im.PushStyleColor(ctx, im.Col_ButtonActive,  0x9999996f)
  local rv = im.Button(ctx, "##Loop", 34, 20)
  im.PopStyleColor(ctx, 3)
  ColorIcon("R", loop_color)
  if rv and loop == 1 then
    loop = 0
  elseif rv and loop == 0 then
    loop = 1
  end
  r.CF_Preview_SetValue(preview, 'B_LOOP', loop) 
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
    if rv and loop == 0 then -- rv == true at the moment when clicking it and toggle note_offs boolean
      r.TrackFX_SetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 12, 0)
    elseif rv and loop == 1 then
      local rv = r.TrackFX_GetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 11)
      if rv == 0 then
        r.TrackFX_SetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 11, 1)
      end
      r.TrackFX_SetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 12, 1)
    end
  end
  if loop == 1 then
    im.SameLine(ctx, nil, 8)
    DrawImageKnob("XFade", a, Pad[a].RS5k_Instances[WhichRS5k], 22, 15, 0)
    im.SameLine(ctx, nil, 8)
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

local function ChangeSample(track, fxidx, a, up, down, random)
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
  if up then
    new_idx = idx - 1
    if new_idx < 1 then
      new_idx = #files
    end
    up = false
  elseif down then
    new_idx = idx + 1
    if new_idx > #files then
      new_idx = 1
    end
    down = false
  elseif random then
    new_idx = math.random(#files)
    while new_idx == idx do
      new_idx = math.random(#files)
    end
    random = false
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
  return new_sample
end

local function ArrowButtons(a)
  local spacing = im.GetStyleVar(ctx, im.StyleVar_ItemInnerSpacing)
  im.PushButtonRepeat(ctx, true)
  if im.ArrowButton(ctx, '##changeinstance_left', im.Dir_Left) then
    WhichRS5k = WhichRS5k - 1
    if WhichRS5k < 1 then
      WhichRS5k = #Pad[a].RS5k_Instances
    end 
  end
  im.SameLine(ctx, 0.0, spacing)
  if im.ArrowButton(ctx, '##changeinstance_right', im.Dir_Right) then
    WhichRS5k = WhichRS5k + 1
    if WhichRS5k > #Pad[a].RS5k_Instances then
      WhichRS5k = 1
    end 
  end
  im.PopButtonRepeat(ctx)
end

local function OpenSamplesDir(open)
  if r.HasExtState("ReaDrum Machine", "preview_file") then
    sample_path = r.GetExtState("ReaDrum Machine", "preview_file")
    if OS == "Win32" or OS == "Win64" then
      last_separator_index = string.find(sample_path, "\\[^\\]*$")
    else
      last_separator_index = string.find(sample_path, "/[^/]*$")
    end
    samples_path = string.sub(sample_path, 1, last_separator_index - 1)
  else
    samples_path = r.GetResourcePath()
  end
  if open then
    if OS == "Win64" or OS == "Win32" then
      r.ExecProcess('explorer.exe /e, ' .. samples_path, -1)
    else
      r.ExecProcess('/usr/bin/open ' .. samples_path, -1)
    end
  end
end

local function GetSamplePeaks(src, disp_w)
  if not src then return nil, 0 end
  local source_length = r.GetMediaSourceLength(src)
  local numchannels = 2
  local starttime = 0
  local peakrate = disp_w / source_length
  local n_spls = math.floor(source_length * peakrate + 0.5)
  local buf = r.new_array(n_spls * numchannels * 3)
  local retval = r.PCM_Source_GetPeaks(src, peakrate, starttime, numchannels, n_spls, 0, buf)
  local spl_cnt = (retval & 0xfffff)
  return buf, spl_cnt
end

local function BuildPeaks(src)
  r.PCM_Source_BuildPeaks(src, 0)
  local ret
  while ret ~= 0 do
    ret = r.PCM_Source_BuildPeaks(src, 1)
  end
  r.PCM_Source_BuildPeaks(src, 2)
end

local function WaveformButton(ctx, sample_path, a)
  cursor_x, cursor_y = im.GetCursorScreenPos(ctx)
  im.SetNextItemAllowOverlap(ctx)
  local button_width, button_height = 360, 100
  im.PushStyleColor(ctx, im.Col_Button,        0x00)
  im.PushStyleColor(ctx, im.Col_ButtonHovered, 0x9999993c)
  im.PushStyleColor(ctx, im.Col_ButtonActive,  0x9999996f)
  local open = im.Button(ctx, "##Waveform_Button", button_width, button_height)
  im.PopStyleColor(ctx, 3)
  DndAddSampleToEachRS5k_TARGET(a, Pad[a].RS5k_Instances[WhichRS5k], 0)
  if open then
    if ALT then
      r.TrackFX_SetNamedConfigParm(track, Pad[a].RS5k_Instances[WhichRS5k], '-FILE*', '')
    else
      --OpenSamplesDir(open)
    end
  end
  
  if pcm_path ~= sample_path or not pcm_path and not r.ValidatePtr(pcm, "PCM_source*") then
    pcm_path = sample_path
    pcm = r.PCM_Source_CreateFromFile(pcm_path)
  end
  
  if pcm then
    local peaks, spl_cnt = GetSamplePeaks(pcm, button_width)
    if sample_path and peaks and spl_cnt == 0 then
      BuildPeaks(pcm)
    end
    if peaks then
      local draw_list = im.GetWindowDrawList(ctx)
      local scale_x = button_width / (spl_cnt - 1)     -- Scale factor for x-axis
      local center_y = cursor_y + (button_height + samplename_height) / 2
      tbl_peak_top = {}
      tbl_peak_bottom = {}
      for i = 1, spl_cnt - 1 do
        local max_peak = peaks[i * 2 - 1]
        local min_peak = peaks[i * 2]
        local peak_x = cursor_x + (i - 1) * scale_x
        local top_peak = center_y - max_peak * (button_height - samplename_height) / 2
        local bottom_peak = center_y + min_peak * (button_height - samplename_height) / 2
        table.insert(tbl_peak_top, peak_x)
        table.insert(tbl_peak_top, top_peak)
        table.insert(tbl_peak_bottom, peak_x)
        table.insert(tbl_peak_bottom, bottom_peak)
        im.DrawList_AddLine(draw_list, peak_x, center_y, peak_x, top_peak, 0x123456ff, 1)
        im.DrawList_AddLine(draw_list, peak_x, center_y, peak_x, bottom_peak, 0x123456ff, 1)
      end
      local arr = r.new_array(tbl_peak_top)
      local arr2 = r.new_array(tbl_peak_bottom)
      im.DrawList_AddPolyline(draw_list, arr, 0xffffffff, im.DrawFlags_None, 1)
      im.DrawList_AddPolyline(draw_list, arr2, 0xffffffff, im.DrawFlags_None, 1)
    end
  end

  local start_pos = r.TrackFX_GetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 13)
  local start_line = cursor_x + 360 * start_pos
  local end_pos = r.TrackFX_GetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 14)
  local end_line = cursor_x + 360 * end_pos
  im.DrawList_AddLine(f_draw_list, start_line, cursor_y + samplename_height, start_line, cursor_y + button_height, 0xffeb00ff, 3)
  im.DrawList_AddRectFilled(f_draw_list, cursor_x, cursor_y + samplename_height, start_line, cursor_y + button_height, 0x1a1a1a99)
  im.DrawList_AddLine(f_draw_list, end_line, cursor_y + samplename_height, end_line, cursor_y + button_height, 0xffeb00ff, 3)
  im.DrawList_AddRectFilled(f_draw_list, end_line + 1, cursor_y + samplename_height, cursor_x + button_width, cursor_y + button_height, 0x1a1a1a99)

  --[[local attack = r.TrackFX_GetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 9)
  local decay = r.TrackFX_GetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 24)
  local sustain = r.TrackFX_GetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 25)
  local release = r.TrackFX_GetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 10)
  im.DrawList_AddLine(f_draw_list, start_line, cursor_y + button_height, start_line + 100, cursor_y + samplename_height, 0xff4500ff, 3)]]

  local loop = r.TrackFX_GetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 12)
  if loop == 1 then
    local media_length, _ = r.GetMediaSourceLength(pcm)
    local active_width = (end_line - start_line) / button_width
    local active_length = media_length * active_width
    local loop_start = r.TrackFX_GetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 23)
    --msg(loop_start * 30000, xfade * 1000) -- ms conversion
    local loop_startline = start_line + (30 * loop_start * button_width) / media_length
    if loop_startline > end_line then
      loop_startline = end_line
    end
    im.DrawList_AddLine(f_draw_list, loop_startline, cursor_y + samplename_height * 2, loop_startline, cursor_y + button_height, 0xea5506ff, 3)
    local xfade = r.TrackFX_GetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 22)
    local xfade_startline = loop_startline + (xfade * button_width) / media_length
    local xfade_endline = end_line - (xfade * button_width) / media_length
    if xfade_startline > (end_line - loop_startline) / 2 + loop_startline then
      xfade_startline = (end_line - loop_startline) / 2 + loop_startline
    end
    if xfade_endline < (end_line - loop_startline) / 2 + loop_startline then
      xfade_endline = (end_line - loop_startline) / 2 + loop_startline
    end
    if xfade_endline < xfade_startline then
      xfade_startline = xfade_endline
      xfade_endline = xfade_startline
    end
    im.DrawList_AddLine(draw_list, xfade_startline, cursor_y + samplename_height * 2, xfade_startline, cursor_y + button_height, 0xffffffaa, 1)
    im.DrawList_AddLine(draw_list, xfade_endline, cursor_y + samplename_height * 2, xfade_endline, cursor_y + button_height, 0xffffffaa, 1)
    im.DrawList_AddLine(draw_list, xfade_startline, cursor_y + samplename_height * 2, loop_startline, cursor_y + button_height, 0xffffffaa, 1)
    im.DrawList_AddLine(draw_list, xfade_endline, cursor_y + samplename_height * 2, end_line, cursor_y + button_height, 0xffffffaa, 1)
  end

  if im.IsItemActive(ctx) then
    local mouse_x, _ = im.GetMouseClickedPos(ctx, 0)
    if im.IsMouseClicked(ctx, 0) then
      start_x = start_line
      end_x = end_line
    end
    mouse_delta, _ = im.GetMouseDelta(ctx)
    if mouse_delta ~= 0.0 then
      if end_x - mouse_x > mouse_x - start_x then
        local start_pos = start_pos + mouse_delta / 350
        if start_pos < 0 then
          start_pos = 0
        elseif start_pos > 1 then
          start_pos = 1
        elseif start_pos > end_pos then
          start_pos = end_pos
        end
        r.TrackFX_SetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 13, start_pos)
      elseif mouse_x - start_x > end_x - mouse_x then
        local end_pos = end_pos + mouse_delta / 350
        if end_pos < 0 then
          end_pos = 0
        elseif end_pos > 1 then
          end_pos = 1
        elseif start_pos > end_pos then
          end_pos = start_pos
        end
        r.TrackFX_SetParam(track, Pad[a].RS5k_Instances[WhichRS5k], 14, end_pos)
      end
    end
  end
end

local function TriggerSamples(rv, a, WhichRS5k, up, down, random)
  if not im.IsItemHovered(ctx) then return end
  if rv then
    ChangeSample(track, Pad[a].RS5k_Instances[WhichRS5k], a, up, down, random)
    r.TrackFX_SetParam(track, Pad[a].Filter_ID, 2, 1)
  else
    r.TrackFX_SetParam(track, Pad[a].Filter_ID, 2, 0)
  end
end

local function ChangeSampleButtons(a)
  im.PushStyleColor(ctx, im.Col_Button,        0x00)
  im.PushStyleColor(ctx, im.Col_ButtonHovered, 0x9999993c)
  im.PushStyleColor(ctx, im.Col_ButtonActive,  0x9999996f)
  im.PushButtonRepeat(ctx, true)
  local rv = im.ArrowButton(ctx, '##changesample_left', im.Dir_Left)
  TriggerSamples(rv, a, WhichRS5k, true, false, false)
  im.PopButtonRepeat(ctx)
  im.PopStyleColor(ctx, 3)
  im.SameLine(ctx, 0, 0)
  im.PushStyleColor(ctx, im.Col_Button,        0x00)
  im.PushStyleColor(ctx, im.Col_ButtonHovered, 0x9999993c)
  im.PushStyleColor(ctx, im.Col_ButtonActive,  0x9999996f)
  im.PushButtonRepeat(ctx, true)
  local rv = im.Button(ctx, "##randomizesample_button", 20, 20)
  DrawListButton("Q", 0x00, false, true)
  TriggerSamples(rv, a, WhichRS5k, false, false, true)
  im.PopButtonRepeat(ctx)
  im.PopStyleColor(ctx, 3)
  im.SameLine(ctx, 0, 0)
  im.PushStyleColor(ctx, im.Col_Button,        0x00)
  im.PushStyleColor(ctx, im.Col_ButtonHovered, 0x9999993c)
  im.PushStyleColor(ctx, im.Col_ButtonActive,  0x9999996f)
  im.PushButtonRepeat(ctx, true)
  local rv = im.ArrowButton(ctx, '##changesample_right', im.Dir_Right)
  TriggerSamples(rv, a, WhichRS5k, false, true, false)
  im.PopButtonRepeat(ctx)
  im.PopStyleColor(ctx, 3)
end

local function BrowseSamplesButton(a)
  im.PushStyleColor(ctx, im.Col_Button,        0x00)
  im.PushStyleColor(ctx, im.Col_ButtonHovered, 0x9999993c)
  im.PushStyleColor(ctx, im.Col_ButtonActive,  0x9999996f)
  local rv = im.Button(ctx, "##Browse Samples", 19, 19)
  im.PopStyleColor(ctx, 3)
  DrawListButton("O", 0x00, nil, true)
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
end

local function SampleNameButton(a)
  im.PushStyleColor(ctx, im.Col_Button,        0x00)
  im.PushStyleColor(ctx, im.Col_ButtonHovered, 0x9999993c)
  im.PushStyleColor(ctx, im.Col_ButtonActive,  0x9999996f)
  local rv = im.Button(ctx, sample_name) -- Sample name
  im.PopStyleColor(ctx, 3)
  DndAddSampleToEachRS5k_TARGET(a, Pad[a].RS5k_Instances[WhichRS5k], 0)
  if DownArrow then
    local new_sample = ChangeSample(track, Pad[a].RS5k_Instances[WhichRS5k], a, false, true, false)
    PreviewSamples(new_sample, a)
  elseif UpArrow then
    local new_sample = ChangeSample(track, Pad[a].RS5k_Instances[WhichRS5k], a, true, false, false)
    PreviewSamples(new_sample, a)
  elseif im.IsKeyPressed(ctx, im.Key_R) then
    local new_sample = ChangeSample(track, Pad[a].RS5k_Instances[WhichRS5k], a, false, false, true)
    PreviewSamples(new_sample, a)
  end
  if rv then
    local open = r.TrackFX_GetOpen(track, Pad[a].RS5k_Instances[WhichRS5k]) -- 0 based
    if open then
      r.TrackFX_Show(track, Pad[a].RS5k_Instances[WhichRS5k], 2)           -- hide floating window
    else
      r.TrackFX_Show(track, Pad[a].RS5k_Instances[WhichRS5k], 3)           -- show floating window
    end
  end
end

local function EmptySampleButton(a)
  cursor_x, cursor_y = im.GetCursorScreenPos(ctx)
  im.SetNextItemAllowOverlap(ctx)
  local open = im.InvisibleButton(ctx, "Click to browse or drag/drop samples here.", 360, 100)
  DrawListButton("Click to browse or drag/drop samples here.", 0x00)
  if open then
    OpenSamplesDir(open)
  end
  DndAddSampleToEachRS5k_TARGET(a, Pad[a].RS5k_Instances[WhichRS5k], 0)
end

function RS5kUI(a)
  if not Pad[a] then return end
  if not Pad[a].RS5k_Instances[WhichRS5k] and WhichRS5k > #Pad[a].RS5k_Instances then WhichRS5k = 1 end
  im.PushStyleColor(ctx, im.Col_Button,        0x99999900)
  im.PushStyleColor(ctx, im.Col_ButtonHovered, 0x9999993c)
  im.PushStyleColor(ctx, im.Col_ButtonActive,  0x9999996f)
  local rv = im.Button(ctx, "##play_button", 19, 19) -- play button
  im.PopStyleColor(ctx, 3)
  DrawListButton(">", 0x00, nil, true, true)
  SendMidiNote(a)
  im.SameLine(ctx, 0, 5)
  im.PushStyleColor(ctx, im.Col_Button,        0x99999900)
  im.PushStyleColor(ctx, im.Col_ButtonHovered, 0x9999993c)
  im.PushStyleColor(ctx, im.Col_ButtonActive,  0x9999996f)
  local rv = im.Button(ctx, "##stop_button", 19, 19) -- stop button
  im.PopStyleColor(ctx, 3)
  DrawListButton("/", 0x00, nil, true, true)
  if rv and preview then
    r.CF_Preview_Stop(preview)
    preview = nil
  elseif rv then
    r.StuffMIDIMessage(0, 0x80, Pad[a].Note_Num, 96) -- send note off
  end
  im.SameLine(ctx)
  ArrowButtons(a)
  im.SameLine(ctx, 0, 5)
  if Pad[a].Sample_Name[WhichRS5k] then
    sample_name = Pad[a].Sample_Name[WhichRS5k]
  else
    sample_name = "Empty"
  end
  im.SameLine(ctx)
  im.PushStyleColor(ctx, im.Col_Button,        0x99999900)
  im.PushStyleColor(ctx, im.Col_ButtonHovered, 0x9999993c)
  im.PushStyleColor(ctx, im.Col_ButtonActive,  0x9999996f)
  --im.PushFont(ctx, system_font)
  local rv = im.Button(ctx, "RS5k[" .. ('%d'):format(WhichRS5k) .. "]") -- RS5k instance number
  --im.PopFont(ctx)
  local _, ys = im.GetItemRectMin(ctx)
  local _, ye = im.GetItemRectMax(ctx)
  samplename_height = ye - ys
  DndAddSampleToEachRS5k_TARGET(a, Pad[a].RS5k_Instances[WhichRS5k], 0)
  if rv then
    local open = r.TrackFX_GetOpen(track, Pad[a].RS5k_Instances[WhichRS5k]) -- 0 based
    if open then
      r.TrackFX_Show(track, Pad[a].RS5k_Instances[WhichRS5k], 2)           -- hide floating window
    else
      r.TrackFX_Show(track, Pad[a].RS5k_Instances[WhichRS5k], 3)           -- show floating window
    end
  end
  im.PopStyleColor(ctx, 3)

  local _, sample_path = r.TrackFX_GetNamedConfigParm(track, Pad[a].RS5k_Instances[WhichRS5k], "FILE0")
  if sample_path ~= "" then
    WaveformButton(ctx, sample_path, a)
  else
    EmptySampleButton(a)
  end

  im.SetCursorScreenPos(ctx, cursor_x, cursor_y)
  BrowseSamplesButton(a)
  im.SameLine(ctx, 0, 0)
  ChangeSampleButtons(a)
  im.SameLine(ctx, 0, 0)
  SampleNameButton(a)
  im.SetCursorScreenPos(ctx, cursor_x, cursor_y + 105)
  --im.Separator(ctx)
  DrawImageKnob("Pitch", a, Pad[a].RS5k_Instances[WhichRS5k], 15, 19, 10)
  im.SameLine(ctx, 0, 10)
  PositionOffset(0, 10)
  LoopSwitch(a)
  im.SameLine(ctx, 0, 10)
  DrawImageKnob("A", a, Pad[a].RS5k_Instances[WhichRS5k], 9, 19, 17)
  im.SameLine(ctx, 0, 8)
  DrawImageKnob("D", a, Pad[a].RS5k_Instances[WhichRS5k], 24, 19, 17)
  im.SameLine(ctx, 0, 8)
  DrawImageKnob("S", a, Pad[a].RS5k_Instances[WhichRS5k], 25, 19, 17)
  im.SameLine(ctx, 0, 8)
  DrawImageKnob("R", a, Pad[a].RS5k_Instances[WhichRS5k], 10, 19, 17)
  PositionOffset(0, 16)
  --im.Separator(ctx)
  DrawImageKnob("Bend", a, Pad[a].RS5k_Instances[WhichRS5k], 16, 19, 10)
  im.SameLine(ctx, 0, 8)
  PositionOffset(0, 8)
  ParameterSwitch(a, "Obey \nnote-offs", 11)
  im.SameLine(ctx, 0, 8)
  DrawImageKnob("Start Pos", "Sample", Pad[a].RS5k_Instances[WhichRS5k], 13, 19, -3)
  im.SameLine(ctx, 0, 8)
  DrawImageKnob("End Pos", a, Pad[a].RS5k_Instances[WhichRS5k], 14, 19, 0)
  im.SameLine(ctx, 0, 15)
  DrawImageKnob("Probability", a, Pad[a].RS5k_Instances[WhichRS5k], 19, 19, -10)
  PositionOffset(0, 16)
  --im.Separator(ctx)
  DrawImageKnob("Min Vol.", "Min Vol.", Pad[a].RS5k_Instances[WhichRS5k], 2, 19, 2)
  im.SameLine(ctx, 0, 8)
  DrawImageKnob("Volume", "Volume", Pad[a].RS5k_Instances[WhichRS5k], 0, 19, 3)
  im.SameLine(ctx, 0, 8)
  DrawImageKnob("Pan", "Pan", Pad[a].RS5k_Instances[WhichRS5k], 1, 19, 10)
  im.SameLine(ctx, 0, 8)
  DrawImageKnob("Min Velocity", "Min Velocity", Pad[a].RS5k_Instances[WhichRS5k], 17, 19, -13)
  im.SameLine(ctx, 0, 20)
  DrawImageKnob("Max Velocity", "Max Velocity", Pad[a].RS5k_Instances[WhichRS5k], 18, 19, -10)
  im.SameLine(ctx, 0, 10)
  PositionOffset(10, 5)
  ParameterSwitchIcon(a, "Round-Robin", 20)  
end

function CustomTitleBar(button_pos)
  im.BeginGroup(ctx)
  im.PushFont(ctx, antonio_semibold_large)
  im.Text(ctx, "ReaDrum Machine")
  im.PopFont(ctx)
  if track then
    im.SameLine(ctx)
    --im.AlignTextToFramePadding(ctx)
    im.PushFont(ctx, antonio_light)
    im.Text(ctx, track_name)
    im.PopFont(ctx)
  end
  im.SameLine(ctx, button_pos)
  im.PushStyleColor(ctx, im.Col_Button,        0x99999900)
  im.PushStyleColor(ctx, im.Col_ButtonHovered, 0x9999993c)
  im.PushStyleColor(ctx, im.Col_ButtonActive,  0x9999996f)
  local rv = im.Button(ctx, "##settings", 22, 22)
  DrawListButton("$", 0x00, nil, true)
  im.PopStyleColor(ctx, 3)
  if rv then
    im.OpenPopup(ctx, "Settings")
  end
  if im.BeginPopup(ctx, "Settings", im.WindowFlags_NoMove) then
    _, pitch_as_parameter = im.Checkbox(ctx, "Apply Pitch as RS5k Parameter", pitch_as_parameter)
    r.SetExtState("ReaDrum Machine", "pitch_settings", tostring(pitch_as_parameter), true)
    im.EndPopup(ctx)
  end
  im.SameLine(ctx)
  PositionOffset(-5, 0)
  im.PushStyleColor(ctx, im.Col_Button,        0x99999900)
  im.PushStyleColor(ctx, im.Col_ButtonHovered, 0x9999993c)
  im.PushStyleColor(ctx, im.Col_ButtonActive,  0x9999996f)
  local rv = im.Button(ctx, "##close", 22, 22)
  DrawListButton("#", 0x00, nil, true)
  im.PopStyleColor(ctx, 3)
  if rv then
    imgui_open = nil
  end
  im.EndGroup(ctx)
  im.Separator(ctx)
end