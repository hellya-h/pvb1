-- Auto Pet Seller & Buyer - One Click Farm Script
-- Автоматически включает все функции для фарма

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Конфигурация
local CONFIG = {
    MIN_WEIGHT_TO_KEEP = 300, -- Минимальный вес для сохранения пета
    MAX_WEIGHT_TO_KEEP = 50000, -- Максимальный вес для сохранения пета
    SELL_DELAY = 0.01, -- Задержка между продажами
    BUY_DELAY = 0.01, -- Задержка между покупками
    BUY_INTERVAL = 2, -- Интервал между циклами покупки (секунды)
    COLLECT_INTERVAL = 60, -- Интервал сбора монет (секунды)
    REPLACE_INTERVAL = 30, -- Интервал замены брейнротов (секунды)
    PLANT_INTERVAL = 10, -- Интервал посадки растений (секунды)
    WATER_INTERVAL = 5, -- Интервал полива растений (секунды)
    PLATFORM_BUY_INTERVAL = 120, -- Интервал покупки платформ (секунды)
    LOG_COPY_KEY = Enum.KeyCode.F4, -- Клавиша для копирования логов
    AUTO_BUY_SEEDS = true, -- Авто-покупка семян
    AUTO_BUY_GEAR = true, -- Авто-покупка предметов
    AUTO_COLLECT_COINS = true, -- Авто-сбор монет
    AUTO_REPLACE_BRAINROTS = true, -- Авто-замена брейнротов
    AUTO_PLANT_SEEDS = true, -- Авто-посадка семян
    AUTO_WATER_PLANTS = true, -- Авто-полив растений
    AUTO_BUY_PLATFORMS = true, -- Авто-покупка платформ
    DEBUG_COLLECT_COINS = true, -- Отладочные сообщения для сбора монет
    DEBUG_PLANTING = true, -- Отладочные сообщения для посадки
    SMART_SELLING = true, -- Умная система продажи (адаптивная)
}

-- Редкости петов в порядке возрастания
local RARITY_ORDER = {
    ["Rare"] = 1,
    ["Epic"] = 2,
    ["Legendary"] = 3,
    ["Mythic"] = 4,
    ["Godly"] = 5,
    ["Secret"] = 6,
    ["Limited"] = 7
}

-- Переменные
local logs = {}
local itemSellRemote = nil
local dataRemoteEvent = nil
local useItemRemote = nil
local openEggRemote = nil
local playerData = nil
local protectedPet = nil -- Защищенный от продажи пет (в руке для замены)
local petAnalysis = nil -- Анализ текущего состояния петов
local currentPlot = nil -- Текущий плот игрока
local plantedSeeds = {} -- Отслеживание посаженных семян
local diagnosticsRun = false -- Флаг для запуска диагностики

-- Коды для ввода
local CODES = {
    "based",
    "stacks",
    "frozen"
}

-- Семена для покупки
local SEEDS = {
    "Cactus Seed",
    "Strawberry Seed", 
    "Sunflower Seed",
    "Pumpkin Seed",
    "Dragon Fruit Seed",
    "Eggplant Seed",
    "Watermelon Seed",
    "Grape Seed",
    "Cocotank Seed",
    "Carnivorous Plant Seed",
    "Mr Carrot Seed",
    "Tomatrio Seed",
    "Shroombino Seed"
}

-- Предметы из Gear Shop
local GEAR_ITEMS = {
    "Water Bucket",
    "Frost Blower",
    "Frost Grenade",
    "Carrot Launcher",
    "Banana Gun"
}

-- Защищенные предметы (не продавать)
local PROTECTED_ITEMS = {
    "Meme Lucky Egg",
    "Godly Lucky Egg",
    "Secret Lucky Egg"
}


-- Инициализация
local function initialize()
    print("Инициализация Auto Pet Seller & Buyer...")
    
    -- Ждем необходимые сервисы
    itemSellRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ItemSell")
    dataRemoteEvent = ReplicatedStorage:WaitForChild("BridgeNet2"):WaitForChild("dataRemoteEvent")
    useItemRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UseItem")
    openEggRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("OpenEgg")
    
    -- Инициализируем PlayerData
    local success, result = pcall(function()
        playerData = require(ReplicatedStorage:WaitForChild("PlayerData"))
    end)
    
    if success then
        print("✅ PlayerData инициализирован успешно")
    else
        print("❌ Ошибка инициализации PlayerData: " .. tostring(result))
        playerData = nil
    end
    
    -- Получаем текущий плот
    local plotNumber = LocalPlayer:GetAttribute("Plot")
    if plotNumber then
        currentPlot = workspace.Plots:FindFirstChild(tostring(plotNumber))
        if currentPlot then
            print("Найден плот: " .. plotNumber)
        else
            print("Плот " .. plotNumber .. " не найден в workspace.Plots")
        end
    else
        print("Атрибут Plot не найден у игрока")
    end
    
    print("Инициализация завершена!")
end

-- Получение веса пета из названия
local function getPetWeight(petName)
    local weight = petName:match("%[(%d+%.?%d*)%s*kg%]")
    return weight and tonumber(weight) or 0
end

