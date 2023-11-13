-- Variables
local BJCore = exports['core']:GetCoreObject()
local PlayerData = BJCore.Functions.GetPlayerData()
local route = 1
local max = #Config.NPCLocations.Locations
local busBlip = nil

local NpcData = {
    Active = false,
    CurrentNpc = nil,
    LastNpc = nil,
    CurrentDeliver = nil,
    LastDeliver = nil,
    Npc = nil,
    NpcBlip = nil,
    DeliveryBlip = nil,
    NpcTaken = false,
    NpcDelivered = false,
    CountDown = 180
}

local BusData = {
    Active = false,
}

-- Functions
local function resetNpcTask()
    NpcData = {
        Active = false,
        CurrentNpc = nil,
        LastNpc = nil,
        CurrentDeliver = nil,
        LastDeliver = nil,
        Npc = nil,
        NpcBlip = nil,
        DeliveryBlip = nil,
        NpcTaken = false,
        NpcDelivered = false,
    }
end

local function updateBlip()
    if PlayerData.job.name == "bus" then
        busBlip = AddBlipForCoord(Config.Location)
        SetBlipSprite(busBlip, 513)
        SetBlipDisplay(busBlip, 4)
        SetBlipScale(busBlip, 0.6)
        SetBlipAsShortRange(busBlip, true)
        SetBlipColour(busBlip, 49)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName('Bus Depot')
        EndTextCommandSetBlipName(busBlip)
    elseif busBlip ~= nil then
        RemoveBlip(busBlip)
    end
end

local function whitelistedVehicle()
    local ped = PlayerPedId()
    local veh = GetEntityModel(GetVehiclePedIsIn(ped))
    local retval = false

    for i = 1, #Config.AllowedVehicles, 1 do
        if veh == Config.AllowedVehicles[i].model then
            retval = true
        end
    end

    if veh == `dynasty` then
        retval = true
    end

    return retval
end

local function nextStop()
    if route <= (max - 1) then
        route = route + 1
    else
        route = 1
    end
end

local function GetDeliveryLocation()
    nextStop()
    if NpcData.DeliveryBlip ~= nil then
        RemoveBlip(NpcData.DeliveryBlip)
    end
    NpcData.DeliveryBlip = AddBlipForCoord(Config.NPCLocations.Locations[route].x, Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z)
    SetBlipColour(NpcData.DeliveryBlip, 3)
    SetBlipRoute(NpcData.DeliveryBlip, true)
    SetBlipRouteColour(NpcData.DeliveryBlip, 3)
    NpcData.LastDeliver = route
    local inRange = false
    local PolyZone = CircleZone:Create(vector3(Config.NPCLocations.Locations[route].x,
        Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z), 5, {
        name = "busjobdeliver",
        useZ = true,
        -- debugPoly=true
    })
    PolyZone:onPlayerInOut(function(isPointInside)
        if isPointInside then
            inRange = true
            BJCore.Functions.Notify('[E] Bus Stop', 'primary')
            CreateThread(function()
                repeat
                    Wait(0)
                    if IsControlJustPressed(0, 38) then
                        local ped = PlayerPedId()
                        local veh = GetVehiclePedIsIn(ped, 0)
                        TaskLeaveVehicle(NpcData.Npc, veh, 0)
                        SetEntityAsMissionEntity(NpcData.Npc, false, true)
                        SetEntityAsNoLongerNeeded(NpcData.Npc)
                        local targetCoords = Config.NPCLocations.Locations[NpcData.LastNpc]
                        TaskGoStraightToCoord(NpcData.Npc, targetCoords.x, targetCoords.y, targetCoords.z, 1.0, -1, 0.0, 0.0)
                        BJCore.Functions.Notify('Person was dropped off', 'success')
                        if NpcData.DeliveryBlip ~= nil then
                            RemoveBlip(NpcData.DeliveryBlip)
                        end
                        local RemovePed = function(pped)
                            SetTimeout(60000, function()
                                DeletePed(pped)
                            end)
                        end
                        RemovePed(NpcData.Npc)
                        resetNpcTask()
                        nextStop()
                        TriggerEvent('bj-busjob:client:DoBusNpc')
                        exports["core"]:HideText()
                        PolyZone:destroy()
                        break
                    end
                until not inRange
            end)
        else
            exports["core"]:HideText()
            inRange = false
        end
    end)
end

local function closeMenuFull()
    exports['qb-menu']:closeMenu()
end

-- Old Menu Code (being removed)
local function busGarage()
    local vehicleMenu = {
        {
            header = 'Bus Vehicles',
            isMenuHeader = true
        }
    }
    for _, v in pairs(Config.AllowedVehicles) do
        vehicleMenu[#vehicleMenu + 1] = {
            header = v.label,
            params = {
                event = "bj-busjob:client:TakeVehicle",
                args = {
                    model = v.model
                }
            }
        }
    end
    vehicleMenu[#vehicleMenu + 1] = {
        header = '⬅ Close Menu',
        params = {
            event = "qb-menu:client:closeMenu"
        }
    }
    exports['qb-menu']:openMenu(vehicleMenu)
end

RegisterNetEvent("bj-busjob:client:TakeVehicle", function(data)
    local coords = Config.Location
    if (BusData.Active) then
        BJCore.Functions.Notify('You can only have one active bus at a time', 'error')
        return
    else
        BJCore.Functions.TriggerCallback('BJCore:Server:SpawnVehicle', function(netId)
            local veh = NetToVeh(netId)
            SetVehicleNumberPlateText(veh, 'BUS' .. tostring(math.random(1000, 9999)))
            exports['LegacyFuel']:SetFuel(veh, 100.0)
            closeMenuFull()
            TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
            TriggerEvent("vehiclekeys:client:SetOwner", BJCore.Functions.GetPlate(veh))
            SetVehicleEngineOn(veh, true, true)
        end, data.model, coords, true)
        Wait(1000)
        TriggerEvent('bj-busjob:client:DoBusNpc')
    end
end)

