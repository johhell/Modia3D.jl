module TwoCollidingBoxes

using Modia3D

vmat1 = VisualMaterial(color="Green", transparency=0.6)
vmat2 = VisualMaterial(color="Red"  , transparency=0.6)
cmat = "Steel"

collidingBoxes = Model3D(
    world = Object3D(feature=Scene(gravityField=UniformGravityField(g=9.81, n=[-1, 0, 0]),
                                   nominalLength=2.0,
                                   mprTolerance=1.0e-9,
                                   enableContactDetection=true)),

    fixedBox = Object3D(parent=:world,
                        translation=[-3.0, 0.0, -2.5],
                        feature=Solid(shape=Box(lengthX=3.0, lengthY=2.0, lengthZ=5.0),
                                      solidMaterial="Aluminium",
                                      visualMaterial=vmat1,
                                      contactMaterial=cmat,
                                      collision=true,
                                      collisionSmoothingRadius=0.001)),

    movingBox = Object3D(parent=:world, fixedToParent=false,
                         rotation=[pi/2, 0.0, 0.0],
                         feature=Solid(shape=Box(lengthX=0.5, lengthY=0.5, lengthZ=0.5),
                                       solidMaterial="Aluminium",
                                       visualMaterial=vmat2,
                                       contactMaterial=cmat,
                                       collision=true,
                                       collisionSmoothingRadius=0.001))
)

twoCollidingBoxes = @instantiateModel(collidingBoxes, unitless=true, log=false, logStateSelection=false, logCode=false)

stopTime = 3.0
tolerance = 1e-6
interval = 0.001
requiredFinalStates = missing

simulate!(twoCollidingBoxes, stopTime=stopTime, tolerance=tolerance, interval=interval, log=true, logStates=false, logEvents=false,
         requiredFinalStates_rtol=0.01, requiredFinalStates_atol=0.01, requiredFinalStates=requiredFinalStates)

@usingModiaPlot
plot(twoCollidingBoxes, ["movingBox.translation" "movingBox.rotation"; "movingBox.velocity" "movingBox.angularVelocity"], figure=1)

end