-- Получение редкости пета
local function getPetRarity(pet)
    local petData = pet:FindFirstChild(pet.Name)
    if not petData then
        -- Пробуем найти по имени без веса и мутаций
        local cleanName = pet.Name:gsub("%[.*%]%s*", "")
        petData = pet:FindFirstChild(cleanName)
    end
    
    if not petData then
        -- Ищем любой дочерний объект с атрибутом Rarity
        for _, child in pairs(pet:GetChildren()) do
            if child:GetAttribute("Rarity") then
                petData = child
                break
            end
        end
    end
    
    if petData then
        return petData:GetAttribute("Rarity") or "Rare"
    end
    
    return "Rare"
end

-- Проверка защищенных мутаций
local function hasProtectedMutations(petName)
    return petName:find("%[Neon%]") or petName:find("%[Galactic%]")
end

-- Проверка защищенных предметов
local function isProtectedItem(itemName)
    for _, protected in pairs(PROTECTED_ITEMS) do
        if itemName:find(protected) then
            return true
        end
    end
    return false
end

-- Получение информации о пете
local function getPetInfo(pet)
    local petData = pet:FindFirstChild(pet.Name)
    if not petData then
        local cleanName = pet.Name:gsub("%[.*%]%s*", "")
        petData = pet:FindFirstChild(cleanName)
    end
    
    if not petData then
        for _, child in pairs(pet:GetChildren()) do
            if child:GetAttribute("Rarity") then
                petData = child
                break
            end
        end
    end
    
    -- Получаем MoneyPerSecond из UI
    local moneyPerSecond = 0
    if petData then
        local rootPart = petData:FindFirstChild("RootPart")
        if rootPart then
            local brainrotToolUI = rootPart:FindFirstChild("BrainrotToolUI")
            if brainrotToolUI then
                local moneyLabel = brainrotToolUI:FindFirstChild("Money")
                if moneyLabel then
                    -- Парсим MoneyPerSecond из текста типа "$1,234/s"
                    local moneyText = moneyLabel.Text
                    local moneyValue = moneyText:match("%$(%d+,?%d*)/s")
                    if moneyValue then
                        -- Убираем запятые и конвертируем в число
                        local cleanValue = moneyValue:gsub(",", "")
                        moneyPerSecond = tonumber(cleanValue) or 0
                    end
                end
            end
        end
    end
    
    if petData then
        return {
            name = pet.Name,
            weight = getPetWeight(pet.Name),
            rarity = petData:GetAttribute("Rarity") or "Rare",
            worth = petData:GetAttribute("Worth") or 0,
            size = petData:GetAttribute("Size") or 1,
            offset = petData:GetAttribute("Offset") or 0,
            moneyPerSecond = moneyPerSecond
        }
    end
    
    return {
        name = pet.Name,
        weight = getPetWeight(pet.Name),
        rarity = "Rare",
        worth = 0,
        size = 1,
        offset = 0,
        moneyPerSecond = moneyPerSecond
    }
end

-- Получение лучшего брейнрота из инвентаря (для проверки)
local function getBestBrainrotForReplacement()
    local backpack = LocalPlayer:WaitForChild("Backpack")
    local bestBrainrot = nil
    local bestMoneyPerSecond = 0
    
    for _, pet in pairs(backpack:GetChildren()) do
        if pet:IsA("Tool") and pet.Name:match("%[%d+%.?%d*%s*kg%]") then
            local petInfo = getPetInfo(pet)
            local moneyPerSecond = petInfo.moneyPerSecond
            
            if moneyPerSecond > bestMoneyPerSecond then
                bestMoneyPerSecond = moneyPerSecond
                bestBrainrot = pet
            end
        end
    end
    
    return bestBrainrot, bestMoneyPerSecond
end

