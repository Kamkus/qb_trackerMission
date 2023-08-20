local QBCore = exports['qb-core']:GetCoreObject()

local currentNPCPosition = Config.NPC.locations[math.random(1, #Config.NPC.locations)]
local tracker = {
    state = false,
    lastTruckerEnded = 0,
    thief = nil,
    car = nil,
    pos = {
        area = nil,
        carPosition = nil
    }
}

local ClearTrackerState = function()
    tracker = {
        state = false,
        lastTruckerEnded = os.time(),
        thief = nil,
        car = nil,
        pos = {
            area = nil,
            carPosition = nil
        }
    }
end

RegisterNetEvent('kd_trucker:server:endTrucker', function()
    local src = source
    ClearTrackerState()
    local xPlayer = QBCore.Functions.GetPlayer(src)
    xPlayer.Functions.AddMoney(Config.money.type, math.random(Config.money.min, Config.money.max))
end)

QBCore.Functions.CreateCallback('kd_trucker:callback:GetNPCPosition', function(src, cb)
    cb(currentNPCPosition)
end)

QBCore.Functions.CreateCallback('kd_trucker:callback:canStartTracker', function(src, cb)
    local totalPolice = 0
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v then
            if v.PlayerData.job.name == "police" and v.PlayerData.job.onduty then
                totalPolice = totalPolice + 1
            end
        end
    end




    cb(os.time() - tracker.lastTruckerEnded >= Config.truckerDelay and not tracker.state and totalPolice >= Config.MinPolice)
end)

RegisterNetEvent('kd_trucker:server:startTucker', function()
    local src = source
    if tracker.state then
        return
    end
    tracker.state = true
    tracker.thief = src
    local truckerPosInfo = Config.tuckerLocations[math.random(1, #Config.tuckerLocations)]
    tracker.pos.area = truckerPosInfo.areaPosition
    tracker.pos.carPosition = truckerPosInfo.vehPositions[math.random(1, #truckerPosInfo.vehPositions)]
    TriggerClientEvent('kd_trucker:client:startTucker', src, {
        area = tracker.pos.area,
        carPosition = tracker.pos.carPosition
    })
end)

RegisterNetEvent('kd_trucker:server:setTruckerCar', function(netId)
    tracker.car = netId
end)

RegisterNetEvent('kd_trucker:server:policeGPS', function(coords)
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v then
            if v.PlayerData.job.name == "police" and v.PlayerData.job.onduty then
                TriggerClientEvent('kd_trucker:client:policeGPS', v.PlayerData.source, coords, tracker.car)
            end
        end
    end
end)

RegisterNetEvent('kd_trucker:server:truckerDestroy', function()
    TriggerClientEvent('kd_trucker:client:truckerDestroy', tracker.thief)
    ClearTrackerState()
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v then
            if v.PlayerData.job.name == "police" then
                TriggerClientEvent('kd_trucker:client:GPSRemoveForced', v.PlayerData.source)
            end
        end
    end
end)

RegisterNetEvent('kd_trucker:server:GPSRemoved', function()
    for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
        if v then
            if v.PlayerData.job.name == "police" then
                TriggerClientEvent('kd_trucker:client:GPSRemoved', v.PlayerData.source)
            end
        end
    end
end)

AddEventHandler('playerDropped', function (reason)
    local src = source
    if src == tracker.thief then
        ClearTrackerState()
        for _, v in pairs(QBCore.Functions.GetQBPlayers()) do
            if v then
                if v.PlayerData.job.name == "police" then
                    TriggerClientEvent('kd_trucker:client:GPSRemoveForced', v.PlayerData.source)
                end
            end
        end
    end
  end)

  RegisterNetEvent('kd_trucker:server:removeitem', function(item)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    xPlayer.Functions.RemoveItem(item.name, item.amount)
  end)