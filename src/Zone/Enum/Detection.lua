-- Important note: Precision checks currently only for 'players' and the 'localplayer', not 'parts'.

-- enumName, enumValue, additionalProperty
return {
	{"Automatic", 1}, -- ZonePlus will dynamically switch between 'WholeBody' and 'Centre' depending upon the number of players in a server (this typically only occurs for servers with 100+ players when volume checks begin to exceed 0.5% in script performance).
	{"Centre", 2}, -- A singular check will be performed on the players HumanoidRootPart
	{"WholeBody", 3}, -- Multiple checks will be casted over an entire players character
}