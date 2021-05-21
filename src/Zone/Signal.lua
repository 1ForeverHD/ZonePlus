-- Signal
-- Author: Stephen Leitnick
-- Source: https://github.com/Sleitnick/AeroGameFramework/blob/43e4e02717e36ac83c820abc4461fb8afa2cd967/src/ReplicatedStorage/Aero/Shared/Signal.lua
-- License: MIT (https://github.com/Sleitnick/AeroGameFramework/blob/master/LICENSE)
-- Modified for use in Nanoblox


local Connection = {}
Connection.__index = Connection

function Connection.new(signal, connection)
	local self = setmetatable({
		_signal = signal;
		_conn = connection;
		Connected = true;
	}, Connection)
	return self
end

function Connection:Disconnect()
	if (self._conn) then
		self._conn:Disconnect()
		self._conn = nil
	end
	if (not self._signal) then return end
	self.Connected = false
	local connections = self._signal._connections
	local connectionIndex = table.find(connections, self)
	if (connectionIndex) then
		local n = #connections
		connections[connectionIndex] = connections[n]
		connections[n] = nil
	end
	self._signal = nil
end

function Connection:IsConnected()
	if (self._conn) then
		return self._conn.Connected
	end
	return false
end

Connection.Destroy = Connection.Disconnect

--------------------------------------------

local Signal = {}
Signal.totalConnections = 0
Signal.__index = Signal


function Signal.new(trackConnectionsChanged)
	local self = setmetatable({
		_bindable = Instance.new("BindableEvent");
		_connections = {};
		_args = {};
		_threads = 0;
		_id = 0;
	}, Signal)
	if trackConnectionsChanged then
		self.connectionsChanged = Signal.new()
	end
	return self
end

function Signal:_setProxy(rbxScriptSignal)
	assert(typeof(rbxScriptSignal) == "RBXScriptSignal", "Argument #1 must be of type RBXScriptSignal")
	self:_clearProxy()
	self._proxyHandle = rbxScriptSignal:Connect(function(...)
		self:Fire(...)
	end)
end


function Signal:_clearProxy()
	if (self._proxyHandle) then
		self._proxyHandle:Disconnect()
		self._proxyHandle = nil
	end
end


function Signal:Fire(...)
	local totalListeners = (#self._connections + self._threads)
	if (totalListeners == 0) then return end
	local id = self._id
	self._id += 1
	self._args[id] = {totalListeners, {n = select("#", ...), ...}}
	self._threads = 0
	self._bindable:Fire(id)
end


function Signal:Wait()
	self._threads += 1
	local id = self._bindable.Event:Wait()
	local args = self._args[id]
	args[1] -= 1
	if (args[1] <= 0) then
		self._args[id] = nil
	end
	return table.unpack(args[2], 1, args[2].n)
end


function Signal:Connect(handler)
	local connection = Connection.new(self, self._bindable.Event:Connect(function(id)
		local args = self._args[id]
		args[1] -= 1
		if (args[1] <= 0) then
			self._args[id] = nil
		end
		handler(table.unpack(args[2], 1, args[2].n))
	end))
	table.insert(self._connections, connection)
	--
	-- this enables us to determine when a signal is connected to from an outside source
	self.totalConnections += 1
	if self.connectionsChanged then
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
	--
	return connection
end


function Signal:DisconnectAll()
	for _,c in ipairs(self._connections) do
		if (c._conn) then
			c._conn:Disconnect()
		end
	end
	self._connections = {}
	self._args = {}
end


function Signal:Destroy()
	self:DisconnectAll()
	self:_clearProxy()
	self._bindable:Destroy()
	if self.connectionsChanged then
		self.connectionsChanged:Fire(-self.totalConnections)
		self.connectionsChanged:Destroy()
		self.connectionsChanged = nil
		self.totalConnections = 0
	end
end
Signal.destroy = Signal.Destroy
Signal.Disconnect = Signal.Destroy
Signal.Disconnect = Signal.Destroy


return Signal