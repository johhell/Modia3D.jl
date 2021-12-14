# License for this file: MIT (expat)
# Copyright 2017-2020, DLR Institute of System Dynamics and Control

module Modia3D

const path = dirname(dirname(@__FILE__))   # Absolute path of package directory
const Version = "0.5.2"
const Date = "2021-11-29"

# println("\nImporting Modia3D Version $Version ($Date)")


# Abstract types
abstract type AbstractObject3DFeature end                                 # Data associated with one Object3D
abstract type AbstractVisualElement  <: AbstractObject3DFeature     end   # Visual element associated with one Object3D
abstract type AbstractShape       <: AbstractVisualElement end   # Geometry type
abstract type AbstractGeometry    <: AbstractShape end   # Immutable shape type that  has a volume and optionally mass. Can be used in collisions.

abstract type AbstractContactMaterial   end   # Contact properties of a solid (e.g. spring constant)
abstract type AbstractContactDetection  end   # Contact detection type
abstract type AbstractGravityField      end   # Gravity field type
abstract type AbstractRenderer          end   # Renderer type
abstract type AbstractDLR_VisualizationRenderer <: AbstractRenderer end   # Community or Professional edition of DLR_Visualization renderer

abstract type AbstractMassPropertiesInterface end
abstract type AbstractMassProperties    end

abstract type AbstractContactPairMaterial end # Constants needed to compute the contact response between two objects

abstract type AbstractObject3D end
abstract type AbstractTwoObject3DObject <: AbstractObject3D end  # Object related to two Object3Ds
abstract type AbstractJoint             <: AbstractTwoObject3DObject end  # Constraint between two Object3Ds
abstract type AbstractForceElement      <: AbstractObject3D end

abstract type AbstractScene end

using StaticArrays
@inline cross(x::SVector{3,F}, y::SVector{3,F}) where {F} = @inbounds SVector{3,F}(x[2]*y[3]-x[3]*y[2],
                                                                                           x[3]*y[1]-x[1]*y[3],
                                                                                           x[1]*y[2]-x[2]*y[1])



# Enumerations
@enum Ternary      True False Inherited

"""
    @enum AnalysisType KinematicAnalysis QuasiStaticAnalysis DynamicAnalysis

Type of analyis that is actually carried out. The `AnalysisType` is set by the user
of the simulation model. Variables are declared in the model with [`VariableAnalysisType`](@ref)`.
Variables with [`VariableAnalysisType`](@ref)` <= AnalysisType` are removed from the analysis and do
not show up in the result. For example, an *acceleration* would be declared as `OnlyDynamicAnalysis`
and then this variable would not show up in the result, if `AnalysisType = KinematicAnalysis` or
`QuasiStaticAnalysis`.

Currently, only DynamicAnalysis is supported and used.
"""
@enum AnalysisType KinematicAnalysis QuasiStaticAnalysis DynamicAnalysis
@enum VariableAnalysisType AllAnalysis QuasiStaticAndDynamicAnalysis OnlyDynamicAnalysis NotUsedInAnalysis


# Used renderer (actual value is defined with __init__() below)
const renderer = Vector{AbstractRenderer}(undef,2)




import Unitful

numberType(value) = ModiaLang.baseType(eltype(value))

"""
    convertAndStripUnit(TargetType, requiredUnit, value)

Return the `value` of a variable converted to the `requiredUnit` and the required `TargetType`.
The `value` can be a scalar, array or collection of a primitive type, such as Float64,
or of a primitive type with units, or of a Measurement type.

- If `value` has no unit, it is converted to `TargetType`.
- If `value` has a unit, it is converted to the `requiredUnit`, then the unit is stripped,
  and finally it is converted to `TargetType`.

# Example

```julia
using Unitful

# :L has unit u"m"
convertAndStripUnit(Float32, 0.01u"km", u"m")  # = 10.0f0
convertAndStripUnit(Float32, 10.0)             # = 10.0f0
```
"""
convertAndStripUnit(TargetType, requiredUnit, value) =
    numberType(value) <: Unitful.AbstractQuantity && unit.(value) != Unitful.NoUnits ?
            convert(TargetType, ustrip.( uconvert.(requiredUnit, value))) : convert(TargetType, value)

# MPRFloatType is used to change betweeen Double64 and Float64 for mpr calculations
using DoubleFloats
const MPRFloatType = Double64

# Include sub-modules
include(joinpath("Frames"           , "_module.jl"))
include(joinpath("Basics"           , "_module.jl"))
include(joinpath("Shapes"         , "_module.jl"))
include(joinpath("Composition"      , "_module.jl"))
include(joinpath("AnimationExport"  , "_module.jl"))
include(joinpath("PathPlanning"     , "_module.jl"))
include(joinpath("renderer"         , "DLR_Visualization"  , "_module.jl"))
include(joinpath("renderer"         , "NoRenderer"         , "_module.jl"))
include(joinpath("contactDetection" , "ContactDetectionMPR", "_module.jl"))
include(joinpath("Interface"        , "_module.jl"))
include(joinpath("ModiaInterface"   , "_module.jl"))


# Make symbols available that have been exported in sub-modules
using  .Frames
using  .Basics
using  .Shapes
using  .AnimationExport
using  .Composition
import .DLR_Visualization
import .NoRenderer
using .PathPlanning
using .Interface
#const connect = Composition.connect  # connect cannot be directly exported, due to a conflict with Base.connect
const run     = Interface.run        # run cannot be directly exported, due to a conflict with Base.run


# Called implicitely at the first import/using of Modia3D (when loading Modia3D to the current Julia session)
function __init__()
    info = DLR_Visualization.getSimVisInfo()
    (directory, dll_name, isProfessionalEdition, isNoRenderer) = info

    if isNoRenderer
        renderer[1] = NoRenderer.DummyRenderer(info)
    elseif isProfessionalEdition
        renderer[1] = DLR_Visualization.ProfessionalEdition(info)
    else
        renderer[1] = DLR_Visualization.CommunityEdition(info)
end; end

function disableRenderer()
    renderer[2] = renderer[1]
    renderer[1] = NoRenderer.DummyRenderer(0)
    return nothing
end
function reenableRenderer()
    if !isnothing(renderer[2])
        renderer[1] = renderer[2]
    end
    return nothing
end


export Object3D

export Sphere, Ellipsoid, Box, Cylinder, Capsule, Beam, Cone
export Spring, GearWheel, CoordinateSystem, Grid, FileMesh, ModelicaShape

export Solid, Visual
export MassProperties
export Fix
export Revolute, Prismatic

export UniformGravityField, PointGravityField, NoGravityField
export VisualMaterial
export Scene, SimulationModel
export print_ModelVariables

export PTP_path, pathEndTime, getPosition!, getPosition, getIndex, plotPath

export calculateRobotMovement

# Add import clauses used in examples and test
import StaticArrays
import Unitful
import LinearAlgebra
import Test
import ModiaLang

end # module
