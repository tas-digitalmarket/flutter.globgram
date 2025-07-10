# P2P WebRTC Flow Correction

## مشکل حل شده
قبلاً ترتیب عملیات در `createRoom` درست نبود و این باعث می‌شد که peers در حالت "connecting" باقی بمانند.

## تغییرات اعمال شده

### 1. ترتیب صحیح عملیات در createRoom():
```dart
// ✅ ترتیب صحیح (جدید)
final offer = await _webRTCService.createOffer();
await _webRTCService.setLocalDescription(offer);
final roomId = await _signalingService.createRoom(offer);  // ← مهم
_isCaller = true;
_setupSignalingListeners(); // AFTER room creation
```

### 2. FirestoreSignalingService ساده‌سازی شد:
```dart
class FirestoreSignalingService {
  final _db = FirebaseFirestore.instance;

  Future<String> createRoom(RTCSessionDescription offer) async {
    final roomRef = _db.collection('rooms').doc();
    await roomRef.set({
      'offer': offer.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return roomRef.id;
  }

  Future<void> joinRoom(String roomId, RTCSessionDescription answer) async {
    final roomRef = _db.collection('rooms').doc(roomId);
    await roomRef.update({
      'answer': answer.toMap(),
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendIceCandidate(String roomId, RTCIceCandidate c, bool isCaller) async {
    await _db
        .collection('rooms')
        .doc(roomId)
        .collection('candidates')
        .doc(isCaller ? 'caller' : 'callee')
        .collection('list')
        .add(c.toMap());
  }

  // --- listeners ---
  Stream<RTCSessionDescription> onRemoteOffer(String roomId) =>
      _db.doc('rooms/$roomId').snapshots().where((s) =>
          s.data()?['offer'] != null).map((s) =>
          RTCSessionDescription(s['offer']['sdp'], s['offer']['type']));

  Stream<RTCSessionDescription> onRemoteAnswer(String roomId) =>
      _db.doc('rooms/$roomId').snapshots().where((s) =>
          s.data()?['answer'] != null).map((s) =>
          RTCSessionDescription(s['answer']['sdp'], s['answer']['type']));

  Stream<RTCIceCandidate> onRemoteIce(String roomId, bool isCaller) =>
      _db
          .collection('rooms/$roomId/candidates/${isCaller ? 'callee' : 'caller'}/list')
          .snapshots()
          .expand((q) => q.docChanges)
          .map((c) => RTCIceCandidate(
                c.doc['candidate'],
                c.doc['sdpMid'],
                c.doc['sdpMLineIndex'],
              ));
}
```

## فایل‌های تغییر یافته:

1. **`lib/core/services/p2p_connection_manager.dart`**
   - ترتیب createRoom اصلاح شد
   - `_isCaller = true` بعد از room creation

2. **`lib/core/services/p2p_manager.dart`**
   - همان تغییرات createRoom
   - کامنت "مهم" اضافه شد

3. **`lib/core/services/firestore_signaling_service.dart`**
   - کد ساده‌سازی شد
   - Stream listeners بهینه شدند
   - `_db` به جای `_firestore` استفاده شد

## ترتیب عملیات صحیح:

### Caller (Create Room):
1. Initialize WebRTC
2. Setup callbacks
3. Create data channel
4. **Create offer**
5. **Set local description**
6. **Create room in Firestore** ← مهم
7. Set `_isCaller = true`
8. Setup signaling listeners
9. Listen for answer and ICE

### Callee (Join Room):
1. Initialize WebRTC
2. Setup callbacks
3. Setup signaling listeners
4. Listen for offer
5. When offer received:
   - Set remote description
   - Create answer
   - Set local description
   - Send answer to Firestore

## انتظارات بعد از تغییرات:

✅ **SDP Exchange**: Offer و Answer درست در Firestore ذخیره می‌شوند
✅ **ICE Exchange**: ICE candidates بین peers تبادل می‌شوند
✅ **Connection State**: هر دو peer از "connecting" به "connected" می‌روند
✅ **Data Channel**: پیام‌ها از طریق WebRTC DataChannel ارسال می‌شوند
✅ **Real-time**: اتصال واقعی P2P برقرار می‌شود

## تست کردن:

```bash
# اجرای پروژه در کروم
flutter run -d chrome --web-port 8080

# دو پنجره باز کنید:
# 1. پنجره اول: Create Room
# 2. پنجره دوم: Join Room با همان Room ID
```

## نکات مهم:

- **ترتیب** بسیار مهم است: ابتدا room ایجاد شود، سپس listeners
- **Firestore rules** باید permissive باشند برای تست
- **Data channel** هم برای caller و هم callee درست تنظیم شده
- **ICE candidates** در مسیر صحیح (caller → callee و بالعکس) تبادل می‌شوند

این تغییرات باید مشکل "connecting state" را حل کنند و اتصال واقعی P2P برقرار شود.
