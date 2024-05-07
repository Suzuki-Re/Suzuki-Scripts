--@noindex

local function ClickAddFX(FX_Name)
  if SELECTED then
    for k, v in pairs(SELECTED) do
      UpdatePadID()
      local k = tonumber(k)
      if Pad[k] then
        local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. Pad[k].Pad_Num - 1) -- 0 based
        local InsertFXPos = ConvertPathToNestedPath(pad_id, Pad[k].FX_Num + 1) -- 1 based
        r.TrackFX_AddByName(track, FX_Name, false, InsertFXPos)
      else
        local notenum = k - 1
        local note_name = getNoteName(notenum)
        AddPad(note_name, k)     -- pad_id = loc, pad_num = num
        AddNoteFilter(notenum, Pad[k].Pad_Num)
        local _, pad_id = r.TrackFX_GetNamedConfigParm(track, parent_id, "container_item." .. Pad[k].Pad_Num - 1) -- 0 based
        local InsertFXPos = ConvertPathToNestedPath(pad_id, 2) -- 1 based
        r.TrackFX_AddByName(track, FX_Name, false, InsertFXPos)
      end
    end
    SELECTED = nil
  else
    InsertFXPos = -1000 - r.TrackFX_GetCount(track)
    r.TrackFX_AddByName(track, FX_Name, false, InsertFXPos)
  end
end

local FX_LIST, CAT = ReadFXFile()
if not FX_LIST or not CAT then
   FX_LIST, CAT = MakeFXFiles()
end

local function Lead_Trim_ws(s) return s:match '^%s*(.*)' end

local tsort = table.sort
function SortTable(tab, val1, val2)
  tsort(tab, function(a, b)
    if (a[val1] < b[val1]) then
      -- primary sort on position -> a before b
      return true
    elseif (a[val1] > b[val1]) then
      -- primary sort on position -> b before a
      return false
    else
      -- primary sort tied, resolve w secondary sort on rank
      return a[val2] < b[val2]
    end
  end)
end

