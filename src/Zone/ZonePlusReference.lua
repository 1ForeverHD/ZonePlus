-- This module enables you to place Zone wherever you like within the data model while
-- still enabling third-party applications (such as HDAdmin/Nanoblox) to locate it
-- This is necessary to prevent two ZonePlus applications initiating at runtime which would
-- diminish it's overall efficiency

local replicatedStorage = game:GetService("ReplicatedStorage")
local ZonePlusReference = {
    container = script.Parent
}

function ZonePlusReference.moveToReplicatedStorage()
    local existingItem = replicatedStorage:FindFirstChild(script.Name)
    if existingItem then
        warn(("Failed to move the ZonePlus reference to ReplicatedStorage as instance '%s' already exists."):format(script.Name))
        return false
    end
    script.Parent = replicatedStorage
    return true
end

return ZonePlusReference