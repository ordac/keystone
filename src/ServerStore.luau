--!strict
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Profile = require(script.Parent.Profile)
local Types = require(script.Parent.Types)

export type ServerStore<T> = Types.ServerStore<T>
export type StoreProps<T> = Types.StoreProps<T>
export type Profile<T> = Types.Profile<T>
export type Session = Types.Session
export type SessionMetadata = Types.SessionMetadata

local function getOrCreateFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)

	if existing then
		assert(existing:IsA("Folder"))
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent

	return folder
end

local function getOrCreateRemote(parent: Instance, name: string): RemoteEvent
	local existing = parent:FindFirstChild(name)

	if existing then
		assert(existing:IsA("RemoteEvent"))
		return existing
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent

	return remote
end

local ServerStore = {}
ServerStore.__index = ServerStore

function ServerStore.new<T>(props: StoreProps<T>): ServerStore<T>
	local self = setmetatable({
		Name = props.Name,
		Template = props.Template,

		Profiles = {},

		DataStore = DataStoreService:GetDataStore(props.Name),

		SaveAttempts = props.SaveAttempts or 5,
		RetryDelay = props.RetryDelay or 2,

		AutosaveInterval = props.AutosaveInterval or 60,
		Running = false,

		SessionLockExpiration = props.SessionLockExpiration or 300,
		SessionLockRetryDelay = props.SessionLockRetryDelay or 5,
		SessionLockMaxWait = props.SessionLockMaxWait or 30,
	}, ServerStore) :: any

	return self
end

function ServerStore.Start<T>(self: ServerStore<T>): ()
	assert(not self.Running, "Store is already running.")

	self.Running = true

	local remoteFolder = getOrCreateFolder(script.Parent, "Remotes")
	local storeFolder = getOrCreateFolder(remoteFolder, self.Name)

	self.RequestRemote = getOrCreateRemote(storeFolder, "Request")
	self.SnapshotRemote = getOrCreateRemote(storeFolder, "Snapshot")
	self.ChangedRemote = getOrCreateRemote(storeFolder, "Changed")

	if self.RequestRemote and self.SnapshotRemote then
		self.RequestRemote.OnServerEvent:Connect(function(player: Player)
			local profile = self.Profiles[player]

			if not profile or profile.Released or profile.SessionLost then
				return
			end

			self.SnapshotRemote:FireClient(player, self:_deepClone(profile.Data))
		end)
	end

	self:_startAutosave()
	self:_bindToClose()

	Players.PlayerAdded:Connect(function(player: Player)
		local profile = self:LoadPlayer(player)

		if not profile and player.Parent == Players then
			player:Kick("Your data could not be loaded. Please rejoin.")
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self:ReleasePlayer(player)
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			local profile = self:LoadPlayer(player)

			if not profile and player.Parent == Players then
				player:Kick("Your data could not be loaded. Please rejoin.")
			end
		end)
	end
end

function ServerStore.LoadPlayer<T>(self: ServerStore<T>, player: Player): Profile<T>?
	local existingProfile = self.Profiles[player]

	if existingProfile then
		return existingProfile
	end

	local session: Session = {
		Id = HttpService:GenerateGUID(false),
	}

	local data = self:_load(player, session)

	if not data then
		return nil
	end

	if player.Parent ~= Players then
		local temporaryProfile = self:_createProfile(player, data, session)
		self:_release(temporaryProfile)

		return nil
	end

	local profile = self:_createProfile(player, data, session)
	self.Profiles[player] = profile

	local snapshotRemote = self.SnapshotRemote
	if snapshotRemote then
		snapshotRemote:FireClient(player, self:_deepClone(profile.Data))
	end

	return profile
end

function ServerStore.ReleasePlayer<T>(self: ServerStore<T>, player: Player): boolean
	local profile = self.Profiles[player]

	if not profile then
		return false
	end

	return self:_release(profile)
end

function ServerStore.SavePlayer<T>(self: ServerStore<T>, player: Player): boolean
	local profile = self.Profiles[player]

	if not profile then
		return false
	end

	return self:_save(profile)
end

function ServerStore.GetProfile<T>(self: ServerStore<T>, player: Player): Profile<T>?
	return self.Profiles[player]
end

function ServerStore._isSessionExpired<T>(self: ServerStore<T>, metadata: SessionMetadata): boolean
	local updatedAt = metadata.SessionUpdatedAt

	if typeof(updatedAt) ~= "number" then
		return true
	end

	return os.time() - updatedAt >= self.SessionLockExpiration
end

