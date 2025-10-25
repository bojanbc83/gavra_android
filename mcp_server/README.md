# Gavra Firestore MCP Server

This MCP server provides tools to interact with your Gavra Android Firebase/Firestore database.

## Setup Instructions

### 1. Install Dependencies

```bash
cd mcp_server
npm install
```

### 2. Firebase Authentication Setup

You need to set up Firebase Admin SDK authentication. You have several options:

#### Option A: Service Account Key (Recommended for development)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `gavra-notif-20250920162521`
3. Go to Project Settings > Service accounts
4. Click "Generate new private key"
5. Save the JSON file as `serviceAccountKey.json` in the `mcp_server/src` directory
6. Update the Firebase initialization in `src/firebase-service.ts`:

```typescript
admin.initializeApp({
  credential: admin.credential.cert(require('./serviceAccountKey.json')),
  databaseURL: 'https://gavra-notif-20250920162521-default-rtdb.firebaseio.com',
});
```

#### Option B: Application Default Credentials (Recommended for production)

1. Install Google Cloud SDK
2. Run: `gcloud auth application-default login`
3. Set environment variable: `GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json`

### 3. Build and Run

```bash
# Build the TypeScript code
npm run build

# Run the server
npm start

# For development with auto-reload
npm run dev
```

## Available Tools

### Passenger Management (Putnici)
- `get_putnici` - Get all active passengers
- `add_putnik` - Add a new passenger
- `update_putnik` - Update an existing passenger
- `delete_putnik` - Soft delete a passenger

### Daily Passengers (Dnevni Putnici)
- `get_dnevni_putnici` - Get daily passengers for a specific date
- `add_dnevni_putnik` - Add a daily passenger entry
- `update_dnevni_putnik` - Update a daily passenger entry
- `delete_dnevni_putnik` - Delete a daily passenger entry

### GPS Locations (GPS Lokacije)
- `get_gps_lokacije` - Get GPS locations for a date range
- `add_gps_lokacija` - Add a GPS location entry

### Analytics
- `get_daily_statistics` - Get daily statistics for passengers and revenue
- `get_monthly_statistics` - Get monthly statistics

### Real-time Data
- `stream_putnici` - Get real-time snapshot of passengers
- `stream_dnevni_putnici` - Get real-time snapshot of daily passengers

## Usage with MCP Client

Add this server to your MCP client configuration:

```json
{
  "mcpServers": {
    "gavra-firestore": {
      "command": "node",
      "args": ["path/to/gavra_android/mcp_server/dist/index.js"]
    }
  }
}
```

## Environment Variables

You can set these environment variables:

- `GOOGLE_APPLICATION_CREDENTIALS` - Path to service account key file
- `FIREBASE_PROJECT_ID` - Firebase project ID (defaults to gavra-notif-20250920162521)

## Security Notes

1. Never commit `serviceAccountKey.json` to version control
2. Use environment variables for production deployments
3. Consider implementing rate limiting for production use
4. The server runs with admin privileges - use carefully

## Example Usage

### Get all passengers
```json
{
  "tool": "get_putnici",
  "arguments": {}
}
```

### Add a new passenger
```json
{
  "tool": "add_putnik",
  "arguments": {
    "ime": "Marko",
    "prezime": "Petrović",
    "telefon": "+381123456789",
    "adresa": "Knez Mihailova 42, Beograd"
  }
}
```

### Get daily statistics
```json
{
  "tool": "get_daily_statistics",
  "arguments": {
    "datum": "2025-10-25"
  }
}
```

## Troubleshooting

1. **Permission denied**: Check your Firebase service account permissions
2. **Module not found**: Run `npm install` and `npm run build`
3. **Connection issues**: Verify your Firebase project configuration
4. **Authentication errors**: Check your service account key and credentials

## Integration with Flutter App

This MCP server mirrors the functionality of your Flutter app's `FirestoreService`. You can use it to:

1. Monitor your app's database in real-time
2. Perform bulk operations
3. Generate reports and analytics
4. Debug data issues
5. Backup and restore data

The tool schemas match your Dart models for consistency.