<div align="center">

# 💸 Student Monthly Expense Manager

A Flutter + Firebase app to help students track income, expenses and monthly budget.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)

</div>

---

## 📖 About

Student Monthly Expense Manager helps students manage their money in one place. Add income and expenses, set a monthly budget, see reports with charts, and export them as PDF.

## ✨ Features

- 🔐 Register / Login with Firebase Authentication
- ➕ Add income and expense transactions
- 📋 View and manage all expenses
- 🎯 Set a monthly budget
- 📊 Reports with charts
- 📄 Export reports as PDF
- 🌗 Light / Dark theme
- ☁️ Real-time cloud sync with Cloud Firestore

## 📸 Screenshots

| Login | Home | Add Transaction |
|:---:|:---:|:---:|
| ![Login](screenshots/login.png) | ![Home](screenshots/home.png) | ![Add](screenshots/add.png) |

| Budget | Report | Dark Mode |
|:---:|:---:|:---:|
| ![Budget](screenshots/budget.png) | ![Report](screenshots/report.png) | ![Dark](screenshots/dark.png) |

## 🛠️ Tech Stack

| Category | Technology |
|---|---|
| Framework | Flutter (Dart) |
| Authentication | Firebase Auth |
| Database | Cloud Firestore |
| State Management | Provider |
| Charts | fl_chart |
| PDF Export | pdf, path_provider, open_file |
| Local Storage | shared_preferences |

## 📁 Project Structure

```
lib/
├── main.dart
├── firebase_options.dart
├── models/       # data models
├── providers/    # theme provider
├── screens/      # login, register, home, expenses, budget, report, settings
├── services/     # auth and firestore services
└── utils/        # helper functions
```

## 🚀 Getting Started

### Requirements
- Flutter SDK
- Android phone with USB debugging on, or an emulator

### Installation

```bash
git clone https://github.com/samiual67/<repo-name>.git
cd stusent_expense_manager
flutter pub get
```

### Run on Android phone

```bash
flutter devices
flutter run -d <device-id>
```

### Run on Chrome

```bash
flutter run -d chrome
```

> ⚠️ PDF export (open_file) works on Android and may not work on web.

## 👥 Team Members

| | Member 1 | Member 2 |
|---|---|---|
| **Name** | Md. Samiual Mia | Md Hasan Ruhanee Ruhan |
| **Student ID** | 0322410105101001 | 0322410105101010 |
| **Responsibility** | UI/UX design, Flutter frontend development, Firebase integration | Database management, testing, documentation, report preparation |
| **GitHub** | [@samiual67](https://github.com/samiual67) | |

---

<div align="center">⭐ Star this repo if you found it useful!</div>