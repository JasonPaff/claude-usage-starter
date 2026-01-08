# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a configuration repository for AI-powered DevOps automation. It contains:
- **Azure Pipelines configuration** for AI-assisted development workflows
- **Reusable pipeline templates** for modular, maintainable CI/CD
- **Claude Code skills, commands, and agents** that are copied into target repositories during pipeline execution
- **Shell scripts** for Azure DevOps and GitHub integration

The `.claude/` configuration is designed to be deployed to target repositories where the actual development happens.

## Architecture

```
claude-planner-config/
├── azure-pipelines.yml          # Main pipeline orchestrator - triggered via REST API
├── templates/                   # Modular pipeline templates
│   ├── variables.yml            # Shared variables (paths, org settings)
│   ├── setup/                   # Environment setup templates
│   │   ├── checkout.yml         # Repository checkout (config + target)
│   │   ├── environment.yml      # Node.js, Claude Code installation
│   │   ├── work-item.yml        # Fetch work item context from Azure DevOps
│   │   └── diagnostics.yml      # Claude Code connectivity checks
│   ├── workflows/               # Workflow-specific logic
│   │   ├── quick-fix.yml        # Quick fix workflow steps
│   │   ├── plan.yml             # Planning workflow steps
│   │   └── implement.yml        # Implementation workflow steps
│   └── outputs/                 # Post-workflow actions
│       ├── create-branch-pr.yml # Branch creation and PR
│       ├── attach-plan.yml      # Attach plan to work item
│       ├── handle-bailout.yml   # Handle quick-fix bail out
│       └── report.yml           # Final status reporting
├── scripts/                     # Integration scripts
│   ├── fetch-work-item.sh       # Fetches work item details from Azure DevOps
│   ├── attach-plan.sh           # Attaches implementation plans to work items
│   └── create-pr.sh             # Creates GitHub PRs and links to work items
└── .claude/                     # Claude Code configuration (deployed to target repos)
    ├── agents/                  # 23 specialized subagents
    ├── commands/                # 9 user-invocable slash commands
    └── skills/                  # 21 domain knowledge skills
```

## Pipeline Workflows

The pipeline supports three workflow types triggered via the `workflowType` parameter:

### `quick-fix`
- For trivial issues (typos, one-line fixes)
- Automatically bails out if issue is too complex
- On success: creates branch and PR

### `plan`
- For feature planning (runs `/plan-feature`)
- Generates implementation plan attached to work item
- No code changes, just planning artifacts

### `implement`
- For executing approved plans (runs `/implement-plan`)
- Downloads plan from work item, implements changes
- Creates branch and PR with implementation

## Commands

| Command | Description |
|---------|-------------|
| `/quick-fix "issue"` | Fix trivial issues, bail out if complex |
| `/plan-feature "feature"` | 3-step orchestration: refine → discover files → plan |
| `/implement-plan path.md` | Execute plan using specialist subagents |
| `/plan-tests "area"` | 4-step test planning orchestration |
| `/implement-tests path.md` | Execute test plan with test specialists |
| `/code-review "area"` | Parallel specialist review with consolidated report |
| `/fix-review path/` | Fix all issues from a code review report |
| `/audit-page /route` | Combined UI testing + code standards review |
| `/db operation` | Neon database operations via expert agent |

## Agent Architecture

Commands use an **orchestrator + specialist** pattern:

1. **Orchestrator** (the command) - coordinates workflow, manages todos, routes tasks
2. **Specialists** - domain-specific agents with pre-loaded skills:

**Implementation Specialists:**
- `server-action-specialist`, `server-component-specialist`, `client-component-specialist`
- `database-specialist`, `facade-specialist`, `form-specialist`
- `validation-specialist`, `media-specialist`, `resend-specialist`

**Testing Specialists:**
- `unit-test-specialist`, `component-test-specialist`
- `integration-test-specialist`, `e2e-test-specialist`
- `test-infrastructure-specialist`, `test-gap-analyzer`, `test-executor`

**Review & Analysis:**
- `code-review-analyzer`, `code-review-reporter`
- `ui-audit-specialist`, `static-analysis-validator`
- `file-discovery-agent`, `implementation-planner`

**Database:**
- `neon-db-expert`

## Skills (21 total)

Skills define domain conventions and are auto-loaded by specialists:

| Category | Skills |
|----------|--------|
| **React/UI** | `react-coding-conventions`, `ui-components`, `client-components`, `server-components`, `form-system` |
| **Backend** | `server-actions`, `facade-layer`, `validation-schemas` |
| **Database** | `database-schema`, `drizzle-orm`, `caching` |
| **Testing** | `testing-base`, `unit-testing`, `component-testing`, `integration-testing`, `e2e-testing`, `test-infrastructure` |
| **Integrations** | `cloudinary-media`, `resend-email`, `sentry-client`, `sentry-server` |

## Pipeline Environment

- **Target repository**: Specified via `targetRepo` and `githubOwner` parameters
- **Work item source**: Specified via `azureDevOpsOrg` and `azureDevOpsProject` parameters
- **Required secrets**: `ANTHROPIC_API_KEY`, `GITHUB_PAT` (in Azure DevOps variable group `AI`)
- **Platform**: `ubuntu-latest`
- **Node version**: 20.x

## Modifying This Repository

When changing pipeline or templates:
- Main pipeline (`azure-pipelines.yml`) is the orchestrator; logic lives in `templates/`
- Pipeline uses `--dangerously-skip-permissions` flag for non-interactive execution
- Shared variables are in `templates/variables.yml`
- Scripts expect specific environment variables (`AZURE_DEVOPS_ORG`, `GITHUB_PAT`, etc.)
- Output uses Azure DevOps logging commands (`##vso[task.setvariable]`, `##vso[task.logissue]`)

When changing `.claude/` configuration:
- Changes affect behavior in **target repositories** after pipeline copies the config
- Test changes by running commands locally with the target repo
- Skills in `skills/` define domain conventions; agents in `agents/` define specialist behaviors
- Commands in `commands/` define user-invocable workflows
