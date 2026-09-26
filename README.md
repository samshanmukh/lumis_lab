# Lumi’s Lab

**Science you can fold.**

Lumi’s Lab is a story-led physics playground for iPhone Duo. Instead of using the fold as a navigation trick, each room turns the physical hinge into part of the experiment: children predict an outcome, fold the device, observe what changes, learn why, and then use the idea to help Lumi.

> [!NOTE]
> **Repository status:** runnable SwiftUI app with a playable Glass Pond prototype and a subscription starter. The other physics rooms remain planned work; their Figma flows describe product intent, not shipped functionality. See the [RevenueCat integration guide](docs/RevenueCat-Integration.md) for subscription setup.

## The experience

Every room follows the same short learning loop:

1. **Predict** what the fold will change.
2. **Try it** by moving the hinge—or by using the accessible on-screen dial.
3. **Check** the result with immediate, gentle feedback.
4. **Understand** the underlying physics in a few visual beats.
5. **Apply** the idea in a challenge that helps Lumi move forward.

The tone is curious rather than punitive. A wrong answer points the learner back to the scene, and repeated misses reveal the answer so nobody gets trapped in a quiz.

## Four-room vision

| Room | The fold controls | Discovery | Design status |
| --- | --- | --- | --- |
| [The Mirror Room](https://www.figma.com/design/4P9upmf1Jx3yqTOmvCRbpk/Lumi-s-Lab?node-id=35-399) | The angle between two simulated mirrors | At ideal symmetric angles, 90° shows four total Lumis and 60° shows six | Hackathon MVP |
| [The Glass Pond](https://www.figma.com/design/4P9upmf1Jx3yqTOmvCRbpk/Lumi-s-Lab?node-id=27-25) | A light ray’s angle at a glass-to-air boundary | Near 42°, the ray skims the surface; past it, light is trapped by total internal reflection | Playable prototype |
| [The Marble Ramp](https://www.figma.com/design/4P9upmf1Jx3yqTOmvCRbpk/Lumi-s-Lab?node-id=66-1543) | The slope of a virtual ramp | A steeper ramp arrives sooner from the same height; changing the controlled setup changes the energy comparison | Designed |
| [Launch Angle](https://www.figma.com/design/4P9upmf1Jx3yqTOmvCRbpk/Lumi-s-Lab?node-id=66-1546) | A virtual launch angle | In the ideal model, 45° travels farthest while complementary angles such as 30° and 60° land together | Designed |

## Playable Glass Pond prototype

Open **The Glass Pond** from the app home screen on iPhone Duo. The room includes the predict → experiment → check → understand → apply loop from the Figma design. At 25° the ray escapes the glass; around 41.8° it skims the surface; at 50° it reflects inside. In the final challenge, hold the ray past the critical angle to wake the moon lily. A dial and a guided sweep keep the experiment playable without hinge input, while a partially open iPhone Duo hinge can control the same model. The journal records completion on the device.

## Original hackathon MVP target

The original hackathon plan centered on one polished Mirror Room. That room is still planned. Its target path is:

**Guess at 90° → fold → count four Lumis → see why → find 60° → celebrate six Lumis → earn a firefly**

The MVP is complete when:

- the live scene responds clearly at 180°, 120°, 90°, 72°, and 60°;
- the 90° and 60° goals settle after a short hold instead of demanding an exact-angle tap;
- the full story-to-solved loop can be demonstrated in 60–90 seconds;
- controls remain clear of the fold in book pose and compact layouts;
- the same lesson remains completable with a dial when hinge input is unavailable; and
- the demo can be reset and repeated from a known state.

## Implementation approach

The Glass Pond is SwiftUI-first, with one physics model shared by the hardware hinge and fallback dial:

```text
DeviceHinge / dial
        ↓
normalized room input
        ↓
pure physics model
        ↓
immutable scene snapshot
        ↓
SwiftUI scene + copy + haptics + accessibility
```

- `onHingeChange` observes the fold while the device is partially open, mapping its angle to a 0–60° light angle.
- `ArrangementView` with a split arrangement places the scene and lesson controls across the Duo display regions.
- Pure room-specific calculations keep physics independent from view state and make known-angle checks deterministic.
- SwiftUI `Canvas` renders the pond, rays, crystal vine, and lily without a separate physics engine.
- Closed, fully open, and unavailable-hinge states use the same model through an adjustable dial or a guided “Show me” sweep.

## Product principles

- **The hinge is the experiment.** Its angle changes the model continuously; it is not just a page-turn gesture.
- **No hardware dead ends.** Every lesson has an equivalent touch path and preserves progress when its input source changes.
- **Kind feedback.** Wrong answers prompt another look, never a red fail screen or buzzer.
- **Fold-safe and accessible.** Support Dynamic Type, VoiceOver-adjustable angles, concise live result labels, visible success cues, and Reduce Motion.
- **Scientifically honest.** Separate the deterministic teaching model from measurements of the real world and state each model’s assumptions.
- **Child-safe growth.** Future purchases belong behind a parental gate; the child experience has no ads or tracking.

## Scientific guardrails

- Mirror counts such as `360° ÷ mirror angle` apply to the ideal symmetric setup at special divisor angles, not every real viewing geometry.
- The Glass Pond’s 41.8° critical angle models **glass to air** with refractive indices 1.5 and 1.0; it is not the water-to-air critical angle.
- Launch Angle assumes fixed speed, equal launch and landing heights, and negligible air drag.
- Marble Ramp distinguishes two experiments: equal starting height and equal ramp length. Those controlled comparisons lead to different conclusions and must stay clearly labeled.

## Relevant Figma links

**Core experience:** [full experience page](https://www.figma.com/design/4P9upmf1Jx3yqTOmvCRbpk/Lumi-s-Lab?node-id=6-2), [foundations and tokens](https://www.figma.com/design/4P9upmf1Jx3yqTOmvCRbpk/Lumi-s-Lab?node-id=22-2), and [start/onboarding](https://www.figma.com/design/4P9upmf1Jx3yqTOmvCRbpk/Lumi-s-Lab?node-id=37-883).

**Room flows:** [Mirror Room](https://www.figma.com/design/4P9upmf1Jx3yqTOmvCRbpk/Lumi-s-Lab?node-id=35-399), [Glass Pond](https://www.figma.com/design/4P9upmf1Jx3yqTOmvCRbpk/Lumi-s-Lab?node-id=27-25), [Marble Ramp](https://www.figma.com/design/4P9upmf1Jx3yqTOmvCRbpk/Lumi-s-Lab?node-id=66-1543), and [Launch Angle](https://www.figma.com/design/4P9upmf1Jx3yqTOmvCRbpk/Lumi-s-Lab?node-id=66-1546).

**Shared behavior:** [journal, dial, hints, and shared screens](https://www.figma.com/design/4P9upmf1Jx3yqTOmvCRbpk/Lumi-s-Lab?node-id=39-1106), [flow, transitions, and logic](https://www.figma.com/design/4P9upmf1Jx3yqTOmvCRbpk/Lumi-s-Lab?node-id=42-1454), and [parental gate and Plus](https://www.figma.com/design/4P9upmf1Jx3yqTOmvCRbpk/Lumi-s-Lab?node-id=127-2775).

The complete design file is available in [Lumi’s Lab on Figma](https://www.figma.com/design/4P9upmf1Jx3yqTOmvCRbpk/Lumi-s-Lab).

## Project materials

The [Lumi’s Lab Drive folder](https://drive.google.com/drive/folders/1wm9BH_CMhGK-9GhSfaJgOJxA1xK8mVAo) contains the product and hackathon plan, physics experiment catalog, engineering and judge brief, pitch deck, pitch script, and concept video. The concept video and Figma frames are design assets; only a verified running build should be presented as implemented.

## Getting started

```bash
git clone https://github.com/samshanmukh/lumis_lab.git
cd lumis_lab
```

The SwiftUI app is defined in `Project.json` and can be built directly in Bitrig. Run it on the iPhone Duo simulator to test The Glass Pond; the remaining rooms in the full journey are planned.

## License

Lumi’s Lab is available under the [MIT License](LICENSE).
