
--/////////////////////////////////////--
local modName =  "Enhanced Manual Flashlight"

local modAuthor = "SilverEzredes"
local modUpdated = "09/23/2024"
local modVersion = "v1.0.57"
local modCredits = "praydog; alphaZomega; Keelhauled"

--/////////////////////////////////////--
local hk = require("Hotkeys/Hotkeys")
local func = require("_SharedCore/Functions")
local ui = require("_SharedCore/Imgui")
local changed = false
local wc = false
local hue = 0
local playerContext = nil
local isPlayerInScene = false
local isDynaLightUsed = false
local isVitalGUIDrawn = false
local lightSwitchZoneManager = sdk.get_managed_singleton("chainsaw.LightSwitchZoneManager")

local flashlight_default_settings = {
	flashlight_Power = false,
    flashlight_Battery = true,
    flashlight_Flicker = true,
    flashlight_Dimming = true,
    flashlight_BatteryLevel = 100.0,
    flashlight_BatteryDrainRate = 0.0025,
    flashlight_BatteryRechargeRate = 0.003,
    flashlight_Flicker_Threshold = 10.0,
    flashlight_Dimming_Threshold = 20.0,
    lightRadius = 1.0,
    lightDirection = Vector3f.new(0.0, 0.0, -1.0),
    lightUseFalloff = true,
    lightUseResourceCone = false,
    lightCone = 80.0,
    lightSpread = 60.0,
    lightFalloff = 1.0,
	lightRange = 20.0,
    lightIlluminanceThreshold = 5.7,
    lightShadowEnable = true,
    lightRTShadowEnable = false,
	lightIntensity = 2500.0,
    lightIntensityTemp = 2500.0,
    lightColor = {
        R = 255,
        G = 243,
        B = 217,
    },
    lightTemperature = 5500.0,
    lightBounceIntensity = 1.0,
    lightSpecScale = 1.0,
    lightMinRoughness = 0.180,
    lightAOEfficiency = 0.0,
    isRGB = false,
    deltaTimeRGB = 0.016,
    isBatteryGUI = true,
    isAlwaysBatteryGUI = false,
    isDynamicBatteryGUI = true,
    batteryGUIThreshold = 100.0,
    batteryGUIPos = {
        x = 169,
        y = 156,
        z = 7,
        w = 100.0,
    },
    batteryGUIBackgroundColor = {120, 120, 120, 200},
    batteryGUIForegroundColor = {125, 125, 125, 255},
    batteryGUIForegroundColor100 = {45, 255, 0, 255},
    batteryGUIForegroundColor75 = {255, 255, 0, 255},
    batteryGUIForegroundColor50 = {255, 155, 0, 255},
    batteryGUIForegroundColor25 = {255, 0, 0, 255},
    -------------------------
    input_mode_idx =  1,
    option_mode_idx = 1,
    use_modifier = false,
    use_pad_modifier = true,
    hotkeys = {
        ["Flashlight Modifier"] = "R Mouse",
        ["Flashlight Switch"] = "Z",
        ["Pad Flashlight Modifier"] = "LT (L2)",
        ["Pad Flashlight Switch"] = "LStickPush",
    },
}
local flashlight_settings = hk.merge_tables({}, flashlight_default_settings) and hk.recurse_def_settings(json.load_file("SILVER/Flashlight_Settings.json") or {}, flashlight_default_settings)
hk.setup_hotkeys(flashlight_settings.hotkeys)

local function get_playerContext()
    local character_manager
    character_manager = sdk.get_managed_singleton(sdk.game_namespace("CharacterManager"))
    playerContext = character_manager and character_manager:call("getPlayerContextRef")
    return playerContext
end

local function HSV_ToRGB(h, s, v)
    local r, g, b

    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)

    i = i % 6

    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end

    return math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)
end

