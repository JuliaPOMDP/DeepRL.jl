module RLInterface

using POMDPs
using POMDPModelTools

# for the ZMQ part
using ZMQ
using JSON
using Random


export
    # Environment types
    AbstractEnvironment,
    POMDPEnvironment,
    MDPEnvironment,
    KMarkovEnvironment,
    # supporting methods
    reset!,
    step!,
    actions,
    sample_action,
    n_actions,
    obs_dimensions,
    render,
    # deprecated
    reset


abstract type AbstractEnvironment end

"""
    obsvector_type(::Union{MDP, POMDP})

Returns the type of the observation vector associated with a specific problem. 
The `MDPEnvironment` and `POMDPEnvironment` wrappers will convert observations to an object of such type when `reset!` or `step!` is called.
"""
obsvector_type(::Union{MDP, POMDP}) = Vector{Float32}

mutable struct MDPEnvironment{OV, M<:MDP, S, R<:AbstractRNG, Info} <: AbstractEnvironment 
    problem::M
    state::S
    rng::R
end
function MDPEnvironment(problem::M,
                        ov::Type{A} = obsvector_type(problem);
                        rng::R=MersenneTwister(0)) where {A<:AbstractArray, M<:MDP, R<:AbstractRNG}
    S = statetype(problem)
    Info = :info in nodenames(DDNStructure(problem))
    return MDPEnvironment{ov, M, S, R, Info}(problem, initialstate(problem, rng), rng)
end

mutable struct POMDPEnvironment{OV, M<:POMDP, S, R<:AbstractRNG, Info} <: AbstractEnvironment
    problem::M
    state::S
    rng::R
end
function POMDPEnvironment(problem::M,
                          ov::Type{A} = obsvector_type(problem);
                          rng::R=MersenneTwister(0)) where {A<:AbstractArray, M<:POMDP, R<:AbstractRNG}
    S = statetype(problem)
    Info = :info in nodenames(DDNStructure(problem))
    return POMDPEnvironment{ov, M, S, R, Info}(problem, initialstate(problem, rng), rng)
end

"""
    reset!(env::MDPEnvironment{OV})
Reset an MDP environment by sampling an initial state returning it.
"""
function reset!(env::MDPEnvironment{OV}) where OV
    s = initialstate(env.problem, env.rng)
    env.state = s
    return convert_s(OV, s, env.problem)
end

"""
    reset!(env::POMDPEnvironment{OV})
Reset an POMDP environment by sampling an initial state,
generating an observation and returning it.
"""
function reset!(env::POMDPEnvironment{OV}) where OV
    s = initialstate(env.problem, env.rng)
    env.state = s
    o = initialobs(env.problem, s, env.rng)
    return convert_o(OV, o, env.problem)
end

"""
    step!(env::MDPEnvironment{OV}, a::A)
Take in an POMDP environment, and an action to execute, and
step the environment forward. Return the state, reward,
terminal flag and info
"""
function step!(env::MDPEnvironment{OV}, a::A) where {OV, A}
    s, r, info = _step!(env, a)
    env.state = s
    t = isterminal(env.problem, s)
    obs = convert_s(OV, s, env.problem)
    return obs, r, t, info
end

# dispatch on Info=true or false
function _step!(env::MDPEnvironment{OV, M, S, R, true}, a::A) where {OV, M, S, R, A}
    s, r, info = gen(DDNOut(:sp, :r, :info), env.problem, env.state, a, env.rng)
end
function _step!(env::MDPEnvironment{OV, M, S, R, false}, a::A) where {OV, M, S, R, A}
    s, r = gen(DDNOut(:sp, :r), env.problem, env.state, a, env.rng)
    return (s, r, nothing)
end

"""
    step!(env::POMDPEnvironment{OV}, a::A)
Take in an MDP environment, and an action to execute, and
step the environment forward. Return the observation, reward,
terminal flag and info
"""
function step!(env::POMDPEnvironment{OV}, a::A) where {OV, A}
    s, o, r, info = _step!(env, a)
    env.state = s
    t = isterminal(env.problem, s)
    obs = convert_o(OV, o, env.problem)
    return obs, r, t, info
end

# dispatch on Info=true or false
function _step!(env::POMDPEnvironment{OV, M, S, R, true}, a::A) where {OV, M, S, R, A}
    s, o, r, info = gen(DDNOut(:sp, :o, :r, :info), env.problem, env.state, a, env.rng)
end
function _step!(env::POMDPEnvironment{OV, M, S, R, false}, a::A) where {OV, M, S, R, A}
    s, o, r = gen(DDNOut(:sp, :o, :r), env.problem, env.state, a, env.rng)
    return (s, o, r, nothing)
end

"""
    actions(env::Union{POMDPEnvironment, MDPEnvironment})
Return an action object that can be sampled with rand.
"""
function POMDPs.actions(env::Union{POMDPEnvironment, MDPEnvironment})
    return actions(env.problem)
end

"""
    sample_action(env::Union{POMDPEnvironment, MDPEnvironment})
Sample an action from the action space of the environment.
"""
function sample_action(env::Union{POMDPEnvironment, MDPEnvironment})
    return rand(env.rng, actions(env))
end

"""
    obs_dimensions(env::MDPEnvironment{OV}) where OV
returns the size of the observation vector.
It generates an initial state, converts it to an array and returns its size.
"""
function obs_dimensions(env::MDPEnvironment{OV}) where OV
    return size(convert_s(OV, initialstate(env.problem, env.rng), env.problem))
end

"""
    obs_dimensions(env::POMDPEnvironment{OV}) where OV
returns the size of the observation vector.
It generates an initial observation, converts it to an array and returns its size.
"""
function obs_dimensions(env::POMDPEnvironment{OV}) where OV
    s = initialstate(env.problem, env.rng)
    return size(convert_o(OV, initialobs(env.problem, s, env.rng), env.problem))
end

"""
    render(env::AbstractEnvironment)
Renders a graphic of the environment
"""
function render(env::AbstractEnvironment) end

include("ZMQServer.jl")
include("k_markov.jl")

# deprecations
import Base.reset
@deprecate reset(env::KMarkovEnvironment) reset!(env)
@deprecate reset(env::POMDPEnvironment) reset!(env)
@deprecate reset(env::MDPEnvironment) reset!(env)

end # module
