# Pull Request

## Description
<!-- Provide a clear and concise description of what this PR does -->

## Type of Change
<!-- Mark the relevant option with an 'x' -->
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Code refactoring
- [ ] Performance improvement
- [ ] Test additions/improvements

## Related Issue
<!-- Link to the related issue using #issue_number, or write "N/A" if not applicable -->
Fixes #

## Changes Made
<!-- List the specific changes made in this PR -->
- 
- 
- 

## Testing Performed
<!-- Describe the testing you've done -->
- [ ] Manual testing on Android
- [ ] Manual testing on iOS
- [ ] Unit tests added/updated
- [ ] All existing tests pass

**Test Environment**:
- Platform(s): 
- Sonarr Version: 
- Radarr Version: 

## Screenshots/Recordings
<!-- If applicable, add screenshots or screen recordings to demonstrate the changes -->

## Checklist
<!-- Mark completed items with an 'x' -->
- [ ] My code follows the project's coding standards (see `.github/copilot-instructions.md`)
- [ ] I have performed a self-review of my code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have updated the documentation if needed
- [ ] My changes generate no new warnings or errors
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] All tests pass locally with my changes (`flutter test`)
- [ ] Code analysis passes (`flutter analyze`)
- [ ] Code is properly formatted (`dart format .`)
- [ ] No secrets or sensitive data are included in this PR
- [ ] I have checked that this PR doesn't duplicate an existing one

## Architecture Compliance
<!-- For code changes, confirm adherence to project patterns -->
- [ ] Follows centralized state management pattern (AppStateManager)
- [ ] Uses CachedDataLoader mixin for data screens (if applicable)
- [ ] Services follow singleton pattern and reset on instance changes
- [ ] Error handling uses ErrorFormatter
- [ ] No state management libraries added
- [ ] No typed models added (except ServiceInstance)

## Breaking Changes
<!-- If this introduces breaking changes, describe them and the migration path -->
N/A

## Additional Notes
<!-- Any additional information that reviewers should know -->
