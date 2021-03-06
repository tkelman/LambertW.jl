module LambertW

import Base: convert
export lambertw, lambertwbp, ω, omega

#### Lambert W function ####

const LAMBERTW_USE_NAN = false

macro baddomain()
    if LAMBERTW_USE_NAN
        return :(return(NaN))
    else
        return :(throw(DomainError()))
    end
end

# Maybe finish implementing this later ?
lambert_verbose() = false

# Use Halley's root-finding method to find x = lambertw(z) with
# initial point x.
function _lambertw{T<:Number}(z::T, x::T)
    two_t = convert(T,2)
    lastx = x
    lastdiff = 0.0
    for i in 1:100
        ex = exp(x)
        xexz = x * ex - z
        x1 = x + 1
        x = x - xexz / (ex * x1 - (x + two_t) * xexz / (two_t * x1 ) )
        xdiff = abs(lastx - x)
        xdiff <= 2*eps(abs(lastx)) && break
        if lastdiff == diff
            lambert_verbose() && warn("lambertw did not converge. diff=$xdiff")
            break
        end
        lastx = x
        lastdiff = xdiff
    end
    x
end

### Real z ###

# Real x, k = 0
# fancy initial condition does not seem to help speed.
function lambertwk0{T<:Real}(x::T)
    x == Inf && return Inf
    const one_t = one(T)
    const oneoe = -one_t/convert(T,e)
    x == oneoe && return -one_t
    const itwo_t = 1/convert(T,2)
    oneoe <= x || @baddomain
    if x > one_t
        lx = log(x)
        llx = log(lx)
        x1 = lx - llx - log(one_t - llx/lx) * itwo_t
    else
        x1 = 0.567 * x
    end
    _lambertw(x,x1)
end

# Real x, k = -1
function _lambertwkm1{T<:Real}(x::T)
    const oneoe = -one(T)/convert(T,e)
    x == oneoe && return -one(T)
    oneoe <= x || @baddomain
    x == zero(T) && return -convert(T,Inf)
    x < zero(T) || @baddomain
    _lambertw(x,log(-x))
end

function lambertw{T<:Real}(x::T, k::Int)
    k == 0 && return lambertwk0(x)
    k == -1 && return _lambertwkm1(x)
    @baddomain  # more informative message like below ?
#    error("lambertw: real x must have k == 0 or k == -1")
end

function lambertw{T<:Integer}(x::T, k::Int)
    if k == 0
        x == 0 && return float(zero(x))
        x == 1 && return convert(typeof(float(x)),LambertW.omega) # must be more efficient way
    end
    lambertw(float(x),k)
end

### Complex z ###

# choose initial value inside correct branch for root finding
function lambertw(z::Complex, k::Int)
    rT = typeof(real(z))
    one_t = one(rT)
    if abs(z) <= one_t/convert(rT,e)
        if z == 0
            k == 0 && return z
            return complex(-convert(rT,Inf),zero(rT))
        end
        if k == 0
            w = z
        elseif k == -1 && imag(z) == 0 && real(z) < 0
            w = complex(log(-real(z)),1/10^7) # need offset for z ≈ -1/e.
        else
            w = log(z)
            k != 0 ? w += complex(0,k * 2 * pi) : nothing
        end
    elseif k == 0 && imag(z) <= 0.7 && abs(z) <= 0.7
        w = abs(z+0.5) < 0.1 ? imag(z) > 0 ? complex(0.7,0.7) : complex(0.7,-0.7) : z
    else
        if real(z) == convert(rT,Inf)
            k == 0 && return z
            return z + complex(0,2*k*pi)
        end
        real(z) == -convert(rT,Inf) && return -z + complex(0,(2*k+1)*pi)
        w = log(z)
        k != 0 ? w += complex(0, 2*k*pi) : nothing
    end
    _lambertw(z,w)
end

lambertw(z::Complex{Int}, k::Int) = lambertw(float(z),k)

# lambertw(e + 0im,k) is ok for all k
function lambertw(::Irrational{:e}, k::Int)
    k == 0 && return 1
    @baddomain
end

lambertw(x::Number) = lambertw(x,0)

### omega constant ###

# These literals have more than Float64 and BigFloat 256 precision
const omega_const_ = 0.567143290409783872999968662210355
const omega_const_bf_ = parse(BigFloat,"0.5671432904097838729999686622103555497538157871865125081351310792230457930866845666932194")

# maybe compute higher precision. converges very quickly
function omega_const(::Type{BigFloat})
    get_bigfloat_precision() <= 256 && return omega_const_bf_
    myeps = eps(BigFloat)
    oc = omega_const_bf_
    for i in 1:100
        nextoc = (1 + oc) / (1 + exp(oc))
        abs(oc - nextoc) <= myeps && break
        oc = nextoc
    end
    oc
end

