// Quick fix for P2P messaging - debugging test
// Check if the current mechanism is showing unique peer IDs per tab

console.log('=== P2P DEBUGGING ===');

// Function to check localStorage for peer IDs
function checkStoredPeerIDs() {
  const keys = Object.keys(localStorage);
  console.log('LocalStorage keys:', keys);
  
  keys.forEach(key => {
    if (key.includes('peer') || key.includes('globgram')) {
      console.log(`${key}: ${localStorage.getItem(key)}`);
    }
  });
}

checkStoredPeerIDs();

// Monitor BroadcastChannel events
if (typeof BroadcastChannel !== 'undefined') {
  const testChannel = new BroadcastChannel('globgram_room_TEST');
  
  testChannel.onmessage = function(event) {
    console.log('BroadcastChannel message received:', event.data);
  };
  
  // Send a test message
  setTimeout(() => {
    testChannel.postMessage(JSON.stringify({
      type: 'test',
      from: 'debug_' + Date.now(),
      timestamp: new Date().toISOString()
    }));
  }, 1000);
}