function ServerStore._acquireSession<T>(self: ServerStore<T>, player: Player, session: Session): (T?, "Locked" | "Failed"?)
	local key = self:_getKey(player)

	local acquired = false
	local locked = false

	local success, result = pcall(function()
		return self.DataStore:UpdateAsync(key, function(oldData, keyInfo)
			acquired = false
			locked = false

			local metadata = if keyInfo then keyInfo:GetMetadata() else {}

			local sessionMetadata = metadata :: SessionMetadata

			local currentSessionId = sessionMetadata.SessionId

			local ownedByAnotherSession = currentSessionId ~= nil and currentSessionId ~= session.Id

			if ownedByAnotherSession and not self:_isSessionExpired(sessionMetadata) then
				locked = true

				return nil
			end

			sessionMetadata.SessionId = session.Id
			sessionMetadata.SessionJobId = game.JobId
			sessionMetadata.SessionPlaceId = game.PlaceId
			sessionMetadata.SessionUpdatedAt = os.time()

			acquired = true

			return oldData, nil, sessionMetadata
		end)
	end)

	if not success then
		warn(`[Keystone] Failed to acquire session for {player.Name}: {result}`)
		return nil, "Failed"
	end

	if locked or not acquired then
		return nil, "Locked"
	end

	return result :: T?, nil
end

function ServerStore._bindToClose<T>(self: ServerStore<T>): ()
	game:BindToClose(function()
		self.Running = false

		local pending = 0
		local finished = Instance.new("BindableEvent")

		for _, profile in self.Profiles do
			pending += 1

			task.spawn(function()
				self:_save(profile :: Profile<T>)

				pending -= 1

				if pending == 0 then
					finished:Fire()
				end
			end)
		end

		if pending > 0 then
			finished.Event:Wait()
		end

		finished:Destroy()
	end)
end

function ServerStore._startAutosave<T>(self: ServerStore<T>): ()
	task.spawn(function()
		while self.Running do
			task.wait(self.AutosaveInterval)

			if not self.Running then
				break
			end

			for _, profile in self.Profiles do
				if profile.Released or profile.SessionLost then
					continue
				end

				if not profile.Saving then
					task.spawn(function()
						self:_save(profile :: Profile<T>)
					end)
				end
			end
		end
	end)
end

function ServerStore._release<T>(self: ServerStore<T>, profile: Profile<T>): boolean
	if profile.Released or profile.SessionLost then
		return false
	end

	-- Wait for an in-progress autosave before performing the final write.
	while profile.Saving do
		task.wait()
	end

	if profile.Released or profile.SessionLost then
		return false
	end

	profile.Saving = true
	profile.SaveQueued = false

	local snapshot = self:_deepClone(profile.Data)
	local key = self:_getKey(profile.Player)

	local released = false
	local sessionLost = false

	for attempt = 1, self.SaveAttempts do
		released = false
		sessionLost = false

		local success, result = pcall(function()
			return self.DataStore:UpdateAsync(key, function(_oldData, keyInfo)
				released = false
				sessionLost = false

				local metadata = if keyInfo then keyInfo:GetMetadata() else {}

				local sessionMetadata = metadata :: SessionMetadata

				if sessionMetadata.SessionId ~= profile.Session.Id then
					sessionLost = true

					return nil
				end

				sessionMetadata.SessionId = nil
				sessionMetadata.SessionJobId = nil
				sessionMetadata.SessionPlaceId = nil
				sessionMetadata.SessionUpdatedAt = nil

				released = true

				return snapshot, nil, sessionMetadata
			end)
		end)

		if sessionLost then
			profile.Saving = false
			self:_handleSessionLost(profile)

			return false
		end

		if success and released then
			break
		end

		warn(`[Keystone] Release attempt {attempt}/{self.SaveAttempts} failed for {profile.Player.Name}: {result}`)

		if attempt < self.SaveAttempts then
			task.wait(self.RetryDelay * attempt)
		end
	end

	if not released then
		profile.Saving = false

		warn(`[Keystone] Refusing to release unsaved profile for {profile.Player.Name}`)

		return false
	end

	profile.LastSave = os.time()
	profile.Dirty = false
	profile.Saving = false
	profile.Released = true

	if self.Profiles[profile.Player] == profile then
		self.Profiles[profile.Player] = nil
	end

	profile:Destroy()

	return true
end

