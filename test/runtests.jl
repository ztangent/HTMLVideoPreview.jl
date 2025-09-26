using HTMLVideoPreview, Test
using Base64

using HTMLVideoPreview: 
    video_blob_to_html, video_path_to_html, attributes_to_str, attr_to_str

ALL_FORMATS =
    (HTMLVideoPreview.IMG_TAG_FORMATS..., HTMLVideoPreview.VIDEO_TAG_FORMATS...)

@testset "Construction" begin
    @testset "File path" begin
        @testset "$format" for format in ALL_FORMATS
            temp_file = tempname() * ".$format"
            test_content = UInt8[0x00, 0x01, 0x02, 0x03, 0x04]
            write(temp_file, test_content)
            try
                # Test with read=true (default when file exists)
                vp = VideoPreview(temp_file, format)
                @test vp.path == temp_file
                @test vp.format == format
                @test vp.blob == base64encode(test_content)

                # Test with read=false
                vp_no_read = VideoPreview(temp_file, format; read=false)
                @test vp_no_read.path == temp_file
                @test vp_no_read.blob === nothing
            finally
                rm(temp_file, force=true)
            end
        end
    end

    @testset "Blob data" begin
        test_data = UInt8[0x00, 0x01, 0x02, 0x03, 0x04]
        @testset "$format" for format in ALL_FORMATS
            vp = VideoPreview(test_data, format)
            @test vp.blob == base64encode(test_data)
            @test vp.path === nothing
            @test vp.format == format

            vp = videopreview(test_data, format)
            @test vp.blob == base64encode(test_data)
            @test vp.path === nothing
            @test vp.format == format
        end
    end

    @testset "IO stream" begin
        test_data = UInt8[0x00, 0x01, 0x02, 0x03, 0x04]
        @testset "$format" for format in ALL_FORMATS
            io = IOBuffer(test_data)
            vp = VideoPreview(io, format)
            @test vp.blob == base64encode(test_data)
            @test vp.path === nothing
            @test vp.format == format

            io = IOBuffer(test_data)
            vp = videopreview(io, format)
            @test vp.blob == base64encode(test_data)
            @test vp.path === nothing
            @test vp.format == format
        end
    end

    @testset "Custom attributes" begin
        test_data = UInt8[0x00, 0x01]
        vp1 = VideoPreview(test_data, "mp4"; loop=true, autoplay=false)
        @test haskey(vp1.attributes, "loop")
        @test !haskey(vp1.attributes, "autoplay") # false attributes are absent
        vp2 = VideoPreview(test_data, "mp4"; width="640", height="480")
        @test vp2.attributes["width"] == "640"
        @test vp2.attributes["height"] == "480"
    end
end

@testset "Attribute Handling" begin
    @testset "default_attributes" begin
        @testset "$format" for format in HTMLVideoPreview.VIDEO_TAG_FORMATS
            attrs = HTMLVideoPreview.default_attributes(format)
            @test attrs == Dict(
                "controls" => "",
                "muted" => "",
                "autoplay" => ""
            )
        end

        @testset "$format" for format in HTMLVideoPreview.IMG_TAG_FORMATS
            attrs = HTMLVideoPreview.default_attributes(format)
            @test attrs == Dict{String, String}()
        end
    end

    @testset "fill_attributes!" begin
        attrs = Dict{String, String}()
        result = HTMLVideoPreview.fill_attributes!(attrs,
            (controls=true, autoplay=false, width="640", height=480)
        )
        @test haskey(result, "controls")
        @test result["controls"] == ""
        @test !haskey(result, "autoplay")
        @test result["width"] == "640"
        @test result["height"] == "480"
    end

    @testset "attributes_to_str" begin
        attrs_dict = Dict("controls" => "", "width" => "640", "height" => "480")
        attr_str = HTMLVideoPreview.attributes_to_str(attrs_dict)
        @test occursin("controls", attr_str)
        @test occursin("width=\"640\"", attr_str)
        @test occursin("height=\"480\"", attr_str)
        @test HTMLVideoPreview.attributes_to_str(Dict{String,String}()) == ""
    end

    @testset "attr_to_str" begin
        test_cases = [
            ("controls", "", "controls"),
            ("controls", "controls", "controls"),
            ("autoplay", "true", "autoplay"),
            ("autoplay", "false", ""),
            ("width", "640", "width=\"640\"")
        ]
        for case in test_cases
            key, value, expected = case
            @test HTMLVideoPreview.attr_to_str(key, value) == expected
        end
    end
