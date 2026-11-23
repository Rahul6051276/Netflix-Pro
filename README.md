# Netflix-Pro

Netflix Pro — Mobile और Android TV दोनों के लिए एक Flutter + Kotlin नेटिव मीडिया प्लेयर स्ट्रीमिंग ऐप।

## Platform Support
- **Mobile:** टच जेस्चर (सिंगल/डबल टैप, ब्राइटनेस और वॉल्यूम/ऑडियो बूस्ट स्वाइप), फ्रंट कैमरा/कटआउट सपोर्ट के साथ `Fit`, `Crop / Zoom`, और `Fill` मोड।
- **Android TV:** D-Pad / रिमोट नेविगेशन, फोकस-आधारित कंट्रोल्स, और साइड पैनल से स्ट्रीम सोर्स स्विचिंग।

## Branch & Repository Structure

- **Default Branch:** `main`

```text
Netflix-Pro/
├── .github/
│   └── workflows/          # APK build and release workflows
├── android/
│   └── app/
│       └── src/
│           └── main/       # Android manifest and app configuration
├── lib/                    # Flutter UI screens (including TV home screen)
├── native_android/
│   ├── CinemaPlayerActivity.kt
│   ├── CinemaPictureEffect.kt
│   ├── MainActivity.kt
│   └── activity_cinema_player.xml
├── Icon.png
└── pubspec.yaml
