--@noindex
-- layouts.lua
-- ReaDrum Machine Layout Configurations
-- 
-- IMPORTANT: All grid notes are OCTAVE-RELATIVE (0-11 per octave)
-- Actual MIDI note = grid_note + (octave * 12)
-- This allows transposing the same layout across octaves

return {
  version = "1.0",
  description = "ReaDrum Machine Layout Configurations",
  defaultLayout = "chromatic_3x4",
  octaveOffset = 3,  -- Global octave offset (can be overridden per-track)
  layouts = {
    chromatic_3x4 = {
      name = "Chromatic (3x4) [default]",
      description = "All 12 chromatic notes in 3x4 grid - default view for any device",
      rows = 3,
      cols = 4,
      minPadWidth = 60,
      octaveSpan = 1,
      grid = {
        {0, 1, 2, 3},
        {4, 5, 6, 7},
        {8, 9, 10, 11}
      },
      comment = "a layout that shows all notes.",
      noteNames = {
        ["0"] = "C",   ["1"] = "C#",  ["2"] = "D",   ["3"] = "D#",
        ["4"] = "E",   ["5"] = "F",   ["6"] = "F#",  ["7"] = "G",
        ["8"] = "G#",  ["9"] = "A",   ["10"] = "A#", ["11"] = "B"
      },
      aliases = {}
    },
    spd_sx_3x3 = {
      name = "Roland SPD-SX (3x3)",
      description = "Roland SPD-SX - 9 pads in 3x3 grid",
      rows = 3,
      cols = 3,
      minPadWidth = 70,
      octaveSpan = 1,
      grid = {
        {0, 1, 2},
        {3, 4, 5},
        {6, 7, 8}
      },
      comment = "noteNames correspond what SPD-SX sends in its default configuration.",
      noteNames = {
        ["0"] = "C",   ["1"] = "C#",  ["2"] = "D",
        ["3"] = "D#",  ["4"] = "E",   ["5"] = "F",
        ["6"] = "F#",  ["7"] = "G",   ["8"] = "G#"
      },
      aliases = {
        ["0"] = "Kick1",
        ["1"] = "Kick2",
        ["2"] = "Snare",
        ["3"] = "Clap",
        ["4"] = "Tom1",
        ["5"] = "Tom2",
        ["6"] = "Tom3",
        ["7"] = "Hihat",
        ["8"] = "Crash"
      }
    },
    alesis_performancepad = {
      name = "Alesis PerformancePad (2x4)",
      description = "Alesis PerformancePad - 8 pads in 2x4 grid",
      rows = 2,
      cols = 4,
      minPadWidth = 60,
      octaveSpan = 1,
      grid = {
        {1, 3, 4, 5},
        {0, 6, 7, 8}
      },
      comment = "Maps to 8 of the 12 chromatic notes: top-left 2 pads of SPD-SX plus both lower rows",
      noteNames = {
        ["1"] = "C#",   ["3"] = "D#",  ["4"] = "E",   ["5"] = "F",
        ["0"] = "C",   ["6"] = "F#",  ["7"] = "G",   ["8"] = "G#"
      },
      aliases = {
        ["0"] = "Kick",
        ["1"] = "Perc1",
        ["3"] = "Tom1",
        ["4"] = "Tom2",
        ["5"] = "Hihat",
        ["6"] = "Crash",
        ["7"] = "Ride",
        ["8"] = "Perc2"
      }
    }
  }
}
