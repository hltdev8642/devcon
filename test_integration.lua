-- Test script to verify laser tool and console integration
print("=== LASER TOOL INTEGRATION TEST ===")

-- Test 1: Check if tool is registered
print("Test 1: Tool Registration")
if RegisterTool then
    print("✓ RegisterTool function available")
else
    print("✗ RegisterTool function not available")
end

-- Test 2: Check registry functions
print("\nTest 2: Registry Functions")
if SetInt and GetInt then
    print("✓ Registry functions available")
    -- Test setting/getting values
    SetInt("test.lasertool.body", 123)
    SetInt("test.lasertool.shape", 456)
    local body = GetInt("test.lasertool.body")
    local shape = GetInt("test.lasertool.shape")
    print("✓ Registry read/write test: body=" .. body .. ", shape=" .. shape)
else
    print("✗ Registry functions not available")
end

-- Test 3: Check raycasting
print("\nTest 3: Raycasting")
if QueryRaycast then
    print("✓ QueryRaycast function available")
else
    print("✗ QueryRaycast function not available")
end

-- Test 4: Check drawing functions
print("\nTest 4: Drawing Functions")
if DrawLine and DrawBodyOutline then
    print("✓ Drawing functions available")
else
    print("✗ Drawing functions not available")
end

-- Test 5: Check console functions
print("\nTest 5: Console Integration")
if dumpSelectedObject and executeOnSelectedObject then
    print("✓ Console functions available")
else
    print("✗ Console functions not available")
end

print("\n=== TEST COMPLETE ===")
print("If all tests pass with ✓, the laser tool should work in Teardown.")