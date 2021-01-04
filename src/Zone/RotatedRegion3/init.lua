-- RotatedRegion3
-- Author: EgoMoose
-- Source: https://devforum.roblox.com/t/rotated-region-3-module/334068

--[[

This is a Rotated Region3 Class that behaves much the same as the standard Region3 class expect that it allows
for both rotated regions and also a varying array of shapes.	

API:

Constructors:
	RotatedRegion3.new(CFrame cframe, Vector3 size)
		> Creates a region from a cframe which acts as the center of the region and size which extends to 
		> the corners like a block part.
	RotatedRegion3.Block(CFrame cframe, Vector3 size)
		> This is the exact same as the region.new constructor, but has a different name.
	RotatedRegion3.Wedge(CFrame cframe, Vector3 size)
		> Creates a region from a cframe which acts as the center of the region and size which extends to 
		> the corners like a wedge part.
	RotatedRegion3.CornerWedge(CFrame cframe, Vector3 size)
		> Creates a region from a cframe which acts as the center of the region and size which extends to 
		> the corners like a cornerWedge part.
	RotatedRegion3.Cylinder(CFrame cframe, Vector3 size)
		> Creates a region from a cframe which acts as the center of the region and size which extends to 
		> the corners like a cylinder part.
	RotatedRegion3.Ball(CFrame cframe, Vector3 size)
		> Creates a region from a cframe which acts as the center of the region and size which extends to 
		> the corners like a ball part.
	RotatedRegion3.FromPart(part)
		> Creates a region from a part in the game. It can be used on any base part, but the region 
		> will treat unknown shapes (meshes, unions, etc) as block shapes.

Methods:
	RotatedRegion3:CastPoint(Vector3 point)
		> returns true or false if the point is within the RotatedRegion3 object
	RotatedRegion3:CastPart(BasePart part)
		> returns true or false if the part is withing the RotatedRegion3 object
	RotatedRegion3:FindPartsInRegion3(Instance ignore, Integer maxParts)
		> returns array of parts in the RotatedRegion3 object
		> will return a maximum number of parts in array [maxParts] the default is 20
		> parts that either are descendants of or actually are the [ignore] instance will be ignored
	RotatedRegion3:FindPartsInRegion3WithIgnoreList(Instance Array ignore, Integer maxParts)
		> returns array of parts in the RotatedRegion3 object
		> will return a maximum number of parts in array [maxParts] the default is 20
		> parts that either are descendants of the [ignore array] or actually are the [ignore array] instances will be ignored
	RotatedRegion3:FindPartsInRegion3WithWhiteList(Instance Array whiteList, Integer maxParts)
		> returns array of parts in the RotatedRegion3 object
		> will return a maximum number of parts in array [maxParts] the default is 20
		> parts that either are descendants of the [whiteList array] or actually are the [whiteList array] instances are all that will be checked
	RotatedRegion3:Cast(Instance or Instance Array ignore, Integer maxParts)
		> Same as the `:FindPartsInRegion3WithIgnoreList` method, but will check if the ignore argument is an array or single instance

Properties:
	RotatedRegion3.CFrame
		> cframe that represents the center of the region
	RotatedRegion3.Size
		> vector3 that represents the size of the region
	RotatedRegion3.Shape
		> string that represents the shape type of the RotatedRegion3 object
	RotatedRegion3.Set
		> array of vector3 that are passed to the support function
	RotatedRegion3.Support
		> function that is used for support in the GJK algorithm
	RotatedRegion3.Centroid
		> vector3 that represents the center of the set, again used for the GJK algorithm
	RotatedRegion3.AlignedRegion3
		> standard region3 that represents the world bounding box of the RotatedRegion3 object

Note: I haven't actually done anything to enforce this, but you should treat all these properties as read only

Enjoy!
- EgoMoose

--]]

--

local GJK = require(script:WaitForChild("GJK"))
local Supports = require(script:WaitForChild("Supports"))
local Vertices = require(script:WaitForChild("Vertices"))

-- Class

local RotatedRegion3 = {}
RotatedRegion3.__index = RotatedRegion3

-- Private functions

local function getCorners(cf, s2)
	return {
		cf:PointToWorldSpace(Vector3.new(-s2.x, s2.y, s2.z));
		cf:PointToWorldSpace(Vector3.new(-s2.x, -s2.y, s2.z));
		cf:PointToWorldSpace(Vector3.new(-s2.x, -s2.y, -s2.z));
		cf:PointToWorldSpace(Vector3.new(s2.x, -s2.y, -s2.z));
		cf:PointToWorldSpace(Vector3.new(s2.x, s2.y, -s2.z));
		cf:PointToWorldSpace(Vector3.new(s2.x, s2.y, s2.z));
		cf:PointToWorldSpace(Vector3.new(s2.x, -s2.y, s2.z));
		cf:PointToWorldSpace(Vector3.new(-s2.x, s2.y, -s2.z));
	}
