module ServoWithPathAndRevolute

using Base: Float64
using Modia3D

include("$(Modia3D.modelsPath)/Blocks.jl")
include("$(Modia3D.modelsPath)/Electric.jl")
include("$(Modia3D.modelsPath)/Rotational.jl")

Controller = Model(
    # Interface
    refLoadAngle     = input,
    actualMotorAngle = input,
    actualMotorSpeed = input,
    refTorque        = output,
    # Components
    gainOuter     = Gain,
    angleFeedback = Feedback,
    gainInner     = Gain,
    speedFeedback = Feedback,
    PI = PI,

    connect = :[
        (refLoadAngle, gainOuter.u)
        (gainOuter.y,  angleFeedback.u1)
        (actualMotorAngle, angleFeedback.u2)
        (angleFeedback.y,  gainInner.u)
        (gainInner.y, speedFeedback.u1)
        (actualMotorSpeed, speedFeedback.u2)
        (speedFeedback.y,  PI.u)
        (PI.y, refTorque)]
)

Drive = Model(
    # Interface
    refTorque   = input,
    actualSpeed = output,
    actualAngle = output,
    flange      = Flange,
    # Components
    torque       = UnitlessTorque,
    speedSensor  = UnitlessSpeedSensor,
    angleSensor  = UnitlessAngleSensor,
    motorInertia = Inertia,
    idealGear    = IdealGear,

    connect = :[
        (refTorque, torque.tau)
        (torque.flange, speedSensor.flange, angleSensor.flange, motorInertia.flange_a)
        (motorInertia.flange_b, idealGear.flange_a)
        (idealGear.flange_b, flange)
        (speedSensor.w, actualSpeed)
        (angleSensor.phi, actualAngle)
        ]
)

Servo = Model(
    refLoadAngle = input,
    flange       = Flange,
    ppi          = Controller,
    drive        = Drive,

    connect = :[
        # inputs of ppi
        (refLoadAngle, ppi.refLoadAngle)
        (ppi.actualMotorSpeed, drive.actualSpeed)
        (ppi.actualMotorAngle, drive.actualAngle)
        # output of ppi --> input of motor
        (ppi.refTorque, drive.refTorque)
        # Flange of drive
        (drive.flange, flange)
        ]
)

axis = 3
vmat1 = VisualMaterial(color="LightBlue", transparency=0.5)

arm_joint_2_obj = joinpath(Modia3D.path, "objects/robot_KUKA_YouBot/arm_joint_2.obj")
m2 = 1.318
translation2 = [0.155, 0, 0]
#rotation2= [90u"°", 0.0, -90u"°"]

k1 = 50.0
k2 = 0.1
T2 = 1.0
gearRatio = 156.0
motorInertia = (0.0000135 + 0.000000409)*u"kg*m^2"
J1 = 0.32

servoParameters = Map(
                      ppi = Map(
                          gainOuter = Map(k=gearRatio),
                          gainInner = Map(k=k1),
                          PI        = Map(k=k2, T=T2)
                      ),
                      drive = Map(
                          motorInertia = Map(J=motorInertia),
                          idealGear = Map(ratio=gearRatio)
                      )
                  )

initPosition = [0.0]

function robotProgram(robotActions)
    addReferencePath(robotActions,
        names = ["angle2"],
        position = initPosition,
        v_max = [2.68512],
        a_max = [1.5])

    ptpJointSpace(robotActions, [0.0; 0.3; 0.0])

    return nothing
end


# getReferencePath() = referencePath1

TestServo = Model3D(
    world = Object3D(feature=Scene(nominalLength=0.2)),
    body  = Object3D(feature=Solid(shape=FileMesh(filename=arm_joint_2_obj),
                                   massProperties=MassPropertiesFromShapeAndMass(mass=m2),
                                   visualMaterial=vmat1)),
    obj2  = Object3D(parent=:body, translation=translation2),

    rev = RevoluteWithFlange(obj1=:world, obj2=:obj2, axis=axis, phi=Var(init = initPosition[1]), w=Var(init=0.0)),


    servo = Servo | servoParameters,
    modelActions = ModelActions(world=:world, actions=robotProgram),
    currentAction = Var(hideResult=true),
    equations=:[
        currentAction = executeActions(modelActions),
        servo.refLoadAngle = getRefPathPosition(currentAction, 1)
    ],

    connect = :[
        (servo.flange, rev.flange)
    ]
)

servo = @instantiateModel(TestServo, unitless=true, logCode=false, log=false)

stopTime = 4.0
tolerance = 1e-6
requiredFinalStates = [2.1923247415673457e-7, -2.1923342072392868e-7, -0.06934863003447111]
simulate!(servo, stopTime=stopTime, tolerance=tolerance, log=true, logStates=false, logEvents=false, requiredFinalStates=requiredFinalStates)

@usingModiaPlot
plotVariables = [("servo.refLoadAngle", "rev.phi"); "servo.ppi.gainOuter.u"; "rev.w"; "servo.ppi.PI.x"; "servo.ppi.refTorque"]
plot(servo, plotVariables, figure=1)

end
