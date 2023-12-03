-- @description Toggle set midi CC link for last touched track or take FX (inside Container) parameter (user input)
-- @author Suzuki
-- @license GPL v3
-- @version 1.1
-- @changelog Fixed a mistake I don't know why I did
-- @about Using v7.0+ API

local r = reaper

local retval, trackidx, itemidx, takeidx, fxidx, parm = r.GetTouchedOrFocusedFX(0)
local track = r.CSurf_TrackFromID(trackidx + 1, false) -- 1 based

local function GetUserInputCC()
    local retval, retvals_csv = r.GetUserInputs('Set CC value', 2, 'CC value(CC=0_119/14bit=0_31),14bit (yes=1/no=0)', '0,0') -- retvals_csv returns "input1,input2"
    local input1val, input2val = retvals_csv:match("([^,]+),([^,]+)")
    if input2val == nil then
        retvals = nil -- To make global retvals nil, when users choose cancel or close the window 
    end
    if input2val ~= nil then
        if type(input1val) == "string" then
            local input1check = tonumber(input1val)
            local input2check = tonumber(input2val)
            if input1check and input2check then
                input1val = input1check
                input2val = input2check
            else
                error('Only enter a number')
            end 
        end 
        local input1val = tonumber(input1val)
        local input2val = tonumber(input2val)                                                      
        if input2val < 0 then  
            input2val = 0
        elseif input2val > 1 then
            input2val = 1
        end
        if input1val < 0 then  
            input1val = 0
        elseif input2val == 0 and input1val > 119 then
            input1val = 119
        elseif input2val == 1 and input1val > 31 then
            input1val = 31
        end
        input2val = input2val * 128
        retvals = input1val + input2val
    end
    return retvals
end

if itemidx ~= -1 then
    local item = r.GetMediaItem(0, itemidx)
    local take = r.GetMediaItemTake(item, takeidx)
    local retval, buf = r.TakeFX_GetNamedConfigParm(take, fxidx, "param."..parm..".plink.active")
    if retval and buf == "1" then
        r.TakeFX_SetNamedConfigParm(take, fxidx, "param."..parm..".plink.active", 0)
        r.TakeFX_SetNamedConfigParm(take, fxidx, "param."..parm..".plink.effect", 0)
        r.TakeFX_SetNamedConfigParm(take, fxidx, "param."..parm..".plink.param", 0)
        r.TakeFX_SetNamedConfigParm(take, fxidx, "param."..parm..".plink.midi_bus", 0)
        r.TakeFX_SetNamedConfigParm(take, fxidx, "param."..parm..".plink.midi_chan", 0)
        r.TakeFX_SetNamedConfigParm(take, fxidx, "param."..parm..".plink.midi_msg", 0)
        r.TakeFX_SetNamedConfigParm(take, fxidx, "param."..parm..".plink.midi_msg2", 0)
    else
        GetUserInputCC()
        if retvals then
        r.TakeFX_SetNamedConfigParm(take, fxidx, "param."..parm..".plink.active", 1)
        r.TakeFX_SetNamedConfigParm(take, fxidx, "param."..parm..".plink.effect", -100)
        r.TakeFX_SetNamedConfigParm(take, fxidx, "param."..parm..".plink.param", -1)
        r.TakeFX_SetNamedConfigParm(take, fxidx, "param."..parm..".plink.midi_bus", 0)
        r.TakeFX_SetNamedConfigParm(take, fxidx, "param."..parm..".plink.midi_chan", 1)
        r.TakeFX_SetNamedConfigParm(take, fxidx, "param."..parm..".plink.midi_msg", 176)
        r.TakeFX_SetNamedConfigParm(take, fxidx, "param."..parm..".plink.midi_msg2", retvals)
        end
    end
else
    local retval, buf = r.TrackFX_GetNamedConfigParm(track, fxidx, "param."..parm..".plink.active")
    if retval and buf == "1" then
        r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".plink.active", 0)
        r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".plink.effect", 0)
        r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".plink.param", 0)
        r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".plink.midi_bus", 0)
        r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".plink.midi_chan", 0)
        r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".plink.midi_msg", 0)
        r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".plink.midi_msg2", 0)
    else
        GetUserInputCC()
        if retvals then
        r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".plink.active", 1)
        r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".plink.effect", -100)
        r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".plink.param", -1)
        r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".plink.midi_bus", 0)
        r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".plink.midi_chan", 1)
        r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".plink.midi_msg", 176)
        r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".plink.midi_msg2", retvals)
        end
    end
end
