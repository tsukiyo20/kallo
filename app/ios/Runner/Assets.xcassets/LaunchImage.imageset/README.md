# The launch screen's mark

`LaunchImage.png`, `LaunchImage@2x.png` and `LaunchImage@3x.png` are written by
`app/icon/generate.py` from the icon master: the icon as iOS masks it, rounded
with a transparent margin. `LaunchScreen.storyboard` centres it on
`LaunchBackground`, the app's ground colour in each appearance, so the launch
screen and the app's first frame are the same colour.

Do not edit these images by hand; run the generator.
