local ESX = nil
local PlayerData = {}
local isDead = false
local passedGateEntry = false
local lastGateEntryTime = 0
local spawnedNPCs = {}
local spawnedVehicles = {}
local lastFineTime = 0
local fineCooldown = 30000

-- Zone notification tracking
local militaryNotified = false
local prisonNotified = false
local trafficNotified = false
local airportNotified = false
local metroNotified = false
local airportWeaponWarning = false
local metroWeaponWarning = false

-- Airport and Metro specific
local airportGuards = {}
local metroGuards = {}
local currentAirportZone = nil
local currentMetroStation = nil
local lastWeaponCheck = 0

-- Initialize ESX
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
    
    while ESX.GetPlayerData().job == nil do
        Citizen.Wait(10)
    end
    
    PlayerData = ESX.GetPlayerData()
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    PlayerData.job = job
end)

-- ===== UTILITY FUNCTIONS =====

-- Check if player has safe job
function IsSafeJob()
    if not PlayerData or not PlayerData.job then
        return false
    end
    
    for _, job in ipairs(Config.SafeJobs) do
        if string.lower(PlayerData.job.name) == string.lower(job) then
            return true
        end
    end
    return false
end

-- Check if player has weapon drawn
function HasWeaponDrawn()
    local playerPed = PlayerPedId()
    local weapon = GetSelectedPedWeapon(playerPed)
    
    if weapon and weapon ~= GetHashKey("WEAPON_UNARMED") then
        for _, restrictedWeapon in ipairs(Config.Airport.weaponDetection.restrictedWeapons) do
            if weapon == GetHashKey(restrictedWeapon) then
                return true, weapon, restrictedWeapon
            end
        end
    end
    
    return false, nil, nil
end

-- Check if weapon is aggressive
function IsAggressiveWeapon(weaponHash)
    for _, aggressiveWeapon in ipairs(Config.Airport.weaponDetection.aggressiveWeapons) do
        if weaponHash == GetHashKey(aggressiveWeapon) then
            return true
        end
    end
    return false
end

-- Check if player is prisoner
function IsPlayerPrisoner()
    if Config.Prison.prisonerDetection.checkPedModel then
        local playerPed = PlayerPedId()
        local playerModel = GetEntityModel(playerPed)
        
        for _, model in ipairs(Config.Prison.prisonerDetection.prisonerModels) do
            if playerModel == GetHashKey(model) then
                return true
            end
        end
    end
    
    if Config.Prison.prisonerDetection.checkJob and PlayerData and PlayerData.job then
        local jobName = string.lower(PlayerData.job.name)
        for _, prisonerJob in ipairs(Config.Prison.prisonerDetection.prisonerJobs) do
            if jobName == string.lower(prisonerJob) then
                return true
            end
        end
    end
    
    if Config.Prison.prisonerDetection.checkClothing then
        local playerPed = PlayerPedId()
        local torsoDrawable = GetPedDrawableVariation(playerPed, 3)
        local legsDrawable = GetPedDrawableVariation(playerPed, 4)
        if (torsoDrawable >= 49 and torsoDrawable <= 53) or (legsDrawable >= 54 and legsDrawable <= 58) then
            return true
        end
    end
    
    return false
end

-- Send notification using Native ESX function
function SendNotification(title, subject, msg, icon, iconType, flash)
    if ESX and ESX.ShowAdvancedNotification then
        ESX.ShowAdvancedNotification(title, subject, msg, icon, iconType or 1, flash or false)
    end
end

-- Zone notification wrapper
function SendZoneNotification(notification)
    if not notification then return end
    
    SendNotification(
        notification.title or "",
        notification.subject or "",
        notification.msg or "",
        notification.icon or "CHAR_DEFAULT",
        notification.iconType or 1,
        notification.flash or false
    )
end

-- ===== ZONE DETECTION FUNCTIONS =====

function HasEnteredMilitaryGate()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local inVehicle = IsPedInAnyVehicle(playerPed, false)
    
    for _, entryPoint in ipairs(Config.MilitaryBase.entryPoints) do
        local distance = #(playerCoords - entryPoint.coords)
        local heightDiff = math.abs(playerCoords.z - entryPoint.coords.z)
        local isAtEntry = distance <= entryPoint.radius and heightDiff < 10.0
        
        if entryPoint.checkVehicle and not inVehicle then
            isAtEntry = false
        end
        
        if isAtEntry then
            return true, entryPoint.coords
        end
    end
    
    return false, nil
end

function IsInsideMilitaryBase()
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    for _, zone in ipairs(Config.MilitaryBase.internalZones) do
        if #(playerCoords - zone.coords) <= zone.radius then
            return true
        end
    end
    
    return false
