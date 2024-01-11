--[[
    profile.lua
    Author(s): Sam Kalish
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Constants
local Signal = require(ReplicatedStorage.packages.signal)

-- Variables
local globalReleaseCallbacks = {}

-- Main
local Profile = {}
Profile.__index = Profile

--[=[
	Instantiates a new profile. This profile will be bound to the raw profile and should be used to interface with the data.
]=]
Profile.new = function(profile, player: Player?)
    local self = setmetatable({}, Profile)

    self.player = player
    self.rawProfile = profile
    self.oldData = table.freeze(table.clone(profile.Data))
    self.onRelease = {}
    self.onChanged = Signal.new()

    return self
end

--[=[
    Binds pre-release callback to all profiles. Do not call directly. 
]=]
Profile.bindToReleaseAll = function(callback: (player: Player, profile: Profile) -> ())
    table.insert(globalReleaseCallbacks, callback)
end

--[=[
    Releases the profile and fires all onRelease events.
]=]
Profile.release = function(self)
    for _, v in self.onRelease do
        v()
    end

    for _, v in globalReleaseCallbacks do
        v(self.player, self)
    end

    self.onChanged:Destroy()
    self.rawProfile:Release()
end

--[=[
    Returns the value of the key in the profile.
]=]
Profile.get = function(self, key: string)
    return self.rawProfile.Data[key]
end

--[=[
    Sets the value of the key in the profile and fires all onChanged events.
]=]
Profile.set = function(self, key: string, value: any)
    local rawData = self.rawProfile.Data
    rawData[key] = value
    self.onChanged:Fire(rawData, self.oldData)
    self.oldData = table.freeze(table.clone(rawData))
end

--[=[
    Updates the value to the function return value and fires all onChanged events.
]=]
Profile.update = function(self, key: string, func: (any) -> (any))
    self:set(key, func(self:get(key)))
end

--[=[
    Binds a function to run when the profile is released.
]=]
Profile.bindToRelease = function(self, func: () -> ())
    table.insert(self.onRelease, func)
end

export type Profile = {
    new: (profile: Profile) -> Profile,
    release: () -> (),
    get: (key: string) -> any,
    set: (key: string, value: any) -> (),
    update: (key: string, func: (any) -> (any)) -> (),
    bindToRelease: (func: () -> ()) -> ()
}

return Profile