module Pendulum2

using  ModiaLang
import Modia3D
using  Modia3D.ModiaInterface

Pendulum = Model(
    world = Object3D(feature=Scene(animationFile="Pendulum2.json")),
    obj1  = Object3D(feature=Solid(shape=Box(lengthX=1.0, lengthY=0.2, lengthZ=0.2),
                solidMaterial="Steel", visualMaterial=VisualMaterial(color="Blue"))),
    obj2  = Object3D(parent=:obj1, feature=Visual(shape=Cylinder(diameter=0.1, length=0.21),
                visualMaterial=VisualMaterial(color="Red")), translation=[-0.5, 0.0, 0.0]),
    rev   = Revolute(obj1=:world, obj2=:obj2)
)

pendulum = @instantiateModel(buildModia3D(Pendulum), unitless=true)
simulate!(pendulum, stopTime=3.0)

@usingModiaPlot
plot(pendulum, "rev.phi")
end
