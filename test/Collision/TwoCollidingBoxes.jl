module TwoCollidingBoxes

using Modia3D

vmat1 = VisualMaterial(color="Green", transparency=0.6)
vmat2 = VisualMaterial(color="Red"  , transparency=0.6)
cmat = "Steel"

collidingBoxes = Model(
    world = Object3D(feature=Scene(gravityField=UniformGravityField(g=9.81, n=[-1, 0, 0]), mprTolerance = 1.0e-9,
                                          enableContactDetection=true)),

    fixedBox = Object3D(parent=:world,
                        translation=[-3.0, 0.0, -2.5],
                        feature=Solid(shape=Box(lengthX=3.0, lengthY=2.0, lengthZ=5.0),
                                      solidMaterial="Aluminium",
                                      visualMaterial=vmat1,
                                      contactMaterial=cmat,
                                      collision=true,
                                      collisionSmoothingRadius=0.001)),

    movingBox = Object3D(feature=Solid(shape=Box(lengthX=0.5, lengthY=0.5, lengthZ=0.5),
                                       solidMaterial="Aluminium",
                                       visualMaterial=vmat2,
                                       contactMaterial=cmat,
                                       collision=true,
                                       collisionSmoothingRadius=0.001)),
    movingBoxJoint = FreeMotion(obj1=:world, obj2=:movingBox,
                                r=Var(init=[0.0, 0.0, 0.0]),
                                rot=Var(init=[pi/2, 0.0, 0.0]))
)

twoCollidingBoxes = @instantiateModel(buildModia3D(collidingBoxes), unitless=true, log=false, logStateSelection=false, logCode=false)

stopTime = 3.0
tolerance = 1e-6
interval = 0.001
if Sys.iswindows()
    requiredFinalStates = [-4.545411902572032, -0.0004339548925595526, 0.997958461213036, -7.952963881809473, -0.0005737829147323827, 1.0504837525229056, 1.5704114560517215, -0.000736947651219812, 4.178796873901921, -0.0006362640507553737, 0.0016059923768505658, 4.7729118080050466]
else
    requiredFinalStates = [-4.539994107706228, -3.9895800164887376e-5, 1.0062426501885768, -7.945240606955788, -5.092515873863734e-5, 1.0612235633669154, 1.570658199884234, 0.000303670527292675, 4.197282711848592, 0.0006744468205883097, -0.0006760290317853639, 4.797671511349969]
end

simulate!(twoCollidingBoxes, stopTime=stopTime, tolerance=tolerance, interval=interval, log=true, logStates=false, logEvents=false, requiredFinalStates=requiredFinalStates)

@usingModiaPlot
plot(twoCollidingBoxes, ["movingBoxJoint.r" "movingBoxJoint.rot"; "movingBoxJoint.v" "movingBoxJoint.w"], figure=1)

end
