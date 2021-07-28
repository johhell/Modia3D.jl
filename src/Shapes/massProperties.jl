# License for this file: MIT (expat)
# Copyright 2017-2018, DLR Institute of System Dynamics and Control
#
# This file is part of module
#   Modia3D.Shapes (Modia3D/Solids/_module.jl)
#


# MassProperties consisting of mass m, center of mass rCM and inertia tensor I
struct MassProperties <: Modia3D.AbstractMassProperties
    m::Float64                 # mass [kg]
    rCM::Frames.Vector3D       # position vector from object3d frame to center of mass resolved in object3d frame [m]
    I::SMatrix{3,3,Float64,9}  # inertia matrix w.r.t. center of mass resolved in object3d frame [kg.m^2]

    #---------------- different constructors for MassProperties -----------------
    # Constructor 0: takes mass, centerOfMass and inertiaMatrix as input values
    function MassProperties(mass::Number, centerOfMass::AbstractVector, inertiaMatrix::AbstractMatrix)
        @assert(mass > 0.0)
        new(mass, centerOfMass, inertiaMatrix)
    end
end


struct MassPropertiesFromShape <: Modia3D.AbstractMassProperties
    function MassPropertiesFromShape()
        new()
    end
end

struct MassPropertiesFromShapeAndMass <: Modia3D.AbstractMassProperties
    mass::Number   # mass in [kg]

    function MassPropertiesFromShapeAndMass(;mass::Number=1.0)
        @assert(mass >= 0.0)
        new(mass)
    end
end


function Base.show(io::IO, mp::MassProperties)
    print(io, "mass = ", mp.m,
            ", centerOfMass = ", mp.rCM,
            ", Ixx = ", mp.I[1,1],
            ", Iyy = ", mp.I[2,2],
            ", Izz = ", mp.I[3,3],
            ", Ixy = ", mp.I[1,2],
            ", Ixz = ", mp.I[1,3],
            ", Iyz = ", mp.I[2,3])
end

# Constructor a: mass, centerOfMass and entries of inertia tensor are optional
#                --> if nothing special is defined it takes predefined values (= zero values)
MassProperties(; mass::Number=0.0, centerOfMass=Modia3D.ZeroVector3D,
               Ixx::Number=0.0, Iyy::Number=0.0, Izz::Number=0.0,
               Ixy::Number=0.0, Ixz::Number=0.0, Iyz::Number=0.0) =
                  MassProperties(mass, centerOfMass, [Ixx Ixy Ixz; Ixy Iyy Iyz; Ixz Iyz Izz])
# Constructor b: shape and mass is given, center of mass and inertia tensor is
#                calculated via shape --> constructor 0 is called
MassProperties(shape::Modia3D.AbstractGeometry, mass::Number) =
                     MassProperties(mass, centroid(shape), inertiaMatrix(shape,mass))
# Constructor c: shape and material is given, mass is computed via volume of
#                shape and density --> constructor b is called
MassProperties(shape::Modia3D.AbstractGeometry, material::SolidMaterial) =
                     MassProperties(shape, material.density*volume(shape))
# Constructor d: shape and materialName is given, material must be defined in
#                solidMaterialPalette --> constructor c is called
MassProperties(shape::Modia3D.AbstractGeometry, materialName::AbstractString) =
                     MassProperties(shape, solidMaterialPalette[materialName])

# structure InternalMassProperties is only for internal purposes
mutable struct InternalMassProperties <: Modia3D.AbstractMassProperties
   m::Float64                 # mass in [kg]
   rCM::Frames.Vector3D   # center of mass in [m]
   I::SMatrix{3,3,Float64,9}  # inertia matrix in [kg.m^2]

   InternalMassProperties() = new(0.0, Modia3D.ZeroVector3D,
                                  SMatrix{3,3,Float64,9}(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0))
end


#=
getMassProperties(massProperties::Union{Modia3D.AbstractMassProperties, Number, AbstractString, SolidMaterial, Nothing},
                  shape::Modia3D.AbstractGeometry, solidMaterial::Union{AbstractString,SolidMaterial,Nothing}) = createMassProperties(massProperties, shape, solidMaterial)
=#
createMassProperties(massProperties::MassProperties, shape, solidMaterial) = massProperties

createMassProperties(massProperties::Union{Number, SolidMaterial, AbstractString}, shape::Modia3D.AbstractGeometry, solidMaterial) = MassProperties(shape, massProperties)

# compute mass properties from shape and material
function createMassProperties(massProperties::Union{MassPropertiesFromShape,Nothing}, shape::Modia3D.AbstractGeometry, solidMaterial::Union{AbstractString,SolidMaterial,Nothing})
    if isnothing(solidMaterial)
        error("It is not possible to compute mass properties (MassPropertiesFromShape = ", massProperties,") for shape = ", shape , " because no solidMaterial is defined.")
    else
        return Modia3D.MassProperties(shape, solidMaterial)
    end
end

# compute mass properties from shape and mass
function createMassProperties(massProperties::MassPropertiesFromShapeAndMass, shape::Modia3D.AbstractGeometry, solidMaterial::Union{AbstractString,SolidMaterial,Nothing})
    return Modia3D.MassProperties(shape, massProperties.mass)
end

function createMassProperties(massProperties::MassPropertiesFromShape, shape::Nothing, solidMaterial::Union{AbstractString,SolidMaterial,Nothing})
    error("It is not possible to compute mass properties (MassPropertiesFromShape = ", massProperties,") because no shape is defined.")
end

function createMassProperties(massProperties::MassPropertiesFromShapeAndMass, shape::Nothing, solidMaterial::Union{AbstractString,SolidMaterial,Nothing})
    error("It is not possible to compute mass properties (MassPropertiesFromShapeAndMass) if no shape is defined.")
end