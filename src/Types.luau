--!strict
local Packages = script.Parent.Parent

local Signal = require(Packages.Signal)

export type Path = { string | number }

export type Session = {
	Id: string,
}

export type SessionMetadata = {
	SessionId: string?,
	SessionJobId: string?,
	SessionPlaceId: number?,
	SessionUpdatedAt: number?,
}

export type SessionLockStatus = "Acquired" | "Locked" | "Failed"

export type StoreProps<T> = {
	Name: string,
	Template: T,

	SaveAttempts: number?,
	RetryDelay: number?,
	AutosaveInterval: number?,

	SessionLockExpiration: number?,
	SessionLockRetryDelay: number?,
	SessionLockMaxWait: number?,
}

export type ServerStore<T> = {
	Name: string,
	Template: T,
	Profiles: { [Player]: Profile<T> },
	DataStore: GlobalDataStore,

	SaveAttempts: number,
	RetryDelay: number,
	AutosaveInterval: number,

	SessionLockExpiration: number,
	SessionLockRetryDelay: number,
	SessionLockMaxWait: number,

	Running: boolean,

	RequestRemote: RemoteEvent?,
	SnapshotRemote: RemoteEvent?,
	ChangedRemote: RemoteEvent?,

	Start: (self: ServerStore<T>) -> (),
	LoadPlayer: (self: ServerStore<T>, player: Player) -> boolean,
	SavePlayer: (self: ServerStore<T>, player: Player) -> boolean,
	ReleasePlayer: (self: ServerStore<T>, player: Player) -> boolean,
	GetProfile: (self: ServerStore<T>, player: Player) -> Profile<T>,

	_load: (self: ServerStore<T>, player: Player, session: Session) -> T?,
	_save: (self: ServerStore<T>, profile: Profile<T>) -> boolean,
	_release: (self: ServerStore<T>, profile: Profile<T>) -> boolean,

	_getKey: (self: ServerStore<T>, player: Player) -> string,
	_createProfile: (self: ServerStore<T>, player: Player, data: T, session: Session) -> Profile<T>,
	_deepClone: <V>(self: ServerStore<T>, value: V) -> V,
	_reconcile: (self: ServerStore<T>, data: T, template: T) -> (),

	_startAutosave: (self: ServerStore<T>) -> (),
	_bindToClose: (self: ServerStore<T>) -> (),

	_acquireSession: (self: ServerStore<T>, player: Player, session: Session) -> (SessionLockStatus, T?),
	_isSessionExpired: (self: ServerStore<T>, metadata: SessionMetadata) -> boolean,
	_handleSessionLost: (self: ServerStore<T>, profile: Profile<T>) -> (),
	_releaseAcquiredSession: (self: ServerStore<T>, player: Player, session: Session) -> boolean,
}

export type ClientStore<T> = {
	Name: string,
	Data: T?,
	Loaded: boolean,

	Changed: Signal.Signal<Path, any, any>,
	ChangedSignals: { [string]: Signal.Signal<any, any> },

	RequestRemote: RemoteEvent?,
	SnapshotRemote: RemoteEvent?,
	ChangedRemote: RemoteEvent?,

	Get: (self: ClientStore<T>, path: Path) -> any,
	GetChangedSignal: (self: ClientStore<T>, path: Path) -> Signal.Signal<any, any>,

	_applyChange: (self: ClientStore<T>, path: Path, value: any) -> (),

	Destroy: (self: ClientStore<T>) -> (),
}

export type Profile<T> = {
	Store: ServerStore<T>,
	Player: Player,
	Data: T,
	Session: Session,

	Dirty: boolean,
	Released: boolean,
	SessionLost: boolean,

	Saving: boolean,
	Releasing: boolean,
	SaveQueued: boolean,
	Revision: number,
	LastSave: number?,

	Changed: Signal.Signal<Path, any, any>,
	ChangedSignals: { [string]: Signal.Signal<any, any> },

	Get: (self: Profile<T>, path: Path) -> any,
	Set: (self: Profile<T>, path: Path, value: any) -> (),
	Update: (self: Profile<T>, path: Path, callback: (currentValue: any) -> any) -> (),
	Save: (self: Profile<T>) -> boolean,
	Release: (self: Profile<T>) -> boolean,

	Destroy: (self: Profile<T>) -> (),
}

return {}
