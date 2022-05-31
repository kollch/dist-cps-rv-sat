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
    Meta.parse(Base.replace(s, subs...))
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

function z3formula(ctx, ϕ)
    @match ϕ begin
        Expr(:call, [:!, x::Expr])             => z3formula(ctx, negate(x))
        Expr(:call, [r::Symbol, x, c::Number]) => Expr(:call, r, z3var(ctx, x), c) |> eval
        Expr(:&&, [x::Expr, y::Expr])          => and(z3formula(ctx, x), z3formula(ctx, y))
        Expr(:||, [x::Expr, y::Expr])          => or(z3formula(ctx, x), z3formula(ctx, y))
        _ => error("invalid formula: ", ϕ)
    end
end

function z3var(ctx, ϕ)
    @match ϕ begin
        Expr(:call, [:*, a::Number, x::Symbol]) => a * z3var(ctx, x)
        Expr(:call, [:+, vars...])              => sum(z3var.(vars))
        Expr(:call, [:-, x, y])                 => z3var(ctx, x) - z3var(ctx, y)
        _ => error("invalid formula: ", ϕ)
    end
end

z3var(ctx, x::Symbol) = real_const(ctx, string(x))

function signalsat(ϕ, ε, signals...)
    signals = initsigs(signals)
    n = length(signals)

    ctx = Context()
    s = Solver(ctx, "QF_NRA")

    # Add time bounds and interpolation
    for (i, sig) in enumerate(signals)
        t = real_const(ctx, "t" * string(i))
        x = real_const(ctx, "x" * string(i))
        add(s, and(t ≥ 0, t ≤ sig[end][1]))
        add(s, pwl(sig, t, x))
    end

    # Add ε restrictions
    # All (i, j) pairs where i ≠ j
    i_j_pairs = filter(((i, j),) -> i ≠ j, collect(Iterators.product(1:n, 1:n)))
    εₜ = map(i_j_pairs) do (i, j)
        tᵢ = real_const(ctx, "t" * string(i))
        tⱼ = real_const(ctx, "t" * string(j))
        tᵢ - tⱼ ≤ ε
    end
    add(s, and(εₜ...))

    # Add ϕ
    formula = z3formula(ctx, strtoexpr(ϕ))
    add(s, formula)

    res = check(s)
    if res == Z3.sat
        println("Formula satisfies.")
        m = get_model(s)
        for (k, v) in consts(m)
            v_str = get_decimal_string(v, 5)
            println("$k = $v_str")
        end
    elseif res == Z3.unsat
        println("Formula does not satisfy.")
    else
        println("Error: SMT solver failed. Satisfaction unknown.")
    end
end

# Mostly pulled from https://stackoverflow.com/a/63769989
window(x, len) = view.(Ref(x), (:).(1:length(x) - (len - 1), len:length(x)))

function pwl(signal, t, x)
    mapreduce(or, window(signal, 2)) do ((t₁, x₁), (t₂, x₂))
        m = (x₂ - x₁) / (t₂ - t₁)
        b = x₁ - m * t₁
        and(x == m * t + b, and(t ≥ t₁, t ≤ t₂))
    end
end

end # module
