-- @noindex
-- mousewheel mod
r = reaper

local function GetPayload()
    local retval, dndtype, payload = r.ImGui_GetDragDropPayload(ctx)
    if retval then
      return dndtype, payload
    end
  end
  
function CheckDnDType()
    local dnd_type = GetPayload()
    DND_ADD_FX = dnd_type == "DND ADD FX"
    DND_MOVE_FX = dnd_type == "DND MOVE FX"
    FX_DRAG = dnd_type == "FX_Drag"
    FX_PLINK = dnd_type == "FX PLINK"
end

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

function CalculateColor(color)
    local alpha = color & 0xFF
    local blue = (color >> 8) & 0xFF
    local green = (color >> 16) & 0xFF
    local red = (color >> 24) & 0xFF
  
    local luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255
    return luminance > 0.5 and (PLink_Edge_LightBG or CustomColorsDefault.PLink_Edge_LightBG) or (PLink_Edge_DarkBG or CustomColorsDefault.PLink_Edge_DarkBG)
end

function ButtonDraw(splitter, color, center, radius_outer) -- for drawing to clarify which destination (target) DND goes to
    r.ImGui_DrawListSplitter_SetCurrentChannel(splitter, 0)
    color = r.ImGui_IsItemHovered(ctx) and IncreaseDecreaseBrightness(color, 30) or color
    local draw_list = r.ImGui_GetWindowDrawList(ctx)
    local f_draw_list = r.ImGui_GetForegroundDrawList(ctx)
    local xs, ys = r.ImGui_GetItemRectMin(ctx)
    local xe, ye = r.ImGui_GetItemRectMax(ctx)

    local edge_color = CalculateColor(color)
  
    if FX_PLINK and r.ImGui_IsMouseHoveringRect(ctx,xs,ys,xe,ye) then
        if KNOB then
            r.ImGui_DrawList_AddCircle(f_draw_list, center[1], center[2], radius_outer, r.ImGui_GetColorEx(ctx, edge_color), 16, 5)
        else
            local x_offset = 2
            r.ImGui_DrawList_AddRect(f_draw_list, xs - x_offset, ys - x_offset, xe + x_offset, ye + x_offset, r.ImGui_GetColorEx(ctx, edge_color), 2, nil, 5)
        end
    end
end

local function WhichClick() -- to alternate left and right click flags for InvisibleButton
    if r.ImGui_IsMouseClicked(ctx, 0) then
        ClickButton =  r.ImGui_ButtonFlags_MouseButtonLeft()
    elseif r.ImGui_IsMouseClicked(ctx, 1) then
        ClickButton =  r.ImGui_ButtonFlags_MouseButtonRight()
    end
    return ClickButton
end

---@param FX_Idx integer
---@param P_Num number
local function DnD_PLink_SOURCE(FX_Idx, P_Num)
    if r.ImGui_BeginDragDropSource(ctx) and not AssigningMacro then
        local draw_list = r.ImGui_GetForegroundDrawList(ctx)
        local mouse_pos = { r.ImGui_GetMousePos(ctx) }
        local click_pos = { r.ImGui_GetMouseClickedPos(ctx, 1) }
        r.ImGui_DrawList_AddLine(draw_list, click_pos[1], click_pos[2], mouse_pos[1], mouse_pos[2], PLink or CustomColorsDefault.PLink, 4.0)  -- Draw a line between the button and the mouse cursor                                             
        lead_fxid = FX_Idx -- storing the original fx id
        fxidx = FX_Idx -- to prevent an error in layout editor function by not changing FX_Idx itself
        lead_paramnumber = P_Num      
        local ret, _ = r.TrackFX_GetNamedConfigParm(LT_Track, lead_fxid, "parent_container") 
        local rev = ret                       
        while rev do -- to get root parent container id
        root_container = fxidx
        rev, fxidx = r.TrackFX_GetNamedConfigParm(LT_Track, fxidx, "parent_container")
        end     
        if ret then       -- new fx and parameter                   
            local rv, buf = r.TrackFX_GetNamedConfigParm(LT_Track, root_container, "container_map.add." .. lead_fxid .. "." .. lead_paramnumber)
            lead_fxid = root_container
            lead_paramnumber = buf
        end 
        local data = lead_fxid .. "," .. lead_paramnumber
        r.ImGui_SetDragDropPayload(ctx, 'FX PLINK', data)
        local _, param_name = r.TrackFX_GetParamName(LT_Track, lead_fxid, lead_paramnumber)
        local retval, fx_name = r.TrackFX_GetNamedConfigParm(LT_Track, lead_fxid, "fx_name")
        r.ImGui_Text(ctx, fx_name .. " " .. param_name) -- To preview what FX + parameter we are dragging
        r.ImGui_EndDragDropSource(ctx)
    end
end

---@param FxGUID string
---@param Fx_P integer
---@param FX_Idx integer
---@param P_Num number
local function DnD_PLink_TARGET(FxGUID, Fx_P, FX_Idx, P_Num)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_DragDropTarget(), 0) -- 0 = To disable yellow rect which is on by default
    if r.ImGui_BeginDragDropTarget(ctx) then
        local rv, payload = r.ImGui_AcceptDragDropPayload(ctx, 'FX PLINK')
        local lead_fxid, lead_paramnumber = payload:match("(.+),(.+)")
        if rv then
            local rv, bf = r.TrackFX_GetNamedConfigParm(LT_Track, FX_Idx, "param.".. P_Num..".plink.midi_bus")
            if bf == "15" then -- reset FX Devices' modulation bus/chan                                  
                r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_bus", 0) -- reset bus and channel because it does not update automatically although in parameter linking midi_* is not available
                r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_chan", 1) 
                r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.effect", -1) 
                r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.active", 0)
                if FX[FxGUID][Fx_P].ModAMT then
                    for Mc = 1, 8, 1 do
                        if FX[FxGUID][Fx_P].ModAMT[Mc] then
                            FX[FxGUID][Fx_P].ModAMT[Mc] = 0
                        end
                    end
                end                                                    
            end
            if lead_fxid ~= nil then   
                follow_fxid = FX_Idx -- storing the original fx id
                fxidx = FX_Idx -- to prevent an error in layout editor function by not changing FX_Idx itself
                follow_paramnumber = P_Num      
                ret, _ = r.TrackFX_GetNamedConfigParm(LT_Track, follow_fxid, "parent_container")
                local rev = ret                            
                while rev do -- to get root parent container id
                root_container = fxidx
                rev, fxidx = r.TrackFX_GetNamedConfigParm(LT_Track, fxidx, "parent_container")
                end
                if ret then  -- fx inside container                        
                    local retval, buf = r.TrackFX_GetNamedConfigParm(LT_Track, root_container, "container_map.get." .. follow_fxid .. "." .. follow_paramnumber)                  
                    if retval then -- toggle off and remove map
                        r.TrackFX_SetNamedConfigParm(LT_Track, root_container, "param."..buf..".plink.active", 0)
                        r.TrackFX_SetNamedConfigParm(LT_Track, root_container, "param."..buf..".plink.effect", -1) 
                        r.TrackFX_SetNamedConfigParm(LT_Track, root_container, "param."..buf..".plink.param", -1) 
                        local rv, container_id = r.TrackFX_GetNamedConfigParm(LT_Track, follow_fxid, "parent_container")
                        while rv do -- removing map
                        _, buf = r.TrackFX_GetNamedConfigParm(LT_Track, container_id, "container_map.get." .. follow_fxid .. "." .. follow_paramnumber)
                        r.TrackFX_GetNamedConfigParm(LT_Track, container_id, "param." .. buf .. ".container_map.delete")
                        rv, container_id = r.TrackFX_GetNamedConfigParm(LT_Track, container_id, "parent_container")
                        end
                    else  -- new fx and parameter             
                        local rv, buf = r.TrackFX_GetNamedConfigParm(LT_Track, root_container, "container_map.add." .. follow_fxid .. "." .. follow_paramnumber) -- map to the root
                        r.TrackFX_SetNamedConfigParm(LT_Track, root_container, "param."..buf..".plink.active", 1)
                        r.TrackFX_SetNamedConfigParm(LT_Track, root_container, "param."..buf..".plink.effect", lead_fxid) -- Link (root container + new mapped container parameter) to lead FX
                        r.TrackFX_SetNamedConfigParm(LT_Track, root_container, "param."..buf..".plink.param", lead_paramnumber) 
                    end
                else -- not inside container
                    local retval, buf = r.TrackFX_GetNamedConfigParm(LT_Track, follow_fxid, "param."..follow_paramnumber..".plink.active") -- Active(true, 1), Deactivated(true, 0), UnsetYet(false)
                    if retval and buf == "1" then -- toggle off
                        value = 0
                        lead_fxid = -1
                        lead_paramnumber = -1
                    else
                        value = 1
                    end
                    r.TrackFX_SetNamedConfigParm(LT_Track, follow_fxid, "param."..follow_paramnumber..".plink.active", value)
                    r.TrackFX_SetNamedConfigParm(LT_Track, follow_fxid, "param."..follow_paramnumber..".plink.effect", lead_fxid) 
                    r.TrackFX_SetNamedConfigParm(LT_Track, follow_fxid, "param."..follow_paramnumber..".plink.param", lead_paramnumber) 
                end
            end  
        end
        r.ImGui_EndDragDropTarget(ctx)
    end
    r.ImGui_PopStyleColor(ctx)
end

local function ParameterTooltip(fxidx, parm)
    if r.ImGui_BeginTooltip(ctx) then -- show parameter value
      local _, parm_v = r.TrackFX_GetFormattedParamValue(LT_Track, fxidx, parm)
      r.ImGui_PushTextWrapPos(ctx, r.ImGui_GetFontSize(ctx) * 35.0)
      r.ImGui_PushFont(ctx, FONT)
      r.ImGui_Text(ctx, parm_v)
      r.ImGui_PopFont(ctx)
      r.ImGui_PopTextWrapPos(ctx)
      r.ImGui_EndTooltip(ctx)
    end
end
  
local function GetSetParamValues(fxidx, parm, drag_delta, step)
    local p_value = r.TrackFX_GetParamNormalized(LT_Track, fxidx, parm)
    local p_value = p_value + (drag_delta * step)
    if p_value < 0 then p_value = 0 end
    if p_value > 1 then p_value = 1 end
    r.TrackFX_SetParamNormalized(LT_Track, fxidx, parm, p_value)
end

local function AdjustParamWheel(FX_Idx, P_Num)
    if r.ImGui_IsItemHovered(ctx) and Mods == Ctrl and not r.ImGui_IsItemActive(ctx) then -- mousewheel to change values
        local stepscale = 1
        local step = (1 - 0) / (200.0 * stepscale)
        GetSetParamValues(FX_Idx, P_Num, (4 * Wheel_V), step)
        --ParameterTooltip(FX_Idx, P_Num)
    elseif r.ImGui_IsItemHovered(ctx) and Mods == Ctrl + Shift and not r.ImGui_IsItemActive(ctx) then -- mousewheel to change values slightly
        local stepscale = 6
        local step = (1 - 0) / (200.0 * stepscale)
        GetSetParamValues(FX_Idx, P_Num, (4 * Wheel_V), step)
    end
end

