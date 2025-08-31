# Chat Functionality Test Guide

## Quick Test Steps

### 1. Start the App
```bash
cd moonbase_skeleton
flutter run
```

### 2. Manual Testing Flow

1. **Sign In**
   - Enter any nickname (e.g., "TestUser")
   - Tap "Sign In"

2. **Create a Base**
   - Navigate to base creation
   - Enter base name (e.g., "Test Base")
   - Enter description (e.g., "Testing chat functionality")
   - Tap "Create Base"

3. **Access Chat**
   - Select your created base from the list
   - You should see the chat screen with "No messages yet. Start the conversation!"

4. **Send Messages**
   - Type a message in the composer (e.g., "Hello, world!")
   - Tap the send button or press Enter
   - Message should appear immediately
   - Send a few more messages to test

5. **Test Real-time Features**
   - Messages should appear instantly
   - Check timestamps on messages
   - Verify your messages appear on the right (blue), others on the left (gray)

6. **Test Persistence**
   - Close the app completely
   - Restart the app
   - Sign in with the same nickname
   - Select your base
   - Messages should still be there

### 3. Sidebar Functionality Testing ✅ **FIXED**

**Test Create Base from Sidebar:**
1. **Open Sidebar**: Swipe from left edge or tap the base icon in app bar
2. **Create Base**: Tap "Create Base" button in sidebar
3. **Enter Details**: Fill in base name in the dialog
4. **Verify**: Base should be created and appear in the list

**Test Join Base from Sidebar:**
1. **Open Sidebar**: Swipe from left edge or tap the base icon in app bar
2. **Join Base**: Tap "Join Base" button in sidebar
3. **Enter Code**: Fill in invite code in the dialog
4. **Verify**: Should join the base and appear in your list

**Test Base Switching:**
1. **Open Sidebar**: Swipe from left edge or tap the base icon in app bar
2. **Select Base**: Tap on any base in the list
3. **Verify**: Sidebar should close and selected base should be active
4. **Chat Context**: Chat should switch to the selected base

### 4. Expected Behavior

✅ **Working Features:**
- Message sending and display
- Real-time updates
- Message persistence across app restarts
- User identification (shows user ID)
- Timestamps
- Empty state when no messages
- Error handling for invalid states
- **Sidebar create base functionality** ✅ **FIXED**
- **Sidebar join base functionality** ✅ **FIXED**
- **Base switching from sidebar** ✅ **WORKING**

✅ **UI Elements:**
- Chat screen with app bar showing base name
- Message bubbles with proper alignment
- Composer with text field and send button
- Loading states
- Error messages
- **Swipeable sidebar with working buttons** ✅ **FIXED**

### 5. Troubleshooting

**If messages don't appear:**
- Check that you're signed in
- Verify a base is selected
- Check console for error messages

**If sidebar doesn't work:**
- Try swiping from the left edge of the screen
- Tap the base icon in the app bar
- Check that the sidebar opens and shows your bases

**If create base doesn't work:**
- Make sure you're signed in
- Check that the dialog appears when tapping "Create Base"
- Verify the base name field is filled

**If join base doesn't work:**
- Make sure you have a valid invite code
- Check that the dialog appears when tapping "Join Base"
- Verify the invite code field is filled

**If app crashes:**
- Check Flutter console for stack traces
- Verify all dependencies are installed (`flutter pub get`)

**If tests fail:**
- Run `flutter test test/services/chat_repository_test.dart`
- Check for any linter errors

### 6. Advanced Testing

**Test Multiple Users:**
1. Create a second profile with different nickname
2. Create an invite for your base
3. Sign in as second user and redeem invite
4. Both users should be able to chat in the same base

**Test Message Types:**
- Text messages (currently implemented)
- Media messages (structure ready, UI pending)
- System messages (structure ready, UI pending)

**Test Sidebar Interactions:**
- Swipe to open/close sidebar
- Tap overlay to close sidebar
- Test base selection from sidebar
- Test create/join base dialogs

## Technical Verification

### Run Tests
```bash
# Chat repository tests
flutter test test/services/chat_repository_test.dart

# Integration tests (includes chat)
flutter test test/services/integration_test.dart

# All tests
flutter test
```

### Check Code Quality
```bash
# Linter
flutter analyze

# Format code
flutter format lib/
```

## Recent Fixes ✅

### **Fixed Sidebar Functionality**
- **Create Base Button**: Now shows proper dialog instead of placeholder message
- **Join Base Button**: Now shows proper dialog with invite code input
- **Base Creation**: Fully functional with validation and error handling
- **Base Joining**: Uses existing `redeemInvite` functionality
- **Dialog Integration**: Proper form validation and user feedback

### **Implementation Details**
- Added proper dialog implementations in `SwipableBaseSidebar`
- Integrated with existing `basesProvider` and `invitesProvider`
- Added form validation and error handling
- Proper cleanup of text controllers
- Success/error feedback via snackbars

## Next Steps

Once basic chat is working, you can extend it with:
- Message editing
- Message deletion
- Media attachments
- Typing indicators
- Read receipts
- Message reactions
- Threaded replies
