-- Lua Console Overlay Mod for Teardown
-- Provides an interactive console for debugging, scripting, and registry management

-- Global variables
console = {
    visible = false,
    input = "",
    cursor = 0,
    history = {},
    historyIndex = 0,
    logs = {},
    maxLogs = 1000,
    scroll = 0,
    apiFunctions = {},
    completionMatches = nil,
    completionIndex = 0,
    keybind = "~",
    opacity = 0.8,
    width = 800,
    height = 400,
    fontSize = 20
}

-- Initialize the mod
function init()
    -- Load API functions for completion
    loadApiFunctions()
    -- Load settings from registry
    loadOptions()
    -- Load previous session
    loadSession()
    if DebugPrint then
        DebugPrint("Lua Console Overlay Mod initialized")
    end
end

-- Main update loop
function tick(dt)
    -- Handle console toggle
    if InputPressed and InputPressed("f7") then
        console.visible = not console.visible
        if not console.visible then
            saveSession()
        end
    end

    -- Handle command execution and special keys when console is visible
    if console.visible then
        if InputPressed and InputPressed("return") then
            executeCommand(console.input)
            table.insert(console.history, console.input)
            console.input = ""
            console.cursor = 0
            console.historyIndex = 0
            console.completionMatches = nil
        elseif InputPressed and InputPressed("tab") then
            -- Tab completion
            if console.input ~= "" then
                if console.completionMatches and #console.completionMatches > 1 then
                    -- Cycle through matches
                    console.completionIndex = console.completionIndex + 1
                    if console.completionIndex > #console.completionMatches then
                        console.completionIndex = 1
                    end
                    console.input = console.completionMatches[console.completionIndex]
                else
                    -- Find new matches
                    local matches = {}
                    for _, func in ipairs(console.apiFunctions) do
                        if func:lower():find(console.input:lower(), 1, true) == 1 then
                            table.insert(matches, func)
                        end
                    end
                    if #matches == 1 then
                        console.input = matches[1]
                        console.completionMatches = nil
                    elseif #matches > 1 then
                        console.completionMatches = matches
                        console.completionIndex = 1
                        console.input = matches[1]
                    end
                end
            end
        elseif InputPressed and InputPressed("uparrow") then
            if #console.history > 0 then
                console.historyIndex = math.min(#console.history, console.historyIndex + 1)
                if console.historyIndex > 0 then
                    console.input = console.history[#console.history - console.historyIndex + 1]
                end
            end
        elseif InputPressed and InputPressed("downarrow") then
            if console.historyIndex > 0 then
                console.historyIndex = console.historyIndex - 1
                if console.historyIndex == 0 then
                    console.input = ""
                else
                    console.input = console.history[#console.history - console.historyIndex + 1]
                end
            end
        end
    end

    -- Handle input when console is visible
    if console.visible then
        handleInput()
    end

    -- Handle mouse wheel scrolling when console is visible
    if console.visible then
        local wheel = InputValue and InputValue("mousewheel") or 0
        if wheel > 0 then
            local maxLines = math.floor((console.height - 60) / (console.fontSize + 2))
            local maxScroll = math.max(0, #console.logs - maxLines)
            console.scroll = math.min(maxScroll, console.scroll + 1)  -- Scroll up (show later logs)
        elseif wheel < 0 then
            local maxLines = math.floor((console.height - 60) / (console.fontSize + 2))
            local maxScroll = math.max(0, #console.logs - maxLines)
            console.scroll = math.max(0, console.scroll - 1)  -- Scroll down (show earlier logs)
        end
    end
end

-- Draw the console overlay
function draw()
    if console.visible then
        drawConsole()
    end
end

-- Handle input when console is active
function handleInput()
    -- Input is now handled automatically by UiTextInput in drawConsole
    -- Special keys (Enter, Tab, arrows) are handled in tick()
end

-- Load API functions for command completion
function loadApiFunctions()
    console.apiFunctions = {}
    -- Extract function names from API XML
    local apiXml = [[
<api>
<function name="GetIntParam">
<function name="GetFloatParam">
<function name="GetBoolParam">
<function name="GetStringParam">
<function name="GetColorParam">
<function name="GetVersion">
<function name="HasVersion">
<function name="GetTime">
<function name="GetTimeStep">
<function name="InputLastPressedKey">
<function name="InputPressed">
<function name="InputReleased">
<function name="InputDown">
<function name="InputValue">
<function name="InputClear">
<function name="InputResetOnTransition">
<function name="LastInputDevice">
<function name="SetValue">
<function name="SetValueInTable">
<function name="PauseMenuButton">
<function name="HasFile">
<function name="StartLevel">
<function name="SetPaused">
<function name="Restart">
<function name="Menu">
<function name="ClearKey">
<function name="ListKeys">
<function name="HasKey">
<function name="SetInt">
<function name="GetInt">
<function name="SetFloat">
<function name="GetFloat">
<function name="SetBool">
<function name="GetBool">
<function name="SetString">
<function name="GetString">
<function name="GetEventCount">
<function name="GetEvent">
<function name="SetColor">
<function name="GetColor">
<function name="GetTranslatedStringByKey">
<function name="HasTranslationByKey">
<function name="LoadLanguageTable">
<function name="GetUserNickname">
<function name="Vec">
<function name="VecCopy">
<function name="VecStr">
<function name="VecLength">
<function name="VecNormalize">
<function name="VecScale">
<function name="VecAdd">
<function name="VecSub">
<function name="VecDot">
<function name="VecCross">
<function name="VecLerp">
<function name="Quat">
<function name="QuatCopy">
<function name="QuatAxisAngle">
<function name="QuatDeltaNormals">
<function name="QuatDeltaVectors">
<function name="QuatEuler">
<function name="QuatAlignXZ">
<function name="GetQuatEuler">
<function name="QuatLookAt">
<function name="QuatSlerp">
<function name="QuatStr">
<function name="QuatRotateQuat">
<function name="QuatRotateVec">
<function name="Transform">
<function name="TransformCopy">
<function name="TransformStr">
<function name="TransformToParentTransform">
<function name="TransformToLocalTransform">
<function name="TransformToParentVec">
<function name="TransformToLocalVec">
<function name="TransformToParentPoint">
<function name="TransformToLocalPoint">
<function name="FindEntity">
<function name="FindEntities">
<function name="GetEntityChildren">
<function name="GetEntityParent">
<function name="SetTag">
<function name="RemoveTag">
<function name="HasTag">
<function name="GetTagValue">
<function name="ListTags">
<function name="GetDescription">
<function name="SetDescription">
<function name="Delete">
<function name="IsHandleValid">
<function name="GetEntityType">
<function name="GetProperty">
<function name="SetProperty">
<function name="FindBody">
<function name="FindBodies">
<function name="GetBodyTransform">
<function name="SetBodyTransform">
<function name="GetBodyMass">
<function name="IsBodyDynamic">
<function name="SetBodyDynamic">
<function name="SetBodyVelocity">
<function name="GetBodyVelocity">
<function name="GetBodyVelocityAtPos">
<function name="SetBodyAngularVelocity">
<function name="GetBodyAngularVelocity">
<function name="IsBodyActive">
<function name="SetBodyActive">
<function name="ApplyBodyImpulse">
<function name="GetBodyShapes">
<function name="GetBodyVehicle">
<function name="GetBodyBounds">
<function name="GetBodyCenterOfMass">
<function name="IsBodyVisible">
<function name="IsBodyBroken">
<function name="DrawBodyOutline">
<function name="DrawBodyHighlight">
<function name="GetBodyClosestPoint">
<function name="ConstrainVelocity">
<function name="ConstrainAngularVelocity">
<function name="ConstrainPosition">
<function name="ConstrainOrientation">
<function name="GetWorldBody">
<function name="FindShape">
<function name="FindShapes">
<function name="GetShapeLocalTransform">
<function name="SetShapeLocalTransform">
<function name="GetShapeWorldTransform">
<function name="GetShapeBody">
<function name="GetShapeJoints">
<function name="GetShapeLights">
<function name="GetShapeBounds">
<function name="SetShapeEmissiveScale">
<function name="SetShapeDensity">
<function name="GetShapeMaterialAtPosition">
<function name="GetShapeMaterialAtIndex">
<function name="GetShapeSize">
<function name="GetShapeVoxelCount">
<function name="IsShapeVisible">
<function name="IsShapeBroken">
<function name="DrawShapeOutline">
<function name="DrawShapeHighlight">
<function name="SetShapeCollisionFilter">
<function name="GetShapeCollisionFilter">
<function name="CreateShape">
<function name="ClearShape">
<function name="ResizeShape">
<function name="SetShapeBody">
<function name="CopyShapeContent">
<function name="CopyShapePalette">
<function name="GetShapePalette">
<function name="GetShapeMaterial">
<function name="SetBrush">
<function name="DrawShapeLine">
<function name="DrawShapeBox">
<function name="ExtrudeShape">
<function name="TrimShape">
<function name="SplitShape">
<function name="MergeShape">
<function name="IsShapeDisconnected">
<function name="IsStaticShapeDetached">
<function name="GetShapeClosestPoint">
<function name="IsShapeTouching">
<function name="FindLocation">
<function name="FindLocations">
<function name="GetLocationTransform">
<function name="FindJoint">
<function name="FindJoints">
<function name="IsJointBroken">
<function name="GetJointType">
<function name="GetJointOtherShape">
<function name="GetJointShapes">
<function name="SetJointMotor">
<function name="SetJointMotorTarget">
<function name="GetJointLimits">
<function name="GetJointMovement">
<function name="GetJointedBodies">
<function name="DetachJointFromShape">
<function name="GetRopeNumberOfPoints">
<function name="GetRopePointPosition">
<function name="GetRopeBounds">
<function name="BreakRope">
<function name="SetAnimatorPositionIK">
<function name="SetAnimatorTransformIK">
<function name="GetBoneChainLength">
<function name="FindAnimator">
<function name="FindAnimators">
<function name="GetAnimatorTransform">
<function name="GetAnimatorAdjustTransformIK">
<function name="SetAnimatorTransform">
<function name="MakeRagdoll">
<function name="UnRagdoll">
<function name="PlayAnimation">
<function name="PlayAnimationLoop">
<function name="PlayAnimationInstance">
<function name="StopAnimationInstance">
<function name="PlayAnimationFrame">
<function name="BeginAnimationGroup">
<function name="EndAnimationGroup">
<function name="PlayAnimationInstances">
<function name="GetAnimationClipNames">
<function name="GetAnimationClipDuration">
<function name="SetAnimationClipFade">
<function name="SetAnimationClipSpeed">
<function name="TrimAnimationClip">
<function name="GetAnimationClipLoopPosition">
<function name="GetAnimationInstancePosition">
<function name="SetAnimationClipLoopPosition">
<function name="SetBoneRotation">
<function name="SetBoneLookAt">
<function name="RotateBone">
<function name="GetBoneNames">
<function name="GetBoneBody">
<function name="GetBoneWorldTransform">
<function name="GetBoneBindPoseTransform">
<function name="FindLight">
<function name="FindLights">
<function name="SetLightEnabled">
<function name="SetLightColor">
<function name="SetLightIntensity">
<function name="GetLightTransform">
<function name="GetLightShape">
<function name="IsLightActive">
<function name="IsPointAffectedByLight">
<function name="GetFlashlight">
<function name="SetFlashlight">
<function name="FindTrigger">
<function name="FindTriggers">
<function name="GetTriggerTransform">
<function name="SetTriggerTransform">
<function name="GetTriggerBounds">
<function name="IsBodyInTrigger">
<function name="IsVehicleInTrigger">
<function name="IsShapeInTrigger">
<function name="IsPointInTrigger">
<function name="IsPointInBoundaries">
<function name="IsTriggerEmpty">
<function name="GetTriggerDistance">
<function name="GetTriggerClosestPoint">
<function name="FindScreen">
<function name="FindScreens">
<function name="SetScreenEnabled">
<function name="IsScreenEnabled">
<function name="GetScreenShape">
<function name="FindVehicle">
<function name="FindVehicles">
<function name="GetVehicleTransform">
<function name="GetVehicleExhaustTransforms">
<function name="GetVehicleVitalTransforms">
<function name="GetVehicleBodies">
<function name="GetVehicleBody">
<function name="GetVehicleHealth">
<function name="GetVehicleParams">
<function name="SetVehicleParam">
<function name="GetVehicleDriverPos">
<function name="GetVehicleSteering">
<function name="GetVehicleDrive">
<function name="DriveVehicle">
<function name="GetPlayerPos">
<function name="GetPlayerAimInfo">
<function name="GetPlayerPitch">
<function name="GetPlayerYaw">
<function name="SetPlayerPitch">
<function name="GetPlayerCrouch">
<function name="GetPlayerTransform">
<function name="SetPlayerTransform">
<function name="ClearPlayerRig">
<function name="SetPlayerRigLocationLocalTransform">
<function name="SetPlayerRigTransform">
<function name="GetPlayerRigTransform">
<function name="GetPlayerRigLocationWorldTransform">
<function name="SetPlayerRigTags">
<function name="GetPlayerRigHasTag">
<function name="GetPlayerRigTagValue">
<function name="SetPlayerGroundVelocity">
<function name="GetPlayerEyeTransform">
<function name="GetPlayerCameraTransform">
<function name="SetPlayerCameraOffsetTransform">
<function name="SetPlayerSpawnTransform">
<function name="SetPlayerSpawnHealth">
<function name="SetPlayerSpawnTool">
<function name="GetPlayerVelocity">
<function name="SetPlayerVelocity">
<function name="GetPlayerVehicle">
<function name="IsPlayerGrounded">
<function name="GetPlayerGroundContact">
<function name="GetPlayerGrabShape">
<function name="GetPlayerGrabBody">
<function name="ReleasePlayerGrab">
<function name="GetPlayerGrabPoint">
<function name="GetPlayerPickShape">
<function name="GetPlayerPickBody">
<function name="GetPlayerInteractShape">
<function name="GetPlayerInteractBody">
<function name="SetPlayerScreen">
<function name="GetPlayerScreen">
<function name="SetPlayerHealth">
<function name="GetPlayerHealth">
<function name="SetPlayerRegenerationState">
<function name="RespawnPlayer">
<function name="GetPlayerWalkingSpeed">
<function name="SetPlayerWalkingSpeed">
<function name="GetPlayerParam">
<function name="SetPlayerParam">
<function name="SetPlayerHidden">
<function name="RegisterTool">
<function name="GetToolBody">
<function name="GetToolHandPoseLocalTransform">
<function name="GetToolHandPoseWorldTransform">
<function name="SetToolHandPoseLocalTransform">
<function name="GetToolLocationLocalTransform">
<function name="GetToolLocationWorldTransform">
<function name="SetToolTransform">
<function name="SetToolAllowedZoom">
<function name="SetToolTransformOverride">
<function name="SetToolOffset">
<function name="LoadSound">
<function name="UnloadSound">
<function name="LoadLoop">
<function name="UnloadLoop">
<function name="SetSoundLoopUser">
<function name="PlaySound">
<function name="StopSound">
<function name="IsSoundPlaying">
<function name="GetSoundProgress">
<function name="SetSoundProgress">
<function name="PlayLoop">
<function name="GetSoundLoopProgress">
<function name="SetSoundLoopProgress">
<function name="PlayMusic">
<function name="StopMusic">
<function name="IsMusicPlaying">
<function name="SetMusicPaused">
<function name="GetMusicProgress">
<function name="SetMusicProgress">
<function name="SetMusicVolume">
<function name="SetMusicLowPass">
<function name="LoadSprite">
<function name="DrawSprite">
<function name="QueryRequire">
<function name="QueryInclude">
<function name="QueryRejectAnimator">
<function name="QueryRejectVehicle">
<function name="QueryRejectBody">
<function name="QueryRejectBodies">
<function name="QueryRejectShape">
<function name="QueryRejectShapes">
<function name="QueryRaycast">
<function name="QueryRaycastRope">
<function name="QueryClosestPoint">
<function name="QueryAabbShapes">
<function name="QueryAabbBodies">
<function name="QueryPath">
<function name="CreatePathPlanner">
<function name="DeletePathPlanner">
<function name="PathPlannerQuery">
<function name="AbortPath">
<function name="GetPathState">
<function name="GetPathLength">
<function name="GetPathPoint">
<function name="GetLastSound">
<function name="IsPointInWater">
<function name="GetWindVelocity">
<function name="ParticleReset">
<function name="ParticleType">
<function name="ParticleTile">
<function name="ParticleColor">
<function name="ParticleRadius">
<function name="ParticleAlpha">
<function name="ParticleGravity">
<function name="ParticleDrag">
<function name="ParticleEmissive">
<function name="ParticleRotation">
<function name="ParticleStretch">
<function name="ParticleSticky">
<function name="ParticleCollide">
<function name="ParticleFlags">
<function name="SpawnParticle">
<function name="Spawn">
<function name="SpawnLayer">
<function name="Shoot">
<function name="Paint">
<function name="PaintRGBA">
<function name="MakeHole">
<function name="Explosion">
<function name="SpawnFire">
<function name="GetFireCount">
<function name="QueryClosestFire">
<function name="QueryAabbFireCount">
<function name="RemoveAabbFires">
<function name="GetCameraTransform">
<function name="SetCameraTransform">
<function name="RequestFirstPerson">
<function name="RequestThirdPerson">
<function name="SetCameraOffsetTransform">
<function name="AttachCameraTo">
<function name="SetPivotClipBody">
<function name="ShakeCamera">
<function name="SetCameraFov">
<function name="SetCameraDof">
<function name="PointLight">
<function name="SetTimeScale">
<function name="SetEnvironmentDefault">
<function name="SetEnvironmentProperty">
<function name="GetEnvironmentProperty">
<function name="SetPostProcessingDefault">
<function name="SetPostProcessingProperty">
<function name="GetPostProcessingProperty">
<function name="DrawLine">
<function name="DebugLine">
<function name="DebugCross">
<function name="DebugTransform">
<function name="DebugWatch">
<function name="DebugPrint">
<function name="RegisterListenerTo">
<function name="UnregisterListener">
<function name="TriggerEvent">
<function name="LoadHaptic">
<function name="CreateHaptic">
<function name="PlayHaptic">
<function name="PlayHapticDirectional">
<function name="HapticIsPlaying">
<function name="SetToolHaptic">
<function name="StopHaptic">
<function name="SetVehicleHealth">
<function name="QueryRaycastWater">
<function name="AddHeat">
<function name="GetGravity">
<function name="SetGravity">
<function name="SetPlayerOrientation">
<function name="GetPlayerOrientation">
<function name="GetPlayerUp">
<function name="GetFps">
<function name="UiMakeInteractive">
<function name="UiPush">
<function name="UiPop">
<function name="UiWidth">
<function name="UiHeight">
<function name="UiCenter">
<function name="UiMiddle">
<function name="UiColor">
<function name="UiColorFilter">
<function name="UiResetColor">
<function name="UiTranslate">
<function name="UiRotate">
<function name="UiScale">
<function name="UiGetScale">
<function name="UiClipRect">
<function name="UiWindow">
<function name="UiGetCurrentWindow">
<function name="UiIsInCurrentWindow">
<function name="UiIsRectFullyClipped">
<function name="UiIsInClipRegion">
<function name="UiIsFullyClipped">
<function name="UiSafeMargins">
<function name="UiCanvasSize">
<function name="UiAlign">
<function name="UiTextAlignment">
<function name="UiModalBegin">
<function name="UiModalEnd">
<function name="UiDisableInput">
<function name="UiEnableInput">
<function name="UiReceivesInput">
<function name="UiGetMousePos">
<function name="UiGetCanvasMousePos">
<function name="UiIsMouseInRect">
<function name="UiWorldToPixel">
<function name="UiPixelToWorld">
<function name="UiGetCursorPos">
<function name="UiBlur">
<function name="UiFont">
<function name="UiFontHeight">
<function name="UiText">
<function name="UiTextDisableWildcards">
<function name="UiTextUniformHeight">
<function name="UiTextLineSpacing">
<function name="UiTextOutline">
<function name="UiTextShadow">
<function name="UiRect">
<function name="UiRectOutline">
<function name="UiRoundedRect">
<function name="UiRoundedRectOutline">
<function name="UiCircle">
<function name="UiCircleOutline">
<function name="UiFillImage">
<function name="UiImage">
<function name="UiUnloadImage">
<function name="UiHasImage">
<function name="UiGetImageSize">
<function name="UiImageBox">
<function name="UiSound">
<function name="UiSoundLoop">
<function name="UiMute">
<function name="UiButtonImageBox">
<function name="UiButtonHoverColor">
<function name="UiButtonPressColor">
<function name="UiButtonPressDist">
<function name="UiButtonTextHandling">
<function name="UiTextButton">
<function name="UiImageButton">
<function name="UiBlankButton">
<function name="UiSlider">
<function name="UiSliderHoverColorFilter">
<function name="UiSliderThumbSize">
<function name="UiGetScreen">
<function name="UiNavComponent">
<function name="UiIgnoreNavigation">
<function name="UiResetNavigation">
<function name="UiNavSkipUpdate">
<function name="UiIsComponentInFocus">
<function name="UiNavGroupBegin">
<function name="UiNavGroupEnd">
<function name="UiNavGroupSize">
<function name="UiForceFocus">
<function name="UiFocusedComponentId">
<function name="UiFocusedComponentRect">
<function name="UiGetItemSize">
<function name="UiAutoTranslate">
<function name="UiBeginFrame">
<function name="UiResetFrame">
<function name="UiFrameOccupy">
<function name="UiEndFrame">
<function name="UiFrameSkipItem">
<function name="UiGetFrameNo">
<function name="UiGetLanguage">
<function name="UiSetCursorState">
<function name="UiMeasureText">
<function name="UiGetTextWidth">
<function name="UiGetSymbolsCount">
<function name="UiTextSymbolsSub">
<function name="UiWordWrap">
<function name="JsonEncode">
<function name="JsonDecode">
</api>
    ]]
    for func in apiXml:gmatch('<function name="([^"]*)"') do
        table.insert(console.apiFunctions, func)
    end
end

-- Execute a command entered in the console
function executeCommand(cmd)
    if cmd == "" then return end

    -- Add command to logs
    addLog("INFO", "> " .. cmd)

    -- Parse command
    local parts = {}
    for part in cmd:gmatch("%S+") do
        table.insert(parts, part)
    end

    if #parts == 0 then return end

    local command = string.lower(parts[1])

    if command == "help" or command == "?" then
        showHelp()
    elseif command == "clear" then
        console.logs = {}
    elseif command == "reg" then
        handleRegCommand(parts)
    elseif command == "lua" then
        executeLua(table.concat(parts, " ", 2))
    else
        -- Try to execute as Lua code
        executeLua(cmd)
    end
end

-- Add a log entry
function addLog(level, message)
    local timestamp = os and os.date("%H:%M:%S") or "00:00:00"
    local logEntry = string.format("[%s] %s: %s", timestamp, level, message)
    table.insert(console.logs, logEntry)
    if #console.logs > console.maxLogs then
        table.remove(console.logs, 1)
    end
end

-- Show help
function showHelp()
    addLog("INFO", "Available commands:")
    addLog("INFO", "help/? - Show this help")
    addLog("INFO", "clear - Clear console")
    addLog("INFO", "reg list [path] - List registry keys")
    addLog("INFO", "reg get <key> - Get registry value")
    addLog("INFO", "reg set <key> <value> - Set registry value")
    addLog("INFO", "reg delete <key> - Delete registry key")
    addLog("INFO", "lua <code> - Execute Lua code")
    addLog("INFO", "Or enter any Lua expression directly")
end

-- Handle registry commands
function handleRegCommand(parts)
    if #parts < 2 then
        addLog("ERROR", "Usage: reg <list|get|set|delete> [args]")
        return
    end

    local subcmd = parts[2]

    if subcmd == "list" then
        local path = parts[3] or ""
        if ListKeys then
            local keys = ListKeys(path)
            if keys then
                for _, key in ipairs(keys) do
                    addLog("INFO", key)
                end
            else
                addLog("ERROR", "Invalid path or no keys found")
            end
        else
            addLog("ERROR", "Registry functions not available")
        end
    elseif subcmd == "get" then
        if #parts < 3 then
            addLog("ERROR", "Usage: reg get <key>")
            return
        end
        local key = parts[3]
        if GetString then
            local value = GetString(key)
            if value then
                addLog("INFO", key .. " = " .. value)
            else
                addLog("ERROR", "Key not found")
            end
        else
            addLog("ERROR", "Registry functions not available")
        end
    elseif subcmd == "set" then
        if #parts < 4 then
            addLog("ERROR", "Usage: reg set <key> <value>")
            return
        end
        local key = parts[3]
        local value = table.concat(parts, " ", 4)
        if SetString then
            SetString(key, value)
            addLog("INFO", "Set " .. key .. " = " .. value)
        else
            addLog("ERROR", "Registry functions not available")
        end
    elseif subcmd == "delete" then
        if #parts < 3 then
            addLog("ERROR", "Usage: reg delete <key>")
            return
        end
        local key = parts[3]
        if ClearKey then
            ClearKey(key)
            addLog("INFO", "Deleted " .. key)
        else
            addLog("ERROR", "Registry functions not available")
        end
    else
        addLog("ERROR", "Unknown reg subcommand: " .. subcmd)
    end
end

-- Execute Lua code
function executeLua(code)
    local func, err = loadstring(code)
    if func then
        local success, result = pcall(func)
        if success then
            if result ~= nil then
                addLog("INFO", tostring(result))
            end
        else
            addLog("ERROR", "Runtime error: " .. result)
        end
    else
        addLog("ERROR", "Syntax error: " .. err)
    end
end

-- Options for the console
local options = {
    -- Console appearance
    opacity = {
        name = "Opacity",
        value = 0.8,
        min = 0.1,
        max = 1.0,
        step = 0.1,
        type = "slider"
    },
    width = {
        name = "Width",
        value = 800,
        min = 400,
        max = 1920,
        step = 50,
        type = "slider"
    },
    height = {
        name = "Height",
        value = 400,
        min = 200,
        max = 1080,
        step = 50,
        type = "slider"
    },
    fontSize = {
        name = "Font Size",
        value = 20,
        min = 10,
        max = 50,
        step = 2,
        type = "slider"
    },

    -- Console behavior
    maxLogs = {
        name = "Max Log Lines",
        value = 1000,
        min = 100,
        max = 10000,
        step = 100,
        type = "slider"
    },

    -- Key bindings
    toggleKey = {
        name = "Toggle Key",
        value = "f7",
        type = "text",
        description = "Key to toggle console (grave, f1, etc.)"
    }
}

-- Save options to registry
function saveOptions()
    if not SetFloat or not SetString then return end -- Skip if not in Teardown environment
    for key, option in pairs(options) do
        if option.type == "slider" then
            SetFloat("savegame.mod.console." .. key, option.value)
        elseif option.type == "text" then
            SetString("savegame.mod.console." .. key, option.value)
        end
    end
end

-- Load options from registry
function loadOptions()
    if not GetFloat or not GetString then return end -- Skip if not in Teardown environment
    for key, option in pairs(options) do
        if option.type == "slider" then
            option.value = GetFloat("savegame.mod.console." .. key) or option.value
        elseif option.type == "text" then
            option.value = GetString("savegame.mod.console." .. key) or option.value
        end
    end
end

-- Get option value
function getOption(key)
    return options[key] and options[key].value
end

-- Set option value
function setOption(key, value)
    if options[key] then
        options[key].value = value
        saveOptions()
    end
end

-- Initialize options
loadOptions()

-- Save console session
function saveSession()
    if not JsonEncode then return end -- Skip if not in Teardown environment
    local session = {
        input = console.input,
        cursor = console.cursor,
        history = console.history,
        logs = console.logs,
        scroll = console.scroll
    }
    SetString("savegame.mod.console.session", JsonEncode(session))
end

-- Load console session
function loadSession()
    if not JsonDecode then return end -- Skip if not in Teardown environment
    local sessionData = GetString("savegame.mod.console.session")
    if sessionData then
        local success, session = pcall(JsonDecode, sessionData)
        if success and session then
            console.input = session.input or ""
            console.cursor = session.cursor or 0
            console.history = session.history or {}
            console.logs = session.logs or {}
            console.scroll = session.scroll or 0
        end
    end
end

-- Draw the console overlay
function drawConsole()
    if not UiMakeInteractive then return end -- Skip if not in Teardown environment

    UiMakeInteractive()

    -- Get screen dimensions and center the console
    local screenWidth = UiWidth()
    local screenHeight = UiHeight()
    local consoleX = (screenWidth - console.width) / 2
    local consoleY = (screenHeight - console.height) / 2

    UiPush()
        UiTranslate(consoleX, consoleY)

        -- Background
        UiPush()
            UiColor(0, 0, 0, console.opacity)
            UiRect(console.width, console.height)
        UiPop()

        -- Logs
        UiPush()
            UiTranslate(10, 10)
            UiFont("regular.ttf", console.fontSize)
            UiColor(1, 1, 1, 1)
            local y = 0
            local maxLines = math.floor((console.height - 60) / (console.fontSize + 2))
            local startLine = math.max(1, #console.logs - maxLines - console.scroll)
            for i = startLine, #console.logs do
                UiText(console.logs[i])
                UiTranslate(0, console.fontSize + 2)
                y = y + console.fontSize + 2
                if y > console.height - 60 then break end
            end
        UiPop()

        -- Input prompt
        UiPush()
            UiTranslate(10, console.height - 30)
            UiFont("regular.ttf", console.fontSize)
            UiColor(1, 1, 1, 1)
            
            -- Draw the prompt
            UiText("> ")
            
            -- Use UiTextInput for automatic text input handling
            if UiTextInput then
                local promptWidth = UiGetTextWidth and UiGetTextWidth("> ") or (2 * console.fontSize * 0.6)
                UiTranslate(promptWidth-10, -16) -- Position after the prompt, adjusted for vertical alignment
                local inputWidth = console.width - 20 - promptWidth
                local inputHeight = console.fontSize + 4
                local newText = UiTextInput(console.input, inputWidth, inputHeight, console.visible, false)
                if newText ~= console.input then
                    console.input = newText
                    console.cursor = #console.input
                    console.completionMatches = nil
                end
            else
                -- Fallback for environments without UiTextInput
                UiText(console.input)
                local cursorX = UiGetTextWidth and UiGetTextWidth(console.input:sub(1, console.cursor)) or
                               (#(console.input:sub(1, console.cursor)) * (console.fontSize * 0.6))
                UiTranslate(cursorX, 0)
                UiRect(2, console.fontSize)
            end
        UiPop()

        -- Completion dropdown
        if console.completionMatches and #console.completionMatches > 1 then
            UiPush()
                UiTranslate(10, console.height - 60)
                UiColor(0.2, 0.2, 0.2, 0.9)
                UiRect(console.width - 20, (#console.completionMatches * (console.fontSize + 2)) + 10)
                UiTranslate(5, 5)
                for i, match in ipairs(console.completionMatches) do
                    if i == console.completionIndex then
                        UiColor(0.5, 0.5, 1, 1)
                    else
                        UiColor(1, 1, 1, 1)
                    end
                    UiText(match)
                    UiTranslate(0, console.fontSize + 2)
                end
            UiPop()
        end
    UiPop()
end