---@param ctx ImGui_Context
---@param label string
---@param labeltoShow string
---@param p_value number
---@param v_min number
---@param v_max number
---@param Fx_P integer
---@param FX_Idx integer
---@param P_Num number
---@param Style string
---@param Radius number
---@param item_inner_spacing number[]
---@param Disabled string
---@param LblTextSize integer
---@param Lbl_Pos "Top"|"Free"|"Bottom"|"Within"|"Left"|"None"|"Right"
---@param V_Pos? "Top"|"Free"|"Bottom"|"Within"|"Left"|"None"|"Right"
---@param ImgPath? ImGui_Image
---@return boolean
---@return number
function AddKnob(ctx, label, labeltoShow, p_value, v_min, v_max, Fx_P, FX_Idx, P_Num, Style, Radius,
                 item_inner_spacing, Disabled, LblTextSize, Lbl_Pos, V_Pos, ImgPath)
    if Style == 'Pro C' then r.gmem_attach('ParamValues') end
    local FxGUID =  r.TrackFX_GetFXGUID(LT_Track, FX_Idx)
    if not FxGUID then return end
    FX[FxGUID] = FX[FxGUID] or {}
    FX[FxGUID][Fx_P] = FX[FxGUID][Fx_P] or {}

    if FX[FxGUID].Morph_Value_Edit or Mods == Alt + Ctrl then r.ImGui_BeginDisabled(ctx) end    
    local p_value = p_value or 0
    local radius_outer = Radius or Df.KnobRadius;
    local FP = FX[FxGUID][Fx_P]
    local V_Font, Font = Arial_12, Font_Andale_Mono_12
    if LblTextSize ~= 'No Font' then
        Font = 'Font_Andale_Mono_' .. roundUp(FP.FontSize or LblTextSize or Knob_DefaultFontSize, 1)
        V_Font = 'Arial_' .. roundUp(FP.V_FontSize or LblTextSize or Knob_DefaultFontSize, 1)
        r.ImGui_PushFont(ctx, _G[Font])
    end
    local Radius       = Radius or 0

    local pos          = { r.ImGui_GetCursorScreenPos(ctx) }
    local center       = { pos[1] + radius_outer, pos[2] + radius_outer }
    local Clr_SldrGrab = Change_Clr_A(getClr(r.ImGui_Col_SliderGrabActive()), -0.2)


    local TextW = r.ImGui_CalcTextSize(ctx, labeltoShow or FX[FxGUID][Fx_P].Name, nil, nil, true)

    local CenteredLblPos, CenteredVPos

    if TextW < (Radius or 0) * 2 then
        CenteredLblPos = pos[1] + Radius - TextW / 2
    else
        CenteredLblPos = pos[1]
    end


    if DraggingMorph == FxGUID then p_value = r.TrackFX_GetParamNormalized(LT_Track, FX_Idx, P_Num) end

    local line_height = r.ImGui_GetTextLineHeight(ctx)
    local draw_list = r.ImGui_GetWindowDrawList(ctx)
    local f_draw_list = r.ImGui_GetForegroundDrawList(ctx)
    local SPLITTER = r.ImGui_CreateDrawListSplitter(draw_list)
    r.ImGui_DrawListSplitter_Split(SPLITTER, 2)

    local item_inner_spacing = { item_inner_spacing, item_inner_spacing } or
        { { r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_ItemInnerSpacing()) } }
    local mouse_delta = { r.ImGui_GetMouseDelta(ctx) }
    local F_Tp = FX.Prm.ToTrkPrm[FxGUID .. Fx_P] or 0

    local ANGLE_MIN = 3.141592 * 0.75
    local ANGLE_MAX = 3.141592 * 2.25
    local BtnOffset
    
    if Lbl_Pos == 'Top' then BtnOffset = -line_height end

    WhichClick()
    r.ImGui_InvisibleButton(ctx, label, radius_outer * 2,
        radius_outer * 2 + line_height + item_inner_spacing[2] + (BtnOffset or 0), ClickButton) -- ClickButton to alternate left/right dragging
        if ClickButton == r.ImGui_ButtonFlags_MouseButtonLeft() then -- left drag to adjust parameters
            if r.ImGui_BeginDragDropSource(ctx, r.ImGui_DragDropFlags_SourceNoPreviewTooltip()) then
                r.ImGui_SetDragDropPayload(ctx, 'my_type', 'my_data')
                Knob_Active  = true
                Clr_SldrGrab = getClr(r.ImGui_Col_Text())

                HideCursorTillMouseUp(0)
                r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_None())
                if -mouse_delta[2] ~= 0.0 then
                    local stepscale = 1
                    if Mods == Shift then stepscale = 3 end
                    local step = (v_max - v_min) / (200.0 * stepscale)
                    p_value = p_value + (-mouse_delta[2] * step)
                    if p_value < v_min then p_value = v_min end
                    if p_value > v_max then p_value = v_max end
                    value_changed = true
                    r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, P_Num, p_value)
                    MvingP_Idx = F_Tp
                    Tweaking = P_Num .. FxGUID
                end
                r.ImGui_EndDragDropSource(ctx)
            end
        elseif ClickButton ==  r.ImGui_ButtonFlags_MouseButtonRight() and not AssigningMacro then -- right drag to link parameters
            DnD_PLink_SOURCE(FX_Idx, P_Num)
        end
        KNOB = true
        DnD_PLink_TARGET(FxGUID, Fx_P, FX_Idx, P_Num)
        ButtonDraw(SPLITTER, FX[FxGUID].BgClr or CustomColorsDefault.FX_Devices_Bg, center, radius_outer)
        AdjustParamWheel(FX_Idx, P_Num)
    if V_Pos == 'Free' then
        local Ox, Oy = r.ImGui_GetCursorScreenPos(ctx)
        r.ImGui_DrawList_AddTextEx(draw_list, _G[V_Font], FX[FxGUID][Fx_P].V_FontSize or Knob_DefaultFontSize,
            pos[1] + (FP.V_Pos_X or 0), pos[2] + (FP.V_Pos_Y or 0), FX[FxGUID][Fx_P].V_Clr or 0xffffffff, FormatPV,
            (Radius or 20) * 2)
    end

    if FP.Lbl_Pos == 'Free' then
        local Cx, Cy = r.ImGui_GetCursorScreenPos(ctx)
        r.ImGui_DrawList_AddTextEx(draw_list, _G[Font], FP.FontSize or LblTextSize or Knob_DefaultFontSize,
            pos[1] + (FP.Lbl_Pos_X or 0), pos[2] + (FP.Lbl_Pos_Y or 0), FP.Lbl_Clr or getClr(r.ImGui_Col_Text()),
            FP.CustomLbl or FP.Name)
    end


    local BtnL, BtnT = r.ImGui_GetItemRectMin(ctx)
    local BtnR, BtnB = r.ImGui_GetItemRectMax(ctx)
    if Lbl_Pos == 'Top' then
        r.ImGui_DrawList_AddTextEx(draw_list, _G[Font], FX[FxGUID][Fx_P].FontSize or Knob_DefaultFontSize,
            CenteredLblPos or pos[1], BtnT - line_height + item_inner_spacing[2], FP.Lbl_Clr or 0xffffffff,
            labeltoShow or FP.Name, nil, pos[1], BtnT - line_height, pos[1] + Radius * 2, BtnT + line_height)
    end

    local value_changed = false
    local is_active = r.ImGui_IsItemActive(ctx)
    local is_hovered = r.ImGui_IsItemHovered(ctx)
    if (is_hovered or Tweaking == P_Num .. FxGUID) and (V_Pos == 'None' or not V_Pos) then
        local get, PV = r.TrackFX_GetFormattedParamValue(LT_Track, FX_Idx, P_Num)
        if get then
            local Y_Pos
            if Lbl_Pos == 'Top' then _, Y_Pos = r.ImGui_GetCursorScreenPos(ctx) end
            local window_padding = { r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()) }
            r.ImGui_SetNextWindowPos(ctx, pos[1] + radius_outer / 2,
                Y_Pos or pos[2] - line_height - window_padding[2] - 8)
            r.ImGui_BeginTooltip(ctx)
            r.ImGui_Text(ctx, PV)
            r.ImGui_EndTooltip(ctx)
        end
        Clr_SldrGrab = getClr(r.ImGui_Col_SliderGrabActive())
    end


    if Knob_Active == true then
        if IsLBtnHeld == false then Knob_Active = false end
    end


    local t = (p_value - v_min) / (v_max - v_min)

    local angle = ANGLE_MIN + (ANGLE_MAX - ANGLE_MIN) * t

    local angle_cos, angle_sin = math.cos(angle), math.sin(angle)
    local radius_inner = radius_outer * 0.40


    local ClrBg = r.ImGui_GetColor(ctx, r.ImGui_Col_FrameBg())
    if Style == 'Pro C' then
        local offset; local TxtClr = 0xD9D9D9ff
        if labeltoShow == 'Release' then offset = 5 else offset = nil end

        r.ImGui_DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_outer,
            FX[FxGUID][Fx_P].BgClr or 0xC7A47399)
        r.ImGui_DrawList_AddLine(draw_list, center[1] + angle_cos * radius_inner, center[2] + angle_sin *
            radius_inner, center[1] + angle_cos * (radius_outer - 2), center[2] + angle_sin * (radius_outer - 2),
            FX[FxGUID][Fx_P].GrbClr or 0xDBDBDBff, FX[FxGUID][Fx_P].Value_Thick or 2.0)
        local TextW, h = r.ImGui_CalcTextSize(ctx, labeltoShow, nil, nil, true)
        if Disabled == 'Pro C Ratio Disabled' then
            local CompStyle = 'CompStyle##Value'
            if _G[CompStyle] == 'Vocal' then
                r.ImGui_DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_outer, 0x000000aa)
                TxtClr = 0x55555577
            end
        end
        --if string.find(FX_Name, 'Pro%-C 2') then
        --    r.ImGui_DrawList_AddText(draw_list, center[1]-TextW/2+ (offset or 0)   , pos[2] + radius_outer * 2 + item_inner_spacing[2], TxtClr, labeltoShow)
        --end





        local txtX = center[1] - TextW / 2; local txtY = pos[2] + radius_outer * 2 + item_inner_spacing[2]

        ---@param Label string
        ---@param offset number
        ---@param Rect_offset? number
        local function AutoBtn(Label, offset, Rect_offset)
            if labeltoShow == Label then
                MouseX, MouseY = r.ImGui_GetMousePos(ctx)
                r.ImGui_DrawList_AddText(draw_list, center[1] - TextW / 2 + (offset or 0),
                    pos[2] + radius_outer * 2 + item_inner_spacing[2], 0xFFD57144, 'A')

                if MouseX > txtX and MouseX < txtX + TextW and MouseY > txtY - 4 and MouseY < txtY + 10 then
                    r.ImGui_DrawList_AddRectFilled(draw_list, txtX + (Rect_offset or 0), txtY,
                        txtX + TextW + (Rect_offset or 0), txtY + 10, 0x99999955, 3)
                    r.ImGui_DrawList_AddText(draw_list, center[1] - TextW / 2 + (offset or 0),
                        pos[2] + radius_outer * 2 + item_inner_spacing[2], 0xFFD57166, 'A')
                    if IsLBtnClicked and Label == 'Release' then
                        AutoRelease = r.TrackFX_GetParamNormalized(LT_Track, FX_Idx, 7)
                        if AutoRelease == 1 then
                            r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, 7, 0)
                            AutoRelease = 0
                        else
                            r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, 7, 1)
                            AutoRelease = 1
                        end
                    elseif IsLBtnClicked and Label == 'Gain' then
                        AutoGain = r.TrackFX_GetParamNormalized(LT_Track, FX_Idx, 14)
                        if AutoGain == 1 then
                            r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, 14, 0)
                            AutoGain = 0
                        else
                            r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, 14, 1)
                            AutoGain = 1
                        end
                    end
                end

                if Label == 'Release' then
                    if not AutoRelease then AutoRelease = r.TrackFX_GetParamNormalized(LT_Track, FX_Idx, 7) end
                    if AutoRelease == 1 then
                        r.ImGui_DrawList_AddText(draw_list, center[1] - TextW / 2 + (offset or 0),
                            pos[2] + radius_outer * 2 + item_inner_spacing[2], 0xFFD571ff, 'A')
                    end
                end
                if Label == 'Gain' then
                    if not AutoGain then AutoGain = r.TrackFX_GetParamNormalized(LT_Track, FX_Idx, 14) end
                    if AutoGain == 1 then
                        r.ImGui_DrawList_AddText(draw_list, center[1] - TextW / 2 + (offset or 0),
                            pos[2] + radius_outer * 2 + item_inner_spacing[2], 0xFFD571ff, 'A')
                    end
                end
            end
        end

        AutoBtn('Release', -8, 3)
        AutoBtn('Gain', -8)

        if is_active or is_hovered then
            if labeltoShow == 'Release' or labeltoShow == 'Gain' and MouseX > txtX and MouseX < txtX + TextW and MouseY > txtY - 4 and MouseY < txtY + 10 then
            else
                if is_active then
                    r.ImGui_DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_outer,
                        FX[FxGUID][Fx_P].BgClrAct or 0xE4B96B99)
                    r.ImGui_DrawList_AddLine(draw_list, center[1] + angle_cos * radius_inner,
                        center[2] + angle_sin * radius_inner, center[1] + angle_cos * (radius_outer - 2),
                        center[2] + angle_sin * (radius_outer - 2), FP.V_Clr or 0xDBDBDBff, 2.0)
                elseif is_hovered then
                    r.ImGui_DrawList_AddCircle(draw_list, center[1], center[2], radius_outer, 0xE4B96B99)
                    --r.ImGui_DrawList_AddLine(draw_list, center[1] + angle_cos*radius_inner, center[2] + angle_sin*radius_inner, center[1] + angle_cos*(radius_outer-2), center[2] + angle_sin*(radius_outer-2), FP.V_Clr or  0xDBDBDBff, 2.0)
                end
            end
        end
    elseif Style == 'FX Layering' then
        r.ImGui_DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_outer,
            FX[FxGUID][Fx_P].BgClr or r.ImGui_GetColor(ctx, r.ImGui_Col_Button()), 16)
        r.ImGui_DrawList_AddLine(draw_list, center[1] + angle_cos * radius_inner,
            center[2] + angle_sin * radius_inner,
            center[1] + angle_cos * (radius_outer - 2), center[2] + angle_sin * (radius_outer - 2),
            FX[FxGUID][Fx_P].GrbClr or Clr_SldrGrab, 2.0)
        r.ImGui_DrawList_PathArcTo(draw_list, center[1], center[2], radius_outer / 2, ANGLE_MAX - ANGLE_MIN, angle)
        r.ImGui_DrawList_PathStroke(draw_list, 0x99999922, nil, radius_outer * 0.6)
        r.ImGui_DrawList_PathClear(draw_list)

        r.ImGui_DrawList_PathArcTo(draw_list, center[1], center[2], radius_outer / 2, ANGLE_MAX + 1.35,
            ANGLE_MAX + 0.15)
        r.ImGui_DrawList_PathStroke(draw_list, r.ImGui_GetColor(ctx, r.ImGui_Col_FrameBg()), nil, radius_outer)

        r.ImGui_DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_inner,
            r.ImGui_GetColor(ctx,
                is_active and r.ImGui_Col_FrameBgActive() or is_hovered and r.ImGui_Col_FrameBgHovered() or
                r.ImGui_Col_FrameBg()), 16)
    elseif Style == 'Custom Image' then
        local Image = ImgPath or FP.Image
        if Image then
            local w, h = r.ImGui_Image_GetSize(Image)

            if h > w * 5 then -- It's probably a strip knob file
                local scale = 2
                local sz = radius_outer * scale


                uvmin, uvmax = Calc_strip_uv(Image, FP.V or FP.V or r.TrackFX_GetParamNormalized(LT_Track, FX_Idx, P_Num))


                r.ImGui_DrawList_AddImage(WDL, Image, center[1] - sz / 2, center[2] - sz / 2, center[1] + sz / 2,
                    center[2] + sz / 2, 0, uvmin, 1, uvmax, FP.BgClr or 0xffffffff)
            else
                local scale = 2
                local sz = radius_outer * scale
                ImageAngle(ctx, Image, 4 + FP.V * 4.5, sz, sz, center[1] - sz / 2, center[2] - sz / 2)
            end
        end
    elseif Style == 'Invisible' then
    else -- for all generic FXs
        r.ImGui_DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_outer,
            FX[FxGUID][Fx_P].BgClr or r.ImGui_GetColor(ctx, r.ImGui_Col_Button()))
        r.ImGui_DrawList_AddLine(draw_list, center[1] + angle_cos * radius_inner,
            center[2] + angle_sin * radius_inner,
            center[1] + angle_cos * (radius_outer - 2), center[2] + angle_sin * (radius_outer - 2),
            FX[FxGUID][Fx_P].GrbClr or Clr_SldrGrab, FX[FxGUID][Fx_P].Value_Thick or 2)
        r.ImGui_DrawList_PathArcTo(draw_list, center[1], center[2], radius_outer / 2, ANGLE_MIN, angle)
        r.ImGui_DrawList_PathStroke(draw_list, 0x99999922, nil, radius_outer * 0.6)
        r.ImGui_DrawList_PathClear(draw_list)
        r.ImGui_DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_inner,
            r.ImGui_GetColor(ctx,
                is_active and r.ImGui_Col_FrameBgActive() or is_hovered and r.ImGui_Col_FrameBgHovered() or
                r.ImGui_Col_FrameBg()))
    end





    if FX[FxGUID].Morph_Value_Edit or Mods == Alt + Ctrl and FX[FxGUID].MorphA and FX[FxGUID].MorphB then
        r.ImGui_EndDisabled(ctx)

        if FX[FxGUID].MorphA[P_Num] and FX[FxGUID].MorphB[P_Num] then
            r.ImGui_SetCursorScreenPos(ctx, pos[1], pos[2])
            local sizeX, sizeY = r.ImGui_GetItemRectSize(ctx)
            r.ImGui_InvisibleButton(ctx, label, sizeX, sizeY)



            --local A = SetMinMax(PosL+ sizeX*FX[FxGUID].MorphA[P_Num],PosL, PosR)
            --local B = SetMinMax(PosL+ sizeX*FX[FxGUID].MorphB[P_Num],PosL,PosR)
            local A = ANGLE_MIN + (ANGLE_MAX - ANGLE_MIN) * FX[FxGUID].MorphA[P_Num]
            local B = ANGLE_MIN + (ANGLE_MAX - ANGLE_MIN) * FX[FxGUID].MorphB[P_Num]

            local ClrA, ClrB = DefClr_A_Hvr, DefClr_B_Hvr
            local MsX, MsY = r.ImGui_GetMousePos(ctx)

            if FX[FxGUID].MorphA[P_Num] ~= FX[FxGUID].MorphB[P_Num] then
                --r.ImGui_DrawList_PathArcTo( draw_list,  center[1] , center[2],(radius_inner+ radius_outer)/2, A , B)
                FX[FxGUID].Angle1 = angle
                FX[FxGUID].Angle2 = angle + (ANGLE_MAX - ANGLE_MIN) * 0.5
                local angle_cos, angle_sin = math.cos(A), math.sin(A)
                r.ImGui_DrawList_AddLine(draw_list, center[1], center[2], center[1] + angle_cos * (radius_outer - 2),
                    center[2] + angle_sin * (radius_outer - 2), ClrA, 2.0)
                local angle_cos, angle_sin = math.cos(B), math.sin(B)
                r.ImGui_DrawList_AddLine(draw_list, center[1], center[2], center[1] + angle_cos * (radius_outer - 2),
                    center[2] + angle_sin * (radius_outer - 2), ClrB, 2.0)


                r.ImGui_DrawList_PathStroke(draw_list, ClrA, nil, radius_outer * 0.2)
                r.ImGui_DrawList_PathClear(draw_list)
                --r.ImGui_DrawList_AddRectFilledMultiColor(WDL,A,PosT,B,PosB,ClrA, ClrB, ClrB,ClrA)
            end

            local txtClr = r.ImGui_GetStyleColor(ctx, r.ImGui_Col_Text())

            if r.ImGui_IsItemClicked(ctx) or r.ImGui_IsItemClicked(ctx, 1) then
                if IsLBtnClicked or IsRBtnClicked then
                    FP.TweakingAB_Val = P_Num
                    retval, Orig_Baseline = r.TrackFX_GetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".mod.baseline") 
                end
                if not FP.TweakingAB_Val then
                    local offsetA, offsetB
                    --if A<B+5 and A>B-14 then offsetA=-10      offsetB = 10 end
                    --r.ImGui_DrawList_AddTextEx(WDL,Font_Andale_Mono_20_B, 16, A, PosT+(offsetA or 0), txtClr,'A')
                    --r.ImGui_DrawList_AddTextEx(WDL,Font_Andale_Mono_20_B, 16, B, PosT+(offsetB or 0), txtClr, 'B')
                end
            end

            if FP.TweakingAB_Val == P_Num and not MorphingMenuOpen then
                local X_A, X_B
                local offsetA, offsetB
                if IsLBtnHeld then
                    local drag = FX[FxGUID].MorphA[P_Num] + select(2, r.ImGui_GetMouseDelta(ctx)) * -0.01
                    FX[FxGUID].MorphA[P_Num] = SetMinMax(drag, 0, 1)
                    if FX[FxGUID].Morph_ID then -- if Morph Sldr is linked to a CC
                        local A = (MsY - BtnT) / sizeY
                        local Scale = FX[FxGUID].MorphB[P_Num] - A
                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.active", 1)   -- 1 active, 0 inactive
                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.scale", Scale)   -- Scale
                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.effect", -100) -- -100 enables midi_msg*
                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.param", -1)   -- -1 not parameter link
                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_bus", 15) -- 0 based, 15 = Bus 16
                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_chan", 16) -- 0 based, 0 = Omni
                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_msg", 160)   -- 160 is Aftertouch
                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_msg2", FX[FxGUID].Morph_ID) -- CC value
                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".mod.baseline", A) -- Baseline
                    end
                elseif IsRBtnHeld then
                    local drag = FX[FxGUID].MorphB[P_Num] + select(2, r.ImGui_GetMouseDelta(ctx, 1)) * -0.01
                    FX[FxGUID].MorphB[P_Num] = SetMinMax(drag, 0, 1)
                    if FX[FxGUID].Morph_ID then -- if Morph Sldr is linked to a CC
                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.active", 1)   -- 1 active, 0 inactive
                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.scale", FX[FxGUID].MorphB[P_Num] - FX[FxGUID].MorphA[P_Num])   -- Scale
                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.effect", -100) -- -100 enables midi_msg*
                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.param", -1)   -- -1 not parameter link
                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_bus", 15) -- 0 based, 15 = Bus 16
                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_chan", 16) -- 0 based, 0 = Omni
                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_msg", 160)   -- 160 is Aftertouch
                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_msg2", FX[FxGUID].Morph_ID) -- CC value
                        r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".mod.baseline", Orig_Baseline) -- Baseline
                    end
                end
                if IsLBtnHeld then
                    X_A = MsX
                    Y_A = MsY - 15
                    offsetA = -10
                    if MsX < B + 5 and MsX > B - 14 then offsetB = 10 end
                elseif IsRBtnHeld then
                    X_B = MsX
                    offsetB = -10
                    if MsX < A + 5 and MsX > A - 14 then offsetA = 10 end
                end

                r.ImGui_DrawList_AddTextEx(WDL, Font_Andale_Mono_20_B, 16, A, BtnT + (offsetA or 0), txtClr, 'A')
                r.ImGui_DrawList_AddTextEx(WDL, Font_Andale_Mono_20_B, 16, B, BtnT + (offsetB or 0), txtClr, 'B')
                if LBtnRel or RBtnRel then
                    StoreAllPrmVal('A', 'Dont')
                    StoreAllPrmVal('B', 'Dont')
                    FP.TweakingAB_Val = nil
                end
            end
        end
        r.ImGui_BeginDisabled(ctx)
    end


    if Lbl_Pos == 'Bottom' then --Write Bottom Label
        local T = pos[2] + radius_outer * 2 + item_inner_spacing[2]; local R = pos[1] + radius_outer * 2; local L =
            pos
            [1]
        local X, Y = CenteredLblPos or pos[1], pos[2] + radius_outer * 2 + item_inner_spacing[2]
        local Clr = FX[FxGUID][Fx_P].Lbl_Clr or 0xffffffff
        local FontSize = FX[FxGUID][Fx_P].FontSize or Knob_DefaultFontSize

        r.ImGui_DrawList_AddTextEx(draw_list, _G[Font], FX[FxGUID][Fx_P].FontSize or Knob_DefaultFontSize, X, Y, Clr,
            labeltoShow or FX[FxGUID][Fx_P].Name, (Radius or 20) * 2, X, Y, X + (Radius or 20) * 2, Y + FontSize * 2)
    end
    RemoveModulationIfDoubleRClick(FxGUID, Fx_P, P_Num, FX_Idx)

    if V_Pos ~= 'None' and V_Pos then
        r.ImGui_PushFont(ctx, _G[V_Font])
        _, FormatPV = r.TrackFX_GetFormattedParamValue(LT_Track, FX_Idx, P_Num)
        if FX[FxGUID][Fx_P].ValToNoteL then
            FormatPV = StrToNum(FormatPV)
            tempo = r.Master_GetTempo()
            local num = FormatPV:gsub('[^%p%d]', '')
            noteL = num * tempo / 60000


            if noteL > 0.99 and noteL < 1.99 then
                FormatPV = roundUp(noteL, 1) .. '/4'
            elseif noteL > 1.99 then
                FormatPV = roundUp(noteL, 2) .. '/4'
            elseif noteL > 0.49 and noteL < 0.99 then
                FormatPV = '1/8'
            elseif noteL > 0.24 and noteL < 0.49 then
                FormatPV = '1/16'
            elseif noteL > 0.124 and noteL < 0.24 then
                FormatPV = '1/32'
            elseif noteL < 0.124 then
                FormatPV = '1/64'
            end
        end

        if FX[FxGUID][Fx_P].V_Round then FormatPV = RoundPrmV(FormatPV, FX[FxGUID][Fx_P].V_Round) end


        local ValueTxtW = r.ImGui_CalcTextSize(ctx, FormatPV, nil, nil, true)
        if ValueTxtW < Radius * 2 then
            CenteredVPos = pos[1] + Radius - ValueTxtW / 2
        else
            CenteredVPos = pos[1]
        end
        local Y_Offset, drawlist

        if V_Pos == 'Within' then Y_Offset = radius_outer * 1.2 end
        if is_active or is_hovered then drawlist = Glob.FDL else drawlist = draw_list end
        if V_Pos ~= 'Free' then
            r.ImGui_DrawList_AddTextEx(draw_list, _G[V_Font], FX[FxGUID][Fx_P].V_FontSize or Knob_DefaultFontSize,
                CenteredVPos, pos[2] + radius_outer * 2 + item_inner_spacing[2] - (Y_Offset or 0),
                FX[FxGUID][Fx_P].V_Clr or 0xffffffff, FormatPV, (Radius or 20) * 2)
        end
        r.ImGui_PopFont(ctx)
    end

    if Lbl_Pos == 'Within' and Style == 'FX Layering' then
        local ValueTxtW = r.ImGui_CalcTextSize(ctx, labeltoShow, nil, nil, true)
        CenteredVPos = pos[1] + Radius - ValueTxtW / 2 + 0.5
        Y_Offset = radius_outer * 1.3 - 1

        r.ImGui_DrawList_AddTextEx(draw_list, _G[V_Font], 10, CenteredVPos,
            pos[2] + radius_outer * 2 + item_inner_spacing[2] - (Y_Offset or 0), FX[FxGUID][Fx_P].V_Clr or 0xffffff88,
            labeltoShow, (Radius or 20) * 2)
    end




    --if user turn knob on ImGui
    if Tweaking == P_Num .. FxGUID then
        FX[FxGUID][Fx_P].V = p_value
        if not FP.WhichCC then
            r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, P_Num, p_value)
        else
            local unsetcc = r.TrackFX_SetNamedConfigParm(LT_Track, LT_FXNum, "param."..P_Num..".plink.active", 0)   -- 1 active, 0 inactive
            r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, P_Num, FX[FxGUID][Fx_P].V)
        end
    end




    if AssigningMacro ~= nil then
        r.ImGui_DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_outer,
            EightColors.bgWhenAsgnMod[AssigningMacro], 16)
    end


    local AlreadyAddPrm = false

    if LT_ParamNum == P_Num and focusedFXState == 1 and LT_FXGUID == FxGUID and not FP.WhichCC then
        local LT_ParamValue = r.TrackFX_GetParamNormalized(LT_Track, LT_FX_Number, LT_ParamNum)

        p_value = LT_ParamValue
        FX[FxGUID][Fx_P].V = p_value

        local L, T = r.ImGui_GetItemRectMin(ctx);

        r.ImGui_DrawList_AddCircle(draw_list, center[1], center[2], radius_outer, 0xffffffff, 16)
        for m = 1, 8, 1 do
            if AssigningMacro == m then
                r.ImGui_PopStyleColor(ctx, 2)
            end
        end
    end


    if PM.TimeNow ~= nil then
        if r.time_precise() > PM.TimeNow + 1 then
            r.gmem_write(7, 0) --tells jsfx to stop retrieving P value
            r.gmem_write(8, 0)
            PM.TimeNow = nil
        end
    end

    IfTryingToAddExistingPrm(Fx_P, FxGUID, 'Circle', center[1], center[2], nil, nil, radius_outer)



    MakeModulationPossible(FxGUID, Fx_P, FX_Idx, P_Num, p_value, Sldr_Width, 'knob')



    if FP.ModAMT then -- Draw modlines  circular
        local offset = 0
        local BipOfs = 0
        FP.ModBipolar= FP.ModBipolar or {}

        
        for Macro, v in ipairs(MacroNums) do
            
            if FP.ModAMT[Macro] then
                --if Modulation has been assigned to params
                local P_V_Norm = r.TrackFX_GetParamNormalized(LT_Track, FX_Idx, P_Num)

                --- indicator of where the param is currently
                local PosAftrMod = ANGLE_MIN + (ANGLE_MAX - ANGLE_MIN) * (P_V_Norm)

                    if FP.ModBipolar[Macro] then 
                        BipOfs =  - FP.ModAMT[Macro]
                    end

                r.ImGui_DrawList_PathArcTo(draw_list, center[1], center[2], radius_outer * 0.75, angle, PosAftrMod )

                r.ImGui_DrawList_PathStroke(draw_list, EightColors.Bright[Macro], nil, radius_outer / 2)
                r.ImGui_DrawList_PathClear(draw_list)

                --- shows modulation range
                local Range = SetMinMax(angle + (ANGLE_MAX - ANGLE_MIN) * FP.ModAMT[Macro],ANGLE_MIN, ANGLE_MAX)
                local angle = angle 
                if BipOfs ~=0 then 

                    local Range = SetMinMax(angle + (ANGLE_MAX - ANGLE_MIN) * -(  FP.ModAMT[Macro]   ) ,ANGLE_MIN, ANGLE_MAX) 
                    r.ImGui_DrawList_PathArcTo(draw_list, center[1], center[2], radius_outer - 1 + offset, angle,Range )
                    r.ImGui_DrawList_PathStroke(draw_list, EightColors.HighSat_MidBright[Macro], nil,
                    radius_outer * 0.1)
                    r.ImGui_DrawList_PathClear(draw_list)
                end 
                r.ImGui_DrawList_PathArcTo(draw_list, center[1], center[2], radius_outer - 1 + offset, angle, Range )
           
                r.ImGui_DrawList_PathStroke(draw_list, EightColors.HighSat_MidBright[Macro], nil,
                    radius_outer * 0.1)
                r.ImGui_DrawList_PathClear(draw_list)

                ParamHasMod_Any = true

                offset = offset + OffsetForMultipleMOD
            end
        end
    end -- of reapeat for every macro

    if Trk.Prm.Assign and F_Tp == Trk.Prm.Assign and AssigningMacro then
        local M = AssigningMacro

        RightBtnDragX, RightBtnDragY = r.ImGui_GetMouseDragDelta(ctx, x, y, 1)

        FP.ModAMT[M] = ((-RightBtnDragY / 100) or 0) + (FP.ModAMT[M] or 0)

        if FP.ModAMT[M] + p_value > 1 then FP.ModAMT[M] = 1 - p_value end
        if FP.ModAMT[M] + p_value < 0 then FP.ModAMT[M] = -p_value end

        local BipolarOut 
        if Mods == Alt then 
            FP.ModAMT[M] = math.abs( FP.ModAMT[M])
            BipolarOut = FP.ModAMT[M]  + 100

            FP.ModBipolar[M] = true 
            r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: FX' .. FxGUID .. 'Prm' .. Fx_P .. 'Macro' .. M .. 'Mod Bipolar','True', true)
        else 
            FP.ModBipolar[M] = nil
            r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: FX' .. FxGUID .. 'Prm' .. Fx_P .. 'Macro' .. M .. 'Mod Bipolar','', true)
        end

       
        r.gmem_write(4, 1) --tells jsfx that user is changing Mod Amount
        r.gmem_write(1000 * AssigningMacro + Trk.Prm.Assign, BipolarOut or FP.ModAMT[M])
        r.ImGui_ResetMouseDragDelta(ctx, 1)

        r.SetProjExtState(0, 'FX Devices', 'Param -' .. Trk.Prm.Assign .. 'Macro - ' .. AssigningMacro .. FxGUID,
            FP.ModAMT[M])
    end

    --repeat for every param stored on track...


    if FX[FxGUID].Morph_Value_Edit or Mods == Alt + Ctrl then r.ImGui_EndDisabled(ctx) end


    if LblTextSize ~= 'No Font' then r.ImGui_PopFont(ctx) end
    r.ImGui_DrawListSplitter_Merge(SPLITTER)

    return value_changed, p_value
