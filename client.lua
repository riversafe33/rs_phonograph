local volume = 0.3
local Menu = exports.vorp_menu:GetMenuData()

local function OpenSongListMenu(labelName, songs, uniqueId)
    Menu.CloseAll()

    local elements = {}

    if songs then
        for _, song in pairs(songs) do
            table.insert(elements, {
                label = song.label,
                value = song.url,
                desc = song.description or "",
            })
        end
    end

    table.insert(elements, {
        label = Config.Menu.Close,
        value = "cancel",
        desc = Config.Menu.Descsub,
    })

    Menu.Open("default", GetCurrentResourceName(), "song_list_menu", {
        title = labelName,
        subtext = Config.Menu.Select,
        align = "top-right",
        elements = elements,
    }, function(data, menu)
        local selectedUrl = data.current.value

        if selectedUrl == "cancel" then
            menu.close()
            return
        end

        TriggerServerEvent('rs_phonograph:server:playMusic', uniqueId, GetEntityCoords(PlayerPedId()), selectedUrl, volume)
        TriggerEvent("vorp:NotifyLeft", Config.Notify.Phono, Config.Notify.PlaySelect, "generic_textures", "tick", 1500, "COLOR_GREEN")
        menu.close()
    end, function(data, menu)
        menu.close()
    end)
end

local function OpenPhonographMenu(entity, uniqueId)
    Menu.CloseAll()

    local function BuildElements()
        local elements = {}

        if Config.AllowCustomSongs then
            table.insert(elements, {
                label = Config.Menu.Play,
                value = "play",
                desc = Config.Menu.DesPlay,
            })
        end

        if Config.AllowListSongs then
            table.insert(elements, {
                label = Config.Menu.SongList,
                value = "choose_song",
                desc = Config.Menu.DesSongList,
            })
        end

        table.insert(elements, {
            label = Config.Menu.Stop,
            value = "stop",
            desc = Config.Menu.DesStop,
        })

        table.insert(elements, {
            label = Config.Menu.VolumeUp,
            value = "volume_up",
        })

        table.insert(elements, {
            label = Config.Menu.VolumeDown,
            value = "volume_down",
        })

        return elements
    end

    local elements = BuildElements()

    Menu.Open('default', GetCurrentResourceName(), 'phonograph_menu', {
        title = Config.Menu.Title,
        subtext = Config.Menu.SubTx,
        align = 'top-right',
        elements = elements,
    },
    function(data, menu)
        local id = uniqueId

        if data.current.value == "play" then
            if not Config.AllowCustomSongs then
                TriggerEvent("vorp:NotifyLeft", Config.Notify.Phono, Config.Notify.Custom, "menu_textures", "cross", 500, "COLOR_RED")
                return
            end

            local myInput = {
                type = "enableinput",
                inputType = "input",
                button = Config.Menu.Button,
                placeholder = Config.Menu.PlaceHolder,
                style = "block",
                attributes = {
                    inputHeader = Config.Menu.InputHeader,
                    type = "text",
                    pattern = ".*",
                    title = Config.Menu.Titles,
                    style = "border-radius: 10px; background-color: ; border:none;"
                }
            }

            local result = exports.vorp_inputs:advancedInput(myInput)

            if result and result:sub(1, 4) == "http" then
                TriggerServerEvent('rs_phonograph:server:playMusic', uniqueId, GetEntityCoords(entity), result, volume)
                TriggerEvent("vorp:NotifyLeft", Config.Notify.Phono, Config.Notify.PlayMessage, "generic_textures", "tick", 1500, "COLOR_GREEN")
            else
                TriggerEvent("vorp:NotifyLeft", Config.Notify.Phono, Config.Notify.InvalidUrlMessage, "menu_textures", "cross", 500, "COLOR_RED")
            end

        elseif data.current.value == "choose_song" then
            menu.close()
            OpenSongListMenu(Config.Menu.SongList, Config.SongList, uniqueId)

        elseif data.current.value == "stop" then
            TriggerServerEvent('rs_phonograph:server:stopMusic', uniqueId)
            TriggerEvent("vorp:NotifyLeft", Config.Notify.Phono, Config.Notify.StopMessage, "menu_textures", "cross", 500, "COLOR_RED")

        elseif data.current.value == "volume_up" then
            if volume < 1.0 then
                volume = math.min(volume + 0.05, 1.0)
                TriggerEvent('rs_phonograph:client:setVolume', uniqueId, volume)
                TriggerEvent("vorp:NotifyLeft", Config.Notify.Phono, Config.Notify.VolumeUpMessage:format(math.floor(volume * 100)), "generic_textures", "tick", 100, "COLOR_GREEN")
            else
                TriggerEvent("vorp:NotifyLeft", Config.Notify.Phono, Config.Notify.MaxVolumeMessage, "menu_textures", "cross", 500, "COLOR_RED")
            end

        elseif data.current.value == "volume_down" then
            if volume > 0.0 then
                volume = math.max(volume - 0.05, 0.0)
                TriggerEvent('rs_phonograph:client:setVolume', uniqueId, volume)
                TriggerEvent("vorp:NotifyLeft", Config.Notify.Phono, Config.Notify.VolumeDownMessage:format(math.floor(volume * 100)), "generic_textures", "tick", 100, "COLOR_GREEN")
            else
                TriggerEvent("vorp:NotifyLeft", Config.Notify.Phono, Config.Notify.MinVolumeMessage, "menu_textures", "cross", 500, "COLOR_RED")
            end
        end
    end,
    function(data, menu)
        menu.close()
    end)
