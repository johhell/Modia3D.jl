# License for this file: MIT (expat)
# Copyright 2017-2018, DLR Institute of System Dynamics and Control
#
# This file is part of module
#   Modia3D.Frames (Modia3D/Frames/_module.jl)
#

"""
    const Modia3D.Vector3D = SVector{3,Float64}

Type of a vector in 3D space (e.g. position vector of the origin of a frame)
"""
const Vector3D = SVector{3,Float64}



"""
    const Modia3D.ZeroVector3D = Vector3D(0.0, 0.0, 0.0)

Constant of a Vector3D where all elements are zero
"""
const ZeroVector3D = Vector3D(0.0, 0.0, 0.0)



"""
    vec = Modia3D.axisValue(axis, value)
    vec = Modia3D.axisValue(axis, positive, value)

Return `vec::Vector3D` where all elements are zero with exception of `vec[axis] = value` or
`vec[axis] = positive ? value : -value`.    
"""
@inline axisValue(axis::Int, value::Number)::Vector3D = axis==1 ? @SVector([value, 0.0, 0.0]) : (axis==2 ? @SVector([0.0, value, 0.0]) : 
                                                       (axis==3 ? @SVector([0.0, 0.0, value]) : error("Bug in Modia3D: axisValue($axis, ...) - argument needs to be 1,2 or 3.")))
@inline axisValue(axis::Int, positive::Bool, value::Number)::Vector3D = positive ? axisValue(axis,value) : axisValue(axis,-value)




"""
    M = Modia3D.skew(e::AbstractVector)

Return the skew symmetric matrix `M::SMatrix{3,3,Float64,9}` of vector `e` (`length(e) = 3`)
"""
skew(e::AbstractVector) = @SMatrix([  0.0   -e[3]    e[2];
                                      e[3]   0.0    -e[1];
                                     -e[2]   e[1]    0.0 ])