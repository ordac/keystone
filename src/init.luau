--!strict
local RunService = game:GetService("RunService")
local Types = require(script.Types)

export type ServerStore<T> = Types.ServerStore<T>
export type ClientStore<T> = Types.ClientStore<T>
export type Profile<T> = Types.Profile<T>

local Keystone = {}

if RunService:IsServer() then
	local ServerStore = require(script.ServerStore)

	function Keystone.create<T>(props: ServerStore.StoreProps<T>): ServerStore.ServerStore<T>
		return ServerStore.new(props)
	end
else
	local ClientStore = require(script.ClientStore)

	function Keystone.connect<T>(name: string): ClientStore.ClientStore<T>
		return ClientStore.new(name)
	end
end

return Keystone
