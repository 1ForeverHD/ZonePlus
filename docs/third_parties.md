It's important only a single ZonePlus applications initiates at runtime otherwise its optimisations will diminish and other issues may occur.

A developer may rename and/or place their Zone module anywhere within ReplicatedStorage therefore it's important for third party runtime applications (such as admin commands) to check and reference this correctly.

To achieve this:

1. When initiated, an ObjectValue called ``ZonePlusReference`` is added directly under ``ReplicatedStorage``.
2. Check for this. If present, require its value otherwise initiate your own ZonePlus.

```lua
local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")

-- This checks for the reference module under ReplicatedStorage
local zonePlusReference = replicatedStorage:FindFirstChild("ZonePlusReference")
local zoneModule = pathway.to.your.zoneplus
if zonePlusReference then
	zoneModule = zonePlusReference.Value
end

-- Now use ZonePlus as normal
local Zone = require(zoneModule)
local zone = Zone.new(zoneGroup)
```
