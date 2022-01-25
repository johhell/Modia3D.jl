module PendulumWithDamper

using ModiaLang

# ModiaLang models
include("$(ModiaLang.path)/models/Blocks.jl")
include("$(ModiaLang.path)/models/Electric.jl")
include("$(ModiaLang.path)/models/Rotational.jl")

using Modia
using Measurements

Pendulum = Model(
    m = 1.0,
    g = 9.81,
    vmat1 = VisualMaterial(color="Sienna", transparency=0.5),
    vmat2 = VisualMaterial(color="Red"),
    world = Object3D(feature=Scene(enableContactDetection=false)),
    worldFrame = Object3D(parent=:world,
                          feature=Visual(shape=CoordinateSystem(length=0.5))),

    frame0 = Object3D(feature=Solid(shape=Beam(axis=1, length=1.0, width=0.2, thickness=0.2),
                                    massProperties=MassProperties(mass=:m),
                                    visualMaterial=:(vmat1))),
    frame1 = Object3D(parent=:(frame0),
                      translation=[-0.5, 0.0, 0.0]),
    cyl    = Object3D(parent=:(frame1),
                      feature=Visual(shape=Cylinder(axis=3, diameter=0.2/2, length=1.2*0.2),
                                     visualMaterial=:(vmat2))),
    rev    = RevoluteWithFlange(obj1=:world, obj2=:frame1)
)

PendulumWithDamp = Model(
    pendulum = buildModia3D(Pendulum | Map(m=2.0 ± 1.0, rev=Map(phi=Var(init=1.0)))),

    damper = Damper | Map(d=0.5),
    fixed = Fixed,
    connect = :[(damper.flange_b, pendulum.rev.flange),
                (damper.flange_a, fixed.flange)]
)

#@showModel PendulumWithDamp

pendulumWithDamper = @instantiateModel(PendulumWithDamp, unitless=true, log=false, logStateSelection=false, logCode=false, FloatType =Measurements.Measurement{Float64})

stopTime = 10.0
requiredFinalStates = [-1.578178283450938, 0.061515170100766486]

simulate!(pendulumWithDamper, stopTime=stopTime, log=true, logStates=false, requiredFinalStates=requiredFinalStates)

@usingModiaPlot
plot(pendulumWithDamper, ["pendulum.rev.flange.phi", "pendulum.rev.variables[1]"], figure=1)

end
