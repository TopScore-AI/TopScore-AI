# Lottie Animation Assets

Place your `.json` Lottie files here. The app expects:

| File | Used for |
|------|----------|
| `level_up.json` | 7-day streak & streak milestones (sci-fi HUD "Level Up") |
| `mission_cleared.json` | Quiz/module mastery (tactical "Mission Cleared" badge) |
| `achievement.json` | Generic achievement unlock dialog |

## Recommended sources
- [LottieFiles](https://lottiefiles.com) — search "level up", "hud", "mission complete"
- Export as Lottie JSON (not dotLottie) for compatibility with the `lottie` Flutter package.

The app uses `errorBuilder` fallbacks (emoji) so it works even without these files.
