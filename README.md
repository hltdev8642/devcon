# Lua Console Overlay Mod for Teardown

A comprehensive interactive console overlay for Teardown that provides debugging, scripting, and registry management capabilities.

## Features

- **Interactive Console**: Toggleable semi-transparent overlay console
- **Command Completion**: Tab-completion for Teardown API functions
- **Registry Management**: List, get, set, and delete registry keys
- **Lua Execution**: Execute Lua code directly in the console
- **Command History**: Navigate through previous commands with arrow keys
- **Log Output**: Display console output with timestamps
- **Configurable Settings**: Customize appearance and behavior
- **Session Persistence**: Save and restore console state between sessions

## Installation

1. Download the mod files
2. Place the `devcon` folder in your Teardown mods directory:
   ```
   %USERPROFILE%\Documents\Teardown\mods\devcon\
   ```
3. Ensure the following files are present:
   - `info.txt` - Mod metadata
   - `main.lua` - Main mod script (includes embedded options)

## Usage

### Basic Controls

- **Toggle Console**: Press the `~` (grave) key to show/hide the console
- **Enter Commands**: Type commands and press Enter to execute
- **Command History**: Use Up/Down arrow keys to navigate history
- **Text Editing**: Use Left/Right arrows to move cursor, Backspace/Delete to edit
- **Tab Completion**: Press Tab to auto-complete API function names

### Available Commands

#### General Commands
- `help` or `?` - Show available commands
- `clear` - Clear the console log

#### Registry Commands
- `reg list [path]` - List registry keys (optional path filter)
- `reg get <key>` - Get registry value
- `reg set <key> <value>` - Set registry value
- `reg delete <key>` - Delete registry key

#### Lua Execution
- `lua <code>` - Execute Lua code
- Or simply enter any Lua expression directly

### Examples

```lua
-- Get player position
GetPlayerTransform()

-- Set a registry value
reg set mymod.testvalue 42

-- List all registry keys
reg list

-- Execute Lua code
lua print("Hello from console!")

-- Direct Lua execution
Vec(1, 2, 3)
```

## Configuration

Settings are embedded in `main.lua` and can be modified there:

- **opacity**: Console background transparency (0.1 - 1.0)
- **width/height**: Console dimensions in pixels
- **fontSize**: Text size
- **maxLogs**: Maximum number of log lines to keep
- **toggleKey**: Key to toggle console (default: "grave")

Settings are automatically saved to the registry.

## API Reference

The console includes tab-completion for all Teardown API functions. Common categories:

- **UI Functions**: UiText, UiRect, UiColor, etc.
- **Entity Functions**: FindBody, GetBodyTransform, etc.
- **Input Functions**: InputPressed, InputValue, etc.
- **Registry Functions**: GetInt, SetString, etc.
- **Math Functions**: Vec, Quat, Transform, etc.

## Troubleshooting

- **Console not appearing**: Ensure the mod is enabled in Teardown's mod menu
- **Commands not working**: Check the console log for error messages
- **Performance issues**: Reduce maxLogs or console size in options.lua
- **Tab completion not working**: Ensure API functions are loaded (check init message)

## Development

The mod is written in Lua 5.1 and uses Teardown's modding API. Key files:

- `main.lua`: Main logic with console UI and command processing
- `options.lua`: Configuration management
- `info.txt`: Mod metadata for Teardown's mod loader

## Compatibility

- **Teardown Version**: 1.7.0+
- **Platform**: Windows, Linux, macOS
- **Dependencies**: None (self-contained)

## License

This mod is provided as-is for educational and entertainment purposes.