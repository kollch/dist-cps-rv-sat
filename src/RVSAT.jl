module RVSAT

using Match

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

function validsigs(signals)
    if length(signals) % 2 ≠ 0
        error("missing signal for provided timesteps")
    end
    map(x -> convert.(AbstractFloat, x), signals)
end

end # module
