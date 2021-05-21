--[[
This is a simplified version of Quenty's Nevemore Signal Class.
I've stripped this down for improved traceback debugging as I don't mind if the table received is not the same which was passed.
If passing the same table is important for you, see: https://github.com/Quenty/NevermoreEngine/blob/a98f213bb46a3c1dbe311b737689c5cc820a4901/Modules/Shared/Events/Signal.lua
--]]



local Signal = {}
Signal.__index = Signal
Signal.ClassName = "Signal"
Signal.totalConnections = 0



-- CONSTRUCTOR
function Signal.new(trackConnectionsChanged)
	local self = setmetatable({}, Signal)

	self._bindableEvent = Instance.new("BindableEvent")
	if trackConnectionsChanged then
		self.connectionsChanged = Signal.new()
	end

	return self
end



-- METHODS
function Signal:Fire(...)
	self._bindableEvent:Fire(...)
end

function Signal:Connect(handler)
	if not (type(handler) == "function") then
		error(("connect(%s)"):format(typeof(handler)), 2)
	end
	
	local connection = self._bindableEvent.Event:Connect(function(...)
		handler(...)
	end)
	
	-- If ``true`` is passed for trackConnectionsChanged within the constructor this will track the amount of active connections
	if self.connectionsChanged then
		self.totalConnections += 1
		self.connectionsChanged:Fire(1)
		local heartbeatConection
		heartbeatConection = game:GetService("RunService").Heartbeat:Connect(function()
			if connection.Connected == false then
				heartbeatConection:Disconnect()
				if self.connectionsChanged then
					self.totalConnections -= 1
					self.connectionsChanged:Fire(-1)
				end
			end
		end)
	end

	return connection
end

function Signal:Wait()
	local args = self._bindableEvent.Event:Wait()
	return unpack(args)
end

function Signal:Destroy()
	if self._bindableEvent then
		self._bindableEvent:Destroy()
		self._bindableEvent = nil
	end
	if self.connectionsChanged then
		self.connectionsChanged:Fire(-self.totalConnections)
		self.connectionsChanged:Destroy()
		self.connectionsChanged = nil
		self.totalConnections = 0
	end
end
Signal.destroy = Signal.Destroy
Signal.Disconnect = Signal.Destroy
Signal.disconnect = Signal.Destroy



return Signal