const ω = Irrational{:ω}()
const omega = ω
convert(::Type{BigFloat}, ::Irrational{:ω}) = omega_const(BigFloat)
convert(::Type{Float64}, ::Irrational{:ω}) = omega_const_
convert(::Type{Float32}, ::Irrational{:ω}) = Float32(omega_const_)
convert(::Type{Float16}, ::Irrational{:ω}) = Float16(omega_const_)

### Expansion about branch point x = -1/e  ###

#  Refer to the paper "On the Lambert W function".  In (4.22)
# coefficients μ₀ through μ₃ are given explicitly. Recursion relations
# (4.23) and (4.24) for all μ are also given. This code implements the
# recursion relations.

# (4.23) and (4.24) give zero based coefficients
cset(a,i,v) = a[i+1] = v
cget(a,i) = a[i+1]

# (4.24)
function compa(k,m,a)
    sum0 = zero(eltype(m))
    for j in 2:k-1
        sum0 += cget(m,j) * cget(m,k+1-j)
    end
    cset(a,k,sum0)
    sum0
end

# (4.23)
function compm(k,m,a)
    kt = convert(eltype(m),k)
    mk = (kt-1)/(kt+1) *(cget(m,k-2)/2 + cget(a,k-2)/4) -
        cget(a,k)/2 - cget(m,k-1)/(kt+1)
    cset(m,k,mk)
    mk
end

# We plug the known value μ₂ == -1//3 for (4.22) into (4.23) and
# solve for α₂. We get α₂ = 0.
# compute array of coefficients μ in (4.22).
# m[1] is μ₀
function lamwcoeff(T::DataType, n::Int)
    a = Array(T,n)
    m = Array(T,n)
    cset(a,0,2)  # α₀ literal in paper
    cset(a,1,-1) # α₁ literal in paper
    cset(a,2,0)  # α₂ get this by solving (4.23) for alpha_2 with values printed in paper
    cset(m,0,-1) # μ₀ literal in paper
    cset(m,1,1)  # μ₁ literal in paper
    cset(m,2,-1//3) # μ₂ literal in paper, but only in (4.22)
    for i in 3:n-1  # coeffs are zero indexed
        compa(i,m,a)
        compm(i,m,a)
    end
    return m
end

const LAMWMU_FLOAT64 = lamwcoeff(Float64,500)

function horner(x, p::AbstractArray,n)
    n += 1
    ex = p[n]
    for i = n-1:-1:2
        ex = :($(p[i]) + t * $ex)
    end
    ex = :( t * $ex)
    Expr(:block, :(t = $x), ex)
end

function mkwser(name, n)
    iex = horner(:x,LAMWMU_FLOAT64,n)
    :(function ($name)(x) $iex  end)
end

eval(mkwser(:wser3, 3))
eval(mkwser(:wser5, 5))
eval(mkwser(:wser7, 7))
eval(mkwser(:wser12, 12))
eval(mkwser(:wser19, 19))
eval(mkwser(:wser26, 26))
eval(mkwser(:wser32, 32))
eval(mkwser(:wser50, 50))
eval(mkwser(:wser100, 100))
eval(mkwser(:wser290, 290))

# Converges to Float64 precision
# We could get finer tuning by separating k=0,-1 branches.
function wser(p,x)
    x < 4e-11 && return wser3(p)
    x < 1e-5 && return wser7(p)
    x < 1e-3 && return wser12(p)
    x < 1e-2 && return wser19(p)
    x < 3e-2 && return wser26(p)
    x < 5e-2 && return wser32(p)
    x < 1e-1 && return wser50(p)
    x < 1.9e-1 && return wser100(p)
    x > 1/e && @baddomain  # radius of convergence
    return wser290(p)  # good for x approx .32
end

# These may need tuning.
function wser(p::Complex,z)
    x = abs(z)
    x < 4e-11 && return wser3(p)
    x < 1e-5 && return wser7(p)
    x < 1e-3 && return wser12(p)
    x < 1e-2 && return wser19(p)
    x < 3e-2 && return wser26(p)
    x < 5e-2 && return wser32(p)
    x < 1e-1 && return wser50(p)
    x < 1.9e-1 && return wser100(p)
    x > 1/e && @baddomain  # radius of convergence
    return wser290(p)
end

@inline function _lambertw0(x) # 1 + W(-1/e + x)  , k = 0
    ps = 2*e*x;
    p = sqrt(ps)
    wser(p,x)
end

@inline function _lambertwm1(x) # 1 + W(-1/e + x)  , k = -1
    ps = 2*e*x;
    p = -sqrt(ps)
    wser(p,x)
end

function lambertwbp{T<:Number}(x::T,k::Int)
    k == 0 && return _lambertw0(x)
    k == -1 && return _lambertwm1(x)
    error("expansion about branch point only implemented for k = 0 and -1")
end

lambertwbp{T<:Number}(x::T) = _lambertw0(x)

Base.@vectorize_1arg Number lambertw
Base.@vectorize_2arg Number lambertw
Base.@vectorize_1arg Number lambertwbp
Base.@vectorize_2arg Number lambertwbp

end #module
