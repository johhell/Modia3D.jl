# Following order of operations on of solid geometries:
#   1. bottomArea(shape): returns the bottom area of a solid shape
#   2. topArea(shape): returns the top area of a solid shape
#   3. volume(shape): computes the volume of a solid shape
#   3. longestEdge(shape): returns is the maximum of all directions (especially needed for FileMesh)
#   5. lengthGeo(shape): returns length of geometries in z direction
#   6. centroid(shape): returns position vector from solid reference to centroid
#   7. inertiaMatrix(shape, mass): returns inertia matrix of solid with respect to reference frame
#      Useful web pages:
#         https://en.wikipedia.org/wiki/List_of_moments_of_inertia
#         https://en.wikipedia.org/wiki/List_of_second_moments_of_area


using LinearAlgebra
EYE3() = Matrix(1.0I,3,3)

const InertiaMatrix  = SMatrix{3,3,Float64,9}


### ------------------------ bottom and top area -------------------------------
bottomArea(shape::Modia3D.AbstractGeometry)  = error(typeof(shape), ": has no bottom or top area!")
bottomArea(shape::Box)       = shape.lengthX*shape.lengthY
bottomArea(shape::Cylinder)  = pi*((shape.diameter/2)^2 - (shape.innerDiameter/2)^2)
bottomArea(shape::Cone)      = pi*(shape.diameter/2)^2
bottomArea(shape::Beam)      = shape.length*shape.width + pi*(shape.width/2)^2


## top area: Cone for other geometrie take bottom area (if defined)
topArea(shape::Modia3D.AbstractGeometry) = bottomArea(shape)
topArea(shape::Cone) = pi*(shape.topDiameter/2)^2


### ------------------------- volume -------------------------------------------
## volume: Sphere, Ellipsoid, Capsule, Cone, FileMesh
## others are computed via bottomArea * lengthGeo
"""
    V = volume(shape)

Return the volume of the solid shape `shape::Modia3D.AbstractGeometry` in [m^3].
"""
volume(shape::Modia3D.AbstractGeometry) = bottomArea(shape)*lengthGeo(shape)
volume(shape::Sphere)    = 4/3*pi*(shape.diameter/2)^3
volume(shape::Ellipsoid) = 4/3*pi*shape.lengthX/2*shape.lengthY/2*shape.lengthZ/2
volume(shape::Cone)      = pi/12*shape.length*(shape.diameter^2 + shape.diameter*shape.topDiameter + shape.topDiameter^2)

function volume(shape::Capsule)
    r = shape.diameter/2
    h = shape.length
    return pi*r^2*h + 4/3*pi*r^3
end

function volume(shape::FileMesh)
  if !isempty(shape.facesIndizes)
    return shape.volume
  else
    println("FileMesh: ", shape.filename, ". The surface areas must be triangular, and each triangle should be specified in right-handed/counter-clockwise order. Otherwise it is not possible to compute a volume.")
    return nothing
end; end


### --------------------------- longest edge  ----------------------------------
#   is the maximum of all directions (especially needed for FileMesh)
longestEdge(shape::Sphere)    = shape.diameter
longestEdge(shape::Ellipsoid) = max(shape.lengthX, shape.lengthY, shape.lengthZ)
longestEdge(shape::Box)       = max(shape.lengthX, shape.lengthY, shape.lengthZ)
longestEdge(shape::Cylinder)  = max(shape.diameter, shape.length)
longestEdge(shape::Cone)      = max(shape.diameter, shape.length)
longestEdge(shape::Capsule)   = shape.length + shape.diameter
longestEdge(shape::Beam)      = max(shape.length + shape.width, shape.thickness)
longestEdge(shape::FileMesh)  = shape.longestEdge
longestEdge(shape::Modia3D.AbstractGeometry) = max(shape.Dx,shape.Dy,shape.Lz)


### -------------------------- length of shape ------------------------------
lengthGeo(shape::Modia3D.AbstractGeometry) = shape.Lz
lengthGeo(shape::Sphere)                   = shape.diameter
lengthGeo(shape::Ellipsoid)                = shape.lengthZ
lengthGeo(shape::Box)                      = shape.lengthZ
lengthGeo(shape::Cylinder)                 = shape.length
lengthGeo(shape::Cone)                     = shape.length
lengthGeo(shape::Beam)                     = shape.thickness
lengthGeo(shape::FileMesh)                 = error("lengthGeo(FileMesh) is not implemented yet!")


