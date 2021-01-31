-- This module enables you to place Zone wherever you like within the data model while
-- still enabling third-party applications (such as HDAdmin/Nanoblox) to locate it
-- This is necessary to prevent two ZonePlus applications initiating at runtime which would
-- diminish it's overall efficiency

local replicatedStorage = game:GetService("ReplicatedStorage")
local ZonePlusReference = {}

function ZonePlusReference.addToReplicatedStorage()
    local existingItem = replicatedStorage:FindFirstChild(script.Name)
    if existingItem then
        return false
    end
    local objectValue = Instance.new("ObjectValue")
    objectValue.Name = script.Name
    objectValue.Value = script.Parent
    objectValue.Parent = replicatedStorage
    local locationValue = Instance.new("BoolValue")
    locationValue.Name = (game:GetService("RunService"):IsClient() and "Client") or "Server"
    locationValue.Value = true
    locationValue.Parent = objectValue
    return objectValue
end

function ZonePlusReference.getObject()
    local objectValue = replicatedStorage:FindFirstChild(script.Name)
    if objectValue then
        return objectValue
    end
    return false
end

return ZonePlusReference