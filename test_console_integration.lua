-- Test script for laser tool and console integration
-- This script validates that the dump and exec commands work correctly

print("Testing Laser Tool Console Integration...")

-- Simulate selecting an object (normally done by laser tool)
SetInt("lasertool.selected_body", 1)  -- Simulate selecting body with handle 1
SetInt("lasertool.selected_shape", 2) -- Simulate selecting shape with handle 2

print("Simulated object selection complete")

-- Test dump command
print("Testing dump command...")
dumpSelectedObject()

-- Test exec command with safe code
print("Testing exec command...")
executeOnSelectedObject("print('Selected body handle:', selectedBody)")
executeOnSelectedObject("print('Selected shape handle:', selectedShape)")
executeOnSelectedObject("print('Body transform:', GetBodyTransform(selectedBody))")

print("Console integration test complete!")