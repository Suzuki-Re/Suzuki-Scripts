# Suzuki Scripts Repository

Comprehensive collection of REAPER Lua scripts for advanced workflow automation, with ReaDrum Machine as the flagship plugin.

## 📋 Table of Contents

- [Suzuki Scripts Repository](#suzuki-scripts-repository)
  - [📋 Table of Contents](#-table-of-contents)
  - [Installation](#installation)
    - [Prerequisites](#prerequisites)
    - [Add Repositories to ReaPack](#add-repositories-to-reapack)
    - [Install Individual Scripts](#install-individual-scripts)
    - [Adding a new script to a repository and wanna make it show up as an action in REAPER?](#adding-a-new-script-to-a-repository-and-wanna-make-it-show-up-as-an-action-in-reaper)
  - [Repository Overview](#repository-overview)
    - [**ReaDrum Machine** ⭐ (Main Project)](#readrum-machine--main-project)
    - [**FX Scripts** (30+ scripts)](#fx-scripts-30-scripts)
    - [**Development Scripts** (2 scripts)](#development-scripts-2-scripts)
    - [**Envelopes** (1 script)](#envelopes-1-script)
    - [**Modulation** (6 scripts)](#modulation-6-scripts)
    - [**Track / Track Template Shortcut Generator**](#track--track-template-shortcut-generator)
    - [**lewloiwc's Sound Design Suite \& Splitter Suite**](#lewloiwcs-sound-design-suite--splitter-suite)
    - [**FXChain / FX Devices**](#fxchain--fx-devices)
  - [ReaDrum Machine](#readrum-machine)
    - [What is it?](#what-is-it)
    - [How to use](#how-to-use)
    - [Key Files](#key-files)
    - [Layouts.lua file](#layoutslua-file)
    - [Data Storage](#data-storage)
      - [Sample Assignments \& Pad Data Hierarchy](#sample-assignments--pad-data-hierarchy)
      - [Summary](#summary)
      - [How REAPER Identifies Executable Scripts](#how-reaper-identifies-executable-scripts)
    - [UI Code Structure](#ui-code-structure)
    - [Architecture](#architecture)
    - [Configurable device layout](#configurable-device-layout)
      - [Concept prompts](#concept-prompts)
  - [Dependencies](#dependencies)
    - [Required for ReaDrum Machine](#required-for-readrum-machine)
    - [Optional](#optional)
    - [What is Sexan's FX Browser Parser?](#what-is-sexans-fx-browser-parser)
  - [Support](#support)
    - [Forum Thread](#forum-thread)
    - [Screenshots](#screenshots)
    - [Enhanced Experience](#enhanced-experience)


## Installation

### Prerequisites
- **REAPER** v7.06+
- **ReaPack** - Package manager for REAPER scripts
  - [Installation Guide](https://reapack.com/user-guide#installation)

### Add Repositories to ReaPack

Add the following repositories to ReaPack:

**Primary Repository:**
```
https://github.com/Suzuki-Re/Suzuki-Scripts/raw/master/index.xml
```

**⚠️ REQUIRED for ReaDrum Machine:**
```
https://github.com/GoranKovac/ReaScripts/raw/master/index.xml
```
(Sexan's FX Browser Parser - needed for the FX browser functionality in ReaDrum Machine)

**Optional (for SKFilter JSFX):**
```
https://raw.githubusercontent.com/tiagolr/tilr_jsfx/master/index.xml
```

**Pnolle's fork => layoutManager branch:**
```
https://raw.githubusercontent.com/pnolle/Reaper_Suzuki-Scripts_ReaDrumMachine/refs/heads/layoutManager/index.xml
```

### Install Individual Scripts

Browse and install scripts through ReaPack's interface. Most scripts are organized by category (Development, FX, Track, etc.). 

**Note**: The ReaDrum Machine script will automatically prompt you to add missing dependencies on first run if needed.


### Adding a new script to a repository and wanna make it show up as an action in REAPER?

Make sure it is included in ``index.xml`` in your latest ``version`` within the ``reapack`` tag.

1. -- @noindex in header of the script

* This directive tells REAPER not to index the script itself as an independent action.
* Typically, a script with -- @noindex won’t appear in the main Actions list.
* It’s mainly used for helper scripts, libraries, or scripts that are only meant to be called by other scripts.

2. -- @provides in header of the main script

* This directive is used in a main script to declare that it "provides" other scripts or files.
* It tells REAPER (and package managers like ReaPack) that the main script depends on or includes these additional files.
* The files listed under -- @provides are usually helper scripts or libraries that the main script calls or loads.
* These provided scripts can have -- @noindex themselves to avoid cluttering the Actions list.

Still, this might not work or not properly refresh, even after REAPER restart. In that case, ``Show Actions list`` => ``New action`` => ``Load ReaScript`` to choose the file from your hard drive. After that, it's in the list.

---

## Repository Overview

This repository contains multiple script collections distributed through ReaPack. Here's what's included:

### **ReaDrum Machine** ⭐ (Main Project)
A professional sampler/beat plugin with an intuitive UI for loading samples and FX into nested container architecture.
- **Focus**: One-shot drums, beat-making, external drum pad integration
- **Key Features**: Drag-and-drop pads, choke groups, per-pad FX routing
- [Manual](ReaDrum%20Machine/ReaDrumMachine_Manual.md)

### **FX Scripts** (30+ scripts)
Utility scripts for advanced FX chain management:
- Close/manage floating FX windows
- Add/copy channel pin mappings
- Stereo channel configuration tools
- Map FX parameters to MIDI CC

### **Development Scripts** (2 scripts)
Developer tools for checking stereo channel bitmasks on FX inside containers.

### **Envelopes** (1 script)
Toggle visibility of envelopes for FX parameters inside containers.

### **Modulation** (6 scripts)
Parameter modulation utilities:
- Enable/disable LFO and audio control signals
- MIDI CC linking for FX parameters
- Parameter linking for modulation workflows

### **Track / Track Template Shortcut Generator**
Tools for managing track templates and shortcuts.

### **lewloiwc's Sound Design Suite & Splitter Suite**
Community JSFX plugin collections integrated into this repository:
- **Sound Design Suite**: MIDI trigger envelope, sample warping, sidechain erosion, and related tools
- **Splitter Suite**: Frequency and amplitude splitting utilities

⚠️ **Note**: These contain `.jsfx` files (synthesizers/effects plugins) and `.RPL` project templates, not Lua scripts. They're not distributed via ReaPack—install JSFX files directly in REAPER's Effects folder, and use `.RPL` templates as reference projects. Included here for convenient bundling with the repository.

### **FXChain / FX Devices**
- **FXChain Presets**: Pre-configured effect chain templates (`.RfxChain` files)—load these manually via REAPER's FX chain UI
- **FX Devices**: Contains `ReaDrum Machine.lua` reference script and documentation

⚠️ **Note**: `.RfxChain` files are effect chain templates, not scripts. They're not distributed via ReaPack—manually load them in REAPER when needed. Included here as reference presets.

---

## ReaDrum Machine

### What is it?
ReaDrum Machine is a Lua script that transforms REAPER into a powerful beat-making tool. It loads samples and effects into a hierarchical container structure, allowing you to:
- **Trigger samples** from 16 or more pads (configurable grid)
- **Add FX per-pad** with full automation
- **Control parameters** via external MIDI drum pads
- **Use choke groups** for realistic drum sounds (mute related hits)
- **Render or adjust pitch** via RS5k sampler parameters

📖 **[Full Manual](ReaDrum%20Machine/ReaDrumMachine_Manual.md)** — see for detailed usage instructions


### How to use

| Action | How to |
| - | - |
| Add sample | Drag & drop sample file on pad |
| Remove sample | alt + click on pad<br>Mac: opt + click |
| Multi-select pads | ctrl + click on pad<br>Mac: cmd + click |


### Key Files
- **Main Script**: `Suzuki_ReaDrum_Machine_Instruments_Rack.lua`
- **Alternative Layout**: `Suzuki_ReaDrum_Machine_Instruments_Rack_(Scrollable Layout).lua`
- **Modules** (in `/Modules/`):
  - `Drawing.lua` - ImGui-based UI rendering (pads, buttons, colors)
  - `DragNDrop.lua` - Pad dragging, swapping, copying functionality
  - `Pad Actions.lua` - Pad interaction handlers (select, remove, etc.)
  - `FX List.lua` - FX browser integration
  - `General Functions.lua` - Utility functions
- **Resources**:
  - `Fonts/` - Custom fonts for UI
  - `Images/` - Icons and graphics
  - `JSFX/` - Custom plugins (e.g., RDM utility)
  - `FXChains/` - Pre-configured effect templates

### Layouts.lua file

noteNames syntax: 
[notenumber in lowest octave] = 'NoteName'. 

### Data Storage

ReaDrum Machine uses two distinct storage mechanisms:

| Aspect | **1. Pad Layout Selection** (per track) | **2. Sample Assignments & Pad Data** (original feature) |
|--------|----------------------------------------|--------------------------------------------------------|
| **Storage Location** | REAPER project file (.RPP) - stored in project's extended state (`ExtState`) | REAPER track's FX chain |
| **Storage Method** | `r.SetProjExtState()` / `r.GetProjExtState()` | Nested Container and RS5k plugin instances |
| **Persistence** | ✅ REAPER project file (.RPP) | ✅ REAPER project file (.RPP) |
| **Key Format** | `"ReaDrum Machine"` namespace, `"{track_guid}layout"` key | N/A - stored as FX plugin hierarchy, not ext state |
| **Contents** | Layout ID (e.g., `"chromatic_3x4"`, `"alesis_performancepad"`) | Container structure, MIDI note IDs, sample file paths, playback parameters (pitch, start/end offset), choke groups, user-added FX per-pad |
| **Scope** | Per-track setting - each track in the project remembers which grid layout it uses | Entire track FX chain - survives project save/load |
| **Module** | `Modules/LayoutManager.lua` handles all layout persistence via `LayoutManager_SetLayoutForTrack()` and `LayoutManager_GetLayoutForTrack()` | Multiple modules (`DragNDrop.lua`, `Pad Actions.lua`, `General Functions.lua`) handle FX chain manipulation; no single module for persistence (handled by REAPER natively) |

#### Sample Assignments & Pad Data Hierarchy

- Main "ReaDrum Machine" Container FX holds all pads
- Each pad is a child Container FX with a unique MIDI note ID
- Inside each pad Container:
  - **RDM MIDI Utility** JSFX - stores MIDI note configuration and choke groups
  - **RS5k (Reasamplomatic 5000)** instances - store sample files and playback parameters (pitch, start/end offset, etc.)
  - Optional additional FX - any user-added effects per-pad

#### Summary
- **Layout configuration** → Lightweight, stored in project ext state
- **Samples and FX** → Heavy data, stored directly in track's FX chain
- Both persist when you save the REAPER project
- Switching layouts on a track doesn't affect its samples or FX - the data remains in the FX chain

#### How REAPER Identifies Executable Scripts

It's all in the header comments at the top of the file. Look at the very top of ``Suzuki_ReaDrum_Machine_Instruments_Rack.lua``:

These @ tags are ReaPack metadata that tell REAPER:

```
@description → The action name shown in the Actions list
@author, @version, @license → Script metadata
@provides → What supporting files this script needs (see below)
The Key: @provides Section
```

The ``[main]`` prefix marks a script as executable. So:

``[main] Suzuki_ReaDrum_Machine_Instruments_Rack_(Scrollable Layout).lua`` → Also appears as an action
Without ``[main]``, files are just bundled resources (not actions)

### UI Code Structure
The ReaDrum Machine UI is built with **ReaImGui** (Dear ImGui bindings for REAPER):
- **Primary renderer**: [Drawing.lua](ReaDrum%20Machine/Modules/Drawing.lua) (996 lines)
  - Color utilities and brightness adjustment
  - Pad rendering with hover effects
  - Parameter visualization and icons
  - Layout and positioning calculations
- **Supporting modules**:
  - `DragNDrop.lua` - Interactive drag-and-drop state management
  - `Pad Actions.lua` - Event handlers for pad interactions
  - `FX List.lua` - FX browser UI and filtering

### Architecture
```
ReaDrum Machine Container (Root)
├── Pad 1 (Sub-container)
│   ├── RS5k Sampler
│   └── FX Chain (user-added effects)
├── Pad 2
│   ├── RS5k Sampler
│   └── FX Chain
└── Pad N...
```

Each pad is a **nested container** with independent routing and effects.


### Configurable device layout


#### Concept prompts

* There's a number of pads defined for each device, like 8 or 9 in total, each one with a fixed note => but not an absolute MIDI note! It's a note within an octave!
* the "grid" prop seems to do a good job, but let's bring it down to the first octave in the config. let's say that that is octave 0, then all the other octaves will add <octaveNo>*12 to the value of each note.
* This means, we have to iterate over the number of pads per octave and assign values, calculated as described above.
* I need the "add octaves" logic to kind of switch sample sets for different songs by just switching the octave of my pads.
* And when you got this logic down, please add a failsafe: My Alesis device has fixed notes that exceed(!) the range of one octave. Meaning: it kinda starts in octave 0, but also in octave 1. Worst case should be that for the highest octave, it will generate some notes that don't exist (exceed MIDI range), and ReaDrum Machine should not crash when asked to draw those pads - just don't draw them or gray them out.
* Before the MIDI notes reach ReaDrum Machine I have another script that adjusts the octave. So ReaDrum Machine (the code in this project) only sees the adjusted values. 
* For SPD-SX, they all stay within the range of one octave, while for the Alesis PP, they're distributed over two octaves (low prio problem because I have yet another script that maps single notes to others - I just need a failsafe here).

---

## Dependencies

### Required for ReaDrum Machine
1. **ReaImGui** (v0.9.3.1+) - ImGui bindings for UI
2. **S&M/SWS Extension** - REAPER API extensions
3. **js Extension** - JavaScript engine support
4. **lewloiwc's Sound Design Suite** - MIDI trigger envelope
5. **Sexan's FX Browser Parser V7** ⭐ - (see below) - **REQUIRED for FX browser functionality**

### Optional
- **tilr's SK Filter** (JSFX) - Optional filtering plugin. Add this repository if you want access to various filter types as effects you can add to pads:
  ```
  https://raw.githubusercontent.com/tiagolr/tilr_jsfx/master/index.xml
  ```

**Auto-Detection**: The ReaDrum Machine script will automatically detect missing required dependencies on first run and prompt you to install them via ReaPack.

### What is Sexan's FX Browser Parser?
**Purpose**: Provides a searchable, categorized FX browser interface for ReaDrum Machine.

**What it does**:
- Scans all installed REAPER plugins (VST, AU, CLAP, JSFX, LV2)
- Builds a hierarchical category system from `reaper-fxtags.ini`
- Enables fast text-based filtering and searching
- Integrates with FX browser favorites and smart folders
- Caches plugin list for faster subsequent loads

**Key Functions**:
- `GetFXTbl()` - Generates plugin list and categories
- `ParseFXTags()` - Organizes by official REAPER categories
- `ParseFavorites()` - Reads custom favorites from `.ini`
- `Stripname()` - Cleans up plugin names (removes VST:, AU: prefixes)

**Source**: [GoranKovac/ReaScripts](https://github.com/GoranKovac/ReaScripts/tree/master/FX)

**Why it's needed**: ReaDrum Machine's FX browser uses this parser to provide users with a searchable, organized list of available effects for adding to pads.

---

## Support

If you find these scripts useful, please consider supporting the developer:

- **Ko-fi**: [https://ko-fi.com/suzukireaper](https://ko-fi.com/suzukireaper)

### Forum Thread
For discussions, feature requests, and bug reports:
[REAPER Forum - ReaDrum Machine](https://forum.cockos.com/showthread.php?t=284566)


### Screenshots
![Workflow](https://i.imgur.com/A3vDxxT.gif)
![UI](https://i.imgur.com/WHT5b6k.png)
![Integration](https://imgur.com/6z9BPOS.gif)


### Enhanced Experience
For a Bitwig Drum Machine-style interface, check out [FX Devices](https://github.com/BryanChi/BryanChi-FX-Devices)
![FX Devices](https://imgur.com/fP72RYB.png)