end

---@param ctx ImGui_Context
---@param label string
---@param labeltoShow string
---@param p_value number
---@param v_min number
---@param v_max number
---@param Fx_P integer
---@param FX_Idx integer
---@param P_Num number
---@param SliderStyle string
---@param Sldr_Width number
---@param item_inner_spacing number
---@param Disable string | nil
---@param Vertical string
---@param GrabSize number
---@param BtmLbl string
---@param SpacingBelow number
---@param Height? number
---@return boolean value_changed
---@return number p_value
function AddSlider(ctx, label, labeltoShow, p_value, v_min, v_max, Fx_P, FX_Idx, P_Num, SliderStyle, Sldr_Width,
                   item_inner_spacing, Disable, Vertical, GrabSize, BtmLbl, SpacingBelow, Height)
    local PosL, PosR, PosT, PosB
    local ClrPop = 0
    local pos = { r.ImGui_GetCursorScreenPos(ctx) }


    local line_height = r.ImGui_GetTextLineHeight(ctx)
    local draw_list = r.ImGui_GetWindowDrawList(ctx)
    local f_draw_list = r.ImGui_GetForegroundDrawList(ctx)
    local SPLITTER = r.ImGui_CreateDrawListSplitter(draw_list)
    r.ImGui_DrawListSplitter_Split(SPLITTER, 2)

    local mouse_delta = { r.ImGui_GetMouseDelta(ctx) }
    local FxGUID = r.TrackFX_GetFXGUID(LT_Track, FX_Idx)
    if not FxGUID then return end

    local F_Tp = FX.Prm.ToTrkPrm[FxGUID .. Fx_P] or 0

    FX[FxGUID][Fx_P] = FX[FxGUID][Fx_P] or {}
    local FP = FX[FxGUID][Fx_P]
    local Font = 'Font_Andale_Mono_' .. roundUp(FP.FontSize or LblTextSize or Knob_DefaultFontSize, 1)

    local V_Font = 'Arial_' .. roundUp(FP.V_FontSize or LblTextSize or Knob_DefaultFontSize, 1)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FramePadding(), 0, FP.Height or 3 )

    


    if FP.Lbl_Pos == 'Left' then
        r.ImGui_PushFont(ctx, _G[Font])
        r.ImGui_AlignTextToFramePadding(ctx)
        r.ImGui_TextColored(ctx, FP.Lbl_Clr or r.ImGui_GetColor(ctx, r.ImGui_Col_Text()), labeltoShow or FP.Name)
        SL()
        r.ImGui_PopFont(ctx)
    end

    if LBtnDC then r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_DisabledAlpha(), 1) end
    if FX[FxGUID][Fx_P].Name then
        local CC = FP.WhichCC or -1


        if FX[FxGUID].Morph_Value_Edit or Mods == Alt + Ctrl or LBtnDC then r.ImGui_BeginDisabled(ctx) end

        if item_inner_spacing then
            r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing(), item_inner_spacing, item_inner_spacing)
        end

        if not Sldr_Width or Sldr_Width == '' then Sldr_Width = FX.Def_Sldr_W[FxGUID] or Def_Sldr_W or 160 end
        r.ImGui_SetNextItemWidth(ctx, Sldr_Width)
        r.ImGui_BeginGroup(ctx)

        if SliderStyle == 'Pro C Thresh' then
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBg(), 0x99999900); r.ImGui_PushStyleColor(ctx,
                r.ImGui_Col_FrameBgActive(), 0x99999922)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBgHovered(), 0x99999922)
            ClrPop = 3;
        elseif FX[FxGUID][Fx_P].BgClr and SliderStyle == nil then
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBg(), FX[FxGUID][Fx_P].BgClr)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBgHovered(), FX[FxGUID][Fx_P].BgClrHvr)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBgActive(), FX[FxGUID][Fx_P].BgClrAct)
            ClrPop = 3
        else
            ClrPop = 0 --r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBg(), 0x474747ff) ClrPop =1
        end
        if GrabSize then r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_GrabMinSize(), GrabSize) end

        if FP.GrbClr then
            local ActV
            local R, G, B, A = r.ImGui_ColorConvertU32ToDouble4(FP.GrbClr)
            local H, S, V = r.ImGui_ColorConvertRGBtoHSV(R, G, B)
            if V > 0.9 then ActV = V - 0.2 end
            local R, G, B = r.ImGui_ColorConvertHSVtoRGB(H, S, ActV or V + 0.2)
            local ActClr = r.ImGui_ColorConvertDouble4ToU32(R, G, B, A)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_SliderGrab(), FP.GrbClr)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_SliderGrabActive(), ActClr)
            ClrPop = ClrPop + 2
        end


        if Vertical == 'Vert' then
            if FP.Lbl_Pos == 'Top' then
                local CurX = r.ImGui_GetCursorPosX(ctx)
                local w = r.ImGui_CalcTextSize(ctx, labeltoShow or FP.Name)
                r.ImGui_SetCursorPosX(ctx, CurX - w / 2 + Sldr_Width / 2)
                --r.ImGui_TextColored(ctx, FP.Lbl_Clr or r.ImGui_GetColor(ctx, r.ImGui_Col_Text())  ,labeltoShow or FP.Name )
                MyText(labeltoShow or FP.Name, _G[Font], FP.Lbl_Clr or r.ImGui_GetColor(ctx, r.ImGui_Col_Text()))
            end
            if FP.V_Pos == 'Top' then
                local CurX             = r.ImGui_GetCursorPosX(ctx)
                local Get, Param_Value = r.TrackFX_GetFormattedParamValue(LT_Track, FX_Idx, P_Num)
                local w                = r.ImGui_CalcTextSize(ctx, Param_Value)
                r.ImGui_SetCursorPosX(ctx, CurX - w / 2 + Sldr_Width / 2)
                if Get then MyText(Param_Value, _G[V_Font], FP.V_Clr or r.ImGui_GetColor(ctx, r.ImGui_Col_Text())) end
            end
        end
        

        FP.V = FP.V or r.TrackFX_GetParamNormalized(LT_Track,FX_Idx,P_Num)
        if DraggingMorph == FxGUID then p_value = r.TrackFX_GetParamNormalized(LT_Track, FX_Idx, P_Num) end


        if Vertical == 'Vert' then
            _, p_value = r.ImGui_VSliderDouble(ctx, label, Sldr_Width, FP.Height or Height, p_value, v_min, v_max, ' ')
        else
            _, p_value = r.ImGui_SliderDouble(ctx, label, p_value, v_min, v_max, ' ', r.ImGui_SliderFlags_NoInput())
        end
        r.ImGui_SetItemAllowOverlap(ctx)
        KNOB = false
        DnD_PLink_TARGET(FxGUID, Fx_P, FX_Idx, P_Num)
        ButtonDraw(SPLITTER, FX[FxGUID].BgClr or CustomColorsDefault.FX_Devices_Bg, nil, nil)
        if GrabSize then r.ImGui_PopStyleVar(ctx) end
        r.ImGui_PopStyleColor(ctx, ClrPop)

        RemoveModulationIfDoubleRClick(FxGUID, Fx_P, P_Num, FX_Idx)
        
        local SldrR, SldrB = r.ImGui_GetItemRectMax(ctx)
        local SldrL, SldrT = r.ImGui_GetItemRectMin(ctx)

        PosL, PosT = r.ImGui_GetItemRectMin(ctx)
        PosR, PosB = r.ImGui_GetItemRectMax(ctx)
        local is_active = r.ImGui_IsItemActive(ctx)
        local is_hovered = r.ImGui_IsItemHovered(ctx)

        
        local button_x, button_y = r.ImGui_GetCursorPos(ctx)
        r.ImGui_SetCursorPosY(ctx, button_y - (PosB - PosT))
        WhichClick()
        r.ImGui_InvisibleButton(ctx, '##plink' .. P_Num, PosR - PosL, PosB - PosT, ClickButton) -- for parameter link
        if ClickButton ==  r.ImGui_ButtonFlags_MouseButtonRight() and not AssigningMacro then -- right drag to link parameters
            DnD_PLink_SOURCE(FX_Idx, P_Num)
        end

        local value_changed = false

        if is_active == true then Knob_Active = true end
        if Knob_Active == true then
            if IsLBtnHeld == false then Knob_Active = false end
        end

        if SliderStyle == 'Pro C' then
            SldrLength = PosR - PosL
            SldrGrbPos = SldrLength * p_value
            if is_active then
                r.ImGui_DrawList_AddRectFilled(draw_list, PosL, PosT, PosL + SldrGrbPos, PosB, 0xFFD571bb, Rounding)
            elseif is_hovered then
                r.ImGui_DrawList_AddRectFilled(draw_list, PosL, PosT, PosL + SldrGrbPos, PosB, 0xDFB973bb, Rounding)
            else
                r.ImGui_DrawList_AddRectFilled(draw_list, PosL, PosT, PosL + SldrGrbPos, PosB, 0x888888bb, Rounding)
            end
        end

        if Disable == 'Disabled' then
            r.ImGui_DrawList_AddRectFilled(draw_list, PosL, PosT, PosL + SldrGrbPos, PosB, 0x000000cc, Rounding)
        end
        
        if is_active then
            p_value = SetMinMax(p_value, v_min, v_max)
            value_changed = true
            r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, P_Num, p_value)
            MvingP_Idx = CC

            Tweaking = P_Num .. FxGUID
        end
        if is_active or is_hovered then
            if FP.V_Pos == 'None' then
                local SzX, SzY = r.ImGui_GetItemRectSize(ctx)
                local MsX, MsY = r.ImGui_GetMousePos(ctx)

                r.ImGui_SetNextWindowPos(ctx, SetMinMax(MsX, pos[1], pos[1] + SzX), pos[2] - SzY - line_height + button_y)
                r.ImGui_BeginTooltip(ctx)
                local Get, Pv = r.TrackFX_GetFormattedParamValue(LT_Track, FX_Idx, P_Num)

                r.ImGui_Text(ctx, Pv)
                r.ImGui_EndTooltip(ctx)
            end
        end
        local t            = (p_value - v_min) / (v_max - v_min)

        local Clr_SldrGrab = r.ImGui_GetColor(ctx, r.ImGui_Col_SliderGrabActive())
        local ClrBg        = r.ImGui_GetColor(ctx, r.ImGui_Col_FrameBg())




        --[[ if is_active or is_hovered then
        local window_padding = {r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding())}
        r.ImGui_SetNextWindowPos(ctx, pos[1] - window_padding[1], pos[2] - line_height - item_inner_spacing[2] - window_padding[2])
        r.ImGui_BeginTooltip(ctx)
        r.ImGui_Text(ctx, ('%.3f'):format(p_value))
        r.ImGui_EndTooltip(ctx)
        end ]]


        --if user turn knob on ImGui
        if not P_Num then P_Num = 0 end
        if Tweaking == P_Num .. FxGUID then
            FX[FxGUID][Fx_P].V       = p_value
            local getSlider, P_Value = r.TrackFX_GetFormattedParamValue(LT_Track, FX_Idx, P_Num)
            ---!!! ONLY ACTIVATE TOOLTIP IF VALUE IS HIDDEN
            --[[ if getSlider  then
                local window_padding = {r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding())}
                r.ImGui_SetNextWindowPos(ctx, pos[1] - window_padding[1], pos[2] - line_height - window_padding[2] -8)
                r.ImGui_BeginTooltip(ctx)
                r.ImGui_Text(ctx, P_Value)
                r.ImGui_EndTooltip(ctx)
            end  ]]
            if Trk.Prm.WhichMcros[CC .. TrkID] == nil then
                r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, P_Num, p_value)
            elseif Trk.Prm.WhichMcros[CC .. TrkID] ~= nil then
                local unsetcc = r.TrackFX_SetNamedConfigParm(LT_Track, LT_FXNum, "param."..P_Num..".plink.active", 0)   -- 1 active, 0 inactive
                r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, P_Num, FX[FxGUID][Fx_P].V)
            end
        end


        if AssigningMacro ~= nil then
            r.ImGui_DrawList_AddRectFilled(draw_list, PosL, PosT, PosR, PosB,
                EightColors.bgWhenAsgnMod[AssigningMacro])
        end

        local AlreadyAddPrm = false

        if LT_ParamNum == P_Num and focusedFXState == 1 and LT_FXGUID == FxGUID and not FP.WhichCC then
            local LT_ParamValue = r.TrackFX_GetParamNormalized(LT_Track, LT_FX_Number, LT_ParamNum)

            FX[FxGUID][Fx_P].V = LT_ParamValue

            r.ImGui_DrawList_AddRectFilled(draw_list, PosL, PosT, PosR, PosB, 0x99999922, Rounding)
            r.ImGui_DrawList_AddRect(draw_list, PosL, PosT, PosR, PosB, 0x99999966, Rounding)

            for m = 1, 8, 1 do
                if AssigningMacro == m then
                    r.ImGui_PopStyleColor(ctx, 2)
                end
            end
        end



        -- if IsLBtnHeld ==false then Tweaking= nil end

        if PM.TimeNow ~= nil then
            if r.time_precise() > PM.TimeNow + 1 then
                r.gmem_write(7, 0) --tells jsfx to stop retrieving P value
                r.gmem_write(8, 0)
                PM.TimeNow = nil
            end
        end

        if FX[FxGUID].Morph_Value_Edit or Mods == Alt + Ctrl and FX[FxGUID].MorphA and FX[FxGUID].MorphB then
            --r.ImGui_EndDisabled(ctx)
            if FX[FxGUID].MorphA[P_Num] and FX[FxGUID].MorphB[P_Num] then
                HintMessage = 'LMB : adjust A   RMB : adjust B    Alt + Ctrl : Quick Access to morph value edit mode'
                local sizeX, sizeY = r.ImGui_GetItemRectSize(ctx)
                local A = SetMinMax(PosL + sizeX * FX[FxGUID].MorphA[P_Num], PosL, PosR)
                local B = SetMinMax(PosL + sizeX * FX[FxGUID].MorphB[P_Num], PosL, PosR)
                local ClrA, ClrB = DefClr_A_Hvr, DefClr_B_Hvr
                local MsX, MsY = r.ImGui_GetMousePos(ctx)


                if FX[FxGUID].MorphA[P_Num] ~= FX[FxGUID].MorphB[P_Num] then
                    r.ImGui_DrawList_AddRectFilledMultiColor(WDL, A, PosT, B, PosB, ClrA, ClrB, ClrB, ClrA)
                end

                local txtClr = r.ImGui_GetStyleColor(ctx, r.ImGui_Col_Text())

                if r.ImGui_IsMouseHoveringRect(ctx, PosL, PosT, PosR, PosB) and not MorphingMenuOpen then
                    if IsLBtnClicked or IsRBtnClicked then
                        FP.TweakingAB_Val = P_Num
                        retval, Orig_Baseline = r.TrackFX_GetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".mod.baseline") 
                    end
                    if not FP.TweakingAB_Val then
                        local offsetA, offsetB
                        if A < B + 5 and A > B - 14 then
                            offsetA = -10
                            offsetB = 10
                        end
                        r.ImGui_DrawList_AddTextEx(WDL, Font_Andale_Mono_20_B, 16, A, PosT + (offsetA or 0), txtClr,
                            'A')
                        r.ImGui_DrawList_AddTextEx(WDL, Font_Andale_Mono_20_B, 16, B, PosT + (offsetB or 0), txtClr,
                            'B')
                    end
                end

                if FP.TweakingAB_Val == P_Num and not MorphingMenuOpen then
                    local X_A, X_B
                    local offsetA, offsetB
                    if IsLBtnHeld then
                        FX[FxGUID].MorphA[P_Num] = SetMinMax((MsX - PosL) / sizeX, 0, 1)
                        if FX[FxGUID].Morph_ID then -- if Morph Sldr is linked to a CC
                            local A = (MsX - PosL) / sizeX
                            local Scale = FX[FxGUID].MorphB[P_Num] - A
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.active", 1)   -- 1 active, 0 inactive
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.scale", Scale)   -- Scale
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.effect", -100) -- -100 enables midi_msg*
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.param", -1)   -- -1 not parameter link
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_bus", 15) -- 0 based, 15 = Bus 16
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_chan", 16) -- 0 based, 0 = Omni
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_msg", 160)   -- 160 is Aftertouch
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_msg2", FX[FxGUID].Morph_ID) -- CC value
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".mod.baseline", A) -- Baseline  
                        end
                    elseif IsRBtnHeld then
                        FX[FxGUID].MorphB[P_Num] = SetMinMax((MsX - PosL) / sizeX, 0, 1)
                        if FX[FxGUID].Morph_ID then -- if Morph Sldr is linked to a CC
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.active", 1)   -- 1 active, 0 inactive
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.scale", FX[FxGUID].MorphB[P_Num] - FX[FxGUID].MorphA[P_Num])   -- Scale
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.effect", -100) -- -100 enables midi_msg*
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.param", -1)   -- -1 not parameter link
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_bus", 15) -- 0 based, 15 = Bus 16
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_chan", 16) -- 0 based, 0 = Omni
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_msg", 160)   -- 160 is Aftertouch
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_msg2", FX[FxGUID].Morph_ID) -- CC value
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".mod.baseline", Orig_Baseline) -- Baseline 
                        end
                    end
                    if IsLBtnHeld then
                        X_A = MsX
                        Y_A = MsY - 15
                        offsetA = -10
                        if MsX < B + 5 and MsX > B - 14 then offsetB = 10 end
                    elseif IsRBtnHeld then
                        X_B = MsX
                        offsetB = -10
                        if MsX < A + 5 and MsX > A - 14 then offsetA = 10 end
                    end

                    r.ImGui_DrawList_AddTextEx(WDL, Font_Andale_Mono_20_B, 16, A, PosT + (offsetA or 0), txtClr, 'A')
                    r.ImGui_DrawList_AddTextEx(WDL, Font_Andale_Mono_20_B, 16, B, PosT + (offsetB or 0), txtClr, 'B')
                end
            end
            if LBtnRel or RBtnRel then
                StoreAllPrmVal('A', 'Dont')
                StoreAllPrmVal('B', 'Dont')
                FP.TweakingAB_Val = nil
            end
            --r.ImGui_BeginDisabled(ctx)
        end

        IfTryingToAddExistingPrm(Fx_P, FxGUID, 'Rect', PosL, PosT, PosR, PosB)

        if Vertical == 'Vert' then ModLineDir = Height else ModLineDir = Sldr_Width end

        Tweaking = MakeModulationPossible(FxGUID, Fx_P, FX_Idx, P_Num, p_value, Sldr_Width, Vertical)





        local TextW, h = r.ImGui_CalcTextSize(ctx, labeltoShow, nil, nil, true)
        local V_Clr, LblClr
        if Disable == 'Disabled' then
            LblClr = 0x111111ff; V_Clr = 0x111111ff
        else
            LblClr = FP.Lbl_Clr or 0xD6D6D6ff; V_Clr = FP.V_Clr or 0xD6D6D6ff
        end

        local _, Format_P_V = r.TrackFX_GetFormattedParamValue(LT_Track, FX_Idx, P_Num)
        r.ImGui_PushFont(ctx, Arial_11)
        TextW, Texth = r.ImGui_CalcTextSize(ctx, Format_P_V, nil, nil, true, -100)

        r.ImGui_PopFont(ctx)

        if FX[FxGUID][Fx_P].V_Round then Format_P_V = RoundPrmV(StrToNum(Format_P_V), FX[FxGUID][Fx_P].V_Round) end


        if BtmLbl ~= 'No BtmLbl' then
            local Cx, Cy = r.ImGui_GetCursorScreenPos(ctx)
            if Vertical ~= 'Vert' then
                if not FP.Lbl_Pos or FP.Lbl_Pos == 'Bottom' then
                    r.ImGui_DrawList_AddTextEx(draw_list, _G[Font],
                        FP.FontSize or LblTextSize or Knob_DefaultFontSize,
                        Cx, Cy, LblClr, labeltoShow or FX[FxGUID][Fx_P].Name, nil, PosL, PosT, SldrR - TextW - 3,
                        PosB + 20)
                end
            else -- if vertical
                if FP.Lbl_Pos == 'Bottom' or not FP.Lbl_Pos then
                    local CurX = r.ImGui_GetCursorPosX(ctx)
                    local w = r.ImGui_CalcTextSize(ctx, labeltoShow or FP.Name)
                    r.ImGui_SetCursorPosX(ctx, CurX - w / 2 + Sldr_Width / 2)
                    MyText(labeltoShow or FP.Name, _G[Font], LblClr)
                end
                if FP.V_Pos == 'Bottom' then
                    local Cx = r.ImGui_GetCursorPosX(ctx)
                    local txtW = r.ImGui_CalcTextSize(ctx, Format_P_V, nil, nil, true)
                    r.ImGui_SetCursorPosX(ctx, Cx + Sldr_Width / 2 - txtW / 2)
                    MyText(Format_P_V, _G[V_Font], FP.V_Clr or LblClr)
                end
            end
            if FP.Lbl_Pos == 'Free' then
                r.ImGui_DrawList_AddTextEx(draw_list, _G[Font], FP.FontSize or LblTextSize or Knob_DefaultFontSize,
                    Cx + (FP.Lbl_Pos_X or 0), Cy + (FP.Lbl_Pos_Y or 0), FP.Lbl_Clr or LblClr,
                    labeltoShow or FX[FxGUID][Fx_P].Name)
            end
        end

        if FP.V_Pos == 'Free' then
            local Ox, Oy = r.ImGui_GetCursorScreenPos(ctx)
            r.ImGui_DrawList_AddTextEx(draw_list, _G[V_Font], FP.V_FontSize or Knob_DefaultFontSize,
                Ox + Sldr_Width - TextW + (FP.V_Pos_X or 0), Oy + (FP.V_Pos_Y or 0), V_Clr,
                Format_P_V)
        end

        if Vertical ~= 'Vert' and (not FP.V_Pos or FP.V_Pos == 'Right') then
            r.ImGui_PushFont(ctx, Arial_11); local X, Y = r.ImGui_GetCursorScreenPos(ctx)
            r.ImGui_SetCursorScreenPos(ctx, SldrR - TextW, Y)


            MyText(Format_P_V, _G[V_Font], V_Clr)

            r.ImGui_PopFont(ctx)
        end




        if FX[FxGUID].Morph_Value_Edit or Mods == Alt + Ctrl or LBtnDC then r.ImGui_EndDisabled(ctx) end


        r.ImGui_EndGroup(ctx)
        if item_inner_spacing then r.ImGui_PopStyleVar(ctx) end


        if SpacingBelow then
            for i = 1, SpacingBelow, 1 do r.ImGui_Spacing(ctx) end
        else
            r.ImGui_Spacing(ctx); r.ImGui_Spacing(ctx); r.ImGui_Spacing(ctx); r.ImGui_Spacing(ctx); r.ImGui_Spacing(
                ctx)
        end
    end

    if LBtnDC then r.ImGui_PopStyleVar(ctx) end
    r.ImGui_PopStyleVar(ctx)
    return value_changed, p_value
