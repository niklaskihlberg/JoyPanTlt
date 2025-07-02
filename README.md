# JoyPanTlt

WIP

Real-time virtual joystick controller for macOS that converts joystick/gamepad input to OSC (Open Sound Control) and/or MIDI output. For controlling dmx-software or other audio/visual software, synthesizers, digital audio workstations or live performance setups.

![JoyPanTlt Main Interface](Screenshots/screenshot-main-interface.png)

## Overview

### Core Functionality

- **Real-time virtual joystick control**
- **OSC message output**
- **MIDI Control Change (CC) output**

### Input Methods

- **Mouse control** - Click and drag for positioning
- **Keyboard control** - Arrow keys for directional control
- **Gamepad support** - Connect external joysticks/gamepads

## Requirements

- **macOS 15.0 (Sequoia) or later** 
- **Xcode 16.0 or later** (for building from source)
- **Swift 5.0+** with SwiftUI support

## Installation

### From Source

1. Clone this repository
2. Open `JoyPanTlt.xcodeproj` in Xcode
3. Build and run the project (⌘+R)

### Basic Operation

- **Control joysticks** using:
   - **Mouse**: Click and drag the joystick knob
   - **Keyboard**: Use arrow keys (↑↓←→) for momentary directional control
   - **Gamepad**: Connect a game controller
- **Settings**
   - Adjust joystick count and sensitivity
   - Set OSC destinations (host/port/address)
   - MIDI CC output
   - Configure gamepad mappings
