-- @description Suzuki Track Template Shortcut Generator
-- @author Suzuki
-- @license GPL v3
-- @version 1.2
-- @changelog 
--   # Updated ReaImGui v0.9.0+
-- @about 
--   # Track Template Shortcut Generator
--   Track Template Shortcut Generator creates scripts to load your track templates. 
--   ### Usage
--   Left clicking the button opens your track template resource folder. Simply drop your ".RTrackTemplate" files to the button from there.
--   The generated script will be automatically saved to the folder "Suzuki Scripts/Track Template Shortcut Generator/Insert Track Template Scripts/", and will also be registered to the action list.
--   ### Prerequisites
--   ReaImGui, js extension

r = reaper

package.path = r.ImGui_GetBuiltinPath() .. '/?.lua'
im = require 'imgui' '0.9.0.2'

local input_title = "Track Template Shortcut Generator"

local OS = r.GetOS()

if OS == "Win64" or OS == "Win32" then
  slash = "\\"
else
  slash = "/"
end

local ResourcePath = r.GetResourcePath()
local folder_path = "/Scripts/Suzuki Scripts/Track/Track Template Shortcut Generator/Insert Track Template Scripts/"

if not im.CreateContext then
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
    ext = d[i]:match("(%.%w+)$")
    local filename = d[i]:match("([^\\/]+)%.%w%w*$")
    r.RecursiveCreateDirectory(ResourcePath .. folder_path, 0) -- create folder if it's not there
    files[i] = string.format("%s" .. folder_path .. "/Suzuki_Insert " .. filename .. " RTrackTemplate.lua", ResourcePath, i)
    if OS == "Win64" or OS == "Win32" then
      payload = d[i]:gsub("\\", "/")
      ResourcePath = ResourcePath:gsub("\\", "/")
    end
    paths[i] = string.match(payload, ResourcePath .. "/(.*)")
  end
  return files, paths
end

local function DNDGenerateFiles(count)
  local files = {}
  local paths = {}
  for i = 1, count do
    local rv, payload = im.GetDragDropPayloadFile(ctx, i - 1) -- 0 based
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
  if im.BeginDragDropTarget(ctx) then
    local rv, count = im.AcceptDragDropPayloadFiles(ctx)
    if rv then
      files, paths = DNDGenerateFiles(count)
      if ext == ".RTrackTemplate" then
        local code = CreateScripts(paths)
        CreateFiles(files, code)
        Register(files, count)
      else
        return
      end
    end
    im.EndDragDropTarget(ctx)
  end
end

local function Main()
  local rv = im.Button(ctx, "Drop Track Template Files Here", 300, 300)
  if rv then
    if r.HasExtState("Track Template Shortcut Generator", "template_files") then
      dir = r.GetExtState("Track Template Shortcut Generator", "template_files")
    else
      dir = ResourcePath .. slash .. "TrackTemplates"
    end
    local rv, files = r.JS_Dialog_BrowseForOpenFiles('Select track template files', dir, '', "TrackTemplates\0*.RTrackTemplate\0\0", true)
    if rv and files:len() > 0 then
      d = {} -- https://forum.cockos.com/showpost.php?p=2107274&postcount=299
      for file in files:gmatch("[^\0]*") do -- * instead of + to capture empty substrings
        d[#d+1] = file
      end
      if #d > 1 then -- multiple files?
        local folder = table.remove(d, 1) -- may be empty, in case of macOS
        for f = 1, #d do
          d[f] = folder .. d[f]
        end
      end
      files, paths = GenerateFiles(#d)
      if ext == ".RTrackTemplate" then
        local code = CreateScripts(paths)
        CreateFiles(files, code)
        Register(files, #d)
      else
        return
      end
      r.SetExtState("Track Template Shortcut Generator", "template_files", d[#d], true)
    end
  end
  DndAddTT_TARGET()
end

local function Run()

  if set_dock_id then
    im.SetNextWindowDockID(ctx, set_dock_id)
    set_dock_id = nil
  end

  im.SetNextWindowSizeConstraints(ctx, 325, 330, 340, 350)
  im.SetNextWindowSize(ctx, 325, 330, im.Cond_FirstUseEver)
  local imgui_visible, imgui_open = im.Begin(ctx, input_title, true, im.WindowFlags_NoScrollbar)

  if imgui_visible then
    Main()
    im.End(ctx)
  end

  if process or not imgui_open or im.IsKeyPressed(ctx, im.Key_Escape) then -- 27 is escaped key
    imgui_open = nil
  else
    r.defer(Run)
  end
end

local function Init()
  SetButtonState(1)
  r.atexit(Exit)
  ctx = im.CreateContext(input_title,  im.ConfigFlags_DockingEnable)
  Run()
end

Init()