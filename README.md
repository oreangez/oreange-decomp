# oreange decomp

Usage of AI is prohibited using this script. 
If you fork/update this script, please make sure to credit me!
Found bugs? contact @oreangez on discord

A fast, standalone Roblox place saver and script decompiler. It saves games, extracts meshes, downloads textures, and decompiles scripts all in one go. Files are neatly organized into an `oreange decomp` folder in your executor's workspace directory.

## Features
- Saves the entire place or specific models/instances.
- Decompiles client scripts using a local or remote decompiler.
- Extracts meshes (`.mesh`) and textures (`.png`) directly from the game.
- Automatically fetches the game's real name for the file save (instead of just "Place ID").
- Minimalist, clean UI in the top-right corner (no annoying backgrounds).
- Silent mode for console logs.

---

## PARAMS (Options you can use)

When you run the loadstring, you can pass a table of parameters to change how the script works. 

Here is the exact syntax to pass params:
`loadstring(...)(command, instance, options)`

### Every Param you can use:

- `DisableLogs` *(boolean)*: Set to `true` to completely silence the developer console. (No print spam).
- `SavePlayers` *(boolean)*: Set to `false` to exclude player instances from the save file.
- `SavePlayerCharacters` *(boolean)*: Set to `false` to exclude player character models.
- `DecompileScripts` *(boolean)*: Set to `false` to skip downloading and decompiling scripts (makes saving faster).
- `SaveMeshes` *(boolean)*: Set to `false` to skip extracting 3D meshes.
- `SaveImages` *(boolean)*: Set to `false` to skip downloading textures and images.
- `IgnoreList` *(table)*: A table of specific Instances you want the script to ignore.
- `IgnoreArchivable` *(boolean)*: Set to `true` to skip instances where `Archivable = false`.
- `SaveNilInstances` *(boolean)*: Set to `false` to skip instances not parented to the game.
- `DisableCompression` *(boolean)*: Set to `true` to turn off ZSTD compression.
- `FilePath` *(string)*: Provide a custom file path. Leave empty to auto-generate using the game name.
- `CopyToClipboard` *(boolean)*: Set to `true` to copy the data to your clipboard instead of saving to a file.

---

## Loadstring Examples

### Just load the script
If you just want to load the script and expose the `saveplace` and `saveinstance` globals to your executor:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/oreangez/oreange-decomp/refs/heads/main/main.luau"))("saveplace", {
    DisableLogs = true,
    SavePlayers = false,
    SavePlayerCharacters = false,
    DecompileScripts = false
})