-- Анализ текущего состояния петов
local function analyzePets()
    local backpack = LocalPlayer:WaitForChild("Backpack")
    local analysis = {
        totalPets = 0,
        petsByRarity = {},
        petsByMoneyPerSecond = {},
        bestMoneyPerSecond = 0,
        worstMoneyPerSecond = math.huge,
        averageMoneyPerSecond = 0,
        totalMoneyPerSecond = 0,
        shouldSellRare = false,
        shouldSellEpic = false,
        shouldSellLegendary = false,
        minMoneyPerSecondToKeep = 0
    }
    
    -- Собираем данные о всех петах
    for _, pet in pairs(backpack:GetChildren()) do
        if pet:IsA("Tool") and pet.Name:match("%[%d+%.?%d*%s*kg%]") then
            local petInfo = getPetInfo(pet)
            local rarity = petInfo.rarity
            local moneyPerSecond = petInfo.moneyPerSecond
            
            analysis.totalPets = analysis.totalPets + 1
            analysis.totalMoneyPerSecond = analysis.totalMoneyPerSecond + moneyPerSecond
            
            -- Группируем по редкости
            if not analysis.petsByRarity[rarity] then
                analysis.petsByRarity[rarity] = 0
            end
            analysis.petsByRarity[rarity] = analysis.petsByRarity[rarity] + 1
            
            -- Отслеживаем лучший и худший MoneyPerSecond
            if moneyPerSecond > analysis.bestMoneyPerSecond then
                analysis.bestMoneyPerSecond = moneyPerSecond
            end
            if moneyPerSecond < analysis.worstMoneyPerSecond then
                analysis.worstMoneyPerSecond = moneyPerSecond
            end
            
            -- Группируем по MoneyPerSecond
            table.insert(analysis.petsByMoneyPerSecond, {
                pet = pet,
                moneyPerSecond = moneyPerSecond,
                rarity = rarity
            })
        end
    end
    
    -- Сортируем по MoneyPerSecond
    table.sort(analysis.petsByMoneyPerSecond, function(a, b)
        return a.moneyPerSecond > b.moneyPerSecond
    end)
    
    -- Вычисляем средний MoneyPerSecond
    if analysis.totalPets > 0 then
        analysis.averageMoneyPerSecond = analysis.totalMoneyPerSecond / analysis.totalPets
    end
    
    -- Умная логика определения, что продавать
    if analysis.totalPets > 0 then
        -- Если у нас мало петов (меньше 10), продаем только самых плохих
        if analysis.totalPets < 10 then
            analysis.minMoneyPerSecondToKeep = analysis.averageMoneyPerSecond * 0.5 -- Оставляем только лучшие 50%
            analysis.shouldSellRare = false
            analysis.shouldSellEpic = false
            analysis.shouldSellLegendary = false
        -- Если у нас среднее количество петов (10-20), начинаем продавать Rare
        elseif analysis.totalPets < 20 then
            analysis.minMoneyPerSecondToKeep = analysis.averageMoneyPerSecond * 0.7
            analysis.shouldSellRare = true
            analysis.shouldSellEpic = false
            analysis.shouldSellLegendary = false
        -- Если у нас много петов (20+), продаем Rare и Epic
        else
            analysis.minMoneyPerSecondToKeep = analysis.averageMoneyPerSecond * 0.8
            analysis.shouldSellRare = true
            analysis.shouldSellEpic = true
            analysis.shouldSellLegendary = false
        end
        
        -- Дополнительная проверка: если у нас есть очень хорошие петы, можем продавать и Legendary
        if analysis.bestMoneyPerSecond > analysis.averageMoneyPerSecond * 2 then
            analysis.shouldSellLegendary = true
        end
        
        -- Специальная логика для мутаций: если у нас много петов с мутациями, можем продавать плохих
        local mutationPets = 0
        for _, petData in pairs(analysis.petsByMoneyPerSecond) do
            if hasProtectedMutations(petData.pet.Name) then
                mutationPets = mutationPets + 1
            end
        end
        
        -- Если у нас много петов с мутациями (больше 5), можем продавать плохих с мутациями
        if mutationPets > 5 then
            analysis.shouldSellEpic = true -- Разрешаем продавать Epic с мутациями
            if analysis.totalPets > 25 then
                analysis.shouldSellLegendary = true -- И Legendary тоже
            end
        end
    end
    
    return analysis
end

-- Определение, нужно ли продавать пета (умная система)
local function shouldSellPet(pet)
    local petName = pet.Name
    local weight = getPetWeight(petName)
    local rarity = getPetRarity(pet)
    local rarityValue = RARITY_ORDER[rarity] or 0
    local petInfo = getPetInfo(pet)
    
    -- Не продаем защищенного пета (который в руке для замены)
    if protectedPet and pet == protectedPet then
        return false
    end
    
    -- Не продаем защищенные предметы
    if isProtectedItem(petName) then
        return false
    end
    
    -- Не продаем тяжелых петов
    if weight >= CONFIG.MIN_WEIGHT_TO_KEEP then
        return false
    end
    
    -- Не продаем высоких редкостей (Mythic и выше)
    if rarityValue > RARITY_ORDER["Legendary"] then
        return false
    end
    
    -- Если умная система отключена, используем старую логику
    if not CONFIG.SMART_SELLING then
        -- Старая логика: не продаем Legendary с мутациями и брейнротов с высоким MoneyPerSecond
        if rarity == "Legendary" and hasProtectedMutations(petName) then
            return false
        end
        if petInfo.moneyPerSecond > 100 then
            return false
        end
        return true
    end
    
    -- Умная система: используем анализ петов
    if not petAnalysis then
        petAnalysis = analyzePets()
    end
    
    -- Проверяем по MoneyPerSecond
    if petInfo.moneyPerSecond >= petAnalysis.minMoneyPerSecondToKeep then
        return false
    end
    
    -- Проверяем по редкости (только если анализ говорит, что можно продавать эту редкость)
    if rarity == "Rare" and not petAnalysis.shouldSellRare then
        return false
    elseif rarity == "Epic" and not petAnalysis.shouldSellEpic then
        return false
    elseif rarity == "Legendary" and not petAnalysis.shouldSellLegendary then
        return false
    end
    
    -- В умной системе НЕ защищаем мутации автоматически - пусть анализ решает
    -- Только если это очень редкие мутации (Neon/Galactic), тогда защищаем
    if hasProtectedMutations(petName) and (rarity == "Mythic" or rarity == "Godly" or rarity == "Secret") then
        return false
    end
    
    return true
end

