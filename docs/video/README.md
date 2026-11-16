# Final prototype presentation

[Watch or download the final video](MCA_Final_With_Team_Voiceovers_1080p.mp4) · [Synchronized English captions](MCA_Final_Captions.srt) · [Team script](../TEAM_VIDEO_SCRIPT.md)

The final presentation runs **4 minutes 54.5 seconds**, under the five-minute submission limit. It is a 1920×1080 H.264 MP4 at 30 fps with the team's recorded narration and captions burned into the video. The separate SRT contains the same 57 caption texts, synchronized to the recordings.

| Member | Sections |
|---|---|
| Aman Soni | Project introduction and processing element |
| Mayank Sharma | Array architecture and conclusion |
| Ankit Kumar Pandey | Controller, top-level integration and verification |

The visuals include the example matrix product, the running sum 0 → 16 → 40 → 64 → 80, the 4×4 dataflow, input alignment, a controller timing diagram derived from RTL, and enlarged PE and system waveform figures from the project report. Report figures and documented test results are labelled as existing evidence; the presentation does not claim a new simulator capture.

The original recordings were trimmed only at their leading and trailing silence, mildly denoised and normalized to consistent volume. No speed or pitch changes were applied.

## Maintained files

- `MCA_Final_With_Team_Voiceovers_1080p.mp4`: final submission video.
- `MCA_Final_Captions.srt`: synchronized subtitle export.
- `MCA_Final_Sync.json`: source clip trims and caption timings for the final edit.
- `MCA_Voiceover_Timing.json`: original caption wording used to check that the script is preserved.
- `build_final_video.py` and `build_video.py`: final renderer and shared drawing functions.

Raw recordings, normalized WAV files, render caches, the earlier silent video and superseded caption exports are excluded from the maintained project. To rebuild the video, provide the original recordings separately in the ignored `voiceovers/` directory. The report PDF, LaTeX, Markdown and figures remain in `report/`.

## Rebuild locally

The current renderer uses Pillow, FFmpeg and macOS system fonts. Place the original recordings in the ignored `voiceovers/` directory using these names:

| File | Recording |
|---|---|
| `Aman.m4a` | Aman introduction and PE explanation |
| `Mayank_Array.m4a` | Mayank array explanation |
| `Ankit.mp3` | Ankit controller and verification explanation |
| `Mayank_Close.m4a` | Mayank conclusion |

From the repository root:

```bash
python3 docs/video/build_final_video.py --preview
python3 docs/video/build_final_video.py
```

The preview command checks the unchanged caption wording and writes sample frames. A full render processes the recordings, constructs the audio track and exports the final MP4 and SRT. Temporary files are written under ignored `docs/video/.build/`. Set `MCA_VIDEO_BUILD_DIR` to choose a different temporary directory.
