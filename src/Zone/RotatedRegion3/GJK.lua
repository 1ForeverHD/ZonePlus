local MAX_TRIES = 20
local ZERO3 = Vector3.new(0, 0, 0)

-- Class

local GJK = {}
GJK.__index = GJK

-- Private Functions

local function tripleProduct(a, b, c)
	return b * c:Dot(a) - a * c:Dot(b)
end

local function containsOrigin(self, simplex, direction)
	local a = simplex[#simplex]
	local ao = -a

	if (#simplex == 4) then
		local b, c, d = simplex[3], simplex[2], simplex[1]
		local ab, ac, ad = b - a, c - a, d - a
		local abc, acd, adb = ab:Cross(ac), ac:Cross(ad), ad:Cross(ab)
		
		abc = abc:Dot(ad) > 0 and -abc or abc
		acd = acd:Dot(ab) > 0 and -acd or acd
		adb = adb:Dot(ac) > 0 and -adb or adb
		
		if (abc:Dot(ao) > 0) then
			table.remove(simplex, 1)
			direction = abc
		elseif (acd:Dot(ao) > 0) then
			table.remove(simplex, 2)
			direction = acd
		elseif (adb:Dot(ao) > 0) then
			table.remove(simplex, 3)
			direction = adb
		else
			return true
		end
	elseif (#simplex == 3) then
		local b, c = simplex[2], simplex[1]
		local ab, ac = b - a, c - a
		
		local abc = ab:Cross(ac)
		local abPerp = tripleProduct(ac, ab, ab).Unit
		local acPerp = tripleProduct(ab, ac, ac).Unit
		
		if (abPerp:Dot(ao) > 0) then
			table.remove(simplex, 1)
			direction = abPerp
		elseif (acPerp:Dot(ao) > 0) then
			table.remove(simplex, 2)
			direction = acPerp
		else
			local isV3 = ((a - a) == ZERO3)
			if (not isV3) then
				return true
			else
				direction = abc:Dot(ao) > 0 and abc or -abc
			end
		end
	else
		local b = simplex[1]
		local ab = b - a
		local bcPerp = tripleProduct(ab, ao, ab).Unit
		direction = bcPerp
	end
	
	return false, direction
end

-- Public Constructors

function GJK.new(SetA, SetB, CentroidA, CentroidB, SupportA, SupportB)
	local self = setmetatable({}, GJK)
	
	self.SetA = SetA
	self.SetB = SetB
	self.CentroidA = CentroidA
	self.CentroidB = CentroidB
	self.SupportA = SupportA
	self.SupportB = SupportB

	return self
end

-- Public Methods

function GJK:IsColliding()
	local direction = (self.CentroidA - self.CentroidB).Unit
	local simplex = {self.SupportA(self.SetA, direction) - self.SupportB(self.SetB, -direction)}
	
	direction = -direction
	
	for i = 1, MAX_TRIES do
		table.insert(simplex, self.SupportA(self.SetA, direction) - self.SupportB(self.SetB, -direction))
		
		if (simplex[#simplex]:Dot(direction) <= 0) then
			return false
		else
			local passed, newDirection = containsOrigin(self, simplex, direction)
			
			if (passed) then
				return true
			end
			
			direction = newDirection
		end
	end
	
	return false
end

--

return GJK