-- Продажа пета
local function sellPet(pet)
    local character = LocalPlayer.Character
    if not character then return false end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return false end
    
    -- Берем пета в руку перед продажей
    humanoid:EquipTool(pet)
    wait(0.1) -- Ждем пока пет возьмется в руку
    
    -- Продаем пета
    itemSellRemote:FireServer(pet)
    
    return true
end

-- Получение лучшего брейнрота из инвентаря
local function getBestBrainrotFromInventory()
    local backpack = LocalPlayer:WaitForChild("Backpack")
    local bestBrainrot = nil
    local bestMoneyPerSecond = 0
    
    for _, pet in pairs(backpack:GetChildren()) do
        if pet:IsA("Tool") and pet.Name:match("%[%d+%.?%d*%s*kg%]") then
            local petInfo = getPetInfo(pet)
            local moneyPerSecond = petInfo.moneyPerSecond
            
            -- Сравниваем по MoneyPerSecond
            if moneyPerSecond > bestMoneyPerSecond then
                bestMoneyPerSecond = moneyPerSecond
                bestBrainrot = {
                    tool = pet,
                    name = pet.Name,
                    rarity = petInfo.rarity,
                    size = petInfo.size,
                    worth = petInfo.worth,
                    moneyPerSecond = moneyPerSecond
                }
            end
        end
    end
    
    return bestBrainrot
end

-- Авто-продажа петов
local function autoSellPets()
    local success, error = pcall(function()
        local backpack = LocalPlayer:WaitForChild("Backpack")
        local soldCount = 0
        local keptCount = 0
        
        -- Обновляем анализ петов перед продажей
        petAnalysis = analyzePets()
        
        -- Показываем информацию об анализе
        if CONFIG.SMART_SELLING and petAnalysis.totalPets > 0 then
            -- Считаем петов с мутациями
            local mutationPets = 0
            for _, petData in pairs(petAnalysis.petsByMoneyPerSecond) do
                if hasProtectedMutations(petData.pet.Name) then
                    mutationPets = mutationPets + 1
                end
            end
            
            print("=== АНАЛИЗ ПЕТОВ ===")
            print("Всего петов: " .. petAnalysis.totalPets)
            print("Петов с мутациями: " .. mutationPets)
            print("Средний MoneyPerSecond: " .. math.floor(petAnalysis.averageMoneyPerSecond))
            print("Лучший MoneyPerSecond: " .. petAnalysis.bestMoneyPerSecond)
            print("Минимальный для сохранения: " .. math.floor(petAnalysis.minMoneyPerSecondToKeep))
            print("Продаем Rare: " .. (petAnalysis.shouldSellRare and "ДА" or "НЕТ"))
            print("Продаем Epic: " .. (petAnalysis.shouldSellEpic and "ДА" or "НЕТ"))
            print("Продаем Legendary: " .. (petAnalysis.shouldSellLegendary and "ДА" or "НЕТ"))
            print("==================")
        end
        
        -- Сначала находим лучшего брейнрота для замены и защищаем его
        local bestBrainrot = getBestBrainrotFromInventory()
        if bestBrainrot then
            protectedPet = bestBrainrot.tool
            print("Защищен от продажи: " .. bestBrainrot.name .. " (" .. bestBrainrot.moneyPerSecond .. "/s)")
        end
        
        for _, pet in pairs(backpack:GetChildren()) do
            if pet:IsA("Tool") and pet.Name:match("%[%d+%.?%d*%s*kg%]") then
                if shouldSellPet(pet) then
                    local petInfo = getPetInfo(pet)
                    local sellSuccess = sellPet(pet)
                    
                    if sellSuccess then
                        soldCount = soldCount + 1
                        
                        local reason = "Продано: " .. petInfo.rarity .. " (вес: " .. petInfo.weight .. "kg)"
                        if CONFIG.SMART_SELLING then
                            reason = reason .. " [MoneyPerSecond: " .. petInfo.moneyPerSecond .. "/s]"
                        end
                        
                        table.insert(logs, {
                            action = "SELL",
                            item = petInfo.name,
                            reason = reason,
                            timestamp = os.time()
                        })
                        
                        print("Продано: " .. petInfo.name .. " (" .. petInfo.rarity .. ", " .. petInfo.weight .. "kg, " .. petInfo.moneyPerSecond .. "/s)")
                    else
                        print("Не удалось продать: " .. petInfo.name)
                    end
                    
                    wait(CONFIG.SELL_DELAY)
                else
                    local petInfo = getPetInfo(pet)
                    local reason = "Сохранен: "
                    
                    -- Проверяем, является ли это полезным брейнротом
                    if petInfo.moneyPerSecond >= petAnalysis.minMoneyPerSecondToKeep then
                        reason = reason .. "высокий MoneyPerSecond (" .. petInfo.moneyPerSecond .. "/s)"
                    elseif petInfo.weight >= CONFIG.MIN_WEIGHT_TO_KEEP then
                        reason = reason .. "тяжелый (" .. petInfo.weight .. "kg)"
                    elseif RARITY_ORDER[petInfo.rarity] > RARITY_ORDER["Legendary"] then
                        reason = reason .. "высокая редкость (" .. petInfo.rarity .. ")"
                    elseif petInfo.rarity == "Legendary" and hasProtectedMutations(pet.Name) then
                        reason = reason .. "защищенные мутации"
                    else
                        reason = reason .. "защищенный предмет"
                    end
                    
                    table.insert(logs, {
                        action = "KEEP",
                        item = petInfo.name,
                        reason = reason,
                        timestamp = os.time()
                    })
                    
                    keptCount = keptCount + 1
                end
            end
        end
        
        -- Снимаем защиту после продажи
        protectedPet = nil
        
        if soldCount > 0 or keptCount > 0 then
            print("Продано петов: " .. soldCount .. ", сохранено: " .. keptCount)
        end
    end)
    
    if not success then
        print("Ошибка в autoSellPets: " .. tostring(error))
    end
