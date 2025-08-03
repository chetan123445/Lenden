# Activity Tracking System

## Overview

The Activity Tracking System provides comprehensive logging of all user activities within the Lenden application. It tracks user actions across transactions, group activities, notes, and profile changes.

## Features

### Activity Types Tracked

#### Transaction Activities
- `transaction_created` - When a user creates a new transaction
- `transaction_cleared` - When a transaction is marked as cleared
- `partial_payment_made` - When a user makes a partial payment
- `partial_payment_received` - When a user receives a partial payment

#### Group Activities
- `group_created` - When a user creates a new group
- `group_joined` - When a user joins a group
- `group_left` - When a user leaves a group
- `member_added` - When a member is added to a group
- `member_removed` - When a member is removed from a group
- `expense_added` - When an expense is added to a group
- `expense_edited` - When an expense is edited
- `expense_deleted` - When an expense is deleted
- `expense_settled` - When an expense is settled

#### Note Activities
- `note_created` - When a user creates a note
- `note_edited` - When a user edits a note
- `note_deleted` - When a user deletes a note

#### Profile Activities
- `profile_updated` - When a user updates their profile
- `password_changed` - When a user changes their password
- `login` - When a user logs in
- `logout` - When a user logs out

## Backend Implementation

### Models

#### Activity Model (`models/activity.js`)
```javascript
{
  user: ObjectId,           // Reference to user
  type: String,             // Activity type
  title: String,            // Activity title
  description: String,      // Activity description
  metadata: Object,         // Additional data
  relatedTransaction: ObjectId,  // Reference to transaction
  relatedGroup: ObjectId,   // Reference to group
  relatedNote: ObjectId,    // Reference to note
  amount: Number,           // Amount involved (for financial activities)
  currency: String,         // Currency for financial activities
  ipAddress: String,        // IP address for security tracking
  userAgent: String,        // User agent for device tracking
  createdAt: Date,          // Timestamp
  updatedAt: Date           // Timestamp
}
```

### Controllers

#### Activity Controller (`controllers/activityController.js`)
- `getUserActivities()` - Get user activities with pagination and filtering
- `getActivityStats()` - Get activity statistics
- `logTransactionActivity()` - Log transaction-related activities
- `logGroupActivity()` - Log group-related activities
- `logNoteActivity()` - Log note-related activities
- `logProfileActivity()` - Log profile-related activities
- `cleanupOldActivities()` - Clean up old activities

### API Routes

#### Activity Routes
- `GET /api/activities` - Get user activities
- `GET /api/activities/stats` - Get activity statistics
- `DELETE /api/activities/cleanup` - Clean up old activities

## Frontend Implementation

### Activity Page (`lib/user/activity_page.dart`)

#### Features
- **Activity List**: Displays all user activities with pagination
- **Filtering**: Filter by activity type and date range
- **Statistics**: Shows activity summary and recent activity count
- **Search**: Search through activities
- **Refresh**: Pull-to-refresh functionality
- **Load More**: Infinite scrolling for large activity lists

#### UI Components
- Activity cards with icons and colors based on activity type
- Filter dialog with dropdown and date pickers
- Statistics cards showing total and recent activities
- Filter chips for active filters
- Empty state when no activities found

#### Activity Card Design
- **Icon**: Activity-specific icon with color coding
- **Title**: Activity title
- **Description**: Detailed description of the activity
- **Amount**: Financial amount (if applicable)
- **Timestamp**: Relative time (e.g., "2 hours ago")

## Integration

### Automatic Activity Logging

The system automatically logs activities when users perform actions:

1. **Transaction Creation**: Logged when users create transactions
2. **Group Operations**: Logged when users create/join/leave groups or manage expenses
3. **Note Operations**: Logged when users create/edit/delete notes
4. **Login**: Logged when users log in

### Manual Activity Logging

Developers can manually log activities using the helper functions:

```javascript
// Log transaction activity
await logTransactionActivity(userId, 'transaction_created', transaction);

// Log group activity
await logGroupActivity(userId, 'group_created', group);

// Log note activity
await logNoteActivity(userId, 'note_created', note);

// Log profile activity
await logProfileActivity(userId, 'login', { ipAddress: req.ip });
```

## Usage

### Accessing Activity Page

1. Navigate to the user dashboard
2. Open the menu drawer
3. Click on "Activity" option
4. View your activity history

### Filtering Activities

1. Click the filter icon in the app bar
2. Select activity type from dropdown
3. Choose date range using date pickers
4. Click "Apply" to filter activities

### Viewing Statistics

The activity page automatically displays:
- Total number of activities
- Recent activities (last 7 days)
- Activity breakdown by type

## Security & Privacy

- Activities are only visible to the user who performed them
- IP addresses and user agents are logged for security purposes
- Old activities can be cleaned up to manage storage
- All activity data is protected by authentication middleware

## Performance Considerations

- Activities are paginated (20 per page by default)
- Database indexes are optimized for efficient querying
- Activity cleanup can be scheduled to remove old entries
- Frontend implements infinite scrolling for better UX

## Future Enhancements

- Activity export functionality
- Activity notifications
- Activity sharing between users
- Advanced analytics and reporting
- Activity templates for common actions
- Integration with external logging services 