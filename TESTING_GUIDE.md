# Globgram P2P Chat Application - Testing Guide

## Setup and Testing Instructions

### Step 1: Running the Application
1. Open two browser tabs to test P2P communication
2. Navigate to `http://localhost:8081` in both tabs

### Step 2: Basic Testing
1. **First Tab**: 
   - Create a room (e.g., "testroom")
   - Copy the room ID

2. **Second Tab**:
   - Enter the same room ID
   - Join the room

3. **Verify Connection**:
   - Both tabs should show "Connected" status
   - You should see a peer join notification

### Step 3: Messaging Test
1. Send a message from Tab 1
2. Verify it appears in Tab 2
3. Send a message from Tab 2
4. Verify it appears in Tab 1
5. Verify that messages are not duplicated or showing up in the same tab they were sent from

### Step 4: Language Settings Test
1. Go to Settings in either tab
2. Change language to Farsi (fa) or Spanish (es)
3. Verify UI updates with correct translation
4. Test RTL layout with Farsi language

### Troubleshooting
If you encounter any issues:
1. Check browser console for errors
2. Verify both tabs are on the same room ID
3. Try refreshing both tabs and rejoining the room
4. Make sure your browser supports WebRTC (Chrome or Firefox recommended)

## Expected Behavior
- Messages should only appear in the recipient's tab, not the sender's
- Connection status should update correctly
- UI should adapt to language changes (including RTL for Farsi)
- No 404 errors for missing assets in the console