-- Events
AddEventHandler('onResourceStart', function(resourceName)
    -- handles script restarts
    if GetCurrentResourceName() == resourceName then
        updateBlip()
    end
end)

RegisterNetEvent('BJCore:Client:OnPlayerLoaded', function()
    PlayerData = BJCore.Functions.GetPlayerData()
    updateBlip()
end)

RegisterNetEvent('BJCore:Client:OnPlayerUnload', function()
    PlayerData = {}
end)

RegisterNetEvent('BJCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
    updateBlip()

end)

RegisterNetEvent('bj-busjob:client:DoBusNpc', function()
    if whitelistedVehicle() then
        if not NpcData.Active then
            local Gender = math.random(1, #Config.NpcSkins)
            local PedSkin = math.random(1, #Config.NpcSkins[Gender])
            local model = Config.NpcSkins[Gender][PedSkin]
            RequestModel(model)
            while not HasModelLoaded(model) do
                Wait(0)
            end
            NpcData.Npc = CreatePed(3, model, Config.NPCLocations.Locations[route].x, Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z - 0.98, Config.NPCLocations.Locations[route].w, false, true)
            PlaceObjectOnGroundProperly(NpcData.Npc)
            FreezeEntityPosition(NpcData.Npc, true)
            if NpcData.NpcBlip ~= nil then
                RemoveBlip(NpcData.NpcBlip)
            end
            BJCore.Functions.Notify('Go to the bus stop', 'primary')
            NpcData.NpcBlip = AddBlipForCoord(Config.NPCLocations.Locations[route].x, Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z)
            SetBlipColour(NpcData.NpcBlip, 3)
            SetBlipRoute(NpcData.NpcBlip, true)
            SetBlipRouteColour(NpcData.NpcBlip, 3)
            NpcData.LastNpc = route
            NpcData.Active = true
            local inRange = false
            local PolyZone = CircleZone:Create(vector3(Config.NPCLocations.Locations[route].x,
                Config.NPCLocations.Locations[route].y, Config.NPCLocations.Locations[route].z), 5, {
                name = "busjobdeliver",
                useZ = true,
                -- debugPoly=true
            })
            PolyZone:onPlayerInOut(function(isPointInside)
                if isPointInside then
                    inRange = true
                     BJCore.Functions.Notify('[E] Bus Stop', 'primary')
                    CreateThread(function()
                        repeat
                            Wait(5)
                            if IsControlJustPressed(0, 38) then
                                local ped = PlayerPedId()
                                local veh = GetVehiclePedIsIn(ped, 0)
                                local maxSeats, freeSeat = GetVehicleMaxNumberOfPassengers(veh)

                                for i = maxSeats - 1, 0, -1 do
                                    if IsVehicleSeatFree(veh, i) then
                                        freeSeat = i
                                        break
                                    end
                                end

                                ClearPedTasksImmediately(NpcData.Npc)
                                FreezeEntityPosition(NpcData.Npc, false)
                                TaskEnterVehicle(NpcData.Npc, veh, -1, freeSeat, 1.0, 0)
                                BJCore.Functions.Notify('Go to the bus stop', 'primary')
                                if NpcData.NpcBlip ~= nil then
                                    RemoveBlip(NpcData.NpcBlip)
                                end
                                GetDeliveryLocation()
                                NpcData.NpcTaken = true
                                TriggerServerEvent('bj-busjob:server:NpcPay')
                                exports["core"]:HideText()
                                PolyZone:destroy()
                                break
                            end
                        until not inRange
                    end)
                else
                    exports["core"]:HideText()
                    inRange = false
                end
            end)
        else
            BJCore.Functions.Notify('You are already driving a bus', 'error')
        end
    else
        BJCore.Functions.Notify('You are not in a bus', 'error')
    end
end)

-- Threads
CreateThread(function()
    local inRange = false
    local PolyZone = CircleZone:Create(vector3(Config.Location.x, Config.Location.y, Config.Location.z), 5, {
        name = "busMain",
        useZ = true,
        debugPoly = false
    })
    PolyZone:onPlayerInOut(function(isPointInside)
        local inVeh = whitelistedVehicle()
        if PlayerData.job.name == "bus" then
            if isPointInside then
                inRange = true
                CreateThread(function()
                    repeat
                        Wait(5)
                        if not inVeh then
                                BJCore.Functions.Notify('[E] Bus Stop', 'primary')
                            if IsControlJustReleased(0, 38) then
                                busGarage()
                                exports["core"]:HideText()
                                break
                            end
                        else
                            BJCore.Functions.Notify('[E] Stop Working', 'primary')
                            if IsControlJustReleased(0, 38) then
                                if (not NpcData.Active or NpcData.Active and NpcData.NpcTaken == false) then
                                    if IsPedInAnyVehicle(PlayerPedId(), false) then
                                        BusData.Active = false;
                                        DeleteVehicle(GetVehiclePedIsIn(PlayerPedId()))
                                        RemoveBlip(NpcData.NpcBlip)
                                        exports["core"]:HideText()
                                        resetNpcTask()
                                        break
                                    end
                                else
                                    BJCore.Functions.Notify('Drop off the passengers before you stop working', 'error')
                                end
                            end
                        end
                    until not inRange
                end)
            else
                exports["core"]:HideText()
                inRange = false
            end
        end
    end)
end)