end

---@param ctx ImGui_Context
---@param LT_Track MediaTrack
---@param FX_Idx integer
---@param Label string
---@param WhichPrm integer
---@param Options? "Get Options"|string[]
---@param Width number
---@param Style Style
---@param FxGUID string
---@param Fx_P integer
---@param OptionValues? number[]
---@param LabelOveride? string|nil
---@param CustomLbl? string
---@param Lbl_Pos? Position
function AddCombo(ctx, LT_Track, FX_Idx, Label, WhichPrm, Options, Width, Style, FxGUID, Fx_P, OptionValues,
                  LabelOveride, CustomLbl, Lbl_Pos)

    LabelValue = Label .. 'Value'
    local FP
    FX[FxGUID or ''][Fx_P or ''] = FX[FxGUID or ''][Fx_P or ''] or {}
    r.ImGui_BeginGroup(ctx)
    if Fx_P then FP = FX[FxGUID][Fx_P] end
    local V_Font = 'Font_Andale_Mono_' .. roundUp(FP.V_FontSize or LblTextSize or Knob_DefaultFontSize, 1)
    local Font = 'Font_Andale_Mono_' .. roundUp(FP.FontSize or LblTextSize or Knob_DefaultFontSize, 1)
    
    if Fx_P and FP then
        if (FP.Lbl_Pos == 'Left' and Lbl_Pos ~= 'No Lbl') or FP.Lbl_Pos == 'Top' then
            local name
            if not LabelOveride and not FP.CustomLbl and not CustomLbl then
                _, name = r.TrackFX_GetParamName(
                    LT_Track, FX_Idx, WhichPrm)
            end
            r.ImGui_AlignTextToFramePadding(ctx)
            MyText(LabelOveride or FP.CustomLbl or CustomLbl or FP.Name, _G[Font],
                FP.Lbl_Clr or r.ImGui_GetColor(ctx, r.ImGui_Col_Text()))
            if FP.Lbl_Pos == 'Left' and Lbl_Pos ~= 'No Lbl' then
                SL()
            end
        end
        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FramePadding(), 0, FP.Height or 3 )

    end

    if LabelOveride then _G[LabelValue] = LabelOveride end

    local PopClr
    local MaxTextLength
    if Style == 'Pro C 2' then
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBg(), 0x444444ff)
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0xffffffff)
        PopClr = 2
        if _G[LabelValue] == 'Mastering' then _G[LabelValue] = 'Master' end
    else
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBg(), FX[FxGUID][Fx_P].BgClr or 0x444444ff)
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), FX[FxGUID][Fx_P].V_Clr or 0xffffffff)
        PopClr = 2
    end
    local OP = FX.Prm.Options; local OPs, V

    if Options == 'Get Options' then
        if not OP[FxGUID] then OP[FxGUID] = {} end
        if not OP[FxGUID][Fx_P] then
            OP[FxGUID][Fx_P] = {};

            OP[FxGUID][Fx_P] = { V = {} }
        end
        OPs = OP[FxGUID][Fx_P]
        V = OP[FxGUID][Fx_P].V


        if #OPs == 0 then
            local OrigPrmV = r.TrackFX_GetParamNormalized(LT_Track, FX_Idx, WhichPrm)
            for i = 0, 1.01, 0.01 do
                r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, WhichPrm, i)
                local _, buf = r.TrackFX_GetFormattedParamValue(LT_Track, FX_Idx, WhichPrm)

                if not Value then
                    Value = buf; OPs[1] = buf
                    V[1] = i
                end
                if Value ~= buf then
                    table.insert(OPs, buf)
                    table.insert(V, i)
                    local L1 = r.ImGui_CalcTextSize(ctx, buf); local L2 = r.ImGui_CalcTextSize(ctx, Value)
                    FX[FxGUID][Fx_P].Combo_W = math.max(L1, L2)
                    Value = buf
                end
            end
            r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, WhichPrm, OrigPrmV)
        end
    end




    local ExtraW
    if Style == 'up-down arrow' then ExtraW = 20 end


    if FX[FxGUID][Fx_P].ManualValues then
        local Vn = r.TrackFX_GetParamNormalized(LT_Track, FX_Idx, WhichPrm)

        for i, V in ipairs(FP.ManualValues) do
            if Vn == V then _G[LabelValue] = FP.ManualValuesFormat[i] end
        end
    else
        _, _G[LabelValue] = r.TrackFX_GetFormattedParamValue(LT_Track, FX_Idx, WhichPrm)
    end
    --_,_G[LabelValue]  = r.TrackFX_GetFormattedParamValue(LT_Track,FX_Idx, WhichPrm)
    local Cx, Cy
    if FP.V_Pos == 'Free' then
        Cx, Cy = r.ImGui_GetCursorPos(ctx)
        r.ImGui_SetCursorPos(ctx, Cx + (FP.V_Pos_X or 0), Cy + (FP.V_Pos_Y or 0))
    end

    ---@param ctx ImGui_Context
    ---@return boolean
    ---@return string
    local function begincombo(ctx)
        if FP.V_FontSize then r.ImGui_PushFont(ctx, _G[V_Font]) end
        if Width or FX[FxGUID][Fx_P].Combo_W then
            r.ImGui_SetNextItemWidth(ctx, Width or (FX[FxGUID][Fx_P].Combo_W + (ExtraW or 0)))
        end
        if r.ImGui_BeginCombo(ctx, '## ' .. tostring(Label), LabelOveride or _G[LabelValue], r.ImGui_ComboFlags_NoArrowButton()) then
            -----Style--------

            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Header(), 0x44444433)
            local AccentClr = r.ImGui_GetColor(ctx, r.ImGui_Col_SliderGrabActive())
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_HeaderHovered(), AccentClr)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), 0xbbbbbbff)
            if Style == 'Pro C 2' then
                ProC.ChoosingStyle = true
            end
            local Options = Options
            if FX[FxGUID][Fx_P].ManualValues then Options = FP.ManualValuesFormat end



            if Options ~= 'Get Options' then
                local rv

                for i = 1, #Options, 1 do
                    if r.ImGui_Selectable(ctx, Options[i], i) and WhichPrm ~= nil then
                        if OptionValues then
                            r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, WhichPrm, OptionValues[i])
                        else
                            r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, WhichPrm,
                                (i - 1) / #Options + ((i - 1) / #Options) * 0.1) -- + options* 0.05 so the value will be slightly higher than threshold,
                        end
                        if FX[FxGUID][Fx_P].ManualValues then
                            if FX[FxGUID][Fx_P].ManualValues[i] then
                                _G[LabelValue] = FP.ManualValuesFormat[i]
                            end
                        else
                            _, _G[LabelValue] = r.TrackFX_GetFormattedParamValue(LT_Track, FX_Idx, WhichPrm)
                        end
                        r.ImGui_PopStyleColor(ctx, 3)
                        r.ImGui_EndCombo(ctx)
                        return true, _G[LabelValue]
                    end
                end
                r.ImGui_PopStyleColor(ctx, 3)
                r.ImGui_EndCombo(ctx)
            else
                for i = 1, #OPs, 1 do
                    if r.ImGui_Selectable(ctx, OPs[i], i) and WhichPrm ~= nil then
                        r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, WhichPrm, V[i])
                        _, _G[LabelValue] = r.TrackFX_GetFormattedParamValue(LT_Track, FX_Idx, WhichPrm)
                        r.ImGui_PopStyleColor(ctx, 3)
                        r.ImGui_EndCombo(ctx)
                        return true, _G[LabelValue]
                    end
                end
                r.ImGui_PopStyleColor(ctx, 3)
                r.ImGui_EndCombo(ctx)
            end

            local L, T = r.ImGui_GetItemRectMin(ctx); local R, B = r.ImGui_GetItemRectMax(ctx)
            local lineheight = r.ImGui_GetTextLineHeight(ctx)
            local drawlist = r.ImGui_GetForegroundDrawList(ctx)

            r.ImGui_DrawList_AddRectFilled(drawlist, L, T + lineheight / 8, R, B - lineheight / 8, 0x88888844,
                Rounding)
            r.ImGui_DrawList_AddRect(drawlist, L, T + lineheight / 8, R, B - lineheight / 8, 0x88888877, Rounding)
        else
            if Style == 'Pro C 2' and LBtnRel then
                ProC.ChoosingStyle = false
            end
        end
        -- DnD_PLink_TARGET(FxGUID, Fx_P, FX_Idx, P_Num)
        if FP.V_FontSize then r.ImGui_PopFont(ctx) end
    end

    local rv, v_format = begincombo(ctx)

    if Style == 'up-down arrow' then
        local R, B = r.ImGui_GetItemRectMax(ctx)
        local lineheight = r.ImGui_GetTextLineHeight(ctx)
        local drawlist = r.ImGui_GetWindowDrawList(ctx)
        local m = B - lineheight / 2 - 3
        g = 2
        local X = R - ExtraW / 2
        DrawTriangle(drawlist, X, m - g, 3, clr)
        DrawDownwardTriangle(drawlist, X, m + g, 3, clr)
    end



    if FP.Lbl_Pos == 'Right' then
        SL()
        r.ImGui_AlignTextToFramePadding(ctx) --[[ r.ImGui_Text(ctx,FP.CustomLbl or FP.Name)  ]]
        MyText(LabelOveride or FP.CustomLbl or CustomLbl or FP.Name, _G[Font],
            FP.Lbl_Clr or r.ImGui_GetColor(ctx, r.ImGui_Col_Text()))
    elseif FP.Lbl_Pos == 'Bottom' then
        MyText(LabelOveride or FP.CustomLbl or CustomLbl or FP.Name, _G[Font],
            FP.Lbl_Clr or r.ImGui_GetColor(ctx, r.ImGui_Col_Text()))
    end
    r.ImGui_PopStyleVar(ctx)
    r.ImGui_EndGroup(ctx)
    r.ImGui_PopStyleColor(ctx, PopClr or 0)
   if rv then return rv, v_format end
end

---@param LT_Track MediaTrack
---@param FX_Idx integer
---@param Value any
---@param P_Num number
---@param BgClr number
---@param Lbl_Type? "Use Prm Name as Lbl"
---@param Fx_P string|integer
---@param F_Tp string|integer ---TODO unused
---@param FontSize number
---@param FxGUID string
---@return integer
function AddSwitch(LT_Track, FX_Idx, Value, P_Num, BgClr, Lbl_Type, Fx_P, F_Tp, FontSize, FxGUID)

    local clr, TextW, Font
    FX[FxGUID][Fx_P] = FX[FxGUID][Fx_P] or {}
    local FP = FX[FxGUID][Fx_P]
    local V_Font = 'Font_Andale_Mono_' .. roundUp(FP.V_FontSize or LblTextSize or Knob_DefaultFontSize, 1)
    r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FramePadding(), 0, FP.Height or 3 )

    if FontSize then
        Font = 'Font_Andale_Mono_' .. roundUp(FontSize, 1); r.ImGui_PushFont(ctx, _G[Font])
    end
    if FX[FxGUID][Fx_P].Lbl_Clr then r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), FX[FxGUID][Fx_P].Lbl_Clr) end
    local popClr

    r.ImGui_BeginGroup(ctx)
    if FP.Lbl_Pos == 'Left' then
        r.ImGui_AlignTextToFramePadding(ctx)
        r.ImGui_Text(ctx, FP.CustomLbl or FP.Name)
        SL()
    elseif FP.Lbl_Pos == 'Top' then
        r.ImGui_Text(ctx, FP.CustomLbl or FP.Name)
    end

    if FP.V_Pos == 'None' or FP.V_Pos == 'Free' then
        lbl = '  '
    elseif FP.V_Pos == 'Within' then
        r.ImGui_PushFont(ctx, _G[V_Font])
        _, lbl = r.TrackFX_GetFormattedParamValue(LT_Track, FX_Idx, P_Num)
        TextW = r.ImGui_CalcTextSize(ctx, lbl)
    elseif Lbl_Type == 'Use Prm Name as Lbl' then
        lbl = FX[FxGUID][Fx_P].Name
        TextW = r.ImGui_CalcTextSize(ctx, lbl)
    elseif Lbl_Type and Lbl_Type ~= 'Use Prm Name as Lbl' then
        lbl = Lbl_Type
        TextW = r.ImGui_CalcTextSize(ctx, Lbl_Type)
        FX[FxGUID][Fx_P].Switch_W = TextW
    else --Use Value As Label
        _, lbl = r.TrackFX_GetFormattedParamValue(LT_Track, FX_Idx, P_Num)
    end

    if FP.Lbl_Pos == 'Within' then lbl = FP.CustomLbl or FP.Name end




    if FX[FxGUID][Fx_P].V == nil then FX[FxGUID][Fx_P].V = r.TrackFX_GetParamNormalized(LT_Track, FX_Idx, P_Num) end


    if FX[FxGUID][Fx_P].Switch_On_Clr then
        if FX[FxGUID][Fx_P].V == 1 then
            popClr = 2
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), FX[FxGUID][Fx_P].Switch_On_Clr)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(),
                Change_Clr_A(FX[FxGUID][Fx_P].Switch_On_Clr, -0.2))
        else
            popClr = 2
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), BgClr or 0x00000000)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), Change_Clr_A((BgClr or 0xffffff00), -0.2))
        end
    else
        if BgClr then
            popClr = 2
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Button(), BgClr or 0xffffff00)
            r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), Change_Clr_A((BgClr or 0xffffff00), -0.2))
        end
    end


    if FP.V_Clr then r.ImGui_PushStyleColor(ctx, r.ImGui_Col_Text(), FP.V_Clr) end




    if not FP.Image then
        r.ImGui_Button(ctx, lbl .. '##' .. FxGUID .. Fx_P, FX[FxGUID][Fx_P].Sldr_W or TextW)
    else -- if there's an image
        uvmin, uvmax, w, h = Calc_strip_uv(FP.Image, FP.V or r.TrackFX_GetParamNormalized(LT_Track, FX_Idx, P_Num))



        r.ImGui_ImageButton(ctx, lbl .. '##' .. FxGUID .. Fx_P, FP.Image, FP.Sldr_W or 30, FP.Sldr_W or 30, 0,
            uvmin, 1, uvmax, FP.BgClr or 0xffffff00)
    end


    if r.ImGui_IsItemClicked(ctx, 0) then
        if FP.SwitchType == 'Momentary' then
            FX[FxGUID][Fx_P].V = FX[FxGUID][Fx_P].SwitchTargV
            r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, P_Num, FX[FxGUID][Fx_P].SwitchTargV or 0)
            if r.ImGui_IsItemDeactivated(ctx) then
                r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, P_Num, FX[FxGUID][Fx_P].SwitchBaseV or 1)
            end
        else -- if it's a toggle
            local Value = r.TrackFX_GetParamNormalized(LT_Track, FX_Idx, P_Num)
            if Value == 0 then
                r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, P_Num, 1)
                FX[FxGUID][Fx_P].V = 1
            elseif Value == 1 then
                r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, P_Num, 0)
                FX[FxGUID][Fx_P].V = 0
            end
        end
    end






    if FP.V_Clr then r.ImGui_PopStyleColor(ctx) end
    --Sync Value if user tweak plugin's actual GUI.

    if focusedFXState == 1 and LT_FXGUID == FxGUID and LT_ParamNum == P_Num and not FX[FxGUID][Fx_P].WhichCC then
        FX[FxGUID][Fx_P].V = r.TrackFX_GetParamNormalized(LT_Track, FX_Idx, P_Num)
    end

    if FX[FxGUID][Fx_P].SwitchType == 'Momentary' then
        clr = 0x00000000
    else
        if FX[FxGUID][Fx_P].V == 0 then clr = 0x00000022 else clr = 0xffffff22 end
    end
    local X, Y = r.ImGui_GetItemRectMin(ctx); local W, H = r.ImGui_GetItemRectSize(ctx)
    local DL = r.ImGui_GetWindowDrawList(ctx)

    if FP.Lbl_Pos == 'Right' then
        SL()
        r.ImGui_AlignTextToFramePadding(ctx)
        r.ImGui_Text(ctx, FP.CustomLbl or FP.Name)
    elseif FP.Lbl_Pos == 'Bottom' then
        r.ImGui_Text(ctx, FP.CustomLbl or FP.Name)
    elseif FP.Lbl_Pos == 'Free' then
        local Cx, Cy = r.ImGui_GetCursorScreenPos(ctx)
        r.ImGui_DrawList_AddTextEx(DL, _G[Font], FontSize or 11, Cx + (FP.Lbl_Pos_X or 0), Cy + (FP.Lbl_Pos_Y or 0),
            FP.Lbl_Clr or getClr(r.ImGui_Col_Text()), FP.CustomLbl or FP.Name)
    end

    if FP.V_Pos == 'Free' then
        local Cx, Cy = r.ImGui_GetCursorScreenPos(ctx)
        local _, lbl = r.TrackFX_GetFormattedParamValue(LT_Track, FX_Idx, P_Num)
        r.ImGui_DrawList_AddTextEx(DL, _G[Font], FontSize or 11, Cx + (FP.V_Pos_X or 0), Cy + (FP.V_Pos_Y or 0),
            FP.Lbl_Clr or getClr(r.ImGui_Col_Text()), lbl)
    end
    if FP.V_Pos == 'Within' then r.ImGui_PopFont(ctx) end


    r.ImGui_EndGroup(ctx)

    r.ImGui_DrawList_AddRectFilled(DL, X, Y, X + W, Y + H, clr, FX.Round[FxGUID] or 0)
    r.ImGui_PopStyleVar(ctx)
    if FontSize then r.ImGui_PopFont(ctx) end
    if popClr then r.ImGui_PopStyleColor(ctx, popClr) end
    if FX[FxGUID][Fx_P].Lbl_Clr then r.ImGui_PopStyleColor(ctx) end
    if Value == 0 then return 0 else return 1 end