function ServerStore._save<T>(self: ServerStore<T>, profile: Profile<T>): boolean
	if profile.Released or profile.SessionLost then
		return false
	end

	if profile.Saving then
		profile.SaveQueued = true
		return true
	end

	profile.Saving = true

	repeat
		profile.SaveQueued = false

		local snapshot = self:_deepClone(profile.Data)
		local revision = profile.Revision
		local key = self:_getKey(profile.Player)

		local saved = false
		local sessionLost = false

		for attempt = 1, self.SaveAttempts do
			sessionLost = false

			local success, result = pcall(function()
				self.DataStore:UpdateAsync(key, function(_oldData, keyInfo: DataStoreKeyInfo)
					sessionLost = false

					local metadata = if keyInfo then keyInfo:GetMetadata() else {}

					local sessionMetadata = metadata :: SessionMetadata

					if sessionMetadata.SessionId ~= profile.Session.Id then
						sessionLost = true
						return nil
					end

					sessionMetadata.SessionUpdatedAt = os.time()

					return snapshot, nil, sessionMetadata
				end)
			end)

			if sessionLost then
				profile.Saving = false
				self:_handleSessionLost(profile)

				return false
			end

			if success then
				saved = true
				profile.LastSave = os.time()

				break
			end

			warn(`[Keystone] Save attempt {attempt}/{self.SaveAttempts} failed for {profile.Player.Name}: {result}`)

			if attempt < self.SaveAttempts then
				task.wait(self.RetryDelay * attempt)
			end
		end

		if not saved then
			profile.Saving = false

			warn(`[Keystone] Exhausted all save attempts for {profile.Player.Name}`)

			return false
		end

		if profile.Revision == revision then
			profile.Dirty = false
		else
			profile.Dirty = true
			profile.SaveQueued = true
		end
	until not profile.SaveQueued

	profile.Saving = false

	return true
end

function ServerStore._load<T>(self: ServerStore<T>, player: Player, session: Session): T?
	local startedAt = os.clock()

	while player.Parent == Players do
		local result, loadError = self:_acquireSession(player, session)

		if loadError == nil then
			local data: T

			if result == nil then
				data = self:_deepClone(self.Template)
			else
				if type(result) ~= "table" then
					warn(`[Keystone] Invalid stored data for {player.Name}`)

					self:_releaseAcquiredSession(player, session)

					return nil
				end

				data = result
				self:_reconcile(data, self.Template)
			end

			return data
		end

		if loadError == "Failed" then
			return nil
		end

		if os.clock() - startedAt >= self.SessionLockMaxWait then
			warn(`[Keystone] Timed out waiting for session lock for {player.Name}`)

			return nil
		end

		task.wait(self.SessionLockRetryDelay)
	end

	return nil
end

function ServerStore._releaseAcquiredSession<T>(self: ServerStore<T>, player: Player, session: Session): boolean
	local key = self:_getKey(player)
	local released = false

	local success, result = pcall(function()
		self.DataStore:UpdateAsync(key, function(oldData, keyInfo: DataStoreKeyInfo)
			released = false

			local metadata = if keyInfo then keyInfo:GetMetadata() else {}

			local sessionMetadata = metadata :: SessionMetadata

			if sessionMetadata.SessionId ~= session.Id then
				return nil
			end

			sessionMetadata.SessionId = nil
			sessionMetadata.SessionJobId = nil
			sessionMetadata.SessionPlaceId = nil
			sessionMetadata.SessionUpdatedAt = nil

			released = true

			return oldData, nil, sessionMetadata
		end)
	end)

	if not success then
		warn(`[Keystone] Failed to release unusable session for {player.Name}: {result}`)
		return false
	end

	return released
end

function ServerStore._handleSessionLost<T>(self: ServerStore<T>, profile: Profile<T>): ()
	if profile.SessionLost then
		return
	end

	profile.SessionLost = true
	profile.Released = true
	profile.Saving = false
	profile.SaveQueued = false

	if self.Profiles[profile.Player] == profile then
		self.Profiles[profile.Player] = nil
	end

	local player = profile.Player

	profile:Destroy()

	if player.Parent == Players then
		player:Kick("Your data session was opened by another server. Please rejoin.")
	end
end

function ServerStore._reconcile<T>(self: ServerStore<T>, data: { [any]: any }, template: { [any]: any }): ()
	for key, templateValue in template do
		local currentValue = data[key]

		if currentValue == nil then
			data[key] = self:_deepClone(templateValue)
			continue
		end

		if type(currentValue) == "table" and type(templateValue) == "table" then
			self:_reconcile(currentValue, templateValue)
		end
	end
end

function ServerStore._deepClone<V>(self: ServerStore<any>, value: V): V
	if type(value) ~= "table" then
		return value
	end

	local clone = {}

	for key, child in value :: any do
		clone[self:_deepClone(key)] = self:_deepClone(child)
	end

	return clone :: any
end

function ServerStore._getKey<T>(_self: ServerStore<T>, player: Player): string
	return tostring(player.UserId)
end

function ServerStore._createProfile<T>(self: ServerStore<T>, player: Player, data: T, session: Session): Profile<T>
	return Profile.new(self, player, data, session)
end

return ServerStore
