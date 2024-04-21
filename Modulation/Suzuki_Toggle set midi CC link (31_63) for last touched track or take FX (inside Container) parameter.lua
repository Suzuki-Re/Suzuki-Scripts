-- @description Toggle set midi CC link (31/63) for last touched track or take FX (inside Container) parameter
-- @author Suzuki
-- @license GPL v3
-- @version 1.1
-- @changelog Added an option value to change bus and channel
-- @about Using v7.0+ API

local r = reaper

local retval, trackidx, itemidx, takeidx, fxidx, parm = r.GetTouchedOrFocusedFX(0)
local track = r.CSurf_TrackFromID(trackidx + 1, false) -- 1 based

----------------------- Change the values to whatever you like -----------------------

local WhichCCValue = 31 -- CC value(CC=0_119/14bit=0_31)
local Is14bit = 1 -- 14bit (yes=1/no=0)
local Bus = 0 -- 0 based (0 = bus 1, 1 = bus 2 etc)
local Channel = 1 -- 1 based (1 = chan 1, 2 = chan 2 etc but 0 = omni)

--------------------------------------------------------------------------------------

local function GetUserInputCC()
    if Is14bit ~= nil then
        if type(WhichCCValue) == "string" then
            local input1check = tonumber(WhichCCValue)
            local input2check = tonumber(Is14bit)
            local input3check = tonumber(Bus)
            local input4check = tonumber(Channel)
            if input1check and input2check and input3check and input4check then
                WhichCCValue = input1check
                Is14bit = input2check
                Bus = input3check
                Channel = input4check
            else
                error('Only enter a number')
            end 
        end 
        local WhichCCValue = tonumber(WhichCCValue)
        local Is14bit = tonumber(Is14bit)   
        Bus = tonumber(Bus)
        Channel = tonumber(Channel)                                                      
        if Is14bit < 0 then  
            Is14bit = 0
        elseif Is14bit > 1 then
            Is14bit = 1
        end
        if WhichCCValue < 0 then  
            WhichCCValue = 0
        elseif Is14bit == 0 and WhichCCValue > 119 then
            WhichCCValue = 119
        elseif Is14bit == 1 and WhichCCValue > 31 then
            WhichCCValue = 31
        end
        if Bus < 0 then  
            Bus = 0
        elseif Bus > 15 then
            Bus = 15
        end
        if Channel < 0 then  
            Channel = 0
        elseif Channel > 16 then
            Channel = 16
        end
        Is14bit = Is14bit * 128
        retvals = WhichCCValue + Is14bit
    end
    return retvals, Bus, Channel
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
        local retvals, Bus, Channel = GetUserInputCC()
        if retvals then
            r.TakeFX_SetNamedConfigParm(take, fxidx, "param."..parm..".plink.active", 1)
            r.TakeFX_SetNamedConfigParm(take, fxidx, "param."..parm..".plink.effect", -100)
            r.TakeFX_SetNamedConfigParm(take, fxidx, "param."..parm..".plink.param", -1)
            r.TakeFX_SetNamedConfigParm(take, fxidx, "param."..parm..".plink.midi_bus", Bus)
            r.TakeFX_SetNamedConfigParm(take, fxidx, "param."..parm..".plink.midi_chan", Channel)
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
        local retvals, Bus, Channel = GetUserInputCC()
        if retvals then
            r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".plink.active", 1)
            r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".plink.effect", -100)
            r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".plink.param", -1)
            r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".plink.midi_bus", Bus)
            r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".plink.midi_chan", Channel)
            r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".plink.midi_msg", 176)
            r.TrackFX_SetNamedConfigParm(track, fxidx, "param."..parm..".plink.midi_msg2", retvals)
        end
    end
end
