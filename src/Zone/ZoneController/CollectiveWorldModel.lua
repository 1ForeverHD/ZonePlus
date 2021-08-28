local CollectiveWorldModel = {}
local worldModel
local runService = game:GetService("RunService")



-- FUNCTIONS
function CollectiveWorldModel.setupWorldModel(zone)
	if worldModel then
		return worldModel
	end
	local location = (runService:IsClient() and "ReplicatedStorage") or "ServerStorage"
	worldModel = Instance.new("WorldModel")
	worldModel.Name = "ZonePlusWorldModel"
	worldModel.Parent = game:GetService(location)
	return worldModel
end



-- METHODS
function CollectiveWorldModel:_getCombinedResults(methodName, ...)
	local results = workspace[methodName](workspace, ...)
	if worldModel then
		local additionalResults = worldModel[methodName](worldModel, ...)
		for _, result in pairs(additionalResults) do
			table.insert(results, result)
		end
	end
	return results
end

function CollectiveWorldModel:GetPartBoundsInBox(cframe, size, overlapParams)
	return self:_getCombinedResults("GetPartBoundsInBox", cframe, size, overlapParams)
end

function CollectiveWorldModel:GetPartBoundsInRadius(position, radius, overlapParams)
	return self:_getCombinedResults("GetPartBoundsInRadius", position, radius, overlapParams)
end

function CollectiveWorldModel:GetPartsInPart(part, overlapParams)
	return self:_getCombinedResults("GetPartsInPart", part, overlapParams)
end



return CollectiveWorldModel