end

---TODO style param is not quite there yet
---some of the missing options might be:
---    | "Pro C 2"
---    | "Pro C Thresh"
---    | "Custom Image"
---    | "Invisible"
---    | "FX Layering"
---    | 'up-down arrow'
---@param ctx ImGui_Context
---@param label string
---@param labeltoShow string
---@param p_value number
---@param v_min number
---@param v_max number
---@param Fx_P any
---@param FX_Idx integer
---@param P_Num number
---@param Style "FX Layering"|"Pro C"|"Pro C Lookahead"|string
---@param Sldr_Width number
---@param item_inner_spacing number
---@param Disable? "Disabled"
---@param Lbl_Clickable? "Lbl_Clickable"
---@param Lbl_Pos Position
---@param V_Pos Position
---@param DragDir "Left"|"Right"|"Left-Right"
---@param AllowInput? "NoInput"
function AddDrag(ctx, label, labeltoShow, p_value, v_min, v_max, Fx_P, FX_Idx, P_Num, Style, Sldr_Width,
                 item_inner_spacing, Disable, Lbl_Clickable, Lbl_Pos, V_Pos, DragDir, AllowInput)
    local FxGUID = FxGUID or r.TrackFX_GetFXGUID(LT_Track, FX_Idx)
    if FxGUID then 
        FX[FxGUID][Fx_P] = FX[FxGUID][Fx_P] or {}

        --local FxGUID = FXGUID[FX_Idx]
        local FP = FX[FxGUID][Fx_P]
        r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FramePadding(), 0, FP.Height or 3 )


        if FX[FxGUID].Morph_Value_Edit or (Mods == Alt + Ctrl and is_hovered) then r.ImGui_BeginDisabled(ctx) end
        local radius_outer = 20.0

        local pos = { r.ImGui_GetCursorScreenPos(ctx) }

        local line_height = r.ImGui_GetTextLineHeight(ctx); local draw_list = r.ImGui_GetWindowDrawList(ctx)

        local f_draw_list = r.ImGui_GetForegroundDrawList(ctx)
        local SPLITTER = r.ImGui_CreateDrawListSplitter(draw_list)
        r.ImGui_DrawListSplitter_Split(SPLITTER, 2)

        local mouse_delta = { r.ImGui_GetMouseDelta(ctx) }
        local F_Tp = FX.Prm.ToTrkPrm[FxGUID .. Fx_P]


        local Font = 'Font_Andale_Mono_' .. roundUp(FP.FontSize or LblTextSize or Knob_DefaultFontSize, 1)


        local V_Font = 'Arial_' .. roundUp(FP.V_FontSize or LblTextSize or Knob_DefaultFontSize, 1)

        if type(FP) ~= 'table' then
            FX[FxGUID][Fx_P] = {}
            FP = FX[FxGUID][Fx_P]
        end

        if item_inner_spacing then
            r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_ItemSpacing(), item_inner_spacing, item_inner_spacing)
        end

        r.ImGui_BeginGroup(ctx)
        local BgClr
        if SliderStyle == 'Pro C' or SliderStyle == 'Pro C Lookahead' then BgClr = 0x55555544 end
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBg(),
            BgClr or FP.BgClr or r.ImGui_GetColor(ctx, r.ImGui_Col_FrameBg()))
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBgActive(),
            FP.BgClrAct or r.ImGui_GetColor(ctx, r.ImGui_Col_FrameBgActive()))
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBgHovered(),
            FP.BgClrHvr or r.ImGui_GetColor(ctx, r.ImGui_Col_FrameBgHovered()))

        if Lbl_Pos == 'Left' then
            r.ImGui_AlignTextToFramePadding(ctx)
            MyText(labeltoShow, _G[Font], FP.Lbl_Clr or 0xaaaaaaff)
            r.ImGui_SameLine(ctx, nil, 8)
            r.ImGui_AlignTextToFramePadding(ctx)
        elseif Lbl_Pos == 'Free' then
            r.ImGui_DrawList_AddTextEx(WDL, _G[Font], FP.FontSize or Knob_DefaultFontSize, pos[1] + (FP.Lbl_Pos_X or 0),
                pos[2] + (FP.Lbl_Pos_Y or 0), FP.Lbl_Clr or 0xffffffff, labeltoShow)
        end
        r.ImGui_SetNextItemWidth(ctx, Sldr_Width)

        local DragSpeed = 0.01
        if Mods == Shift then DragSpeed = 0.0003 end
        if DraggingMorph == FxGUID then p_value = r.TrackFX_GetParamNormalized(LT_Track, FX_Idx, P_Num) end


        local flag
        if AllowInput == 'NoInput' then flag = r.ImGui_SliderFlags_NoInput() end
        if Style == 'FX Layering' then r.ImGui_PushStyleVar(ctx, r.ImGui_StyleVar_FrameRounding(), 0) end

        _, p_value = r.ImGui_DragDouble(ctx, label, p_value, DragSpeed, v_min, v_max, ' ', r.ImGui_SliderFlags_NoInput())
        r.ImGui_SetItemAllowOverlap(ctx)
        KNOB = false
        DnD_PLink_TARGET(FxGUID, Fx_P, FX_Idx, P_Num)
        ButtonDraw(SPLITTER, FX[FxGUID].BgClr or CustomColorsDefault.FX_Devices_Bg, nil, nil)
        if Style == 'FX Layering' then r.ImGui_PopStyleVar(ctx) end

        r.ImGui_PopStyleColor(ctx, 3)
        local PosL, PosT = r.ImGui_GetItemRectMin(ctx); local PosR, PosB = r.ImGui_GetItemRectMax(ctx)

        local value_changed = false
        local is_active = r.ImGui_IsItemActive(ctx)
        local is_hovered = r.ImGui_IsItemHovered(ctx)
        
        if is_active == true then Knob_Active = true end
        if Knob_Active == true then
            if IsLBtnHeld == false then Knob_Active = false end
        end
        SldrLength = PosR - PosL

        SldrGrbPos = SldrLength * (p_value or 1)

        RemoveModulationIfDoubleRClick(FxGUID, Fx_P, P_Num, FX_Idx)
        ---Edit preset morph values

        if FX[FxGUID].Morph_Value_Edit or (Mods == Alt + Ctrl and is_hovered) then
            if FX[FxGUID].MorphA[P_Num] and FX[FxGUID].MorphB[P_Num] then
                local sizeX, sizeY = r.ImGui_GetItemRectSize(ctx)
                local A = SetMinMax(PosL + sizeX * FX[FxGUID].MorphA[P_Num], PosL, PosR)
                local B = SetMinMax(PosL + sizeX * FX[FxGUID].MorphB[P_Num], PosL, PosR)
                local ClrA, ClrB = DefClr_A_Hvr, DefClr_B_Hvr
                local MsX, MsY = r.ImGui_GetMousePos(ctx)

                if FX[FxGUID].MorphA[P_Num] ~= FX[FxGUID].MorphB[P_Num] then
                    r.ImGui_DrawList_AddRectFilledMultiColor(WDL, A, PosT, B, PosB, ClrA, ClrB, ClrB, ClrA)
                end

                local txtClr = r.ImGui_GetStyleColor(ctx, r.ImGui_Col_Text())

                if r.ImGui_IsMouseHoveringRect(ctx, PosL, PosT, PosR, PosB) and not MorphingMenuOpen then
                    if IsLBtnClicked or IsRBtnClicked then
                        FP.TweakingAB_Val = P_Num
                        retval, Orig_Baseline = r.TrackFX_GetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".mod.baseline") 
                    end
                    if not FP.TweakingAB_Val then
                        local offsetA, offsetB
                        if A < B + 5 and A > B - 14 then
                            offsetA = -10
                            offsetB = 10
                        end
                        r.ImGui_DrawList_AddTextEx(WDL, Font_Andale_Mono_20_B, 16, A, PosT + (offsetA or 0), txtClr, 'A')
                        r.ImGui_DrawList_AddTextEx(WDL, Font_Andale_Mono_20_B, 16, B, PosT + (offsetB or 0), txtClr, 'B')
                    end
                end

                if FP.TweakingAB_Val == P_Num and not MorphingMenuOpen then
                    local X_A, X_B
                    local offsetA, offsetB
                    if IsLBtnHeld then
                        FX[FxGUID].MorphA[P_Num] = SetMinMax((MsX - PosL) / sizeX, 0, 1)
                        if FX[FxGUID].Morph_ID then -- if Morph Sldr is linked to a CC
                            local A = (MsX - PosL) / sizeX
                            local Scale = FX[FxGUID].MorphB[P_Num] - A
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.active", 1)   -- 1 active, 0 inactive
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.scale", Scale)   -- Scale
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.effect", -100) -- -100 enables midi_msg*
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.param", -1)   -- -1 not parameter link
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_bus", 15) -- 0 based, 15 = Bus 16
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_chan", 16) -- 0 based, 0 = Omni
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_msg", 160)   -- 160 is Aftertouch
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_msg2", FX[FxGUID].Morph_ID) -- CC value
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".mod.baseline", A) -- Baseline  
                        end
                    elseif IsRBtnHeld then
                        FX[FxGUID].MorphB[P_Num] = SetMinMax((MsX - PosL) / sizeX, 0, 1)
                        if FX[FxGUID].Morph_ID then -- if Morph Sldr is linked to a CC
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.active", 1)   -- 1 active, 0 inactive
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.scale", FX[FxGUID].MorphB[P_Num] - FX[FxGUID].MorphA[P_Num])   -- Scale
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.effect", -100) -- -100 enables midi_msg*
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.param", -1)   -- -1 not parameter link
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_bus", 15) -- 0 based, 15 = Bus 16
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_chan", 16) -- 0 based, 0 = Omni
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_msg", 160)   -- 160 is Aftertouch
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".plink.midi_msg2", FX[FxGUID].Morph_ID) -- CC value
                            r.TrackFX_SetNamedConfigParm(LT_Track, FX_Idx, "param."..P_Num..".mod.baseline", Orig_Baseline) -- Baseline 
                        end
                    end
                    if IsLBtnHeld then
                        X_A = MsX
                        Y_A = MsY - 15
                        offsetA = -10
                        if MsX < B + 5 and MsX > B - 14 then offsetB = 10 end
                    elseif IsRBtnHeld then
                        X_B = MsX
                        offsetB = -10
                        if MsX < A + 5 and MsX > A - 14 then offsetA = 10 end
                    end

                    r.ImGui_DrawList_AddTextEx(WDL, Font_Andale_Mono_20_B, 16, A, PosT + (offsetA or 0), txtClr, 'A')
                    r.ImGui_DrawList_AddTextEx(WDL, Font_Andale_Mono_20_B, 16, B, PosT + (offsetB or 0), txtClr, 'B')
                end
            end
            if LBtnRel or RBtnRel then
                StoreAllPrmVal('A', 'Dont')
                StoreAllPrmVal('B', 'Dont')
                FP.TweakingAB_Val = nil
            end
        end

        if FP.GrbClr and FX.LayEdit == FxGUID then
            local ActV
            local R, G, B, A = r.ImGui_ColorConvertU32ToDouble4(FP.GrbClr)
            local HSV, _, H, S, V = r.ImGui_ColorConvertRGBtoHSV(R, G, B) ---TODO I think this function only returns 3 values, not 5
            if V > 0.9 then ActV = V - 0.2 end
            local RGB, _, R, G, B = r.ImGui_ColorConvertHSVtoRGB(H, S, ActV or V + 0.2)
            local ActClr = r.ImGui_ColorConvertDouble4ToU32(R, G, B, A)
            local RGB, _, R, G, B = r.ImGui_ColorConvertHSVtoRGB(H, S, HvrV or V + 0.1)
            local HvrClr = r.ImGui_ColorConvertDouble4ToU32(R, G, B, A)
            FP.GrbAct = ActClr
            FP.GrbHvr = HvrClr
        end

        if Style == 'FX Layering' then
            r.ImGui_DrawList_AddRectFilled(draw_list, PosL, PosT, PosR, PosB, 0x99999910)
        end

        if not SliderStyle then
            if DragDir == 'Right' or DragDir == nil then
                if is_active then
                    r.ImGui_DrawList_AddRectFilled(draw_list, PosL, PosT, PosL + SldrGrbPos, PosB,
                        FP.GrbAct or 0xffffff77, Rounding)
                elseif is_hovered then
                    r.ImGui_DrawList_AddRectFilled(draw_list, PosL, PosT, PosL + SldrGrbPos, PosB,
                        FP.GrbHvr or 0xffffff55, Rounding)
                else
                    r.ImGui_DrawList_AddRectFilled(draw_list, PosL, PosT, PosL + SldrGrbPos, PosB,
                        FP.GrbClr or 0xffffff44, Rounding)
                end
            elseif DragDir == 'Left-Right' then
                local L = math.min(PosL + (PosR - PosL) / 2, PosL + SldrGrbPos); local R = math.max(
                    PosL + (PosR - PosL) / 2,
                    PosL + SldrGrbPos)
                if is_active then
                    r.ImGui_DrawList_AddRectFilled(draw_list, L, PosT, R, PosB, FP.GrbAct or 0xffffff77, Rounding)
                elseif is_hovered then
                    r.ImGui_DrawList_AddRectFilled(draw_list, L, PosT, R, PosB, FP.GrbHvr or 0xffffff55, Rounding)
                else
                    r.ImGui_DrawList_AddRectFilled(draw_list, L, PosT, R, PosB, FP.GrbClr or 0xffffff44, Rounding)
                end
            elseif DragDir == 'Left' then
                if is_active then
                    r.ImGui_DrawList_AddRectFilled(draw_list, PosR, PosT, PosL + SldrGrbPos, PosB,
                        FP.GrbAct or 0xffffff77,
                        Rounding)
                elseif is_hovered then
                    r.ImGui_DrawList_AddRectFilled(draw_list, PosR, PosT, PosL + SldrGrbPos, PosB,
                        FP.GrbHvr or 0xffffff55,
                        Rounding)
                else
                    r.ImGui_DrawList_AddRectFilled(draw_list, PosR, PosT, PosL + SldrGrbPos, PosB,
                        FP.GrbClr or 0xffffff44,
                        Rounding)
                end
            end
        elseif SliderStyle == 'Pro C' or SliderStyle == 'Pro C Lookahead' then
            if is_active then
                r.ImGui_DrawList_AddRectFilled(draw_list, PosL, PosT, PosL + SldrGrbPos, PosB, 0xFFD571bb, Rounding)
            elseif is_hovered then
                r.ImGui_DrawList_AddRectFilled(draw_list, PosL, PosT, PosL + SldrGrbPos, PosB, 0xDFB973bb, Rounding)
            else
                r.ImGui_DrawList_AddRectFilled(draw_list, PosL, PosT, math.max(PosL + SldrGrbPos, PosL), PosB, 0x888888bb,
                    Rounding)
            end
        end


        if Disable == 'Disabled' then
            r.ImGui_DrawList_AddRectFilled(draw_list, PosL, PosT, PosL + SldrGrbPos, PosB, 0x222222bb, Rounding)
        end

        local button_x, button_y = r.ImGui_GetCursorPos(ctx)
        r.ImGui_SetCursorPosY(ctx, button_y - (PosB - PosT))
        WhichClick()
        r.ImGui_InvisibleButton(ctx, '##plink' .. P_Num, PosR - PosL, PosB - PosT, ClickButton) -- for parameter link
        if ClickButton ==  r.ImGui_ButtonFlags_MouseButtonRight() and not AssigningMacro then -- right drag to link parameters
            DnD_PLink_SOURCE(FX_Idx, P_Num)
        end

        if is_active then
            if p_value < v_min then p_value = v_min end
            if p_value > v_max then p_value = v_max end
            value_changed = true
            r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, P_Num, p_value)
            MvingP_Idx = F_Tp

            Tweaking = P_Num .. FxGUID
        end

        local t            = (p_value - v_min) / (v_max - v_min)

        local radius_inner = radius_outer * 0.40
        local Clr_SldrGrab = r.ImGui_GetColor(ctx, r.ImGui_Col_SliderGrabActive())
        local ClrBg        = r.ImGui_GetColor(ctx, r.ImGui_Col_FrameBg())


        if (is_active or is_hovered) and (FX[FxGUID][Fx_P].V_Pos == 'None' or Style == 'Pro C' or Style == 'Pro C Lookahead') then
            local getSldr, Param_Value = r.TrackFX_GetFormattedParamValue(LT_Track, FX_Idx, P_Num)

            local window_padding       = { r.ImGui_GetStyleVar(ctx, r.ImGui_StyleVar_WindowPadding()) }
            r.ImGui_SetNextWindowPos(ctx, pos[1] - window_padding[1], pos[2] - line_height - window_padding[2] - 8)

            r.ImGui_BeginTooltip(ctx)
            r.ImGui_Text(ctx, Param_Value)
            r.ImGui_EndTooltip(ctx)
        end



        --if user tweak drag on ImGui
        if Tweaking == P_Num .. FxGUID then
            FX[FxGUID][Fx_P].V = p_value
            if not FP.WhichCC then
                r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, P_Num, p_value)
            else
                local unsetcc = r.TrackFX_SetNamedConfigParm(LT_Track, LT_FXNum, "param."..P_Num..".plink.active", 0)   -- 1 active, 0 inactive
                r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, P_Num, FX[FxGUID][Fx_P].V)
            end
        end


        if AssigningMacro ~= nil then
            r.ImGui_DrawList_AddRectFilled(draw_list, PosL, PosT, PosR, PosB,
                EightColors.bgWhenAsgnMod[AssigningMacro])
        end


        local AlreadyAddPrm = false

        if LT_ParamNum == P_Num and focusedFXState == 1 and LT_FXGUID == FxGUID and FX[FxGUID][Fx_P].Name and not FP.WhichCC then
            local LT_ParamValue = r.TrackFX_GetParamNormalized(LT_Track, LT_FX_Number, LT_ParamNum)

            FX[FxGUID][Fx_P].V = LT_ParamValue
            r.ImGui_DrawList_AddRectFilled(draw_list, PosL, PosT, PosR, PosB, 0x99999922, Rounding)
            r.ImGui_DrawList_AddRect(draw_list, PosL, PosT, PosR, PosB, 0x99999966, Rounding)

            for m = 1, 8, 1 do
                if AssigningMacro == m then
                    r.ImGui_PopStyleColor(ctx, 2)
                end
            end
        end

        --[[ if Tweaking == P_Num..FxGUID and IsLBtnHeld == false then
            if FP.WhichMODs  then
                r.GetSetMediaTrackInfo_String(LT_Track,'P_EXT: FX'..FxGUID..'Prm'..Fx_P.. 'Value before modulation' , FX[FxGUID][Fx_P].V, true    )
                r.gmem_write(7, CC) --tells jsfx to retrieve P value
                PM.TimeNow= r.time_precise()
                r.gmem_write(11000+CC , p_value)
                Link_Param_to_CC(LT_TrackNum, LT_FX_Number, P_Num, true, true, 176,MvingP_Idx) -- Use native API instead

            end

            Tweaking= nil
        end ]]

        if PM.TimeNow ~= nil then
            if r.time_precise() > PM.TimeNow + 1 then
                r.gmem_write(7, 0) --tells jsfx to stop retrieving P value
                r.gmem_write(8, 0)
                PM.TimeNow = nil
            end
        end

        IfTryingToAddExistingPrm(Fx_P, FxGUID, 'Rect', PosL, PosT, PosR, PosB)

        Tweaking = MakeModulationPossible(FxGUID, Fx_P, FX_Idx, P_Num, p_value, Sldr_Width)


        local TextW, h      = r.ImGui_CalcTextSize(ctx, labeltoShow, nil, nil, true)
        local SldrR, SldrB  = r.ImGui_GetItemRectMax(ctx)
        local SldrL, SldrT  = r.ImGui_GetItemRectMin(ctx)
        local W, H          = SldrR - SldrL, SldrB - SldrT
        local _, Format_P_V = r.TrackFX_GetFormattedParamValue(LT_Track, FX_Idx, P_Num)
        r.ImGui_PushFont(ctx, Arial_11)
        if FX[FxGUID][Fx_P].V_Round then Format_P_V = RoundPrmV(Format_P_V, FX[FxGUID][Fx_P].V_Round) end
        TextW, Texth = r.ImGui_CalcTextSize(ctx, Format_P_V, nil, nil, true, -100)
        if is_active then txtclr = 0xEEEEEEff else txtclr = 0xD6D6D6ff end

        if (V_Pos == 'Within' or Lbl_Pos == 'Left') and V_Pos ~= 'None' and V_Pos ~= 'Free' and V_Pos then
            r.ImGui_DrawList_AddTextEx(draw_list, _G[V_Font], FP.V_FontSize or Knob_DefaultFontSize,
                SldrL + W / 2 - TextW / 2,
                SldrT + H / 2 - 5, FP.V_Clr or txtclr, Format_P_V)
        elseif FP.V_Pos == 'Free' then
            local X = SldrL + W / 2 - TextW / 2
            local Y = SldrT + H / 2 - 5
            local Ox, Oy = Get
            r.ImGui_DrawList_AddTextEx(draw_list, _G[V_Font], FP.V_FontSize or Knob_DefaultFontSize,
                X + (FP.V_Pos_X or 0),
                Y + (FP.V_Pos_Y or 0), FP.V_Clr or 0xffffffff, Format_P_V)
        end

        if Lbl_Pos == 'Within-Left' then
            r.ImGui_DrawList_AddText(draw_list, SldrL, SldrT + H / 2 - 5, FX[FxGUID][Fx_P].Lbl_Clr or txtclr, labeltoShow)
        end
        if V_Pos == 'Within-Right' then
            r.ImGui_DrawList_AddText(draw_list, SldrR - TextW, SldrT + H / 2 - 5, FX[FxGUID][Fx_P].V_Clr or txtclr,
                Format_P_V)
        end

        r.ImGui_PopFont(ctx)

        if not Lbl_Pos or Lbl_Pos == 'Bottom' then
            local X, Y = r.ImGui_GetCursorScreenPos(ctx)
            local TxtClr = FP.Lbl_Clr or getClr(r.ImGui_Col_Text())
            if Disable == 'Disabled' then TxtClr = getClr(r.ImGui_Col_TextDisabled()) end

            if item_inner_spacing then
                if item_inner_spacing < 0 then r.ImGui_SetCursorPosY(ctx, r.ImGui_GetCursorPosY(ctx) + item_inner_spacing) end
            end

            MyText(labeltoShow, _G[Font] or Font_Andale_Mono_12, TxtClr)

            if not string.find(FX.Win_Name_S[FX_Idx] or '', 'Pro%-C 2') then r.ImGui_SameLine(ctx) end

            r.ImGui_SetCursorScreenPos(ctx, SldrR - TextW, Y)

            if Style ~= 'Pro C Lookahead' and Style ~= 'Pro C' and (not FX[FxGUID][Fx_P].V_Pos or FX[FxGUID][Fx_P].V_Pos == 'Right') then
                MyText(Format_P_V, _G[V_Font], FP.V_Clr or getClr(r.ImGui_Col_Text()))
            end
        end




        if Lbl_Clickable == 'Lbl_Clickable' then
            local TextL; local TextY; local TxtSize;
            local HvrText = r.ImGui_IsItemHovered(ctx)
            local ClickText = r.ImGui_IsItemClicked(ctx)

            if HvrText then
                TextL, TextY = r.ImGui_GetItemRectMin(ctx); TxtSize = r.ImGui_CalcTextSize(ctx, labeltoShow)
                r.ImGui_DrawList_AddRectFilled(draw_list, TextL - 2, TextY, TextL + TxtSize, TextY + 10, 0x99999933)
                r.ImGui_DrawList_AddRect(draw_list, TextL - 2, TextY, TextL + TxtSize, TextY + 10, 0x99999955)
            end

            if ClickText then
                if Style == 'Pro C Lookahead' then
                    local OnOff;
                    if OnOff == nil then OnOff = r.TrackFX_GetParamNormalized(LT_Track, FX_Idx, 41) end
                    if OnOff == 1 then
                        r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, 41, 0)
                        Lookahead = 1
                    else
                        Lookahead = 0
                        r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, 41, 1)
                    end
                end
            end
        end

        r.ImGui_EndGroup(ctx)
        if item_inner_spacing then r.ImGui_PopStyleVar(ctx) end
        if FX[FxGUID].Morph_Value_Edit or is_hovered and Mods == Alt + Ctrl then r.ImGui_EndDisabled(ctx) end

        r.ImGui_PopStyleVar(ctx)
    end
    return value_changed, p_value