local function set_flashlightState()
    get_playerContext()
    if playerContext ~= nil then
        isPlayerInScene = true
        local playerID = playerContext:get_field("<KindID>k__BackingField")
        if (playerID == 100000) or (playerID == 380000) then
            local playerBody = playerContext and playerContext:get_BodyGameObject()

            if playerBody then
                local playerFlashLight = playerBody:get_Transform():find("FlashLight"):get_GameObject()
                if playerFlashLight then
                    local playerFlashLight_Comp = func.get_GameObjectComponent(playerFlashLight, "chainsaw.Flashlight")

                    if flashlight_settings.flashlight_Battery then
                        if flashlight_settings.flashlight_Power then
                            if flashlight_settings.flashlight_BatteryLevel > 0.0 then
                                flashlight_settings.flashlight_BatteryLevel = flashlight_settings.flashlight_BatteryLevel - flashlight_settings.flashlight_BatteryDrainRate
                            else
                                flashlight_settings.flashlight_Power = false
                            end
                        end
                    
                        if not flashlight_settings.flashlight_Power and flashlight_settings.flashlight_BatteryLevel < 100.0 then
                            flashlight_settings.flashlight_BatteryLevel = flashlight_settings.flashlight_BatteryLevel + flashlight_settings.flashlight_BatteryRechargeRate
                        end
                        
                        if flashlight_settings.flashlight_BatteryLevel ~= 100.0 then
                            local floatTolerance = 0.01
                            if math.abs(flashlight_settings.flashlight_BatteryLevel % 10) < floatTolerance then
                                json.dump_file("SILVER/Flashlight_Settings.json", flashlight_settings)
                            end
                        end

                        local finalIntensity = flashlight_settings.lightIntensity

                        if flashlight_settings.flashlight_Dimming and (flashlight_settings.flashlight_Power and flashlight_settings.flashlight_BatteryLevel < flashlight_settings.flashlight_Dimming_Threshold) then
                            local batteryDeficit = flashlight_settings.flashlight_Dimming_Threshold - flashlight_settings.flashlight_BatteryLevel
                            finalIntensity = finalIntensity * (1 - (batteryDeficit * 0.045))
                        end

                        if flashlight_settings.flashlight_Flicker and (flashlight_settings.flashlight_Power and flashlight_settings.flashlight_BatteryLevel < flashlight_settings.flashlight_Flicker_Threshold) then
                            local flashlightFlicker_Delay = math.random(25, 5000)
                            local flashlightFlicker_DelaySeconds = math.random(5, 2500)
                            
                            if ((flashlightFlicker_DelaySeconds) >= flashlightFlicker_Delay) then
                                local flashlightFlicker = math.random(250.0, 3000.0) / 2
                                finalIntensity = flashlightFlicker
                            end
                        end

                        flashlight_settings.lightIntensityTemp = finalIntensity
                    end

                    if flashlight_settings.isRGB then
                        hue = (hue + flashlight_settings.deltaTimeRGB * 0.1) % 1
                        flashlight_settings.lightColor.R, flashlight_settings.lightColor.G, flashlight_settings.lightColor.B = HSV_ToRGB(hue, 1, 1)
                    end

                    if lightSwitchZoneManager and playerFlashLight_Comp then
                        if flashlight_settings.flashlight_Power then
                            local refLight = playerFlashLight_Comp._RefLight
                            local count = lightSwitchZoneManager.lightSwitchedOn._entries
                            playerFlashLight_Comp.ExpectedOverlapNumber = 0
                            playerFlashLight_Comp:set_ActiveLightType(0)
                            playerFlashLight_Comp._Active = true
                            
                            
                            if count ~= nil then
                                for i in pairs(count) do
                                    local entry = lightSwitchZoneManager.lightSwitchedOn._entries[i]
                                    if entry and entry.value ~= nil then
                                        entry.value:Invoke()
                                    end
                                end
                            end

                            if refLight then
                                refLight:set_Radius(flashlight_settings.lightRadius)
                                refLight:set_Direction(flashlight_settings.lightDirection)
                                refLight:set_UseFalloff(flashlight_settings.lightUseFalloff)
                                refLight:set_UseResourceCone(flashlight_settings.lightUseResourceCone)
                                refLight:set_Cone(flashlight_settings.lightCone)
                                refLight:set_Spread(flashlight_settings.lightSpread)
                                refLight:set_Falloff(flashlight_settings.lightFalloff)
                                refLight:set_ReferenceEffectiveRange(flashlight_settings.lightRange)
                                refLight:set_IlluminanceThreshold(flashlight_settings.lightIlluminanceThreshold)
                                refLight:set_ShadowEnable(flashlight_settings.lightShadowEnable)
                                refLight:set_RayTracingShadowEnable(flashlight_settings.lightRTShadowEnable)
                                refLight:set_Intensity(flashlight_settings.lightIntensity)
                                refLight:set_Intensity(flashlight_settings.lightIntensityTemp)
                                refLight:set_Color(func.convert_rgb_to_vector3f(flashlight_settings.lightColor.R, flashlight_settings.lightColor.G, flashlight_settings.lightColor.B))
                                refLight:set_Temperature(flashlight_settings.lightTemperature)
                                refLight:set_BounceIntensity(flashlight_settings.lightBounceIntensity)
                                refLight:set_MinRoughness(flashlight_settings.lightMinRoughness)
                                refLight:set_SpecularScale(flashlight_settings.lightSpecScale)
                                refLight:set_AOEfficiency(flashlight_settings.lightAOEfficiency)
                            end
                        elseif not flashlight_settings.flashlight_Power then
                            local count = lightSwitchZoneManager.lightSwitchedOff._entries
                            if count ~= nil then
                                for i in pairs(count) do
                                    local entry = lightSwitchZoneManager.lightSwitchedOff._entries[i]
                                    if entry and entry.value ~= nil then
                                        entry.value:Invoke()
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function update_flashlightState()
    local KM_controls = ((not flashlight_settings.use_modifier or hk.check_hotkey("Flashlight Modifier", false)) and hk.check_hotkey("Flashlight Switch")) or (hk.check_hotkey("Flashlight Modifier", true) and hk.check_hotkey("Flashlight Switch"))
    local PAD_controls = ((not flashlight_settings.use_pad_modifier or hk.check_hotkey("Pad Flashlight Modifier", false)) and hk.check_hotkey("Pad Flashlight Switch")) or (hk.check_hotkey("Pad Flashlight Modifier", true) and hk.check_hotkey("Pad Flashlight Switch"))

    if KM_controls or PAD_controls then
        flashlight_settings.flashlight_Power = not flashlight_settings.flashlight_Power
        set_flashlightState()
    end
