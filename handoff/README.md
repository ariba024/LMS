# Interactive Question Overlay — Handoff

A premium, in-video **knowledge-check** component for Flutter. A centered modal
appears on top of a (paused) lesson video with a blurred dark backdrop and a
fade + scale animation. Learners answer by **Choosing** an option, **speaking**
(voice → transcript), or **typing** a free-text answer.

This folder contains a **single, self-contained file** you can drop into any
Flutter project — no project-specific imports, all colors/text/logo inlined.

---

## Files

| File | What it is |
|---|---|
| `interactive_question.dart` | The complete component — model + overlay + card + voice + animations. **This is the only file you need.** |
| `README.md` | This guide. |

> There is also a theme-integrated copy living in the main app at
> `lib/features/learner/lesson_player/interactive_question.dart` (it uses the
> app's `ArrestoColors` / `ArrestoText` / `ArrestoAiLogo`). The copy in **this**
> folder is the portable one — prefer it for a clean drop-in.

---

## Install

1. Copy `interactive_question.dart` into your project (e.g. `lib/components/`).
2. Add the voice dependency to `pubspec.yaml`:
   ```yaml
   dependencies:
     speech_to_text: ^7.0.0
   ```
   then run `flutter pub get`.
3. **Web only:** voice uses the browser **Web Speech API** (Chrome, Edge,
   Safari, most mobile browsers). It must be served over **https or localhost**,
   and the browser will prompt for microphone permission.

> Don't need voice? Delete `_toggleListen()`, the `AnswerMode.voice` entry in
> `_modes`, `_voiceSection()`, `_PulsingMic`, and the two `speech_to_text`
> imports. Everything else works without the package.

---

## Usage

Place it inside the `Stack` that sits over your video, toggled by a flag.
**Pausing/resuming the video is the parent's job** (do it in the callbacks).

```dart
Stack(
  children: [
    MyVideoWidget(...),

    if (_showQuestion)
      InteractiveQuestionOverlay(
        question: const InteractiveQuestion(
          type: QuestionType.multipleChoice,
          prompt: "What's the accepted minimum rating for a fall-arrest anchor?",
          options: ['10 kN', '22 kN', '5 kN', 'Any steel beam'],
          correctIndex: 1, // 0-based → 'B. 22 kN'
        ),
        index: 1,
        total: 1,
        companionName: 'Aria',
        onSubmit: (result) {
          // result.correct  → bool
          // result.answer   → String (chosen option / transcript / typed text)
          // result.mode     → AnswerMode.choose | voice | type
          setState(() => _showQuestion = false);
          _resumeVideo();
        },
        onSkip: () {
          setState(() => _showQuestion = false);
          _resumeVideo();
        },
      ),
  ],
)
```

Trigger `_showQuestion = true` (and pause the video) at whatever timestamp you
want — e.g. when playback hits 25% of the lesson.

---

## API

### `InteractiveQuestion`
| Field | Type | Notes |
|---|---|---|
| `type` | `QuestionType` | `multipleChoice`, `trueFalse`, `voice`, `text` |
| `prompt` | `String` | The question text |
| `options` | `List<String>` | For `multipleChoice`. Omit for `trueFalse` → auto `['True','False']` |
| `correctIndex` | `int?` | 0-based index of the correct option (null = open answer) |

### `InteractiveQuestionOverlay`
| Prop | Type | Default | Notes |
|---|---|---|---|
| `question` | `InteractiveQuestion` | — | required |
| `onSubmit` | `ValueChanged<QuestionResult>` | — | required |
| `onSkip` | `VoidCallback` | — | required |
| `index` | `int` | `1` | current question number (for the progress bar) |
| `total` | `int` | `1` | total questions |
| `companionName` | `String` | `'Aria'` | shown in the header subtitle |

### `QuestionResult`
| Field | Type | Notes |
|---|---|---|
| `correct` | `bool` | choose: matches `correctIndex`; voice/type: substring match if gradeable, else `true` (participation) |
| `answer` | `String` | the learner's answer |
| `mode` | `AnswerMode` | how they answered |

---

## Answer modes

- **Choose** — A/B/C/D (or True/False) cards. On submit, shows green/red
  correctness for ~0.9s, then fires `onSubmit`.
- **Voice** — tap the pulsing mic → speak → live transcript appears → Submit.
- **Type** — multiline textarea with a `0/300` character counter.

The Choose tab only appears when the question has options; Voice and Type are
always available.

---

## Theming

Open `interactive_question.dart` and edit:

- **`_C`** — the color palette (amber/orange brand, surface, lines, status colors)
- **`_T`** — the text styles (sizes/weights)
- **`_BrandLogo`** — replace with your own logo widget, or keep the vector
  book+sparkle mark

No external theme files are referenced, so it renders identically in any app.

---

## Requirements

- Flutter 3.10+ / Dart 3.0+ (uses `switch` expressions and `.withValues()`)
- `speech_to_text: ^7.0.0` (voice mode only)