end

-- Ввод кодов
local function redeemCodes()
    print("Ввод кодов...")
    for _, code in pairs(CODES) do
        local args = {{"code", "\031"}}
        dataRemoteEvent:FireServer(unpack(args))
        wait(0.1)
    end
    print("Коды введены!")
end

-- Автоматическое открытие яиц
local function autoOpenEggs()
    local success, error = pcall(function()
        local backpack = LocalPlayer:WaitForChild("Backpack")
        local openedCount = 0
        
        for _, item in pairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                for _, eggName in pairs(PROTECTED_ITEMS) do
                    if item.Name:find(eggName) then
                        local args = {eggName}
                        openEggRemote:FireServer(unpack(args))
                        
                        table.insert(logs, {
                            action = "OPEN_EGG",
                            item = eggName,
                            reason = "Автоматически открыто яйцо",
                            timestamp = os.time()
                        })
                        
                        print("Открыто яйцо: " .. eggName)
                        openedCount = openedCount + 1
                        wait(0.1)
                        break
                    end
                end
            end
        end
        
        if openedCount > 0 then
            print("Открыто яиц: " .. openedCount)
        end
    end)
    
    if not success then
        print("Ошибка в autoOpenEggs: " .. tostring(error))
    end
end

-- Проверка стока семян
local function checkSeedStock(seedName)
    local seedsGui = PlayerGui:FindFirstChild("Main")
    if not seedsGui then return false, 0 end
    
    local seedsFrame = seedsGui:FindFirstChild("Seeds")
    if not seedsFrame then return false, 0 end
    
    local scrollingFrame = seedsFrame:FindFirstChild("Frame"):FindFirstChild("ScrollingFrame")
    if not scrollingFrame then return false, 0 end
    
    local seedFrame = scrollingFrame:FindFirstChild(seedName)
    if not seedFrame then return false, 0 end
    
    local stockLabel = seedFrame:FindFirstChild("Stock")
    if not stockLabel then return false, 0 end
    
    local stockText = stockLabel.Text
    local stockCount = tonumber(stockText:match("x(%d+)")) or 0
    
    return stockCount > 0, stockCount
end

-- Авто-покупка семян
local function autoBuySeeds()
    local success, error = pcall(function()
        for _, seedName in pairs(SEEDS) do
            local hasStock, stockCount = checkSeedStock(seedName)
            if hasStock then
                local args = {{seedName, "\b"}}
                dataRemoteEvent:FireServer(unpack(args))
                
                table.insert(logs, {
                    action = "BUY_SEED",
                    item = seedName,
                    reason = "Куплено (в стоке: " .. stockCount .. ")",
                    timestamp = os.time()
                })
                
                print("Куплено семя: " .. seedName .. " (в стоке: " .. stockCount .. ")")
                wait(0.1)
            end
        end
    end)
    
    if not success then
        print("Ошибка в autoBuySeeds: " .. tostring(error))
    end
end

-- Проверка стока предметов
local function checkGearStock(gearName)
    local gearsGui = PlayerGui:FindFirstChild("Main")
    if not gearsGui then return false, 0 end
    
    local gearsFrame = gearsGui:FindFirstChild("Gears")
    if not gearsFrame then return false, 0 end
    
    local scrollingFrame = gearsFrame:FindFirstChild("Frame"):FindFirstChild("ScrollingFrame")
    if not scrollingFrame then return false, 0 end
    
    local gearFrame = scrollingFrame:FindFirstChild(gearName)
    if not gearFrame then return false, 0 end
    
    local stockLabel = gearFrame:FindFirstChild("Stock")
    if not stockLabel then return false, 0 end
    
    local stockText = stockLabel.Text
    local stockCount = tonumber(stockText:match("x(%d+)")) or 0
    
    return stockCount > 0, stockCount
end

-- Авто-покупка предметов
local function autoBuyGear()
    local success, error = pcall(function()
        for _, gearName in pairs(GEAR_ITEMS) do
            local hasStock, stockCount = checkGearStock(gearName)
            if hasStock then
                local args = {{gearName, "\026"}}
                dataRemoteEvent:FireServer(unpack(args))
                
                table.insert(logs, {
                    action = "BUY_GEAR",
                    item = gearName,
                    reason = "Куплено (в стоке: " .. stockCount .. ")",
                    timestamp = os.time()
                })
                
                print("Куплен предмет: " .. gearName .. " (в стоке: " .. stockCount .. ")")
                wait(0.1)
            end
        end
    end)
    
    if not success then
        print("Ошибка в autoBuyGear: " .. tostring(error))
    end
