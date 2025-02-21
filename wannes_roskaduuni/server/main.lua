local QBCore = exports['qb-core']:GetCoreObject() -- Mikäs frameworkki?
local Routes = {}

QBCore.Functions.CreateCallback("garbagejob:server:NewShift", function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    local CitizenId = Player.PlayerData.citizenid
    local shouldContinue = false
    local nextStop = 0
    local totalNumberOfStops = 0
    local bagNum = 0

    if Player.Functions.RemoveMoney("bank", Config.TruckPrice, "garbo-truck-dep") then
        math.randomseed(os.time())
        local MaxStops = math.random(Config.MinStops, #Config.Locations["trashcan"])
        local allStops = {}

        for i=1, MaxStops do
            local stop = math.random(1,#Config.Locations["trashcan"])
            local newBagAmount = math.random(Config.MinBagsPerStop, Config.MaxBagsPerStop)
            allStops[#allStops+1] = {stop = stop, bags = newBagAmount}
        end

        Routes[CitizenId] = {
            stops = allStops,
            currentStop = 1,
            started = true,
            currentDistance = 0,
            depositPay = Config.TruckPrice,
            actualPay = 0,
            stopsCompleted = 0,
            totalNumberOfStops = #allStops
        }

        nextStop = allStops[1].stop
        shouldContinue = true
        totalNumberOfStops = #allStops
        bagNum = allStops[1].bags
    else
        TriggerClientEvent('QBCore:Notify', source, 'Ei tarpeeksi rahaa ('..Config.TruckPrice..' required)', "error")
    end
    cb(shouldContinue, nextStop, bagNum, totalNumberOfStops)
end)


QBCore.Functions.CreateCallback("garbagejob:server:NextStop", function(source, cb, currentStop, currentStopNum, currLocation)
    local Player = QBCore.Functions.GetPlayer(source)
    local CitizenId = Player.PlayerData.citizenid

    local currStopCoords = Config.Locations["trashcan"][currentStop].coords
    currStopCoords = vector3(currStopCoords.x, currStopCoords.y, currStopCoords.z)

    local distance = #(currLocation - currStopCoords)
    local newStop = 0
    local shouldContinue = false
    local newBagAmount = 0

    if(math.random(100) >= Config.CryptoStickChance) and Config.GiveCryptoStick then
        Player.Functions.AddItem("cryptostick", 1, false)
        TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items["cryptostick"], 'add')
        TriggerClientEvent('QBCore:Notify', source, "Löysit jotain lattialta")
    end

    if distance <= 10 then
        if currentStopNum >= #Routes[CitizenId].stops then
            Routes[CitizenId].stopsCompleted = tonumber(Routes[CitizenId].stopsCompleted) + 1
            newStop = currentStop
        else
            newStop = Routes[CitizenId].stops[currentStopNum+1].stop
            newBagAmount = Routes[CitizenId].stops[currentStopNum+1].bags
            shouldContinue = true
            local bagAmount = Routes[CitizenId].stops[currentStopNum].bags
            local totalNewPay = 0

            for i = 1, bagAmount do
                totalNewPay = totalNewPay + math.random(Config.BagLowerWorth, Config.BagUpperWorth)
            end

            Routes[CitizenId].actualPay = math.ceil(Routes[CitizenId].actualPay + totalNewPay)
            Routes[CitizenId].stopsCompleted = tonumber(Routes[CitizenId].stopsCompleted) + 1
        end
    else
        TriggerClientEvent('QBCore:Notify', source, 'Olet liian kaukana palautus pisteestä', "error")
    end

    cb(shouldContinue,newStop,newBagAmount)
end)

QBCore.Functions.CreateCallback('garbagejob:server:EndShift', function(source, cb, location)
    local Player = QBCore.Functions.GetPlayer(source)
    local CitizenId = Player.PlayerData.citizenid
    local distance = #(location - vector3(Config.Locations["vehicle"].coords.x, Config.Locations["vehicle"].coords.y, Config.Locations["vehicle"].coords.z))

    if(distance < 10) then
        if Routes[CitizenId] ~= nil then
            cb(true)
        else
            cb(false)
        end
    else
        TriggerClientEvent('QBCore:Notify', source, 'Olet liian kaukana palautus pisteestä', "error")
        cb(false)
    end
end)

RegisterNetEvent('garbagejob:server:PayShift', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local CitizenId = Player.PlayerData.citizenid

    if Routes[CitizenId] ~= nil then
        local depositPay = Routes[CitizenId].depositPay
        if tonumber(Routes[CitizenId].stopsCompleted) < tonumber(Routes[CitizenId].totalNumberOfStops) then
            -- local totalComplete = math.floor((Routes[CitizenId].stopsCompleted/Routes[CitizenId].totalNumberOfStops) * 100) -- JOTAIN PASKOJA
            -- depositPay = math.ceil((totalComplete/Routes[CitizenId].depositPay) * 100) -- JOTAIN PASKOJA
            depositPay = 0
            TriggerClientEvent('QBCore:Notify', src, "Lopetit työt liian aikasin (Tehty: "..Routes[CitizenId].stopsCompleted .." Totaali määrä: "..Routes[CitizenId].totalNumberOfStops.."), Sinulle on palautettu jotain", "error")
        end

        local totalToPay = depositPay + Routes[CitizenId].actualPay
        local payoutDeposit = "(+ €"..depositPay.." deposit)"
        if depositPay == 0 then
            payoutDeposit = ""
        end

        Player.Functions.AddMoney("bank", totalToPay , 'garbage-payslip')
        TriggerClientEvent('QBCore:Notify', src, "Sinä ansaitsit €"..totalToPay..", sinun palkkakuittisi "..payoutDeposit.." se maksettiin tilillesi!", "success")
        Routes[CitizenId] = nil
    else
        TriggerClientEvent('QBCore:Notify', source, 'Et lopettanut työvuoroasi milloinkaan', "error")
    end
end)

QBCore.Commands.Add("cleargarbroutes", "Poista kaikki roskalenkit", {{name="id", help="Kaupunkilais (ID)"}}, false, function(source, args)
    local Player = QBCore.Functions.GetPlayer(tonumber(args[1]))
    local CitizenId = Player.PlayerData.citizenid
    local count = 0
    for k,v in pairs(Routes) do
        if k == CitizenId then
            count = count + 1
        end
    end

    TriggerClientEvent('QBCore:Notify', source, "Reitit on poistettu "..count.." reitit tallennettiin järjestejlmään", "success")
    Routes[CitizenId] = nil
end, "admin")