local old_t = {}
local old_filter = ""
local function Filter_actions(filter_text)
  if old_filter == filter_text then return old_t end
  filter_text = Lead_Trim_ws(filter_text)
  local t = {}
  if filter_text == "" or not filter_text then return t end
  for i = 1, #FX_LIST do
    local name = FX_LIST[i]:lower()     --:gsub("(%S+:)", "")
    local found = true
    for word in filter_text:gmatch("%S+") do
      if not name:find(word:lower(), 1, true) then
        found = false
        break
      end
    end
    if found then t[#t + 1] = { score = FX_LIST[i]:len() - filter_text:len(), name = FX_LIST[i] } end
  end
  if #t >= 2 then
    SortTable(t, "score", "name")     -- Sort by key priority
  end
  old_t = t
  old_filter = filter_text
  return t
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

local FILTER = ''
local function FilterBox()
  local MAX_FX_SIZE = 300
  im.PushItemWidth(ctx, MAX_FX_SIZE)
  if im.IsWindowAppearing(ctx) then im.SetKeyboardFocusHere(ctx) end
  _, FILTER = im.InputTextWithHint(ctx, '##input', "SEARCH FX", FILTER)
  local filtered_fx = Filter_actions(FILTER)
  local filter_h = #filtered_fx == 0 and 0 or (#filtered_fx > 40 and 20 * 17 or (17 * #filtered_fx))
  ADDFX_Sel_Entry = SetMinMax(ADDFX_Sel_Entry or 1, 1, #filtered_fx)
  if #filtered_fx ~= 0 then
    if im.BeginChild(ctx, "##popupp", MAX_FX_SIZE, filter_h) then
      for i = 1, #filtered_fx do
        if im.Selectable(ctx, filtered_fx[i].name, i == ADDFX_Sel_Entry) then
          ClickAddFX(filtered_fx[i].name)
          im.CloseCurrentPopup(ctx)
          LAST_USED_FX = filtered_fx[i].name
        end
        DndAddFX_SRC(filtered_fx[i].name)
      end
      im.EndChild(ctx)
    end
    if im.IsKeyPressed(ctx, im.Key_Enter) then
      ClickAddFX(filtered_fx[ADDFX_Sel_Entry].name)
      LAST_USED_FX = filtered_fx[filtered_fx[ADDFX_Sel_Entry].name]
      ADDFX_Sel_Entry = nil
      FILTER = ''
      im.CloseCurrentPopup(ctx)
    elseif im.IsKeyPressed(ctx, im.Key_UpArrow) then
      ADDFX_Sel_Entry = ADDFX_Sel_Entry - 1
    elseif im.IsKeyPressed(ctx, im.Key_DownArrow) then
      ADDFX_Sel_Entry = ADDFX_Sel_Entry + 1
    end
  end
  if im.IsKeyPressed(ctx, im.Key_Escape) then
    FILTER = ''
    im.CloseCurrentPopup(ctx)
  end
  return #filtered_fx ~= 0
end

local function DrawFxChains(tbl, path)
  local extension = ".RfxChain"
  path = path or ""
  for i = 1, #tbl do
    if tbl[i].dir then
      if im.BeginMenu(ctx, tbl[i].dir) then
        DrawFxChains(tbl[i], table.concat({ path, os_separator, tbl[i].dir }))
        im.EndMenu(ctx)
      end
    end
    if type(tbl[i]) ~= "table" then
      if im.Selectable(ctx, tbl[i]) then
        if TRACK then
          ClickAddFX(table.concat({ path, os_separator, tbl[i], extension }))
        end
      end
      DndAddFX_SRC(table.concat({ path, os_separator, tbl[i], extension }))
    end
  end
end

local function DrawItems(tbl, main_cat_name)
  for i = 1, #tbl do
    if im.BeginMenu(ctx, tbl[i].name) then
      for j = 1, #tbl[i].fx do
        if tbl[i].fx[j] then
          local name = tbl[i].fx[j]
          if main_cat_name == "ALL PLUGINS" and tbl[i].name ~= "INSTRUMENTS" then
            -- STRIP PREFIX IN "ALL PLUGINS" CATEGORIES EXCEPT INSTRUMENT WHERE THERE CAN BE MIXED ONES
            name = name:gsub("^(%S+:)", "")
          elseif main_cat_name == "DEVELOPER" then
            -- STRIP SUFFIX (DEVELOPER) FROM THESE CATEGORIES
            name = name:gsub(' %(' .. Literalize(tbl[i].name) .. '%)', "")
          end
          if im.Selectable(ctx, name) then
            if TRACK then
              ClickAddFX(tbl[i].fx[j])
              LAST_USED_FX = tbl[i].fx[j]
            end
          end
          DndAddFX_SRC(tbl[i].fx[j])
        end
      end
      im.EndMenu(ctx)
    end
  end
end

function Frame()
  local search = FilterBox()
  if search then return end
  for i = 1, #CAT do
    if CAT[i].name ~= "TRACK TEMPLATES" then
      if #CAT[i].list ~= 0 then
        if im.BeginMenu(ctx, CAT[i].name) then
          if CAT[i].name == "FX CHAINS" then
            DrawFxChains(CAT[i].list)
      --elseif CAT[i].name == "TRACK TEMPLATES" then
      --  DrawTrackTemplates(CAT[i].list)
          else
            DrawItems(CAT[i].list, CAT[i].name)
          end
          im.EndMenu(ctx)
        end
      end
    end
  end
  if im.BeginMenu(ctx, "RDM TOOLS") then
    r.Undo_BeginBlock()
    if im.Selectable(ctx, "Reverse Effect") then
      ClickAddFX("Reverse Audio (Methode Double-Buffer)")
      LAST_USED_FX = "Reverse Effect"
    end
    DndAddFX_SRC("Reverse Audio (Methode Double-Buffer)")
    EndUndoBlock("ADD REVERSE EFFECTS")
    if im.Selectable(ctx, "MIDI Triggered Low Pass Filter") then
      ClickAddFX("../Scripts/Suzuki Scripts/ReaDrum Machine/FXChains/MIDI Triggered Low Pass Filter.RfxChain")
      LAST_USED_FX = "MIDI Triggered Low Pass Filter"
    end
    DndAddFX_SRC("../Scripts/Suzuki Scripts/ReaDrum Machine/FXChains/MIDI Triggered Low Pass Filter.RfxChain")
    im.EndMenu(ctx)
  end
  if im.Selectable(ctx, "CONTAINER") then
    ClickAddFX("Container")
    LAST_USED_FX = "Container"
  end
  DndAddFX_SRC("Container")
  if im.Selectable(ctx, "VIDEO PROCESSOR") then
    ClickAddFX("Video processor")
    LAST_USED_FX = "Video processor"
  end
  DndAddFX_SRC("Video processor")
  if LAST_USED_FX then
    if im.Selectable(ctx, "RECENT: " .. LAST_USED_FX) then
      ClickAddFX(LAST_USED_FX)
    end
  DndAddFX_SRC(LAST_USED_FX)
  end
  if im.Selectable(ctx, "RESCAN FX LIST") then
    FX_LIST, CAT = MakeFXFiles()
  end
end