end

local function update_DynamicBatteryUI()
    if flashlight_settings.isDynamicBatteryGUI then
        isDynaLightUsed = true
        if flashlight_settings.flashlight_BatteryLevel > 75.0 then
            flashlight_settings.batteryGUIForegroundColor = flashlight_settings.batteryGUIForegroundColor100
        end
        if flashlight_settings.flashlight_BatteryLevel < 75.0 then
            flashlight_settings.batteryGUIForegroundColor = flashlight_settings.batteryGUIForegroundColor75
        end
        if flashlight_settings.flashlight_BatteryLevel < 50.0 then
            flashlight_settings.batteryGUIForegroundColor = flashlight_settings.batteryGUIForegroundColor50
        end
        if flashlight_settings.flashlight_BatteryLevel < 25.0 then
            flashlight_settings.batteryGUIForegroundColor = flashlight_settings.batteryGUIForegroundColor25
        end
    elseif not flashlight_settings.isDynamicBatteryGUI and isDynaLightUsed then
        flashlight_settings.batteryGUIForegroundColor = hk.recurse_def_settings({}, flashlight_default_settings.batteryGUIForegroundColor)
        isDynaLightUsed = false
    end
end

local function draw_Flashlight_GUI()
    if imgui.tree_node("Flashlight Settings") then
		imgui.begin_rect()
        imgui.spacing()
        imgui.indent(5)
			if imgui.button("Reset to Defaults") then
				wc = true
				flashlight_settings = hk.recurse_def_settings({}, flashlight_default_settings)
				hk.reset_from_defaults_tbl(flashlight_default_settings.hotkeys)
			end
            imgui.same_line()
            func.colored_TextSwitch("Flashlight State:", flashlight_settings.flashlight_Power, "ON", 0xFF00FF00, "OFF", 0xFF0000FF)
            imgui.same_line()
            func.colored_TextSwitch("Battery Drain:", flashlight_settings.flashlight_Battery, "ON", 0xFF00FF00, "OFF", 0xFF0000FF)

            imgui.spacing()

            changed, flashlight_settings.lightRadius = imgui.drag_float("Light Radius", flashlight_settings.lightRadius, 0.1, 0.0, 100.0); wc = wc or changed
            changed, flashlight_settings.lightRange = imgui.drag_float("Light Range", flashlight_settings.lightRange, 1.0, 0.0, 1000.0); wc = wc or changed
            changed, flashlight_settings.lightIntensity = imgui.drag_float("Light Intensity", flashlight_settings.lightIntensity, 50.0, 0.0, 100000.0); wc = wc or changed
            --changed, flashlight_settings.lightIntensityTemp = imgui.drag_float("Light Intensity", flashlight_settings.lightIntensityTemp, 50.0, 0.0, 100000.0)
            
            imgui.spacing()
            
            local LightColor = func.convert_rgb_to_vector3f(flashlight_settings.lightColor.R, flashlight_settings.lightColor.G, flashlight_settings.lightColor.B)
            changed, flashlight_settings.isRGB = imgui.checkbox("Enable RGB Mode", flashlight_settings.isRGB); wc = wc or changed
            if flashlight_settings.isRGB then
                changed, flashlight_settings.deltaTimeRGB = imgui.drag_float("RGB Mode Blend Speed", flashlight_settings.deltaTimeRGB, 0.0001, 0.0, 1.0); wc = wc or changed
            end
            changed, LightColor = imgui.color_edit3("Light Color", LightColor, nil); wc = wc or changed

            local R, G, B = func.convert_vector3f_to_rgb(LightColor)
            flashlight_settings.lightColor.R = R
            flashlight_settings.lightColor.G = G
            flashlight_settings.lightColor.B = B

            imgui.spacing()

            changed, flashlight_settings.flashlight_Battery = imgui.checkbox("Enable Battery Drain", flashlight_settings.flashlight_Battery); wc = wc or changed
            if flashlight_settings.flashlight_Battery then
                imgui.slider_float("Battery Level", flashlight_settings.flashlight_BatteryLevel, 0.0, 100.0, "%.2f%%")
                changed, flashlight_settings.flashlight_BatteryDrainRate = imgui.drag_float("Battery Drain Rate", flashlight_settings.flashlight_BatteryDrainRate, 0.0005, 0.0, 100.0, "%.4f%%"); wc = wc or changed
                changed, flashlight_settings.flashlight_BatteryRechargeRate = imgui.drag_float("Battery Recharge Rate", flashlight_settings.flashlight_BatteryRechargeRate, 0.0005, 0.0, 100.0, "%.4f%%"); wc = wc or changed
            end

            imgui.spacing()

            changed, flashlight_settings.isBatteryGUI = imgui.checkbox("Show Battery UI", flashlight_settings.isBatteryGUI); wc = wc or changed
            if flashlight_settings.isBatteryGUI then
                imgui.same_line()
                changed, flashlight_settings.isDynamicBatteryGUI = imgui.checkbox("Dynamic Battery UI", flashlight_settings.isDynamicBatteryGUI); wc = wc or changed
                imgui.same_line()
                changed, flashlight_settings.isAlwaysBatteryGUI = imgui.checkbox("Always Show Battery UI", flashlight_settings.isAlwaysBatteryGUI); wc = wc or changed

                if not flashlight_settings.isDynamicBatteryGUI then
                    local batteryGUIForegroundColor = func.convert_rgba_to_vector4f(flashlight_settings.batteryGUIForegroundColor[1], flashlight_settings.batteryGUIForegroundColor[2], flashlight_settings.batteryGUIForegroundColor[3], flashlight_settings.batteryGUIForegroundColor[4])
                    changed, batteryGUIForegroundColor = imgui.color_edit4("Battery UI Color", batteryGUIForegroundColor); wc = wc or changed
                    local R3, G3, B3, A3 = func.convert_vector4f_to_rgba(batteryGUIForegroundColor)
                    flashlight_settings.batteryGUIForegroundColor[1] = R3
                    flashlight_settings.batteryGUIForegroundColor[2] = G3
                    flashlight_settings.batteryGUIForegroundColor[3] = B3
                    flashlight_settings.batteryGUIForegroundColor[4] = A3
                end
                if flashlight_settings.isDynamicBatteryGUI then
                    local batteryGUIForegroundColor100 = func.convert_rgba_to_vector4f(flashlight_settings.batteryGUIForegroundColor100[1], flashlight_settings.batteryGUIForegroundColor100[2], flashlight_settings.batteryGUIForegroundColor100[3], flashlight_settings.batteryGUIForegroundColor100[4])
                    changed, batteryGUIForegroundColor100 = imgui.color_edit4("Battery UI Color: Below 100% ", batteryGUIForegroundColor100); wc = wc or changed
                    local R4, G4, B4, A4 = func.convert_vector4f_to_rgba(batteryGUIForegroundColor100)
                    flashlight_settings.batteryGUIForegroundColor100[1] = R4
                    flashlight_settings.batteryGUIForegroundColor100[2] = G4
                    flashlight_settings.batteryGUIForegroundColor100[3] = B4
                    flashlight_settings.batteryGUIForegroundColor100[4] = A4

                    local batteryGUIForegroundColor75 = func.convert_rgba_to_vector4f(flashlight_settings.batteryGUIForegroundColor75[1], flashlight_settings.batteryGUIForegroundColor75[2], flashlight_settings.batteryGUIForegroundColor75[3], flashlight_settings.batteryGUIForegroundColor75[4])
                    changed, batteryGUIForegroundColor75 = imgui.color_edit4("Battery UI Color: Below 75%", batteryGUIForegroundColor75); wc = wc or changed
                    local R5, G5, B5, A5 = func.convert_vector4f_to_rgba(batteryGUIForegroundColor75)
                    flashlight_settings.batteryGUIForegroundColor75[1] = R5
                    flashlight_settings.batteryGUIForegroundColor75[2] = G5
                    flashlight_settings.batteryGUIForegroundColor75[3] = B5
                    flashlight_settings.batteryGUIForegroundColor75[4] = A5

                    local batteryGUIForegroundColor50 = func.convert_rgba_to_vector4f(flashlight_settings.batteryGUIForegroundColor50[1], flashlight_settings.batteryGUIForegroundColor50[2], flashlight_settings.batteryGUIForegroundColor50[3], flashlight_settings.batteryGUIForegroundColor50[4])
                    changed, batteryGUIForegroundColor50 = imgui.color_edit4("Battery UI Color: Below 50%", batteryGUIForegroundColor50); wc = wc or changed
                    local R6, G6, B6, A6 = func.convert_vector4f_to_rgba(batteryGUIForegroundColor50)
                    flashlight_settings.batteryGUIForegroundColor50[1] = R6
                    flashlight_settings.batteryGUIForegroundColor50[2] = G6
                    flashlight_settings.batteryGUIForegroundColor50[3] = B6
                    flashlight_settings.batteryGUIForegroundColor50[4] = A6

                    local batteryGUIForegroundColor25 = func.convert_rgba_to_vector4f(flashlight_settings.batteryGUIForegroundColor25[1], flashlight_settings.batteryGUIForegroundColor25[2], flashlight_settings.batteryGUIForegroundColor25[3], flashlight_settings.batteryGUIForegroundColor25[4])
                    changed, batteryGUIForegroundColor25 = imgui.color_edit4("Battery UI Color: Below 25%", batteryGUIForegroundColor25); wc = wc or changed
                    local R7, G7, B7, A7 = func.convert_vector4f_to_rgba(batteryGUIForegroundColor25)
                    flashlight_settings.batteryGUIForegroundColor25[1] = R7
                    flashlight_settings.batteryGUIForegroundColor25[2] = G7
                    flashlight_settings.batteryGUIForegroundColor25[3] = B7
                    flashlight_settings.batteryGUIForegroundColor25[4] = A7
                end

                local batteryGUIBackgroundColor = func.convert_rgba_to_vector4f(flashlight_settings.batteryGUIBackgroundColor[1], flashlight_settings.batteryGUIBackgroundColor[2], flashlight_settings.batteryGUIBackgroundColor[3], flashlight_settings.batteryGUIBackgroundColor[4])
                changed, batteryGUIBackgroundColor = imgui.color_edit4("Battery UI Background Color ", batteryGUIBackgroundColor); wc = wc or changed
                local R2, G2, B2, A2 = func.convert_vector4f_to_rgba(batteryGUIBackgroundColor)
                flashlight_settings.batteryGUIBackgroundColor[1] = R2
                flashlight_settings.batteryGUIBackgroundColor[2] = G2
                flashlight_settings.batteryGUIBackgroundColor[3] = B2
                flashlight_settings.batteryGUIBackgroundColor[4] = A2

                changed, flashlight_settings.batteryGUIThreshold = imgui.drag_float("Battery UI Threshold", flashlight_settings.batteryGUIThreshold, 1.0, 0.0, 100.0, "%.1f%%"); wc = wc or changed
                changed, flashlight_settings.batteryGUIPos.x = imgui.drag_int("Battery UI Position X", flashlight_settings.batteryGUIPos.x, 1, 0, 200); wc = wc or changed
                changed, flashlight_settings.batteryGUIPos.y = imgui.drag_int("Battery UI Position Y", flashlight_settings.batteryGUIPos.y, 1, 0, 200); wc = wc or changed
                changed, flashlight_settings.batteryGUIPos.z = imgui.drag_int("Battery UI Height", flashlight_settings.batteryGUIPos.z, 1, 0, 100); wc = wc or changed
                changed, flashlight_settings.batteryGUIPos.w = imgui.drag_float("Battery UI Width", flashlight_settings.batteryGUIPos.w, 1.0, 0.0, 500.0, "%.1f%%"); wc = wc or changed
            end

            imgui.spacing()
            
            changed, flashlight_settings.flashlight_Flicker = imgui.checkbox("Enable Flicker", flashlight_settings.flashlight_Flicker); wc = wc or changed
            if flashlight_settings.flashlight_Flicker then
                changed, flashlight_settings.flashlight_Flicker_Threshold = imgui.drag_float("Flicker Threshold", flashlight_settings.flashlight_Flicker_Threshold, 0.1, 0.0, 100.0, "%.1f%%"); wc = wc or changed
            end
            
            imgui.spacing()
                
            changed, flashlight_settings.flashlight_Dimming = imgui.checkbox("Enable Dimming", flashlight_settings.flashlight_Dimming); wc = wc or changed
            if flashlight_settings.flashlight_Dimming then
                changed, flashlight_settings.flashlight_Dimming_Threshold = imgui.drag_float("Dimming Threshold", flashlight_settings.flashlight_Dimming_Threshold, 0.1, 0.0, 25.0, "%.1f%%"); wc = wc or changed
            end

            imgui.spacing()

            changed, flashlight_settings.lightUseFalloff = imgui.checkbox("Use Falloff", flashlight_settings.lightUseFalloff); wc = wc or changed
            changed, flashlight_settings.lightFalloff = imgui.drag_float("Light Falloff", flashlight_settings.lightFalloff, 1.0, 0.0, 500.0); wc = wc or changed
            changed, flashlight_settings.lightSpread = imgui.drag_float("Light Spread", flashlight_settings.lightSpread, 1.0, 0.0, 150.0); wc = wc or changed
            changed, flashlight_settings.lightCone = imgui.drag_float("Light Cone", flashlight_settings.lightCone, 1.0, 0.0, 1000.0); wc = wc or changed
            imgui.spacing()
            changed, flashlight_settings.lightShadowEnable = imgui.checkbox("Enable Shadows", flashlight_settings.lightShadowEnable); wc = wc or changed
            changed, flashlight_settings.lightTemperature = imgui.drag_float("Light Temperature", flashlight_settings.lightTemperature, 100.0, 0.0, 100000.0); wc = wc or changed
            changed, flashlight_settings.lightBounceIntensity = imgui.drag_float("Light Bounce Intensity", flashlight_settings.lightBounceIntensity, 1.0, 0.0, 1000.0); wc = wc or changed
            changed, flashlight_settings.lightMinRoughness = imgui.drag_float("Minimum Roughness", flashlight_settings.lightMinRoughness, 0.1, 0.0, 15.0); wc = wc or changed
            changed, flashlight_settings.lightSpecScale = imgui.drag_float("Specular Scale", flashlight_settings.lightSpecScale, 0.1, 0.0, 15.0); wc = wc or changed
            changed, flashlight_settings.lightAOEfficiency = imgui.drag_float("AO Efficiency", flashlight_settings.lightAOEfficiency, 0.1, 0.0, 100.0); wc = wc or changed
            
            imgui.spacing()

            imgui.begin_rect()
			changed, flashlight_settings.input_mode_idx = imgui.combo("Input Settings", flashlight_settings.input_mode_idx, {"Default", "Custom"}); wc = wc or changed
			func.tooltip("Set the control scheme for the mod")
			
			if flashlight_settings.input_mode_idx == 2 then
                if imgui.tree_node("Keyboard and Mouse Settings") then
                    changed, flashlight_settings.use_modifier = imgui.checkbox(" ", flashlight_settings.use_modifier); wc = wc or changed
                    func.tooltip("Require that you hold down this button")
                    imgui.same_line()
                    changed = hk.hotkey_setter("Flashlight Modifier"); wc = wc or changed
                    changed = hk.hotkey_setter("Flashlight Switch", flashlight_settings.use_modifier and "Flashlight Modifier"); wc = wc or changed
                    imgui.tree_pop()
                end
                
                if imgui.tree_node("Gamepad Settings") then
                    changed, flashlight_settings.use_pad_modifier = imgui.checkbox(" ", flashlight_settings.use_pad_modifier); wc = wc or changed
                    func.tooltip("Require that you hold down this button")
                    imgui.same_line()
                    changed = hk.hotkey_setter("Pad Flashlight Modifier"); wc = wc or changed
                    changed = hk.hotkey_setter("Pad Flashlight Switch", flashlight_settings.use_pad_modifier and "Pad Flashlight Modifier"); wc = wc or changed
                    imgui.tree_pop()
                end
			end
			imgui.end_rect(2)

            if changed or wc then
				hk.update_hotkey_table(flashlight_settings.hotkeys)
				json.dump_file("SILVER/Flashlight_Settings.json", flashlight_settings)
                wc = false
                changed = false
			end

        ui.button_n_colored_txt("Current Version:", modVersion .. " | " .. modUpdated, func.convert_rgba_to_AGBR(0, 255, 0, 255))
        imgui.same_line()
        imgui.text("| by " .. modAuthor .. " ")
        imgui.spacing()
        imgui.indent(-5)
        imgui.end_rect(3)
        imgui.tree_pop()
    end
