module PendulumWithBar3

using  Modia3D
import Modia3D.JSON

include("$(Modia3D.modelsPath)/Blocks.jl")
include("$(Modia3D.modelsPath)/Electric.jl")
include("$(Modia3D.modelsPath)/Rotational.jl")

Bar = Model(
    m  = 0.1,
    Lx = 0.1,
    Ly = Par(value=:(0.2*Lx)),
    Lz = Par(value=:(0.2*Lx)),
    vmat1 = VisualMaterial(color="DeepSkyBlue2", transparency=0.5),
    vmat2 = VisualMaterial(color="Red"),
    frame0 = Object3D(feature=Solid(shape=Beam(axis=1, length=:Lx, width=:Ly, thickness=:Lz),
                                    massProperties=MassProperties(mass=:m),
                                    visualMaterial=:(vmat1))),
	frame1 = Object3D(parent=:frame0,
                      translation=:[-Lx/2, 0.0, 0.0],
                      feature=Visual(shape=Cylinder(axis=3, diameter=:(Ly/2), length=:(1.2*Lz)),
                                     visualMaterial=:(vmat2)))
)

Pendulum = Model3D(
    m = 1.0,
    Lx = 0.1,
    world = Object3D(feature=Scene(provideAnimationHistory=true, enableVisualization=false) ),
    worldFrame = Object3D(parent=:world,
                          feature=Visual(shape=CoordinateSystem(length=:(Lx/2)))),
    bar = Bar | Map(m=:m, Lx=:Lx),
    rev = RevoluteWithFlange(obj1=:world, obj2=:(bar.frame1))
)

PendulumWithBar = Model(
    pendulum = Pendulum | Map(Lx=1.0, m=2.0, rev=Map(phi=Var(init=1.0))),

    damper = Damper | Map(d=0.5),
    fixed = Fixed,
    connect = :[(damper.flange_b, pendulum.rev.flange),
                (damper.flange_a, fixed.flange)]
)

pendulumWithBar = @instantiateModel(PendulumWithBar, unitless=true)

algorithm = Tsit5()
simulate!(pendulumWithBar, algorithm, interval=0.1, stopTime=0.3)

# Test generation of animation history
animationHistory = get_animationHistory(pendulumWithBar, "pendulum")
animationHistoryJson = JSON.json(animationHistory,2)
@show animationHistoryJson
@show animationHistory["time"]
@show animationHistory["pendulum.worldFrame"]
@show animationHistory["pendulum.bar.frame0"]
@show animationHistory["pendulum.bar.frame1"]

end