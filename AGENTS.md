# Agent Permissions & Safety Rules
    
## 1. Strictly Read-Only Source Code Files (No Code Mutations)
- **Do not write, edit, overwrite, or delete project source code files.**
- Never call file modification tools (`write_to_file`, `replace_file_content`) on implementation source code files (e.g. `*.vhd`,`*.v`, `*.c`, `*.h`, `*.tcl`, `*.xdc`, `*.py`, build scripts, or Makefiles).
- All proposed source code changes must be presented in chat for user review and manual application.

## 2. Allowed Documentation Mutations (.md Files Only)
- The agent **IS PERMITTED** to read, create, edit, and overwrite Markdown documentation files (`*.md`), including:
  - Project plans and documentation under `docs/`
  - `README.md`
  - Other `*.md` reports or specifications.

## 3. No Git Mutations or Write Operations
- **Do not perform state-altering Git commands.**
- Explicitly prohibited:
  - `git commit`
  - `git merge`
  - `git push`
  - `git rebase`
  - `git reset`
  - `git tag`
  - `git branch -d` / `git branch -D`
  - `git stash pop` / `git stash drop`

## 4. Allowed Operations
- **Documentation**: Reading, creating, and modifying `*.md` files.
- **Build, Run & Testing (As Needed / Verification)**:
  - Compiling and building targets (e.g., `make`, build scripts).
  - Executing test suites, simulations, and validation checks.
- **Codebase Inspection & Reading**:
  - Viewing file contents, searching files, directory listings.
- **Read-Only Git Commands**:
  - `git status`, `git log`, `git diff`, `git branch`, `git show`.
- **Web Research & Information Retrieval**.