end

-- Получение текущего плота игрока
local function getCurrentPlot()
    local plotNumber = LocalPlayer:GetAttribute("Plot")
    if plotNumber then
        local plot = workspace.Plots:FindFirstChild(tostring(plotNumber))
        if plot then
            print("Найден плот: " .. plotNumber)
            return plot
        else
            print("Плот " .. plotNumber .. " не найден в workspace.Plots")
        end
    else
        print("Атрибут Plot не найден у игрока")
    end
    return nil
end

-- Получение баланса игрока
local function getPlayerBalance()
    if not playerData then
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "❌ playerData не инициализирован, пробуем альтернативный способ",
            timestamp = os.time()
        })
        
        -- Альтернативный способ получения баланса
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                local moneyValue = humanoid:FindFirstChild("Money")
                if moneyValue then
                    local balance = moneyValue.Value
                    table.insert(logs, {
                        action = "PLATFORM_DEBUG",
                        message = "💰 Баланс получен альтернативным способом: $" .. balance,
                        timestamp = os.time()
                    })
                    return balance
                end
            end
        end
        return 0
    end
    
    local success, balance = pcall(function()
        return playerData.get("Money") or 0
    end)
    
    if success then
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "💰 Баланс получен: $" .. balance,
            timestamp = os.time()
        })
        return balance
    else
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "❌ Ошибка получения баланса, пробуем альтернативный способ",
            timestamp = os.time()
        })
        
        -- Альтернативный способ получения баланса
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                local moneyValue = humanoid:FindFirstChild("Money")
                if moneyValue then
                    local balance = moneyValue.Value
                    table.insert(logs, {
                        action = "PLATFORM_DEBUG",
                        message = "💰 Баланс получен альтернативным способом: $" .. balance,
                        timestamp = os.time()
                    })
                    return balance
                end
            end
        end
        return 0
    end
end

-- Покупка платформы
local function buyPlatform(platformNumber)
    table.insert(logs, {
        action = "PLATFORM_DEBUG",
        message = "=== ПОПЫТКА ПОКУПКИ ПЛАТФОРМЫ " .. platformNumber .. " ===",
        timestamp = os.time()
    })
    
    local args = {
        {
            tostring(platformNumber),
            ","
        }
    }
    
    table.insert(logs, {
        action = "PLATFORM_DEBUG",
        message = "Отправляем запрос на покупку платформы " .. platformNumber,
        timestamp = os.time()
    })
    
    table.insert(logs, {
        action = "PLATFORM_DEBUG",
        message = "Аргументы запроса: " .. tostring(args[1][1]) .. ", " .. tostring(args[1][2]),
        timestamp = os.time()
    })
    
    local success, error = pcall(function()
        dataRemoteEvent:FireServer(unpack(args))
    end)
    
    if success then
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "✅ Запрос на покупку платформы " .. platformNumber .. " отправлен успешно",
            timestamp = os.time()
        })
        
        table.insert(logs, {
            action = "BUY_PLATFORM",
            item = "Platform " .. platformNumber,
            reason = "Куплена платформа",
            timestamp = os.time()
        })
    else
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "❌ ОШИБКА при покупке платформы " .. platformNumber .. ": " .. tostring(error),
            timestamp = os.time()
        })
    end
    
    table.insert(logs, {
        action = "PLATFORM_DEBUG",
        message = "=== ЗАВЕРШЕНИЕ ПОПЫТКИ ПОКУПКИ ПЛАТФОРМЫ " .. platformNumber .. " ===",
        timestamp = os.time()
    })
end

-- Тестовая функция для диагностики покупки платформ
local function testPlatformBuying()
    -- Простая проверка доступности платформ
    local plotNumber = LocalPlayer:GetAttribute("Plot")
    if plotNumber then
        local plot = workspace.Plots[tostring(plotNumber)]
        if plot and plot:FindFirstChild("Brainrots") then
            table.insert(logs, {
                action = "PLATFORM_DEBUG",
                message = "✅ Платформы доступны для покупки",
                timestamp = os.time()
            })
        end
    end
end

