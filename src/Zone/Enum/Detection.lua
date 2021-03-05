-- Important note: Precision checks currently only for 'players' and the 'localplayer', not 'parts'.

-- enumName, enumValue, additionalProperty
return {
	{"Automatic", 1}, -- ZonePlus will dynamically switch between 'WholeBody' and 'Centre' depending upon the number of players in a server (this typically only occurs for servers with 100+ players when volume checks begin to exceed 0.5% in script performance).
	{"Centre", 2}, -- A tiny lightweight Region3 check will be casted at the centre of the player of part
	{"WholeBody", 3}, -- A RotatedRegion3 check will be casted over a player or parts entire body
}