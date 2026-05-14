---
slug: drunk-lib-standalone-templates
started: 2026-05-14T03:08:23Z
superpowers_version: 5.1.0
plugin_version: 0.0.15
claude_code_version: 2.1.141
stack_shape: be-only
---

# Session: drunk-lib-standalone-templates
**Started:** 2026-05-14T03:08:23Z
**Last update:** 2026-05-14T03:08:23Z
**Team:** superpower-drunk-lib-standalone-templates
**Worktree:** <pending — planner records in phase 2>
**Worktree origin:** <pending>

## Owner request
> I would like to help to improve the drunk-lib helm chart for every template please make it flexible as much as possible so that developer can pick stand alone template as use. But still not breaking the existing functionality.

## Phases
- [ ] design → docs/superpowers/specs/2026-05-14-drunk-lib-standalone-templates-design.md
- [ ] worktree → <branch>
- [ ] plan → docs/superpowers/plans/2026-05-14-drunk-lib-standalone-templates-plan.md
- [ ] pre_impl_review → arch + sec PASSED
- [ ] implementation (0/0 tasks complete)
- [ ] qa
- [ ] review
- [ ] finish

## Teammates planned (be-only shape, 7 lifetime roles)
- designer — to spawn (phase 1)
- planner — to spawn (phase 2)
- software-architect — to spawn (phase 3, parallel with security-engineer)
- security-engineer — to spawn (phase 3, parallel with software-architect)
- backend-developer — to spawn (phase 4)
- qa-engineer — to spawn (phase 5)
- reviewer — to spawn (phase 6)

## Open escalations
- (none)

## Notes
- No CLAUDE.md existed at session start. Lead created one for be-only Helm library work — owner asked to proceed without stopping. Owner may revise.
- detect-stack.sh returned exit 1 (no BE/FE signal) because the repo is a Helm chart, not a typical app stack.

## Resume protocol
1. Owner runs /team-feature-resume with this filename.
2. Lead respawns teammates using same role definitions.
3. Lead reads this checkpoint, identifies next pending task, resumes.