end

local function worldBoundingBox(set)
	local x, y, z = {}, {}, {}
	for i = 1, #set do x[i], y[i], z[i] = set[i].x, set[i].y, set[i].z end
	local min = Vector3.new(math.min(unpack(x)), math.min(unpack(y)), math.min(unpack(z)))
	local max = Vector3.new(math.max(unpack(x)), math.max(unpack(y)), math.max(unpack(z)))
	return min, max
end

-- Public Constructors

function RotatedRegion3.new(cframe, size)
	local self = setmetatable({}, RotatedRegion3)
	
	self.CFrame = cframe
	self.Size = size
	self.Shape = "Block"
	
	self.Set = Vertices.Block(cframe, size/2)
	self.Support = Supports.PointCloud
	self.Centroid = cframe.p
	
	self.AlignedRegion3 = Region3.new(worldBoundingBox(self.Set))

	return self
end

RotatedRegion3.Block = RotatedRegion3.new

function RotatedRegion3.Wedge(cframe, size)
	local self = setmetatable({}, RotatedRegion3)

	self.CFrame = cframe
	self.Size = size
	self.Shape = "Wedge"
	
	self.Set = Vertices.Wedge(cframe, size/2)
	self.Support = Supports.PointCloud
	self.Centroid = Vertices.GetCentroid(self.Set)
	
	self.AlignedRegion3 = Region3.new(worldBoundingBox(self.Set))

	return self
end

function RotatedRegion3.CornerWedge(cframe, size)
	local self = setmetatable({}, RotatedRegion3)

	self.CFrame = cframe
	self.Size = size
	self.Shape = "CornerWedge"
	
	self.Set = Vertices.CornerWedge(cframe, size/2)
	self.Support = Supports.PointCloud
	self.Centroid = Vertices.GetCentroid(self.Set)
	
	self.AlignedRegion3 = Region3.new(worldBoundingBox(self.Set))

	return self
end

function RotatedRegion3.Cylinder(cframe, size)
	local self = setmetatable({}, RotatedRegion3)

	self.CFrame = cframe
	self.Size = size
	self.Shape = "Cylinder"
	
	self.Set = {cframe, size/2}
	self.Support = Supports.Cylinder
	self.Centroid = cframe.p
	
	self.AlignedRegion3 = Region3.new(worldBoundingBox(getCorners(unpack(self.Set))))

	return self
end

function RotatedRegion3.Ball(cframe, size)
	local self = setmetatable({}, RotatedRegion3)

	self.CFrame = cframe
	self.Size = size
	self.Shape = "Ball"
	
	self.Set = {cframe, size/2}
	self.Support = Supports.Ellipsoid
	self.Centroid = cframe.p
	
	self.AlignedRegion3 = Region3.new(worldBoundingBox(getCorners(unpack(self.Set))))

	return self
end

function RotatedRegion3.FromPart(part)
	return RotatedRegion3[Vertices.Classify(part)](part.CFrame, part.Size)
end

-- Public Constructors

function RotatedRegion3:CastPoint(point)
	local gjk = GJK.new(self.Set, {point}, self.Centroid, point, self.Support, Supports.PointCloud)
	return gjk:IsColliding()
end

function RotatedRegion3:CastPart(part)
	local r3 = RotatedRegion3.FromPart(part)
	local gjk = GJK.new(self.Set, r3.Set, self.Centroid, r3.Centroid, self.Support, r3.Support)
	return gjk:IsColliding()
end

function RotatedRegion3:FindPartsInRegion3(ignore, maxParts)
	local found = {}
	local parts = game.Workspace:FindPartsInRegion3(self.AlignedRegion3, ignore, maxParts)
	for i = 1, #parts do
		if (self:CastPart(parts[i])) then
			table.insert(found, parts[i])
		end
	end
	return found
end

function RotatedRegion3:FindPartsInRegion3WithIgnoreList(ignore, maxParts)
	ignore = ignore or {}
	local found = {}
	local parts = game.Workspace:FindPartsInRegion3WithIgnoreList(self.AlignedRegion3, ignore, maxParts)
	for i = 1, #parts do
		if (self:CastPart(parts[i])) then
			table.insert(found, parts[i])
		end
	end
	return found
end

function RotatedRegion3:FindPartsInRegion3WithWhiteList(whiteList, maxParts)
	whiteList = whiteList or {}
	local found = {}
	local parts = game.Workspace:FindPartsInRegion3WithWhiteList(self.AlignedRegion3, whiteList, maxParts)
	for i = 1, #parts do
		if (self:CastPart(parts[i])) then
			table.insert(found, parts[i])
		end
	end
	return found
end

function RotatedRegion3:Cast(ignore, maxParts)
	ignore = type(ignore) == "table" and ignore or {ignore}
	return self:FindPartsInRegion3WithIgnoreList(ignore, maxParts)
end

--

return RotatedRegion3