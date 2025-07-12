# 🔍 مراحل عیب‌یابی WebRTC "Connecting" مشکل

## ✅ چک‌لیست تشخیص مشکل:

### 1. **بررسی console مرورگر**
- F12 را فشار دهید
- به Console tab بروید  
- دنبال خطاهای مربوط به WebRTC، Firestore یا ICE باشید

### 2. **بررسی WebRTC Internals**
- آدرس `chrome://webrtc-internals/` را در Chrome باز کنید
- وضعیت ICE connection را بررسی کنید
- ببینید آیا ICE candidates تولید می‌شوند یا نه

### 3. **بررسی Firestore Rules**
```javascript
// باید rules زیر در Firestore تنظیم شده باشد:
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true; // برای تست
    }
  }
}
```

### 4. **تست مراحل به صورت دستی:**

#### مرحله 1: ایجاد اتاق (Caller)
1. پنجره اول مرورگر را باز کنید
2. روی "Create Room" کلیک کنید  
3. Room ID را کپی کنید
4. در Console باید این لاگ‌ها را ببینید:
   - `🏠 Creating room as caller`
   - `✅ Room created in Firestore: [ROOM_ID]`
   - `👂 Setting up signaling listeners...`

#### مرحله 2: پیوستن به اتاق (Callee)  
1. پنجره دوم مرورگر را باز کنید
2. Room ID را وارد کنید
3. روی "Join Room" کلیک کنید
4. باید این لاگ‌ها را ببینید:
   - `🚪 Joining room: [ROOM_ID] as callee`
   - `📥 Received remote offer`
   - `📤 Sent answer`

#### مرحله 3: تبادل ICE Candidates
- در هر دو پنجره باید لاگ‌های ICE ببینید:
  - `🧊 Sending ICE candidate`
  - `🧊 Received remote ICE candidate`

#### مرحله 4: اتصال برقرار شدن
- وقتی اتصال برقرار شود باید ببینید:
  - `🎉 P2P connection established!`
  - `📡 Data channel opened - ready for messaging`

## 🚨 مشکلات رایج و راه‌حل:

### مشکل 1: Firebase/Firestore خطا
**علامت**: خطاهای مربوط به Firebase در console
**راه‌حل**: 
- از اینترنت مطمئن شوید
- Firebase project configuration را چک کنید
- Firestore rules را بررسی کنید

### مشکل 2: ICE Gathering فشل
**علامت**: هیچ ICE candidate در لاگ نیست
**راه‌حل**:
- STUN server های دیگر امتحان کنید
- اتصال اینترنت را چک کنید  
- Firewall یا VPN را غیرفعال کنید

### مشکل 3: SDP Exchange مشکل
**علامت**: Offer یا Answer تبادل نمی‌شود
**راه‌حل**:
- Firestore console را چک کنید
- Rules دسترسی را بررسی کنید
- Network connectivity را تست کنید

### مشکل 4: DataChannel نمی‌آید
**علامت**: WebRTC connected ولی data channel open نمی‌شود
**راه‌حل**:
- مطمئن شوید که caller data channel می‌سازد
- Callee باید data channel را دریافت کند

## 🔧 کمک‌های فوری:

### اگر هنوز connecting است:
1. **هر دو پنجره را refresh کنید**
2. **برنامه را restart کنید**
3. **Room ID جدید بسازید**
4. **Chrome یا Edge استفاده کنید** (نه Firefox)
5. **اینترنت connection را چک کنید**

### برای debugging بیشتر:
1. F12 → Console → Network tab
2. دنبال Firestore requests باشید
3. `chrome://webrtc-internals/` را چک کنید
4. مطمئن شوید که هیچ ad-blocker یا extension فعال نیست

این مراحل را دنبال کنید و نتیجه را به من بگویید تا بتوانم مشکل دقیق را پیدا کنم.