end

function IsInPrisonZone()
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    for _, zone in ipairs(Config.Prison.zones) do
        if #(playerCoords - zone.coords) <= zone.radius then
            return true
        end
    end
    
    return false
end

function IsInAirportZone()
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    for _, zone in ipairs(Config.Airport.zones) do
        if #(playerCoords - zone.coords) <= zone.radius then
            return true, zone
        end
    end
    
    return false, nil
end

function IsInMetroStation()
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    for _, station in ipairs(Config.Metro.stations) do
        local distance = #(playerCoords - station.coords)
        if station.underground then
            local zDiff = math.abs(playerCoords.z - station.coords.z)
            if distance <= station.radius and zDiff <= 10.0 then
                return true, station
            end
        elseif distance <= station.radius then
            return true, station
        end
    end
    
    return false, nil
end

-- ===== NPC SPAWNING FUNCTIONS =====

function SpawnNPC(model, coords, weapon, accuracy, friendly)
    RequestModel(GetHashKey(model))
    while not HasModelLoaded(GetHashKey(model)) do
        Citizen.Wait(10)
    end
    
    local ped = CreatePed(4, GetHashKey(model), coords.x, coords.y, coords.z, 0.0, true, false)
    
    if DoesEntityExist(ped) then
        if not friendly then
            SetPedAsCop(ped, true)
            SetPedFleeAttributes(ped, 0, 0)
            SetPedCombatAttributes(ped, 46, true)
            SetPedCombatRange(ped, 2)
            SetPedCombatMovement(ped, 3)
        else
            SetPedFleeAttributes(ped, 0, 0)
            SetPedCombatAttributes(ped, 0, true)
            SetPedCombatRange(ped, 0)
            SetPedSeeingRange(ped, 50.0)
            SetPedHearingRange(ped, 50.0)
            SetPedAlertness(ped, 3)
        end
        
        SetPedAccuracy(ped, accuracy or 50)
        
        if weapon and not friendly then
            GiveWeaponToPed(ped, GetHashKey(weapon), 999, false, true)
            SetCurrentPedWeapon(ped, GetHashKey(weapon), true)
        end
        
        if friendly then
            GiveWeaponToPed(ped, GetHashKey("WEAPON_COMBATPISTOL"), 999, false, true)
            SetCurrentPedWeapon(ped, GetHashKey("WEAPON_UNARMED"), true)
        end
        
        SetPedRelationshipGroupHash(ped, GetHashKey("SECURITY_GUARD"))
        
        table.insert(spawnedNPCs, ped)
    end
    
    return ped
end

function SpawnVehicleWithCrew(model, coords, heading, hasWeapon, isAircraft)
    RequestModel(GetHashKey(model))
    while not HasModelLoaded(GetHashKey(model)) do
        Citizen.Wait(10)
    end
    
    local veh = CreateVehicle(GetHashKey(model), coords.x, coords.y, coords.z, heading or 0.0, true, false)
    
    if DoesEntityExist(veh) then
        SetVehicleOnGroundProperly(veh)
        SetVehicleEngineOn(veh, true, true, false)
        
        if isAircraft then
            SetVehicleEngineHealth(veh, 1000.0)
            SetHeliBladesFullSpeed(veh)
        end
        
        local driverModel = "s_m_m_marine_01"
        if Config.Airport then
            driverModel = Config.Airport.npcs.security.models[1]
        end
        
        local driver = CreatePedInsideVehicle(veh, 4, GetHashKey(driverModel), -1, true, false)
        
        if hasWeapon and not isAircraft then
            local passenger = CreatePedInsideVehicle(veh, 4, GetHashKey(driverModel), 0, true, false)
            GiveWeaponToPed(passenger, GetHashKey("WEAPON_COMBATPISTOL"), 999, false, true)
        end
        
        table.insert(spawnedVehicles, veh)
    end
    
    return veh
end

function CleanUpSpawns()
    for _, ped in ipairs(spawnedNPCs) do
        if DoesEntityExist(ped) then
            SetPedAsNoLongerNeeded(ped)
            DeleteEntity(ped)
        end
    end
    
    for _, veh in ipairs(spawnedVehicles) do
        if DoesEntityExist(veh) then
            SetEntityAsNoLongerNeeded(veh)
            DeleteEntity(veh)
        end
    end
    
    spawnedNPCs = {}
    spawnedVehicles = {}
    airportGuards = {}
    metroGuards = {}
end

-- ===== AIRPORT SECURITY SYSTEM =====

local airportGuardsSpawned = false

