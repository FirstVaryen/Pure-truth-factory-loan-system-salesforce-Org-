# Repository maintenance notes

## 14 Nov 2026: credential and personal data removed

**What was wrong:** a test portal user's password and two personal email addresses were committed in plain text
(`scripts/apex/set_stanley_password.apex`, `scripts/apex/set_stanley_email.apex`, `PROJECT_LOG.md` and
`deliverables/05_Technical_Change_Log.docx`), in every commit since the first.

**What was done:**
- The password was changed in the Salesforce org before this clean-up, so the old value no longer works.
- The password was removed and the emails replaced with `portal.tester@example.com`, in the current files
  **and in the full git history** (history rewritten with `git filter-repo`, then force-pushed).
  Commit IDs in this repo changed as a result; re-clone rather than pull an old copy.
- `set_stanley_password.apex` now holds placeholders only, with a note not to commit real values.
- `05_Technical_Change_Log.docx`: only the email addresses were changed; the rest of the document is unchanged.

**Not changed:** all Salesforce metadata (objects, flows, sharing, email templates) and the other deliverables.
