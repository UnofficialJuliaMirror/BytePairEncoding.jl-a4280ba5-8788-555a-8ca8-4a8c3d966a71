struct Bpe
    rank::Dict{Pair{String,String}, Int}
    merge::Int
    _oldsym::String
    endsym::String
    sepsym::String
    cache::Dict{String, Tuple}
    # glossaries::Vector{Union{Regex,String}}
    function Bpe(bfile::AbstractString;
                 merge::Int = -1, sepsym::String = "", endsym::String = "</w>")
        rank = Dict{Pair{String,String}, Int}()
        cache = Dict{String, Tuple}()
        _oldsym = open(bfile) do io
            header = readline(io)
            esi = findlast(isequal("#endsym:"), header)
            if esi !== nothing
                _oldsym = header[last(esi)+1:end]
            else
                _oldsym = "</w>"
            end
            set_endsym(_oldsym)

            for (i, line) ∈ enumerate(eachline(io))
                i < merge && break
                pair = Pair(split(line, " ")...)
                rank[pair] = i
            end
            _oldsym
        end
        new(rank, merge, _oldsym, endsym, sepsym, cache)
    end
end

"process a line, remain leading & trailing whitespace"
function process_line(bpe::Bpe, line)
    pat = r"(\S.*\S)"
    m = match(pat, line)
    m === nothing && return line
    sentence = m.captures[1]
    seg = join(segment(bpe, sentence), " ")
    replace(line, pat=>seg)
end

"segment a given sentence"
segment(bpe::Bpe, sentence::AbstractString)::Vector{String} =
    segment_token(bpe, intern.(tokenize(sentence)))

"bpe tokens"
segment_token(bpe::Bpe, tokens::Vector{String}) =
    mapreduce(x->segment_token(bpe, x), vcat, tokens)

"add seperator and end symbol"
_add_se_sym(bt, i, x, rp, ss)::String = intern(i == length(bt) ? replace(x, rp) : (x * ss))

"bpe a token and add seperator"
segment_token(bpe::Bpe, token::String) = segment_token(bpe, bpe(token))

function segment_token(bpe::Bpe, ttp::Tuple)
    rp = bpe._oldsym=>bpe.endsym
    ss = bpe.sepsym
    map(enumerate(ttp)) do (i, x)
        _add_se_sym(ttp, i, x, rp, ss)
    end::Vector{String}
end


"byte pair encode a word"
function (bpe::Bpe)(x::String)::Tuple
    haskey(bpe.cache, x) && return bpe.cache[x]

    xtp = toStrTuple(x)
    xps = bi_pairs(xtp)
    isempty(xps) && return xtp
    while true
        mp = lowestpair(bpe, xps)
        !haskey(bpe.rank, mp) && break

        xtp = merged_pairs(xtp, mp)[1]
        length(xps) == 1 && break
        xps = bi_pairs(xtp)
    end
    bpe.cache[x] = xtp
end

"find pair with lowest rank"
lowestpair(bpe::Bpe, xps) = argmin(
    sizehint!(Dict(
        map(xps) do p
        p=>get(bpe.rank, p, typemax(Int))
        end),
              length(xps))
)
