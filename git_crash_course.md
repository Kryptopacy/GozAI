# 🚀 Git & GitHub Crash Course: The Post-Hackathon Guide

First off, congratulations on completing the hackathon! Since judges are reviewing your `main` branch, the safest way to continue adding features without risking your current submission is by using **Branches**. 

When judging is over, you can easily merge these branches back into `main`. Let's break down exactly how to do that.

---

## 📖 1. The Core Dictionary
* **Repository (Repo):** Your project folder that is being tracked by Git.
* **Commit:** A saved "snapshot" of your code at a specific point in time.
* **Branch:** An independent line of development. The default is `main`. Creating a new branch creates a copy of `main` where you can experiment freely.
* **Push:** Uploading your local commits (saved snapshots) to GitHub so they're backed up and visible online.
* **Pull:** Downloading the latest changes from GitHub to your local computer.
* **Merge:** Taking the changes from one branch (e.g., your new feature) and combining them into another (e.g., `main`).

---

## 🛠️ 2. Step-by-Step: The Safe Workflow

Whenever you want to add a new feature or fix a bug, follow this loop:

### Step 1: Make sure you're starting from the latest `main`
```bash
git checkout main
git pull origin main
```

### Step 2: Create a new branch and switch to it
Give your branch a descriptive name (e.g., `feature/payment-integration` or `fix/nav-bar`).
```bash
git checkout -b your-branch-name
```
*(The `-b` flag means "create and switch to" this new branch).*

### Step 3: Code!
Make your changes, test them, and do your thing. Your `main` branch is untouched and perfectly safe.

### Step 4: Save (Commit) your changes
When you hit a good stopping point, save a snapshot:
```bash
# Stage all changed files to be saved
git add .

# Create the saved snapshot with a descriptive message
git commit -m "Added a new cool feature"
```

### Step 5: Push your new branch to GitHub
Because this is a brand new branch that GitHub doesn't know about yet, you have to push it slightly differently the first time:
```bash
git push -u origin your-branch-name
```
*(For all future updates to this same branch, you can just type `git push`)*

---

## 🔀 3. How to Merge Your Branch into `main`

Once judging is completely over, or when a feature is 100% finished and tested, here is how you merge it back into `main`.

### Method A: The Easy Way (via GitHub.com)
This is highly recommended because it gives you a visual overview of your changes.
1. Go to your repository page on GitHub.
2. At the top, you should see a yellow/green alert that says your branch had recent pushes, with a button saying **"Compare & pull request"**. Click it.
3. Review the changes to make sure everything looks correct, then click **"Create pull request"**.
4. Once created, click the big green **"Merge pull request"** button, then "Confirm merge".
5. Finally, go back to VS Code/Terminal to update your local computer:
   ```bash
   git checkout main
   git pull origin main
   ```

### Method B: The Hacker Way (via Terminal)
If you want to do it all locally without leaving VS Code:
1. Switch back to your `main` branch:
   ```bash
   git checkout main
   ```
2. Make sure it's up to date:
   ```bash
   git pull origin main
   ```
3. **Merge** your feature branch into it:
   ```bash
   git merge your-branch-name
   ```
4. Push the newly updated `main` branch up to GitHub:
   ```bash
   git push origin main
   ```

---

## 🩹 4. Dealing with Merge Conflicts

Sometimes, Git doesn't know how to merge because the exact same line of code was edited in both `main` and your branch. This is a **Merge Conflict**.

Don't panic! Here's how to fix it:
1. Git will tell you which files have a conflict. Open them in VS Code.
2. VS Code will highlight the conflicting sections with options like **"Accept Current Change"**, **"Accept Incoming Change"**, or **"Accept Both Changes"**.
3. Click whichever option keeps the correct code (or manually edit the file to have the exact code you want).
4. Save the file.
5. Tell Git you fixed it by committing:
   ```bash
   git add .
   git commit -m "Resolved merge conflicts"
   git push
   ```

---

## ⚡ 5. Quick Reference Commands

| Command | What it does |
|---------|--------------|
| `git status` | Shows what files you've changed and what branch you're on. |
| `git branch` | Lists all your local branches. (`*` marks your current one). |
| `git log` | Shows history of commits. |
| `git restore <file>` | Undoes uncommitted changes to a specific file. |
| `git reset --hard` | ⚠️ Wipes ALL uncommitted changes in your working directory. |
