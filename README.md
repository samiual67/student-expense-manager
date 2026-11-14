<div align="center">

<img src="android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" width="96" alt="App icon" />

# Student Monthly Expense Manager

**A premium Flutter + Firebase app that helps students track income, control spending and reach savings goals.**

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://www.android.com)
[![Material 3](https://img.shields.io/badge/Material%203-6C4DF6?style=for-the-badge&logo=materialdesign&logoColor=white)](https://m3.material.io)

![Version](https://img.shields.io/badge/version-1.0.0-6C4DF6?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Web-blue?style=flat-square)
![Status](https://img.shields.io/badge/status-active-success?style=flat-square)
![Made with Love](https://img.shields.io/badge/made%20with-%E2%9D%A4-ff5d6c?style=flat-square)

[Features](#-features) •
[Screenshots](#-screenshots) •
[Tech Stack](#-tech-stack) •
[Getting Started](#-getting-started) •
[Architecture](#-architecture) •
[Team](#-team)

</div>

---

## 📖 About

**Student Monthly Expense Manager** is built for the way students actually spend money: small daily payments like rickshaw, chai and lunch, a fixed monthly pocket money, and a constant worry about running out before the month ends.

Instead of just listing transactions, the app tells you **how much you can safely spend today**, shows **where your money goes**, warns you **before you cross your budget**, and helps you **save towards a goal**, all in a clean, modern interface with light and dark themes.

---

## ✨ Features

### 💰 Smart money tracking
| | Feature | Description |
|---|---|---|
| ➕ | **Income & Expense** | Add, edit and delete transactions with title, amount, category, date and note |
| ⚡ | **Quick Add** | One tap adds common expenses (Rickshaw, Bus, Chai, Snacks, Lunch, Recharge) |
| 🌤️ | **Safe to spend today** | Daily limit calculated from your budget and the days left in the month |
| 💡 | **Spending insights** | Weekly trend vs last week, top category and average spend per day |

### 🎯 Budget & savings
| | Feature | Description |
|---|---|---|
| 🎯 | **Monthly budget** | Set a budget with a live progress ring (turns orange and red as you approach the limit) |
| 🔔 | **Budget alerts** | Warnings when you cross spending thresholds |
| 🐷 | **Savings tracker** | Monthly and all-time savings at a glance |
| 🏁 | **Savings goal** | Name a goal, set a target and watch the progress bar fill |

### 📊 Reports & history
| | Feature | Description |
|---|---|---|
| 📋 | **Transaction history** | Search, filter by category and month, sort by date or amount |
| 👆 | **Swipe to delete** | Swipe left on any record, tap to edit |
| 🍩 | **Donut chart** | Spending breakdown by category with percentages |
| 📈 | **6-month bar chart** | Income vs expense trend |
| 📄 | **PDF export** | Download a monthly report |

### 🎨 Experience
| | Feature | Description |
|---|---|---|
| 🌗 | **Light / Dark mode** | Premium purple theme, saved across launches |
| 👤 | **Editable profile** | Name, phone, university, department and student ID |
| 🔐 | **Secure auth** | Firebase Authentication with email/password and password reset |
| ☁️ | **Real-time sync** | Cloud Firestore keeps your data safe and up to date |

---

## 📸 Screenshots

<div align="center">

| Login | Home | Add Transaction |
|:---:|:---:|:---:|
| <img src="screenshots/login.png" width="220" /> | <img src="screenshots/home.png" width="220" /> | <img src="screenshots/add.png" width="220" /> |

| History | Budget | Report |
|:---:|:---:|:---:|
| <img src="screenshots/history.png" width="220" /> | <img src="screenshots/budget.png" width="220" /> | <img src="screenshots/report.png" width="220" /> |

| Settings | Dark Mode |
|:---:|:---:|
| <img src="screenshots/settings.png" width="220" /> | <img src="screenshots/dark.png" width="220" /> |

</div>

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter 3 (Dart, Material 3) |
| **Authentication** | Firebase Authentication |
| **Database** | Cloud Firestore (real-time streams) |
| **State management** | Provider |
| **Charts** | fl_chart |
| **PDF export** | pdf, path_provider, open_file |
| **Local storage** | shared_preferences |
| **Formatting** | intl |

---

## 🏗️ Architecture

```
lib/
├── main.dart                 # App entry, global premium theme, AuthGate
├── firebase_options.dart     # Firebase configuration
├── models/
│   └── tx_item.dart          # Transaction model
├── providers/
│   └── theme_provider.dart   # Light / dark theme state
├── services/
│   ├── auth_service.dart     # Register, login, logout, reset password
│   └── firestore_service.dart# Transactions, budgets, goals
├── screens/
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── home_screen.dart
│   ├── add_transaction_screen.dart
│   ├── expenses_screen.dart  # History
│   ├── budget_screen.dart
│   ├── report_screen.dart
│   └── settings_screen.dart
├── widgets/
│   └── insights_card.dart    # Spending insights
└── utils/
    └── helpers.dart          # Categories, icons, colors, calculations
```

### 🗄️ Firestore data model

```
users/{uid}
 ├── name, email, phone, university, department, studentId
 ├── expenses/{id}   → title, amount, category, date, note
 ├── incomes/{id}    → title, amount, category, date, note
 ├── budgets/{YYYY-MM} → amount
 └── goals/main      → title, target
```

Each user can only access their own data.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable)
- Android Studio or VS Code
- An Android phone with USB debugging on, or an emulator
- A Firebase project (Authentication + Cloud Firestore enabled)

### 1. Clone the repository
```bash
git clone https://github.com/samiual67/student-expense-manager.git
cd student-expense-manager
```

### 2. Install packages
```bash
flutter pub get
```

### 3. Connect Firebase
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```
This generates `lib/firebase_options.dart` and `android/app/google-services.json` for your own Firebase project.

### 4. Run the app

**On an Android phone**
```bash
flutter devices
flutter run -d <device-id>
```

**On Chrome**
```bash
flutter run -d chrome
```

> ⚠️ PDF export uses `open_file`, which works on Android but may not work on web.

### Useful commands
| Command | Purpose |
|---|---|
| `r` | Hot reload |
| `R` | Hot restart |
| `flutter analyze` | Check code for errors |
| `flutter clean` | Fix stubborn build problems |
| `flutter build apk --release` | Build a release APK |

---

## 🗺️ Roadmap

- [x] Premium Material 3 redesign (light and dark)
- [x] Safe to spend today
- [x] Quick Add
- [x] Spending insights
- [x] Editable profile
- [ ] Splash screen and onboarding
- [ ] Category-wise budget limits
- [ ] Wallet balances (Cash, bKash, Bank)
- [ ] Bangla / English language switch
- [ ] CSV export

---

## 👥 Team

<div align="center">

| | **Member 1** | **Member 2** |
|:---:|:---:|:---:|
| **Name** | Md. Samiual Mia | Md Hasan Ruhanee Ruhan |
| **Student ID** | 0322410105101001 | 0322410105101010 |
| **Role** | UI/UX design, Flutter frontend development, Firebase integration | Database management, testing, documentation, report preparation |
| **GitHub** | [@samiual67](https://github.com/samiual67) | |

</div>

---

## 📄 License

This project was created for academic purposes as part of a university course.

---

<div align="center">

**Made with ❤️ using Flutter and Firebase**

⭐ Star this repo if you found it useful!

</div>
