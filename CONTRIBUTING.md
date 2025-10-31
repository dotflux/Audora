# 🌀 Contributing to Audora

Welcome to **Audora** an open, community-driven Flutter music streaming app.  
We’re thrilled that you want to contribute! 💙

Whether you’re fixing a bug, improving UI, adding new features, or updating docs **every contribution matters**.

---

## 🧭 Table of Contents

1. [Getting Started](#getting-started)
2. [Setting Up the Project](#setting-up-the-project)
3. [Branching Model](#branching-model)
4. [Contribution Workflow](#contribution-workflow)
5. [Coding Standards](#coding-standards)
6. [Commit Guidelines](#commit-guidelines)
7. [Pull Requests](#pull-requests)
8. [Reporting Bugs](#reporting-bugs)
9. [Feature Requests](#feature-requests)
10. [Code of Conduct](#code-of-conduct)

---

## 🧠 Getting Started

Before you start contributing, make sure you have:

- Flutter (latest stable version)
- Android Studio or VS Code with Flutter/Dart plugins
- A GitHub account

If you’re new to open-source, check out this guide first:  
👉 [How to Contribute to Open Source](https://opensource.guide/how-to-contribute/)

---

## ⚙️ Setting Up the Project

1. **Fork the repository**  
   Click the "Fork" button on the top right of the repo page.

2. **Clone your fork locally**

   ```bash
   git clone https://github.com/<your-username>/Audora
   cd Audora
   ```

3. **Add the upstream repo**

   ```bash
   git remote add upstream https://github.com/dotflux/Audora
   ```

4. **Install dependencies**

   ```bash
   flutter pub get
   ```

5. **Run the app**
   ```bash
   flutter run
   ```

---

## 🌿 Branching Model

We use a simple branching model for clean collaboration.

| Branch | Purpose                                              |
| ------ | ---------------------------------------------------- |
| `main` | Stable, production-ready code                        |
| `dev`  | Internal development and testing                     |
| `open` | Open community contributions (pull requests go here) |

> **Note:** Never push directly to `main`.  
> Always create your feature branch from `open`.

---

## 🔁 Contribution Workflow

1. Create a new branch from `open`:

   ```bash
   git checkout open
   git pull upstream open
   git checkout -b feature/your-feature-name
   ```

2. Make your changes, then run the formatter:

   ```bash
   dart format .
   ```

3. Commit your work (see [Commit Guidelines](#commit-guidelines)).

4. Push to your fork:

   ```bash
   git push origin feature/your-feature-name
   ```

5. Open a Pull Request (PR) targeting **`open`**.

---

## 🧩 Coding Standards

- Follow **Flutter’s official style guide**:  
  https://dart.dev/guides/language/effective-dart/style
- Use meaningful variable and class names.
- Keep widgets small and reusable.
- Run the analyzer before submitting:
  ```bash
  flutter analyze
  ```

---

## ✍️ Commit Guidelines

Use clear and descriptive commit messages:

```
feat: add playlist delete confirmation
fix: waveform overlaps on song change
chore: update dependencies
docs: improve README setup steps
```

Follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

---

## 🚀 Pull Requests

Before submitting your PR:

- Ensure your code compiles with no errors.
- Confirm formatting via `dart format .`
- Check you’re merging into **`open`**, not `main`.

PR title examples:

- ✅ `feat: new library sorting options`
- 🧰 `fix: crash on loading cached tracks`
- 🧱 `refactor: improved AudioManager stream handling`

PRs are reviewed by maintainers once approved, they’ll be merged into `dev` or `main` after internal testing.

---

## 🐞 Reporting Bugs

Found something off? Open an issue with:

- Clear title and description
- Steps to reproduce
- Logs or screenshots (if possible)

Use the **"Bug Report"** issue template if available.

---

## 💡 Feature Requests

Have an idea to improve Audora?  
Open an issue titled **“Feature Request: <your idea>”** and describe:

- The problem you’re solving
- Your proposed solution
- Optional mockups or examples

---

## 🤝 Code of Conduct

We follow a zero-tolerance policy for harassment, disrespect, or hate speech.

By participating in this project, you agree to uphold our:  
👉 [Code of Conduct](CODE_OF_CONDUCT.md)

Let’s keep Audora open, kind, and welcoming 💙

---

## 💬 Need Help?

Join discussions, ask questions, or share ideas in:

- GitHub Discussions (if enabled)
- Issue comments
- Pull Request threads

---

## 🧱 License

By contributing, you agree that your work will be licensed under the same license as the project (see `LICENSE`).

---

**Thank you for helping build Audora 🎧**  
Together, we’re crafting an open, modern, and community-driven music experience.
