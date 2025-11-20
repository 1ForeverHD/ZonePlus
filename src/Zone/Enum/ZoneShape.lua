-- ZoneShape enum for optimized spatial query method selection
-- This allows zones to use different spatial query APIs based on their shape
-- enumName, enumValue, additionalProperty (query method)
return {
	{ "Box", 1, "GetPartBoundsInBox" }, -- Optimal for box-shaped zones (aligned or rotated)
	{ "Sphere", 2, "GetPartBoundsInRadius" }, -- Optimal for spherical/circular zones
	{ "Auto", 3 }, -- Automatically determines best method based on zone parts
}
