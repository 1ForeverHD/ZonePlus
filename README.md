# ZonePlus - Modern Spatial Query Edition

[![Documentation](https://img.shields.io/badge/docs-site-blue)](https://devforum.roblox.com/t/zone/1017701)

ZonePlus is a powerful and efficient zone detection library for Roblox, now fully modernized to leverage Roblox's latest spatial query APIs.

## 🚀 What's New - Modern Spatial Query Update (v4.0.0)

ZonePlus has been completely modernized to use Roblox's current spatial query APIs:

### Key Improvements

✅ **Modern Spatial Query APIs**

- Replaced deprecated `Region3` with `CFrame + Size` approach
- Full integration with `WorldRoot:GetPartBoundsInBox`
- Full integration with `WorldRoot:GetPartBoundsInRadius` for spherical zones
- Full integration with `WorldRoot:GetPartsInPart` for precise geometry checks

✅ **Updated FilterType Enums**

- Migrated from deprecated `Whitelist/Blacklist` to modern `Include/Exclude`
- Optimized `OverlapParams` reuse for better performance

✅ **New Zone Shape Support**

- `Zone.fromBox(cframe, size)` - Optimized box-shaped zones using `GetPartBoundsInBox`
- `Zone.fromSphere(position, radius)` - Optimized spherical zones using `GetPartBoundsInRadius`
- Auto-detection for optimal spatial query method based on zone geometry

✅ **Performance Optimizations**

- Reusable `OverlapParams` objects to reduce garbage collection
- Smart spatial query method selection based on zone shape
- Efficient filtering using modern collision detection

## 📚 Spatial Query API Comparison

### Roblox Spatial Query Methods Used

| API Method              | Use Case                           | Performance                 |
| ----------------------- | ---------------------------------- | --------------------------- |
| `GetPartBoundsInBox`    | Box-shaped zones (rotated/aligned) | ⚡ Very Fast (bounding box) |
| `GetPartBoundsInRadius` | Spherical/radial zones             | ⚡ Very Fast (bounding box) |
| `GetPartsInPart`        | Precise geometry checks            | ⚠️ Slower (precise overlap) |

ZonePlus automatically selects the best method based on your zone configuration.

## 🎯 Quick Start

```lua
local Zone = require(game.ReplicatedStorage.Zone)

-- Create a traditional zone from a container
local container = workspace.SafeZone
local zone = Zone.new(container)

-- Or create an optimized box zone
local boxZone = Zone.fromBox(
    CFrame.new(0, 10, 0),
    Vector3.new(50, 20, 50)
)

-- Or create an optimized spherical zone
local sphereZone = Zone.fromSphere(
    Vector3.new(0, 10, 0),
    25 -- radius
)

-- Connect to events
zone.playerEntered:Connect(function(player)
    print(player.Name .. " entered the zone!")
end)

zone.playerExited:Connect(function(player)
    print(player.Name .. " left the zone!")
end)
```

## 🔧 Advanced Configuration

### Zone Shape Optimization

```lua
-- Manually set the spatial query method
zone:setZoneShape("Box")    -- Use GetPartBoundsInBox
zone:setZoneShape("Sphere") -- Use GetPartBoundsInRadius
zone:setZoneShape("Auto")   -- Auto-detect (default)
```

### Detection Modes

```lua
-- Set detection precision
zone:setAccuracy("High")    -- 0.1 second checks
zone:setAccuracy("Medium")  -- 0.5 second checks
zone:setAccuracy("Low")     -- 1.0 second checks
zone:setAccuracy("Precise") -- Every frame (0.0)

-- Set detection method
zone:setDetection("Centre")    -- Check HumanoidRootPart only (faster)
zone:setDetection("WholeBody") -- Check entire character (more accurate)
```

## 📖 Documentation

For comprehensive documentation including:

- API reference
- Advanced examples
- Best practices
- Migration guides

Visit the [ZonePlus Documentation Site](https://devforum.roblox.com/t/zone/1017701)

## 💡 Performance Tips

1. **Reuse OverlapParams**: ZonePlus now automatically reuses OverlapParams objects
2. **Choose the right shape**: Use `fromSphere()` for radial zones, `fromBox()` for rectangular zones
3. **Optimize accuracy**: Use lower accuracy settings when possible
4. **Use Centre detection**: For large zones with many players, Centre detection is much faster

## 🔄 Migration from Old Region3 Code

If you were using older ZonePlus versions, your existing code will continue to work! The modernization is backward-compatible. However, we recommend:

1. Using the new `fromBox()` and `fromSphere()` constructors for new zones
2. Checking that zones work as expected (internal representation changed from Region3 to CFrame+Size)

## 🐛 Known Limitations

- Collision group edge cases: Parts in the same collision group may not always be detected (Roblox engine limitation)
- Performance with distant parts: Many parts far from query regions can cause performance degradation (Roblox engine limitation)

## 📝 License

See LICENSE file for details.

## 🙏 Credits

Original ZonePlus by nanoblox
Modern Spatial Query Update - 2025

---

For support and discussions, visit the [DevForum thread](https://devforum.roblox.com/t/zone/1017701)
