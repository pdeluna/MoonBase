# Git Alias Cheat Sheet

These aliases save keystrokes and simplify common workflows.

## 🔧 Setup Aliases

Run each command once in your terminal:

```bash
git config --global alias.co checkout
git config --global alias.cb "checkout -b"
git config --global alias.br branch
git config --global alias.cm "commit -m"
git config --global alias.st status
git config --global alias.ps "push -u origin"
```

---

## 🚀 What They Do

- `git co <branch>` → shorthand for `git checkout <branch>`  
- `git cb <new-branch>` → shorthand for `git checkout -b <new-branch>`  
- `git br` → shorthand for `git branch`  
- `git cm "message"` → shorthand for `git commit -m "message"`  
- `git st` → shorthand for `git status`  
- `git ps <branch>` → shorthand for `git push -u origin <branch>`  

---

## 📌 Example Workflow with Aliases

```bash
# 1. Create & switch to a new branch
git cb feat/minimal-auth-and-entry-flow

# 2. Make some edits... then stage them
git add .

# 3. Commit them
git cm "feat: implement nickname entry screen"

# 4. Push branch to GitHub
git ps feat/minimal-auth-and-entry-flow
```

After the first push, you can simply use `git push` and `git pull`.