end

---@param FxGUID string
---@param FX_Name string
function CheckIfLayoutEditHasBeenMade(FxGUID, FX_Name)
    if FX[FxGUID].File then
        local ChangeBeenMade
        local PrmCount = r.GetExtState('FX Devices - ' .. FX_Name, 'Param Instance')
        local Ln = FX[FxGUID].FileLine

        if FX[FxGUID].GrbRound ~= (get_aftr_Equal_Num(Ln[4]) or 0) then end
        if FX[FxGUID].Round ~= (get_aftr_Equal_Num(Ln[3]) or 0) then end
        if FX[FxGUID].BgClr ~= get_aftr_Equal_Num(Ln[5]) then end
        if FX[FxGUID].TitleWidth ~= (get_aftr_Equal_Num(Ln[7]) or 0) then end
        if FX[FxGUID].Width ~= (get_aftr_Equal_Num(Ln[6]) or 0) then end

        ChangeBeenMade = true
        --end

        for Fx_P = 1, #FX[FxGUID] or 0, 1 do
            local ID = FxGUID .. Fx_P
            local FP = FX[FxGUID][Fx_P]
            local function L(n)
                return Ln[n + (40 - 14) * (Fx_P - 1)]
            end
            if FP.Name ~= get_aftr_Equal_Num(L(14)) or
                FP.Num ~= get_aftr_Equal_Num(L(15)) or
                FP.Sldr_W ~= get_aftr_Equal_Num(L(16)) or
                FP.Type ~= get_aftr_Equal_(L(17)) or
                FP.PosX ~= get_aftr_Equal_Num(L(18)) or
                FP.PosY ~= get_aftr_Equal_Num(L(19)) or
                FP.Style ~= get_aftr_Equal(L(20)) or
                FP.V_FontSize ~= get_aftr_Equal_Num(L(21)) or
                FP.CustomLbl ~= get_aftr_Equal_Num(L(22)) or
                FP.FontSize ~= get_aftr_Equal_Num(L(23)) or
                FP.Sldr_H ~= '1' or
                FP.BgClr ~= '2' or
                FP.GrbClr ~= '3' or
                FP.Lbl_Pos ~= '4' or
                FP.V_Pos ~= '' or
                FP.Lbl_Clr ~= '4' or
                FP.V_Clr ~= '4' or
                FP.DragDir ~= '4' or
                FP.ConditionPrm ~= '4'

            then
                ChangeBeenMade = true
            end
        end


        if FX[FxGUID].AllPrmHasBeenDeleted then ChangeBeenMade = true end
        return ChangeBeenMade
    end
end

---@param FX_Idx string
function CheckIfDrawingHasBeenMade(FX_Idx)
    local D = Draw[FX.Win_Name_S[FX_Idx]], ChangeBeenMade
    for i, Type in pairs(D.Type) do
        if D.L[i] ~= tonumber(r.GetExtState('FX Devices Drawings', 'prm ' .. i .. 's L pos')) or
            D.R[i] ~= tonumber(r.GetExtState('FX Devices Drawings', 'prm ' .. i .. 's R Pos')) or
            D.T[i] ~= tonumber(r.GetExtState('FX Devices Drawings', 'prm ' .. i .. 's T Pos')) or
            D.B[i] ~= tonumber(r.GetExtState('FX Devices Drawings', 'prm ' .. i .. 's B Pos')) or
            D.Txt[i] ~= tonumber(r.GetExtState('FX Devices Drawings', 'prm ' .. i .. 's Txt')) or
            D.clr[i] ~= tonumber(r.GetExtState('FX Devices Drawings', 'prm ' .. i .. 's Clr')) then
            ChangeBeenMade = true
        end
    end
    return ChangeBeenMade
end

---@param Sel_Track_FX_Count integer
function RetrieveFXsSavedLayout(Sel_Track_FX_Count)

    if LT_Track then
        TREE = BuildFXTree(LT_Track or tr)

        for FX_Idx = 0, Sel_Track_FX_Count - 1, 1 do
            
            local PrmInst, Line, FX_Name
            local FxGUID = r.TrackFX_GetFXGUID(LT_Track, FX_Idx)
            --local file = CallFile('r', FX_Name..'.ini', 'FX Layouts')

            local function GetInfo(FxGUID, FX_Idx)
                if FxGUID then
                    FX[FxGUID] = FX[FxGUID] or {}
                    FX[FxGUID].File = file
                    local _, FX_Name = r.TrackFX_GetFXName(LT_Track, FX_Idx)
                    local FX_Name = ChangeFX_Name(FX_Name)

                    if LO[FX_Name] then 

                        FX[FxGUID] = FX[FxGUID] or {}
                        local T = LO[FX_Name]
                        FX[FxGUID].MorphHide = T.MorphHide
                        FX[FxGUID].Round = T.Round
                        FX[FxGUID].GrbRound = T.GrbRound
                        FX[FxGUID].BgClr = T.BgClr
                        FX[FxGUID].Width = T.Width
                        FX[FxGUID].TitleWidth = T.TitleWidth
                        FX[FxGUID].TitleClr = T.TitleClr
                        FX[FxGUID].CustomTitle = T.CustomTitle

                        for i, v in ipairs(T) do 
                            FX[FxGUID][i] = FX[FxGUID][i] or {}
                            local FP = FX[FxGUID][i]
                            FP.Name         =  v.Name       
                            FP.Num          =  v.Num        
                            FP.Sldr_W       =  v.Sldr_W     
                            FP.Type         =  v.Type       
                            FP.PosX         =  v.PosX       
                            FP.PosY         =  v.PosY       
                            FP.Style        =  v.Style      
                            FP.V_FontSize   =  v.V_FontSize 
                            FP.CustomLbl    =  v.CustomLbl  
                            FP.FontSize     =  v.FontSize
                            FP.Height       =  v.Height
                            FP.BgClr        =  v.BgClr
                            FP.GrbClr       =  v.GrbClr
                            FP.Lbl_Pos      =  v.Lbl_Pos
                            FP.V_Pos        =  v.V_Pos 
                            FP.Lbl_Clr      =  v.Lbl_Clr
                            FP.V_Clr        =  v.V_Clr
                            FP.DragDir      =  v.DragDir
                            FP.Value_Thick  =  v.Value_Thick
                            FP.V_Pos_X      =  v.V_Pos_X
                            FP.V_Pos_Y      =  v.V_Pos_Y
                            FP.Lbl_Pos_X    =  v.Lbl_Pos_X
                            FP.Lbl_Pos_Y    =  v.Lbl_Pos_Y 
                            FP.Image        =  v.Image
                            FP.ImagePath    =  v.ImagePath
                            FP.ConditionPrm =  v.ConditionPrm
                            FP.ConditionPrm_V = v.ConditionPrm_V
                            FP.ConditionPrm_V_Norm = v.ConditionPrm_V_Norm
                            FP.Switch_On_Clr = v.Switch_On_Clr
                            for i = 2, 5, 1 do
                                FP['ConditionPrm'..i]  = v['ConditionPrm'..i]
                                FP['ConditionPrm_V'..i]  = v['ConditionPrm_V'..i]
                                FP['ConditionPrm_V_Norm'..i]  = v['ConditionPrm_V_Norm'..i]
                            end
                            FP.ManualValues = v.ManualValues
                            FP.ManualValuesFormat = v.ManualValuesFormat
                            FP.Draw = v.Draw
                        end
                        FX[FxGUID].Draw =  T.Draw
                        
                    else
                        local dir_path = ConcatPath(r.GetResourcePath(), 'Scripts', 'FX Devices', 'BryanChi_FX_Devices', 'src', 'FX Layouts')
                        local file_path = ConcatPath(dir_path, FX_Name .. '.ini')

                        -- Create directory for file if it doesn't exist
                        r.RecursiveCreateDirectory(dir_path, 0)
                        local file = io.open(file_path, 'r')

                        local PrmInst
                        LO[FX_Name] = LO[FX_Name] or {}
                        local T = LO[FX_Name]
                        if file then

                            Line = get_lines(file_path)
                            FX[FxGUID].FileLine = Line
                            Content = file:read('*a')
                            local Ct = Content

                            

                            T.MorphHide = r.GetSetMediaTrackInfo_String(LT_Track,'P_EXT: FX Morph Hide' .. FxGUID, 'true', true)
                            T.Round = RecallGlobInfo(Ct, 'Edge Rounding = ', 'Num')
                            T.GrbRound = RecallGlobInfo(Ct, 'Grb Rounding = ', 'Num')
                            T.BgClr = RecallGlobInfo(Ct, 'BgClr = ', 'Num')
                            T.Width = RecallGlobInfo(Ct, 'Window Width = ', 'Num')
                            T.TitleWidth = RecallGlobInfo(Ct, 'Title Width = ', 'Num')
                            T.TitleClr = RecallGlobInfo(Ct, 'Title Clr = ', 'Num')
                            T.CustomTitle = RecallGlobInfo(Ct, 'Custom Title = ')
                            PrmInst = RecallGlobInfo(Ct, 'Param Instance = ', 'Num')
                        else
                            Draw[FX_Name] = nil
                        end




                        -------------------------------------Parameters -------------------------------------------------
                        function attachFont(ctx, var, ft, sz, FP)
                            if sz > 20 then
                                --ChangeFont = FP

                                CF = CF or {}


                                ChangeFont_Size = roundUp(sz, 1)
                                _G[var .. '_' .. roundUp(sz, 1)] = r.ImGui_CreateFont(ft, roundUp(sz, 1))

                                r.ImGui_Attach(ctx, _G[var .. '_' .. roundUp(sz, 1)])
                                ChangeFont_Font = var
                            end
                        end

                        if --[[ r.GetExtState('FX Devices - '..FX_Name, 'Param Instance') ~= ''  ]] PrmInst then
                            local Ct = Content
                            PrmCount = RecallGlobInfo(Ct, 'Param Instance = ', 'Num')

                            if PrmCount then
                                for Fx_P = 1, PrmCount or 0, 1 do
                                    local function L(n)
                                        return Line[n + (40 - 14) * (Fx_P - 1)]
                                    end
                                    FX[FxGUID]       = FX[FxGUID] or {}
                                    T[Fx_P] = T[Fx_P] or {}

                                    local FP         = T[Fx_P]
                                    local ID         = FxGUID .. Fx_P

                                    FP.Name          = RecallInfo(Ct, 'Name', Fx_P)
                                    FP.Num           = RecallInfo(Ct, 'Num', Fx_P, 'Num')
                                    FP.Sldr_W        = RecallInfo(Ct, 'Width', Fx_P, 'Num')
                                    FP.Type          = RecallInfo(Ct, 'Type', Fx_P)
                                    FP.PosX          = RecallInfo(Ct, 'Pos X', Fx_P, 'Num')
                                    FP.PosY          = RecallInfo(Ct, 'Pos Y', Fx_P, 'Num')
                                    FP.Style         = RecallInfo(Ct, 'Style', Fx_P)
                                    FP.V_FontSize    = RecallInfo(Ct, 'Value Font Size', Fx_P, 'Num')
                                    FP.CustomLbl     = RecallInfo(Ct, 'Custom Label', Fx_P)
                                    if FP.CustomLbl == '' then FP.CustomLbl = nil end
                                    FP.FontSize     = RecallInfo(Ct, 'Font Size', Fx_P, 'Num')
                                    FP.Height       = RecallInfo(Ct, 'Slider Height', Fx_P, 'Num')
                                    FP.BgClr        = RecallInfo(Ct, 'BgClr', Fx_P, 'Num')
                                    FP.GrbClr       = RecallInfo(Ct, 'GrbClr', Fx_P, 'Num')
                                    FP.Lbl_Pos      = RecallInfo(Ct, 'Label Pos', Fx_P)
                                    FP.V_Pos        = RecallInfo(Ct, 'Value Pos', Fx_P)
                                    FP.Lbl_Clr      = RecallInfo(Ct, 'Lbl Clr', Fx_P, 'Num')
                                    FP.V_Clr        = RecallInfo(Ct, 'V Clr', Fx_P, 'Num')
                                    FP.DragDir      = RecallInfo(Ct, 'Drag Direction', Fx_P, 'Num')
                                    FP.Value_Thick  = RecallInfo(Ct, 'Value Thickness', Fx_P, 'Num')
                                    FP.V_Pos_X      = RecallInfo(Ct, 'Value Free Pos X', Fx_P, 'Num')
                                    FP.V_Pos_Y      = RecallInfo(Ct, 'Value Free Pos Y', Fx_P, 'Num')
                                    FP.Lbl_Pos_X    = RecallInfo(Ct, 'Label Free Pos X', Fx_P, 'Num')
                                    FP.Lbl_Pos_Y    = RecallInfo(Ct, 'Label Free Pos Y', Fx_P, 'Num')
                                    FP.Switch_On_Clr= RecallInfo(Ct, 'Switch On Clr', Fx_P, 'Num')

                                    local path = RecallInfo(Ct, 'Custom Image', Fx_P)

                                    if path then
                                        FP.ImagePath = path
                                        FP.Style = 'Custom Image'
                                        FP.Image = r.ImGui_CreateImage(r.GetResourcePath() .. path)
                                        r.ImGui_Attach(ctx, FP.Image)
                                    end


                                    FP.ConditionPrm = RecallInfo(Ct, 'Condition Param', '\n'..Fx_P , 'Num', '|')
                                    for i = 2, 5, 1 do
                                        FP['ConditionPrm' .. i] = RecallInfo(Ct, 'Condition Param' .. i, Fx_P, 'Num', '|')
                                    end
                                    FP.V_Round = RecallInfo(Ct, 'Decimal Rounding', Fx_P, 'Num')
                                    FP.ValToNoteL = RecallInfo(Ct, 'Value to Note Length', Fx_P, 'Num')
                                    FP.SwitchType = RecallInfo(Ct, 'Switch type', Fx_P, 'Num')
                                    FP.SwitchBaseV = RecallInfo(Ct, 'Switch Base Value', Fx_P, 'Num')
                                    FP.SwitchTargV = RecallInfo(Ct, 'Switch Target Value', Fx_P, 'Num')



                                    if FP.ConditionPrm then
                                        FP.ConditionPrm_V = RecallIntoTable(Ct, Fx_P .. '. Condition Param = %d+|1=', Fx_P, nil)
                                        FP.ConditionPrm_V_Norm = RecallIntoTable(Ct, Fx_P .. '. Condition Param Norm = |1=', Fx_P,'Num')
                                    end
                                    for i = 2, 5, 1 do
                                        FP['ConditionPrm_V' .. i] = RecallIntoTable(Ct, Fx_P ..
                                            '. Condition Param' .. i .. ' = %d+|1=', Fx_P, nil)
                                        FP['ConditionPrm_V_Norm' .. i] = RecallIntoTable(Ct,
                                            Fx_P .. '. Condition Param Norm' .. i .. ' = |1=', Fx_P, 'Num')
                                    end

                                    if Prm.InstAdded[FxGUID] ~= true then
                                        StoreNewParam(FxGUID, FP.Name, FP.Num, FX_Idx, 'Not Deletable', 'AddingFromExtState',
                                            Fx_P, FX_Idx, TrkID)
                                        r.SetProjExtState(0, 'FX Devices', 'FX' .. FxGUID .. 'Params Added', 'true')
                                    end

                                    FP.ManualValues = RecallIntoTable(Ct, Fx_P .. '. Manual V:1=', Fx_P, 'Num')
                                    FP.ManualValuesFormat = RecallIntoTable(Ct, Fx_P .. '. Manual Val format:1=', Fx_P)



                                    local DrawNum = RecallInfo(Ct, 'Number of attached drawings', Fx_P, 'Num')
                                    if DrawNum then
                                        FP.Draw = FP.Draw or {}
                                        for D = 1, DrawNum, 1 do
                                            FP.Draw[D] = FP.Draw[D] or {}
                                            local d = FP.Draw[D]

                                            local function RC(name, type)
                                                return RecallInfo(Ct, 'Draw Item ' .. D .. ': ' .. name, Fx_P, type)
                                            end

                                            d.Type = RC('Type')
                                            d.X_Offset = RC('X Offset', 'Num')
                                            d.X_Offset_VA = RC('X Offset Value Affect', 'Num')
                                            d.X_Offset_VA_GR = RC('X Offset Value Affect GR', 'Num')
                                            d.Y_Offset = RC('Y offset', 'Num')
                                            d.Y_Offset_VA = RC('Y Offset Value Affect', 'Num')
                                            d.Y_Offset_VA_GR = RC('Y Offset Value Affect GR', 'Num')
                                            d.Width = RC('Width', 'Num')
                                            d.Width_VA = RC('Width Value Affect', 'Num')
                                            d.Width_VA_GR = RC('Width Value Affect GR', 'Num')
                                            d.Clr = RC('Color', 'Num')
                                            d.Clr_VA = RC('Color_VA', 'Num')

                                            d.FillClr = RC('Fill Color', 'Num')
                                            d.Angle_Min = RC('Angle Min', 'Num')
                                            d.Angle_Max = RC('Angle Max', 'Num')
                                            d.Rad_In = RC('Radius Inner', 'Num')
                                            d.Rad_Out = RC('Radius Outer', 'Num')
                                            d.Height = RC('Height', 'Num')
                                            d.Height_VA = RC('Height_VA', 'Num')
                                            d.Height_VA_GR = RC('Height_VA GR', 'Num')
                                            d.Round = RC('Round', 'Num')
                                            d.Thick = RC('Thick', 'Num')
                                            d.Repeat = RC('Repeat', 'Num')
                                            d.Repeat_VA = RC('Repeat_VA', 'Num')
                                            d.Repeat_VA_GR = RC('Repeat_VA GR', 'Num')
                                            d.Y_Repeat = RC('Y_Repeat', 'Num')
                                            d.Y_Repeat_VA = RC('Y_Repeat_VA', 'Num')
                                            d.Y_Repeat_VA_GR = RC('Y_Repeat_VA GR', 'Num')
                                            d.Gap = RC('Gap', 'Num')
                                            d.Gap_VA = RC('Gap_VA', 'Num')
                                            d.Gap_VA_GR = RC('Gap_VA GR', 'Num')

                                            d.X_Gap = RC('X_Gap', 'Num')
                                            d.X_Gap_VA = RC('X_Gap_VA', 'Num')
                                            d.X_Gap_VA_GR = RC('X_Gap_VA GR', 'Num')
                                            d.Y_Gap = RC('Y_Gap', 'Num')
                                            d.Y_Gap_VA = RC('Y_Gap_VA', 'Num')
                                            d.Y_Gap_VA_GR = RC('Y_Gap_VA GR', 'Num')
                                            d.RPT_Clr = RC('RPT_Clr', 'Num')
                                            

                                            local path = RC('Image_Path')
                                            if path then
                                                d.FilePath = path

                                                d.Image = r.ImGui_CreateImage(r.GetResourcePath() .. d.FilePath)
                                                r.ImGui_Attach(ctx, d.Image)
                                            end
                                        end
                                    end
                                end
                                GetProjExt_FxNameNum(FxGUID)
                                Prm.InstAdded[FxGUID] = true
                            end
                        else ---- if no editings has been saved to extstate
                            if FX[FxGUID] then
                                for Fx_P = 1, #FX[FxGUID] or 0, 1 do
                                    local ID = FxGUID .. Fx_P
                                    local FP = FX[FxGUID][Fx_P]
                                    if FX[FxGUID][Fx_P] then
                                        FP.Name         = nil
                                        FP.Num          = nil
                                        FP.Sldr_W       = nil
                                        FP.Type         = nil
                                        FP.PosX         = nil
                                        FP.PosY         = nil
                                        FP.Style        = nil
                                        FP.V_FontSize   = nil
                                        FP.CustomLbl    = nil
                                        FP.FontSize     = nil
                                        FP.Sldr_H       = nil
                                        FP.BgClr        = nil
                                        FP.GrbClr       = nil
                                        FP.Lbl_Pos      = nil
                                        FP.V_Pos        = nil
                                        FP.Lbl_Clr      = nil
                                        FP.V_Clr        = nil
                                        FP.DragDir      = nil
                                        FP.ConditionPrm = nil
                                        FP.V_Round      = nil
                                        FP.ValToNoteL   = nil
                                        FP.SwitchType   = nil
                                        FP.SwitchBaseV  = nil
                                        FP.SwitchTargV  = nil
                                    end
                                end
                                GetProjExt_FxNameNum(FxGUID)
                            end
                        end

                        ------------------------------------- Drawings -------------------------------------------------
                        if file then
                            local All = file:read('*a')

                            local Top = tablefind(Line, '========== Drawings ==========') or nil


                            if Top then
                                local Ct = Content

                                
                                local DrawInst = RecallGlobInfo(Ct, 'Total Number of Drawings = ', 'Num')


                                if DrawInst then
                                    if DrawInst > 0 then
                                        T.Draw = T.Draw or {}
                                        T.Draw.Df_EdgeRound = get_aftr_Equal_Num(Line[Top + 1])
                                    end
                                end
                                T.Draw = T.Draw or {}

                                for i = 1, DrawInst or 0, 1 do
                                    --D[i] = D[i] or {}
                                    local function LN(num)
                                        return Line[Top + 5 + ((i - 1) * 9) + num]
                                    end
                                    local ID = FX_Name .. i
                                    T.Draw[i] = T.Draw[i] or {}
                                    local D = T.Draw[i]

                                    D.Type = RecallInfo(Ct, 'Type', 'D' .. i, Type, untilwhere)
                                    D.L = RecallInfo(Ct, 'Left', 'D' .. i, 'Num')
                                    D.R = RecallInfo(Ct, 'Right', 'D' .. i, 'Num')
                                    D.T = RecallInfo(Ct, 'Top', 'D' .. i, 'Num')
                                    D.B = RecallInfo(Ct, 'Bottom', 'D' .. i, 'Num')
                                    D.clr = RecallInfo(Ct, 'Color', 'D' .. i, 'Num')
                                    D.Txt = RecallInfo(Ct, 'Text', 'D' .. i)
                                    D.Txt = RecallInfo(Ct, 'Text', 'D' .. i)
                                    D.FilePath = RecallInfo(Ct, 'ImagePath', 'D' .. i)
                                    D.KeepImgRatio = RecallInfo(Ct, 'KeepImgRatio', 'D' .. i, 'Bool')

                                    if D.FilePath then
                                        D.Image = r.ImGui_CreateImage(D.FilePath)
                                        r.ImGui_Attach(ctx, D.Image)
                                    end



                                    --[[ Draw[FX_Name].Type[i] = get_aftr_Equal(LN(1))
                                            D.L[i] =   get_aftr_Equal_Num(LN(2))
                                            D.R[i] =   get_aftr_Equal_Num(LN(3))
                                            D.T[i] =   get_aftr_Equal_Num(LN(4))
                                            D.B[i] =   get_aftr_Equal_Num(LN(5))
                                            D.clr[i] = get_aftr_Equal_Num(LN(6))
                                            D.Txt[i] = get_aftr_Equal(LN(7)) ]]
                                end
                            end
                        end
                        GetInfo(FxGUID, FX_Idx)
                    end
                end
            end




            local rv, FX_Count = r.TrackFX_GetNamedConfigParm( LT_Track, FX_Idx, 'container_count')
           
            if rv  then     -- if iterated fx is a container
                local Upcoming_Container
                if TREE[FX_Idx+1] then 
                    if TREE[FX_Idx+1].children then 

                        local function get_Container_Info ()
                            
                            for i, v in ipairs(Upcoming_Container or TREE[FX_Idx+1].children) do 

                                local FX_Id = v.addr_fxid
                                local GUID = v.GUID
                                GetInfo(GUID, FX_Id)
                                if v.children then 
                                    Upcoming_Container = v.children
                                    get_Container_Info ()

                                end
                                
                                
                            end
                        end

                        
                            get_Container_Info ()

                        
                    end
                end

            else 
                GetInfo(FxGUID,FX_Idx)
            end
        end
    end
