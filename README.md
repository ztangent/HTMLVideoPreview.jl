# HTMLVideoPreview.jl

Enable previews of videos and animated images in HTML displays (VSCode plot
pane, Jupyter notebooks, etc.) via `Base.display` and `Base.show`.

## Installation

Press `]` to enter the Julia `Pkg` REPL, then enter the following command:

```julia-repl
add HTMLVideoPreview
```

Or from within a script or Jupyter notebook, use the `Pkg.add` function:

```julia
using Pkg
Pkg.add("HTMLVideoPreview")
```

## Usage

The main function is `videopreview`, which creates a `VideoPreview` object
given a video path, URL, or binary data. The resulting object will automatically
be displayed when using the Julia REPL in VSCode, or in the output cells of
Jupyter notebooks.

```julia
using HTMLVideoPreview

# From file path
vp = videopreview("path/to/video.mp4")

# From URL
vp = videopreview("https://example.com/video.mp4")

# From binary data
data = read("video.gif")
vp = videopreview(data, "gif")

# Display in notebook (as last line of cell) / VSCode (via inline or REPL eval)
vp  # automatically renders as HTML

# Manual display
display(vp)

# Get rendered HTML as a string
repr(MIME("text/html"), vp)
```

## Custom Attributes

Video formats get `controls`, `muted`, and `autoplay` attributes by default. 
Custom attributes can be added via keyword arguments.

```julia
# Add HTML attributes
videopreview("video.mp4"; width=640, height=480, loop=true)

# Disable default controls
videopreview(data, "mp4"; controls=false, autoplay=false)
```

## Supported Formats and Outputs

Video formats: `mp4`, `webm`, `ogg`, `gif`

HTML display MIME types:
- `"text/html"` (used by Jupyter, etc.)
- `"juliavscode/html"` (used by [Julia for VSCode](https://github.com/julia-vscode/julia-vscode) plot pane)
- `"application/prs.juno.plotpane+html"` (used by [Juno](https://junolab.org/) plot pane)
- `"application/vnd.webio.application+html"` (used by [WebIO.jl](https://github.com/JuliaGizmos/WebIO.jl) applications)

Note that not all applications may support all video formats (e.g. VSCode
currently cannot display `webm` videos).

Support for additional HTML display MIME types can be added via the 
`HTMLVideoPreview.@register_mime` macro.

## Related Packages

[VideoIO.jl](https://github.com/JuliaIO/VideoIO.jl) provides support for
reading, writing, and converting videos, but not display/preview of videos.

[Plots.jl](https://github.com/JuliaPlots/Plots.jl) and [Makie.jl](https://github.com/MakieOrg/Makie.jl)
provide (some) support for displaying of animated plots that are saved as GIFs
or videos, but support is currently patchy, and users can't choose a specific
file to display or set custom HTML attributes.