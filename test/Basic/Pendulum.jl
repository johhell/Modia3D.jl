module PendulumModule

using ModiaLang
import Modia3D
using  Modia3D.ModiaInterface

Pendulum = Model3D(
    world     = Object3D(feature=Scene()),
    body      = Object3D(feature=Solid(massProperties=MassProperties(mass=1.0))),
    bodyFrame = Object3D(parent=:body, translation=[-0.5, 0.0, 0.0]),
    rev       = Revolute(obj1=:world, obj2=:bodyFrame)
)

pendulum = @instantiateModel(Pendulum, unitless=true, log=false, logDetails=false, logCode=true, logStateSelection=false, logCalculations=false)
simulate!(pendulum, stopTime=3.0, log=true)

@usingModiaPlot
plot(pendulum, "rev.phi")


end