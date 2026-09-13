# SlepáMapa engineering instructions
Build an offline-first Flutter geography game for Android, Linux and Windows. Core play, visual authoring, JSON exchange and progress must never require network or AI. Use one versioned validated GeoJSON level format, coordinates [longitude, latitude], isolated fair scoring and local persistence. Never expose answers before submission. Czech and English UI are independent from content language.

Read docs/PROJECT_STATE.md first. Preserve working changes. Use small local commits at verified milestones; never push or publish without explicit authorization. Never commit credentials or caches. Verify formatting, analysis and meaningful tests; report only builds actually executed. Native Windows builds need Windows CI.

After a complete release candidate, continue evidence-driven cycles: audit, prioritize data loss/crashes/scoring/gameplay/platform/security before polish, implement, verify, regression review, update project memory, commit and repeat. Do not refactor merely to stay busy. Keep recoverable state before risky work. Update RESUME HERE and exact blockers before any enforced stop. No privileged setup without approval.