end

local phonographEntities = {}
local closestEntity = nil
local closestId = nil
local lastPlacedPhonograph = nil

local promptGroup = UipromptGroup:new(Config.Promp.Controls)

local playMusicPrompt = Uiprompt:new(`INPUT_DYNAMIC_SCENARIO`, Config.Promp.Play, promptGroup)
playMusicPrompt:setHoldMode(true)

local pickUpPrompt = Uiprompt:new(`INPUT_RELOAD`, Config.Promp.Collect, promptGroup)
pickUpPrompt:setHoldMode(true)

local function updatePrompts()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    closestEntity, closestId = nil, nil
    local closestDistance = 1.5

    for uniqueId, entity in pairs(phonographEntities or {}) do
        if DoesEntityExist(entity) then
            local entityCoords = GetEntityCoords(entity)
            local distance = #(playerCoords - entityCoords)
            if distance <= closestDistance then
                closestDistance = distance
                closestEntity = entity
                closestId = uniqueId
            end
        end
    end

    local found = (closestEntity ~= nil)
    promptGroup:setActive(found)
    playMusicPrompt:setVisible(found)
    playMusicPrompt:setEnabled(found)
    pickUpPrompt:setVisible(found)
    pickUpPrompt:setEnabled(found)
end

CreateThread(function()
    while true do
        Wait(500)
        updatePrompts()
    end
end)

RegisterNetEvent('rs_phonograph:client:spawnPhonograph')
AddEventHandler('rs_phonograph:client:spawnPhonograph', function(data)
    local propModel = `p_phonograph01x`
    local x, y, z = data.x, data.y, data.z
    local rotZ = tonumber(data.rotation.z or 0.0) % 360.0
    local uniqueId = data.id

    if phonographEntities[uniqueId] and DoesEntityExist(phonographEntities[uniqueId]) then
        return
    end

    RequestModel(propModel)
    while not HasModelLoaded(propModel) do Wait(10) end

    local object = CreateObject(propModel, x, y, z, false, false, false)
    SetEntityHeading(object, rotZ)
    FreezeEntityPosition(object, true)
    SetEntityAsMissionEntity(object, true)

    phonographEntities[uniqueId] = object
end)

Citizen.CreateThread(function()
    TriggerServerEvent('rs_phonograph:server:requestPhonographs')
end)

RegisterNetEvent('rs_phonograph:client:receivePhonographs')
AddEventHandler('rs_phonograph:client:receivePhonographs', function(phonographs)
    if phonographs then
        for _, data in pairs(phonographs) do
            TriggerEvent('rs_phonograph:client:spawnPhonograph', data)
        end
    end
end)

