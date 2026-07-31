--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)
local Types = require(script.Parent.Types)

type Path = Types.Path

export type ClientStore<T> = Types.ClientStore<T>
export type Profile<T> = Types.Profile<T>

local function getPathKey(path: Path): string
	local parts = table.create(#path)

	for index, key in path do
		parts[index] = `{typeof(key)}:{tostring(key)}`
	end

	return table.concat(parts, "/")
end

local ClientStore = {}
ClientStore.__index = ClientStore

function ClientStore.new<T>(name: string): ClientStore<T>
	local remotesFolder = script.Parent:WaitForChild("Remotes")
	local storeFolder = remotesFolder:WaitForChild(name)

	local self = setmetatable({
		Name = name,
		Data = nil,
		Loaded = false,

		Changed = Signal.new(),
		ChangedSignals = {},

		RequestRemote = storeFolder:WaitForChild("Request") :: RemoteEvent,
		SnapshotRemote = storeFolder:WaitForChild("Snapshot") :: RemoteEvent,
		ChangedRemote = storeFolder:WaitForChild("Changed") :: RemoteEvent,
	}, ClientStore) :: any

	self.SnapshotRemote.OnClientEvent:Connect(function(data: T)
		self.Data = data
		self.Loaded = true
	end)

	self.ChangedRemote.OnClientEvent:Connect(function(path: Path, value: any)
		self:_applyChange(path, value)
	end)

	self.RequestRemote:FireServer()

	return self
end

function ClientStore.Get<T>(self: ClientStore<T>, path: Path): any
	assert(self.Loaded, "Client data has not loaded yet.")
	assert(self.Data ~= nil, "Client data is missing.")
	assert(#path > 0, "Path cannot be empty.")

	local current = self.Data :: any

	for _, key in path do
		if type(current) ~= "table" then
			return nil
		end

		current = current[key]
	end

	return current
end

function ClientStore.GetChangedSignal<T>(self: ClientStore<T>, path: Path): Signal.Signal<any, any>
	assert(#path > 0, "Path cannot be empty.")

	local pathKey = getPathKey(path)
	local signal = self.ChangedSignals[pathKey]

	if not signal then
		signal = Signal.new()
		self.ChangedSignals[pathKey] = signal
	end

	return signal
end

function ClientStore._applyChange<T>(self: ClientStore<T>, path: Path, value: any): ()
	if not self.Loaded or self.Data == nil then
		return
	end

	local current = self.Data :: any

	for index = 1, #path - 1 do
		local key = path[index]
		local nextValue = current[key]

		if type(nextValue) ~= "table" then
			warn(`[Keystone] Invalid replicated path at "{tostring(key)}"`)
			return
		end

		current = nextValue
	end

	local finalKey = path[#path]
	local oldValue = current[finalKey]

	if oldValue == value then
		return
	end

	current[finalKey] = value

	local changedPath = table.clone(path)

	self.Changed:Fire(changedPath, value, oldValue)

	local signal = self.ChangedSignals[getPathKey(path)]
	if signal then
		signal:Fire(value, oldValue)
	end
end

function ClientStore.Destroy<T>(self: ClientStore<T>): ()
	self.Changed:Destroy()

	for _, signal in self.ChangedSignals do
		signal:Destroy()
	end

	table.clear(self.ChangedSignals)
end

return ClientStore
