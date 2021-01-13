-- This module enables you to place Zone wherever you like within the data model while
-- still enabling third-party applications (such as HDAdmin/Nanoblox) to locate it
-- This is necessary to prevent two ZonePlus applications initiating at runtime which would
-- diminish it's overall efficiency

local replicatedStorage = game:GetService("ReplicatedStorage")
local ZonePlusReference = {
    container = script.Parent
}

function ZonePlusReference.addToReplicatedStorage()
    local existingItem = replicatedStorage:FindFirstChild(script.Name)
    if existingItem then
        return false
    end
    script:Clone().Parent = replicatedStorage
    return true
end

return ZonePlusReference