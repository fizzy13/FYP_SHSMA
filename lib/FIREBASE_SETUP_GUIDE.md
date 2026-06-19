# Firebase User Information Setup Guide

## Overview
This guide explains how the user profile editing system works and how to set up Firebase Firestore for storing user information.

## Database Structure

### Firestore Collection: `users_info`

The user information is stored in a Firestore collection called `users_info` with the following structure:

```
users_info/
├── [user_email_1]/
│   ├── email: "user1@example.com"
│   ├── phoneNumber: "+1 (555) 123-4567"
│   ├── address: "123 Main St, City, State"
│   ├── fullName: "John Doe"
│   ├── createdAt: "2024-01-15T10:30:00.000Z"
│   └── updatedAt: "2024-01-15T10:30:00.000Z"
│
├── [user_email_2]/
│   ├── email: "user2@example.com"
│   ├── phoneNumber: "+1 (555) 987-6543"
│   ├── address: "456 Oak Ave, Town, State"
│   ├── fullName: "Jane Smith"
│   ├── createdAt: "2024-01-16T14:20:00.000Z"
│   └── updatedAt: "2024-01-16T14:20:00.000Z"
```

**Key Points:**
- Each document is keyed by the user's email address (makes it easy to query by email)
- The email field is duplicated in the document for reference
- `createdAt` and `updatedAt` are ISO 8601 formatted timestamps
- All user information is linked to the authenticated email

## Implementation Details

### Files Created/Modified

1. **`lib/models/user_model.dart`** - UserInfo model class
   - Defines the data structure for user information
   - Methods: `toMap()` (for Firestore), `fromMap()` (from Firestore), `copyWith()` (for updates)

2. **`lib/services/user_info_service.dart`** - UserInfoService class
   - Handles all Firestore operations for user information
   - Methods:
     - `saveUserInfo()` - Save or update user information
     - `getUserInfoByEmail()` - Retrieve user data by email
     - `updateUserInfo()` - Update specific fields
     - `deleteUserInfo()` - Delete user information
     - `getUserInfoStream()` - Real-time updates stream
     - `userInfoExists()` - Check if user exists

3. **`lib/screens/edit_profile_screen.dart`** - EditProfileScreen widget
   - UI for editing user information
   - Validates input fields
   - Saves changes to Firestore
   - Returns updated UserInfo to ProfileScreen

4. **`lib/auth_service.dart`** - Updated AuthService
   - Added user registration method that creates Firestore record
   - Added methods to get/update user information
   - Added account deletion method

5. **`lib/screens/profile_screen.dart`** - Updated ProfileScreen
   - Loads user information on screen initialization
   - Displays data from Firestore
   - EDIT button now navigates to EditProfileScreen
   - Settings icon also navigates to edit profile

## Firebase Firestore Security Rules

To properly protect your user data, add these security rules in Firebase Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow users to read/write only their own data
    match /users_info/{email} {
      allow read, write: if request.auth.token.email == email;
    }
    
    // You can add additional collections here if needed
    match /{document=**} {
      allow read, write: if false; // Deny all by default
    }
  }
}
```

**Security Rule Explanation:**
- Users can only read/write their own document (matched by email)
- `request.auth.token.email` ensures the authenticated user's email matches the document ID
- This prevents users from accessing other users' information

## How to Use

### 1. During User Registration
When a user creates an account, use the updated `register()` method in AuthService:

```dart
final user = await authService.register(
  email: 'user@example.com',
  password: 'password123',
  fullName: 'John Doe',
  phoneNumber: '+1-555-1234',
  address: '123 Main St',
);
```

This automatically creates a Firestore document in `users_info` collection.

### 2. During User Login
After successful login, the ProfileScreen automatically:
- Loads user information from Firestore
- Displays it in the profile screen
- Updates when user clicks EDIT

### 3. Editing Profile
1. User clicks EDIT button or settings icon
2. EditProfileScreen opens with current information
3. User modifies the fields
4. Clicks SAVE CHANGES
5. Data is updated in Firestore
6. ProfileScreen refreshes with new data

### 4. Retrieving User Information
You can retrieve user information anywhere in your app:

```dart
final userInfoService = UserInfoService();

// Get user info by email (one-time fetch)
final userInfo = await userInfoService.getUserInfoByEmail('user@example.com');

// Get real-time updates (for live data sync)
userInfoService.getUserInfoStream('user@example.com').listen((userInfo) {
  // Update UI whenever data changes
  setState(() {
    this.userInfo = userInfo;
  });
});
```

## Firebase Console Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project "shsma-db2b4"
3. Navigate to **Firestore Database**
4. Create a new collection (if not exists)
   - Collection ID: `users_info`
5. Go to **Rules** tab
6. Replace the default rules with the security rules shown above
7. Publish the rules

## Testing

To test the implementation:

1. **Register a new user** with email, password, and profile information
2. **Login** - Profile screen should display the saved information
3. **Click EDIT** - EditProfileScreen opens with current data
4. **Modify fields** and click SAVE
5. **Verify changes** - ProfileScreen shows updated information
6. **Check Firestore** - In Firebase Console, navigate to `users_info` collection to verify data

## Error Handling

The implementation includes error handling for:
- Empty form fields
- Firestore save/read failures
- Network errors

Users see appropriate error messages in SnackBars.

## Real-time Updates

The ProfileScreen can be enhanced to use real-time updates by replacing the one-time fetch with a stream:

```dart
StreamBuilder<UserInfo?>(
  stream: _userInfoService.getUserInfoStream(_userInfo?.email ?? ''),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      _userInfo = snapshot.data;
      return // build UI with _userInfo
    }
    return Loading();
  },
)
```

## Troubleshooting

### Issue: "Permission denied" error when saving
- **Solution**: Check Firebase Security Rules - ensure they allow the authenticated user to write to their own document

### Issue: User data not loading
- **Solution**: Ensure Firestore is enabled in Firebase Console and the user has an authenticated email

### Issue: Changes not reflecting in real-time
- **Solution**: Use `getUserInfoStream()` instead of one-time `getUserInfoByEmail()` for real-time updates

## Next Steps

1. Add image upload functionality for profile pictures
2. Implement email verification
3. Add activity logging when profile is updated
4. Create admin dashboard to view all user information (with proper security rules)
