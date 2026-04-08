# Gatherly

## Developer Setup Instructions

Before running the app locally, you need to manually configure your environment variables and Firebase keys using the file I provided to you directly. Please follow these steps carefully:

1. **Add the `.env` file**
   - Take the `.env` file that I shared with you.
   - Place this file directly inside the **root directory** of the project (i.e., `Event_management_app/.env`).
   - *Note: This file contains secret keys and is intentionally ignored by Git.*

2. **Add the Firebase config file (Android)**
   - Take the `google-services.json` file I shared with you.
   - Place it inside the `android/app/` directory (i.e., `Event_management_app/android/app/google-services.json`).
   - *Note: This file connects the app to Firebase. It's also ignored by Git for security.*

3. **Install Dependencies**
   - Open your terminal in the project root folder.
   - Run `flutter pub get` to download the installed packages.

Once those files are in place, you can simply run `flutter run` on your emulator or physical device. If you see Firebase failing to initialize, double-check that the files are placed in the exact directories mentioned above.