### ------------------------ centroid of geometries ----------------------------
#   it is the zero vector, only for Cone and FileMesh it is different
"""
    r = centroid(shape)

Return position vector from solid reference frame to [centroid](https://en.wikipedia.org/wiki/Centroid)
of solid `shape::Modia3D.AbstractGeometry` in [m]. If the solid has a uniform density,
the centroid is identical to the *center of mass*.
"""
@inline centroid(shape::Sphere) = Modia3D.ZeroVector3D
@inline centroid(shape::Ellipsoid) = Modia3D.ZeroVector3D
@inline centroid(shape::Box) = Modia3D.ZeroVector3D
@inline centroid(shape::Cylinder) = Modia3D.ZeroVector3D
@inline centroid(shape::Capsule) = Modia3D.ZeroVector3D
@inline centroid(shape::Beam) = Modia3D.ZeroVector3D

@inline centHeight(shape::Cone) = shape.length/4*(shape.diameter^2 + 2*shape.diameter*shape.topDiameter + 3*shape.topDiameter^2)/(shape.diameter^2 + shape.diameter*shape.topDiameter + shape.topDiameter^2)  # https://mathworld.wolfram.com/ConicalFrustum.html
@inline function centroid(shape::Cone)
    if shape.axis == 1
        return SVector{3,Float64}([centHeight(shape), 0.0, 0.0])
    elseif shape.axis == 2
        return SVector{3,Float64}([0.0, centHeight(shape), 0.0])
    else
        return SVector{3,Float64}([0.0, 0.0, centHeight(shape)])
    end
end

@inline function centroid(shape::FileMesh)
  if !isempty(shape.facesIndizes)
    return shape.centroidAlgo
  else
    return shape.centroid
end; end


### ----------------------- inertia matrix of geometries -----------------------
"""
   I = inertiaMatrix(shape, mass)

Return [inertia matrix] (https://en.wikipedia.org/wiki/Moment_of_inertia) `I` of solid
`shape::Modia3D.AbstractGeometry` w.r.t. center of mass resolved in object3d frame in
[kg*m^2] as `SMatrix{3,3,Float64,9}`. Hereby it is assumed that `shape` has uniform
density and `mass` is the mass of `shape` in [kg].
"""
inertiaMatrix(shape::Sphere, mass::Number) = InertiaMatrix(mass/10*shape.diameter^2*EYE3())

inertiaMatrix(shape::Ellipsoid, mass::Number) =
                InertiaMatrix(mass/20 * Diagonal([shape.lengthY^2 + shape.lengthZ^2, shape.lengthX^2 + shape.lengthZ^2, shape.lengthX^2 + shape.lengthY^2]))

inertiaMatrix(shape::Box, mass::Number) =
                InertiaMatrix(1/12*mass * Diagonal([shape.lengthY^2 + shape.lengthZ^2, shape.lengthX^2 + shape.lengthZ^2, shape.lengthX^2 + shape.lengthY^2]))

function inertiaMatrix(shape::Cylinder, mass::Number)  # https://en.wikipedia.org/wiki/List_of_moments_of_inertia
    Iax  = mass/2*((shape.diameter/2)^2 + (shape.innerDiameter/2)^2)
    Irad = mass/12*(3*((shape.diameter/2)^2 + (shape.innerDiameter/2)^2) + shape.length^2)
    if shape.axis == 1
        return InertiaMatrix(Diagonal([Iax, Irad, Irad]))
    elseif shape.axis == 2
        return InertiaMatrix(Diagonal([Irad, Iax, Irad]))
    else
        return InertiaMatrix(Diagonal([Irad, Irad, Iax]))
    end
end

function inertiaMatrix(shape::Cone, mass::Number)  # https://en.wikipedia.org/wiki/List_of_moments_of_inertia
    if shape.topDiameter == 0.0
        Iax  = 3/40*mass*shape.diameter^2
        Irad = 3/80*mass*(shape.diameter^2 + shape.length^2)
    else
        fullLength = shape.length*shape.diameter/(shape.diameter - shape.topDiameter)  # length from base to apex
        pruneLength = fullLength - shape.length                                  # length from top to apex
        fullVolume = pi/12*fullLength*shape.diameter^2                           # volume from base to apex
        pruneVolume = pi/12*pruneLength*shape.topDiameter^2                      # volume from top to apex
        fullMass = mass*fullVolume/(fullVolume - pruneVolume)                  # mass from base to apex
        pruneMass = mass*pruneVolume/(fullVolume - pruneVolume)                # mass from top to apex
        fullIrad = 3/80*fullMass*(shape.diameter^2 + 16*fullLength^2)            # moment of inertia from base to apex w.r.t. apex
        pruneIrad = 3/80*pruneMass*(shape.topDiameter^2 + 16*pruneLength^2)      # moment of inertia from top to apex w.r.t. apex
        dist = fullLength - centHeight(shape)                                    # distance between apex and centroid
        Iax  = 3/40*(fullMass*shape.diameter^2 - pruneMass*shape.topDiameter^2)
        Irad = (fullIrad - pruneIrad) - mass*dist^2                            # radial moment of intertia w.r.t. centroid
    end
    if shape.axis == 1
        return InertiaMatrix(Diagonal([Iax, Irad, Irad]))
    elseif shape.axis == 2
        return InertiaMatrix(Diagonal([Irad, Iax, Irad]))
    else
        return InertiaMatrix(Diagonal([Irad, Irad, Iax]))
    end