end

local function draw_OnFrame_Flashlight_GUI()
    if (flashlight_settings.isBatteryGUI and flashlight_settings.flashlight_BatteryLevel < flashlight_settings.batteryGUIThreshold) or flashlight_settings.isAlwaysBatteryGUI then
        local size = sdk.call_native_func(sdk.call_native_func(sdk.get_native_singleton("via.SceneManager"), sdk.find_type_definition("via.SceneManager"), "get_MainView"), sdk.find_type_definition("via.SceneView"), "get_WindowSize")
        local battery_gui_pos = {
            x = flashlight_settings.batteryGUIPos.x * 0.01 * (size.w / 2),
            y = flashlight_settings.batteryGUIPos.y * 0.01 * (size.h / 2)
        }
        local width = 200.0 * (1920.0 / size.w) * flashlight_settings.batteryGUIPos.w * 0.01
        imgui.set_next_window_pos({battery_gui_pos.x, battery_gui_pos.y}, 3, {0,0})
        imgui.set_next_window_size({width, width}, 3)
        update_DynamicBatteryUI()
        local should_DrawBatteryGUI = (flashlight_settings.isDynamicBatteryGUI and isVitalGUIDrawn) or flashlight_settings.isAlwaysBatteryGUI
        if should_DrawBatteryGUI or not flashlight_settings.isDynamicBatteryGUI then
            imgui.begin_window("Battery", true, 129)
            imgui.set_next_item_width(width)
            imgui.push_style_color(7, func.convert_rgba_to_AGBR(flashlight_settings.batteryGUIBackgroundColor))
            imgui.push_style_color(40, func.convert_rgba_to_AGBR(flashlight_settings.batteryGUIForegroundColor))
            imgui.progress_bar(flashlight_settings.flashlight_BatteryLevel / 100, Vector2f.new(flashlight_settings.batteryGUIPos.w, flashlight_settings.batteryGUIPos.z))
            imgui.pop_style_color(2)
            imgui.end_window()
        end
    end
end

sdk.hook(sdk.find_type_definition("chainsaw.VitalAmountGui"):get_method("update"),
	function(args)
        isVitalGUIDrawn = true
end)

re.on_frame(function ()
    update_flashlightState()
    set_flashlightState()
    if isPlayerInScene then
        draw_OnFrame_Flashlight_GUI()
    end
    isVitalGUIDrawn = false
end)

re.on_draw_ui(function ()
    draw_Flashlight_GUI()
end)