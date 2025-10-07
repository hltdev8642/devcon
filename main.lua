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
    apiSignatures = {}, -- New: function signatures with parameters
    completionMatches = nil,
    completionIndex = 0,
    keybind = "~",
    opacity = 0.8,
    width = 800,
    height = 600,
    fontSize = 20,
    scripts = {} -- Script library storage
}

-- Helper function to check if a value exists in a table
local function has_value(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

-- Global variables for level body filtering
global = global or {}
global.levelBodies = global.levelBodies or {}

-- Laser tool variables
local laserTool = {
    selectedBody = 0,
    selectedShape = 0,
    laserRange = 100.0,
    laserColor = {1, 0, 0, 0.8}, -- Red laser
    outlineColor = {1, 0, 0, 0.5} -- Semi-transparent red outline
}

-- Initialize the mod
function init()
    -- Load API functions for completion
    loadApiFunctions()
    -- Load settings from registry
    loadOptions()
    -- Load previous session
    loadSession()
    -- Load saved scripts
    loadScripts()
    -- Load keyboard shortcuts
    loadShortcuts()
    
    -- Register the laser pointer tool
    if RegisterTool then
        RegisterTool("laserpointer", "Laser Pointer", "lasertool/laserpointer.vox")
        SetBool("game.tool.laserpointer.enabled", true)
    end
    
    -- Initialize level bodies for filtering
    if FindBodies then
        local allBodies = FindBodies(nil, true) or {}
        for _, body in ipairs(allBodies) do
            if not IsBodyDynamic(body) then
                local voxelCount = 0
                local shapes = GetBodyShapes(body) or {}
                for _, shape in ipairs(shapes) do
                    voxelCount = voxelCount + (GetShapeVoxelCount(shape) or 0)
                end
                if voxelCount >= 10000000 then
                    table.insert(global.levelBodies, body)
                end
            end
        end
    end
    
    if DebugPrint then
        DebugPrint("Lua Console Overlay Mod initialized")
    end
end

-- Main update loop
function tick(dt)
    -- Handle console toggle
    if InputPressed and InputPressed("home") then
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
                    local searchText = console.input
                    local apiList = console.apiFunctions

                    -- Check if this is an exec command
                    if console.input:lower():find("^exec ") then
                        -- For exec commands, complete from the code part after "exec "
                        -- but use the full API list for maximum flexibility
                        searchText = console.input:sub(6) -- Remove "exec " prefix
                        apiList = console.apiFunctions -- Use full API for exec commands
                    end

                    for _, func in ipairs(apiList) do
                        if func:lower():find(searchText:lower(), 1, true) == 1 then
                            if console.input:lower():find("^exec ") then
                                -- For exec commands, get the signature and add "exec " prefix
                                local signature = console.apiSignatures[func] or (func .. "()")
                                table.insert(matches, "exec " .. signature)
                            else
                                -- For regular commands, use the signature directly
                                local signature = console.apiSignatures[func] or (func .. "()")
                                table.insert(matches, signature)
                            end
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
        elseif InputPressed and InputPressed("end") then
            -- End key completion insertion
            if console.completionMatches and #console.completionMatches > 0 then
                console.input = console.completionMatches[console.completionIndex]
                console.cursor = #console.input
                console.completionMatches = nil
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

    -- Handle laser tool functionality
    handleLaserTool(dt)

    -- Handle mouse wheel scrolling when console is visible
    if console.visible then
        local wheel = InputValue and InputValue("mousewheel") or 0
        if wheel > 0 then
            local maxLines = math.floor((console.height - 60) / (console.fontSize + 2))
            local maxScroll = math.max(0, #console.logs - maxLines)
            console.scroll = math.min(maxScroll, console.scroll + 2)  -- Scroll up (show later logs)
        elseif wheel < 0 then
            local maxLines = math.floor((console.height - 60) / (console.fontSize + 2))
            local maxScroll = math.max(0, #console.logs - maxLines)
            console.scroll = math.max(0, console.scroll - 2)  -- Scroll down (show earlier logs)
        end
    end
end

-- Draw the console overlay
function draw()
    if console.visible then
        drawConsole()
    end
    
    -- Draw laser tool UI if needed
    drawLaserTool()
end

-- Draw laser tool UI
function drawLaserTool()
    -- Tool UI could go here if needed
end

-- Handle input when console is active
function handleInput()
    -- Input is now handled automatically by UiTextInput in drawConsole
    -- Special keys (Enter, Tab, arrows) are handled in tick()
end

-- Handle laser tool functionality
function handleLaserTool(dt)
    -- Only work when this tool is selected
    if not GetString or GetString("game.player.tool") ~= "laserpointer" then
        return
    end

    -- Get player camera transform
    local cameraTransform = GetPlayerCameraTransform()
    if not cameraTransform then return end
    local cameraPos = cameraTransform.pos

    -- Get camera forward direction (negative Z in camera space)
    local cameraDir = TransformToParentVec(cameraTransform, Vec(0, 0, -1))

    -- Perform raycast to find objects
    local hit, dist, normal, shape = QueryRaycast(cameraPos, cameraDir, laserTool.laserRange)

    if hit then
        local hitPoint = VecAdd(cameraPos, VecScale(cameraDir, dist))

        -- Draw laser beam
        DrawLine(cameraPos, hitPoint, laserTool.laserColor[1], laserTool.laserColor[2], laserTool.laserColor[3], laserTool.laserColor[4])

        -- Get the body that contains this shape
        local body = GetShapeBody(shape)

        if not has_value(global.levelBodies, body) then
            -- Body context: work with selectable body
            -- Handle tool usage (click to select)
            if InputPressed and InputPressed("usetool") then
                -- Clear previous selection
                if laserTool.selectedBody ~= 0 then
                    DrawBodyOutline(laserTool.selectedBody, 0) -- Remove outline
                end

                -- Select new object
                laserTool.selectedBody = body
                laserTool.selectedShape = shape

                -- Store selection in registry for console access
                SetInt("lasertool.selected_body", body)
                SetInt("lasertool.selected_shape", shape)

                -- Add red outline to selected body
                DrawBodyOutline(body, laserTool.outlineColor[4])
            end

            -- Draw outline on currently aimed body
            if body ~= laserTool.selectedBody then
                DrawBodyOutline(body, laserTool.outlineColor[4])
            end
        else
            -- Shape context: fallback to shape selection for level bodies
            -- Handle tool usage (click to select)
            if InputPressed and InputPressed("usetool") then
                -- Clear previous selection
                if laserTool.selectedBody ~= 0 then
                    DrawBodyOutline(laserTool.selectedBody, 0) -- Remove outline
                end

                -- Select shape instead of body
                laserTool.selectedBody = 0  -- Clear body selection
                laserTool.selectedShape = shape

                -- Store selection in registry for console access
                SetInt("lasertool.selected_body", 0)
                SetInt("lasertool.selected_shape", shape)

                -- Add red outline to selected shape
                DrawShapeOutline(shape, laserTool.outlineColor[1], laserTool.outlineColor[2], laserTool.outlineColor[3], laserTool.outlineColor[4])
            end

            -- Draw outline on currently aimed shape
            if shape ~= laserTool.selectedShape then
                DrawShapeOutline(shape, laserTool.outlineColor[1], laserTool.outlineColor[2], laserTool.outlineColor[3], laserTool.outlineColor[4])
            end
        end
    end

    -- Keep selected object outlined
    if laserTool.selectedBody ~= 0 then
        DrawBodyOutline(laserTool.selectedBody, laserTool.outlineColor[4])
    elseif laserTool.selectedShape ~= 0 then
        DrawShapeOutline(laserTool.selectedShape, laserTool.outlineColor[1], laserTool.outlineColor[2], laserTool.outlineColor[3], laserTool.outlineColor[4])
    end
end

-- Load API functions for command completion
function loadApiFunctions()
    console.apiFunctions = {}
    console.apiSignatures = {}
    
    -- Parse HTML API documentation for function signatures
    local htmlApi = [[
<h1>API Reference</h1>
<h2>General</h2>
<dl>
<dt><a name="GetVersion"></a>GetVersion()</dt>
<dd>Get game version string</dd>
<dt><a name="HasVersion"></a>HasVersion(version)</dt>
<dd>Check if game has specific version</dd>
<dt><a name="GetTime"></a>GetTime()</dt>
<dd>Get current game time in seconds</dd>
<dt><a name="GetTimeStep"></a>GetTimeStep()</dt>
<dd>Get time step for current frame</dd>
<dt><a name="InputLastPressedKey"></a>InputLastPressedKey()</dt>
<dd>Get last pressed key</dd>
<dt><a name="InputPressed"></a>InputPressed(key)</dt>
<dd>Check if key was pressed this frame</dd>
<dt><a name="InputReleased"></a>InputReleased(key)</dt>
<dd>Check if key was released this frame</dd>
<dt><a name="InputDown"></a>InputDown(key)</dt>
<dd>Check if key is currently down</dd>
<dt><a name="InputValue"></a>InputValue(name)</dt>
<dd>Get input value (mouse, joystick)</dd>
<dt><a name="InputClear"></a>InputClear()</dt>
<dd>Clear all input states</dd>
<dt><a name="InputResetOnTransition"></a>InputResetOnTransition(reset)</dt>
<dd>Reset input on level transition</dd>
<dt><a name="LastInputDevice"></a>LastInputDevice()</dt>
<dd>Get last used input device</dd>
<dt><a name="SetValue"></a>SetValue(name, value)</dt>
<dd>Set global value</dd>
<dt><a name="SetValueInTable"></a>SetValueInTable(table, name, value)</dt>
<dd>Set value in table</dd>
<dt><a name="PauseMenuButton"></a>PauseMenuButton(name)</dt>
<dd>Show pause menu button</dd>
<dt><a name="HasFile"></a>HasFile(path)</dt>
<dd>Check if file exists</dd>
<dt><a name="StartLevel"></a>StartLevel(path, [checkpoint])</dt>
<dd>Start level</dd>
<dt><a name="SetPaused"></a>SetPaused(paused)</dt>
<dd>Pause/unpause game</dd>
<dt><a name="Restart"></a>Restart()</dt>
<dd>Restart level</dd>
<dt><a name="Menu"></a>Menu()</dt>
<dd>Go to main menu</dd>
<dt><a name="ClearKey"></a>ClearKey(key)</dt>
<dd>Delete registry key</dd>
<dt><a name="ListKeys"></a>ListKeys(path)</dt>
<dd>List registry keys</dd>
<dt><a name="HasKey"></a>HasKey(key)</dt>
<dd>Check if registry key exists</dd>
<dt><a name="SetInt"></a>SetInt(key, value)</dt>
<dd>Set integer registry value</dd>
<dt><a name="GetInt"></a>GetInt(key)</dt>
<dd>Get integer registry value</dd>
<dt><a name="SetFloat"></a>SetFloat(key, value)</dt>
<dd>Set float registry value</dd>
<dt><a name="GetFloat"></a>GetFloat(key)</dt>
<dd>Get float registry value</dd>
<dt><a name="SetBool"></a>SetBool(key, value)</dt>
<dd>Set boolean registry value</dd>
<dt><a name="GetBool"></a>GetBool(key)</dt>
<dd>Get boolean registry value</dd>
<dt><a name="SetString"></a>SetString(key, value)</dt>
<dd>Set string registry value</dd>
<dt><a name="GetString"></a>GetString(key)</dt>
<dd>Get string registry value</dd>
<dt><a name="GetEventCount"></a>GetEventCount()</dt>
<dd>Get number of events</dd>
<dt><a name="GetEvent"></a>GetEvent(index)</dt>
<dd>Get event data</dd>
<dt><a name="SetColor"></a>SetColor(key, r, g, b, [a])</dt>
<dd>Set color registry value</dd>
<dt><a name="GetColor"></a>GetColor(key)</dt>
<dd>Get color registry value</dd>
<dt><a name="GetTranslatedStringByKey"></a>GetTranslatedStringByKey(key)</dt>
<dd>Get translated string</dd>
<dt><a name="HasTranslationByKey"></a>HasTranslationByKey(key)</dt>
<dd>Check if translation exists</dd>
<dt><a name="LoadLanguageTable"></a>LoadLanguageTable(path)</dt>
<dd>Load language table</dd>
<dt><a name="GetUserNickname"></a>GetUserNickname()</dt>
<dd>Get user nickname</dd>
<dt><a name="Vec"></a>Vec(x, y, z)</dt>
<dd>Create vector</dd>
<dt><a name="VecCopy"></a>VecCopy(v)</dt>
<dd>Copy vector</dd>
<dt><a name="VecStr"></a>VecStr(v)</dt>
<dd>Convert vector to string</dd>
<dt><a name="VecLength"></a>VecLength(v)</dt>
<dd>Get vector length</dd>
<dt><a name="VecNormalize"></a>VecNormalize(v)</dt>
<dd>Normalize vector</dd>
<dt><a name="VecScale"></a>VecScale(v, s)</dt>
<dd>Scale vector</dd>
<dt><a name="VecAdd"></a>VecAdd(a, b)</dt>
<dd>Add vectors</dd>
<dt><a name="VecSub"></a>VecSub(a, b)</dt>
<dd>Subtract vectors</dd>
<dt><a name="VecDot"></a>VecDot(a, b)</dt>
<dd>Dot product</dd>
<dt><a name="VecCross"></a>VecCross(a, b)</dt>
<dd>Cross product</dd>
<dt><a name="VecLerp"></a>VecLerp(a, b, t)</dt>
<dd>Linear interpolation</dd>
<dt><a name="Quat"></a>Quat(x, y, z, w)</dt>
<dd>Create quaternion</dd>
<dt><a name="QuatCopy"></a>QuatCopy(q)</dt>
<dd>Copy quaternion</dd>
<dt><a name="QuatAxisAngle"></a>QuatAxisAngle(axis, angle)</dt>
<dd>Create quaternion from axis and angle</dd>
<dt><a name="QuatDeltaNormals"></a>QuatDeltaNormals(n1, n2)</dt>
<dd>Create quaternion from normal vectors</dd>
<dt><a name="QuatDeltaVectors"></a>QuatDeltaVectors(v1, v2)</dt>
<dd>Create quaternion from vectors</dd>
<dt><a name="QuatEuler"></a>QuatEuler(x, y, z)</dt>
<dd>Create quaternion from Euler angles</dd>
<dt><a name="QuatAlignXZ"></a>QuatAlignXZ(x, z)</dt>
<dd>Align quaternion to XZ plane</dd>
<dt><a name="GetQuatEuler"></a>GetQuatEuler(q)</dt>
<dd>Get Euler angles from quaternion</dd>
<dt><a name="QuatLookAt"></a>QuatLookAt(eye, target, up)</dt>
<dd>Create look-at quaternion</dd>
<dt><a name="QuatSlerp"></a>QuatSlerp(a, b, t)</dt>
<dd>Spherical interpolation</dd>
<dt><a name="QuatStr"></a>QuatStr(q)</dt>
<dd>Convert quaternion to string</dd>
<dt><a name="QuatRotateQuat"></a>QuatRotateQuat(a, b)</dt>
<dd>Rotate quaternion by quaternion</dd>
<dt><a name="QuatRotateVec"></a>QuatRotateVec(q, v)</dt>
<dd>Rotate vector by quaternion</dd>
<dt><a name="Transform"></a>Transform(pos, rot)</dt>
<dd>Create transform</dd>
<dt><a name="TransformCopy"></a>TransformCopy(t)</dt>
<dd>Copy transform</dd>
<dt><a name="TransformStr"></a>TransformStr(t)</dt>
<dd>Convert transform to string</dd>
<dt><a name="TransformToParentTransform"></a>TransformToParentTransform(parent, child)</dt>
<dd>Convert transform to parent space</dd>
<dt><a name="TransformToLocalTransform"></a>TransformToLocalTransform(parent, child)</dt>
<dd>Convert transform to local space</dd>
<dt><a name="TransformToParentVec"></a>TransformToParentVec(t, v)</dt>
<dd>Transform vector to parent space</dd>
<dt><a name="TransformToLocalVec"></a>TransformToLocalVec(t, v)</dt>
<dd>Transform vector to local space</dd>
<dt><a name="TransformToParentPoint"></a>TransformToParentPoint(t, p)</dt>
<dd>Transform point to parent space</dd>
<dt><a name="TransformToLocalPoint"></a>TransformToLocalPoint(t, p)</dt>
<dd>Transform point to local space</dd>
<dt><a name="FindEntity"></a>FindEntity(name)</dt>
<dd>Find entity by name</dd>
<dt><a name="FindEntities"></a>FindEntities(name)</dt>
<dd>Find entities by name</dd>
<dt><a name="GetEntityChildren"></a>GetEntityChildren(entity)</dt>
<dd>Get entity children</dd>
<dt><a name="GetEntityParent"></a>GetEntityParent(entity)</dt>
<dd>Get entity parent</dd>
<dt><a name="SetTag"></a>SetTag(entity, tag, value)</dt>
<dd>Set entity tag</dd>
<dt><a name="RemoveTag"></a>RemoveTag(entity, tag)</dt>
<dd>Remove entity tag</dd>
<dt><a name="HasTag"></a>HasTag(entity, tag)</dt>
<dd>Check if entity has tag</dd>
<dt><a name="GetTagValue"></a>GetTagValue(entity, tag)</dt>
<dd>Get entity tag value</dd>
<dt><a name="ListTags"></a>ListTags(entity)</dt>
<dd>List entity tags</dd>
<dt><a name="GetDescription"></a>GetDescription(entity)</dt>
<dd>Get entity description</dd>
<dt><a name="SetDescription"></a>SetDescription(entity, desc)</dt>
<dd>Set entity description</dd>
<dt><a name="Delete"></a>Delete(handle)</dt>
<dd>Delete entity</dd>
<dt><a name="IsHandleValid"></a>IsHandleValid(handle)</dt>
<dd>Check if handle is valid</dd>
<dt><a name="GetEntityType"></a>GetEntityType(entity)</dt>
<dd>Get entity type</dd>
<dt><a name="GetProperty"></a>GetProperty(entity, property)</dt>
<dd>Get entity property</dd>
<dt><a name="SetProperty"></a>SetProperty(entity, property, value)</dt>
<dd>Set entity property</dd>
<dt><a name="FindBody"></a>FindBody(name)</dt>
<dd>Find body by name</dd>
<dt><a name="FindBodies"></a>FindBodies(name, includeBroken)</dt>
<dd>Find bodies by name</dd>
<dt><a name="GetBodyTransform"></a>GetBodyTransform(body)</dt>
<dd>Get body transform</dd>
<dt><a name="SetBodyTransform"></a>SetBodyTransform(body, transform)</dt>
<dd>Set body transform</dd>
<dt><a name="GetBodyMass"></a>GetBodyMass(body)</dt>
<dd>Get body mass</dd>
<dt><a name="IsBodyDynamic"></a>IsBodyDynamic(body)</dt>
<dd>Check if body is dynamic</dd>
<dt><a name="SetBodyDynamic"></a>SetBodyDynamic(body, dynamic)</dt>
<dd>Set body dynamic state</dd>
<dt><a name="SetBodyVelocity"></a>SetBodyVelocity(body, velocity)</dt>
<dd>Set body velocity</dd>
<dt><a name="GetBodyVelocity"></a>GetBodyVelocity(body)</dt>
<dd>Get body velocity</dd>
<dt><a name="GetBodyVelocityAtPos"></a>GetBodyVelocityAtPos(body, pos)</dt>
<dd>Get body velocity at position</dd>
<dt><a name="SetBodyAngularVelocity"></a>SetBodyAngularVelocity(body, velocity)</dt>
<dd>Set body angular velocity</dd>
<dt><a name="GetBodyAngularVelocity"></a>GetBodyAngularVelocity(body)</dt>
<dd>Get body angular velocity</dd>
<dt><a name="IsBodyActive"></a>IsBodyActive(body)</dt>
<dd>Check if body is active</dd>
<dt><a name="SetBodyActive"></a>SetBodyActive(body, active)</dt>
<dd>Set body active state</dd>
<dt><a name="ApplyBodyImpulse"></a>ApplyBodyImpulse(body, position, impulse)</dt>
<dd>Apply impulse to body</dd>
<dt><a name="GetBodyShapes"></a>GetBodyShapes(body)</dt>
<dd>Get body shapes</dd>
<dt><a name="GetBodyVehicle"></a>GetBodyVehicle(body)</dt>
<dd>Get body vehicle</dd>
<dt><a name="GetBodyBounds"></a>GetBodyBounds(body)</dt>
<dd>Get body bounds</dd>
<dt><a name="GetBodyCenterOfMass"></a>GetBodyCenterOfMass(body)</dt>
<dd>Get body center of mass</dd>
<dt><a name="IsBodyVisible"></a>IsBodyVisible(body)</dt>
<dd>Check if body is visible</dd>
<dt><a name="IsBodyBroken"></a>IsBodyBroken(body)</dt>
<dd>Check if body is broken</dd>
<dt><a name="DrawBodyOutline"></a>DrawBodyOutline(body, alpha)</dt>
<dd>Draw body outline</dd>
<dt><a name="DrawBodyHighlight"></a>DrawBodyHighlight(body, alpha)</dt>
<dd>Draw body highlight</dd>
<dt><a name="GetBodyClosestPoint"></a>GetBodyClosestPoint(body, point)</dt>
<dd>Get closest point on body</dd>
<dt><a name="ConstrainVelocity"></a>ConstrainVelocity(body, velocity, maxSpeed)</dt>
<dd>Constrain body velocity</dd>
<dt><a name="ConstrainAngularVelocity"></a>ConstrainAngularVelocity(body, velocity, maxSpeed)</dt>
<dd>Constrain body angular velocity</dd>
<dt><a name="ConstrainPosition"></a>ConstrainPosition(body, position, distance)</dt>
<dd>Constrain body position</dd>
<dt><a name="ConstrainOrientation"></a>ConstrainOrientation(body, orientation, maxAngle)</dt>
<dd>Constrain body orientation</dd>
<dt><a name="GetWorldBody"></a>GetWorldBody()</dt>
<dd>Get world body</dd>
<dt><a name="FindShape"></a>FindShape(name)</dt>
<dd>Find shape by name</dd>
<dt><a name="FindShapes"></a>FindShapes(name, includeBroken)</dt>
<dd>Find shapes by name</dd>
<dt><a name="GetShapeLocalTransform"></a>GetShapeLocalTransform(shape)</dt>
<dd>Get shape local transform</dd>
<dt><a name="SetShapeLocalTransform"></a>SetShapeLocalTransform(shape, transform)</dt>
<dd>Set shape local transform</dd>
<dt><a name="GetShapeWorldTransform"></a>GetShapeWorldTransform(shape)</dt>
<dd>Get shape world transform</dd>
<dt><a name="GetShapeBody"></a>GetShapeBody(shape)</dt>
<dd>Get shape body</dd>
<dt><a name="GetShapeJoints"></a>GetShapeJoints(shape)</dt>
<dd>Get shape joints</dd>
<dt><a name="GetShapeLights"></a>GetShapeLights(shape)</dt>
<dd>Get shape lights</dd>
<dt><a name="GetShapeBounds"></a>GetShapeBounds(shape)</dt>
<dd>Get shape bounds</dd>
<dt><a name="SetShapeEmissiveScale"></a>SetShapeEmissiveScale(shape, scale)</dt>
<dd>Set shape emissive scale</dd>
<dt><a name="SetShapeDensity"></a>SetShapeDensity(shape, density)</dt>
<dd>Set shape density</dd>
<dt><a name="GetShapeMaterialAtPosition"></a>GetShapeMaterialAtPosition(shape, pos)</dt>
<dd>Get material at position</dd>
<dt><a name="GetShapeMaterialAtIndex"></a>GetShapeMaterialAtIndex(shape, x, y, z)</dt>
<dd>Get material at index</dd>
<dt><a name="GetShapeSize"></a>GetShapeSize(shape)</dt>
<dd>Get shape size</dd>
<dt><a name="GetShapeVoxelCount"></a>GetShapeVoxelCount(shape)</dt>
<dd>Get shape voxel count</dd>
<dt><a name="IsShapeVisible"></a>IsShapeVisible(shape)</dt>
<dd>Check if shape is visible</dd>
<dt><a name="IsShapeBroken"></a>IsShapeBroken(shape)</dt>
<dd>Check if shape is broken</dd>
<dt><a name="DrawShapeOutline"></a>DrawShapeOutline(shape, r, g, b, a)</dt>
<dd>Draw shape outline</dd>
<dt><a name="DrawShapeHighlight"></a>DrawShapeHighlight(shape, r, g, b, a)</dt>
<dd>Draw shape highlight</dd>
<dt><a name="SetShapeCollisionFilter"></a>SetShapeCollisionFilter(shape, layer)</dt>
<dd>Set shape collision filter</dd>
<dt><a name="GetShapeCollisionFilter"></a>GetShapeCollisionFilter(shape)</dt>
<dd>Get shape collision filter</dd>
<dt><a name="CreateShape"></a>CreateShape(box, transform, density)</dt>
<dd>Create shape</dd>
<dt><a name="ClearShape"></a>ClearShape(shape)</dt>
<dd>Clear shape</dd>
<dt><a name="ResizeShape"></a>ResizeShape(shape, x, y, z)</dt>
<dd>Resize shape</dd>
<dt><a name="SetShapeBody"></a>SetShapeBody(shape, body)</dt>
<dd>Set shape body</dd>
<dt><a name="CopyShapeContent"></a>CopyShapeContent(shape, source)</dt>
<dd>Copy shape content</dd>
<dt><a name="CopyShapePalette"></a>CopyShapePalette(shape, source)</dt>
<dd>Copy shape palette</dd>
<dt><a name="GetShapePalette"></a>GetShapePalette(shape)</dt>
<dd>Get shape palette</dd>
<dt><a name="GetShapeMaterial"></a>GetShapeMaterial(shape)</dt>
<dd>Get shape material</dd>
<dt><a name="SetBrush"></a>SetBrush(type, size, color, alpha, emissive)</dt>
<dd>Set brush</dd>
<dt><a name="DrawShapeLine"></a>DrawShapeLine(shape, start, stop)</dt>
<dd>Draw line on shape</dd>
<dt><a name="DrawShapeBox"></a>DrawShapeBox(shape, min, max)</dt>
<dd>Draw box on shape</dd>
<dt><a name="ExtrudeShape"></a>ExtrudeShape(shape, depth)</dt>
<dd>Extrude shape</dd>
<dt><a name="TrimShape"></a>TrimShape(shape)</dt>
<dd>Trim shape</dd>
<dt><a name="SplitShape"></a>SplitShape(shape)</dt>
<dd>Split shape</dd>
<dt><a name="MergeShape"></a>MergeShape(shape, other)</dt>
<dd>Merge shapes</dd>
<dt><a name="IsShapeDisconnected"></a>IsShapeDisconnected(shape)</dt>
<dd>Check if shape is disconnected</dd>
<dt><a name="IsStaticShapeDetached"></a>IsStaticShapeDetached(shape)</dt>
<dd>Check if static shape is detached</dd>
<dt><a name="GetShapeClosestPoint"></a>GetShapeClosestPoint(shape, point)</dt>
<dd>Get closest point on shape</dd>
<dt><a name="IsShapeTouching"></a>IsShapeTouching(shape, other)</dt>
<dd>Check if shapes are touching</dd>
<dt><a name="FindLocation"></a>FindLocation(name)</dt>
<dd>Find location by name</dd>
<dt><a name="FindLocations"></a>FindLocations(name)</dt>
<dd>Find locations by name</dd>
<dt><a name="GetLocationTransform"></a>GetLocationTransform(location)</dt>
<dd>Get location transform</dd>
<dt><a name="FindJoint"></a>FindJoint(name)</dt>
<dd>Find joint by name</dd>
<dt><a name="FindJoints"></a>FindJoints(name)</dt>
<dd>Find joints by name</dd>
<dt><a name="IsJointBroken"></a>IsJointBroken(joint)</dt>
<dd>Check if joint is broken</dd>
<dt><a name="GetJointType"></a>GetJointType(joint)</dt>
<dd>Get joint type</dd>
<dt><a name="GetJointOtherShape"></a>GetJointOtherShape(joint, shape)</dt>
<dd>Get other shape in joint</dd>
<dt><a name="GetJointShapes"></a>GetJointShapes(joint)</dt>
<dd>Get joint shapes</dd>
<dt><a name="SetJointMotor"></a>SetJointMotor(joint, velocity, strength)</dt>
<dd>Set joint motor</dd>
<dt><a name="SetJointMotorTarget"></a>SetJointMotorTarget(joint, target)</dt>
<dd>Set joint motor target</dd>
<dt><a name="GetJointLimits"></a>GetJointLimits(joint)</dt>
<dd>Get joint limits</dd>
<dt><a name="GetJointMovement"></a>GetJointMovement(joint)</dt>
<dd>Get joint movement</dd>
<dt><a name="GetJointedBodies"></a>GetJointedBodies(joint)</dt>
<dd>Get jointed bodies</dd>
<dt><a name="DetachJointFromShape"></a>DetachJointFromShape(joint, shape)</dt>
<dd>Detach joint from shape</dd>
<dt><a name="GetRopeNumberOfPoints"></a>GetRopeNumberOfPoints(rope)</dt>
<dd>Get rope point count</dd>
<dt><a name="GetRopePointPosition"></a>GetRopePointPosition(rope, index)</dt>
<dd>Get rope point position</dd>
<dt><a name="GetRopeBounds"></a>GetRopeBounds(rope)</dt>
<dd>Get rope bounds</dd>
<dt><a name="BreakRope"></a>BreakRope(rope)</dt>
<dd>Break rope</dd>
<dt><a name="SetAnimatorPositionIK"></a>SetAnimatorPositionIK(animator, name, position)</dt>
<dd>Set animator IK position</dd>
<dt><a name="SetAnimatorTransformIK"></a>SetAnimatorTransformIK(animator, name, transform)</dt>
<dd>Set animator IK transform</dd>
<dt><a name="GetBoneChainLength"></a>GetBoneChainLength(animator, name)</dt>
<dd>Get bone chain length</dd>
<dt><a name="FindAnimator"></a>FindAnimator(name)</dt>
<dd>Find animator by name</dd>
<dt><a name="FindAnimators"></a>FindAnimators(name)</dt>
<dd>Find animators by name</dd>
<dt><a name="GetAnimatorTransform"></a>GetAnimatorTransform(animator)</dt>
<dd>Get animator transform</dd>
<dt><a name="GetAnimatorAdjustTransformIK"></a>GetAnimatorAdjustTransformIK(animator, name)</dt>
<dd>Get animator IK adjust transform</dd>
<dt><a name="SetAnimatorTransform"></a>SetAnimatorTransform(animator, transform)</dt>
<dd>Set animator transform</dd>
<dt><a name="MakeRagdoll"></a>MakeRagdoll(animator)</dt>
<dd>Make ragdoll</dd>
<dt><a name="UnRagdoll"></a>UnRagdoll(animator)</dt>
<dd>Unragdoll</dd>
<dt><a name="PlayAnimation"></a>PlayAnimation(animator, clip, loop, speed)</dt>
<dd>Play animation</dd>
<dt><a name="PlayAnimationLoop"></a>PlayAnimationLoop(animator, clip, speed)</dt>
<dd>Play animation loop</dd>
<dt><a name="PlayAnimationInstance"></a>PlayAnimationInstance(animator, clip, loop, speed)</dt>
<dd>Play animation instance</dd>
<dt><a name="StopAnimationInstance"></a>StopAnimationInstance(instance)</dt>
<dd>Stop animation instance</dd>
<dt><a name="PlayAnimationFrame"></a>PlayAnimationFrame(animator, clip, frame)</dt>
<dd>Play animation frame</dd>
<dt><a name="BeginAnimationGroup"></a>BeginAnimationGroup()</dt>
<dd>Begin animation group</dd>
<dt><a name="EndAnimationGroup"></a>EndAnimationGroup()</dt>
<dd>End animation group</dd>
<dt><a name="PlayAnimationInstances"></a>PlayAnimationInstances(animators, clips, loops, speeds)</dt>
<dd>Play animation instances</dd>
<dt><a name="GetAnimationClipNames"></a>GetAnimationClipNames(animator)</dt>
<dd>Get animation clip names</dd>
<dt><a name="GetAnimationClipDuration"></a>GetAnimationClipDuration(animator, clip)</dt>
<dd>Get animation clip duration</dd>
<dt><a name="SetAnimationClipFade"></a>SetAnimationClipFade(animator, clip, fade)</dt>
<dd>Set animation clip fade</dd>
<dt><a name="SetAnimationClipSpeed"></a>SetAnimationClipSpeed(animator, clip, speed)</dt>
<dd>Set animation clip speed</dd>
<dt><a name="TrimAnimationClip"></a>TrimAnimationClip(animator, clip, start, stop)</dt>
<dd>Trim animation clip</dd>
<dt><a name="GetAnimationClipLoopPosition"></a>GetAnimationClipLoopPosition(animator, clip)</dt>
<dd>Get animation clip loop position</dd>
<dt><a name="GetAnimationInstancePosition"></a>GetAnimationInstancePosition(instance)</dt>
<dd>Get animation instance position</dd>
<dt><a name="SetAnimationClipLoopPosition"></a>SetAnimationClipLoopPosition(animator, clip, position)</dt>
<dd>Set animation clip loop position</dd>
<dt><a name="SetBoneRotation"></a>SetBoneRotation(animator, bone, rotation)</dt>
<dd>Set bone rotation</dd>
<dt><a name="SetBoneLookAt"></a>SetBoneLookAt(animator, bone, target)</dt>
<dd>Set bone look at</dd>
<dt><a name="RotateBone"></a>RotateBone(animator, bone, rotation)</dt>
<dd>Rotate bone</dd>
<dt><a name="GetBoneNames"></a>GetBoneNames(animator)</dt>
<dd>Get bone names</dd>
<dt><a name="GetBoneBody"></a>GetBoneBody(animator, bone)</dt>
<dd>Get bone body</dd>
<dt><a name="GetBoneWorldTransform"></a>GetBoneWorldTransform(animator, bone)</dt>
<dd>Get bone world transform</dd>
<dt><a name="GetBoneBindPoseTransform"></a>GetBoneBindPoseTransform(animator, bone)</dt>
<dd>Get bone bind pose transform</dd>
<dt><a name="FindLight"></a>FindLight(name)</dt>
<dd>Find light by name</dd>
<dt><a name="FindLights"></a>FindLights(name)</dt>
<dd>Find lights by name</dd>
<dt><a name="SetLightEnabled"></a>SetLightEnabled(light, enabled)</dt>
<dd>Set light enabled</dd>
<dt><a name="SetLightColor"></a>SetLightColor(light, r, g, b)</dt>
<dd>Set light color</dd>
<dt><a name="SetLightIntensity"></a>SetLightIntensity(light, intensity)</dt>
<dd>Set light intensity</dd>
<dt><a name="GetLightTransform"></a>GetLightTransform(light)</dt>
<dd>Get light transform</dd>
<dt><a name="GetLightShape"></a>GetLightShape(light)</dt>
<dd>Get light shape</dd>
<dt><a name="IsLightActive"></a>IsLightActive(light)</dt>
<dd>Check if light is active</dd>
<dt><a name="IsPointAffectedByLight"></a>IsPointAffectedByLight(point, light)</dt>
<dd>Check if point is affected by light</dd>
<dt><a name="GetFlashlight"></a>GetFlashlight()</dt>
<dd>Get flashlight</dd>
<dt><a name="SetFlashlight"></a>SetFlashlight(light)</dt>
<dd>Set flashlight</dd>
<dt><a name="FindTrigger"></a>FindTrigger(name)</dt>
<dd>Find trigger by name</dd>
<dt><a name="FindTriggers"></a>FindTriggers(name)</dt>
<dd>Find triggers by name</dd>
<dt><a name="GetTriggerTransform"></a>GetTriggerTransform(trigger)</dt>
<dd>Get trigger transform</dd>
<dt><a name="SetTriggerTransform"></a>SetTriggerTransform(trigger, transform)</dt>
<dd>Set trigger transform</dd>
<dt><a name="GetTriggerBounds"></a>GetTriggerBounds(trigger)</dt>
<dd>Get trigger bounds</dd>
<dt><a name="IsBodyInTrigger"></a>IsBodyInTrigger(trigger, body)</dt>
<dd>Check if body is in trigger</dd>
<dt><a name="IsVehicleInTrigger"></a>IsVehicleInTrigger(trigger, vehicle)</dt>
<dd>Check if vehicle is in trigger</dd>
<dt><a name="IsShapeInTrigger"></a>IsShapeInTrigger(trigger, shape)</dt>
<dd>Check if shape is in trigger</dd>
<dt><a name="IsPointInTrigger"></a>IsPointInTrigger(trigger, point)</dt>
<dd>Check if point is in trigger</dd>
<dt><a name="IsPointInBoundaries"></a>IsPointInBoundaries(point, boundaries)</dt>
<dd>Check if point is in boundaries</dd>
<dt><a name="IsTriggerEmpty"></a>IsTriggerEmpty(trigger)</dt>
<dd>Check if trigger is empty</dd>
<dt><a name="GetTriggerDistance"></a>GetTriggerDistance(trigger, point)</dt>
<dd>Get trigger distance</dd>
<dt><a name="GetTriggerClosestPoint"></a>GetTriggerClosestPoint(trigger, point)</dt>
<dd>Get trigger closest point</dd>
<dt><a name="FindScreen"></a>FindScreen(name)</dt>
<dd>Find screen by name</dd>
<dt><a name="FindScreens"></a>FindScreens(name)</dt>
<dd>Find screens by name</dd>
<dt><a name="SetScreenEnabled"></a>SetScreenEnabled(screen, enabled)</dt>
<dd>Set screen enabled</dd>
<dt><a name="IsScreenEnabled"></a>IsScreenEnabled(screen)</dt>
<dd>Check if screen is enabled</dd>
<dt><a name="GetScreenShape"></a>GetScreenShape(screen)</dt>
<dd>Get screen shape</dd>
<dt><a name="FindVehicle"></a>FindVehicle(name)</dt>
<dd>Find vehicle by name</dd>
<dt><a name="FindVehicles"></a>FindVehicles(name)</dt>
<dd>Find vehicles by name</dd>
<dt><a name="GetVehicleTransform"></a>GetVehicleTransform(vehicle)</dt>
<dd>Get vehicle transform</dd>
<dt><a name="GetVehicleExhaustTransforms"></a>GetVehicleExhaustTransforms(vehicle)</dt>
<dd>Get vehicle exhaust transforms</dd>
<dt><a name="GetVehicleVitalTransforms"></a>GetVehicleVitalTransforms(vehicle)</dt>
<dd>Get vehicle vital transforms</dd>
<dt><a name="GetVehicleBodies"></a>GetVehicleBodies(vehicle)</dt>
<dd>Get vehicle bodies</dd>
<dt><a name="GetVehicleBody"></a>GetVehicleBody(vehicle)</dt>
<dd>Get vehicle body</dd>
<dt><a name="GetVehicleHealth"></a>GetVehicleHealth(vehicle)</dt>
<dd>Get vehicle health</dd>
<dt><a name="GetVehicleParams"></a>GetVehicleParams(vehicle)</dt>
<dd>Get vehicle params</dd>
<dt><a name="SetVehicleParam"></a>SetVehicleParam(vehicle, param, value)</dt>
<dd>Set vehicle param</dd>
<dt><a name="GetVehicleDriverPos"></a>GetVehicleDriverPos(vehicle)</dt>
<dd>Get vehicle driver position</dd>
<dt><a name="GetVehicleSteering"></a>GetVehicleSteering(vehicle)</dt>
<dd>Get vehicle steering</dd>
<dt><a name="GetVehicleDrive"></a>GetVehicleDrive(vehicle)</dt>
<dd>Get vehicle drive</dd>
<dt><a name="DriveVehicle"></a>DriveVehicle(vehicle, drive, steering, brake)</dt>
<dd>Drive vehicle</dd>
<dt><a name="GetPlayerPos"></a>GetPlayerPos()</dt>
<dd>Get player position</dd>
<dt><a name="GetPlayerAimInfo"></a>GetPlayerAimInfo()</dt>
<dd>Get player aim info</dd>
<dt><a name="GetPlayerPitch"></a>GetPlayerPitch()</dt>
<dd>Get player pitch</dd>
<dt><a name="GetPlayerYaw"></a>GetPlayerYaw()</dt>
<dd>Get player yaw</dd>
<dt><a name="SetPlayerPitch"></a>SetPlayerPitch(pitch)</dt>
<dd>Set player pitch</dd>
<dt><a name="GetPlayerCrouch"></a>GetPlayerCrouch()</dt>
<dd>Get player crouch</dd>
<dt><a name="GetPlayerTransform"></a>GetPlayerTransform()</dt>
<dd>Get player transform</dd>
<dt><a name="SetPlayerTransform"></a>SetPlayerTransform(transform)</dt>
<dd>Set player transform</dd>
<dt><a name="ClearPlayerRig"></a>ClearPlayerRig()</dt>
<dd>Clear player rig</dd>
<dt><a name="SetPlayerRigLocationLocalTransform"></a>SetPlayerRigLocationLocalTransform(location, transform)</dt>
<dd>Set player rig location local transform</dd>
<dt><a name="SetPlayerRigTransform"></a>SetPlayerRigTransform(transform)</dt>
<dd>Set player rig transform</dd>
<dt><a name="GetPlayerRigTransform"></a>GetPlayerRigTransform()</dt>
<dd>Get player rig transform</dd>
<dt><a name="GetPlayerRigLocationWorldTransform"></a>GetPlayerRigLocationWorldTransform(location)</dt>
<dd>Get player rig location world transform</dd>
<dt><a name="SetPlayerRigTags"></a>SetPlayerRigTags(tags)</dt>
<dd>Set player rig tags</dd>
<dt><a name="GetPlayerRigHasTag"></a>GetPlayerRigHasTag(tag)</dt>
<dd>Get player rig has tag</dd>
<dt><a name="GetPlayerRigTagValue"></a>GetPlayerRigTagValue(tag)</dt>
<dd>Get player rig tag value</dd>
<dt><a name="SetPlayerGroundVelocity"></a>SetPlayerGroundVelocity(velocity)</dt>
<dd>Set player ground velocity</dd>
<dt><a name="GetPlayerEyeTransform"></a>GetPlayerEyeTransform()</dt>
<dd>Get player eye transform</dd>
<dt><a name="GetPlayerCameraTransform"></a>GetPlayerCameraTransform()</dt>
<dd>Get player camera transform</dd>
<dt><a name="SetPlayerCameraOffsetTransform"></a>SetPlayerCameraOffsetTransform(transform)</dt>
<dd>Set player camera offset transform</dd>
<dt><a name="SetPlayerSpawnTransform"></a>SetPlayerSpawnTransform(transform)</dt>
<dd>Set player spawn transform</dd>
<dt><a name="SetPlayerSpawnHealth"></a>SetPlayerSpawnHealth(health)</dt>
<dd>Set player spawn health</dd>
<dt><a name="SetPlayerSpawnTool"></a>SetPlayerSpawnTool(tool)</dt>
<dd>Set player spawn tool</dd>
<dt><a name="GetPlayerVelocity"></a>GetPlayerVelocity()</dt>
<dd>Get player velocity</dd>
<dt><a name="SetPlayerVelocity"></a>SetPlayerVelocity(velocity)</dt>
<dd>Set player velocity</dd>
<dt><a name="GetPlayerVehicle"></a>GetPlayerVehicle()</dt>
<dd>Get player vehicle</dd>
<dt><a name="IsPlayerGrounded"></a>IsPlayerGrounded()</dt>
<dd>Check if player is grounded</dd>
<dt><a name="GetPlayerGroundContact"></a>GetPlayerGroundContact()</dt>
<dd>Get player ground contact</dd>
<dt><a name="GetPlayerGrabShape"></a>GetPlayerGrabShape()</dt>
<dd>Get player grab shape</dd>
<dt><a name="GetPlayerGrabBody"></a>GetPlayerGrabBody()</dt>
<dd>Get player grab body</dd>
<dt><a name="ReleasePlayerGrab"></a>ReleasePlayerGrab()</dt>
<dd>Release player grab</dd>
<dt><a name="GetPlayerGrabPoint"></a>GetPlayerGrabPoint()</dt>
<dd>Get player grab point</dd>
<dt><a name="GetPlayerPickShape"></a>GetPlayerPickShape()</dt>
<dd>Get player pick shape</dd>
<dt><a name="GetPlayerPickBody"></a>GetPlayerPickBody()</dt>
<dd>Get player pick body</dd>
<dt><a name="GetPlayerInteractShape"></a>GetPlayerInteractShape()</dt>
<dd>Get player interact shape</dd>
<dt><a name="GetPlayerInteractBody"></a>GetPlayerInteractBody()</dt>
<dd>Get player interact body</dd>
<dt><a name="SetPlayerScreen"></a>SetPlayerScreen(screen)</dt>
<dd>Set player screen</dd>
<dt><a name="GetPlayerScreen"></a>GetPlayerScreen()</dt>
<dd>Get player screen</dd>
<dt><a name="SetPlayerHealth"></a>SetPlayerHealth(health)</dt>
<dd>Set player health</dd>
<dt><a name="GetPlayerHealth"></a>GetPlayerHealth()</dt>
<dd>Get player health</dd>
<dt><a name="SetPlayerRegenerationState"></a>SetPlayerRegenerationState(state)</dt>
<dd>Set player regeneration state</dd>
<dt><a name="RespawnPlayer"></a>RespawnPlayer()</dt>
<dd>Respawn player</dd>
<dt><a name="GetPlayerWalkingSpeed"></a>GetPlayerWalkingSpeed()</dt>
<dd>Get player walking speed</dd>
<dt><a name="SetPlayerWalkingSpeed"></a>SetPlayerWalkingSpeed(speed)</dt>
<dd>Set player walking speed</dd>
<dt><a name="GetPlayerParam"></a>GetPlayerParam(param)</dt>
<dd>Get player param</dd>
<dt><a name="SetPlayerParam"></a>SetPlayerParam(param, value)</dt>
<dd>Set player param</dd>
<dt><a name="SetPlayerHidden"></a>SetPlayerHidden(hidden)</dt>
<dd>Set player hidden</dd>
<dt><a name="RegisterTool"></a>RegisterTool(id, name, path)</dt>
<dd>Register tool</dd>
<dt><a name="GetToolBody"></a>GetToolBody()</dt>
<dd>Get tool body</dd>
<dt><a name="GetToolHandPoseLocalTransform"></a>GetToolHandPoseLocalTransform()</dt>
<dd>Get tool hand pose local transform</dd>
<dt><a name="GetToolHandPoseWorldTransform"></a>GetToolHandPoseWorldTransform()</dt>
<dd>Get tool hand pose world transform</dd>
<dt><a name="SetToolHandPoseLocalTransform"></a>SetToolHandPoseLocalTransform(transform)</dt>
<dd>Set tool hand pose local transform</dd>
<dt><a name="GetToolLocationLocalTransform"></a>GetToolLocationLocalTransform()</dt>
<dd>Get tool location local transform</dd>
<dt><a name="GetToolLocationWorldTransform"></a>GetToolLocationWorldTransform()</dt>
<dd>Get tool location world transform</dd>
<dt><a name="SetToolTransform"></a>SetToolTransform(transform)</dt>
<dd>Set tool transform</dd>
<dt><a name="SetToolAllowedZoom"></a>SetToolAllowedZoom(zoom)</dt>
<dd>Set tool allowed zoom</dd>
<dt><a name="SetToolTransformOverride"></a>SetToolTransformOverride(transform)</dt>
<dd>Set tool transform override</dd>
<dt><a name="SetToolOffset"></a>SetToolOffset(offset)</dt>
<dd>Set tool offset</dd>
<dt><a name="LoadSound"></a>LoadSound(path)</dt>
<dd>Load sound</dd>
<dt><a name="UnloadSound"></a>UnloadSound(sound)</dt>
<dd>Unload sound</dd>
<dt><a name="LoadLoop"></a>LoadLoop(path)</dt>
<dd>Load loop</dd>
<dt><a name="UnloadLoop"></a>UnloadLoop(loop)</dt>
<dd>Unload loop</dd>
<dt><a name="SetSoundLoopUser"></a>SetSoundLoopUser(loop, user)</dt>
<dd>Set sound loop user</dd>
<dt><a name="PlaySound"></a>PlaySound(sound, pos, volume)</dt>
<dd>Play sound</dd>
<dt><a name="StopSound"></a>StopSound(sound)</dt>
<dd>Stop sound</dd>
<dt><a name="IsSoundPlaying"></a>IsSoundPlaying(sound)</dt>
<dd>Check if sound is playing</dd>
<dt><a name="GetSoundProgress"></a>GetSoundProgress(sound)</dt>
<dd>Get sound progress</dd>
<dt><a name="SetSoundProgress"></a>SetSoundProgress(sound, progress)</dt>
<dd>Set sound progress</dd>
<dt><a name="PlayLoop"></a>PlayLoop(loop, pos, volume)</dt>
<dd>Play loop</dd>
<dt><a name="GetSoundLoopProgress"></a>GetSoundLoopProgress(loop)</dt>
<dd>Get sound loop progress</dd>
<dt><a name="SetSoundLoopProgress"></a>SetSoundLoopProgress(loop, progress)</dt>
<dd>Set sound loop progress</dd>
<dt><a name="PlayMusic"></a>PlayMusic(path)</dt>
<dd>Play music</dd>
<dt><a name="StopMusic"></a>StopMusic()</dt>
<dd>Stop music</dd>
<dt><a name="IsMusicPlaying"></a>IsMusicPlaying()</dt>
<dd>Check if music is playing</dd>
<dt><a name="SetMusicPaused"></a>SetMusicPaused(paused)</dt>
<dd>Set music paused</dd>
<dt><a name="GetMusicProgress"></a>GetMusicProgress()</dt>
<dd>Get music progress</dd>
<dt><a name="SetMusicProgress"></a>SetMusicProgress(progress)</dt>
<dd>Set music progress</dd>
<dt><a name="SetMusicVolume"></a>SetMusicVolume(volume)</dt>
<dd>Set music volume</dd>
<dt><a name="SetMusicLowPass"></a>SetMusicLowPass(lowpass)</dt>
<dd>Set music low pass</dd>
<dt><a name="LoadSprite"></a>LoadSprite(path)</dt>
<dd>Load sprite</dd>
<dt><a name="DrawSprite"></a>DrawSprite(pos, size, r, g, b, a)</dt>
<dd>Draw sprite</dd>
<dt><a name="QueryRequire"></a>QueryRequire(path)</dt>
<dd>Query require</dd>
<dt><a name="QueryInclude"></a>QueryInclude(path)</dt>
<dd>Query include</dd>
<dt><a name="QueryRejectAnimator"></a>QueryRejectAnimator()</dt>
<dd>Query reject animator</dd>
<dt><a name="QueryRejectVehicle"></a>QueryRejectVehicle()</dt>
<dd>Query reject vehicle</dd>
<dt><a name="QueryRejectBody"></a>QueryRejectBody()</dt>
<dd>Query reject body</dd>
<dt><a name="QueryRejectBodies"></a>QueryRejectBodies()</dt>
<dd>Query reject bodies</dd>
<dt><a name="QueryRejectShape"></a>QueryRejectShape()</dt>
<dd>Query reject shape</dd>
<dt><a name="QueryRejectShapes"></a>QueryRejectShapes()</dt>
<dd>Query reject shapes</dd>
<dt><a name="QueryRaycast"></a>QueryRaycast(origin, direction, maxDist)</dt>
<dd>Query raycast</dd>
<dt><a name="QueryRaycastRope"></a>QueryRaycastRope(origin, direction, maxDist)</dt>
<dd>Query raycast rope</dd>
<dt><a name="QueryClosestPoint"></a>QueryClosestPoint(origin, maxDist)</dt>
<dd>Query closest point</dd>
<dt><a name="QueryAabbShapes"></a>QueryAabbShapes(min, max)</dt>
<dd>Query AABB shapes</dd>
<dt><a name="QueryAabbBodies"></a>QueryAabbBodies(min, max)</dt>
<dd>Query AABB bodies</dd>
<dt><a name="QueryPath"></a>QueryPath(start, goal, maxDist)</dt>
<dd>Query path</dd>
<dt><a name="CreatePathPlanner"></a>CreatePathPlanner()</dt>
<dd>Create path planner</dd>
<dt><a name="DeletePathPlanner"></a>DeletePathPlanner(planner)</dt>
<dd>Delete path planner</dd>
<dt><a name="PathPlannerQuery"></a>PathPlannerQuery(planner, start, goal, maxDist)</dt>
<dd>Path planner query</dd>
<dt><a name="AbortPath"></a>AbortPath()</dt>
<dd>Abort path</dd>
<dt><a name="GetPathState"></a>GetPathState()</dt>
<dd>Get path state</dd>
<dt><a name="GetPathLength"></a>GetPathLength()</dt>
<dd>Get path length</dd>
<dt><a name="GetPathPoint"></a>GetPathPoint(index)</dt>
<dd>Get path point</dd>
<dt><a name="GetLastSound"></a>GetLastSound()</dt>
<dd>Get last sound</dd>
<dt><a name="IsPointInWater"></a>IsPointInWater(point)</dt>
<dd>Check if point is in water</dd>
<dt><a name="GetWindVelocity"></a>GetWindVelocity(point)</dt>
<dd>Get wind velocity</dd>
<dt><a name="ParticleReset"></a>ParticleReset()</dt>
<dd>Particle reset</dd>
<dt><a name="ParticleType"></a>ParticleType(type)</dt>
<dd>Particle type</dd>
<dt><a name="ParticleTile"></a>ParticleTile(tile)</dt>
<dd>Particle tile</dd>
<dt><a name="ParticleColor"></a>ParticleColor(r, g, b, a)</dt>
<dd>Particle color</dd>
<dt><a name="ParticleRadius"></a>ParticleRadius(radius)</dt>
<dd>Particle radius</dd>
<dt><a name="ParticleAlpha"></a>ParticleAlpha(alpha)</dt>
<dd>Particle alpha</dd>
<dt><a name="ParticleGravity"></a>ParticleGravity(gravity)</dt>
<dd>Particle gravity</dd>
<dt><a name="ParticleDrag"></a>ParticleDrag(drag)</dt>
<dd>Particle drag</dd>
<dt><a name="ParticleEmissive"></a>ParticleEmissive(emissive)</dt>
<dd>Particle emissive</dd>
<dt><a name="ParticleRotation"></a>ParticleRotation(rotation)</dt>
<dd>Particle rotation</dd>
<dt><a name="ParticleStretch"></a>ParticleStretch(stretch)</dt>
<dd>Particle stretch</dd>
<dt><a name="ParticleSticky"></a>ParticleSticky(sticky)</dt>
<dd>Particle sticky</dd>
<dt><a name="ParticleCollide"></a>ParticleCollide(collide)</dt>
<dd>Particle collide</dd>
<dt><a name="ParticleFlags"></a>ParticleFlags(flags)</dt>
<dd>Particle flags</dd>
<dt><a name="SpawnParticle"></a>SpawnParticle(pos, velocity, lifetime)</dt>
<dd>Spawn particle</dd>
<dt><a name="Spawn"></a>Spawn(name, transform)</dt>
<dd>Spawn</dd>
<dt><a name="SpawnLayer"></a>SpawnLayer(name, transform)</dt>
<dd>Spawn layer</dd>
<dt><a name="Shoot"></a>Shoot(pos, dir, type, strength)</dt>
<dd>Shoot</dd>
<dt><a name="Paint"></a>Paint(pos, r, g, b, a)</dt>
<dd>Paint</dd>
<dt><a name="PaintRGBA"></a>PaintRGBA(pos, rgba)</dt>
<dd>Paint RGBA</dd>
<dt><a name="MakeHole"></a>MakeHole(pos, r, strength)</dt>
<dd>Make hole</dd>
<dt><a name="Explosion"></a>Explosion(pos, size)</dt>
<dd>Explosion</dd>
<dt><a name="SpawnFire"></a>SpawnFire(pos)</dt>
<dd>Spawn fire</dd>
<dt><a name="GetFireCount"></a>GetFireCount()</dt>
<dd>Get fire count</dd>
<dt><a name="QueryClosestFire"></a>QueryClosestFire(pos, maxDist)</dt>
<dd>Query closest fire</dd>
<dt><a name="QueryAabbFireCount"></a>QueryAabbFireCount(min, max)</dt>
<dd>Query AABB fire count</dd>
<dt><a name="RemoveAabbFires"></a>RemoveAabbFires(min, max)</dt>
<dd>Remove AABB fires</dd>
<dt><a name="GetCameraTransform"></a>GetCameraTransform()</dt>
<dd>Get camera transform</dd>
<dt><a name="SetCameraTransform"></a>SetCameraTransform(transform)</dt>
<dd>Set camera transform</dd>
<dt><a name="RequestFirstPerson"></a>RequestFirstPerson()</dt>
<dd>Request first person</dd>
<dt><a name="RequestThirdPerson"></a>RequestThirdPerson()</dt>
<dd>Request third person</dd>
<dt><a name="SetCameraOffsetTransform"></a>SetCameraOffsetTransform(transform)</dt>
<dd>Set camera offset transform</dd>
<dt><a name="AttachCameraTo"></a>AttachCameraTo(entity)</dt>
<dd>Attach camera to</dd>
<dt><a name="SetPivotClipBody"></a>SetPivotClipBody(body)</dt>
<dd>Set pivot clip body</dd>
<dt><a name="ShakeCamera"></a>ShakeCamera(amount)</dt>
<dd>Shake camera</dd>
<dt><a name="SetCameraFov"></a>SetCameraFov(fov)</dt>
<dd>Set camera FOV</dd>
<dt><a name="SetCameraDof"></a>SetCameraDof(distance, amount)</dt>
<dd>Set camera DOF</dd>
<dt><a name="PointLight"></a>PointLight(pos, r, g, b)</dt>
<dd>Point light</dd>
<dt><a name="SetTimeScale"></a>SetTimeScale(scale)</dt>
<dd>Set time scale</dd>
<dt><a name="SetEnvironmentDefault"></a>SetEnvironmentDefault()</dt>
<dd>Set environment default</dd>
<dt><a name="SetEnvironmentProperty"></a>SetEnvironmentProperty(name, value)</dt>
<dd>Set environment property</dd>
<dt><a name="GetEnvironmentProperty"></a>GetEnvironmentProperty(name)</dt>
<dd>Get environment property</dd>
<dt><a name="SetPostProcessingDefault"></a>SetPostProcessingDefault()</dt>
<dd>Set post processing default</dd>
<dt><a name="SetPostProcessingProperty"></a>SetPostProcessingProperty(name, value)</dt>
<dd>Set post processing property</dd>
<dt><a name="GetPostProcessingProperty"></a>GetPostProcessingProperty(name)</dt>
<dd>Get post processing property</dd>
<dt><a name="DrawLine"></a>DrawLine(pos1, pos2, r, g, b, a)</dt>
<dd>Draw line</dd>
<dt><a name="DebugLine"></a>DebugLine(pos1, pos2, r, g, b, a)</dt>
<dd>Debug line</dd>
<dt><a name="DebugCross"></a>DebugCross(pos, size, r, g, b, a)</dt>
<dd>Debug cross</dd>
<dt><a name="DebugTransform"></a>DebugTransform(transform, size)</dt>
<dd>Debug transform</dd>
<dt><a name="DebugWatch"></a>DebugWatch(name, value)</dt>
<dd>Debug watch</dd>
<dt><a name="DebugPrint"></a>DebugPrint(text)</dt>
<dd>Debug print</dd>
<dt><a name="RegisterListenerTo"></a>RegisterListenerTo(event, entity)</dt>
<dd>Register listener to</dd>
<dt><a name="UnregisterListener"></a>UnregisterListener(listener)</dt>
<dd>Unregister listener</dd>
<dt><a name="TriggerEvent"></a>TriggerEvent(event, entity)</dt>
<dd>Trigger event</dd>
<dt><a name="LoadHaptic"></a>LoadHaptic(path)</dt>
<dd>Load haptic</dd>
<dt><a name="CreateHaptic"></a>CreateHaptic(name)</dt>
<dd>Create haptic</dd>
<dt><a name="PlayHaptic"></a>PlayHaptic(haptic, intensity)</dt>
<dd>Play haptic</dd>
<dt><a name="PlayHapticDirectional"></a>PlayHapticDirectional(haptic, direction, intensity)</dt>
<dd>Play haptic directional</dd>
<dt><a name="HapticIsPlaying"></a>HapticIsPlaying(haptic)</dt>
<dd>Haptic is playing</dd>
<dt><a name="SetToolHaptic"></a>SetToolHaptic(haptic)</dt>
<dd>Set tool haptic</dd>
<dt><a name="StopHaptic"></a>StopHaptic(haptic)</dt>
<dd>Stop haptic</dd>
<dt><a name="SetVehicleHealth"></a>SetVehicleHealth(vehicle, health)</dt>
<dd>Set vehicle health</dd>
<dt><a name="QueryRaycastWater"></a>QueryRaycastWater(origin, direction, maxDist)</dt>
<dd>Query raycast water</dd>
<dt><a name="AddHeat"></a>AddHeat(pos, amount)</dt>
<dd>Add heat</dd>
<dt><a name="GetGravity"></a>GetGravity()</dt>
<dd>Get gravity</dd>
<dt><a name="SetGravity"></a>SetGravity(gravity)</dt>
<dd>Set gravity</dd>
<dt><a name="SetPlayerOrientation"></a>SetPlayerOrientation(orientation)</dt>
<dd>Set player orientation</dd>
<dt><a name="GetPlayerOrientation"></a>GetPlayerOrientation()</dt>
<dd>Get player orientation</dd>
<dt><a name="GetPlayerUp"></a>GetPlayerUp()</dt>
<dd>Get player up</dd>
<dt><a name="GetFps"></a>GetFps()</dt>
<dd>Get FPS</dd>
<dt><a name="UiMakeInteractive"></a>UiMakeInteractive()</dt>
<dd>UI make interactive</dd>
<dt><a name="UiPush"></a>UiPush()</dt>
<dd>UI push</dd>
<dt><a name="UiPop"></a>UiPop()</dt>
<dd>UI pop</dd>
<dt><a name="UiWidth"></a>UiWidth()</dt>
<dd>UI width</dd>
<dt><a name="UiHeight"></a>UiHeight()</dt>
<dd>UI height</dd>
<dt><a name="UiCenter"></a>UiCenter()</dt>
<dd>UI center</dd>
<dt><a name="UiMiddle"></a>UiMiddle()</dt>
<dd>UI middle</dd>
<dt><a name="UiColor"></a>UiColor(r, g, b, a)</dt>
<dd>UI color</dd>
<dt><a name="UiColorFilter"></a>UiColorFilter(r, g, b, a)</dt>
<dd>UI color filter</dd>
<dt><a name="UiResetColor"></a>UiResetColor()</dt>
<dd>UI reset color</dd>
<dt><a name="UiTranslate"></a>UiTranslate(x, y)</dt>
<dd>UI translate</dd>
<dt><a name="UiRotate"></a>UiRotate(angle)</dt>
<dd>UI rotate</dd>
<dt><a name="UiScale"></a>UiScale(scale)</dt>
<dd>UI scale</dd>
<dt><a name="UiGetScale"></a>UiGetScale()</dt>
<dd>UI get scale</dd>
<dt><a name="UiClipRect"></a>UiClipRect(x, y, w, h)</dt>
<dd>UI clip rect</dd>
<dt><a name="UiWindow"></a>UiWindow(id, x, y, w, h)</dt>
<dd>UI window</dd>
<dt><a name="UiGetCurrentWindow"></a>UiGetCurrentWindow()</dt>
<dd>UI get current window</dd>
<dt><a name="UiIsInCurrentWindow"></a>UiIsInCurrentWindow(x, y)</dt>
<dd>UI is in current window</dd>
<dt><a name="UiIsRectFullyClipped"></a>UiIsRectFullyClipped(x, y, w, h)</dt>
<dd>UI is rect fully clipped</dd>
<dt><a name="UiIsInClipRegion"></a>UiIsInClipRegion(x, y)</dt>
<dd>UI is in clip region</dd>
<dt><a name="UiIsFullyClipped"></a>UiIsFullyClipped()</dt>
<dd>UI is fully clipped</dd>
<dt><a name="UiSafeMargins"></a>UiSafeMargins()</dt>
<dd>UI safe margins</dd>
<dt><a name="UiCanvasSize"></a>UiCanvasSize()</dt>
<dd>UI canvas size</dd>
<dt><a name="UiAlign"></a>UiAlign(align)</dt>
<dd>UI align</dd>
<dt><a name="UiTextAlignment"></a>UiTextAlignment(align)</dt>
<dd>UI text alignment</dd>
<dt><a name="UiModalBegin"></a>UiModalBegin()</dt>
<dd>UI modal begin</dd>
<dt><a name="UiModalEnd"></a>UiModalEnd()</dt>
<dd>UI modal end</dd>
<dt><a name="UiDisableInput"></a>UiDisableInput()</dt>
<dd>UI disable input</dd>
<dt><a name="UiEnableInput"></a>UiEnableInput()</dt>
<dd>UI enable input</dd>
<dt><a name="UiReceivesInput"></a>UiReceivesInput()</dt>
<dd>UI receives input</dd>
<dt><a name="UiGetMousePos"></a>UiGetMousePos()</dt>
<dd>UI get mouse pos</dd>
<dt><a name="UiGetCanvasMousePos"></a>UiGetCanvasMousePos()</dt>
<dd>UI get canvas mouse pos</dd>
<dt><a name="UiIsMouseInRect"></a>UiIsMouseInRect(x, y, w, h)</dt>
<dd>UI is mouse in rect</dd>
<dt><a name="UiWorldToPixel"></a>UiWorldToPixel(worldPos)</dt>
<dd>UI world to pixel</dd>
<dt><a name="UiPixelToWorld"></a>UiPixelToWorld(pixelPos)</dt>
<dd>UI pixel to world</dd>
<dt><a name="UiGetCursorPos"></a>UiGetCursorPos()</dt>
<dd>UI get cursor pos</dd>
<dt><a name="UiBlur"></a>UiBlur(amount)</dt>
<dd>UI blur</dd>
<dt><a name="UiFont"></a>UiFont(path, size)</dt>
<dd>UI font</dd>
<dt><a name="UiFontHeight"></a>UiFontHeight()</dt>
<dd>UI font height</dd>
<dt><a name="UiText"></a>UiText(text)</dt>
<dd>UI text</dd>
<dt><a name="UiTextDisableWildcards"></a>UiTextDisableWildcards()</dt>
<dd>UI text disable wildcards</dd>
<dt><a name="UiTextUniformHeight"></a>UiTextUniformHeight(enabled)</dt>
<dd>UI text uniform height</dd>
<dt><a name="UiTextLineSpacing"></a>UiTextLineSpacing(spacing)</dt>
<dd>UI text line spacing</dd>
<dt><a name="UiTextOutline"></a>UiTextOutline(r, g, b, a)</dt>
<dd>UI text outline</dd>
<dt><a name="UiTextShadow"></a>UiTextShadow(r, g, b, a)</dt>
<dd>UI text shadow</dd>
<dt><a name="UiRect"></a>UiRect(w, h)</dt>
<dd>UI rect</dd>
<dt><a name="UiRectOutline"></a>UiRectOutline(w, h, thickness)</dt>
<dd>UI rect outline</dd>
<dt><a name="UiRoundedRect"></a>UiRoundedRect(w, h, radius)</dt>
<dd>UI rounded rect</dd>
<dt><a name="UiRoundedRectOutline"></a>UiRoundedRectOutline(w, h, radius, thickness)</dt>
<dd>UI rounded rect outline</dd>
<dt><a name="UiCircle"></a>UiCircle(radius)</dt>
<dd>UI circle</dd>
<dt><a name="UiCircleOutline"></a>UiCircleOutline(radius, thickness)</dt>
<dd>UI circle outline</dd>
<dt><a name="UiFillImage"></a>UiFillImage(image)</dt>
<dd>UI fill image</dd>
<dt><a name="UiImage"></a>UiImage(image)</dt>
<dd>UI image</dd>
<dt><a name="UiUnloadImage"></a>UiUnloadImage(image)</dt>
<dd>UI unload image</dd>
<dt><a name="UiHasImage"></a>UiHasImage(path)</dt>
<dd>UI has image</dd>
<dt><a name="UiGetImageSize"></a>UiGetImageSize(image)</dt>
<dd>UI get image size</dd>
<dt><a name="UiImageBox"></a>UiImageBox(image, w, h, border)</dt>
<dd>UI image box</dd>
<dt><a name="UiSound"></a>UiSound(path)</dt>
<dd>UI sound</dd>
<dt><a name="UiSoundLoop"></a>UiSoundLoop(path)</dt>
<dd>UI sound loop</dd>
<dt><a name="UiMute"></a>UiMute(muted)</dt>
<dd>UI mute</dd>
<dt><a name="UiButtonImageBox"></a>UiButtonImageBox(image, w, h, border)</dt>
<dd>UI button image box</dd>
<dt><a name="UiButtonHoverColor"></a>UiButtonHoverColor(r, g, b, a)</dt>
<dd>UI button hover color</dd>
<dt><a name="UiButtonPressColor"></a>UiButtonPressColor(r, g, b, a)</dt>
<dd>UI button press color</dd>
<dt><a name="UiButtonPressDist"></a>UiButtonPressDist(dist)</dt>
<dd>UI button press dist</dd>
<dt><a name="UiButtonTextHandling"></a>UiButtonTextHandling(handling)</dt>
<dd>UI button text handling</dd>
<dt><a name="UiTextButton"></a>UiTextButton(text, w, h)</dt>
<dd>UI text button</dd>
<dt><a name="UiImageButton"></a>UiImageButton(image, w, h)</dt>
<dd>UI image button</dd>
<dt><a name="UiBlankButton"></a>UiBlankButton(w, h)</dt>
<dd>UI blank button</dd>
<dt><a name="UiSlider"></a>UiSlider(value, min, max, w, h)</dt>
<dd>UI slider</dd>
<dt><a name="UiSliderHoverColorFilter"></a>UiSliderHoverColorFilter(r, g, b, a)</dt>
<dd>UI slider hover color filter</dd>
<dt><a name="UiSliderThumbSize"></a>UiSliderThumbSize(size)</dt>
<dd>UI slider thumb size</dd>
<dt><a name="UiGetScreen"></a>UiGetScreen()</dt>
<dd>UI get screen</dd>
<dt><a name="UiNavComponent"></a>UiNavComponent(id)</dt>
<dd>UI nav component</dd>
<dt><a name="UiIgnoreNavigation"></a>UiIgnoreNavigation()</dt>
<dd>UI ignore navigation</dd>
<dt><a name="UiResetNavigation"></a>UiResetNavigation()</dt>
<dd>UI reset navigation</dd>
<dt><a name="UiNavSkipUpdate"></a>UiNavSkipUpdate()</dt>
<dd>UI nav skip update</dd>
<dt><a name="UiIsComponentInFocus"></a>UiIsComponentInFocus(id)</dt>
<dd>UI is component in focus</dd>
<dt><a name="UiNavGroupBegin"></a>UiNavGroupBegin()</dt>
<dd>UI nav group begin</dd>
<dt><a name="UiNavGroupEnd"></a>UiNavGroupEnd()</dt>
<dd>UI nav group end</dd>
<dt><a name="UiNavGroupSize"></a>UiNavGroupSize()</dt>
<dd>UI nav group size</dd>
<dt><a name="UiForceFocus"></a>UiForceFocus(id)</dt>
<dd>UI force focus</dd>
<dt><a name="UiFocusedComponentId"></a>UiFocusedComponentId()</dt>
<dd>UI focused component id</dd>
<dt><a name="UiFocusedComponentRect"></a>UiFocusedComponentRect()</dt>
<dd>UI focused component rect</dd>
<dt><a name="UiGetItemSize"></a>UiGetItemSize()</dt>
<dd>UI get item size</dd>
<dt><a name="UiAutoTranslate"></a>UiAutoTranslate(enabled)</dt>
<dd>UI auto translate</dd>
<dt><a name="UiBeginFrame"></a>UiBeginFrame()</dt>
<dd>UI begin frame</dd>
<dt><a name="UiResetFrame"></a>UiResetFrame()</dt>
<dd>UI reset frame</dd>
<dt><a name="UiFrameOccupy"></a>UiFrameOccupy(x, y, w, h)</dt>
<dd>UI frame occupy</dd>
<dt><a name="UiEndFrame"></a>UiEndFrame()</dt>
<dd>UI end frame</dd>
<dt><a name="UiFrameSkipItem"></a>UiFrameSkipItem()</dt>
<dd>UI frame skip item</dd>
<dt><a name="UiGetFrameNo"></a>UiGetFrameNo()</dt>
<dd>UI get frame no</dd>
<dt><a name="UiGetLanguage"></a>UiGetLanguage()</dt>
<dd>UI get language</dd>
<dt><a name="UiSetCursorState"></a>UiSetCursorState(state)</dt>
<dd>UI set cursor state</dd>
<dt><a name="UiMeasureText"></a>UiMeasureText(text)</dt>
<dd>UI measure text</dd>
<dt><a name="UiGetTextWidth"></a>UiGetTextWidth(text)</dt>
<dd>UI get text width</dd>
<dt><a name="UiGetSymbolsCount"></a>UiGetSymbolsCount(text)</dt>
<dd>UI get symbols count</dd>
<dt><a name="UiTextSymbolsSub"></a>UiTextSymbolsSub(text, start, count)</dt>
<dd>UI text symbols sub</dd>
<dt><a name="UiWordWrap"></a>UiWordWrap(text, width)</dt>
<dd>UI word wrap</dd>
<dt><a name="JsonEncode"></a>JsonEncode(data)</dt>
<dd>JSON encode</dd>
<dt><a name="JsonDecode"></a>JsonDecode(json)</dt>
<dd>JSON decode</dd>
</dl>
    ]]
    
    -- Parse HTML for function signatures
    for funcName, params in htmlApi:gmatch('<dt><a name="([^"]*)"></a>([^<]*)</dt>') do
        table.insert(console.apiFunctions, funcName)
        console.apiSignatures[funcName] = params
    end
    
    -- Parse XML for additional function names (fallback)
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
    
    -- Add any functions from XML that weren't in HTML
    for func in apiXml:gmatch('<function name="([^"]*)"') do
        if not has_value(console.apiFunctions, func) then
            table.insert(console.apiFunctions, func)
            if not console.apiSignatures[func] then
                console.apiSignatures[func] = func .. "()" -- Basic signature if no HTML data
            end
        end
    end
end

-- Execute a command entered in the console
function executeCommand(cmd)
    if cmd == "" then return end

    -- Ensure cmd is a string
    if type(cmd) ~= "string" then
        cmd = tostring(cmd or "")
    end

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
    elseif command == "dump" then
        dumpSelectedObject()
    elseif command == "exec" then
        executeOnSelectedObject(table.concat(parts, " ", 2))
    elseif command == "script" then
        handleScriptCommand(parts)
    elseif command == "inspect" then
        inspectSelectedObject(table.concat(parts, " ", 2))
    elseif command == "hierarchy" then
        showObjectHierarchy(table.concat(parts, " ", 2))
    elseif command == "diff" then
        diffObjectProperties(table.concat(parts, " ", 2))
    elseif command == "highlight" then
        highlightSelectedObject(table.concat(parts, " ", 2))
    elseif command == "search" then
        searchAPI(table.concat(parts, " ", 2))
    elseif command == "find" then
        findObjects(table.concat(parts, " ", 2))
    elseif command == "physics" then
        handlePhysicsCommand(table.concat(parts, " ", 2))
    elseif command == "shortcuts" then
        handleShortcutsCommand(table.concat(parts, " ", 2))
    elseif command == "font" then
        handleFontCommand(table.concat(parts, " ", 2))
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
    addLog("INFO", "dump - Show debug info about selected object")
    addLog("INFO", "exec <code> - Execute Lua code on selected object")
    addLog("INFO", "inspect [level] - Inspect selected object (basic/detailed/full)")
    addLog("INFO", "hierarchy - Show object hierarchy and connections")
    addLog("INFO", "diff <snapshot|compare|clear> - Compare object properties over time")
    addLog("INFO", "highlight <outline|highlight|glow|clear> - Visual debugging tools")
    addLog("INFO", "search <query> [category] - Search Teardown API functions")
    addLog("INFO", "find <type> [filters] - Find objects by type and properties")
    addLog("INFO", "physics <forces|collisions|performance|gravity|reset> - Physics debugging tools")
    addLog("INFO", "shortcuts <list|set|remove|reset> - Manage keyboard shortcuts")
    addLog("INFO", "font <size|list|set|current|reset> - Customize font settings")
    addLog("INFO", "script save <name> <code> - Save a script")
    addLog("INFO", "script load <name> - Load a script into input")
    addLog("INFO", "script list - List saved scripts")
    addLog("INFO", "script templates - List available templates")
    addLog("INFO", "script delete <name> - Delete a script")
    addLog("INFO", "script run <name> [params] - Run a saved script")
    addLog("INFO", "script export <name|all> - Export scripts as JSON")
    addLog("INFO", "script import <json> - Import scripts from JSON")
    addLog("INFO", "")
    addLog("INFO", "Use the Laser Pointer tool to select objects for dump/exec/inspect/hierarchy/diff/highlight commands")
    addLog("INFO", "Use Tab for autocompletion - exec commands show object manipulation functions")
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

-- Dump debug information about selected object
function dumpSelectedObject()
    local selectedBody = GetInt and GetInt("lasertool.selected_body") or 0
    local selectedShape = GetInt and GetInt("lasertool.selected_shape") or 0

    if selectedBody == 0 and selectedShape == 0 then
        addLog("ERROR", "No object selected. Use the laser pointer tool to select an object first.")
        return
    end

    addLog("INFO", "=== SELECTED OBJECT DEBUG INFO ===")

    -- General info
    if GetPlayerPos then
        local playerPos = GetPlayerPos()
        if playerPos and playerPos.x and playerPos.y and playerPos.z then
            addLog("INFO", "Player Position: (" .. string.format("%.2f", playerPos.x) .. ", " .. string.format("%.2f", playerPos.y) .. ", " .. string.format("%.2f", playerPos.z) .. ")")
        end
    end

    if selectedBody ~= 0 then
        addLog("INFO", "Body Handle: " .. selectedBody)

        -- Transform info
        if GetBodyTransform then
            local transform = GetBodyTransform(selectedBody)
            if transform and transform.pos and transform.pos.x and transform.pos.y and transform.pos.z then
                addLog("INFO", "Body Position: (" .. string.format("%.2f", transform.pos.x) .. ", " .. string.format("%.2f", transform.pos.y) .. ", " .. string.format("%.2f", transform.pos.z) .. ")")
            end
            if transform and transform.rot and transform.rot.x and transform.rot.y and transform.rot.z and transform.rot.w then
                addLog("INFO", "Body Rotation: (" .. string.format("%.3f", transform.rot.x) .. ", " .. string.format("%.3f", transform.rot.y) .. ", " .. string.format("%.3f", transform.rot.z) .. ", " .. string.format("%.3f", transform.rot.w) .. ")")
            end
        end

        -- Physics properties
        if GetBodyMass then
            local mass = GetBodyMass(selectedBody)
            if mass then
                addLog("INFO", "Body Mass: " .. string.format("%.2f", mass) .. " kg")
            else
                addLog("INFO", "Body Mass: N/A")
            end
        end

        if GetBodyVelocity then
            local vel = GetBodyVelocity(selectedBody)
            if vel and vel.x and vel.y and vel.z then
                local speed = math.sqrt(vel.x*vel.x + vel.y*vel.y + vel.z*vel.z)
                addLog("INFO", "Body Velocity: (" .. string.format("%.2f", vel.x) .. ", " .. string.format("%.2f", vel.y) .. ", " .. string.format("%.2f", vel.z) .. ") [" .. string.format("%.2f", speed) .. " m/s]")
            end
        end

        if GetBodyAngularVelocity then
            local angVel = GetBodyAngularVelocity(selectedBody)
            if angVel and angVel.x and angVel.y and angVel.z then
                local angSpeed = math.sqrt(angVel.x*angVel.x + angVel.y*angVel.y + angVel.z*angVel.z)
                addLog("INFO", "Body Angular Velocity: (" .. string.format("%.2f", angVel.x) .. ", " .. string.format("%.2f", angVel.y) .. ", " .. string.format("%.2f", angVel.z) .. ") [" .. string.format("%.2f", angSpeed) .. " rad/s]")
            end
        end

        if GetBodyCenterOfMass then
            local com = GetBodyCenterOfMass(selectedBody)
            if com and com.x and com.y and com.z then
                addLog("INFO", "Center of Mass: (" .. string.format("%.2f", com.x) .. ", " .. string.format("%.2f", com.y) .. ", " .. string.format("%.2f", com.z) .. ")")
            end
        end

        -- State info
        if IsBodyDynamic then
            local isDynamic = IsBodyDynamic(selectedBody)
            addLog("INFO", "Is Dynamic: " .. tostring(isDynamic))
        end

        if IsBodyActive then
            local isActive = IsBodyActive(selectedBody)
            addLog("INFO", "Is Active: " .. tostring(isActive))
        end

        if IsBodyBroken then
            local isBroken = IsBodyBroken(selectedBody)
            addLog("INFO", "Is Broken: " .. tostring(isBroken))
        end

        if IsBodyVisible then
            local isVisible = IsBodyVisible(selectedBody)
            addLog("INFO", "Is Visible: " .. tostring(isVisible))
        end

        -- Bounds and shapes
        if GetBodyBounds then
            local min, max = GetBodyBounds(selectedBody)
            if min and max and min.x and min.y and min.z and max.x and max.y and max.z then
                addLog("INFO", "Bounds Min: (" .. string.format("%.2f", min.x) .. ", " .. string.format("%.2f", min.y) .. ", " .. string.format("%.2f", min.z) .. ")")
                addLog("INFO", "Bounds Max: (" .. string.format("%.2f", max.x) .. ", " .. string.format("%.2f", max.y) .. ", " .. string.format("%.2f", max.z) .. ")")
                local size = {x = max.x - min.x, y = max.y - min.y, z = max.z - min.z}
                addLog("INFO", "Bounds Size: (" .. string.format("%.2f", size.x) .. ", " .. string.format("%.2f", size.y) .. ", " .. string.format("%.2f", size.z) .. ")")
            end
        end

        if GetBodyShapes then
            local shapes = GetBodyShapes(selectedBody) or {}
            addLog("INFO", "Shape Count: " .. #shapes)
            if #shapes > 0 then
                local totalVoxels = 0
                for _, shape in ipairs(shapes) do
                    if GetShapeVoxelCount then
                        totalVoxels = totalVoxels + (GetShapeVoxelCount(shape) or 0)
                    end
                end
                addLog("INFO", "Total Voxels: " .. totalVoxels)
            end
        end

        -- Vehicle info
        if GetBodyVehicle then
            local vehicle = GetBodyVehicle(selectedBody)
            if vehicle and vehicle ~= 0 then
                addLog("INFO", "Vehicle Handle: " .. vehicle)
                if GetVehicleHealth then
                    local health = GetVehicleHealth(vehicle)
                    if health then
                        addLog("INFO", "Vehicle Health: " .. string.format("%.1f", health))
                    else
                        addLog("INFO", "Vehicle Health: N/A")
                    end
                end
            end
        end

        -- Tags and description
        if GetDescription then
            local desc = GetDescription(selectedBody)
            if desc and desc ~= "" then
                addLog("INFO", "Description: " .. desc)
            end
        end

        if ListTags then
            local tags = ListTags(selectedBody) or {}
            if #tags > 0 then
                addLog("INFO", "Tags: " .. table.concat(tags, ", "))
            end
        end
    end

    if selectedShape ~= 0 then
        addLog("INFO", "Shape Handle: " .. selectedShape)

        -- Parent body
        if GetShapeBody then
            local body = GetShapeBody(selectedShape)
            if body and body ~= 0 then
                addLog("INFO", "Parent Body: " .. body)
            end
        end

        -- Transform info
        if GetShapeWorldTransform then
            local transform = GetShapeWorldTransform(selectedShape)
            if transform and transform.pos and transform.pos.x and transform.pos.y and transform.pos.z then
                addLog("INFO", "Shape Position: (" .. string.format("%.2f", transform.pos.x) .. ", " .. string.format("%.2f", transform.pos.y) .. ", " .. string.format("%.2f", transform.pos.z) .. ")")
            end
            if transform and transform.rot and transform.rot.x and transform.rot.y and transform.rot.z and transform.rot.w then
                addLog("INFO", "Shape Rotation: (" .. string.format("%.3f", transform.rot.x) .. ", " .. string.format("%.3f", transform.rot.y) .. ", " .. string.format("%.3f", transform.rot.z) .. ", " .. string.format("%.3f", transform.rot.w) .. ")")
            end
        end

        if GetShapeLocalTransform then
            local transform = GetShapeLocalTransform(selectedShape)
            if transform and transform.pos and transform.pos.x and transform.pos.y and transform.pos.z then
                addLog("INFO", "Local Position: (" .. string.format("%.2f", transform.pos.x) .. ", " .. string.format("%.2f", transform.pos.y) .. ", " .. string.format("%.2f", transform.pos.z) .. ")")
            end
            if transform and transform.rot and transform.rot.x and transform.rot.y and transform.rot.z and transform.rot.w then
                addLog("INFO", "Local Rotation: (" .. string.format("%.3f", transform.rot.x) .. ", " .. string.format("%.3f", transform.rot.y) .. ", " .. string.format("%.3f", transform.rot.z) .. ", " .. string.format("%.3f", transform.rot.w) .. ")")
            end
        end

        -- Size and voxels
        if GetShapeSize then
            local size = GetShapeSize(selectedShape)
            if type(size) == "table" and size.x and size.y and size.z then
                addLog("INFO", "Shape Size: " .. size.x .. "x" .. size.y .. "x" .. size.z)
                local volume = size.x * size.y * size.z
                addLog("INFO", "Shape Volume: " .. volume .. " voxels")
            elseif type(size) == "number" then
                addLog("INFO", "Shape Size: " .. size)
            else
                addLog("INFO", "Shape Size: " .. tostring(size))
            end
        end

        if GetShapeVoxelCount then
            local voxels = GetShapeVoxelCount(selectedShape)
            if voxels then
                addLog("INFO", "Voxel Count: " .. voxels)
            else
                addLog("INFO", "Voxel Count: N/A")
            end
        end

        -- Materials
        if GetShapeMaterial then
            local material = GetShapeMaterial(selectedShape)
            if material then
                addLog("INFO", "Primary Material: " .. material)
            end
        end

        if GetShapeMaterialAtIndex then
            -- Sample materials at different positions
            local size = GetShapeSize and GetShapeSize(selectedShape)
            if type(size) == "table" and size.x and size.y and size.z then
                local centerX, centerY, centerZ = math.floor(size.x/2), math.floor(size.y/2), math.floor(size.z/2)
                local matCenter = GetShapeMaterialAtIndex(selectedShape, centerX, centerY, centerZ)
                local matCorner = GetShapeMaterialAtIndex(selectedShape, 0, 0, 0)
                addLog("INFO", "Material (Center): " .. (matCenter or "none"))
                addLog("INFO", "Material (Corner): " .. (matCorner or "none"))
            end
        end

        -- Physics properties
        if GetShapeDensity then
            local density = GetShapeDensity(selectedShape)
            if density then
                addLog("INFO", "Density: " .. string.format("%.2f", density))
            else
                addLog("INFO", "Density: N/A")
            end
        end

        if GetShapeEmissiveScale then
            local emissive = GetShapeEmissiveScale(selectedShape)
            if emissive and emissive > 0 then
                addLog("INFO", "Emissive Scale: " .. string.format("%.2f", emissive))
            end
        end

        -- State info
        if IsShapeVisible then
            local isVisible = IsShapeVisible(selectedShape)
            addLog("INFO", "Is Visible: " .. tostring(isVisible))
        end

        if IsShapeBroken then
            local isBroken = IsShapeBroken(selectedShape)
            addLog("INFO", "Is Broken: " .. tostring(isBroken))
        end

        if IsShapeDisconnected then
            local isDisconnected = IsShapeDisconnected(selectedShape)
            addLog("INFO", "Is Disconnected: " .. tostring(isDisconnected))
        end

        if IsStaticShapeDetached then
            local isDetached = IsStaticShapeDetached(selectedShape)
            addLog("INFO", "Is Detached: " .. tostring(isDetached))
        end

        -- Collision and joints
        if GetShapeCollisionFilter then
            local filter = GetShapeCollisionFilter(selectedShape)
            addLog("INFO", "Collision Filter: " .. filter)
        end

        if GetShapeJoints then
            local joints = GetShapeJoints(selectedShape) or {}
            addLog("INFO", "Joint Count: " .. #joints)
            if #joints > 0 then
                for i, joint in ipairs(joints) do
                    if GetJointType then
                        local jointType = GetJointType(joint)
                        addLog("INFO", "  Joint " .. i .. ": " .. joint .. " (Type: " .. jointType .. ")")
                    end
                end
            end
        end

        -- Lights and screens
        if GetShapeLights then
            local lights = GetShapeLights(selectedShape) or {}
            addLog("INFO", "Light Count: " .. #lights)
        end

        -- Distance from player
        if GetPlayerPos and GetShapeWorldTransform then
            local playerPos = GetPlayerPos()
            local shapeTransform = GetShapeWorldTransform(selectedShape)
            if playerPos and shapeTransform and shapeTransform.pos and 
               playerPos.x and playerPos.y and playerPos.z and 
               shapeTransform.pos.x and shapeTransform.pos.y and shapeTransform.pos.z then
                local dx = shapeTransform.pos.x - playerPos.x
                local dy = shapeTransform.pos.y - playerPos.y
                local dz = shapeTransform.pos.z - playerPos.z
                local distance = math.sqrt(dx*dx + dy*dy + dz*dz)
                addLog("INFO", "Distance from Player: " .. string.format("%.2f", distance) .. " meters")
            end
        end
    end

    -- Object type info
    if GetEntityType then
        if selectedBody ~= 0 then
            local entityType = GetEntityType(selectedBody)
            addLog("INFO", "Entity Type: " .. entityType)
        elseif selectedShape ~= 0 then
            local entityType = GetEntityType(selectedShape)
            addLog("INFO", "Entity Type: " .. entityType)
        end
    end

    addLog("INFO", "=== END DEBUG INFO ===")
end

-- Enhanced object inspection with different detail levels
function inspectSelectedObject(args)
    local selectedBody = GetInt and GetInt("lasertool.selected_body") or 0
    local selectedShape = GetInt and GetInt("lasertool.selected_shape") or 0

    if selectedBody == 0 and selectedShape == 0 then
        addLog("ERROR", "No object selected. Use the laser pointer tool to select an object first.")
        return
    end

    -- Parse arguments for detail level
    local detailLevel = "basic"
    if args and args ~= "" then
        local level = args:match("^%s*(%w+)")
        if level then
            detailLevel = level:lower()
        end
    end

    addLog("INFO", "=== OBJECT INSPECTION (Level: " .. detailLevel .. ") ===")

    if selectedBody ~= 0 then
        inspectBody(selectedBody, detailLevel)
    elseif selectedShape ~= 0 then
        inspectShape(selectedShape, detailLevel)
    end

    addLog("INFO", "=== END INSPECTION ===")
end

-- Inspect a body with specified detail level
function inspectBody(body, level)
    addLog("INFO", "Body Handle: " .. body)

    -- Basic info (always shown)
    if GetBodyTransform and level ~= "minimal" then
        local transform = GetBodyTransform(body)
        if transform and transform.pos then
            addLog("INFO", "Position: (" .. string.format("%.2f", transform.pos.x) .. ", " .. string.format("%.2f", transform.pos.y) .. ", " .. string.format("%.2f", transform.pos.z) .. ")")
        end
    end

    if GetBodyMass and (level == "basic" or level == "detailed" or level == "full") then
        local mass = GetBodyMass(body)
        if mass then
            addLog("INFO", "Mass: " .. string.format("%.2f", mass) .. " kg")
        end
    end

    if IsBodyDynamic and (level == "basic" or level == "detailed" or level == "full") then
        local isDynamic = IsBodyDynamic(body)
        addLog("INFO", "Dynamic: " .. tostring(isDynamic))
    end

    -- Detailed info
    if level == "detailed" or level == "full" then
        if GetBodyVelocity then
            local vel = GetBodyVelocity(body)
            if vel then
                local speed = math.sqrt(vel.x*vel.x + vel.y*vel.y + vel.z*vel.z)
                addLog("INFO", "Velocity: (" .. string.format("%.2f", vel.x) .. ", " .. string.format("%.2f", vel.y) .. ", " .. string.format("%.2f", vel.z) .. ") [" .. string.format("%.2f", speed) .. " m/s]")
            end
        end

        if GetBodyBounds then
            local min, max = GetBodyBounds(body)
            if min and max then
                addLog("INFO", "Bounds: (" .. string.format("%.1f", min.x) .. "," .. string.format("%.1f", min.y) .. "," .. string.format("%.1f", min.z) .. ") to (" .. string.format("%.1f", max.x) .. "," .. string.format("%.1f", max.y) .. "," .. string.format("%.1f", max.z) .. ")")
            end
        end

        if GetBodyShapes then
            local shapes = GetBodyShapes(body) or {}
            addLog("INFO", "Shapes: " .. #shapes)
        end
    end

    -- Full info
    if level == "full" then
        if GetBodyAngularVelocity then
            local angVel = GetBodyAngularVelocity(body)
            if angVel then
                local angSpeed = math.sqrt(angVel.x*angVel.x + angVel.y*angVel.y + angVel.z*angVel.z)
                addLog("INFO", "Angular Velocity: (" .. string.format("%.2f", angVel.x) .. ", " .. string.format("%.2f", angVel.y) .. ", " .. string.format("%.2f", angVel.z) .. ") [" .. string.format("%.2f", angSpeed) .. " rad/s]")
            end
        end

        if GetBodyCenterOfMass then
            local com = GetBodyCenterOfMass(body)
            if com then
                addLog("INFO", "Center of Mass: (" .. string.format("%.2f", com.x) .. ", " .. string.format("%.2f", com.y) .. ", " .. string.format("%.2f", com.z) .. ")")
            end
        end

        if IsBodyActive then
            addLog("INFO", "Active: " .. tostring(IsBodyActive(body)))
        end
        if IsBodyVisible then
            addLog("INFO", "Visible: " .. tostring(IsBodyVisible(body)))
        end
        if IsBodyBroken then
            addLog("INFO", "Broken: " .. tostring(IsBodyBroken(body)))
        end
    end
end

-- Inspect a shape with specified detail level
function inspectShape(shape, level)
    addLog("INFO", "Shape Handle: " .. shape)

    -- Basic info (always shown)
    if GetShapeBody and level ~= "minimal" then
        local body = GetShapeBody(shape)
        if body and body ~= 0 then
            addLog("INFO", "Parent Body: " .. body)
        end
    end

    if GetShapeSize and (level == "basic" or level == "detailed" or level == "full") then
        local size = GetShapeSize(shape)
        if type(size) == "table" and size.x then
            addLog("INFO", "Size: " .. size.x .. "x" .. size.y .. "x" .. size.z)
        end
    end

    -- Detailed info
    if level == "detailed" or level == "full" then
        if GetShapeWorldTransform then
            local transform = GetShapeWorldTransform(shape)
            if transform and transform.pos and transform.pos.x and transform.pos.y and transform.pos.z then
                addLog("INFO", "World Position: (" .. string.format("%.2f", transform.pos.x) .. ", " .. string.format("%.2f", transform.pos.y) .. ", " .. string.format("%.2f", transform.pos.z) .. ")")
            end
        end

        if GetShapeVoxelCount then
            local voxels = GetShapeVoxelCount(shape)
            if voxels then
                addLog("INFO", "Voxels: " .. voxels)
            end
        end

        if GetShapeMaterial then
            local material = GetShapeMaterial(shape)
            if material then
                addLog("INFO", "Material: " .. material)
            end
        end
    end

    -- Full info
    if level == "full" then
        if GetShapeDensity then
            local density = GetShapeDensity(shape)
            if density then
                addLog("INFO", "Density: " .. string.format("%.2f", density))
            end
        end

        if GetShapeEmissiveScale then
            local emissive = GetShapeEmissiveScale(shape)
            if emissive and emissive > 0 then
                addLog("INFO", "Emissive Scale: " .. string.format("%.2f", emissive))
            end
        end

        if IsShapeVisible then
            addLog("INFO", "Visible: " .. tostring(IsShapeVisible(shape)))
        end
        if IsShapeBroken then
            addLog("INFO", "Broken: " .. tostring(IsShapeBroken(shape)))
        end
        if IsShapeDisconnected then
            addLog("INFO", "Disconnected: " .. tostring(IsShapeDisconnected(shape)))
        end
    end
end

-- Show object hierarchy
function showObjectHierarchy(args)
    local selectedBody = GetInt and GetInt("lasertool.selected_body") or 0
    local selectedShape = GetInt and GetInt("lasertool.selected_shape") or 0

    if selectedBody == 0 and selectedShape == 0 then
        addLog("ERROR", "No object selected. Use the laser pointer tool to select an object first.")
        return
    end

    addLog("INFO", "=== OBJECT HIERARCHY ===")

    if selectedBody ~= 0 then
        showBodyHierarchy(selectedBody, 0)
    elseif selectedShape ~= 0 then
        showShapeHierarchy(selectedShape, 0)
    end

    addLog("INFO", "=== END HIERARCHY ===")
end

-- Show body hierarchy
function showBodyHierarchy(body, depth)
    local indent = string.rep("  ", depth)
    addLog("INFO", indent .. "Body: " .. body)

    if GetBodyShapes then
        local shapes = GetBodyShapes(body) or {}
        for i, shape in ipairs(shapes) do
            showShapeHierarchy(shape, depth + 1)
        end
    end

    -- Show connected bodies through joints
    if GetBodyJoints then
        local joints = GetBodyJoints(body) or {}
        for _, joint in ipairs(joints) do
            if GetJointedBodies then
                local bodies = GetJointedBodies(joint) or {}
                for _, connectedBody in ipairs(bodies) do
                    if connectedBody ~= body then
                        addLog("INFO", indent .. "  Connected Body: " .. connectedBody .. " (via joint " .. joint .. ")")
                    end
                end
            end
        end
    end
end

-- Show shape hierarchy
function showShapeHierarchy(shape, depth)
    local indent = string.rep("  ", depth)
    local shapeInfo = "Shape: " .. shape

    if GetShapeSize then
        local size = GetShapeSize(shape)
        if type(size) == "table" and size.x then
            shapeInfo = shapeInfo .. " (" .. size.x .. "x" .. size.y .. "x" .. size.z .. ")"
        end
    end

    addLog("INFO", indent .. shapeInfo)

    -- Show joints connected to this shape
    if GetShapeJoints then
        local joints = GetShapeJoints(shape) or {}
        for _, joint in ipairs(joints) do
            if GetJointType then
                local jointType = GetJointType(joint)
                addLog("INFO", indent .. "  Joint: " .. joint .. " (" .. jointType .. ")")
            end
        end
    end

    -- Show lights attached to this shape
    if GetShapeLights then
        local lights = GetShapeLights(shape) or {}
        for _, light in ipairs(lights) do
            addLog("INFO", indent .. "  Light: " .. light)
        end
    end
end

-- Property diff functionality
function diffObjectProperties(args)
    local selectedBody = GetInt and GetInt("lasertool.selected_body") or 0
    local selectedShape = GetInt and GetInt("lasertool.selected_shape") or 0

    if selectedBody == 0 and selectedShape == 0 then
        addLog("ERROR", "No object selected. Use the laser pointer tool to select an object first.")
        return
    end

    -- Parse arguments for baseline snapshot
    local action = args and args:match("^%s*(%w+)") or "snapshot"

    if action == "snapshot" then
        takePropertySnapshot(selectedBody, selectedShape)
        addLog("INFO", "Property snapshot taken. Use 'diff compare' to see changes.")
    elseif action == "compare" then
        comparePropertySnapshot(selectedBody, selectedShape)
    elseif action == "clear" then
        console.propertySnapshot = nil
        addLog("INFO", "Property snapshot cleared.")
    else
        addLog("ERROR", "Usage: diff <snapshot|compare|clear>")
        addLog("INFO", "snapshot - Take current property snapshot")
        addLog("INFO", "compare - Compare current properties with snapshot")
        addLog("INFO", "clear - Clear stored snapshot")
    end
end

-- Take property snapshot
function takePropertySnapshot(body, shape)
    console.propertySnapshot = {
        timestamp = os and os.time() or 0,
        body = body,
        shape = shape
    }

    if body ~= 0 then
        console.propertySnapshot.bodyData = {}
        local data = console.propertySnapshot.bodyData

        if GetBodyTransform then
            data.transform = GetBodyTransform(body)
        end
        if GetBodyMass then
            data.mass = GetBodyMass(body)
        end
        if GetBodyVelocity then
            data.velocity = GetBodyVelocity(body)
        end
        if IsBodyDynamic then
            data.isDynamic = IsBodyDynamic(body)
        end
        if GetBodyBounds then
            data.bounds = {GetBodyBounds(body)}
        end
    elseif shape ~= 0 then
        console.propertySnapshot.shapeData = {}
        local data = console.propertySnapshot.shapeData

        if GetShapeWorldTransform then
            data.transform = GetShapeWorldTransform(shape)
        end
        if GetShapeSize then
            data.size = GetShapeSize(shape)
        end
        if GetShapeVoxelCount then
            data.voxels = GetShapeVoxelCount(shape)
        end
        if IsShapeVisible then
            data.isVisible = IsShapeVisible(shape)
        end
    end
end

-- Compare with property snapshot
function comparePropertySnapshot(body, shape)
    if not console.propertySnapshot then
        addLog("ERROR", "No property snapshot available. Use 'diff snapshot' first.")
        return
    end

    if console.propertySnapshot.body ~= body or console.propertySnapshot.shape ~= shape then
        addLog("ERROR", "Snapshot was taken for a different object.")
        return
    end

    addLog("INFO", "=== PROPERTY DIFF ===")

    if body ~= 0 and console.propertySnapshot.bodyData then
        compareBodyProperties(body, console.propertySnapshot.bodyData)
    elseif shape ~= 0 and console.propertySnapshot.shapeData then
        compareShapeProperties(shape, console.propertySnapshot.shapeData)
    end

    addLog("INFO", "=== END DIFF ===")
end

-- Compare body properties
function compareBodyProperties(body, snapshot)
    -- Compare transform
    if snapshot.transform and GetBodyTransform then
        local current = GetBodyTransform(body)
        if current and current.pos then
            local dx = current.pos.x - snapshot.transform.pos.x
            local dy = current.pos.y - snapshot.transform.pos.y
            local dz = current.pos.z - snapshot.transform.pos.z
            if math.abs(dx) > 0.01 or math.abs(dy) > 0.01 or math.abs(dz) > 0.01 then
                addLog("INFO", "Position changed: Δ(" .. string.format("%.2f", dx) .. ", " .. string.format("%.2f", dy) .. ", " .. string.format("%.2f", dz) .. ")")
            end
        end
    end

    -- Compare mass
    if snapshot.mass and GetBodyMass then
        local current = GetBodyMass(body)
        if current and math.abs(current - snapshot.mass) > 0.01 then
            addLog("INFO", "Mass changed: " .. string.format("%.2f", snapshot.mass) .. " → " .. string.format("%.2f", current))
        end
    end

    -- Compare velocity
    if snapshot.velocity and GetBodyVelocity then
        local current = GetBodyVelocity(body)
        if current then
            local dvx = current.x - snapshot.velocity.x
            local dvy = current.y - snapshot.velocity.y
            local dvz = current.z - snapshot.velocity.z
            if math.abs(dvx) > 0.01 or math.abs(dvy) > 0.01 or math.abs(dvz) > 0.01 then
                addLog("INFO", "Velocity changed: Δ(" .. string.format("%.2f", dvx) .. ", " .. string.format("%.2f", dvy) .. ", " .. string.format("%.2f", dvz) .. ")")
            end
        end
    end

    -- Compare dynamic state
    if snapshot.isDynamic ~= nil and IsBodyDynamic then
        local current = IsBodyDynamic(body)
        if current ~= snapshot.isDynamic then
            addLog("INFO", "Dynamic state changed: " .. tostring(snapshot.isDynamic) .. " → " .. tostring(current))
        end
    end
end

-- Compare shape properties
function compareShapeProperties(shape, snapshot)
    -- Compare transform
    if snapshot.transform and GetShapeWorldTransform then
        local current = GetShapeWorldTransform(shape)
        if current and current.pos then
            local dx = current.pos.x - snapshot.transform.pos.x
            local dy = current.pos.y - snapshot.transform.pos.y
            local dz = current.pos.z - snapshot.transform.pos.z
            if math.abs(dx) > 0.01 or math.abs(dy) > 0.01 or math.abs(dz) > 0.01 then
                addLog("INFO", "Position changed: Δ(" .. string.format("%.2f", dx) .. ", " .. string.format("%.2f", dy) .. ", " .. string.format("%.2f", dz) .. ")")
            end
        end
    end

    -- Compare visibility
    if snapshot.isVisible ~= nil and IsShapeVisible then
        local current = IsShapeVisible(shape)
        if current ~= snapshot.isVisible then
            addLog("INFO", "Visibility changed: " .. tostring(snapshot.isVisible) .. " → " .. tostring(current))
        end
    end
end

-- Visual debugging tools
function highlightSelectedObject(args)
    local selectedBody = GetInt and GetInt("lasertool.selected_body") or 0
    local selectedShape = GetInt and GetInt("lasertool.selected_shape") or 0

    if selectedBody == 0 and selectedShape == 0 then
        addLog("ERROR", "No object selected. Use the laser pointer tool to select an object first.")
        return
    end

    -- Parse arguments for highlight type
    local highlightType = args and args:match("^%s*(%w+)") or "outline"

    if highlightType == "outline" then
        if selectedBody ~= 0 and DrawBodyOutline then
            DrawBodyOutline(selectedBody, 1.0)
            addLog("INFO", "Body highlighted with outline")
        elseif selectedShape ~= 0 and DrawShapeOutline then
            DrawShapeOutline(selectedShape, 1, 1, 0, 1.0) -- Yellow outline
            addLog("INFO", "Shape highlighted with yellow outline")
        end
    elseif highlightType == "highlight" then
        if selectedBody ~= 0 and DrawBodyHighlight then
            DrawBodyHighlight(selectedBody, 1.0)
            addLog("INFO", "Body highlighted")
        elseif selectedShape ~= 0 and DrawShapeHighlight then
            DrawShapeHighlight(selectedShape, 1.0)
            addLog("INFO", "Shape highlighted")
        end
    elseif highlightType == "glow" then
        if selectedShape ~= 0 and SetShapeEmissiveScale then
            SetShapeEmissiveScale(selectedShape, 5.0)
            addLog("INFO", "Shape set to glow")
        else
            addLog("ERROR", "Glow highlighting only works on shapes")
        end
    elseif highlightType == "clear" then
        if selectedShape ~= 0 and SetShapeEmissiveScale then
            SetShapeEmissiveScale(selectedShape, 0.0)
            addLog("INFO", "Shape glow cleared")
        end
    else
        addLog("ERROR", "Usage: highlight <outline|highlight|glow|clear>")
        addLog("INFO", "outline - Draw colored outline around object")
        addLog("INFO", "highlight - Highlight object")
        addLog("INFO", "glow - Make shape glow (shapes only)")
        addLog("INFO", "clear - Clear glow effect")
    end
end

-- API search functionality
function searchAPI(query)
    if not query or query == "" then
        addLog("ERROR", "Usage: search <query> [category]")
        addLog("INFO", "Search Teardown API functions")
        addLog("INFO", "Categories: body, shape, joint, light, vehicle, physics, ui, debug, general")
        return
    end

    local searchTerm = query:lower()
    local category = nil

    -- Check if category is specified
    local parts = {}
    for part in query:gmatch("%S+") do
        table.insert(parts, part)
    end

    if #parts > 1 then
        -- Last part might be a category
        local lastPart = parts[#parts]:lower()
        local categories = {
            body = true, shape = true, joint = true, light = true,
            vehicle = true, physics = true, ui = true, debug = true, general = true
        }
        if categories[lastPart] then
            category = lastPart
            table.remove(parts, #parts)
            searchTerm = table.concat(parts, " "):lower()
        end
    end

    local matches = {}
    local maxResults = 20

    -- Search through API functions
    for _, funcName in ipairs(console.apiFunctions) do
        local funcLower = funcName:lower()
        local signature = console.apiSignatures[funcName] or ""

        -- Check if function matches search term
        local matchesSearch = funcLower:find(searchTerm, 1, true) ~= nil

        -- Check category if specified
        local matchesCategory = true
        if category then
            matchesCategory = getFunctionCategory(funcName) == category
        end

        if matchesSearch and matchesCategory then
            table.insert(matches, {
                name = funcName,
                signature = signature,
                category = getFunctionCategory(funcName)
            })

            if #matches >= maxResults then
                break
            end
        end
    end

    if #matches == 0 then
        addLog("INFO", "No API functions found matching '" .. query .. "'")
    else
        addLog("INFO", "=== API SEARCH RESULTS (" .. #matches .. " matches) ===")
        for _, match in ipairs(matches) do
            local categoryTag = match.category and "[" .. match.category:upper() .. "] " or ""
            addLog("INFO", categoryTag .. match.signature)
        end
        if #matches >= maxResults then
            addLog("INFO", "... and more results (showing first " .. maxResults .. ")")
        end
        addLog("INFO", "=== END SEARCH ===")
    end
end

-- Categorize API functions
function getFunctionCategory(funcName)
    local categories = {
        -- Body functions
        body = {"GetBody", "SetBody", "IsBody", "DrawBody"},
        -- Shape functions
        shape = {"GetShape", "SetShape", "IsShape", "DrawShape"},
        -- Joint functions
        joint = {"GetJoint", "SetJoint", "IsJoint"},
        -- Light functions
        light = {"GetLight", "SetLight", "IsLight", "PointLight"},
        -- Vehicle functions
        vehicle = {"GetVehicle", "SetVehicle", "DriveVehicle"},
        -- Physics functions
        physics = {"GetGravity", "SetGravity", "QueryRaycast", "QueryClosestPoint"},
        -- UI functions
        ui = {"Ui", "DrawLine", "Debug"},
        -- Debug functions
        debug = {"Debug", "addLog", "print"}
    }

    for category, prefixes in pairs(categories) do
        for _, prefix in ipairs(prefixes) do
            if funcName:sub(1, #prefix) == prefix then
                return category
            end
        end
    end

    return "general"
end

-- Object finder functionality
function findObjects(query)
    if not query or query == "" then
        addLog("ERROR", "Usage: find <type> [property=value ...]")
        addLog("INFO", "Find objects by type and properties")
        addLog("INFO", "Types: bodies, shapes, joints, lights, vehicles")
        addLog("INFO", "Examples:")
        addLog("INFO", "  find bodies mass>100")
        addLog("INFO", "  find shapes size=5")
        addLog("INFO", "  find vehicles")
        return
    end

    local parts = {}
    for part in query:gmatch("%S+") do
        table.insert(parts, part)
    end

    local objectType = parts[1]:lower()
    local filters = {}

    -- Parse filters
    for i = 2, #parts do
        local filter = parts[i]
        local prop, op, value = filter:match("([^=<>]+)([=<>]+)(.+)")
        if prop and op and value then
            table.insert(filters, {
                property = prop:lower(),
                operator = op,
                value = tonumber(value) or value
            })
        end
    end

    local found = {}

    if objectType == "bodies" or objectType == "body" then
        found = findBodies(filters)
    elseif objectType == "shapes" or objectType == "shape" then
        found = findShapes(filters)
    elseif objectType == "joints" or objectType == "joint" then
        found = findJoints(filters)
    elseif objectType == "lights" or objectType == "light" then
        found = findLights(filters)
    elseif objectType == "vehicles" or objectType == "vehicle" then
        found = findVehicles(filters)
    else
        addLog("ERROR", "Unknown object type: " .. objectType)
        addLog("INFO", "Supported types: bodies, shapes, joints, lights, vehicles")
        return
    end

    if #found == 0 then
        addLog("INFO", "No " .. objectType .. " found matching criteria")
    else
        addLog("INFO", "=== FOUND " .. #found .. " " .. objectType:upper() .. " ===")
        for i, obj in ipairs(found) do
            if objectType == "bodies" or objectType == "body" then
                local info = "Body " .. obj.handle
                if obj.mass then info = info .. " (mass: " .. string.format("%.1f", obj.mass) .. ")" end
                if obj.distance then info = info .. " [" .. string.format("%.1f", obj.distance) .. "m]" end
                addLog("INFO", info)
            elseif objectType == "shapes" or objectType == "shape" then
                local info = "Shape " .. obj.handle
                if obj.size then info = info .. " (" .. obj.size .. ")" end
                if obj.material then info = info .. " [" .. obj.material .. "]" end
                if obj.distance then info = info .. " [" .. string.format("%.1f", obj.distance) .. "m]" end
                addLog("INFO", info)
            else
                addLog("INFO", objectType:sub(1, -2) .. " " .. obj.handle)
            end

            if i >= 10 then -- Limit output
                addLog("INFO", "... and " .. (#found - 10) .. " more")
                break
            end
        end
        addLog("INFO", "=== END FIND ===")
    end
end

-- Find bodies with filters
function findBodies(filters)
    local found = {}

    -- Get all bodies (this is a simplified version - in practice you'd need to query the scene)
    -- For now, we'll use a placeholder that demonstrates the filtering logic
    if FindBodies then
        local bodies = FindBodies() or {}
        for _, body in ipairs(bodies) do
            if matchesFilters(body, filters, "body") then
                table.insert(found, {handle = body})
            end
        end
    end

    return found
end

-- Find shapes with filters
function findShapes(filters)
    local found = {}

    if FindShapes then
        local shapes = FindShapes() or {}
        for _, shape in ipairs(shapes) do
            if matchesFilters(shape, filters, "shape") then
                table.insert(found, {handle = shape})
            end
        end
    end

    return found
end

-- Find joints with filters
function findJoints(filters)
    local found = {}

    if FindJoints then
        local joints = FindJoints() or {}
        for _, joint in ipairs(joints) do
            if matchesFilters(joint, filters, "joint") then
                table.insert(found, {handle = joint})
            end
        end
    end

    return found
end

-- Find lights with filters
function findLights(filters)
    local found = {}

    if FindLights then
        local lights = FindLights() or {}
        for _, light in ipairs(lights) do
            if matchesFilters(light, filters, "light") then
                table.insert(found, {handle = light})
            end
        end
    end

    return found
end

-- Find vehicles with filters
function findVehicles(filters)
    local found = {}

    if FindVehicles then
        local vehicles = FindVehicles() or {}
        for _, vehicle in ipairs(vehicles) do
            if matchesFilters(vehicle, filters, "vehicle") then
                table.insert(found, {handle = vehicle})
            end
        end
    end

    return found
end

-- Check if object matches filters
function matchesFilters(handle, filters, objectType)
    for _, filter in ipairs(filters) do
        local prop = filter.property
        local op = filter.operator
        local expectedValue = filter.value

        local actualValue = nil

        -- Get property value based on object type and property
        if objectType == "body" then
            if prop == "mass" and GetBodyMass then
                actualValue = GetBodyMass(handle)
            elseif prop == "dynamic" and IsBodyDynamic then
                actualValue = IsBodyDynamic(handle) and 1 or 0
            elseif prop == "visible" and IsBodyVisible then
                actualValue = IsBodyVisible(handle) and 1 or 0
            end
        elseif objectType == "shape" then
            if prop == "size" and GetShapeSize then
                local size = GetShapeSize(handle)
                if type(size) == "table" then
                    actualValue = size.x * size.y * size.z -- Volume
                else
                    actualValue = size
                end
            elseif prop == "voxels" and GetShapeVoxelCount then
                actualValue = GetShapeVoxelCount(handle)
            elseif prop == "visible" and IsShapeVisible then
                actualValue = IsShapeVisible(handle) and 1 or 0
            end
        end

        if actualValue == nil then
            return false -- Property not available
        end

        -- Compare values
        local matches = false
        if op == "=" or op == "==" then
            matches = actualValue == expectedValue
        elseif op == "!=" then
            matches = actualValue ~= expectedValue
        elseif op == ">" then
            matches = actualValue > expectedValue
        elseif op == "<" then
            matches = actualValue < expectedValue
        elseif op == ">=" then
            matches = actualValue >= expectedValue
        elseif op == "<=" then
            matches = actualValue <= expectedValue
        end

        if not matches then
            return false
        end
    end

    return true
end

-- Physics debugger commands
function handlePhysicsCommand(args)
    if not args or args == "" then
        addLog("ERROR", "Usage: physics <forces|collisions|performance|gravity|reset>")
        addLog("INFO", "forces - Visualize forces on selected object")
        addLog("INFO", "collisions - Check collision status")
        addLog("INFO", "performance - Show physics performance stats")
        addLog("INFO", "gravity - Display gravity vector")
        addLog("INFO", "reset - Reset physics debugging overlays")
        return
    end

    local parts = {}
    for part in args:gmatch("%S+") do
        table.insert(parts, part)
    end

    local subcmd = parts[1]:lower()

    if subcmd == "forces" then
        visualizeForces()
    elseif subcmd == "collisions" then
        checkCollisions()
    elseif subcmd == "performance" then
        showPhysicsPerformance()
    elseif subcmd == "gravity" then
        showGravity()
    elseif subcmd == "reset" then
        resetPhysicsDebug()
    else
        addLog("ERROR", "Unknown physics subcommand: " .. subcmd)
    end
end

-- Visualize forces on selected object
function visualizeForces()
    local selectedBody = GetInt and GetInt("lasertool.selected_body") or 0
    local selectedShape = GetInt and GetInt("lasertool.selected_shape") or 0

    if selectedBody == 0 and selectedShape == 0 then
        addLog("ERROR", "No object selected. Use the laser pointer tool to select an object first.")
        return
    end

    addLog("INFO", "=== FORCE VISUALIZATION ===")

    if selectedBody ~= 0 then
        -- Visualize forces on body
        if GetBodyVelocity then
            local vel = GetBodyVelocity(selectedBody)
            if vel then
                local speed = math.sqrt(vel.x*vel.x + vel.y*vel.y + vel.z*vel.z)
                addLog("INFO", "Velocity: " .. string.format("%.2f", speed) .. " m/s")

                -- Draw velocity vector
                if GetBodyTransform and DrawLine then
                    local transform = GetBodyTransform(selectedBody)
                    if transform and transform.pos then
                        local endPos = {
                            x = transform.pos.x + vel.x * 0.1,
                            y = transform.pos.y + vel.y * 0.1,
                            z = transform.pos.z + vel.z * 0.1
                        }
                        DrawLine(transform.pos.x, transform.pos.y, transform.pos.z,
                               endPos.x, endPos.y, endPos.z, 0, 1, 0, 1) -- Green line
                        addLog("INFO", "Velocity vector drawn (green)")
                    end
                end
            end
        end

        if GetBodyAngularVelocity then
            local angVel = GetBodyAngularVelocity(selectedBody)
            if angVel then
                local angSpeed = math.sqrt(angVel.x*angVel.x + angVel.y*angVel.y + angVel.z*angVel.z)
                addLog("INFO", "Angular Velocity: " .. string.format("%.2f", angSpeed) .. " rad/s")
            end
        end

        -- Show applied forces (if any)
        if GetBodyMass then
            local mass = GetBodyMass(selectedBody)
            if mass and mass > 0 then
                addLog("INFO", "Mass: " .. string.format("%.2f", mass) .. " kg")
                addLog("INFO", "Use 'exec ApplyBodyImpulse(body, Vec(x,y,z))' to apply forces")
            end
        end
    end

    addLog("INFO", "=== END FORCE VISUALIZATION ===")
end

-- Check collision status
function checkCollisions()
    local selectedBody = GetInt and GetInt("lasertool.selected_body") or 0
    local selectedShape = GetInt and GetInt("lasertool.selected_shape") or 0

    if selectedBody == 0 and selectedShape == 0 then
        addLog("ERROR", "No object selected. Use the laser pointer tool to select an object first.")
        return
    end

    addLog("INFO", "=== COLLISION STATUS ===")

    if selectedBody ~= 0 then
        -- Check body collisions
        if IsBodyBroken then
            local isBroken = IsBodyBroken(selectedBody)
            addLog("INFO", "Body Broken: " .. tostring(isBroken))
        end

        -- Check for contact points
        if GetBodyShapes then
            local shapes = GetBodyShapes(selectedBody) or {}
            local totalContacts = 0
            for _, shape in ipairs(shapes) do
                if IsShapeTouching then
                    -- This would need to be checked against other shapes
                    -- For now, just show shape count
                end
            end
            addLog("INFO", "Body has " .. #shapes .. " shapes")
        end
    elseif selectedShape ~= 0 then
        -- Check shape collisions
        if IsShapeBroken then
            local isBroken = IsShapeBroken(selectedShape)
            addLog("INFO", "Shape Broken: " .. tostring(isBroken))
        end

        if IsShapeDisconnected then
            local isDisconnected = IsShapeDisconnected(selectedShape)
            addLog("INFO", "Shape Disconnected: " .. tostring(isDisconnected))
        end

        if IsShapeTouching then
            -- Would need to check against specific other shapes
            addLog("INFO", "Use 'exec IsShapeTouching(shape, otherShape)' to check specific collisions")
        end
    end

    addLog("INFO", "=== END COLLISION STATUS ===")
end

-- Show physics performance stats
function showPhysicsPerformance()
    addLog("INFO", "=== PHYSICS PERFORMANCE ===")

    if GetFps then
        local fps = GetFps()
        addLog("INFO", "FPS: " .. string.format("%.1f", fps))
    end

    if GetTimeStep then
        local timeStep = GetTimeStep()
        addLog("INFO", "Time Step: " .. string.format("%.4f", timeStep) .. " s")
    end

    -- Count active physics objects
    local bodyCount = 0
    local shapeCount = 0
    local jointCount = 0

    if FindBodies then
        local bodies = FindBodies() or {}
        bodyCount = #bodies
        addLog("INFO", "Active Bodies: " .. bodyCount)
    end

    if FindShapes then
        local shapes = FindShapes() or {}
        shapeCount = #shapes
        addLog("INFO", "Active Shapes: " .. shapeCount)
    end

    if FindJoints then
        local joints = FindJoints() or {}
        jointCount = #joints
        addLog("INFO", "Active Joints: " .. jointCount)
    end

    -- Estimate physics load
    local physicsLoad = "Low"
    if bodyCount > 100 or shapeCount > 500 then
        physicsLoad = "High"
    elseif bodyCount > 50 or shapeCount > 200 then
        physicsLoad = "Medium"
    end

    addLog("INFO", "Estimated Physics Load: " .. physicsLoad)

    addLog("INFO", "=== END PHYSICS PERFORMANCE ===")
end

-- Show gravity vector
function showGravity()
    addLog("INFO", "=== GRAVITY INFO ===")

    if GetGravity then
        local gravity = GetGravity()
        if gravity and gravity.x and gravity.y and gravity.z then
            local magnitude = math.sqrt(gravity.x*gravity.x + gravity.y*gravity.y + gravity.z*gravity.z)
            addLog("INFO", "Gravity Vector: (" .. string.format("%.2f", gravity.x) .. ", " .. string.format("%.2f", gravity.y) .. ", " .. string.format("%.2f", gravity.z) .. ")")
            addLog("INFO", "Gravity Magnitude: " .. string.format("%.2f", magnitude) .. " m/s²")

            -- Visualize gravity vector from player position
            if GetPlayerPos and DrawLine then
                local playerPos = GetPlayerPos()
                if playerPos then
                    local endPos = {
                        x = playerPos.x + gravity.x * 0.01,
                        y = playerPos.y + gravity.y * 0.01,
                        z = playerPos.z + gravity.z * 0.01
                    }
                    DrawLine(playerPos.x, playerPos.y, playerPos.z,
                           endPos.x, endPos.y, endPos.z, 1, 0, 1, 1) -- Magenta line
                    addLog("INFO", "Gravity vector drawn from player position (magenta)")
                end
            end
        else
            addLog("INFO", "Gravity: Default (0, -10, 0) m/s²")
        end
    else
        addLog("INFO", "Gravity: Default (0, -10, 0) m/s²")
    end

    addLog("INFO", "=== END GRAVITY INFO ===")
end

-- Reset physics debugging overlays
function resetPhysicsDebug()
    addLog("INFO", "Physics debugging overlays reset")
    -- In a full implementation, this would clear any drawn debug lines
    -- For now, just provide feedback
end

-- Handle keyboard shortcuts command
function handleShortcutsCommand(args)
    if not args or args == "" then
        showShortcutsHelp()
        return
    end

    local parts = {}
    for part in args:gmatch("%S+") do
        table.insert(parts, part)
    end

    local subcmd = parts[1]:lower()

    if subcmd == "list" then
        listShortcuts()
    elseif subcmd == "set" then
        if #parts < 3 then
            addLog("ERROR", "Usage: shortcuts set <key> <command>")
            addLog("INFO", "Example: shortcuts set f1 clear")
            return
        end
        local key = parts[2]:lower()
        local command = table.concat(parts, " ", 3)
        setShortcut(key, command)
    elseif subcmd == "remove" or subcmd == "delete" then
        if #parts < 2 then
            addLog("ERROR", "Usage: shortcuts remove <key>")
            return
        end
        local key = parts[2]:lower()
        removeShortcut(key)
    elseif subcmd == "reset" then
        resetShortcuts()
    else
        addLog("ERROR", "Unknown shortcuts subcommand: " .. subcmd)
        showShortcutsHelp()
    end
end

-- Show shortcuts help
function showShortcutsHelp()
    addLog("INFO", "Keyboard Shortcuts Management:")
    addLog("INFO", "shortcuts list - List all shortcuts")
    addLog("INFO", "shortcuts set <key> <command> - Set shortcut for key")
    addLog("INFO", "shortcuts remove <key> - Remove shortcut for key")
    addLog("INFO", "shortcuts reset - Reset to default shortcuts")
    addLog("INFO", "")
    addLog("INFO", "Available keys: f1-f12, 1-9, a-z, space, enter, tab, escape")
    addLog("INFO", "Examples:")
    addLog("INFO", "  shortcuts set f1 clear")
    addLog("INFO", "  shortcuts set c dump")
    addLog("INFO", "  shortcuts set space physics forces")
end

-- List all shortcuts
function listShortcuts()
    if not console.shortcuts or next(console.shortcuts) == nil then
        addLog("INFO", "No shortcuts configured")
        addLog("INFO", "Use 'shortcuts set <key> <command>' to add shortcuts")
        return
    end

    addLog("INFO", "=== KEYBOARD SHORTCUTS ===")
    for key, command in pairs(console.shortcuts) do
        addLog("INFO", key:upper() .. " -> " .. command)
    end
    addLog("INFO", "=== END SHORTCUTS ===")
end

-- Set a keyboard shortcut
function setShortcut(key, command)
    if not console.shortcuts then
        console.shortcuts = {}
    end

    -- Validate key
    if not isValidShortcutKey(key) then
        addLog("ERROR", "Invalid key: " .. key)
        addLog("INFO", "Valid keys: f1-f12, 1-9, a-z, space, enter, tab, escape")
        return
    end

    console.shortcuts[key] = command
    saveShortcuts()
    addLog("INFO", "Shortcut set: " .. key:upper() .. " -> " .. command)
end

-- Remove a keyboard shortcut
function removeShortcut(key)
    if not console.shortcuts or not console.shortcuts[key] then
        addLog("ERROR", "Shortcut not found: " .. key)
        return
    end

    console.shortcuts[key] = nil
    saveShortcuts()
    addLog("INFO", "Shortcut removed: " .. key:upper())
end

-- Reset shortcuts to defaults
function resetShortcuts()
    console.shortcuts = getDefaultShortcuts()
    saveShortcuts()
    addLog("INFO", "Shortcuts reset to defaults")
end

-- Get default shortcuts
function getDefaultShortcuts()
    return {
        f1 = "clear",
        f2 = "dump",
        f3 = "inspect",
        f4 = "hierarchy",
        f5 = "physics forces",
        f6 = "physics performance",
        c = "dump",  -- Alternative to F2
        i = "inspect",  -- Alternative to F3
        h = "hierarchy",  -- Alternative to F4
        p = "physics forces",  -- Alternative to F5
        space = "physics reset"
    }
end

-- Check if key is valid for shortcuts
function isValidShortcutKey(key)
    -- Function keys
    if key:match("^f%d+$") then
        local num = tonumber(key:sub(2))
        return num >= 1 and num <= 12
    end

    -- Numbers
    if key:match("^%d+$") then
        local num = tonumber(key)
        return num >= 1 and num <= 9
    end

    -- Letters
    if key:match("^[a-z]$") then
        return true
    end

    -- Special keys
    local specialKeys = {space = true, enter = true, tab = true, escape = true}
    return specialKeys[key] == true
end

-- Handle shortcut key presses
function handleShortcutKeys()
    if not console.shortcuts then return end

    for key, command in pairs(console.shortcuts) do
        local pressed = false

        -- Handle different key types
        if key:match("^f%d+$") then
            -- Function keys
            local num = tonumber(key:sub(2))
            if num >= 1 and num <= 12 then
                pressed = InputPressed and InputPressed("f" .. num)
            end
        elseif key:match("^%d+$") then
            -- Number keys
            pressed = InputPressed and InputPressed(key)
        elseif key:match("^[a-z]$") then
            -- Letter keys
            pressed = InputPressed and InputPressed(key)
        elseif key == "space" then
            pressed = InputPressed and InputPressed("space")
        elseif key == "enter" then
            pressed = InputPressed and InputPressed("return")
        elseif key == "tab" then
            pressed = InputPressed and InputPressed("tab")
        elseif key == "escape" then
            pressed = InputPressed and InputPressed("escape")
        end

        if pressed then
            addLog("INFO", "Shortcut triggered: " .. key:upper() .. " -> " .. command)
            executeCommand(command)
            return true -- Only handle one shortcut per frame
        end
    end

    return false
end

-- Save shortcuts to registry
function saveShortcuts()
    if not JsonEncode or not SetString then return end
    SetString("savegame.mod.console.shortcuts", JsonEncode(console.shortcuts or {}))
end

-- Load shortcuts from registry
function loadShortcuts()
    if not JsonDecode or not GetString then
        console.shortcuts = getDefaultShortcuts()
        return
    end

    local shortcutsData = GetString("savegame.mod.console.shortcuts")
    if shortcutsData then
        local success, shortcuts = pcall(JsonDecode, shortcutsData)
        if success and shortcuts then
            console.shortcuts = shortcuts
        else
            console.shortcuts = getDefaultShortcuts()
        end
    else
        console.shortcuts = getDefaultShortcuts()
    end
end

-- Handle font customization command
function handleFontCommand(args)
    if not args or args == "" then
        showFontHelp()
        return
    end

    local parts = {}
    for part in args:gmatch("%S+") do
        table.insert(parts, part)
    end

    local subcmd = parts[1]:lower()

    if subcmd == "size" then
        if #parts < 2 then
            addLog("ERROR", "Usage: font size <number>")
            addLog("INFO", "Current size: " .. console.fontSize)
            return
        end
        local size = tonumber(parts[2])
        if not size or size < 10 or size > 50 then
            addLog("ERROR", "Font size must be between 10 and 50")
            return
        end
        console.fontSize = size
        saveOptions()
        addLog("INFO", "Font size set to " .. size)

    elseif subcmd == "list" then
        listAvailableFonts()

    elseif subcmd == "set" then
        if #parts < 2 then
            addLog("ERROR", "Usage: font set <font_name>")
            return
        end
        local fontName = parts[2]
        if setFont(fontName) then
            addLog("INFO", "Font set to " .. fontName)
        else
            addLog("ERROR", "Font not available: " .. fontName)
            listAvailableFonts()
        end

    elseif subcmd == "reset" then
        console.fontSize = 20
        console.fontName = "regular.ttf"
        saveOptions()
        addLog("INFO", "Font settings reset to defaults")

    elseif subcmd == "current" then
        addLog("INFO", "Current font: " .. (console.fontName or "regular.ttf"))
        addLog("INFO", "Current size: " .. console.fontSize)

    else
        addLog("ERROR", "Unknown font subcommand: " .. subcmd)
        showFontHelp()
    end
end

-- Show font help
function showFontHelp()
    addLog("INFO", "Font Customization:")
    addLog("INFO", "font size <10-50> - Set font size")
    addLog("INFO", "font list - List available fonts")
    addLog("INFO", "font set <name> - Set font")
    addLog("INFO", "font current - Show current font settings")
    addLog("INFO", "font reset - Reset to defaults")
end

-- List available fonts
function listAvailableFonts()
    local fonts = {
        "regular.ttf",
        "bold.ttf",
        "italic.ttf",
        "bolditalic.ttf",
        "mono.ttf"
    }

    addLog("INFO", "Available fonts:")
    for _, font in ipairs(fonts) do
        local marker = (console.fontName == font) and " [CURRENT]" or ""
        addLog("INFO", "  " .. font .. marker)
    end
end

-- Set font
function setFont(fontName)
    local availableFonts = {
        "regular.ttf",
        "bold.ttf",
        "italic.ttf",
        "bolditalic.ttf",
        "mono.ttf"
    }

    for _, font in ipairs(availableFonts) do
        if font == fontName then
            console.fontName = fontName
            saveOptions()
            return true
        end
    end

    return false
end

-- Execute Lua code on selected object
function executeOnSelectedObject(code)
    local selectedBody = GetInt and GetInt("lasertool.selected_body") or 0
    local selectedShape = GetInt and GetInt("lasertool.selected_shape") or 0

    if selectedBody == 0 and selectedShape == 0 then
        addLog("ERROR", "No object selected. Use the laser pointer tool to select an object first.")
        return
    end

    if code == "" then
        addLog("ERROR", "Usage: exec <lua_code>")
        addLog("INFO", "Example: exec SetBodyVelocity(body, Vec(0, 10, 0))")
        return
    end

    -- Create a safe environment with selected object variables
    local env = {}
    for k, v in pairs(_G) do
        env[k] = v
    end

    -- Add selected object variables to environment
    env.body = selectedBody
    env.shape = selectedShape
    env.selectedBody = selectedBody
    env.selectedShape = selectedShape

    -- Set the environment for the code
    local func, err = loadstring(code)
    if func then
        setfenv(func, env)
        local success, result = pcall(func)
        if success then
            if result ~= nil then
                addLog("INFO", "Result: " .. tostring(result))
            else
                addLog("INFO", "Code executed successfully")
            end
        else
            addLog("ERROR", "Runtime error: " .. result)
        end
    else
        addLog("ERROR", "Syntax error: " .. err)
    end
end

-- Handle script management commands
function handleScriptCommand(parts)
    if #parts < 2 then
        addLog("ERROR", "Usage: script <save|load|list|delete|run> [name] [code]")
        return
    end

    local subcmd = parts[2]

    if subcmd == "save" then
        if #parts < 4 then
            addLog("ERROR", "Usage: script save <name> <code>")
            addLog("INFO", "Example: script save teleport SetBodyTransform(body, Transform(Vec(0,10,0), QuatEuler(0,0,0)))")
            return
        end
        local name = parts[3]
        local code = table.concat(parts, " ", 4)
        console.scripts[name] = {
            code = code,
            created = os and os.date("%Y-%m-%d %H:%M:%S") or "unknown",
            description = "" -- Could be extended to include descriptions
        }
        saveScripts()
        addLog("INFO", "Script '" .. name .. "' saved")

    elseif subcmd == "load" then
        if #parts < 3 then
            addLog("ERROR", "Usage: script load <name>")
            return
        end
        local name = parts[3]
        if console.scripts[name] then
            console.input = console.scripts[name].code
            addLog("INFO", "Script '" .. name .. "' loaded into input")
        else
            addLog("ERROR", "Script '" .. name .. "' not found")
        end

    elseif subcmd == "list" then
        if next(console.scripts) == nil then
            addLog("INFO", "No scripts saved")
        else
            addLog("INFO", "Saved scripts:")
            for name, script in pairs(console.scripts) do
                local desc = script.description or ""
                local type_indicator = script.created == "template" and "[TEMPLATE] " or ""
                addLog("INFO", "  " .. type_indicator .. name .. " - " .. desc)
            end
        end

    elseif subcmd == "templates" then
        addLog("INFO", "Available script templates:")
        for name, script in pairs(console.scripts) do
            if script.created == "template" then
                addLog("INFO", "  " .. name .. " - " .. (script.description or ""))
            end
        end
        addLog("INFO", "Use 'script load <name>' to load a template into the input field")

    elseif subcmd == "delete" then
        if #parts < 3 then
            addLog("ERROR", "Usage: script delete <name>")
            return
        end
        local name = parts[3]
        if console.scripts[name] then
            console.scripts[name] = nil
            saveScripts()
            addLog("INFO", "Script '" .. name .. "' deleted")
        else
            addLog("ERROR", "Script '" .. name .. "' not found")
        end

    elseif subcmd == "run" then
        if #parts < 3 then
            addLog("ERROR", "Usage: script run <name> [param1=value1 param2=value2 ...]")
            return
        end
        local name = parts[3]
        if console.scripts[name] then
            local code = console.scripts[name].code
            -- Parse parameters if provided
            if #parts > 3 then
                local params = {}
                for i = 4, #parts do
                    local param = parts[i]
                    local key, value = param:match("([^=]+)=(.+)")
                    if key and value then
                        params[key] = value
                    end
                end
                -- Replace parameter placeholders in code
                for key, value in pairs(params) do
                    code = code:gsub("%$" .. key .. "%$", value)
                    code = code:gsub("%$" .. key .. "%b[]", value) -- Handle array-style parameters
                end
            end
            executeLua(code)
        else
            addLog("ERROR", "Script '" .. name .. "' not found")
        end

    elseif subcmd == "export" then
        if #parts < 3 then
            addLog("ERROR", "Usage: script export <name> - Export script as JSON")
            addLog("INFO", "Or: script export all - Export all scripts as JSON")
            return
        end
        local name = parts[3]
        if name == "all" then
            -- Export all scripts
            if JsonEncode then
                local exportData = JsonEncode(console.scripts)
                addLog("INFO", "=== EXPORT ALL SCRIPTS ===")
                addLog("INFO", "Copy the JSON below to share your scripts:")
                addLog("INFO", exportData)
                addLog("INFO", "=== END EXPORT ===")
            else
                addLog("ERROR", "JSON encoding not available")
            end
        elseif console.scripts[name] then
            -- Export single script
            if JsonEncode then
                local exportData = JsonEncode({[name] = console.scripts[name]})
                addLog("INFO", "=== EXPORT SCRIPT: " .. name .. " ===")
                addLog("INFO", "Copy the JSON below to share this script:")
                addLog("INFO", exportData)
                addLog("INFO", "=== END EXPORT ===")
            else
                addLog("ERROR", "JSON encoding not available")
            end
        else
            addLog("ERROR", "Script '" .. name .. "' not found")
        end

    elseif subcmd == "import" then
        if #parts < 3 then
            addLog("ERROR", "Usage: script import <json_string> - Import scripts from JSON")
            return
        end
        local jsonStr = table.concat(parts, " ", 3)
        if JsonDecode then
            local success, importedScripts = pcall(JsonDecode, jsonStr)
            if success and importedScripts then
                local importedCount = 0
                for name, script in pairs(importedScripts) do
                    if type(script) == "table" and script.code then
                        -- Mark as imported and add timestamp
                        script.created = script.created or "imported"
                        script.imported_at = os and os.date("%Y-%m-%d %H:%M:%S") or "unknown"
                        console.scripts[name] = script
                        importedCount = importedCount + 1
                        addLog("INFO", "Imported script: " .. name)
                    end
                end
                if importedCount > 0 then
                    saveScripts()
                    addLog("INFO", "Successfully imported " .. importedCount .. " script(s)")
                else
                    addLog("ERROR", "No valid scripts found in JSON")
                end
            else
                addLog("ERROR", "Invalid JSON format")
            end
        else
            addLog("ERROR", "JSON decoding not available")
        end
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
        value = "home",
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
    -- Save font settings
    if console.fontName then
        SetString("savegame.mod.console.fontName", console.fontName)
    end
    if console.fontSize then
        SetFloat("savegame.mod.console.fontSize", console.fontSize)
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
    -- Load font settings
    console.fontName = GetString("savegame.mod.console.fontName") or "regular.ttf"
    console.fontSize = GetFloat("savegame.mod.console.fontSize") or 20
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

-- Save scripts library
function saveScripts()
    if not JsonEncode then return end -- Skip if not in Teardown environment
    SetString("savegame.mod.console.scripts", JsonEncode(console.scripts))
end

-- Load scripts library
function loadScripts()
    if JsonDecode and GetString then
        local scriptsData = GetString("savegame.mod.console.scripts")
        if scriptsData then
            local success, scripts = pcall(JsonDecode, scriptsData)
            if success and scripts then
                console.scripts = scripts
            end
        end
    end
    
    -- Initialize default templates if no user scripts exist
    -- (only add templates that don't already exist)
    if next(console.scripts) == nil then
        initializeScriptTemplates()
    else
        -- Add any missing templates to existing scripts
        local defaultTemplates = getDefaultTemplates()
        for name, template in pairs(defaultTemplates) do
            if not console.scripts[name] then
                console.scripts[name] = template
            end
        end
    end
end

-- Get default script templates
function getDefaultTemplates()
    return {
        -- Physics manipulation templates
        ["teleport_up"] = {
            code = "if body ~= 0 then SetBodyTransform(body, Transform(VecAdd(GetBodyTransform(body).pos, Vec(0, 5, 0)), GetBodyTransform(body).rot)) end",
            created = "template",
            description = "Teleport selected body 5 units up"
        },
        ["launch_forward"] = {
            code = "if body ~= 0 then SetBodyVelocity(body, Vec(0, 0, 20)) end",
            created = "template",
            description = "Launch selected body forward at 20 m/s"
        },
        ["freeze_body"] = {
            code = "if body ~= 0 then SetBodyDynamic(body, false) end",
            created = "template",
            description = "Make selected body static (freeze it)"
        },
        ["unfreeze_body"] = {
            code = "if body ~= 0 then SetBodyDynamic(body, true) end",
            created = "template",
            description = "Make selected body dynamic (unfreeze it)"
        },
        ["increase_mass"] = {
            code = "if body ~= 0 then SetBodyMass(body, (GetBodyMass(body) or 1) * 2) end",
            created = "template",
            description = "Double the mass of selected body"
        },
        ["decrease_mass"] = {
            code = "if body ~= 0 then SetBodyMass(body, (GetBodyMass(body) or 1) * 0.5) end",
            created = "template",
            description = "Halve the mass of selected body"
        },
        
        -- Visual effects templates
        ["make_glow"] = {
            code = "if shape ~= 0 then SetShapeEmissiveScale(shape, 5.0) end",
            created = "template",
            description = "Make selected shape glow brightly"
        },
        ["remove_glow"] = {
            code = "if shape ~= 0 then SetShapeEmissiveScale(shape, 0.0) end",
            created = "template",
            description = "Remove glow from selected shape"
        },
        ["highlight_red"] = {
            code = "if body ~= 0 then DrawBodyOutline(body, 1.0) elseif shape ~= 0 then DrawShapeOutline(shape, 1, 0, 0, 1.0) end",
            created = "template",
            description = "Highlight selected object in red"
        },
        
        -- Utility templates
        ["get_info"] = {
            code = "if body ~= 0 then print('Body:', body, 'Mass:', GetBodyMass(body), 'Dynamic:', IsBodyDynamic(body)) elseif shape ~= 0 then print('Shape:', shape, 'Size:', GetShapeSize(shape)) end",
            created = "template",
            description = "Print basic info about selected object"
        },
        ["clone_object"] = {
            code = "if body ~= 0 then local t = GetBodyTransform(body); Spawn('body', t) elseif shape ~= 0 then local t = GetShapeWorldTransform(shape); Spawn('shape', t) end",
            created = "template",
            description = "Create a copy of selected object at same position"
        },
        ["delete_object"] = {
            code = "if body ~= 0 then Delete(body) elseif shape ~= 0 then Delete(shape) end",
            created = "template",
            description = "Delete selected object"
        }
    }
end

-- Initialize default script templates
function initializeScriptTemplates()
    console.scripts = getDefaultTemplates()
    
    -- Save the templates if persistence is available
    if JsonEncode and SetString then
        saveScripts()
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
        UiFont(console.fontName or "regular.ttf", console.fontSize)
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