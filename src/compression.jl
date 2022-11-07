# Compressor Codecs
# ==================

abstract type CompressorCodec <: TranscodingStreams.Codec end

function Base.show(io::IO, codec::CompressorCodec)
    print(io, summary(codec), "(level=$(codec.level), windowbits=$(codec.windowbits))")
end


# Gzip
# ----

struct GzipCompressor <: CompressorCodec
    zstream::ZNGStream
    level::Int
    windowbits::Int
end

"""
    GzipCompressor(;level=$(Z_DEFAULT_COMPRESSION), windowbits=$(Z_DEFAULT_WINDOWBITS))

Create a gzip compression codec.

Arguments
---------
- `level`: compression level (-1..9)
- `windowbits`: size of history buffer (8..15)
"""
function GzipCompressor(;level::Integer=Z_DEFAULT_COMPRESSION,
                         windowbits::Integer=Z_DEFAULT_WINDOWBITS)
    if !(-1 ≤ level ≤ 9)
        throw(ArgumentError("compression level must be within -1..9"))
    elseif !(8 ≤ windowbits ≤ 15)
        throw(ArgumentError("windowbits must be within 8..15"))
    end
    # Add 16 to windowBits to write a simple gzip header and trailer around the
    # compressed data instead of a zlib wrapper.
    return GzipCompressor(ZNGStream(), level, windowbits+16)
end

const GzipCompressorStream{S} = TranscodingStream{GzipCompressor,S} where S<:IO

"""
    GzipCompressorStream(stream::IO; kwargs...)

Create a gzip compression stream (see `GzipCompressor` for `kwargs`).
"""
function GzipCompressorStream(stream::IO; kwargs...)
    x, y = splitkwargs(kwargs, (:level, :windowbits))
    return TranscodingStream(GzipCompressor(;x...), stream; y...)
end


# Zlib
# ----

struct ZlibCompressor <: CompressorCodec
    zstream::ZNGStream
    level::Int
    windowbits::Int
end

"""
    ZlibCompressor(;level=$(Z_DEFAULT_COMPRESSION), windowbits=$(Z_DEFAULT_WINDOWBITS))

Create a zlib compression codec.

Arguments
---------
- `level`: compression level (-1..9)
- `windowbits`: size of history buffer (8..15)
"""
function ZlibCompressor(;level::Integer=Z_DEFAULT_COMPRESSION,
                         windowbits::Integer=Z_DEFAULT_WINDOWBITS)
    if !(-1 ≤ level ≤ 9)
        throw(ArgumentError("compression level must be within -1..9"))
    elseif !(8 ≤ windowbits ≤ 15)
        throw(ArgumentError("windowbits must be within 8..15"))
    end
    return ZlibCompressor(ZNGStream(), level, windowbits)
end

const ZlibCompressorStream{S} = TranscodingStream{ZlibCompressor,S} where S<:IO

"""
    ZlibCompressorStream(stream::IO)

Create a zlib compression stream (see `ZlibCompressor` for `kwargs`).
"""
function ZlibCompressorStream(stream::IO; kwargs...)
    x, y = splitkwargs(kwargs, (:level, :windowbits))
    return TranscodingStream(ZlibCompressor(;x...), stream; y...)
end


# Deflate
# -------

struct DeflateCompressor <: CompressorCodec
    zstream::ZNGStream
    level::Int
    windowbits::Int
    memlevel::Int
    strategy::Int
end

"""
    DeflateCompressor(;level=$(Z_DEFAULT_COMPRESSION), windowbits=$(Z_DEFAULT_COMPRESSION))

Create a deflate compression codec.

Arguments
---------
- `level`: compression level (-1..9)
- `windowbits`: size of history buffer (8..15)
- `memlevel`: memory size used for internal compression state (1..9)
- `strategy`: compression strategy
    * 0 <-> Z_DEFAULT_STRATEGY
    * 1 <-> Z_FILTERED
    * 2 <-> Z_HUFFMAN_ONLY
    * 3 <-> Z_RLE
    * 4 <-> Z_FIXED
"""
function DeflateCompressor(;
    level::Integer=Z_DEFAULT_COMPRESSION,
    windowbits::Integer=Z_DEFAULT_WINDOWBITS,
    memlevel::Integer=Z_DEFAULT_MEMLEVEL,
    strategy::Integer=Z_DEFAULT_STRATEGY,
)
    if !(-1 ≤ level ≤ 9)
        throw(ArgumentError("compression level must be within -1..9"))
    elseif !(8 ≤ windowbits ≤ 15)
        throw(ArgumentError("windowbits must be within 8..15"))
    elseif !(1 ≤ memlevel ≤ 9)
        throw(ArgumentError("memlevel must be within 1..9"))
    elseif !(0 ≤ strategy ≤ 4)
        throw(ArgumentError("strategy must be within 0..4"))
    end
    return DeflateCompressor(ZNGStream(), level, -Int(windowbits), memlevel, strategy)
end

const DeflateCompressorStream{S} = TranscodingStream{DeflateCompressor,S} where S<:IO

"""
    DeflateCompressorStream(stream::IO; kwargs...)

Create a deflate compression stream (see `DeflateCompressor` for `kwargs`).
"""
function DeflateCompressorStream(stream::IO; kwargs...)
    x, y = splitkwargs(kwargs, (:level, :windowbits))
    return TranscodingStream(DeflateCompressor(;x...), stream; y...)
end


# Methods
# -------

function TranscodingStreams.initialize(codec::CompressorCodec)
    code = deflate_init!(codec.zstream, codec.level, codec.windowbits)
    if code != Z_OK
        zerror(codec.zstream, code)
    end
    return
end

function TranscodingStreams.finalize(codec::CompressorCodec)
    zstream = codec.zstream
    if zstream.state != C_NULL
        code = deflate_end!(zstream)
        if code != Z_OK
            zerror(zstream, code)
        end
    end
    return
end

function TranscodingStreams.startproc(codec::CompressorCodec, state::Symbol, error::Error)
    code = deflate_reset!(codec.zstream)
    if code == Z_OK
        return :ok
    else
        error[] = ErrorException(zlib_error_message(codec.zstream, code))
        return :error
    end
end

function TranscodingStreams.process(codec::CompressorCodec, input::Memory, output::Memory, error::Error)
    zstream = codec.zstream
    zstream.next_in = input.ptr
    zstream.avail_in = input.size
    zstream.next_out = output.ptr
    zstream.avail_out = output.size
    code = deflate!(zstream, input.size > 0 ? Z_NO_FLUSH : Z_FINISH)
    Δin = Int(input.size - zstream.avail_in)
    Δout = Int(output.size - zstream.avail_out)
    if code == Z_OK
        return Δin, Δout, :ok
    elseif code == Z_STREAM_END
        return Δin, Δout, :end
    else
        error[] = ErrorException(zlib_error_message(zstream, code))
        return Δin, Δout, :error
    end
end