-- Авто-покупка платформ
local function autoBuyPlatforms()
    table.insert(logs, {
        action = "PLATFORM_DEBUG",
        message = "=== ФУНКЦИЯ autoBuyPlatforms() ВЫЗВАНА ===",
        timestamp = os.time()
    })
    
    
    local success, error = pcall(function()
        if not CONFIG.AUTO_BUY_PLATFORMS then
            table.insert(logs, {
                action = "PLATFORM_DEBUG",
                message = "Авто-покупка платформ отключена в конфигурации",
                timestamp = os.time()
            })
            return
        end
        
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "Авто-покупка платформ включена, начинаем проверку...",
            timestamp = os.time()
        })
        
        local currentPlot = getCurrentPlot()
        if not currentPlot then
            table.insert(logs, {
                action = "PLATFORM_DEBUG",
                message = "Не найден текущий плот для покупки платформ",
                timestamp = os.time()
            })
            return
        end
        
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "Найден плот: " .. tostring(currentPlot),
            timestamp = os.time()
        })
        
        local brainrots = currentPlot:FindFirstChild("Brainrots")
        if not brainrots then
            table.insert(logs, {
                action = "PLATFORM_DEBUG",
                message = "Не найден Brainrots на плоте для покупки платформ",
                timestamp = os.time()
            })
            return
        end
        
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "Найден Brainrots, проверяем платформы...",
            timestamp = os.time()
        })
        
        
        local playerBalance = getPlayerBalance()
        local boughtCount = 0
        local platformsChecked = 0
        
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "Проверяем платформы для покупки. Баланс: $" .. playerBalance,
            timestamp = os.time()
        })
        
        -- Проверяем dataRemoteEvent
        if dataRemoteEvent then
            table.insert(logs, {
                action = "PLATFORM_DEBUG",
                message = "dataRemoteEvent найден: " .. tostring(dataRemoteEvent),
                timestamp = os.time()
            })
        else
            table.insert(logs, {
                action = "PLATFORM_DEBUG",
                message = "ОШИБКА: dataRemoteEvent не найден!",
                timestamp = os.time()
            })
        end
        
        for _, platform in pairs(brainrots:GetChildren()) do
            if platform:IsA("Model") and platform.Name:match("^%d+$") then
                platformsChecked = platformsChecked + 1
                
                -- Проверяем PlatformPrice.Money вместо просто PlatformPrice
                local platformPrice = platform:GetAttribute("PlatformPrice")
                if platformPrice then
                    -- Проверяем, есть ли у PlatformPrice атрибут Money
                    local platformPriceMoney = platformPrice.Money
                    if platformPriceMoney then
                        -- Парсим цену из PlatformPrice.Money
                        local priceText = tostring(platformPriceMoney)
                        local priceValue = priceText:match("%$(%d+,?%d*%d*)")
                        if priceValue then
                            -- Убираем запятые и конвертируем в число
                            local cleanPrice = priceValue:gsub(",", "")
                            local price = tonumber(cleanPrice) or 0
                        
                            -- Всегда пытаемся купить платформу, независимо от баланса
                            table.insert(logs, {
                                action = "PLATFORM_DEBUG",
                                message = "Покупаем платформу " .. platform.Name .. " за $" .. price .. " (баланс: $" .. playerBalance .. ")",
                                timestamp = os.time()
                            })
                            buyPlatform(platform.Name)
                            boughtCount = boughtCount + 1
                            wait(0.5) -- Небольшая пауза между покупками
                        end
                    end
                end
            end
        end
        
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "Проверено платформ: " .. platformsChecked .. ", куплено: " .. boughtCount,
            timestamp = os.time()
        })
        
        if boughtCount > 0 then
            table.insert(logs, {
                action = "PLATFORM_DEBUG",
                message = "Куплено платформ: " .. boughtCount,
                timestamp = os.time()
            })
        else
            table.insert(logs, {
                action = "PLATFORM_DEBUG",
                message = "Нет платформ для покупки",
                timestamp = os.time()
            })
        end
    end)
    
    if not success then
        table.insert(logs, {
            action = "PLATFORM_DEBUG",
            message = "Ошибка в autoBuyPlatforms: " .. tostring(error),
            timestamp = os.time()
        })
    end
    
    table.insert(logs, {
        action = "PLATFORM_DEBUG",
        message = "=== ФУНКЦИЯ autoBuyPlatforms() ЗАВЕРШЕНА ===",
        timestamp = os.time()
    })
end

-- Проверка доступности платформы (видна ли она в игре)
local function isPlatformAvailable(platform)
    -- Проверяем, есть ли у платформы PlatformPrice.Money - если есть, то подиум недоступен
    local platformPrice = platform:GetAttribute("PlatformPrice")
    if platformPrice then
        -- Проверяем, есть ли у PlatformPrice атрибут Money
        local platformPriceMoney = platformPrice.Money
        if platformPriceMoney then
            return false -- Подиум недоступен, так как есть цена для покупки
        end
    end
    
    -- Проверяем, есть ли у платформы видимые части
    local hasVisibleParts = false
    
    -- Проверяем все дочерние объекты платформы
    for _, child in pairs(platform:GetChildren()) do
        if child:IsA("BasePart") then
            -- Проверяем, видна ли часть (не прозрачная)
            -- Не проверяем Visible, так как не все BasePart имеют это свойство
            if child.Transparency < 1 then
                hasVisibleParts = true
                break
            end
        elseif child:IsA("Model") then
            -- Проверяем дочерние модели
            for _, subChild in pairs(child:GetChildren()) do
                if subChild:IsA("BasePart") and subChild.Transparency < 1 then
                    hasVisibleParts = true
                    break
                end
            end
            if hasVisibleParts then break end
        end
    end
    
    return hasVisibleParts
end

