# Image Generation Record

```yaml
image_generation_record:
  generation_run_id: GEN-SR3GEN-001
  generation_attempt_id: GEN-SR3GEN-001-001
  image_task_id: IMGTASK-SR3GEN-001-001
  source_prompt_id: PROMPT-SR3GEN-001-001
  provider: codex_builtin_imagegen
  model: builtin
  provider_mode: codex_builtin
  input_schema_version: imagegen-skill-v1
  input_payload_path: intermediate/05-visual-plan.md#PROMPT-SR3GEN-001-001
  prompt_used: photorealistic used-car dealer trust-pressure desk scene, no text, no logos, no people, no license plates
  negative_prompt: readable text, license plates, logos, people, fake brand marks, dark cyber style
  aspect_ratio: "16:9"
  started_at: 2026-07-07
  finished_at: 2026-07-07
  generation_status: generated
  output_asset_path: assets/images/IMG-SR3GEN-001-001.png
  failure_reason: none
  retry_suggestion: none
  execution_trace_ref: intermediate/00-execution-trace.md
```

## Prompt Used

```text
Use case: photorealistic-natural
Asset type: short-video picture-in-picture visual for an automotive content workflow sample
Primary request: a realistic editorial image symbolizing a used-car dealer under trust pressure, with a clean used car lot, a desk with inspection checklist papers, a car key, and a smartphone showing an abstract analytics dashboard without readable text
Scene/backdrop: modern indoor car dealership office with large window looking toward a few generic cars outside
Subject: the objects on the desk and the dealership environment, no identifiable people
Style/medium: photorealistic editorial still, natural texture, not stock-like
Composition/framing: 16:9 landscape, desk foreground, cars softly visible in background, clear focal subject, suitable as picture-in-picture insert
Lighting/mood: soft daylight, credible, calm but slightly tense business mood
Color palette: neutral grays, white papers, subtle blue-gray accents, natural car colors
Constraints: no logos, no brand names, no readable text, no license plates, no people, no watermark, no UI that looks like a real product screenshot
Avoid: exaggerated futuristic interface, dark moody cyber style, advertising poster, Chinese text, English text, fake brand marks
```
