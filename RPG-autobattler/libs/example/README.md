# Library Usage Example

This directory contains a simple Love2D application that demonstrates how to use the installed libraries.

## Running the Example

```bash
cd libs/example
love .
```

## What it demonstrates

- **Proper library loading**: Shows how to set up Lua paths for local libraries
- **LuaSocket usage**: Creates TCP and UDP sockets
- **dkjson usage**: Encodes and decodes JSON data
- **Integration**: All libraries working together in a Love2D app

## Interactive tests

- **SPACE**: Test socket creation
- **J**: Test JSON encoding with current data
- **ESCAPE**: Quit

## Expected output

If everything is working correctly, you should see:
- "Libraries loaded successfully!"
- LuaSocket version and successful TCP socket creation
- dkjson encoding/decoding confirmation
- Real-time FPS counter

This confirms all libraries are properly installed and accessible from Love2D.