-- Установка PrimaryPart для платформы если его нет
local function ensurePlatformPrimaryPart(platform)
    if platform.PrimaryPart then
        return true
    end
    
    -- Ищем подходящую часть для PrimaryPart
    local candidates = {}
    
    -- Ищем Hitbox как основной кандидат
    local hitbox = platform:FindFirstChild("Hitbox")
    if hitbox and hitbox:IsA("BasePart") then
        table.insert(candidates, hitbox)
    end
    
    -- Ищем любые BasePart в платформе
    for _, child in pairs(platform:GetChildren()) do
        if child:IsA("BasePart") and child.Name ~= "Hitbox" then
            table.insert(candidates, child)
        end
    end
    
    -- Устанавливаем первый найденный BasePart как PrimaryPart
    if #candidates > 0 then
        platform.PrimaryPart = candidates[1]
        print("Установлен PrimaryPart для платформы " .. platform.Name .. " (" .. candidates[1].Name .. ")")
        return true
    end
    
    return false
end

-- Авто-сбор монет с платформ
local function autoCollectCoins()
    local success, error = pcall(function()
        local currentPlot = getCurrentPlot()
        if not currentPlot then
            print("Не найден текущий плот для сбора монет")
            return
        end
        
        local brainrots = currentPlot:FindFirstChild("Brainrots")
        if not brainrots then
            print("Не найден Brainrots на плоте")
            return
        end
        
        local collectedCount = 0
        local character = LocalPlayer.Character
        if not character then
            print("Персонаж не найден для сбора монет")
            return
        end
        
        -- Сохраняем текущую позицию персонажа
        local originalPosition = character:GetPrimaryPartCFrame()
        
        print("Найдено платформ: " .. #brainrots:GetChildren())
        if CONFIG.DEBUG_COLLECT_COINS then
            print("Список всех платформ:")
            for _, platform in pairs(brainrots:GetChildren()) do
                print("  - " .. platform.Name .. " (тип: " .. platform.ClassName .. ")")
            end
        end
        
        for _, platform in pairs(brainrots:GetChildren()) do
            if platform:IsA("Model") and platform.Name:match("^%d+$") then -- Только платформы с числовыми именами
                -- Проверяем доступность платформы (видна ли она)
                if isPlatformAvailable(platform) then
                    if CONFIG.DEBUG_COLLECT_COINS then
                        print("Обрабатываем доступную платформу: " .. platform.Name)
                    end
                    
                    -- Устанавливаем PrimaryPart если его нет
                    if not ensurePlatformPrimaryPart(platform) then
                        if CONFIG.DEBUG_COLLECT_COINS then
                            print("У платформы " .. platform.Name .. " нет подходящих частей для PrimaryPart")
                        end
                    else
                    
                    -- Просто телепортируемся к платформе для сбора монет
                    local platformPosition = platform.PrimaryPart.Position
                    character:SetPrimaryPartCFrame(CFrame.new(platformPosition + Vector3.new(0, 3, 0)))
                    wait(0.2)
                    
                    collectedCount = collectedCount + 1
                    if CONFIG.DEBUG_COLLECT_COINS then
                        print("Телепортировались к платформе " .. platform.Name .. " для сбора монет")
                    end
                    
                    wait(0.1)
                    end
                elseif CONFIG.DEBUG_COLLECT_COINS then
                    local platformPrice = platform:GetAttribute("PlatformPrice")
                    if platformPrice then
                        print("Пропускаем недоступную платформу: " .. platform.Name .. " (есть PlatformPrice: " .. platformPrice .. ")")
                    else
                        print("Пропускаем недоступную платформу: " .. platform.Name .. " (не видна в игре)")
                    end
                end
            elseif CONFIG.DEBUG_COLLECT_COINS then
                print("Пропускаем объект: " .. platform.Name .. " (тип: " .. platform.ClassName .. ")")
            end
        end
        
        -- Возвращаемся на исходную позицию
        character:SetPrimaryPartCFrame(originalPosition)
        
        if collectedCount > 0 then
            table.insert(logs, {
                action = "COLLECT_COINS",
                item = "Платформы",
                reason = "Телепортировались к " .. collectedCount .. " платформам для сбора монет",
                timestamp = os.time()
            })
            print("Телепортировались к " .. collectedCount .. " платформам для сбора монет")
        else
            print("Нет доступных платформ для сбора монет")
        end
    end)
    
    if not success then
        print("Ошибка в autoCollectCoins: " .. tostring(error))
    end
end

-- Получение информации о брейнроте на платформе
local function getPlatformBrainrotInfo(platform)
    local brainrot = platform:FindFirstChild("Brainrot")
    if not brainrot then return nil end
    
    local name = brainrot:GetAttribute("Name") or brainrot.Name
    local rarity = brainrot:GetAttribute("Rarity") or "Rare"
    local size = brainrot:GetAttribute("Size") or 1
    local moneyPerSecond = platform:GetAttribute("MoneyPerSecond") or 0
    
    return {
        name = name,
        rarity = rarity,
        size = size,
        moneyPerSecond = moneyPerSecond,
        model = brainrot
    }
end

-- Замена брейнрота на платформе
local function replaceBrainrotOnPlatform(platform, newBrainrot)
    local character = LocalPlayer.Character
    if not character then 
        print("Персонаж не найден")
        protectedPet = nil -- Снимаем защиту при ошибке
        return false 
    end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then 
        print("Humanoid не найден")
        protectedPet = nil -- Снимаем защиту при ошибке
        return false 
    end
    
    -- Пытаемся установить PrimaryPart если его нет
    if not en... (60 KB left)
