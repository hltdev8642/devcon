# Creating a Laser Pointer Tool VOX File

The laser pointer tool needs a visual model (.vox file) to appear in Teardown's tool inventory.

## Option 1: Use MagicaVoxel (Recommended)

1. Download and install [MagicaVoxel](https://ephtracy.github.io/)
2. Create a new scene (32x32x32 recommended)
3. Design a laser pointer tool model (e.g., a gun-like shape with a red tip)
4. Export as `.vox` file to `lasertool/laserpointer.vox`

## Option 2: Download Pre-made Model

You can find Teardown tool models online or create a simple placeholder.

## Option 3: Use Existing Tool Model (Temporary)

For testing, you can temporarily copy an existing tool's .vox file:
```
copy "path\to\existing\tool.vox" "lasertool\laserpointer.vox"
```

## Model Requirements

- **Format**: MagicaVoxel .vox format
- **Size**: Typically 32x32x32 voxels or smaller
- **Colors**: Use palette colors that fit the laser pointer theme
- **Orientation**: Pointing forward (positive Z direction)

## Testing the Tool

Once you have a .vox file:
1. Launch Teardown
2. Enable the devcon mod
3. Look for "Laser Pointer" in your tool inventory
4. Select it and test the laser beam and selection

## Troubleshooting

- **Tool not appearing**: Check that the .vox file exists and is valid
- **Tool not working**: Ensure the main.lua file is properly registered
- **Registry issues**: Check that selections are stored correctly