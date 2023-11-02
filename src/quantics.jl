"""
    module UnfoldingSchemes

Contains an enum to choose between interleaved and fused representation during quantics
conversion / unfolding. Choose between `UnfoldingSchemes.interleaved` and
`UnfoldingSchemes.fused`.
"""
module UnfoldingSchemes
@enum UnfoldingScheme begin
    interleaved
    fused
end
end

"""
    fuse_dimensions([base=Val(2)], bitlists...)

Merge d bitlists that represent a quantics index into a bitlist where each bit
has dimension base^d. This fuses legs for different dimensions that have equal length
scale (see QTCI paper).

Inverse of [`split_dimensions`](@ref).
"""
function fuse_dimensions(base::Val{B}, bitlists...) where {B}
    result = ones(Int, length(bitlists[1]))
    return fuse_dimensions!(base, result, bitlists...)
end

fuse_dimensions(bitlists...) = fuse_dimensions(Val(2), bitlists...)

function fuse_dimensions!(base::Val{B}, fused::AbstractArray{<:Integer}, bitlists...) where {B}
    p = 1
    for d in eachindex(bitlists)
        @. fused += (bitlists[d] - 1) * p
        p *= B
    end
    return fused
end

fuse_dimensions!(fused::AbstractArray{<:Integer}, bitlists...) = fuse_dimensions!(Val(2), fused::AbstractArray{<:Integer}, bitlists...)

"""
    function merge_dimensions(bitlists...)

See [`fuse_dimensions`](@ref).
"""
function merge_dimensions(bitlists...)
    return fuse_dimensions(bitlists...)
end

"""
    split_dimensions([base=Val(2)], bitlist, d)

Split up a merged bitlist with bits of dimension base^d into d bitlists where each bit has dimension `base`.
Inverse of [`fuse_dimensions`](@ref).
"""
function split_dimensions(base::Val{B}, bitlist, d) where {B}
    result = [zeros(Int, length(bitlist)) for _ in 1:d]
    return split_dimensions!(base, result, bitlist)
end

function split_dimensions!(base::Val{B}, bitlists, bitlist) where {B}
    d = length(bitlists)
    p = 1
    for i in 1:d
        bitlists[i] .= (((bitlist .- 1) .& p) .!= 0) .+ 1
        p *= B
    end
    return bitlists
end

split_dimensions(bitlist, d) = split_dimensions(Val(2), bitlist, d)

split_dimensions!(bitlists, bitlist) = split_dimensions!(Val(2), bitlists, bitlist)

"""
    interleave_dimensions(bitlists...)

Interleaves the indices of all bitlists into one long bitlist. Use this for
quantics representation of multidimensional objects without fusing indices.
Inverse of [`deinterleave_dimensions`](@ref).
"""
function interleave_dimensions(bitlists...)
    return [bitlists[d][i] for i in eachindex(bitlists[1]) for d in eachindex(bitlists)]
end

"""
    deinterleave_dimensions(bitlist, d)

Reverses the interleaving of bits, i.e. yields bitlists for each dimension from
a long interleaved bitlist. Inverse of [`interleave_dimensions`](@ref).
"""
function deinterleave_dimensions(bitlist, d)
    return [bitlist[i:d:end] for i in 1:d]
end

"""
    quantics_to_index_fused(
        bitlist::Union{Array{Int},NTuple{N,Int}},
        d::Int
    ) where {N}

Convert a d-dimensional index from fused quantics representation to d Integers.

* `bitlist`     binary representation
* `d`           number of dimensions

See also [`quantics_to_index_interleaved`](@ref).
"""
function quantics_to_index_fused(
    bitlist::Union{Array{Int},NTuple{N,Int}}, d::Int
) where {N}
    # Must be signed int to avoid https://github.com/JuliaLang/julia/issues/44895
    result = zeros(Int, d)
    n = length(bitlist)
    dimensions_bitmask = 2 .^ (0:(d-1))
    for i in eachindex(bitlist)
        result .+= (((bitlist[i] - 1) .& dimensions_bitmask) .!= 0) .* (1 << (n - i))
    end
    return result .+ 1
