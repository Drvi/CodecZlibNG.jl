module CodecZlibNG

export
    # gzip
    GzipCompressor,
    GzipCompressorStream,
    GzipDecompressor,
    GzipDecompressorStream,

    # zlib
    ZlibCompressor,
    ZlibCompressorStream,
    ZlibDecompressor,
    ZlibDecompressorStream,

    # deflate
    DeflateCompressor,
    DeflateCompressorStream,
    DeflateDecompressor,
    DeflateDecompressorStream

import TranscodingStreams:
    TranscodingStreams,
    TranscodingStream,
    Memory,
    Error,
    initialize,
    finalize,
    splitkwargs
using ZlibNG_jll

include("libzng.jl")
include("compression.jl")
include("decompression.jl")

end # module
