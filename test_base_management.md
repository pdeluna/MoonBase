# Base Management Test Guide

## Quick Test Steps

### 1. Start the App
```bash
cd moonbase_skeleton
flutter run
```

### 2. Test Base Creation and Management

1. **Sign In**
   - Enter any nickname (e.g., "Alice")
   - Tap "Sign In"

2. **Create Multiple Bases**
   - Use the sidebar to create bases
   - Create at least 2-3 bases with different names
   - Verify bases appear in the sidebar

3. **Test Base Selection**
   - Tap on different bases in the sidebar
   - Verify the selected base is highlighted
   - Check that the "Current Base" section updates

### 3. Test Base Owner Features

1. **Identify Owner Status**
   - Look for "Owner" badges on bases you created
   - These should appear below the base description

2. **Test Long-Press Menu**
   - Long-press on a base you own (has "Owner" badge)
   - Verify a bottom sheet appears with options:
     - "Rename Base"
     - "Delete Base"

3. **Test Base Renaming**
   - Long-press on a base you own
   - Tap "Rename Base"
   - Enter a new name and description
   - Tap "Save"
   - Verify the base name updates in the sidebar

4. **Test Base Deletion**
   - Long-press on a base you own
   - Tap "Delete Base"
   - Confirm the deletion in the dialog
   - Verify the base is removed from the sidebar

### 4. Test Non-Owner Limitations

1. **Join Another User's Base**
   - Create a second user (Bob)
   - Have Alice create an invite for one of her bases
   - Have Bob join using the invite code
   - Verify Bob can see the base but doesn't have "Owner" badge

2. **Test Non-Owner Restrictions**
   - Long-press on a base Bob doesn't own
   - Verify no menu appears (no long-press functionality)

### 5. Test Error Handling

1. **Test Invalid Operations**
   - Try to rename a base with empty name
   - Try to rename a base with very short name
   - Verify appropriate validation messages

2. **Test Deletion Confirmation**
   - Start deletion process
   - Cancel at the confirmation dialog
   - Verify base is not deleted

## Expected Behavior

### ✅ **Working Features:**
- **Base Creation**: Create new bases with names and descriptions
- **Base Selection**: Switch between bases seamlessly
- **Owner Identification**: Clear "Owner" badges for base owners
- **Long-Press Menu**: Context menu for base owners only
- **Base Renaming**: Update base names and descriptions
- **Base Deletion**: Permanently delete bases and all associated data
- **Permission Control**: Only owners can modify/delete their bases
- **Visual Feedback**: Clear indication of selected and owned bases

### ✅ **UI Elements:**
- **Owner Badge**: Small "Owner" label on owned bases
- **Long-Press Menu**: Bottom sheet with rename and delete options
- **Rename Dialog**: Form with name and description fields
- **Delete Confirmation**: Warning dialog with clear consequences
- **Success Messages**: Snackbar notifications for successful operations
- **Error Messages**: Clear error feedback for failed operations

## Testing Scenarios

### **Basic Flow**
1. Alice creates base "Work Team"
2. Alice long-presses on "Work Team"
3. Alice renames it to "Development Team"
4. Alice adds description "Software development team"
5. Verify changes are saved and visible

### **Deletion Flow**
1. Alice creates base "Test Base"
2. Alice long-presses on "Test Base"
3. Alice taps "Delete Base"
4. Alice confirms deletion
5. Verify "Test Base" is removed from list

### **Multi-User Scenario**
1. Alice creates base "Shared Project"
2. Alice creates invite for "Shared Project"
3. Bob joins "Shared Project" via invite
4. Bob can see the base but no "Owner" badge
5. Bob cannot long-press to modify the base
6. Alice can still modify/delete the base

### **Error Scenarios**
1. Try to rename with empty name → validation error
2. Try to rename with single character → validation error
3. Cancel deletion → base remains
4. Network error during update → error message

## Technical Verification

### Run Tests
```bash
# Bases repository tests
flutter test test/services/bases_repository_test.dart

# Integration tests
flutter test test/services/integration_test.dart
```

### Check Code Quality
```bash
# Linter
flutter analyze

# Format code
flutter format lib/
```

## Recent Implementation ✅

### **Base Management Features**
- **Long-Press Menu**: Context menu for base owners
- **Rename Functionality**: Update base names and descriptions
- **Delete Functionality**: Permanently remove bases
- **Owner Identification**: Visual badges for base owners
- **Permission Control**: Only owners can modify their bases

### **Repository Layer**
- **updateBase Method**: Update base information
- **deleteBase Method**: Remove base and all associated data
- **isOwner Method**: Check ownership permissions
- **Proper Validation**: Ensure only owners can modify bases

### **Provider Layer**
- **updateBase Method**: State management for base updates
- **deleteBase Method**: State management for base deletion
- **Real-time Updates**: UI updates immediately after changes

### **UI Layer**
- **Long-Press Detection**: Gesture recognition for context menus
- **Modal Bottom Sheet**: Clean interface for base options
- **Form Validation**: Input validation for rename operations
- **Confirmation Dialogs**: Safety measures for destructive actions

## User Experience

### **Intuitive Interaction**
- **Long-Press**: Natural gesture for context menus
- **Visual Feedback**: Clear indication of ownership and selection
- **Confirmation**: Safety measures prevent accidental deletions
- **Immediate Updates**: Changes reflect instantly in the UI

### **Accessibility**
- **Clear Labels**: Descriptive text for all actions
- **Color Coding**: Red for destructive actions
- **Icon Usage**: Visual cues for different operations
- **Error Messages**: Clear feedback for validation failures

## Next Steps

Once base management is working, you can extend it with:
- **Base Transfer**: Transfer ownership to another member
- **Base Archiving**: Archive instead of delete
- **Bulk Operations**: Select multiple bases for operations
- **Base Templates**: Pre-configured base settings
- **Base Analytics**: Usage statistics and insights
