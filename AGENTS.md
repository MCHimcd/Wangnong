# Wangnong Instructions For Codex

Apply these rules for all files under `Wangnong/`.

Read first:
- [.github/copilot-instructions.md](/d:/projects/ww/Wangnong/.github/copilot-instructions.md)
- [.github/instructions/arkts-patterns.instructions.md](/d:/projects/ww/Wangnong/.github/instructions/arkts-patterns.instructions.md) for `*.ets`
- [.github/instructions/testing.instructions.md](/d:/projects/ww/Wangnong/.github/instructions/testing.instructions.md) for tests
- [.github/instructions/build-and-verify.instructions.md](/d:/projects/ww/Wangnong/.github/instructions/build-and-verify.instructions.md)
- [.github/instructions/debugging.instructions.md](/d:/projects/ww/Wangnong/.github/instructions/debugging.instructions.md)
- [.github/instructions/api-endpoints.instructions.md](/d:/projects/ww/Wangnong/.github/instructions/api-endpoints.instructions.md) for HTTP-related work
- [.github/instructions/mqtt-protocol.instructions.md](/d:/projects/ww/Wangnong/.github/instructions/mqtt-protocol.instructions.md) for MQTT-related work
- [.github/instructions/asyncapi-sync.instructions.md](/d:/projects/ww/Wangnong/.github/instructions/asyncapi-sync.instructions.md) for protocol changes

Non-negotiable rules:
- Clarify unclear requirements before implementation.
- Update tests first or together with the implementation.
- Read `README.md` before larger code changes and sync it when pages, services, models, utilities, HTTP APIs, MQTT contracts, navigation, AppStorage keys, design tokens, or build/test setup change.
- After each modification, append the change to `CHANGELOG.md`.
- Final verification must include the project-required build and test steps from `build-and-verify.instructions.md`.

Key coding constraints:
- Services use `static getInstance()`.
- All HTTP access goes through `HttpService`.
- All MQTT access goes through `MqttClientService`.
- Use `DesignToken.ets` constants instead of hardcoded style values.
- Avoid untyped object literals, intersection types, and index-based property access in ArkTS.
- Clean up timers, listeners, and other resources in `aboutToDisappear()`.
- Maintain OpenHarmony compatibility; if a higher API is necessary, mark it with `TODO: API 11 compatibility`.