promptGroup:setOnHoldModeJustCompleted(function(group, prompt)
    if closestEntity and DoesEntityExist(closestEntity) then
        if prompt == playMusicPrompt then
            if closestId then
                OpenPhonographMenu(closestEntity, closestId)
            else
                TriggerEvent("vorp:NotifyLeft", Config.Notify.Phono, Config.Notify.UnregisteredMessage, "generic_textures", "tick", 3000, "COLOR_GREEN")
            end
        elseif prompt == pickUpPrompt then
            if closestId then
                TriggerServerEvent('rs_phonograph:server:pickUpByOwner', closestId)
            else
                TriggerEvent("vorp:NotifyLeft", Config.Notify.Phono, Config.Notify.UnregisteredMessage, "generic_textures", "tick", 3000, "COLOR_GREEN")
            end
        end
    else
        TriggerEvent("vorp:NotifyLeft", Config.Notify.Phono, Config.Notify.NoPhonographMessage, "menu_textures", "cross", 3000, "COLOR_RED")
    end
end)

UipromptManager:startEventThread()

RegisterNetEvent('rs_phonograph:client:placePropPhonograph')
AddEventHandler('rs_phonograph:client:placePropPhonograph', function()
    local phonographModel = GetHashKey('p_phonograph01x')
    RequestModel(phonographModel)
    while not HasModelLoaded(phonographModel) do Wait(10) end

    local playerPed = PlayerPedId()
    local px, py, pz = table.unpack(GetEntityCoords(playerPed, true))
    local ox, oy, oz = table.unpack(GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 2.5, 0.0))

    local groundSuccess, groundZ = GetGroundZFor_3dCoord(ox, oy, pz, false)
    if groundSuccess then pz = groundZ end

    local tempObject = CreateObject(phonographModel, ox, oy, pz, true, false, false)
    PlaceObjectOnGroundProperly(tempObject)

    local posX, posY, posZ = table.unpack(GetEntityCoords(tempObject))
    local heading = GetEntityHeading(tempObject)

    local moveStep = 0.05
    local isPlacing = true

    FreezeEntityPosition(tempObject, true)
    SetEntityCollision(tempObject, false, false)
    SetEntityAlpha(tempObject, 150, false)
    SendNUIMessage({ action = "show" })

    lastPlacedPhonograph = {
        entity = tempObject,
        coords = vector3(posX, posY, posZ),
        rotation = vector3(0.0, 0.0, heading)
    }

    CreateThread(function()
        while isPlacing do
            Wait(0)
            local moved = false

            if IsControlPressed(0, 0x6319DB71) then posY = posY + moveStep; moved = true end
            if IsControlPressed(0, 0x05CA7C52) then posY = posY - moveStep; moved = true end
            if IsControlPressed(0, 0xA65EBAB4) then posX = posX - moveStep; moved = true end
            if IsControlPressed(0, 0xDEB34313) then posX = posX + moveStep; moved = true end
            if IsControlPressed(0, 0xB03A913B) then posZ = posZ + moveStep; moved = true end
            if IsControlPressed(0, 0x42385422) then posZ = posZ - moveStep; moved = true end
            if IsControlPressed(0, 0xE6F612E4) then heading = heading + 5; moved = true end
            if IsControlPressed(0, 0x1CE6D9EB) then heading = heading - 5; moved = true end

            if IsControlJustPressed(0, 0x4F49CC4C) then
                local myInput = {
                    type = "enableinput",
                    inputType = "input",
                    button = Config.Menu.Confirm,
                    placeholder = Config.Menu.MinMax,
                    style = "block",
                    attributes = {
                        inputHeader = Config.Menu.Speed,
                        type = "text",
                        pattern = "[0-9.]+",
                        title = Config.Menu.Change,
                        style = "border-radius: 10px; background-color: ; border:none;"
                    }
                }

                local result = exports.vorp_inputs:advancedInput(myInput)
                if result and result ~= "" then
                    local testint = tonumber(result)
                    if testint and testint ~= 0 then
                        moveStep = math.max(0.01, math.min(testint, 5))
                    end
                end
            end

            if moved then
                SetEntityCoords(tempObject, posX, posY, posZ, true, true, true, false)
                SetEntityHeading(tempObject, heading)
            end

            if IsControlJustPressed(0, 0xC7B5340A) then

                isPlacing = false
                SendNUIMessage({ action = "hide" })

                local pos = GetEntityCoords(tempObject)
                local rot = vector3(0.0, 0.0, GetEntityHeading(tempObject))

                DeleteObject(tempObject)
                lastPlacedPhonograph = nil

                Wait(1000)

                TriggerServerEvent('rs_phonograph:server:saveOwner', pos, rot)
                TriggerServerEvent("rs_phonograph:givePhonograph")

                updatePrompts()
                TriggerEvent("vorp:NotifyLeft", Config.Notify.Phono, Config.Notify.Place, "generic_textures", "tick", 2000, "COLOR_GREEN")
            end

            if IsControlJustPressed(0, 0x760A9C6F) then
                isPlacing = false
                SendNUIMessage({ action = "hide" })

                if DoesEntityExist(tempObject) then
                    DeleteObject(tempObject)
                end

                lastPlacedPhonograph = nil

                TriggerEvent("vorp:NotifyLeft", Config.Notify.Phono, Config.Notify.Cancel, "menu_textures", "cross", 2000, "COLOR_RED")
            end  
        end
    end)
