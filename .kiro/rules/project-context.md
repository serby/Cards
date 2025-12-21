# Cards Project Context

## CI/CD Integration Points

**WARNING**: These files are interconnected. Changes to one may break others.

### Fastlane Lanes (fastlane/Fastfile)
| Lane | Used By | Purpose |
|------|---------|---------|
| `deploy_alpha` | `.github/workflows/deploy.yml` | Deploy to TestFlight |
| `build` | `.github/workflows/ci.yml` | Build verification |
| `test` | `.github/workflows/ci.yml` | Run tests |

### GitHub Actions Workflows
- `.github/workflows/ci.yml` - Runs on PR/push, calls `fastlane build` and `fastlane test`
- `.github/workflows/deploy.yml` - Runs after CI success on main, calls `fastlane deploy_alpha`

### Before Renaming Fastlane Lanes
1. Search for lane name in `.github/workflows/`
2. Update all workflow files that reference the lane
3. Update README.md if it documents the lane

### Before Modifying GitHub Workflows
1. Check if workflow triggers other workflows (`workflow_run`)
2. Verify secret names match what's configured in GitHub