end

function inertiaMatrix(shape::Capsule, mass::Number)
    rho = mass/volume(shape)
    rad = shape.diameter/2

    lenCyl = shape.length
    volCyl = pi*rad^2*lenCyl
    massCyl = volCyl*rho

    volHalfSph = 4/3*pi*rad^3/2
    massHalfSph = volHalfSph*rho

    # moments of inertia of cylinder w.r.t. center of mass of capsule
    IaxCyl = massCyl/2*rad^2
    IradCyl = massCyl/12*(3*rad^2 + lenCyl^2)

    # moment of inertia of half sphere w.r.t. center of full sphere (same formula as for full sphere because of half mass)
    IaxHalfSph = 2/5*massHalfSph*rad^2

    # distance between centers of mass of full sphere and of half sphere https://en.wikipedia.org/wiki/List_of_centroids
    distCoM = 3/8*rad

    # radial moment of inertia of half sphere w.r.t. center of mass of half sphere
    IradHalfSph = IaxHalfSph - massHalfSph*distCoM^2

    # radial moment of inertia of half cylinder w.r.t. center of mass of capsule
    IradHalfSph = IradHalfSph + massHalfSph*(distCoM + lenCyl/2)^2

    Iax  = IaxCyl  + 2*IaxHalfSph
    Irad = IradCyl + 2*IradHalfSph
    if shape.axis == 1
        return InertiaMatrix(Diagonal([Iax, Irad, Irad]))
    elseif shape.axis == 2
        return InertiaMatrix(Diagonal([Irad, Iax, Irad]))
    else
        return InertiaMatrix(Diagonal([Irad, Irad, Iax]))
    end
end

function inertiaMatrix(shape::Beam, massGeo::Number)
    rho = massGeo/volume(shape)

    volBox = shape.length*shape.thickness*shape.width
    massBox = volBox*rho

    radCyl = shape.width/2
    volHalfCyl = pi*radCyl^2*shape.thickness/2
    massHalfCyl = volHalfCyl*rho

    # moments of inertia of box w.r.t. center of mass of beam
    IlBox = massBox/12*(shape.width^2 + shape.thickness^2)
    IwBox = massBox/12*(shape.thickness^2 + shape.length^2)
    ItBox = massBox/12*(shape.length^2 + shape.width^2)

    # moments of inertia of half cylinder w.r.t. center of full cylinder (same formulas as for full cylinder because of half mass)
    IlCylHalf = massHalfCyl/12*(3*radCyl^2 + shape.thickness^2)
    IwCylHalf = massHalfCyl/12*(3*radCyl^2 + shape.thickness^2)
    ItCylHalf = massHalfCyl/2*radCyl^2

    # distance between centers of mass of full cylinder and of half cylinder https://en.wikipedia.org/wiki/List_of_centroids
    distCoM = 4/(3*pi)*radCyl

    # moments of inertia of half cylinder w.r.t. center of mass of half cylinder
    IwCylHalf = IwCylHalf - massHalfCyl*distCoM^2
    ItCylHalf = ItCylHalf - massHalfCyl*distCoM^2

    # moments of inertia of half cylinder w.r.t. center of mass of beam
    IwCylHalf = IwCylHalf + massHalfCyl*(distCoM + shape.length/2)^2
    ItCylHalf = ItCylHalf + massHalfCyl*(distCoM + shape.length/2)^2

    Il = IlBox + 2*IlCylHalf
    Iw = IwBox + 2*IwCylHalf
    It = ItBox + 2*ItCylHalf
    if shape.axis == 1
        return InertiaMatrix(Diagonal([Il, Iw, It]))
    elseif shape.axis == 2
        return InertiaMatrix(Diagonal([It, Il, Iw]))
    else
        return InertiaMatrix(Diagonal([Iw, It, Il]))
    end
end

function inertiaMatrix(shape::FileMesh, mass::Number)
    if !isempty(shape.facesIndizes)
        return shape.inertia.*mass
    else
        println("FileMesh: ", shape.filename, ". The surface areas must be triangular, and each triangle should be specified in right-handed/counter-clockwise order. Otherwise it is not possible to compute an inertia tensor.")
        return nothing
    end
end