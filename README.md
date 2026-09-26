# Lumi’s Lab

**Science you can fold.**

Lumi’s Lab is a story-led physics playground for iPhone Duo. Instead of using the fold as a navigation trick, each room turns the physical hinge into part of the experiment: children predict an outcome, fold the device, observe what changes, learn why, and then use the idea to help Lumi.

> [!NOTE]
> **Repository status:** a runnable SwiftUI iPhone target combines the GitHub journey and Mirror Room shell with the Marble Ramp chapter. The Mirror Room experiment and the other rooms remain future work.

## Current build: The Marble Ramp

The GitHub app shell opens to a welcome screen and journey map; Marble Ramp can be opened from the map. The chapter begins at a tappable two-panel door that swings open into the activity. In iPhone Duo’s passport layout, the upper pane holds the ramp experiment and the lower pane holds its objective, feedback, Roll button, and Friction, Gravity, and Mass sliders. The displayed hinge convention is 0° fully open, 90° perpendicular, and 180° closed. Moving the physical hinge changes the ramp continuously; each roll accelerates down the ramp and decelerates across the ground. Friction changes stopping distance, gravity changes acceleration, and mass changes marble size. Reaching the firefly unlocks a separate two-ramp visual quiz. After watching both marbles roll, the learner sees a short `PE = mgh` explanation and can continue to a Launch Angle introduction. Launch Angle itself is not yet implemented.

`Project.json` defines the app target. Bitrig generates and builds it with Xcode 27.1 for the iPhone Duo simulator. The current Marble Ramp experiment requires hinge input and intentionally has no angle slider.

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
| [The Glass Pond](https://www.figma.com/design/4P9upmf1Jx3yqTOmvCRbpk/Lumi-s-Lab?node-id=27-25) | A light ray’s angle at a glass-to-air boundary | Near 42°, the ray skims the surface; past it, light is trapped by total internal reflection | Designed next |
| [The Marble Ramp](https://www.figma.com/design/4P9upmf1Jx3yqTOmvCRbpk/Lumi-s-Lab?node-id=69-1853) | The slope of a virtual ramp | A steeper ramp accelerates the marble faster and carries it farther in this simplified teaching model | Implemented chapter |
| [Launch Angle](https://www.figma.com/design/4P9upmf1Jx3yqTOmvCRbpk/Lumi-s-Lab?node-id=66-1546) | A virtual launch angle | In the ideal model, 45° travels farthest while complementary angles such as 30° and 60° land together | Designed |

## Hackathon MVP

The smallest complete version is one polished Mirror Room, not four partial experiments. The target path is:

**Guess at 90° → fold → count four Lumis → see why → find 60° → celebrate six Lumis → earn a firefly**

The MVP is complete when:

- the live scene responds clearly at 180°, 120°, 90°, 72°, and 60°;
- the 90° and 60° goals settle after a short hold instead of demanding an exact-angle tap;
- the full story-to-solved loop can be demonstrated in 60–90 seconds;
- controls remain clear of the fold in book pose and compact layouts;
- the same lesson remains completable with a dial when hinge input is unavailable; and
- the demo can be reset and repeated from a known state.

## Planned implementation

The app is intended to be SwiftUI-first, with one input path shared by the hardware hinge and the fallback dial:

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

- `onHingeChange` observes the fold while the device is partially open.
- `ArrangementView` with a split arrangement places the scene and lesson controls across the two display regions.
- `reservedRegions(kind: .division)` keeps controls and essential content away from the fold.
- Pure room-specific calculations keep physics independent from view state and make known-angle tests deterministic.
- SwiftUI `Canvas` can render mirrors, rays, ramps, trajectories, and trails without a separate physics engine.
- Closed, fully open, unavailable-hinge, and outer-display states use the same model through a 1° adjustable dial or a guided “Show me” sweep.

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

Open this folder in Bitrig. Its `Project.json` generates the Xcode project; use the iOS 27.1 SDK and iPhone Duo simulator to test hinge input.

## License

Lumi’s Lab is available under the [MIT License](LICENSE).