end

"""
    quantics_to_index_interleaved(bitlist::Array{Int}, d::Int)

Convert a d-dimensional index from interleaved quantics representation to d Integers.

* `bitlist`     binary representation
* `d`           number of dimensions

See also [`quantics_to_index_fused`](@ref).
"""
function quantics_to_index_interleaved(bitlist::Array{Int}, d::Int)
    return [quantics_to_index(q)[1] for q in deinterleave_dimensions(bitlist, d)]
end

"""
    function quantics_to_index(
        bitlist::Union{Array{Int},NTuple{N,Int}}, d::Int;
        unfoldingscheme::UnfoldingSchemes.UnfoldingScheme=UnfoldingSchemes.fused
    ) where {N}

Convert a d-dimensional index from quantics representation to d Integers. Choose between
fused and interleaved representation.

* `bitlist`     binary representation
* `d`           number of dimensions
* `unfoldingscheme`    Choose fused or interleaved representation from [`UnfoldingSchemes`](@ref).

See also [`quantics_to_index_fused`](@ref), [`quantics_to_index_interleaved`](@ref).
"""
function quantics_to_index(
    bitlist::Union{Array{Int},NTuple{N,Int}}, d::Int;
    unfoldingscheme::UnfoldingSchemes.UnfoldingScheme=UnfoldingSchemes.fused
) where {N}
    if unfoldingscheme == UnfoldingSchemes.fused
        return quantics_to_index_fused(bitlist, d)
    else
        return quantics_to_index_interleaved(bitlist, d)
    end
end

"""
    quantics_to_index(bitlist::Union{Array{Int},NTuple{N,Int}})

Convert a 1d index from quantics representation to a single integer.
"""
function quantics_to_index(bitlist::Union{Array{Int},NTuple{N,Int}})::Int where {N}
    return quantics_to_index(bitlist, 1)[1]
end

"""
    binary_representation(index::Int; numdigits=8)

Convert an integer to its binary representation.

 * `index`       an integer
 * `numdigits`   how many digits to zero-pad to
"""
function binary_representation(index::Int; numdigits=8)
    return [(index & (1 << (numdigits - i))) != 0 for i in 1:numdigits]
end

"""
    index_to_quantics_fused(indices::Array{Int}, n::Int)

Convert d indices to fused quantics representation with n digits.
"""
function index_to_quantics_fused(indices::Array{Int}, n::Int)
    result = [binary_representation(indices[d] - 1; numdigits=n) * 2^(d - 1)
              for d in eachindex(indices)]
    return [sum(r[i] for r in result) for i in 1:n] .+ 1
end

"""
    index_to_quantics_interleaved(indices::Array{Int}, n::Int)

Convert d indices to interleaved quantics representation with n digits.
"""
function index_to_quantics_interleaved(indices::Array{Int}, n::Int)
    return interleave_dimensions([index_to_quantics(i, n) for i in indices]...)
end

"""
    function index_to_quantics(
        indices::Array{Int}, n::Int;
        unfoldingscheme::UnfoldingSchemes.UnfoldingScheme=UnfoldingSchemes.fused
    )

Convert d indices to fused or interleaved quantics representation with n digits, depending on unfoldingscheme.

Arguments:
* `indices::Array{Int}`: an Array of quantics indices.
* `n::Int`: The number of binary digits in the quantics representation; i.e. the length of the tensor train (MPS) for a quantics tensor train decomposition.
* `unfoldingscheme`: Either `UnfoldingSchemes.fused` or `UnfoldingSchemes.interleaved` to choose between fused and interleaved quantics representation.
"""
function index_to_quantics(
    indices::Array{Int}, n::Int;
    unfoldingscheme::UnfoldingSchemes.UnfoldingScheme=UnfoldingSchemes.fused
)
    if unfoldingscheme == UnfoldingSchemes.fused
        return index_to_quantics_fused(indices, n)
    else
        return index_to_quantics_interleaved(indices, n)
    end
