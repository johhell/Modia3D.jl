module GrippingDetection

export GrippingPair, changeParentOfMovableUnit!, checkGrippingFeatures

import Modia3D
import Modia3D.Basics
import Modia3D.Composition
using LinearAlgebra

const NOTHING = Nothing

export GripStatus, Grip, Release, ReleaseAndSetDown, Delete, NoAction

@enum GripStatus Grip Release ReleaseAndSetDown Delete NoAction

include("grippingPair.jl")

end