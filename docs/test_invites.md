# Invitation UI Test Guide

> **Deprecated.** This guide describes legacy invite flows. For the current 3-layer architecture, see [REFACTOR_ARCHITECTURE.md](phase2/REFACTOR_ARCHITECTURE.md) and the bases/invites feature under `lib/features/bases/`.

## Quick Test Steps

### 1. Start the App
```bash
cd moonbase_skeleton
flutter run
```

### 2. Test Invitation Creation

1. **Sign In**
   - Enter any nickname (e.g., "Alice")
   - Tap "Sign In"

2. **Create a Base**
   - Use the sidebar to create a base
   - Enter base name (e.g., "Test Base")
   - Verify base is created

3. **Access Invites Screen**
   - Tap the group icon (👥) in the app bar
   - Should navigate to invites screen for the selected base

4. **Create an Invite**
   - Tap "Create Invite" button
   - Optionally enter max uses (e.g., "3")
   - Tap "Create"
   - Verify invite code is generated and shown in snackbar
   - Tap "Copy" to copy the code

### 3. Test Invitation Redemption

1. **Create Second User**
   - Close the app
   - Restart the app
   - Sign in with different nickname (e.g., "Bob")

2. **Join Base via Invite**
   - Open sidebar (swipe from left)
   - Tap "Join Base" button
   - Enter the invite code from step 2.4
   - Tap "Join"
   - Verify success message

3. **Verify Base Access**
   - Check that the base appears in Bob's base list
   - Select the base
   - Verify Bob can access the chat

### 4. Test Invitation Management

1. **View Invite Details**
   - Go back to Alice's account
   - Navigate to invites screen
   - Tap on an invite to view details
   - Verify all information is displayed correctly

2. **Test Invite Limits**
   - Create an invite with max uses = 1
   - Have Bob join using that invite
   - Try to have a third user join with same code
   - Verify it fails with appropriate error

3. **Test Copy Functionality**
   - Tap "Copy Code" in invite details
   - Verify code is copied to clipboard
   - Paste in another app to confirm

## Expected Behavior

### ✅ **Working Features:**
- **Invite Creation**: Generate unique invite codes
- **Invite Redemption**: Join bases using invite codes
- **Base Access**: New members can access base and chat
- **Invite Management**: View and manage invite details
- **Copy to Clipboard**: Easy sharing of invite codes
- **Usage Tracking**: Track how many times invites are used
- **Error Handling**: Proper validation and error messages

### ✅ **UI Elements:**
- **Invites Screen**: Dedicated screen for invite management
- **Create Dialog**: Form for creating new invites
- **Invite List**: Display all invites for a base
- **Invite Details**: Detailed view of invite information
- **Copy Buttons**: Easy code copying functionality
- **Status Indicators**: Visual status of invite validity

## Testing Scenarios

### **Basic Flow**
1. Alice creates base
2. Alice creates invite
3. Bob joins with invite code
4. Both users can chat in the same base

### **Multiple Users**
1. Alice creates base
2. Alice creates multiple invites
3. Bob, Charlie, and David join
4. All four users can chat together

### **Invite Limits**
1. Alice creates invite with max uses = 2
2. Bob and Charlie join successfully
3. David tries to join - should fail
4. Verify appropriate error message

### **Error Cases**
1. Try to join with invalid invite code
2. Try to join with expired invite
3. Try to join with depleted invite
4. Try to create invite without selecting base

## Technical Verification

### Run Tests
```bash
# Invites repository tests
flutter test test/services/invites_repository_test.dart

# Integration tests (includes invite functionality)
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

### **Invitation UI Features**
- **Invites Screen**: Complete screen for managing invites
- **Create Invite Dialog**: Form with validation
- **Invite List**: Display all invites with status
- **Invite Details**: Detailed view with copy functionality
- **Navigation**: Easy access from home screen

### **Integration Points**
- **Home Screen**: Group icon in app bar
- **Sidebar**: Join base functionality
- **Router**: Proper navigation to invites screen
- **Providers**: State management for invites

### **User Experience**
- **Easy Access**: One tap to manage invites
- **Visual Feedback**: Status indicators and success messages
- **Copy Functionality**: Easy sharing of invite codes
- **Error Handling**: Clear error messages and validation

## Next Steps

Once invitation functionality is working, you can extend it with:
- **Invite Expiration**: Set expiration dates for invites
- **Invite Analytics**: Track invite usage patterns
- **Bulk Operations**: Create multiple invites at once
- **Invite Templates**: Pre-configured invite settings
- **QR Code Generation**: Generate QR codes for invites
