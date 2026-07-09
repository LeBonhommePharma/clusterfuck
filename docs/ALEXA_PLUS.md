# Alexa + Alexa+ API support

NATURaL Remote supports **three control planes** for environment actuation. Pick one via `AlexaProxyConfig.mode` (or `.auto`).

## Modes (`AlexaAPIMode`)

| Mode | When to use | Primary types |
|------|-------------|----------------|
| `skillProxy` | Custom skill / Alexa for Apps / Lambda BFF | Intent JSON `{intent, params}` |
| `smartHomeV3` | Classic Smart Home Skill API v3 | `AlexaSmartHomeDirective` (BrightnessController, PowerController, SceneController, ModeController) |
| `alexaPlus` | **Alexa+** generative AI assistant plane | `AlexaPlusAction` (expert + utterance + slots) |
| `auto` | Prefer Alexa+ if `alexaPlusEndpoint` set, else Smart Home v3, else skill proxy | resolved at call time |

## Alexa+ (generative / agentic)

Amazon’s **Alexa+** (2025+) is the next-gen assistant with LLM + agentic “experts” that orchestrate services and devices. Developer integrations include:

- **Alexa AI Action SDK**
- **Alexa AI Web Action SDK**
- **Alexa AI Multi-Agent SDK**

Public partner-facing details: [Introducing AI-native SDKs for Alexa+](https://developer.amazon.com/en-US/blogs/alexa/alexa-skills-kit/2025/02/new-alexa-announce-blog).

### How this package models Alexa+

```swift
let action = AlexaPlusAction(
    expert: "smart_home",
    utterance: "dim the lights to thirty percent and start a calm breathe routine",
    slots: ["brightness": "30", "routine": "breatheAndDim"],
    sessionId: nil,
    requireConfirmation: false
)
try await alexa.invokeAlexaPlusAction(action)
```

POST body shape (to your BFF or Alexa+ action gateway):

```json
{
  "api": "alexa_plus",
  "sdk": "AI_Action",
  "expert": "smart_home",
  "utterance": "…",
  "slots": { "brightness": "30" },
  "requireConfirmation": false,
  "householdId": "optional"
}
```

Configure:

```swift
var cfg = AlexaProxyConfig(
    mode: .alexaPlus, // or .auto
    alexaPlusEndpoint: URL(string: "https://your-bff.example/alexa-plus/action")!,
    accessToken: "<lwa-or-session-token>",
    householdId: "home-1"
)
alexa.updateConfig(cfg)
```

### Crooks integration

- `breatheAndDim` / `neutralAmbient` on Alexa+ emit natural-language **utterances** to the `smart_home` expert (not only brightness integers).
- Foundation Model voice path can emit `RemoteCommand(service: .alexa, action: "alexaPlusAction", …)` and `setMode` → `alexaPlus`.
- Without credentials/endpoints, state is still recorded (offline) so σ_irr minimization tests pass.

## Smart Home Skill API v3

Used when `mode == .smartHomeV3` or auto-fallback:

- `Alexa.BrightnessController` / `SetBrightness`
- `Alexa.PowerController` / `TurnOff`
- `Alexa.SceneController` / `Activate` (breathe scene)
- `Alexa.ModeController` / `SetMode`

Docs: [Smart Home Skill APIs](https://developer.amazon.com/en-US/docs/alexa/device-apis/smart-home-general-apis.html).

## Skill proxy (classic)

POST `{ "api": "skill_proxy", "intent": "…", "params": {…} }` to `skillEndpoint`.

## RemoteCommand cheatsheet

| action | plane |
|--------|--------|
| `breatheAndDim` | all (resolved by mode) |
| `neutralAmbient` | all |
| `alexaPlusAction` | Alexa+ only |
| `smartHomeSetBrightness` | Smart Home v3 |
| `smartHomePowerOff` | Smart Home v3 |
| `setMode` | config (`alexaPlus` / `smartHomeV3` / `skillProxy` / `auto`) |

## Security / App Store notes

- Tokens stay on the **iPhone companion** (liver); watch sends structured commands only.
- Do not embed long-lived Amazon secrets in the watch app.
- Live Alexa+ partner SDK binaries may require Amazon developer program access; this package ships the **control-plane adapter** so you can swap the BFF when credentials exist.