end

---@param FxGUID string
---@param P_Name string
---@param P_Num number
---@param FX_Num number ---TODO this is unused
---@param IsDeletable boolean
---@param AddingFromExtState? "AddingFromExtState"
---@param Fx_P? integer|string ---TODO not sure about this
---@param FX_Idx? integer
---@param TrkID? string
function StoreNewParam(FxGUID, P_Name, P_Num, FX_Num, IsDeletable, AddingFromExtState, Fx_P, FX_Idx, TrkID)
    TrkID = TrkID or r.GetTrackGUID(r.GetLastTouchedTrack())

    --Trk.Prm.Inst[TrkID] = (Trk.Prm.Inst[TrkID] or 0 )+1
    --r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: Trk Prm Count',Trk.Prm.Inst[TrkID], true )

    local P



    if AddingFromExtState == 'AddingFromExtState' then
        P = Fx_P
    else
        FX[FxGUID] = FX[FxGUID] or {}
        -- local Index = #FX[FxGUID] or 0
        table.insert(FX[FxGUID], Fx_P)
        FX.Prm.Count[FxGUID] = (FX.Prm.Count[FxGUID] or 0) + 1
        P = #FX[FxGUID] + 1
    end


    r.SetProjExtState(0, 'FX Devices', 'Prm Count' .. FxGUID, P)
    r.GetSetMediaTrackInfo_String(LT_Track, 'P_EXT: FXs Prm Count' .. FxGUID, P, true)


    FX[FxGUID][P] = FX[FxGUID][P] or {}
    FX[FxGUID][P].Num = P_Num
    FX[FxGUID][P].Name = P_Name
    FX[FxGUID][P].Deletable = IsDeletable


    r.SetProjExtState(0, 'FX Devices', 'FX' .. P .. 'Name' .. FxGUID, P_Name)
    r.SetProjExtState(0, 'FX Devices', 'FX' .. P .. 'Num' .. FxGUID, P_Num)
    table.insert(Prm.Num, P_Num)



    if AddingFromExtState == 'AddingFromExtState' then
        FX[FxGUID][P].V = r.TrackFX_GetParamNormalized(LT_Track, FX_Idx, P_Num)
    else
        local rv, step, smallstep, largestep, istoggle = r.TrackFX_GetParameterStepSizes(LT_Track,
            LT_FX_Number,
            LT_ParamNum)
        if rv then --[[ if the param is a switch ]] end
        FX[FxGUID][P].V = r.TrackFX_GetParamNormalized(LT_Track, LT_FX_Number, LT_ParamNum)
    end
    return P
end

---TODO I think this is unused
---@param get? "get"
---@param FxGUID string
---@param FX_Idx integer
---@param Fx_P number
---@param WhichPrm integer
function GetParamOptions(get, FxGUID, FX_Idx, Fx_P, WhichPrm)
    local OP = FX.Prm.Options; local OPs, V

    if get == 'get' then OP[FxGUID] = nil end

    if not OP[FxGUID] then OP[FxGUID] = {} end
    if not OP[FxGUID][Fx_P] then
        OP[FxGUID][Fx_P] = {};

        OP[FxGUID][Fx_P] = { V = {} }
    end
    OPs = OP[FxGUID][Fx_P]
    V = OP[FxGUID][Fx_P].V


    local OrigV = r.TrackFX_GetParamNormalized(LT_Track, FX_Idx, WhichPrm)



    if #OPs == 0 then
        for i = 0, 1, 0.01 do
            r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, WhichPrm, i)
            local _, buf = r.TrackFX_GetFormattedParamValue(LT_Track, FX_Idx, WhichPrm)
            if not Value then
                Value = buf; OPs[1] = buf
                V[1] = i
            end
            if Value ~= buf then
                OPs[#OPs + 1]            = buf; V[#V + 1] = i;
                local L1                 = r.ImGui_CalcTextSize(ctx, buf); local L2 = r.ImGui_CalcTextSize(ctx, Value)
                FX[FxGUID][Fx_P].Combo_W = math.max(L1, L2)
                Value                    = buf
            end
        end
    end
    r.TrackFX_SetParamNormalized(LT_Track, FX_Idx, WhichPrm, OrigV)
end

---@param Macro string|number
---@param AddIndicator boolean
---@param McroV number
---@param FxGUID string
---@param F_Tp number
---@param Sldr_Width number
---@param P_V number
---@param Vertical? "Vert"
---@param FP FX_P
---@param offset number
function DrawModLines(Macro, AddIndicator, McroV, FxGUID, F_Tp, Sldr_Width, P_V, Vertical, FP, offset)
    local drawlist = r.ImGui_GetWindowDrawList(ctx) --[[add+ here]]
    local SldrGrabPos
    local L, T = r.ImGui_GetItemRectMin(ctx); local R, B = r.ImGui_GetItemRectMax(ctx)
    local SizeX, SizeY = r.ImGui_GetItemRectSize(ctx)
    MacroModLineOffset = 0

    
    
    local ModAmt , BipOfs  = FP.ModAMT[Macro] , 0 
    if FP then 
        FP.ModBipolar = FP.ModBipolar or {}
        if FP.ModBipolar[Macro] then 
            ModAmt = FP.ModAMT[Macro] 
            BipOfs =  - FP.ModAMT[Macro]
        end
    end 

    if Vertical ~= 'Vert' then
        PosX_End_Of_Slider = (Sldr_Width) + L
        SldrGrabPos = SizeX * P_V
        SliderCurPos = L + SldrGrabPos 
        SliderModPos = SliderCurPos + ((ModAmt * Sldr_Width) or 0)
        SliderModPos = SetMinMax(SliderModPos, L, PosX_End_Of_Slider)
    elseif Vertical == 'Vert' then
        PosX_End_Of_Slider = T
        SldrGrabPos = (SizeY) * (P_V)
        SliderCurPos = B - SldrGrabPos
        SliderModPos = SliderCurPos - ((ModAmt * Sldr_Width) or 0)
        SliderModPos = SetMinMax(SliderModPos, T, B)
    end


    drawlist = r.ImGui_GetWindowDrawList(ctx)
    -- r.ImGui_DrawList_AddLine(drawlist,SliderCurPos,T,SliderModPos or 1,T, EightColors.HighSat_MidBright[Macro],3)


    local Midsat, MidBright = EightColors.MidSat[Macro], EightColors.HighSat_MidBright[Macro]
    if FP.ModBypass == Macro then Midsat, MidBright = 0x88888866, 0xaaaaaa66 end


    if AddIndicator and FP.ModAMT[Macro] ~= 0 then
        local ModPosWithAmt
        local M = Trk[TrkID].Mod[Macro]
        local MOD = McroV
        if M.Type == 'env' or M.Type == 'Step' or M.Type == 'Follower' or M.Type == 'LFO' then
            r.gmem_attach('ParamValues')
            MOD = math.abs(SetMinMax(r.gmem_read(100 + Macro) / 127, -1, 1))
        end
        

        if MOD then 

            local ModAmt = ModAmt 
            if BipOfs~= 0  then  ModAmt = ModAmt*2  end 
            if Vertical == 'Vert'   then
                ModPosWithAmt = math.max(SliderCurPos - (MOD * Sldr_Width * ModAmt) - BipOfs*Sldr_Width or 0, PosX_End_Of_Slider)
                r.ImGui_DrawList_AddRectFilled(drawlist, L, SliderCurPos, R, ModPosWithAmt or SliderCurPos, Midsat,Rounding)
            else
                ModPosWithAmt = math.min(SliderCurPos + (MOD * Sldr_Width * ModAmt) + BipOfs*Sldr_Width or 0, PosX_End_Of_Slider)
                r.ImGui_DrawList_AddRectFilled(drawlist, SliderCurPos, T, (ModPosWithAmt or SliderCurPos or 0), B,Midsat, Rounding)
            end
        end
    end

    --- mod range indicator line
    if Vertical == 'Vert' then
        local SliderCurPos = SliderCurPos - BipOfs * Sldr_Width
        r.ImGui_DrawList_AddRectFilled(drawlist, L - offset, SliderCurPos, L - offset, SliderModPos, MidBright,Rounding)
    else
        local SliderCurPos = SliderCurPos + BipOfs * Sldr_Width
        r.ImGui_DrawList_AddLine(drawlist, SliderCurPos, T - offset, SliderModPos or 1, T - offset,MidBright, 2)
    end
end

--r.ImGui_SetNextWindowDockID(ctx, -1)   ---Dock the script
---@param ctx ImGui_Context
---@param img ImGui_Image
---@param angle any
---@param w any
---@param h any
---@param x any
---@param y any
function ImageAngle(ctx, img, angle, w, h, x, y)
    if not x and not y then x, y = r.ImGui_GetCursorScreenPos(ctx) end
    local cx, cy = x + (w / 2), y + (h / 2)
    local rotate = function(x, y)
        x, y = x - cx, y - cy
        return (x * math.cos(angle) - y * math.sin(angle)) + cx,
            (x * math.sin(angle) + y * math.cos(angle)) + cy
    end
    local dl = r.ImGui_GetWindowDrawList(ctx)
    local p1_x, p1_y = rotate(x, y)
    local p2_x, p2_y = rotate(x + w, y)
    local p3_x, p3_y = rotate(x + w, y + h)
    local p4_x, p4_y = rotate(x, y + h)
    r.ImGui_DrawList_AddImageQuad(dl, img,
        p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y)
    --r.ImGui_Dummy(ctx, w, h)
end

---@param FX_Name string
---@param ID string ---TODO this param is not used
---@param FxGUID string
function SaveLayoutEditings(FX_Name, FX_Idx, FxGUID)
    local dir_path = ConcatPath(r.GetResourcePath(), 'Scripts', 'FX Devices', 'BryanChi_FX_Devices', 'src', 'FX Layouts')
    --local _, FX_Name = r.TrackFX_GetFXName(LT_Track, FX_Idx)
    local FX_Name = ChangeFX_Name(FX_Name)
    local file_path = ConcatPath(dir_path, FX_Name .. '.ini')


    r.RecursiveCreateDirectory(dir_path, 0)

    local file = io.open(file_path, 'w')
    if file then
        local function write(Name, Value)
            file:write(Name, ' = ', Value or '', '\n')
        end


        file:write('FX global settings', '\n\n')
        write('Edge Rounding', FX[FxGUID].Round)   -- 2
        write('Grb Rounding', FX[FxGUID].GrbRound) -- 3
        write('BgClr', FX[FxGUID].BgClr)           -- 4
        write('Window Width', FX[FxGUID].Width)    -- 5
        write('Title Width', FX[FxGUID].TitleWidth)
        write('Title Clr', FX[FxGUID].TitleClr)
        write('Custom Title', FX[FxGUID].CustomTitle)

        write('Param Instance', #FX[FxGUID]) -- 6

        file:write('\nParameter Specific Settings \n\n')

        for i, v in ipairs(FX[FxGUID]) do
            local Fx_P = i
            local FP = FX[FxGUID][i]
            if type(i) ~= 'number' and i then
                i = 1; FP = {}
            end
            local function write(Name, Value)
                if Value then
                    file:write(i .. '. ' .. Name, ' = ', Value or '', '\n')
                end
            end


            file:write('\n-----------------Prm ', i, '-----------------\n')
            write('Name', FP.Name)
            write('Num', FP.Num)
            write('Width', FP.Sldr_W)
            write('Type', FP.Type or FX.Def_Type[FxGUID] or 'Slider')
            write('Pos X', FP.PosX)
            write('Pos Y', FP.PosY)
            write('Style', FP.Style)
            write('Value Font Size', FP.V_FontSize)
            write('Custom Label', FP.CustomLbl)
            write('Font Size', FP.FontSize)
            write('Slider Height', FP.Height)
            write('BgClr', FP.BgClr)
            write('GrbClr', FP.GrbClr)
            write('Label Pos', FP.Lbl_Pos)
            write('Value Pos', FP.V_Pos)
            write('Lbl Clr', FP.Lbl_Clr)
            write('V Clr', FP.V_Clr)
            write('Switch On Clr', FP.Switch_On_Clr)
            write('Drag Direction', FP.DragDir)
            write('Value Thickness', FP.Value_Thick)
            write('Value Free Pos X', FP.V_Pos_X)
            write('Value Free Pos Y', FP.V_Pos_Y)
            write('Label Free Pos X', FP.Lbl_Pos_X)
            write('Label Free Pos Y', FP.Lbl_Pos_Y)
            write('Custom Image', FP.ImagePath)
            




            if FP.ConditionPrm_V then
                file:write(i .. '. Condition Param = ', FP.ConditionPrm or '')

                for i, v in pairs(FP.ConditionPrm_V) do
                    file:write('|', i, '=', v or '')
                    --write('Condition Params Value'..i, v)
                end
                file:write('|\n')
            else
                file:write('\n')
            end

            if FP.ConditionPrm_V_Norm then
                file:write(i .. '. Condition Param Norm = ')
                for i, v in ipairs(FP.ConditionPrm_V_Norm) do
                    file:write('|', i, '=', v or '')
                end
                file:write('|\n')
            else
                file:write('\n')
            end

            for I = 2, 5, 1 do
                if FP['ConditionPrm_V' .. I] then
                    file:write(i .. '. Condition Param' .. I .. ' = ', FP['ConditionPrm' .. I] or '')

                    if FP['ConditionPrm_V' .. I] then
                        for i, v in pairs(FP['ConditionPrm_V' .. I]) do
                            file:write('|', i, '=', v or '')
                            --write('Condition Params Value'..i, v)
                        end
                        file:write('|\n')
                    else
                        file:write('\n')
                    end

                    if FP['ConditionPrm_V_Norm' .. I] then
                        file:write(i .. '. Condition Param Norm' .. I .. ' = ')
                        for i, v in ipairs(FP['ConditionPrm_V_Norm' .. I]) do
                            file:write('|', i, '=', v or '')
                        end
                        file:write('|\n')
                    else
                        file:write('\n')
                    end
                end
            end

            write('Decimal Rounding', FP.V_Round)
            write('Value to Note Length', FP.ValToNoteL)
            write('Switch type', FP.SwitchType)
            write('Switch Base Value', FP.SwitchBaseV)
            write('Switch Target Value', FP.SwitchTargV)


            if FP.ManualValues then
                if FP.ManualValues[1] then
                    file:write(i .. '. Manual V:')
                    for i, V in ipairs(FP.ManualValues) do
                        file:write(i, '=', V, '|')
                    end
                    file:write('\n')
                    file:write(i .. '. Manual Val format:')
                    for i, V in ipairs(FP.ManualValuesFormat) do
                        file:write(i, '=', V, '|')
                    end
                    file:write('\n')
                end
            end
            if FP.Draw then
                write('Number of attached drawings', #FP.Draw)
                for D, v in ipairs(FP.Draw) do
                    local function WRITE(name, val)
                        write('Draw Item ' .. D .. ': ' .. name, val)
                    end
                    WRITE('Type', v.Type)
                    WRITE('X Offset', v.X_Offset)
                    WRITE('X Offset Value Affect', v.X_Offset_VA)
                    WRITE('X Offset Value Affect GR', v.X_Offset_VA_GR)
                    WRITE('Y offset', v.Y_Offset)
                    WRITE('Y Offset Value Affect', v.Y_Offset_VA)
                    WRITE('Y Offset Value Affect GR', v.Y_Offset_VA_GR)
                    WRITE('Width', v.Width)
                    WRITE('Width Value Affect', v.Width_VA)
                    WRITE('Width Value Affect GR', v.Y_Offset_VA_GR)
                    WRITE('Color', v.Clr)
                    WRITE('Color_VA', v.Clr_VA)
                    WRITE('Fill Color', v.FillClr)
                    WRITE('Angle Min', v.Angle_Min)
                    WRITE('Angle Max', v.Angle_Max)
                    WRITE('Radius Inner', v.Rad_In)
                    WRITE('Radius Outer', v.Rad_Out)
                    WRITE('Thick', v.Thick)
                    WRITE('Height', v.Height)
                    WRITE('Height_VA', v.Height_VA)
                    WRITE('Height_VA GR', v.Height_VA_GR)
                    WRITE('Round', v.Round)
                    WRITE('Repeat', v.Repeat)
                    WRITE('Repeat_VA', v.Repeat_VA)
                    WRITE('Repeat_VA GR', v.Repeat_VA_GR)
                    WRITE('Y_Repeat', v.Y_Repeat)
                    WRITE('Y_Repeat_VA', v.Y_Repeat_VA)
                    WRITE('Y_Repeat_VA GR', v.Y_Repeat_VA_GR)
                    WRITE('Gap', v.Gap)
                    WRITE('Gap_VA', v.Gap_VA)
                    WRITE('Gap_VA GR', v.Gap_VA_GR)
                    WRITE('X_Gap', v.X_Gap)
                    WRITE('X_Gap_VA', v.X_Gap_VA)
                    WRITE('X_Gap_VA GR', v.X_Gap_VA_GR)
                    WRITE('Y_Gap', v.Y_Gap)
                    WRITE('Y_Gap_VA', v.Y_Gap_VA)
                    WRITE('Y_Gap_VA GR', v.Y_Gap_VA_GR)
                    WRITE('RPT_Clr', v.RPT_Clr)
                    WRITE('Image_Path', v.FilePath)
                end
            end
        end
        file:close()
    end

    r.SetProjExtState(0, 'FX Devices', 'Prm Count' .. FxGUID, #FX[FxGUID])
    --[[ for i, v in pairs (FX[FxGUID]) do
        local Fx_P=i
        local FP = FX[FxGUID][i]

        if type(i)~= 'number' and i then i = 1 ; FP={} end

        r.SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P ..'s Param Name', FP.Name or '', true )
        r.SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P ..'s Param Num', FP.Num or '', true )

        r.SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P ..'s Width', FP.Sldr_W or  '' , true)
        r.SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Type', FP.Type or '', true)


        if FP.PosX then r. SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Pos X'   , FP.PosX, true) else r.DeleteExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Pos X',true) end
        if FP.PosY  then r. SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Pos Y'   , FP.PosY, true)else r.DeleteExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Pos Y',true ) end
        if FP.Style then r.SetExtState('FX Devices - '..FX_Name,  'Prm'..Fx_P..'s Style'   ,FP.Style,  true)else r.DeleteExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Style', true ) end
        if FP.V_FontSize then r.SetExtState('FX Devices - '..FX_Name,  'Prm'..Fx_P..'s V_FontSize'   ,FP.V_FontSize,  true)else r.DeleteExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s V_FontSize', true ) end
        if FP.CustomLbl then r. SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Custom Label'   , FP.CustomLbl, true) else r.DeleteExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Custom Label', true ) end
        if FP.FontSize then r. SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Font Size'   , FP.FontSize, true) else r.DeleteExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Font Size', true )  end
        if FP.Sldr_H then  r. SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Slider Height'   , FP.Sldr_H, true)else r.DeleteExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Slider Height', true ) end
        if FP.BgClr then  r. SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s BgClr'   , FP.BgClr, true) else r.DeleteExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s BgClr', true ) end
        if FP.GrbClr then  r. SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s GrbClr'   , FP.GrbClr, true) else r.DeleteExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s GrbClr', true )        end

        if FP.Lbl_Pos then r. SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Label Pos'   , FP.Lbl_Pos, true)else r.DeleteExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Label Pos', true )    end
        if FP.V_Pos then r. SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Value Pos'   , FP.V_Pos, true) else r.DeleteExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Value Pos', true )   end
        if FP.Lbl_Clr then r. SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Lbl Clr'   , FP.Lbl_Clr, true)else r.DeleteExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Lbl Clr', true )   end
        if FP.V_Clr then r. SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s V Clr'   , FP.V_Clr, true) else r.DeleteExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s V Clr', true ) end
        if FP.DragDir then r. SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Drag Direction'   , FP.DragDir, true)else r.DeleteExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Drag Direction', true ) end
        if FP.ConditionPrm then r.SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Condition Param'   , FP.ConditionPrm, true) else r.DeleteExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Condition Param', true ) end
        if FP.ConditionPrm_V then
            for i, v in pairs(FP.ConditionPrm_V) do
                r.SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Condition Params Value'..i  , v, true)
            end
            r.SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Condition Params Value How Many'   , #FP.ConditionPrm_V, true)

        end
        if FP.V_Round then r. SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Decimal Rounding'   , FP.V_Round, true) end
        if FP.ValToNoteL~=nil then r.SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Value to Note Length'   , tostring(FP.ValToNoteL), true) end
        if FP.SwitchType then r.SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Switch type'   , FP.SwitchType, true) end
        if FP.SwitchBaseV then r.SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Switch Base Value'   , FP.SwitchBaseV, true) end
        if FP.SwitchTargV then r.SetExtState('FX Devices - '..FX_Name, 'Prm'..Fx_P..'s Switch Target Value'   , FP.SwitchTargV, true) end


    end ]]


    SaveDrawings(FX_Idx, FxGUID)
