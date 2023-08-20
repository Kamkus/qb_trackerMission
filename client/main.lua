local QBCore = exports['qb-core']:GetCoreObject()

local trackerBlip = nil

local trackerState = nil
local trackerCar = nil
local trackerLocation = nil
local startedGPS = 0
local trackerPoliceBlip = nil
local trackerPoliceCar = nil

Citizen.CreateThread(function()
    QBCore.Functions.TriggerCallback('kd_trucker:callback:GetNPCPosition', function(currentNPCPosition)
        -- lib.requestModel(Config.NPC.model, 500)
        Config.RequestModel(Config.NPC.model)
        local NPC = CreatePed(4, GetHashKey(Config.NPC.model), currentNPCPosition.x, currentNPCPosition.y,
            currentNPCPosition.z, currentNPCPosition.w, false, true)
        SetEntityCoordsNoOffset(NPC, currentNPCPosition.x, currentNPCPosition.y, currentNPCPosition.z, true, false,
            false)
        FreezeEntityPosition(NPC, true)
        SetEntityInvincible(NPC, true)
        SetBlockingOfNonTemporaryEvents(NPC, true)
        exports['qb-target']:AddTargetEntity(NPC, {
            options = {{
                icon = "fa-regular fa-circle-check",
                label = Config.lang['talk_to_npc'],
                action = function()
                    QBCore.Functions.TriggerCallback('kd_trucker:callback:canStartTracker', function(canStart)
                        if not canStart then
                            QBCore.Functions.Notify(Config.lang['mission_in_progress'], 'error', 3000)
                            return
                        end
                        TriggerServerEvent('kd_trucker:server:startTucker')
                    end)
                end
            }},
            distance = 2
        })
    end)
end)

local GetDistanceBetweenTwoCoords = function(coords1, coords2)
    return math.ceil(math.sqrt((coords2.x - coords1.x) ^ 2 + (coords2.y - coords1.y) ^ 2))
end

RegisterNetEvent('kd_trucker:client:truckerDestroy', function()
    DeleteEntity(trackerCar)
    if trackerBlip ~= nil then
        RemoveBlip(trackerBlip)
    end
    trackerBlip = nil
    trackerState = nil
    trackerCar = nil
    trackerLocation = nil
    startedGPS = 0
end)

