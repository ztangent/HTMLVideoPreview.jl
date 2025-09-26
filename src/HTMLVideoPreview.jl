module HTMLVideoPreview

using Base64

export VideoPreview, videopreview

const IMG_TAG_FORMATS = ("gif",)
const VIDEO_TAG_FORMATS = ("mp4", "webm", "ogg")

## Construction

"""
    VideoPreview 

Represents a video that can be displayed in HTML displays (e.g. notebook output
cells, the VSCode plot pane, etc.)

See [`videopreview`](@ref) for a constructor.
"""
struct VideoPreview
    blob::Union{String, Nothing}
    path::Union{String, Nothing}
    format::String
    attributes::Dict{String, String}
end

function VideoPreview(
    path::AbstractString, format::AbstractString = splitext(path)[2][2:end];
    read::Bool = isfile(path), kwargs...
)
    blob = read ? base64encode(Base.read(path)) : nothing
    attributes = fill_attributes!(default_attributes(format), kwargs)
    return VideoPreview(blob, path, format, attributes)
end

function VideoPreview(blob::Vector{UInt8}, format::AbstractString; kwargs...)
    blob = base64encode(blob)
    attributes = fill_attributes!(default_attributes(format), kwargs)
    return VideoPreview(blob, nothing, format, attributes)
end

function VideoPreview(io::IO, format::AbstractString; kwargs...)
    return VideoPreview(read(io), format; kwargs...)
end

function default_attributes(format::AbstractString)
    if format in VIDEO_TAG_FORMATS
        return Dict(
            "controls" => "",
            "muted" => "",
            "autoplay" => ""
        )
    else
        return Dict{String, String}()
    end
end

function fill_attributes!(attributes::Dict{String, String}, kwargs)
    for (key, value) in pairs(kwargs)
        if value isa Bool
            if value
                attributes[string(key)] = ""
            else
                delete!(attributes, string(key))
            end
        else
            attributes[string(key)] = string(value)
        end
    end
    return attributes
end

"""
    videopreview(path::AbstractString, format, attributes...)
    videopreview(blob::Vector{UInt8}, format, attributes...)
    videopreview(io::IO, format, attributes...)

Construct a `VideoPreview` object, allowing the video stored in `path`, `blob`,
or `io` to be displayed via HTML displays (e.g. notebook output cells, 
the VSCode plot pane, etc.)
"""
videopreview(args...; kwargs...) = VideoPreview(args...; kwargs...)

## MIME registration

"""
    @register_mime mime_str

Register the MIME type `mime_str` for video previews, defining a new method for
`Base.show(io::IO, ::MIME{mime_str}, vp::VideoPreview)`. Can be used to add 
support for output to other HTML displays.
"""
macro register_mime(mime_str::String)
    mime_type = Symbol(mime_str)
    return quote
        Base.show(io::IO, ::MIME{$(QuoteNode(mime_type))}, vp::VideoPreview) =
            showpreview(io, vp)
    end
end

@register_mime "text/html"
@register_mime "juliavscode/html"
@register_mime "application/prs.juno.plotpane+html"
@register_mime "application/vnd.webio.application+html"

## Display

function showpreview(io::IO, vp::VideoPreview)
    if vp.blob isa String
        html = video_blob_to_html(vp.blob, vp.format, vp.attributes)
    elseif vp.path isa String
        html = video_path_to_html(vp.path, vp.format, vp.attributes)
    else
        html = not_available_html()
    end
    print(io, html)
end

function video_blob_to_html(blob, format, attributes)
    attributes_str = attributes_to_str(attributes)
    if format in IMG_TAG_FORMATS
        return "<img $attributes_str src=\"data:image/$format;base64,$blob\">"
    elseif format in VIDEO_TAG_FORMATS
        return """<video $attributes_str>
            <source src=\"data:video/$format;base64,$blob\" type=\"video/$format\">
        </video>"""
    else
        error("Unrecognized format: $format")
    end
end

function video_path_to_html(path, format, attributes)
    attributes_str = attributes_to_str(attributes)
    if format in IMG_TAG_FORMATS
        return "<img $attributes_str src=\"$path\">"
    elseif format in VIDEO_TAG_FORMATS
        return """<video $attributes_str>
            <source src=\"$path\" type=\"video/$format\">
        </video>"""
    else
        error("Unrecognized format: $format")
    end
end

function attributes_to_str(attributes::Dict)
    isempty(attributes) && return ""
    attr_strs = filter!(!isempty, [attr_to_str(k, v) for (k, v) in attributes])
    return join(attr_strs, " ")
end

function attr_to_str(key, value)
    if isempty(value) || key == value
        return "$key"
    elseif value in ("true", "false")
        return value == "true" ? "$key" : ""
    else
        return "$key=\"$value\""
    end
end

function not_available_html()
    return "<p><em>Video not available</em></p>"
end

end
