-- Important note: Precision checks currently only for 'players' and the 'localplayer', not 'parts'.

-- enumName, enumValue, additionalProperty
return {
	{"WholeBody", 1}, -- Multiple checks will be casted over an entire players character
	{"Centre", 2}, -- A singular check will be performed on the players HumanoidRootPart
	--{"Automatic", 3}, -- REMOVED DUE TO UNECESSARY COMPLEXITY. ZonePlus will dynamically switch between 'WholeBody' and 'Centre' depending upon the number of players in a server (this typically only occurs for servers with 100+ players when volume checks begin to exceed 0.5% in script performance).
}