RegisterNetEvent('kd_trucker:client:startTucker', function(data)
    local carModel = Config.carModels[math.random(1, #Config.carModels)]
    SetNewWaypoint(data.area.x, data.area.y)
    local radius = GetDistanceBetweenTwoCoords(data.carPosition, data.area) + 100.0
    trackerBlip = AddBlipForRadius(data.area, radius)
    SetBlipAlpha(trackerBlip, 150)
    SetBlipColour(trackerBlip, 49)
    trackerState = 1
    initializeLoop()
    Config.RequestModel(carModel)
    trackerCar = CreateVehicle(carModel, data.carPosition.x, data.carPosition.y, data.carPosition.z, data.carPosition.w,
        true, true)
    SetEntityCoordsNoOffset(trackerCar, data.carPosition, false, false, false)
    SetEntityHeading(trackerCar, data.carPosition.w)
    QBCore.Functions.Notify(string.format(Config.lang['car_location'],
        GetDisplayNameFromVehicleModel(GetHashKey(carModel)), GetVehicleNumberPlateText(trackerCar)), 'primary', 10000)
    TriggerServerEvent('kd_trucker:server:setTruckerCar', NetworkGetNetworkIdFromEntity(trackerCar))
    Citizen.CreateThread(function()
        local playerPed = PlayerPedId()
        while trackerState == 1 do
            if #(GetEntityCoords(playerPed) - vector3(data.area.x, data.area.y, data.area.z)) <= radius then
                QBCore.Functions.Notify(Config.lang['right_spot'], 'primary', 3000)
                trackerState = 2
            end
            Citizen.Wait(1000)
        end
    end)
    Citizen.SetTimeout(Config.AFKProtect * 1000 * 60, function()
        if trackerState == 1 then
            QBCore.Functions.Notify(Config.lang['afk'], 'error', 5000)
            TriggerServerEvent('kd_trucker:server:truckerDestroy')
        end
    end)
end)
RegisterNetEvent('kd_trucker:enteredVehicle')
AddEventHandler('kd_trucker:enteredVehicle', function(vehicle, plate)
    if trackerState ~= 2 then
        return
    end
    print(vehicle, plate, trackerCar)
    if (vehicle == trackerCar or GetVehicleNumberPlateText(trackerCar) == plate) then
        RemoveBlip(trackerBlip)
        trackerState = 3
        startedGPS = GetGameTimer()
        -- Add some alert for police
        QBCore.Functions.Notify(Config.lang['rid_of_gps'], 'success', 3000)
        Citizen.CreateThread(function()
            while trackerState == 3 do
                TriggerServerEvent('kd_trucker:server:policeGPS', GetEntityCoords(trackerCar))
                Citizen.Wait(500)
            end
        end)
    end
end)
RegisterNetEvent('kd_trucker:exitedVehicle')
AddEventHandler('kd_trucker:exitedVehicle', function(vehicle, plate)
    if trackerState ~= 4 or #(trackerLocation - GetEntityCoords(trackerCar)) > 30.0 then
        return
    end
    if (vehicle == trackerCar or GetVehicleNumberPlateText(trackerCar) == plate) then
        RemoveBlip(trackerBlip)
        QBCore.Functions.Notify(Config.lang['good_job'], 'success', 3000)
        TriggerServerEvent('kd_trucker:server:endTrucker')
        Citizen.SetTimeout(5000, function()
            DeleteEntity(trackerCar)
            trackerBlip = nil
            trackerState = nil
            trackerCar = nil
            trackerLocation = nil
            startedGPS = 0
        end)
    end
end)

RegisterNetEvent('kd_trucker:client:GPSRemoved', function()
    Citizen.SetTimeout(Config.GPSRemove, function()
        if trackerPoliceBlip ~= nil then
            RemoveBlip(trackerPoliceBlip)
            trackerPoliceBlip = nil
        end
    end)
end)

RegisterNetEvent('kd_trucker:client:GPSRemoveForced', function()
    if trackerPoliceBlip ~= nil then
        RemoveBlip(trackerPoliceBlip)
        trackerPoliceBlip = nil
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        RemoveBlip(trackerBlip)
    end
end)

RegisterNetEvent('kd_trucker:client:policeGPS', function(coords, vehicleNetID)
    if vehicleNetID ~= trackerPoliceCar then
        trackerPoliceCar = vehicleNetID
    end
    RemoveBlip(trackerPoliceBlip)
    trackerPoliceBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(trackerPoliceBlip, 227)
    SetBlipScale(trackerPoliceBlip, 1.5)
    SetBlipDisplay(trackerPoliceBlip, 2)
    SetBlipColour(trackerPoliceBlip, 49)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.lang['stolen_vehicle'])
    EndTextCommandSetBlipName(trackerPoliceBlip)
end)

local inAction = false

local GPSDestroyed = function()
    trackerState = 4
    TriggerServerEvent('kd_trucker:server:GPSRemoved')
    QBCore.Functions.Notify(Config.lang['gps_off'], 'success', 3000)
    trackerLocation = Config.trackerHideoutLocations[math.random(1, #Config.trackerHideoutLocations)]
    trackerBlip = AddBlipForCoord(trackerLocation.x, trackerLocation.y, trackerLocation.z)
    SetBlipSprite(trackerBlip, 271)
    SetBlipScale(trackerBlip, 1.0)
    SetBlipDisplay(trackerBlip, 2)
    SetBlipColour(trackerBlip, 73)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.lang['drop'])
    EndTextCommandSetBlipName(trackerBlip)
    SetBlipRoute(trackerBlip, true)
end

local hackSuccess = function()
    QBCore.Functions.Progressbar('taking_off_gps', Config.lang['taking_off_gps'], 20000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true
    }, {
        animDict = 'amb@prop_human_bum_bin@base',
        anim = 'base'
    }, {}, {}, function()
        inAction = false
        GPSDestroyed()
        TriggerServerEvent('kd_trucker:server:removeitem', Config.RequireItem)
        ClearPedTasks(PlayerPedId())
    end, function()
        ClearPedTasks(PlayerPedId())
        inAction = false
    end)
end

exports['qb-target']:AddGlobalVehicle({
    options = {{
        icon = "fa-regular fa-circle-check",
        label = Config.lang['tow_the_vehicle'],
        canInteract = function(entity)
            if trackerPoliceCar == nil then
                return false
            end
            return entity == NetworkGetEntityFromNetworkId(trackerPoliceCar)
        end,
        action = function()
            if not inAction then
                inAction = true
                QBCore.Functions.Progressbar('towing', Config.lang['towing'], 6000, false, true, {
                    disableMovement = false,
                    disableCarMovement = true,
                    disableMouse = false,
                    disableCombat = true
                }, {
                }, {}, {}, function()
                    inAction = false
                    TriggerServerEvent('kd_trucker:server:truckerDestroy')
                    trackerPoliceCar = nil
                end, function()
                    inAction = false
                end)
            end
        end,
        job = {
            ['police'] = 0
        }
    }, {
        icon = "fa-regular fa-circle-check",
        label = Config.lang['gps_take_off'],
        canInteract = function(entity)
            if trackerState ~= 3 then
                return false
            end
            return (GetGameTimer() - startedGPS) / 1000 >= Config.destroyGPSTime
        end,
        action = function()
            if not QBCore.Functions.HasItem(Config.RequireItem) then
                QBCore.Functions.Notify(Config.lang['required_items'], 'error', 3000)
                return
            end
            hackSuccess()
        end
    }},
    distance = 2
})

initializeLoop = function()
    Citizen.CreateThread(function()
        local isInsideVehicle = false
        local isInside
        local pedVehicle
        while trackerState ~= nil do
            isInside = IsPedInAnyVehicle(PlayerPedId(), false)
            if isInside and not pedVehicle then
                pedVehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                print("Wchodze")
                TriggerEvent('kd_trucker:enteredVehicle', pedVehicle, GetVehicleNumberPlateText(pedVehicle))
            elseif not isInside and pedVehicle then
                print("Wychodze")
                TriggerEvent('kd_trucker:exitedVehicle', pedVehicle, GetVehicleNumberPlateText(pedVehicle))
                pedVehicle = nil
            end
            Citizen.Wait(1000)
        end
    end)
end