end

"""
    index_to_quantics(index::Int, n::Int)

Convert a single index to quantics representation.
"""
function index_to_quantics(index::Int, n::Int)
    return index_to_quantics([index], n)
end

@doc raw"""
    struct QuanticsFunction{ValueType}

Wrapper to convert a function to quantics representation. Given some function ``f(u)``, ``u \in [1, \ldots, 2^R]`` for some integer ``R``, a quantics representation `qf` can be obtained by
```julia
qf = QuanticsFunction{Float64}(f)
```
Replace `Float64` by other types as necessary. The resulting object `qf` can be called with a Vector of `Ints` that represent quantics indices, e.g. `qf([1, 2, 1, 1])`. Note that the "bits" take values `1` and `2` due to Julia's 1-based indexing. This is already the correct format for obtaining a quantics TCI with `TensorCrossInterpolation.crossinterpolate`.

For multivariate ``f``, see [`QuanticsFunctionInterleaved`](@ref) or [`QuanticsFunctionFused`](@ref).
"""
struct QuanticsFunction{ValueType}
    f::Function
end

function Base.broadcastable(qf::QuanticsFunction{ValueType}) where ValueType
    return Ref(qf)
end

function (qf::QuanticsFunction{ValueType})(q::AbstractVector{Int})::ValueType where {ValueType}
    return qf.f(quantics_to_index(q))
end

@doc raw"""
    struct QuanticsFunctionInterleaved{ValueType} <: QuanticsFunction{ValueType}

Wrapper to decode the argument of a multivariate function from the *interleaved* quantics representation into "normal" form (see quantics TCI paper). Given ``f(u)`` with ``ndims`` dimensions, the quantics function can be created by
```julia
qf = QuanticsFunctionInterleaved{Float64}(f, ndims)
```
For example, the argument of `qf([1, 2, 2, 2, 1, 1])` is "de-interleaved" to `[1, 2, 1]` and `[2, 2, 1]`, which are then decoded separately to `2` and `6`; the return value is `f([2, 6])`.
"""
struct QuanticsFunctionInterleaved{ValueType}
    f::Function
    ndims::Int
end

function (qf::QuanticsFunctionInterleaved{ValueType})(q::AbstractVector{Int})::ValueType where {ValueType}
    qvec = deinterleave_dimensions(q, qf.ndims)
    return qf.f([quantics_to_index(s)[1] for s in qvec])
end

function Base.broadcastable(qf::QuanticsFunctionInterleaved{ValueType}) where ValueType
    return Ref(qf)
end

@doc raw"""
    struct QuanticsFunctionFused{ValueType} <: QuanticsFunction{ValueType}

Wrapper to decode the argument of a multivariate function from the *fused* quantics representation into "normal" form (see quantics TCI paper). Given ``f(u)`` with ``ndims`` dimensions, the quantics function can be created by
```julia
qf = QuanticsFunctionFused{Float64}(f, ndims)
```
For example, the argument of `qf([3, 4, 1])` is "split" to `[1, 2, 1]` and `[2, 2, 1]`, which are then decoded separately to `2` and `6`; the return value is `f([2, 6])`.
"""
struct QuanticsFunctionFused{ValueType}
    f::Function
    ndims::Int
end

function Base.broadcastable(qf::QuanticsFunctionFused{ValueType}) where ValueType
    return Ref(qf)
end

function (qf::QuanticsFunctionFused{ValueType})(q::AbstractVector{Int})::ValueType where {ValueType}
    qvec = split_dimensions(q, qf.ndims)
    return qf.f([quantics_to_index(s)[1] for s in qvec])
end
