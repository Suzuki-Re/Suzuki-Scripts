-- @description Suzuki Track Template Shortcut Generator
-- @author Suzuki
-- @license GPL v3
-- @version 1.0
-- @changelog 
--   Initial Release
-- @about 
--   # Track Template Shortcut Generator
--   Track Template Shortcut Generator creates scripts to load your track templates. 
--   ### Usage
--   Left clicking the button opens your track template resource folder. Simply drop your ".RTrackTemplate" files to the button from there.
--   The generated script will be automatically saved to the folder "Suzuki Scripts/Track Template Shortcut Generator/Insert Track Template Scripts/", and will also be registered to the action list.
--   ### Prerequisites
--   ReaImGui

local input_title = "Track Template Shortcut Generator"

r = reaper

local OS = r.GetOS()

local ResourcePath = r.GetResourcePath()
local folder_path = "/Scripts/Suzuki Scripts/Track/Track Template Shortcut Generator/Insert Track Template Scripts/"

if not r.ImGui_CreateContext then
  r.MB("Missing dependency: ReaImGui extension.\nDownload it via Reapack ReaTeam extension repository.", "Error", 0)
  return false
end

-- Set ToolBar Button State
local function SetButtonState( set )
  local is_new_value, filename, sec, cmd, mode, resolution, val = r.get_action_context()
  r.SetToggleCommandState( sec, cmd, set or 0 )
  r.RefreshToolbar2( sec, cmd )
end

local function Exit()
  SetButtonState()
end

local function GenerateFiles(count)
  local files = {}
  local paths = {}
  for i = 1, count do
    local rv, payload = r.ImGui_GetDragDropPayloadFile(ctx, i - 1) -- 0 based
    ext = payload:match("(%.%w+)$")
    local filename = payload:match("([^\\/]+)%.%w%w*$")
    r.RecursiveCreateDirectory(ResourcePath .. folder_path, 0) -- create folder if it's not there
    files[i] = string.format("%s" .. folder_path .. "/Suzuki_Insert " .. filename .. " RTrackTemplate.lua", ResourcePath, i)
    if OS == "Win64" or OS == "Win32" then
      payload = payload:gsub("\\", "/")
      ResourcePath = ResourcePath:gsub("\\", "/")
    end
    paths[i] = string.match(payload, ResourcePath .. "/(.*)")
  end
  return files, paths
end

local function CreateScripts(paths)
  local code = {}
  for _, path in ipairs(paths) do
  code[_] = [[
    local track_template_path = reaper.GetResourcePath() .. "/]] .. path .. [["
    reaper.Main_openProject(track_template_path)]]
  end
  return code
end

local function CreateFiles(files, code)
  for _, file in ipairs(files) do
    file = io.open(file, 'w')
    file:write(code[_])
    file:close()
  end
end

local function Register(files, count)
  for index, file in ipairs(files) do
    local ret = r.AddRemoveReaScript(true, 0, file, index == count)
  end
end

local function DndAddTT_TARGET()
  if r.ImGui_BeginDragDropTarget(ctx) then
    local rv, count = r.ImGui_AcceptDragDropPayloadFiles(ctx)
    if rv then
      files, paths = GenerateFiles(count)
      if ext == ".RTrackTemplate" then
        local code = CreateScripts(paths)
        CreateFiles(files, code)
        Register(files, count)
      else
        return
      end
    end
    r.ImGui_EndDragDropTarget(ctx)
  end
end

local function Main()
  local rv = r.ImGui_Button(ctx, "Drop Track Template Files Here", 300, 300)
  if rv then
    if OS == "Win64" or OS == "Win32" then
      os.execute('start ' .. ResourcePath .. "/TrackTemplates")
    else
      os.execute('open ' .. ResourcePath .. "/TrackTemplates")
    end
  end
  DndAddTT_TARGET()
end

local function Run()

  if set_dock_id then
    r.ImGui_SetNextWindowDockID(ctx, set_dock_id)
    set_dock_id = nil
  end

  r.ImGui_SetNextWindowSizeConstraints(ctx, 325, 330, 340, 350)
  r.ImGui_SetNextWindowSize(ctx, 325, 330, r.ImGui_Cond_FirstUseEver())
  local imgui_visible, imgui_open = r.ImGui_Begin(ctx, input_title, true, r.ImGui_WindowFlags_NoScrollbar())

  if imgui_visible then
    Main()
    r.ImGui_End(ctx)
  end

  if process or not imgui_open or r.ImGui_IsKeyPressed(ctx, 27) then -- 27 is escaped key
    imgui_open = nil
  else
    r.defer(Run)
  end
end

local function Init()
  SetButtonState(1)
  r.atexit(Exit)
  ctx = r.ImGui_CreateContext(input_title,  r.ImGui_ConfigFlags_DockingEnable())
  Run()
end

Init()