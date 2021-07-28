module PendulumWithFixSimulation

using ModiaLang

# ModiaLang models
include("$(ModiaLang.path)/models/Blocks.jl")
include("$(ModiaLang.path)/models/Electric.jl")
include("$(ModiaLang.path)/models/Rotational.jl")

import Modia3D
using  Modia3D.ModiaInterface

Bar = Model(
    m  = 0.1,
    Lx = 0.1,
    Ly = Par(value=:(0.2*Lx)),
    Lz = Par(value=:(0.2*Lx)),
    vmat1 = VisualMaterial(color="Teal", transparency=0.5),
    vmat2 = VisualMaterial(color="Red"),
    frame0 = Object3D(feature=Solid(shape=Beam(axis=1, length=:Lx, width=:Ly, thickness=:Lz),
                                    massProperties=MassProperties(mass=:m),
                                    visualMaterial=:(vmat1))),
	frame1 = Object3D(parent=:frame0,
                      translation=:[-Lx/2, 0.0, 0.0],
                      feature=Visual(shape=Cylinder(axis=3, diameter=:(Ly/2), length=:(1.2*Lz)),
                                     visualMaterial=:(vmat2))),
    frame2 = Object3D(parent=:frame0, translation=:[Lx/2, 0.0, 0.0])
)

Pendulum = Model(
    m = 1.0,
    Lx = 0.1,
    world = Object3D(feature=Scene() ),
    worldFrame = Object3D(parent=:world,
                          feature=Visual(shape=CoordinateSystem(length=:(Lx/2)))),
    bar0 = Bar | Map(m=:m, Lx=:Lx),
    rev = RevoluteWithFlange(obj1=:world, obj2=:(bar0.frame1)),
    bar1 = Bar | Map(m=:m, Lx=:Lx),
    fix1 = Fix(obj1=:(bar0.frame2), obj2=:(bar1.frame1), translation=:[0.0, -Lx/4, 0.0]),
    bar2 = Bar | Map(m=:m, Lx=:Lx),
    fix2 = Fix(obj1=:(bar0.frame2), obj2=:(bar2.frame1), translation=:[0.0, Lx/4, 0.0], rotation=[0.0, 0.0, 45*pi/180]),
    capsule1 = Object3D(feature=Solid(shape=Capsule(axis=3, length=:(Lx/2), diameter=:(Lx/4)), solidMaterial="DryWood", visualMaterial="BlueTransparent")),
    fix3 = Fix(obj1=:(bar1.frame2), obj2=:capsule1, translation=:[Lx/4, 0.0, 0.0], rotation=[90*pi/180, 0.0, 0.0]),
    capsule2 = Object3D(feature=Solid(shape=Capsule(axis=3, length=:(Lx/2), diameter=:(Lx/4)), solidMaterial="DryWood", visualMaterial="GreenTransparent")),
    fix4 = Fix(obj1=:capsule2, obj2=:(bar2.frame2), translation=:[-Lx/4, 0.0, 0.0], rotation=[-90*pi/180, 0.0, 0.0])
)

PendulumWithFix = Model(
    pendulum = buildModia3D(Pendulum | Map(Lx=1.0, m=2.0, rev=Map(phi=Var(init=1.0)))),

    damper = Damper | Map(d=100.0),
    fixed = Fixed,
    connect = :[(damper.flange_b, pendulum.rev.flange),
                (damper.flange_a, fixed.flange)]
)

pendulumWithFix = @instantiateModel(PendulumWithFix, unitless=true)

stopTime = 10.0
requiredFinalStates = [-1.6164397926928633, 0.4670955914743122]
simulate!(pendulumWithFix, stopTime=stopTime, log=true, logStates=true, requiredFinalStates=requiredFinalStates)

@usingModiaPlot
plot(pendulumWithFix, ["pendulum.rev.flange.phi", "pendulum.rev.variables[1]"], figure=1)

end