end

@testset "HTML Generation" begin
    test_blob = "dGVzdGRhdGE="  # base64 for "testdata"
    attrs = Dict{String, String}()
    video_attrs = Dict("controls" => "", "loop" => "")
    video_attr_str = HTMLVideoPreview.attributes_to_str(video_attrs)
    img_attrs = Dict("width" => "640", "height" => "480")
    img_attr_str = HTMLVideoPreview.attributes_to_str(img_attrs)

    @testset "Blob to HTML" begin
        @testset "$format" for format in HTMLVideoPreview.VIDEO_TAG_FORMATS
            html = video_blob_to_html(test_blob, format, video_attrs)
            @test occursin("<video", html)
            @test occursin(video_attr_str, html)
            @test occursin("data:video/$format;base64,$test_blob", html)
            @test occursin("type=\"video/$format\"", html)
        end

        @testset "$format" for format in HTMLVideoPreview.IMG_TAG_FORMATS
            html = video_blob_to_html(test_blob, format, img_attrs)
            @test occursin("<img", html)
            @test occursin(img_attr_str, html)
            @test occursin("data:image/$format;base64,$test_blob", html)
        end

        @test_throws ErrorException video_blob_to_html(test_blob, "???", attrs)
    end

    @testset "Path to HTML" begin
        @testset "$format" for format in HTMLVideoPreview.VIDEO_TAG_FORMATS
            test_path = "/path/to/video.$format"
            html = video_path_to_html(test_path, format, video_attrs)
            @test occursin("<video", html)
            @test occursin(video_attr_str, html)
            @test occursin("src=\"$test_path\"", html)
            @test occursin("type=\"video/$format\"", html)
        end

        @testset "$format" for format in HTMLVideoPreview.IMG_TAG_FORMATS
            test_path = "/path/to/image.$format"
            html = video_path_to_html(test_path, format, img_attrs)
            @test occursin("<img", html)
            @test occursin(img_attr_str, html)
            @test occursin("src=\"$test_path\"", html)
        end

        @test_throws ErrorException video_path_to_html("test.???", "???", attrs)
    end
end

@testset "Display (Base.show)" begin
    @testset "showpreview" begin
        test_data = UInt8[0x00, 0x01, 0x02]

        @testset "with blob" begin
            vp = VideoPreview(test_data, "mp4")
            io = IOBuffer()
            HTMLVideoPreview.showpreview(io, vp)
            output = String(take!(io))
            @test occursin("<video", output)
            @test occursin("data:video/mp4;base64,", output)
        end

        @testset "with path" begin
            vp = VideoPreview("test.mp4", "mp4"; read=false)
            io = IOBuffer()
            HTMLVideoPreview.showpreview(io, vp)
            output = String(take!(io))
            @test occursin("<video", output)
            @test occursin("src=\"test.mp4\"", output)
        end

        @testset "not available" begin
            vp = VideoPreview(nothing, nothing, "mp4", Dict{String,String}())
            io = IOBuffer()
            HTMLVideoPreview.showpreview(io, vp)
            output = String(take!(io))
            @test occursin("Video not available", output)
        end
    end

    mime_types = [
        "text/html",
        "juliavscode/html",
        "application/prs.juno.plotpane+html",
        "application/vnd.webio.application+html"
    ]

    @testset "$mime_type" for mime_type in mime_types
        @testset "$format" for format in HTMLVideoPreview.VIDEO_TAG_FORMATS
            test_data = UInt8[0x48, 0x65, 0x6c, 0x6c, 0x6f]
            vp = VideoPreview(test_data, format)
            output = String(repr(MIME(mime_type), vp))
            @test occursin("<video", output)
            @test occursin("data:video/$format;base64,", output)
        end

        @testset "$format" for format in HTMLVideoPreview.IMG_TAG_FORMATS
            test_data = UInt8[0x47, 0x49, 0x46, 0x38, 0x39, 0x61]
            vp = VideoPreview(test_data, format)
            output = String(repr(MIME(mime_type), vp))
            @test occursin("<img", output)
            @test occursin("data:image/$format;base64,", output)
        end
    end
end