end

---@param FxGUID string
---@param Fx_P number
---@param ItemWidth number
---@param ItemType 'V-Slider' | 'Sldr' |'Drag' |'Selection'
---@param PosX number
---@param PosY number
function MakeItemEditable(FxGUID, Fx_P, ItemWidth, ItemType, PosX, PosY)
    if FX.LayEdit == FxGUID and Draw.DrawMode[FxGUID] ~= true and Mods ~= Apl then
        local DeltaX, DeltaY = r.ImGui_GetMouseDelta(ctx); local MouseX, MouseY = r.ImGui_GetMousePos(ctx)

        WinDrawList = r.ImGui_GetWindowDrawList(ctx)
        local L, T = r.ImGui_GetItemRectMin(ctx); local w, h = r.ImGui_GetItemRectSize(ctx); local R = L + w; local B =
            T +
            h;
        r.ImGui_DrawList_AddRect(WinDrawList, L, T, R, B, 0x999999ff)



        for i, v in pairs(LE.Sel_Items) do
            if Fx_P == v then
                HighlightSelectedItem(0x66666644, 0xffffffff, 0, L, T, R, B, h, w, 5, 4)
                LE.SelectedItemType = ItemType
            end
        end





        --- if mouse is on an item
        if r.ImGui_IsWindowHovered(ctx, r.ImGui_HoveredFlags_RootAndChildWindows()) then
            if MouseX > L and MouseX < R - 5 and MouseY > T and MouseY < B then
                if LBtnRel and Max_L_MouseDownDuration < 0.1 and Mods == 0 then
                    LE.Sel_Items = {}
                    table.insert(LE.Sel_Items, Fx_P)
                end

                if IsLBtnClicked and Mods == 0 then
                    LE.SelectedItem = Fx_P
                elseif IsLBtnClicked and Mods == Shift then
                    local ClickOnSelItem, ClickedItmNum
                    for i, v in pairs(LE.Sel_Items) do
                        if v == Fx_P then
                            ClickedItmNum = i
                        else
                        end
                    end
                    if ClickedItmNum then
                        table.remove(LE.Sel_Items, ClickedItmNum)
                    else
                        table.insert(LE.Sel_Items,
                            Fx_P)
                    end
                end

                if IsLBtnClicked then
                    ClickOnAnyItem = true
                    FX[FxGUID][Fx_P].PosX = PosX
                    FX[FxGUID][Fx_P].PosY = PosY
                    if #LE.Sel_Items > 1 then
                        LE.ChangePos = LE.Sel_Items
                    else
                        LE.ChangePos = Fx_P
                    end
                end
            end
        end


        if LE.Sel_Items and not r.ImGui_IsAnyItemActive(ctx) then
            if r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_DownArrow()) and Mods == 0 then
                for i, v in ipairs(LE.Sel_Items) do
                    if v == Fx_P then FX[FxGUID][v].PosY = FX[FxGUID][v].PosY + LE.GridSize end
                end
            elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_UpArrow()) and Mods == 0 then
                for i, v in ipairs(LE.Sel_Items) do
                    if v == Fx_P then FX[FxGUID][v].PosY = FX[FxGUID][v].PosY - LE.GridSize end
                end
            elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_LeftArrow()) and Mods == 0 then
                for i, v in ipairs(LE.Sel_Items) do
                    if v == Fx_P then FX[FxGUID][v].PosX = FX[FxGUID][v].PosX - LE.GridSize end
                end
            elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_RightArrow()) and Mods == 0 then
                for i, v in ipairs(LE.Sel_Items) do
                    if v == Fx_P then FX[FxGUID][v].PosX = FX[FxGUID][v].PosX + LE.GridSize end
                end
            elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_DownArrow()) and Mods == Shift then
                for i, v in ipairs(LE.Sel_Items) do
                    if v == Fx_P then FX[FxGUID][v].PosY = FX[FxGUID][v].PosY + 1 end
                end
            elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_UpArrow()) and Mods == Shift then
                for i, v in ipairs(LE.Sel_Items) do
                    if v == Fx_P then FX[FxGUID][v].PosY = FX[FxGUID][v].PosY - 1 end
                end
            elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_LeftArrow()) and Mods == Shift then
                for i, v in ipairs(LE.Sel_Items) do
                    if v == Fx_P then FX[FxGUID][v].PosX = FX[FxGUID][v].PosX - 1 end
                end
            elseif r.ImGui_IsKeyPressed(ctx, r.ImGui_Key_RightArrow()) and Mods == Shift then
                for i, v in ipairs(LE.Sel_Items) do
                    if v == Fx_P then FX[FxGUID][v].PosX = FX[FxGUID][v].PosX + 1 end
                end
            end
        end

        -- Right Bound
        if ItemType == 'V-Slider' or ItemType == 'Sldr' or ItemType == 'Drag' or ItemType == 'Selection' then
            r.ImGui_DrawList_AddCircleFilled(WinDrawList, R, T + h / 2, 3, 0x999999dd)
            if MouseX > R - 5 and MouseX < R + 5 and MouseY > T and MouseY < B then
                r.ImGui_DrawList_AddCircleFilled(WinDrawList, R, T + h / 2, 4, 0xbbbbbbff)
                r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_ResizeEW())
                if IsLBtnClicked then
                    local ChangeSelectedItmBounds
                    for i, v in pairs(LE.Sel_Items) do
                        if v == Fx_P then
                            ChangeSelectedItmBounds = true
                        end
                    end
                    if ChangeSelectedItmBounds then
                        ChangePrmW = 'group'
                    else
                        ChangePrmW = Fx_P
                    end
                end
            end
        elseif ItemType == 'Knob' or (not ItemType and FX.Def_Type[FxGUID] == 'Knob') then
            r.ImGui_DrawList_AddCircleFilled(WinDrawList, R, B, 3, 0x999999dd)
            if MouseX > R - 5 and MouseX < R + 5 and MouseY > B - 5 and MouseY < B + 3 then
                r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_ResizeNWSE())
                r.ImGui_DrawList_AddCircleFilled(WinDrawList, R, B, 4, 0xbbbbbbff)
                if IsLBtnClicked then
                    local ChangeSelItmRadius
                    for i, v in pairs(LE.Sel_Items) do
                        if v == Fx_P then ChangeSelItmRadius = true end
                    end
                    if ChangeSelItmRadius then LE.ChangeRadius = 'Group' else LE.ChangeRadius = Fx_P end
                end
            end
        end




        function ChangeParamWidth(Fx_P)
            r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_ResizeEW())
            r.ImGui_DrawList_AddCircleFilled(WinDrawList, R, T + h / 2, 3, 0x444444ff)
            local MsDragDeltaX, MsDragDeltaY = r.ImGui_GetMouseDragDelta(ctx); local Dx, Dy = r.ImGui_GetMouseDelta(
                ctx)

            if ItemWidth == nil then
                if ItemType == 'Sldr' or ItemType == 'Drag' then
                    ItemWidth = 160
                elseif ItemType == 'Selection' then
                    ItemWidth = FX[FxGUID][Fx_P].Combo_W
                elseif ItemType == 'Switch' then
                    ItemWidth = FX[FxGUID][Fx_P].Switch_W
                elseif ItemType == 'Knob' then
                    ItemWidth = Df.KnobRadius
                elseif ItemType == 'V-Slider' then
                    ItemWidth = 15
                end
            elseif ItemWidth < LE.GridSize and ItemType ~= 'V-Slider' then
                ItemWidth = LE.GridSize
            elseif ItemWidth < 5 and ItemType == 'V-Slider' then
                ItemWidth = 4
            end

            if Mods == 0 then ItemWidth = ItemWidth + Dx end

            if ItemType == 'Sldr' or ItemType == 'V-Slider' or ItemType == 'Drag' or ItemType == 'Selection' or ItemType == 'Switch' then
                FX[FxGUID][Fx_P].Sldr_W = ItemWidth
            end
            if LBtnRel and ChangePrmW == Fx_P then
                FX[FxGUID][Fx_P].Sldr_W = roundUp(FX[FxGUID][Fx_P].Sldr_W, LE
                    .GridSize)
            end
            if LBtnRel then ChangePrmW = nil end
            AdjustPrmWidth = true
        end

        function ChangeKnobRadius(Fx_P)
            r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_ResizeNWSE())
            r.ImGui_DrawList_AddCircleFilled(WinDrawList, R, B, 3, 0x444444ff)
            local Dx, Dy = r.ImGui_GetMouseDelta(ctx)
            if not FX[FxGUID][Fx_P].Sldr_W then FX[FxGUID][Fx_P].Sldr_W = Df.KnobRadius end
            local DiagDrag = (Dx + Dy) / 2
            if Mods == 0 then
                FX[FxGUID][Fx_P].Sldr_W = FX[FxGUID][Fx_P].Sldr_W + DiagDrag;
            end
            if LBtnRel and LE.ChangeRaius == Fx_P then
                FX[FxGUID][Fx_P].Sldr_W = roundUp(FX[FxGUID][Fx_P].Sldr_W,
                    LE.GridSize / 2)
            end
            if LBtnRel then LE.ChangeRadius = nil end
            ClickOnAnyItem = true
            FX[FxGUID][Fx_P].Sldr_W = math.max(FX[FxGUID][Fx_P].Sldr_W, 10)
        end

        if LE.ChangeRadius == Fx_P then
            ChangeKnobRadius(Fx_P)
        elseif LE.ChangeRadius == 'Group' then
            for i, v in pairs(LE.Sel_Items) do
                if v == Fx_P then
                    ChangeKnobRadius(v)
                end
            end
        end


        if ChangePrmW == 'group' then
            for i, v in pairs(LE.Sel_Items) do
                if v == Fx_P then
                    ChangeParamWidth(v)
                end
            end
        elseif ChangePrmW == Fx_P then
            ChangeParamWidth(Fx_P)
        end



        function ChangeItmPos()
            if LBtnDrag then
                HintMessage = 'Ctrl = Lock Y Axis | Alt = Lock X Axis | Shift = Disable grid snapping '
                local Dx, Dy = r.ImGui_GetMouseDelta(ctx)
                if Mods == Ctrl or Mods == Ctrl + Shift then
                    Dx = 0
                elseif Mods == Alt or Mods == Alt + Shift then
                    Dy = 0
                end
                r.ImGui_SetMouseCursor(ctx, r.ImGui_MouseCursor_ResizeAll())
                FX[FxGUID][Fx_P].PosX = FX[FxGUID][Fx_P].PosX or PosX
                FX[FxGUID][Fx_P].PosY = FX[FxGUID][Fx_P].PosY or PosY
                FX[FxGUID][Fx_P].PosX = FX[FxGUID][Fx_P].PosX + Dx; FX[FxGUID][Fx_P].PosY = FX[FxGUID][Fx_P].PosY +
                    Dy
                AddGuideLines(0xffffff44, L, T, R, B)
            end
        end

        if LE.ChangePos == Fx_P then
            ChangeItmPos()
        elseif LBtnDrag and type(LE.ChangePos) == 'table' then
            for i, v in pairs(LE.ChangePos) do
                if v == Fx_P then
                    ChangeItmPos()
                end
            end
        end

        if LBtnRel and LE.ChangePos == Fx_P and Max_L_MouseDownDuration > 0.1 then
            if (Mods ~= Shift and Mods ~= Shift + Ctrl and Mods ~= Shift + Alt) and FX[FxGUID][Fx_P].PosX and FX[FxGUID][Fx_P].PosY then
                FX[FxGUID][Fx_P].PosX = SetMinMax(roundUp(FX[FxGUID][Fx_P].PosX, LE.GridSize), 0,
                    Win_W - (FX[FxGUID][Fx_P].Sldr_W or 15))
                FX[FxGUID][Fx_P].PosY = SetMinMax(roundUp(FX[FxGUID][Fx_P].PosY, LE.GridSize), 0, 220 - 10)
            end
        end
        if LBtnRel then
            LE.ChangePos = nil
        end
    end
end

---@param Clr any
---@param L number
---@param T number
---@param R number
---@param B number
function AddGuideLines(Clr, L, T, R, B)
    r.ImGui_DrawList_AddLine(Glob.FDL, L, T, L - 9999, T, Clr)
    r.ImGui_DrawList_AddLine(Glob.FDL, R, T, R + 9999, T, Clr)
    r.ImGui_DrawList_AddLine(Glob.FDL, L, B, L - 9999, B, Clr)
    r.ImGui_DrawList_AddLine(Glob.FDL, R, B, R + 9999, B, Clr)
    r.ImGui_DrawList_AddLine(Glob.FDL, L, T, L, T - 9999, Clr)
    r.ImGui_DrawList_AddLine(Glob.FDL, L, B, L, B + 9999, Clr)
    r.ImGui_DrawList_AddLine(Glob.FDL, R, B, R, B + 9999, Clr)
    r.ImGui_DrawList_AddLine(Glob.FDL, R, B, R, B + 9999, Clr)
    r.ImGui_DrawList_AddLine(Glob.FDL, R, T, R, T - 9999, Clr)
end

---@param img ImGui_Image
---@param V number
---@return number uvmin
---@return number uvmax
---@return number w
---@return number h
function Calc_strip_uv(img, V)
    local V = V or 0 
    local w, h = r.ImGui_Image_GetSize(img)
    local FrameNum = h / w

    local StepizedV = (SetMinMax(math.floor(V * FrameNum), 0, FrameNum - 1) / FrameNum)

    local uvmin = (1 / FrameNum) * StepizedV * FrameNum

    local uvmax = 1 / FrameNum + (1 / FrameNum) * StepizedV * FrameNum


    return uvmin, uvmax, w, h

    --[[  if h > w * 5 then          -- It's probably a strip knob file
            local FrameNum = h / w -- 31
            local scale = 2
            local sz = radius_outer * scale

            local StepizedV = (SetMinMax(math.floor(FP.V * FrameNum), 0, FrameNum - 1) / FrameNum)

            local uvmin = (1 / FrameNum) * StepizedV * FrameNum

            local uvmax = 1 / FrameNum + (1 / FrameNum) * StepizedV * FrameNum
            r.ImGui_DrawList_AddImage(WDL, FP.Image, center[1] - sz / 2, center[2] - sz / 2, center[1] + sz / 2,
                center[2] + sz / 2, 0, uvmin, 1, uvmax, FP.BgClr or 0xffffffff)
        end ]]
end
