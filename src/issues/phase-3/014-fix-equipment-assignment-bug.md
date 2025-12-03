# Issue 014 - Fix Equipment Assignment Bug in Character Generation

## Current Behavior
There is a documented bug in `src/main.c` at line 218:
```c
/* FIXME: unit gear assigned in error when multiple items are   */
```
This indicates that the equipment assignment system has issues when dealing with multiple items of the same type or multiple item assignments. The exact symptoms need to be investigated, but this suggests:
- Items may be overwriting each other in the gear array
- Item counts may not be properly tracked
- Memory management issues with item assignment
- Possible array bounds issues

## Intended Behavior
The equipment assignment system should correctly:
- Assign multiple different items to available gear slots
- Handle multiple quantities of the same item type
- Properly track item counts in the `gear_count` array
- Manage memory safely when assigning item pointers
- Prevent array overflow in the gear array
- Handle edge cases like full inventory

## Suggested Implementation Steps

### Phase 3A: Bug Investigation and Analysis
1. **Investigate Current Bug Behavior**
   - Add debug logging to equipment assignment functions
   - Create test cases with multiple item generation
   - Identify specific failure modes and error patterns
   - Document current vs. expected behavior

2. **Analyze Equipment Assignment Code**
   - Review `src/main.c` equipment assignment logic
   - Check `gear[]` and `gear_count[]` array management
   - Examine memory allocation/deallocation for items
   - Identify race conditions or logic errors

3. **Create Reproduction Test Cases**
   ```c
   void test_multiple_item_assignment() {
       Unit* character = init_unit();
       
       // Test case 1: Multiple different items
       assign_equipment(character, SWORD);
       assign_equipment(character, SHIELD);
       assign_equipment(character, LEATHER_ARMOR);
       
       // Test case 2: Multiple same items
       assign_equipment(character, ARROW, 20);
       assign_equipment(character, ARROW, 10); // Should add to existing
       
       // Test case 3: Full inventory
       for (int i = 0; i < 25; i++) {
           assign_equipment(character, DAGGER); // Should handle overflow
       }
   }
   ```

### Phase 3B: Core Bug Fixes
4. **Fix Gear Array Management**
   - Ensure gear slot allocation doesn't overwrite existing items
   - Implement proper slot finding algorithm:
   ```c
   int find_available_gear_slot(const Unit* character) {
       for (int i = 0; i < MAX_GEAR_SLOTS; i++) {
           if (character->gear[i] == NULL) {
               return i;
           }
       }
       return -1; // No available slots
   }
   
   int find_item_in_gear(const Unit* character, ItemType item_type) {
       for (int i = 0; i < MAX_GEAR_SLOTS; i++) {
           if (character->gear[i] != NULL && 
               character->gear[i]->item_type == item_type) {
               return i;
           }
       }
       return -1; // Item not found
   }
   ```

5. **Fix Item Count Management**
   - Properly handle stackable vs. non-stackable items
   - Fix gear_count array synchronization:
   ```c
   bool assign_item_to_character(Unit* character, Item* item, int quantity) {
       if (!character || !item || quantity <= 0) {
           return false;
       }
       
       // Check if item is stackable and already exists
       if (item->is_stackable) {
           int existing_slot = find_item_in_gear(character, item->item_type);
           if (existing_slot >= 0) {
               character->gear_count[existing_slot] += quantity;
               return true;
           }
       }
       
       // Find new slot for item
       int available_slot = find_available_gear_slot(character);
       if (available_slot < 0) {
           return false; // Inventory full
       }
       
       character->gear[available_slot] = item;
       character->gear_count[available_slot] = quantity;
       return true;
   }
   ```

6. **Fix Memory Management Issues**
   - Ensure proper item allocation and deallocation
   - Fix potential memory leaks in item assignment
   - Add reference counting for shared items
   - Implement safe item removal functions

### Phase 3C: Enhanced Equipment Management
7. **Implement Robust Equipment Assignment System**
   ```c
   typedef enum AssignmentResult {
       ASSIGNMENT_SUCCESS,
       ASSIGNMENT_INVENTORY_FULL,
       ASSIGNMENT_INVALID_ITEM,
       ASSIGNMENT_MEMORY_ERROR,
       ASSIGNMENT_SLOT_CONFLICT
   } AssignmentResult;
   
   AssignmentResult assign_equipment_safe(Unit* character, 
                                         Item* item, 
                                         int quantity,
                                         bool allow_stacking);
   ```

8. **Add Equipment Validation**
   - Implement gear array consistency checks
   - Add validation functions for character equipment state
   - Create debugging utilities for equipment inspection
   ```c
   bool validate_character_equipment(const Unit* character);
   void print_character_equipment_debug(const Unit* character);
   int count_total_items(const Unit* character);
   ```

9. **Implement Equipment Organization**
   - Add item sorting and organization functions
   - Implement equipment type categorization (weapons, armor, misc)
   - Add functions to find specific equipment types
   - Create equipment summary generation

### Phase 3D: Testing and Validation
10. **Create Comprehensive Test Suite**
    - Unit tests for all equipment assignment functions
    - Edge case testing (full inventory, null items, etc.)
    - Memory leak detection tests
    - Performance testing with large equipment sets

11. **Add Error Handling and Logging**
    - Implement detailed error reporting for assignment failures
    - Add logging for equipment operations
    - Create diagnostic functions for troubleshooting
    - Add assertions and safety checks

12. **Integration Testing**
    - Test equipment assignment with character generation
    - Verify compatibility with existing equipment generation
    - Test save/load functionality with fixed equipment system
    - Validate UI display with corrected equipment data

## Dependencies
- Access to current buggy code for investigation
- Debug logging infrastructure
- Unit testing framework
- Memory debugging tools (valgrind, sanitizers)
- Character generation system

## Verification Criteria
- All documented FIXME comments resolved
- Multiple item assignment works correctly without overwrites
- gear[] and gear_count[] arrays remain synchronized
- No memory leaks in equipment assignment
- Equipment assignment handles edge cases gracefully
- Character generation produces valid equipment sets consistently
- All test cases pass including edge cases

## Estimated Complexity
**Medium** - This is a bug fix with some system enhancement:
- Code investigation and debugging
- Array management and bounds checking
- Memory management safety
- Error handling and validation
- Comprehensive testing

## Related Issues
- Issue 006: Equipment generation system (provides context)
- Issue 013: Weapon generation system (will use fixed assignment)
- Future: Inventory management UI
- Future: Equipment trading and modification

## Notes
This is a critical bug that affects character generation reliability. Priority should be on identifying and fixing the core issue while improving overall robustness. The fix should maintain backward compatibility with existing character data where possible.