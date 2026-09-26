# 026-the-walk.lua

Lists every file under a folder with one `find` process, NUL-separated so no
name can be misread; skipped folders are pruned inside `find`.

| Name | In | Out |
|---|---|---|
| `list(root, skips, limit)` | folder; a skip table or nil (nil = list everything); most entries allowed or nil | array of `{ path = relative path (string), kind = "file" or "link" (string) }`, sorted by path. Links are listed, never followed. Refuses when `find` cannot read everything, or when over the limit |
| `SURVEY_SKIPS` | | array of `{ name, why }`: `.git`, `node_modules`, `tmp`, `build`, `target`, `dist`, `__pycache__`, `llm-transcripts`, `cases` |
| `DEFAULT_FILE_LIMIT` | | 20 000 |
