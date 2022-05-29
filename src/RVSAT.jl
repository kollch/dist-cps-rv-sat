module RVSAT

using Match
using Z3

function strtoexpr(s)
    # Ensure that Julia can interpret the formula correctly
    subs = Dict(begin
        "<=" => "≤",
        ">=" => "≥",
        "¬" => "!",
        "∨" => "||",
        "∧" => "&&",
        "₀" => "0",
        "₁" => "1",
        "₂" => "2",
        "₃" => "3",
        "₄" => "4",
        "₅" => "5",
        "₆" => "6",
        "₇" => "7",
        "₈" => "8",
        "₉" => "9"
    end)
    Meta.parse(replace(s, subs...))
end

function negate(ϕ)
    function negbinrel(r)
        @match r begin
            :≤ => :>
            :≥ => :<
            :< => :≥
            :> => :≤
            _ => error("invalid binary relation in formula: ", r)
        end
    end
    @match ϕ begin
        Expr(:call, [:!, x::Expr])             => x
        Expr(:call, [r::Symbol, x, y::Number]) => Expr(:call, negbinrel(r), x, y)
        Expr(:&&, [x::Expr, y::Expr])          => Expr(:||, negate(x), negate(y))
        Expr(:||, [x::Expr, y::Expr])          => Expr(:&&, negate(x), negate(y))
        _ => error("invalid formula: ", ϕ)
    end
end

function tbounds(signals)
    times = signals[1:2:end]
    n = length(times)
    # Return upper and lower bounds for each time signal
    zeros(n), maximum.(times)
end

function initsigs(signals)
    if length(signals) % 2 ≠ 0
        error("missing signal for provided timesteps")
    end
    #map(x -> convert.(AbstractFloat, x), signals)
    map(x -> (collect ∘ zip)(x...), Iterators.partition(signals, 2))
end

function z3example()
    ctx = Context()
    s = Solver(ctx, "QF_LRA")
    t = real_const(ctx, "t")
    #x = func(ctx, "x", real_sort(ctx), real_sort(ctx))
    x = real_const(ctx, "x")
    add(s, and(t ≥ 0, t ≤ 5))
    #add(s, x(t) == t - 3)
    add(s, x == t - 3)
    add(s, x ≥ 0)
    res = check(s)
    m = get_model(s)
    for (k, v) in consts(m)
        println("$k = $v")
    end
end

function z3formula(ϕ)
    @match ϕ begin
        Expr(:call, [:!, x::Expr])             => z3formula(negate(x))
        Expr(:call, [r::Symbol, x, c::Number]) => Expr(:call, r, x, c) |> eval
        Expr(:&&, [x::Expr, y::Expr])          => and(z3formula(x), z3formula(y))
        Expr(:||, [x::Expr, y::Expr])          => or(z3formula(x), z3formula(y))
        _ => error("invalid formula: ", ϕ)
    end
end

function signalsat(ϕ, ε, signals...)
    signals = initsigs(signals)
    formula = (z3formula ∘ strtoexpr)(ϕ)
end

end # module
