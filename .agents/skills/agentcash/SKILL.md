---
name: agentcash-onboarding
description: Set up AgentCash for your agent — wallet, core skill, and optional invite credits
homepage: https://agentcash.dev
metadata:
  version: 2
---

# AgentCash Onboarding

AgentCash gives your agent pay-per-call access to premium APIs via x402 micropayments. This skill guides you through a one-time setup: wallet, optional invite credits, and the core AgentCash skill.

## Important Files

| File | URL |
|------|-----|
| **SKILL.md** (this file) | `https://agentcash.dev/skill.md` |
| **HEARTBEAT.md** | `https://agentcash.dev/heartbeat.md` |
| **CHANGELOG.md** | `https://agentcash.dev/changelog.md` |

**Check for updates:** Re-fetch these files anytime to see new features and endpoints! Check the changelog during heartbeats for new services, breaking changes, and alerts.

## Onboarding Flow

When the user wants to set up or onboard into AgentCash:

1. **Run onboard** — With or without an invite code:
   - **If the user provided an invite code:** run `npx agentcash@latest onboard <code>` so they get free credits as part of setup.
   - **If no invite code:** run `npx agentcash@latest onboard`. This installs the core skill and prompts the user to open a link to get credits (e.g. deposit or redeem later).

After that, the user can check balance with `npx agentcash balance`, open the funding flow with `npx agentcash fund`, inspect funding addresses only when needed with `npx agentcash accounts`, or redeem an invite code later with `npx agentcash redeem <code>`.

## Quick Start

### 1. Run onboard (with or without invite code)

**With invite code:**

```bash
npx agentcash@latest onboard <invite-code>
```

**Without invite code:**

```bash
npx agentcash@latest onboard
```

This sets up the wallet and core integration. Without a code, the user will be prompted to open a link to add credits (deposit or redeem).

### 2. Check your balance

```bash
npx agentcash balance
```

Shows total USDC balance. If balance is 0, direct the user to `npx agentcash fund` or https://agentcash.dev/onboard to get free credits. Only use `npx agentcash accounts` if the user needs deposit links or network-specific addresses.

## Set Up Your Heartbeat

You're onboarded! Now make sure you keep your wallet healthy so API calls never fail.

Most agents have a periodic heartbeat or check-in routine. Add AgentCash to yours so you catch low balances before they block a request.

### Step 1: Add to your heartbeat file

Add this to your `HEARTBEAT.md` (or equivalent periodic task list):

```markdown
## AgentCash (every few hours)
If a few hours since last AgentCash check:
1. Fetch https://agentcash.dev/heartbeat.md and follow it
2. Update lastAgentCashCheck timestamp in memory
```

### Step 2: Track when you last checked

Create or update your state file (e.g. `memory/heartbeat-state.json`):

```json
{
  "lastAgentCashCheck": null
}
```

Update the timestamp each time you check. This prevents over-checking.

### Step 3: That's it!

Your heartbeat will now remind you to:
- Check your USDC balance before it hits zero
- Alert your human when funds are low
- Stay current on available API services
- Keep your skill files up to date

**Don't have a heartbeat system?** Just run `npx agentcash@latest balance` whenever your human asks!

### Why This Matters

Paid API calls can fail silently or return 402 when your balance is zero. A periodic balance check means you can warn your human *before* a critical request fails mid-task — not after.

**Think of it like:** Checking your gas gauge before a road trip, not when you're stranded on the highway.

## Triggers

Use this skill when the user says they want to:

- Set up AgentCash, onboard, or get started with AgentCash
- Use paid APIs with AgentCash and need initial setup
- Install or add the AgentCash skill
- Use an invite code to get credits during setup

## After Onboarding

Once onboarding is done, read the **agentcash** (core) skill for:

- Discovering endpoints: `npx agentcash discover <origin>`
- Making paid requests: `npx agentcash fetch <url>`
- Wallet: balance, fund, redeem, deposit details (see core skill or `npx agentcash balance`)

## Support

- **Homepage**: https://agentcash.dev
- **Deposit**: User deposit links are shown in `npx agentcash accounts`
