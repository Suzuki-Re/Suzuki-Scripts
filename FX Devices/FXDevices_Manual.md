# FX Devices Manual
FX Device - Macro&Env Modulation, Parallel FX, Preset Morph, FX Wrapper

## Prerequisites
ReaImGui, js_ReaScriptAPI, Ultraschall API, and Sexan's FX Browser

## Overview
![](https://i.imgur.com/aO9mIv5.png)

①Settings
Left click

1) Style Editor
You can change color of the script here.

2) Keyboard Shortcut Editor
You can assign actions from action list. Click + button to add a key slot, and open action list and copy selected action command ID, and then click to paste command ID. Don't forget to press save. Alt + Left click to remove action.
![](https://i.imgur.com/cmo8l9a.png)

②Record Last Touch
Touch parameter in FX window, and then clicking this button shows that parameter on the script.

③Plugin Name
For a basic usage, hover the mouse cursor over and see ⑧tooltip. To change the order of plugins, drag and dropping from here to ⑦. Hovering over and clicking plus (+) button on the righ side shows FX Parameter list.
Ctrl + right clicking -> Preset morphing, the wrench icon I don't know what it's for, Layout edit mode, Save all values as default, default slider width, default parameter type.
1) Preset morphing
Select a preset in FX window, and then click A (or B) to assign that preset. Move slider to morph presets. Ctrl + right click to morph related menu. [See op's post](https://forum.cockos.com/showpost.php?p=2531298&postcount=1).
![](https://i.imgur.com/m10yj00.gif)


2) Layout edit mode
You can create your custom layout for a plugin. Prepare parameters in advance and follow [the instruction video](https://www.youtube.com/watch?v=CfxUQ-_lyLs).

4) Save all values as default
You can save current parameter values as default, and recall them by double clicking parameters.

④Wet/Dry knob
alt + right click -> Toggle delta solo

⑤Macro Name
Editable

⑥Macro Control
1) Right click -> Assigning macro. You can control multiple parameters at once by assigining macro. See macro modulation on [the op's post](https://forum.cockos.com/showpost.php?p=2531298&postcount=1).

2) Ctrl + right click -> Option to automate or set type to envelope.
:Automate -> Show selected macro envelope, and then you can automate macro by drawing envelope on the track.
:Set type to envelope -> You can modulate parameters by a simple envelope shape. You need to set midi notes to use this feature. Left side determines how fast parameters reach highest macro value after midi note starts, while right side determines how fast parameters reach minimum macro value after midi note stops. [See also op's post - Envelope Modulation](https://forum.cockos.com/showpost.php?p=2531298&postcount=1).
:Set type to Step Sequencer
:Set type to Audio Follower
:Set type to LFO

3) Ctrl + Left click
Enter value.

⑦A Space between Plugins
Left Click -> Option to open FX adder, FX Layering or Band Split feature.

1) FX Adder
You can add FX here.

2) FX Layering
See op's post.

3) Band Split
Right clicking to add or remove band. [See op's post](https://forum.cockos.com/showpost.php?p=2531298&postcount=1).

⑧Tooltip
L = Left click, R = Right Click

## Band Split
![](https://i.imgur.com/H75sj25.gif)

## Shortcut Editor
![](https://i.imgur.com/REFZaKD.gif)

## Container
Container is supported.
![](https://i.imgur.com/jOdFO0a.gif)

## ReaDrum Machine
![](https://i.imgur.com/kfWEO1U.gif)

Right clicking a pad shows FX layouts in the pad.
![](https://i.imgur.com/fP72RYB.gif)

## Layout Editor
![](https://i.imgur.com/75nVi2W.gif)
![](https://i.imgur.com/8hI4bPI.gif)
![](https://i.imgur.com/7gofb0C.gif)
![](https://i.imgur.com/HT4c5Pu.gif)
![](https://i.imgur.com/Y8G8mDX.gif)
![](https://i.imgur.com/79NLKFg.gif)
![](https://i.imgur.com/8ouOgy1.gif)

## Parameter Modulation
### LFO
![](https://i.imgur.com/txNyQ3s.gif)
![](https://i.imgur.com/ZG7fqr5.gif)
![](https://i.imgur.com/iw9AnxJ.gif)

### Step Sequencer
![](https://i.imgur.com/QMccvY2.gif)

### Bipolar modulation
Holding alt when assigning modulation activates bipolar modulation

![](https://i.imgur.com/5yfUGWO.gif)

### Morph
Store preset into A and B slot, and then you can morph between them:

![](https://i.imgur.com/iT91j3o.gif)

Easily edit presets' values by holding down ctrl+option, or click on 'ENTER Edit Preset Value Mode' in Morph slider's context menu: (L-click to adjust A, R-click to adjust B)

![](https://i.imgur.com/nhbBZN7.gif)

If you want to exclude some parameters from morphing, you can set it in the blacklist settings window:

![](https://i.imgur.com/IkM56Zf.gif)

### Modulation Menu
Ctrl + right click parameters.

![](https://i.imgur.com/tuWPjzK.gif)

### Parameter Linking
Right drag/drop parameters.

![](https://i.imgur.com/vUpkH8K.gif)
