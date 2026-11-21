# Prompt for Claude

You are a senior product designer and frontend engineer. Build a polished, responsive **Control Center** dashboard using the supplied reference files.

## Read these files first

- `assets/original-reference.png` — source screenshot and primary reference for content and functionality.
- `assets/generated-visual-reference.png` — visual direction for a refined dark, glassmorphism-style interface.
- `01-control-center-wireframe.svg` — grayscale layout and component hierarchy.
- `component-spec.json` — component inventory and example data.

## Goal

Turn the wireframe into a coherent, high-quality desktop Control Center interface. Use the original screenshot to preserve the information architecture and the generated visual reference for styling inspiration. Do not simply reproduce the wireframe's grayscale styling.

## Required UI components

1. **Main Control Center panel** — window-style header, Wi-Fi details, channel selector, quick controls, media controls, speed-test summary, and a compact Devices table.
2. **Wi-Fi status tile** — network name, connection state, signal strength, and a details affordance.
3. **Speed Test panel** — download, upload, ping, jitter, server, and a start-test affordance.
4. **System controls** — volume slider, Display accordion, and Opacity accordion.
5. **Media controls** — previous, play/pause, next, microphone status, and camera status.
6. **Connected devices table** — IP, MAC, and device name, with a Scan action.
7. **Connection status notification** — clear connected / disconnected state.
8. **Wi-Fi channel selector** — channels 1–11 and a visible selected state.
9. **Quick status tile** — network name, connected state, and signal strength.

## Visual direction

- Dark charcoal / near-black background with restrained glass-like surfaces.
- Use subtle borders, soft shadows, blur/translucency only where it improves legibility.
- Use green for connected / healthy states, blue for primary actions, and amber sparingly for test actions or attention states.
- Use a clear type scale, consistent spacing, and accessible contrast.
- Prefer simple, consistent line icons. Avoid emoji icons.
- Keep the main dashboard visually dominant, with supporting widgets arranged in a balanced grid.

## Behavior and states

- Wi-Fi refresh/details affordances should have meaningful click behavior or clear disabled states.
- Channel buttons should show the selected channel.
- Volume should be an accessible slider and update its displayed percentage.
- Display and Opacity sections should expand/collapse.
- Media controls should expose play/pause and device state feedback. Do not imply real microphone or camera access unless permissions and real integration exist.
- Scan should show a loading state and then a clear empty, sample, or populated state. Do not fabricate discovered network devices; use mock data only when clearly labelled as demo data.
- Speed Test should show idle, running, and completed states. Use mock results only when clearly identified as demo values; do not claim to measure the user's actual connection without a real test implementation.
- Provide sensible empty, loading, disconnected, and error states.

## Technical expectations

- First inspect the repository and follow its existing framework, package manager, and conventions. If no project exists, propose a minimal modern setup before implementation.
- Build reusable components rather than one monolithic screen.
- Keep content and sample values data-driven.
- Make the layout responsive: desktop multi-column layout, tablet reduced columns, mobile stacked panels.
- Use semantic HTML, keyboard-accessible controls, visible focus states, and appropriate ARIA labels.
- Do not add backend/network integrations, credentials, or permissions that were not supplied.
- Keep the implementation maintainable and avoid unnecessary dependencies.

## Deliverables

1. Working UI source code in the current project.
2. A short README explaining how to run it.
3. A list of assumptions and any behavior that is mocked rather than truly integrated.
4. A brief description of the responsive breakpoints and component structure.

Before coding, briefly summarize the intended component structure and any project assumptions. Then implement the UI.
