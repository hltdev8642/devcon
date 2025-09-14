-- Laser Pointer Tool for Teardown
-- Allows selecting objects with a laser beam for console inspection

local tool = {
    selectedBody = 0,
    selectedShape = 0,
    laserRange = 100.0,
    laserColor = {1, 0, 0, 0.8}, -- Red laser
    outlineColor = {1, 0, 0, 0.5} -- Semi-transparent red outline
}

function init()
    -- Register the tool with the vox model
    RegisterTool("laserpointer", "Laser Pointer", "laserpointer.vox")
    SetBool("game.tool.laserpointer.enabled", true)
end

function tick(dt)
    -- Only work when this tool is selected
    if GetString("game.player.tool") ~= "laserpointer" then
        return
    end

    -- Get player camera transform
    local cameraTransform = GetPlayerCameraTransform()
    local cameraPos = cameraTransform.pos

    -- Get camera forward direction (negative Z in camera space)
    local cameraDir = TransformToParentVec(cameraTransform, Vec(0, 0, -1))

    -- Perform raycast to find objects
    local hit, dist, normal, shape = QueryRaycast(cameraPos, cameraDir, tool.laserRange)

    if hit then
        local hitPoint = VecAdd(cameraPos, VecScale(cameraDir, dist))

        -- Draw laser beam
        DrawLine(cameraPos, hitPoint, tool.laserColor[1], tool.laserColor[2], tool.laserColor[3], tool.laserColor[4])

        -- Get the body that contains this shape
        local body = GetShapeBody(shape)

        -- Handle tool usage (click to select)
        if InputPressed("usetool") then
            -- Clear previous selection
            if tool.selectedBody ~= 0 then
                DrawBodyOutline(tool.selectedBody, 0) -- Remove outline
            end

            -- Select new object
            tool.selectedBody = body
            tool.selectedShape = shape

            -- Store selection in registry for console access
            SetInt("lasertool.selected_body", body)
            SetInt("lasertool.selected_shape", shape)

            -- Add red outline to selected body
            DrawBodyOutline(body, tool.outlineColor[4])
        end

        -- Draw outline on currently aimed body
        if body ~= tool.selectedBody then
            DrawBodyOutline(body, tool.outlineColor[4])
        end
    end

    -- Keep selected object outlined
    if tool.selectedBody ~= 0 then
        DrawBodyOutline(tool.selectedBody, tool.outlineColor[4])
    end
end

function draw()
    -- Tool UI could go here if needed
end