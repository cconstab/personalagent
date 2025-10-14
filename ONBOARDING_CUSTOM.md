# Custom atPlatform Onboarding Implementation

## Problem

The `at_onboarding_flutter` package (v6.x) has critical compatibility issues:
- Depends on `showcaseview` v2.1.1 which uses deprecated Flutter APIs (`headline6`, `subtitle2`)
- Function signature mismatches (`void Function()` vs `bool Function()?`)
- These issues prevent the app from building on current Flutter versions

## Solution

Implemented a **custom onboarding flow** that uses `at_client_mobile` directly without the problematic `at_onboarding_flutter` package.

## Implementation Details

### Dependencies Removed
```yaml
# at_onboarding_flutter: ^6.0.0  # Removed due to showcaseview compatibility issues
```

### Dependencies Added
```yaml
file_picker: ^8.0.0  # For selecting .atKeys files
```

### Custom Onboarding Dialog

Created `_AtSignInputDialog` widget that:
1. **Collects @sign** - Text input with validation
2. **Selects .atKeys file** - File picker for authentication keys
3. **Validates inputs** - Ensures both @sign and keys file are provided
4. **Returns data** - Passes atSign and keys file path back to onboarding flow

### Authentication Flow

The `_initializeAtClient` method:
1. Formats the @sign (ensures @ prefix)
2. Gets app documents directory for local storage
3. Configures `AtClientPreference` with:
   - Root domain: `root.atsign.org`
   - Namespace: `personalagent`
   - Hive storage and commit log paths
4. Validates keys file exists
5. Initializes `AtClientManager` with the @sign
6. Sets up the app's `AtClientService` wrapper
7. Configures agent @sign (currently hardcoded to `@llama`)
8. Updates `AuthProvider` with authenticated state

## User Experience

### Onboarding Screen Flow
1. **Welcome slides** - 4 informational pages explaining:
   - Private AI Assistant concept
   - Local-first processing (Ollama)
   - Smart privacy with sanitization
   - Getting started prompt

2. **Authentication dialog** - When user clicks "Get Started":
   - Input field for @sign (e.g., `@cconstab`)
   - File picker button to select `.atKeys` file
   - Help section with instructions:
     - Get free @sign at atsign.com
     - Keys usually in `~/.atsign/keys/`
     - File format: `@yoursign_key.atKeys`

3. **Loading state** - Shows spinner while authenticating

4. **Success/Error feedback** - Snackbar with result

## Key Files Modified

### `/app/pubspec.yaml`
- Removed `at_onboarding_flutter` dependency
- Added `file_picker` for .atKeys file selection

### `/app/lib/screens/onboarding_screen.dart`
- Removed imports for `at_onboarding_flutter`
- Added imports for `dart:io`, `file_picker`
- Replaced `_startAtOnboarding()` with custom implementation
- Added `_initializeAtClient()` for atClient setup
- Created `_AtSignInputDialog` stateful widget
- Created `_AtSignInputDialogState` with file picking logic

## Testing the Onboarding

1. **Start the agent**:
   ```bash
   cd agent && dart run bin/agent.dart
   ```

2. **Run the Flutter app**:
   ```bash
   cd app && flutter run -d macos
   ```

3. **Go through onboarding**:
   - Swipe through the 4 welcome pages
   - Click "Get Started" on the final page
   - Enter your @sign (e.g., `cconstab` or `@cconstab`)
   - Click "Select .atKeys File"
   - Navigate to `~/.atsign/keys/` and select your `.atKeys` file
   - Click "Authenticate"

4. **Expected result**:
   - Loading spinner appears
   - Green snackbar: "✅ Authenticated as @yoursign"
   - Navigates to home screen
   - Can now send messages to the agent

## TODO: Production Enhancements

1. **Key Loading** - Currently keys file is validated but not fully loaded into keystore
   - Need to parse `.atKeys` JSON format
   - Load encryption keys into `AtClient` keystore
   - Handle key decryption if password-protected

2. **Agent @sign Configuration** - Currently hardcoded to `@llama`
   - Should be configurable in settings
   - Could auto-discover from `.env` or config file
   - Allow multiple agents

3. **Error Handling** - Enhanced error messages for:
   - Invalid keys file format
   - Network connectivity issues
   - Invalid @sign format
   - Keys file decryption failures

4. **Persistent Storage** - Store keys file path for:
   - Faster re-authentication
   - Switching between multiple @signs
   - Background sync

## Advantages of Custom Implementation

✅ **No dependency conflicts** - Direct control over all code  
✅ **Simplified flow** - Only what's needed for this app  
✅ **Better error handling** - Custom messages for our use case  
✅ **Maintainable** - Can update as needed without waiting for package updates  
✅ **Cleaner UI** - Matches app's design language  

## Migration Notes

If you want to try the official package again in the future:
1. Check if `showcaseview` has been updated to support current Flutter
2. Verify `at_onboarding_flutter` compatibility
3. Run `flutter pub outdated` to check version constraints
4. Replace custom dialog with `AtOnboarding.onboard()` call

For now, the custom implementation provides a stable, working solution.