end)

RegisterNetEvent('rs_phonograph:client:removePhonograph')
AddEventHandler('rs_phonograph:client:removePhonograph', function(uniqueId)
    local entity = phonographEntities[uniqueId]
    if entity and DoesEntityExist(entity) then
        DeleteObject(entity)
    end
    phonographEntities[uniqueId] = nil
end)

local function getSoundName(uniqueId)
    return tostring(uniqueId)
end

RegisterNetEvent('rs_phonograph:client:playMusic')
AddEventHandler('rs_phonograph:client:playMusic', function(uniqueId, coords, url, volume)
    local soundName = getSoundName(uniqueId)
    local effectSoundName = soundName .. "_effect"

    if exports.xsound:soundExists(soundName) then
        exports.xsound:Destroy(soundName)
    end
    if Config.WithEffect and exports.xsound:soundExists(effectSoundName) then
        exports.xsound:Destroy(effectSoundName)
    end

    exports.xsound:PlayUrlPos(soundName, url, volume, coords)
    exports.xsound:Distance(soundName, Config.SoundDistance)

    if Config.WithEffect then
        local effectVolume = volume * Config.VolumeEffect
        exports.xsound:PlayUrlPos(effectSoundName, "https://www.youtube.com/watch?v=m5Mz9Tqs9CE", effectVolume, coords)
        exports.xsound:Distance(effectSoundName, Config.SoundDistance)
    end

    if exports.xsound.onPlayEnd then
        exports.xsound:onPlayEnd(soundName, function()
            if Config.WithEffect and exports.xsound:soundExists(effectSoundName) then
                exports.xsound:Destroy(effectSoundName)
            end
            TriggerServerEvent('rs_phonograph:server:soundEnded', uniqueId)
        end)
    end
end)

RegisterNetEvent('rs_phonograph:client:setVolume')
AddEventHandler('rs_phonograph:client:setVolume', function(uniqueId, newVolume)
    local soundName = getSoundName(uniqueId)
    local effectSoundName = soundName .. "_effect"

    if exports.xsound:soundExists(soundName) then
        exports.xsound:setVolume(soundName, newVolume)
    end

    if Config.WithEffect and exports.xsound:soundExists(effectSoundName) then
        exports.xsound:setVolume(effectSoundName, newVolume * Config.VolumeEffect)
    end
end)

RegisterNetEvent('rs_phonograph:client:stopMusic')
AddEventHandler('rs_phonograph:client:stopMusic', function(uniqueId)
    local soundName = getSoundName(uniqueId)
    local effectSoundName = soundName .. "_effect"

    if exports.xsound:soundExists(soundName) then
        exports.xsound:Destroy(soundName)
    end
    if Config.WithEffect and exports.xsound:soundExists(effectSoundName) then
        exports.xsound:Destroy(effectSoundName)
    end

    TriggerServerEvent('rs_phonograph:server:soundEnded', uniqueId)
end)
