# Do we really need to have broadcasting defined for every operation we do with Tensors?
# They don't really lend themselves well to the AbstractArray interface.

import Base.Broadcast
import Base.Broadcast: broadcasted, BroadcastStyle
using Base.Broadcast: broadcast_shape

# struct TensorStyle <: BroadcastStyle end
# Base.BroadcastStyle(::Type{Tensor}) = TensorStyle()

for op in (:+, :-, :/)
  @eval function broadcasted(::typeof($op), t1::Tensor, t2::Tensor)
    $op(t1, t2)
  end
end

for op in (:+, :-)
  @eval function broadcasted(::typeof($op), t1::Tensor, t2::TensorVector)
    t_ = reshape(t2, -1, 1)
    $op(t1, t_)
  end
end

function broadcasted(::typeof(*), t1::Tensor{T,N}, t2::Tensor{T,M}) where {T,N,M}
  ptr = Ref(Ptr{Cvoid}())

  atg_mul(ptr, t1.ptr, t2.ptr)
  Tensor{T,max(N,M)}(ptr[], on(t1))
end

broadcasted(::typeof(NNlib.relu), t::Tensor) = NNlib.relu(t)
broadcasted(::typeof(NNlib.leakyrelu), t::Tensor) = NNlib.leakyrelu(t)
broadcasted(::typeof(identity), t::Tensor) = identity(t)
broadcasted(::typeof(NNlib.sigmoid), t::Tensor) = NNlib.sigmoid(t)

for op in (:+, :-, :*, :/)
  @eval function broadcasted(::typeof($op), t::Tensor, args...)
    $op(t, args...)
  end
end

broadcasted(::typeof(sqrt), t::Tensor) = sqrt(t)

function broadcasted(::typeof(copy), t::Tensor{T,N}) where {T,N}
  t
end

@adjoint function broadcast(::typeof(NNlib.sigmoid), t::Tensor)

  NNlib.sigmoid(t), Δ -> (∇sigmoid(Δ, t),)
end

@adjoint function broadcasted(::typeof(NNlib.relu), t::Tensor{T}) where T
  relu(t), Δ -> (nothing, ∇leaky_relu(Δ, t, zero(T)),)
end
