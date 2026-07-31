--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)
local Types = require(script.Parent.Types)

type Path = Types.Path

export type Profile<T> = Types.Profile<T>
export type ServerStore<T> = Types.ServerStore<T>
export type Session = Types.Session

local function getPathKey(path: Path): string
	local parts = table.create(#path)

	for index, key in path do
		parts[index] = `{typeof(key)}:{tostring(key)}`
	end

	return table.concat(parts, "/")
end

local Profile = {}
Profile.__index = Profile

function Profile.new<T>(store: ServerStore<T>, player: Player, data: T, session: Session): Profile<T>
	local self = setmetatable({
		Store = store,
		Player = player,
		Data = data,
		Session = session,

		Dirty = false,
		Released = false,
		SessionLost = false,

		Saving = false,
		SaveQueued = false,
		Revision = 0,
		LastSave = nil,

		Changed = Signal.new(),
		ChangeSignals = {},
	}, Profile) :: any

	return self
end

function Profile.Get<T>(self: Profile<T>, path: Path): any
	assert(not self.Released, "Cannot read a released profile.")

	local current: any = self.Data

	for _, key in path do
		if type(current) ~= "table" then
			return nil
		end

		current = current[key]
	end

	return current
end

function Profile.Set<T>(self: Profile<T>, path: Path, value: any): ()
	assert(not self.Released, "Cannot modify a released profile")
	assert(#path > 0, "Path cannot be empty")

	local current: any = self.Data

	for index = 1, #path - 1 do
		local key = path[index]
		local nextValue = current[key]

		assert(type(nextValue) == "table", `Invalid profile path at "{key}"`)

		current = nextValue
	end

	local finalKey = path[#path]
	local oldValue = current[finalKey]

	if oldValue == value then
		return
	end

	current[finalKey] = value
	self.Dirty = true
	self.Revision += 1

	local changedPath = table.clone(path)

	self.Changed:Fire(changedPath, value, oldValue)

	local pathKey = getPathKey(path)
	local changedSignal = self.ChangedSignals[pathKey]
	if changedSignal then
		changedSignal:Fire(value, oldValue)
	end

	local changedRemote = self.Store.ChangedRemote
	if changedRemote then
		changedRemote:FireClient(self.Player, table.clone(path), self.Store:_deepClone(value))
	end
end

function Profile.GetChangedSignal<T>(self: Profile<T>, path: Path): Signal.Signal<any, any>
	assert(not self.Released, "Cannot observe a released profile.")
	assert(#path > 0, "Path cannot be empty.")

	local pathKey = getPathKey(path)
	local changedSignal = self.ChangedSignals[pathKey]

	if not changedSignal then
		changedSignal = Signal.new()
		self.ChangedSignals[pathKey] = changedSignal
	end

	return changedSignal
end

function Profile.Update<T>(self: Profile<T>, path: Path, callback: (currentValue: any) -> any): ()
	local currentValue = self:Get(path)

	local newValue = callback(currentValue)

	self:Set(path, newValue)
end

function Profile.Save<T>(self: Profile<T>): boolean
	return self.Store:SavePlayer(self.Player)
end

function Profile.Release<T>(self: Profile<T>): boolean
	return self.Store:ReleasePlayer(self.Player)
end

function Profile.Destroy<T>(self: Profile<T>): ()
	self.Changed:Destroy()

	for _, signal in self.ChangedSignals do
		signal:Destroy()
	end

	table.clear(self.ChangedSignals)
end

return Profile