function HandleAirportSecurity()
    local playerPed = PlayerPedId()
    
    if not Config.Airport.enabled or IsPedDeadOrDying(playerPed, true) then
        if airportGuardsSpawned then
            CleanUpAirportGuards()
            airportGuardsSpawned = false
            airportWeaponWarning = false
        end
        return
    end
    
    local inAirport, zone = IsInAirportZone()
    
    if inAirport then
        if not airportNotified then
            SendZoneNotification(Config.Airport.notification.friendly)
            airportNotified = true
        end
        
        if not airportGuardsSpawned then
            SpawnAirportGuards(zone)
            airportGuardsSpawned = true
        end
        
        if Config.Airport.weaponDetection.enabled then
            local currentTime = GetGameTimer()
            if currentTime - lastWeaponCheck >= Config.Airport.weaponDetection.checkInterval then
                lastWeaponCheck = currentTime
                CheckAirportWeapons(zone)
            end
        end
    else
        if airportGuardsSpawned then
            airportNotified = false
            airportWeaponWarning = false
            CleanUpAirportGuards()
            airportGuardsSpawned = false
        end
    end
end

function SpawnAirportGuards(zone)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local guardCount = Config.Airport.npcs.security.guardsPerZone[zone.type] or 4
    
    if #airportGuards >= Config.Airport.npcs.security.maxGuards then
        return
    end
    
    local guardsToSpawn = math.min(guardCount, Config.Airport.npcs.security.maxGuards - #airportGuards)
    local patrolPoints = Config.Airport.npcs.security.patrolPoints[zone.type]
    
    for i = 1, guardsToSpawn do
        local spawnPos
        if patrolPoints and #patrolPoints > 0 then
            local patrolPoint = patrolPoints[math.random(1, #patrolPoints)]
            spawnPos = vector3(
                patrolPoint.x + math.random(-10, 10),
                patrolPoint.y + math.random(-10, 10),
                patrolPoint.z
            )
        else
            local angle = (360 / guardsToSpawn) * i
            local radius = math.random(30, 60)
            spawnPos = vector3(
                playerCoords.x + math.cos(math.rad(angle)) * radius,
                playerCoords.y + math.sin(math.rad(angle)) * radius,
                playerCoords.z
            )
        end
        
        local model = Config.Airport.npcs.security.models[math.random(1, #Config.Airport.npcs.security.models)]
        local guard = SpawnNPC(model, spawnPos, nil, Config.Airport.npcs.security.accuracy, true)
        
        if DoesEntityExist(guard) then
            TaskGuardStand(guard, spawnPos, 10.0, 10.0, 3)
            table.insert(airportGuards, guard)
        end
    end
    
    for _, vehicleData in ipairs(Config.Airport.npcs.vehicles) do
        if vehicleData.patrol then
            for i = 1, (vehicleData.count or 1) do
                local angle = math.random(0, 360)
                local radius = math.random(80, 120)
                local spawnX = playerCoords.x + math.cos(math.rad(angle)) * radius
                local spawnY = playerCoords.y + math.sin(math.rad(angle)) * radius
                
                SpawnVehicleWithCrew(vehicleData.model, vector3(spawnX, spawnY, playerCoords.z), angle, false, false)
            end
        end
    end
end

function CheckAirportWeapons(zone)
    local playerPed = PlayerPedId()
    local hasWeapon, weaponHash, weaponName = HasWeaponDrawn()
    
    if hasWeapon then
        if not airportWeaponWarning then
            SendZoneNotification(Config.Airport.notification.weaponWarning)
            airportWeaponWarning = true
        end
        
        local playerCoords = GetEntityCoords(playerPed)
        local isAggressive = IsAggressiveWeapon(weaponHash)
        
        for _, guard in ipairs(airportGuards) do
            if DoesEntityExist(guard) and not IsPedDeadOrDying(guard, true) then
                local guardCoords = GetEntityCoords(guard)
                local distance = #(playerCoords - guardCoords)
                
                if distance <= Config.Airport.weaponDetection.alertRadius then
                    local guardWeapon = isAggressive and "WEAPON_PUMPSHOTGUN" or "WEAPON_COMBATPISTOL"
                    GiveWeaponToPed(guard, GetHashKey(guardWeapon), 999, false, true)
                    SetCurrentPedWeapon(guard, GetHashKey(guardWeapon), true)
                    
                    SetPedCombatAttributes(guard, 46, true)
                    SetPedCombatRange(guard, 2)
                    TaskCombatPed(guard, playerPed, 0, 16)
                    
                    for _, otherGuard in ipairs(airportGuards) do
                        if DoesEntityExist(otherGuard) and not IsPedDeadOrDying(otherGuard, true) then
                            local otherDistance = #(guardCoords - GetEntityCoords(otherGuard))
                            if otherDistance <= 100.0 then
                                GiveWeaponToPed(otherGuard, GetHashKey("WEAPON_COMBATPISTOL"), 999, false, true)
                                TaskCombatPed(otherGuard, playerPed, 0, 16)
                            end                        end
                    end
                end
            end
        end
    else
        if airportWeaponWarning then
            airportWeaponWarning = false
            Citizen.SetTimeout(10000, function()
                ResetAirportGuards()
            end)
        end
    end
end

function ResetAirportGuards()
    for _, guard in ipairs(airportGuards) do
        if DoesEntityExist(guard) and not IsPedDeadOrDying(guard, true) then
            ClearPedTasks(guard)
            SetCurrentPedWeapon(guard, GetHashKey("WEAPON_UNARMED"), true)
            SetPedCombatAttributes(guard, 0, true)
            local guardCoords = GetEntityCoords(guard)
            TaskGuardStand(guard, guardCoords, 10.0, 10.0, 3)
        end
    end
end

function CleanUpAirportGuards()
    for _, guard in ipairs(airportGuards) do
        if DoesEntityExist(guard) then
            SetPedAsNoLongerNeeded(guard)
            DeleteEntity(guard)
        end
    end
    airportGuards = {}
end

-- ===== METRO SECURITY SYSTEM =====

local metroGuardsSpawned = false

function HandleMetroSecurity()
    local playerPed = PlayerPedId()
    
    if not Config.Metro.enabled or IsPedDeadOrDying(playerPed, true) then
        if metroGuardsSpawned then
            CleanUpMetroGuards()
            metroGuardsSpawned = false
            metroWeaponWarning = false
        end
        return
    end
    
    local inMetro, station = IsInMetroStation()
    
    if inMetro then
        if not metroNotified then
            SendZoneNotification(Config.Metro.notification.friendly)
            metroNotified = true
            currentMetroStation = station
        end
        
        if not metroGuardsSpawned then
            SpawnMetroGuards(station)
            metroGuardsSpawned = true
        end
        
        if Config.Metro.weaponDetection.enabled then
            local currentTime = GetGameTimer()
            if currentTime - lastWeaponCheck >= Config.Metro.weaponDetection.checkInterval then
                lastWeaponCheck = currentTime
                CheckMetroWeapons(station)
            end
        end
    else
        if metroGuardsSpawned then
            metroNotified = false
            metroWeaponWarning = false
            currentMetroStation = nil
            CleanUpMetroGuards()
            metroGuardsSpawned = false
        end
    end
end

function SpawnMetroGuards(station)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local guardCount = Config.Metro.npcs.security.guardsPerStation
    
    if #metroGuards >= Config.Metro.npcs.security.maxGuards then
        return
    end
    
    local guardsToSpawn = math.min(guardCount, Config.Metro.npcs.security.maxGuards - #metroGuards)
    
    for i = 1, guardsToSpawn do
        local angle = (360 / guardsToSpawn) * i
        local radius = math.random(15, 30)
        
        local spawnPos = vector3(
            station.coords.x + math.cos(math.rad(angle)) * radius,
            station.coords.y + math.sin(math.rad(angle)) * radius,
            station.coords.z
        )
        
        local model = Config.Metro.npcs.security.models[math.random(1, #Config.Metro.npcs.security.models)]
        local guard = SpawnNPC(model, spawnPos, nil, Config.Metro.npcs.security.accuracy, true)
        
        if DoesEntityExist(guard) then
            if Config.Metro.npcs.security.patrolBehavior == "stationary" then
                TaskGuardStand(guard, spawnPos, 5.0, 5.0, 1)
            else
                TaskGuardStand(guard, spawnPos, Config.Metro.npcs.security.patrolRadius, 5.0, 3)
            end
            table.insert(metroGuards, guard)
        end
    end
end

function CheckMetroWeapons(station)
    local playerPed = PlayerPedId()
    local hasWeapon, weaponHash, weaponName = HasWeaponDrawn()
    
    if hasWeapon then
        if not metroWeaponWarning then
            SendZoneNotification(Config.Metro.notification.weaponWarning)
            metroWeaponWarning = true
        end
        
        local playerCoords = GetEntityCoords(playerPed)
        local isAggressive = IsAggressiveWeapon(weaponHash)
        
        for _, guard in ipairs(metroGuards) do
            if DoesEntityExist(guard) and not IsPedDeadOrDying(guard, true) then
                local guardCoords = GetEntityCoords(guard)
                local distance = #(playerCoords - guardCoords)
                
                if distance <= Config.Metro.weaponDetection.alertRadius then
                    local guardWeapon = isAggressive and "WEAPON_COMBATPISTOL" or "WEAPON_STUNGUN"
                    GiveWeaponToPed(guard, GetHashKey(guardWeapon), 999, false, true)
                    SetCurrentPedWeapon(guard, GetHashKey(guardWeapon), true)
                    
                    SetPedCombatAttributes(guard, 46, true)
                    SetPedCombatRange(guard, 2)
                    TaskCombatPed(guard, playerPed, 0, 16)
                    
                    for _, otherGuard in ipairs(metroGuards) do
                        if DoesEntityExist(otherGuard) and not IsPedDeadOrDying(otherGuard, true) then
                            local otherDistance = #(guardCoords - GetEntityCoords(otherGuard))
                            if otherDistance <= 50.0 then
                                GiveWeaponToPed(otherGuard, GetHashKey("WEAPON_STUNGUN"), 999, false, true)
                                TaskCombatPed(otherGuard, playerPed, 0, 16)
                            end
                        end
                    end
                end
            end
        end
    else
        if metroWeaponWarning then
            metroWeaponWarning = false
            Citizen.SetTimeout(10000, function()
                ResetMetroGuards()
            end)
        end
    end
end

function ResetMetroGuards()
    for _, guard in ipairs(metroGuards) do
        if DoesEntityExist(guard) and not IsPedDeadOrDying(guard, true) then
            ClearPedTasks(guard)
            SetCurrentPedWeapon(guard, GetHashKey("WEAPON_UNARMED"), true)
            SetPedCombatAttributes(guard, 0, true)
            local guardCoords = GetEntityCoords(guard)
            TaskGuardStand(guard, guardCoords, 5.0, 5.0, 1)
        end
    end
end

function CleanUpMetroGuards()
    for _, guard in ipairs(metroGuards) do
        if DoesEntityExist(guard) then
            SetPedAsNoLongerNeeded(guard)
            DeleteEntity(guard)
        end
    end
    metroGuards = {}
end

-- ===== MILITARY BASE SYSTEM =====

local militaryForcesSpawned = false

function HandleMilitaryBase()
    local playerPed = PlayerPedId()
    
    if not Config.MilitaryBase.enabled or IsSafeJob() or IsPedDeadOrDying(playerPed, true) then
        if militaryForcesSpawned then
            CleanUpSpawns()
            militaryForcesSpawned = false
            passedGateEntry = false
        end
        return
    end
    
    local hasEntered, gateCoords = HasEnteredMilitaryGate()
    local inside = IsInsideMilitaryBase()
    local currentTime = GetGameTimer()
    
    if hasEntered and not passedGateEntry then
        passedGateEntry = true
        lastGateEntryTime = currentTime
        
        if not militaryNotified then
            SendZoneNotification(Config.MilitaryBase.notification)
            militaryNotified = true
            TriggerServerEvent('npc_reactions:logZoneViolation', 'military', Config.MilitaryBase.zoneName, GetEntityCoords(playerPed))
        end
        
        SpawnMilitaryForces()
        
    elseif inside and passedGateEntry then
        if currentTime - lastGateEntryTime > Config.MilitaryBase.chaseSettings.chaseTimeout then
            passedGateEntry = false
            militaryNotified = false
            CleanUpSpawns()
            militaryForcesSpawned = false
        else
            if not militaryForcesSpawned then
                SpawnMilitaryForces()
            end
        end
        
    elseif not inside and not hasEntered and passedGateEntry then
        local distanceFromGate = gateCoords and #(GetEntityCoords(playerPed) - gateCoords) or 0
        
        if distanceFromGate <= Config.MilitaryBase.chaseSettings.maxChaseDistance then
            if not militaryForcesSpawned then
                SpawnMilitaryForces()
            end
        else
            passedGateEntry = false
            militaryNotified = false
            CleanUpSpawns()
            militaryForcesSpawned = false
        end
        
        if currentTime - lastGateEntryTime > Config.MilitaryBase.chaseSettings.chaseTimeout then
            passedGateEntry = false
            militaryNotified = false
            CleanUpSpawns()
            militaryForcesSpawned = false
        end
    end
end

function SpawnMilitaryForces()
    CleanUpSpawns()
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    for i = 1, Config.MilitaryBase.npcs.soldiers.count do
        local angle = (360 / Config.MilitaryBase.npcs.soldiers.count) * i
        local radius = math.random(30, 50)
        local spawnX = playerCoords.x + math.cos(math.rad(angle)) * radius
        local spawnY = playerCoords.y + math.sin(math.rad(angle)) * radius
        local spawnZ = playerCoords.z
        
        local model = Config.MilitaryBase.npcs.soldiers.models[math.random(1, #Config.MilitaryBase.npcs.soldiers.models)]
        local weapon = Config.MilitaryBase.npcs.soldiers.weapons[math.random(1, #Config.MilitaryBase.npcs.soldiers.weapons)]
        
        SpawnNPC(model, vector3(spawnX, spawnY, spawnZ), weapon, Config.MilitaryBase.npcs.soldiers.accuracy, false)
    end
    
    for _, vehicleData in ipairs(Config.MilitaryBase.npcs.vehicles) do
        for i = 1, (vehicleData.count or 1) do
            local angle = math.random(0, 360)
            local radius = math.random(60, 100)
            local spawnX = playerCoords.x + math.cos(math.rad(angle)) * radius
            local spawnY = playerCoords.y + math.sin(math.rad(angle)) * radius
            local spawnZ = vehicleData.airVehicle and playerCoords.z + 50.0 or playerCoords.z
            
            SpawnVehicleWithCrew(
                vehicleData.model,
                vector3(spawnX, spawnY, spawnZ),
                angle,
                vehicleData.weapon,
                vehicleData.airVehicle
            )
        end
    end
    
    militaryForcesSpawned = true
end

-- ===== PRISON SYSTEM =====

local prisonForcesSpawned = false

function HandlePrison()
    local playerPed = PlayerPedId()
    
    if not Config.Prison.enabled or IsSafeJob() or IsPedDeadOrDying(playerPed, true) then
        if prisonForcesSpawned then
            CleanUpSpawns()
            prisonForcesSpawned = false
        end
        return
    end
    
    if IsPlayerPrisoner() then
        if prisonForcesSpawned then
            CleanUpSpawns()
            prisonForcesSpawned = false
        end
        return
    end
    
    local inZone = IsInPrisonZone()
    
    if inZone and not prisonForcesSpawned then
        if not prisonNotified then
            SendZoneNotification(Config.Prison.notification)
            prisonNotified = true
            TriggerServerEvent('npc_reactions:logZoneViolation', 'prison', Config.Prison.zoneName, GetEntityCoords(playerPed))
        end
        
        local playerCoords = GetEntityCoords(playerPed)
        
        for i = 1, Config.Prison.npcs.guards.count do
            local angle = (360 / Config.Prison.npcs.guards.count) * i
            local radius = math.random(25, 40)
            local spawnX = playerCoords.x + math.cos(math.rad(angle)) * radius
            local spawnY = playerCoords.y + math.sin(math.rad(angle)) * radius
            
            local model = Config.Prison.npcs.guards.models[math.random(1, #Config.Prison.npcs.guards.models)]
            local weapon = Config.Prison.npcs.guards.weapons[math.random(1, #Config.Prison.npcs.guards.weapons)]
            
            local guard = SpawnNPC(model, vector3(spawnX, spawnY, playerCoords.z), weapon, Config.Prison.npcs.guards.accuracy, false)
            
            if DoesEntityExist(guard) then
                TaskCombatPed(guard, playerPed, 0, 16)
            end
        end
        
        for _, vehicleData in ipairs(Config.Prison.npcs.vehicles) do
            for i = 1, (vehicleData.count or 1) do
                local angle = math.random(0, 360)
                local radius = math.random(50, 80)
                local spawnX = playerCoords.x + math.cos(math.rad(angle)) * radius
                local spawnY = playerCoords.y + math.sin(math.rad(angle)) * radius
                
                SpawnVehicleWithCrew(vehicleData.model, vector3(spawnX, spawnY, playerCoords.z), angle, vehicleData.weapon or false, false)
            end
        end
        
        prisonForcesSpawned = true
        
    elseif not inZone and prisonForcesSpawned then
        prisonNotified = false
        CleanUpSpawns()
        prisonForcesSpawned = false
    end
end

-- ===== TRAFFIC POLICE SYSTEM =====

local trafficForcesSpawned = false
local lastSpeedCheck = 0

function HandleTrafficPolice()
    local playerPed = PlayerPedId()
    local currentTime = GetGameTimer()
    
    if not Config.TrafficPolice.enabled or IsSafeJob() or IsPedDeadOrDying(playerPed, true) then
        if trafficForcesSpawned then
            CleanUpSpawns()
            trafficForcesSpawned = false
        end
        return
    end
    
    local inZone = false
    local playerCoords = GetEntityCoords(playerPed)
    
    for _, zone in ipairs(Config.TrafficPolice.zones) do
        if #(playerCoords - zone.coords) <= zone.radius then
            inZone = true
            break
        end
    end
    
    if inZone then
        if not trafficNotified then
            SendZoneNotification(Config.TrafficPolice.notification)
            trafficNotified = true
        end
        
        if currentTime - lastSpeedCheck >= Config.TrafficPolice.violations.speedCheckInterval then
            lastSpeedCheck = currentTime
            CheckTrafficViolations()
        end
        
        if trafficForcesSpawned then
            local allDead = true
            for _, ped in ipairs(spawnedNPCs) do
                if DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then
                    allDead = false
                    break
                end
            end
            
            if allDead then
                CleanUpSpawns()
                trafficForcesSpawned = false
            end
        end
        
    elseif not inZone and trafficForcesSpawned then
        trafficNotified = false
        CleanUpSpawns()
        trafficForcesSpawned = false
    end
end

function CheckTrafficViolations()
    local playerPed = PlayerPedId()
    
    if not IsPedInAnyVehicle(playerPed, false) then
        return
    end
    
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    local driverPed = GetPedInVehicleSeat(vehicle, -1)
    
    if driverPed ~= playerPed then
        return
    end
    
    local speed = GetEntitySpeed(vehicle) * 3.6
    local speedLimit = Config.TrafficPolice.violations.speedLimit
    local violation = nil
    local fineAmount = 0
    
    if speed > speedLimit + Config.TrafficPolice.violations.majorSpeedingThreshold then
        violation = Config.TrafficPolice.fines.majorSpeeding
        fineAmount = math.random(violation.min, violation.max)
    elseif speed > speedLimit + Config.TrafficPolice.violations.minorSpeedingThreshold then
        violation = Config.TrafficPolice.fines.minorSpeeding
        fineAmount = math.random(violation.min, violation.max)
    end
    
    if Config.TrafficPolice.violations.checkAggressive then
        if IsVehicleInBurnout(vehicle) or (speed > 80.0 and IsVehicleOnAllWheels(vehicle) == false) then
            violation = Config.TrafficPolice.fines.recklessDriving
            fineAmount = math.random(violation.min, violation.max)
        end
    end
    
    if Config.TrafficPolice.violations.checkHitAndRun then
        if HasEntityBeenDamagedByAnyPed(vehicle) or HasEntityBeenDamagedByAnyVehicle(vehicle) then
            local lastDamaged = GetTimeSinceLastVehicleDamage(vehicle)
            if lastDamaged > 0 and lastDamaged < 10000 then
                violation = Config.TrafficPolice.fines.hitAndRun
                fineAmount = math.random(violation.min, violation.max)
            end
        end
    end
    
    if violation and fineAmount > 0 then
        local currentTime = GetGameTimer()
        if currentTime - lastFineTime >= fineCooldown then
            lastFineTime = currentTime
            IssueTrafficFine(fineAmount, violation.label)
        end
    end
end

function IssueTrafficFine(amount, reason)
    TriggerServerEvent('npc_reactions:processFine', amount, reason)
    SpawnTrafficPolice()
end

function SpawnTrafficPolice()
    if trafficForcesSpawned then
        return
    end
    
    CleanUpSpawns()
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    for i = 1, Config.TrafficPolice.npcs.officers.count do
        local angle = math.random(0, 360)
        local radius = math.random(30, 60)
        local spawnX = playerCoords.x + math.cos(math.rad(angle)) * radius
        local spawnY = playerCoords.y + math.sin(math.rad(angle)) * radius
        
        local model = Config.TrafficPolice.npcs.officers.models[math.random(1, #Config.TrafficPolice.npcs.officers.models)]
        local officer = SpawnNPC(model, vector3(spawnX, spawnY, playerCoords.z), nil, Config.TrafficPolice.npcs.officers.accuracy, false)
        
        if DoesEntityExist(officer) then
            SetPedAsCop(officer, true)
            TaskCombatPed(officer, playerPed, 0, 16)
        end
    end
    
    for _, vehicleData in ipairs(Config.TrafficPolice.npcs.vehicles) do
        for i = 1, (vehicleData.count or 1) do
            local angle = math.random(0, 360)
            local radius = math.random(50, 100)
            local spawnX = playerCoords.x + math.cos(math.rad(angle)) * radius
            local spawnY = playerCoords.y + math.sin(math.rad(angle)) * radius
            
            RequestModel(GetHashKey(vehicleData.model))
            while not HasModelLoaded(GetHashKey(vehicleData.model)) do
                Citizen.Wait(10)
            end
            
            local veh = CreateVehicle(GetHashKey(vehicleData.model), spawnX, spawnY, playerCoords.z, angle, true, false)
            if DoesEntityExist(veh) then
                SetVehicleOnGroundProperly(veh)
                SetVehicleEngineOn(veh, true, true, false)
                SetVehicleSiren(veh, true)
                
                local driverModel = Config.TrafficPolice.npcs.officers.models[1]
                local driver = CreatePedInsideVehicle(veh, 4, GetHashKey(driverModel), -1, true, false)
                
                if IsPedInAnyVehicle(playerPed, false) then
                    local playerVeh = GetVehiclePedIsIn(playerPed, false)
                    TaskVehicleChase(driver, playerVeh)
                end
                
                table.insert(spawnedVehicles, veh)
            end
        end
    end
    
    trafficForcesSpawned = true
    
    Citizen.SetTimeout(30000, function()
        if trafficForcesSpawned then
            CleanUpSpawns()
            trafficForcesSpawned = false
        end
    end)
end

-- Handle fine payment events
RegisterNetEvent('npc_reactions:finePaid')
AddEventHandler('npc_reactions:finePaid', function(data)
    if data.success then
        SendNotification(
            "FINE PAID",
            "Traffic Violation",
            string.format("$%d has been deducted from your %s for: %s", data.amount, data.method, data.reason),
            "CHAR_BANK_MAZE",
            1,
            false
        )
        
        if trafficForcesSpawned then
            Citizen.SetTimeout(5000, function()
                CleanUpSpawns()
                trafficForcesSpawned = false
            end)
        end
    end
end)

RegisterNetEvent('npc_reactions:fineFailed')
AddEventHandler('npc_reactions:fineFailed', function(data)
    if not data.success then
        SendNotification(
            "PAYMENT FAILED",
            "Insufficient Funds",
            string.format("You owe $%d for %s but lack sufficient funds. Police are investigating!", data.amount, data.reason),
            "CHAR_BLOCKED",
            1,
            true
        )
        
        if trafficForcesSpawned then
            for _, ped in ipairs(spawnedNPCs) do
                if DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then
                    GiveWeaponToPed(ped, GetHashKey("WEAPON_COMBATPISTOL"), 999, false, true)
                    TaskCombatPed(ped, PlayerPedId(), 0, 16)
                end
            end
        end
    end
end)

-- ===== MAIN UPDATE LOOP =====

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.General.updateInterval)
        
        local playerPed = PlayerPedId()
        
        if not IsPedDeadOrDying(playerPed, true) then
            if isDead then
                isDead = false
                passedGateEntry = false
                militaryNotified = false
                prisonNotified = false
                trafficNotified = false
                airportNotified = false
                metroNotified = false
                airportWeaponWarning = false
                metroWeaponWarning = false
                CleanUpSpawns()
                militaryForcesSpawned = false
                prisonForcesSpawned = false
                trafficForcesSpawned = false
                airportGuardsSpawned = false
                metroGuardsSpawned = false
            end
            
            HandleMilitaryBase()
            HandlePrison()
            HandleTrafficPolice()
            HandleAirportSecurity()
            HandleMetroSecurity()
        elseif not isDead then
            isDead = true
            CleanUpSpawns()
        end
    end
end)

-- Clean up on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        CleanUpSpawns()
    end
end)

-- Debug display
if Config.General.debug then
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(1000)
            
            local inAirport, zone = IsInAirportZone()
            local inMetro, station = IsInMetroStation()
            
            local text = "=== NPC REACTIONS DEBUG ===\n"
            text = text .. "Safe Job: " .. tostring(IsSafeJob()) .. "\n"
            text = text .. "Is Prisoner: " .. tostring(IsPlayerPrisoner()) .. "\n"
            text = text .. "Military Gate: " .. tostring(passedGateEntry) .. "\n"
            text = text .. "Airport: " .. tostring(inAirport) .. "\n"
            text = text .. "Metro: " .. tostring(inMetro) .. "\n"
            if station then
                text = text .. "Station: " .. station.name .. "\n"
            end
            text = text .. "Airport Guards: " .. #airportGuards .. "\n"
            text = text .. "Metro Guards: " .. #metroGuards .. "\n"
            text = text .. "Total NPCs: " .. #spawnedNPCs .. "\n"
            text = text .. "Total Vehicles: " .. #spawnedVehicles
            
            SetTextFont(4)
            SetTextScale(0.3, 0.3)
            SetTextColour(0, 255, 0, 255)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(1, 0, 0, 0, 255)
            SetTextEntry("STRING")
            AddTextComponentString(text)
            DrawText(0.015, 0.015)
        end
    end)
end
