# libzng Interfaces
# ===============

mutable struct ZNGStream
    next_in::Ptr{UInt8}
    avail_in::Cuint
    total_in::Csize_t

    next_out::Ptr{UInt8}
    avail_out::Cuint
    total_out::Csize_t

    msg::Ptr{UInt8}
    state::Ptr{Cvoid}

    zalloc::Ptr{Cvoid}
    zfree::Ptr{Cvoid}
    opaque::Ptr{Cvoid}

    data_type::Cint

    adler::Cuint
    reserved::Culong
end

function ZNGStream()
    ZNGStream(
        # input
        C_NULL, 0, 0,
        # output
        C_NULL, 0, 0,
        # message and state
        C_NULL, C_NULL,
        # memory allocation
        C_NULL, C_NULL, C_NULL,
        # data type, adler and reserved
        0, 0, 0)
end

const Z_DEFAULT_COMPRESSION = Cint(-1)

const Z_OK         = Cint(0)
const Z_STREAM_END = Cint(1)
const Z_BUF_ERROR  = Cint(-5)

const Z_NO_FLUSH      = Cint(0)
const Z_SYNC_FLUSH    = Cint(2)
const Z_FINISH        = Cint(4)

# The deflate compression method
const Z_DEFLATED = Cint(8)

const Z_FILTERED         = Cint(1)
const Z_HUFFMAN_ONLY     = Cint(2)
const Z_RLE              = Cint(3)
const Z_FIXED            = Cint(4)
const Z_DEFAULT_STRATEGY = Cint(0)

const Z_DEFAULT_MEMLEVEL = Cint(8)
const Z_DEFAULT_WINDOWBITS = Cint(15)

function version()
    return unsafe_string(ccall((:zlibng_version, libzng), Ptr{UInt8}, ()))
end

const zlibng_version = version()

function deflate_init!(zstream::ZNGStream, level::Integer=Z_DEFAULT_COMPRESSION, windowbits::Integer=Z_DEFAULT_WINDOWBITS, memlevel::Integer=Z_DEFAULT_MEMLEVEL, strategy::Integer=Z_DEFAULT_STRATEGY)
    return ccall((:zng_deflateInit2, libzng), Cint, (Ref{ZNGStream}, Cint, Cint, Cint, Cint, Cint), zstream, level, Z_DEFLATED, windowbits, memlevel, strategy)
end

function deflate_reset!(zstream::ZNGStream)
    return ccall((:zng_deflateReset, libzng), Cint, (Ref{ZNGStream},), zstream)
end

function deflate_end!(zstream::ZNGStream)
    return ccall((:zng_deflateEnd, libzng), Cint, (Ref{ZNGStream},), zstream)
end

function deflate!(zstream::ZNGStream, flush::Integer)
    return ccall((:zng_deflate, libzng), Cint, (Ref{ZNGStream}, Cint), zstream, flush)
end

function inflate_init!(zstream::ZNGStream, windowbits::Integer)
    return ccall((:zng_inflateInit2, libzng), Cint, (Ref{ZNGStream}, Cint), zstream, windowbits)
end

function inflate_reset!(zstream::ZNGStream)
    return ccall((:zng_inflateReset, libzng), Cint, (Ref{ZNGStream},), zstream)
end

function inflate_end!(zstream::ZNGStream)
    return ccall((:zng_inflateEnd, libzng), Cint, (Ref{ZNGStream},), zstream)
end

function inflate!(zstream::ZNGStream, flush::Integer)
    return ccall((:zng_inflate, libzng), Cint, (Ref{ZNGStream}, Cint), zstream, flush)
end

function zerror(zstream::ZNGStream, code::Integer)
    return throw(ErrorException(zlib_error_message(zstream, code)))
end

function zlib_error_message(zstream::ZNGStream, code::Integer)
    if zstream.msg == C_NULL
        return "zlib error: <no message> (code: $(code))"
    else
        return "zlib error: $(unsafe_string(zstream.msg)) (code: $(code))"
    end
end
