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