# License for this file: MIT (expat)
# Copyright 2017-2018, DLR Institute of System Dynamics and Control

using LinearAlgebra

# returns true, if AABB's are touching
AABB_touching(aabb1::Basics.BoundingBox, aabb2::Basics.BoundingBox) = aabb1.x_max >= aabb2.x_min && aabb1.x_min <= aabb2.x_max &&
    aabb1.y_max >= aabb2.y_min && aabb1.y_min <= aabb2.y_max &&
    aabb1.z_max >= aabb2.z_min && aabb1.z_min <= aabb2.z_max



function Composition.initializeContactDetection!(world::Composition.Object3D, scene::Composition.Scene)::Nothing
    if typeof(scene.options.contactDetection) <: Modia3D.ContactDetectionMPR_handler
        ch = scene.options.contactDetection
        ch.contactPairs = Composition.ContactPairs(world, scene, ch.visualizeContactPoints,
            ch.visualizeSupportPoints, ch.defaultContactSphereDiameter)
        if ch.contactPairs.nz == 0
            Composition.closeContactDetection!(ch)
            scene.collide = false
                @warn "... From Modia3D collision handler: Collision handling switched off, since no contacts can take place (nz=0).\n" *
                    "... You might need to set canCollide=true at joints.\n"
            return
        end
        @assert(ch.contactPairs.ne > 0)
        @assert(ch.contactPairs.nz > 0)
    end
end


function Composition.setComputationFlag(ch::Composition.ContactDetectionMPR_handler)
    ch.distanceComputed = false
end

# This function performs (a) a broad phase to determine which
# shapes are potentially in contact to each other, (b) computes
# the distances of these shapes in a narrow phase and (c) selects
# the nz shape pairs with the smallest distances and orders them
# according to their distances in O(n_n log(n_z)) operations.
# This function is called after initialization and after state events.
function Composition.selectContactPairsWithEvent!(sim, scene::Composition.Scene{F}, ch::Composition.ContactDetectionMPR_handler, world::Composition.Object3D) where F <: Modia3D.VarFloatType
    empty!(ch.contactDict)
    ch.noContactMinVal =  F(42.0)
    selectContactPairs!(sim,scene,ch,world,true)
    ch.contactPairs.nzContact = length(ch.contactDict)
    return nothing
end


# This function performs (a) a broad phase to determine which
# shapes are potentially in contact to each other, (b) computes
# the distances of these shapes in a narrow phase and (c) selects
# the nz shape pairs with the smallest distances and orders them
# according to their distances in O(n_n log(n_z)) operations.
# This function is called for contact detection during simulation.
# It also checks if the contact pairs (contact == true), from a previous call of selectContactPairsWithEvent!(...)
# are still true.
function Composition.selectContactPairsNoEvent!(sim, scene::Composition.Scene{F}, ch::Composition.ContactDetectionMPR_handler, world::Composition.Object3D) where F <: Modia3D.VarFloatType
    ch.noContactMinVal = F(42.0)
    selectContactPairs!(sim,scene,ch,world,false)
    return nothing
end


function selectContactPairs!(sim, scene::Composition.Scene{F}, ch::Composition.ContactDetectionMPR_handler, world::Composition.Object3D, hasEvent::Bool) where F <: Modia3D.VarFloatType
    if !ch.distanceComputed
        computeDistances(scene, ch, world, false, hasEvent)
    end

    # Store z in simulation engine
    if !isnothing(sim)
        simh = sim.eventHandler
        # z[1] ... zero crossing function from contact to no contact
        # max. distance (= min. penetration) of active contact pairs
        if isempty(ch.contactDict)
            simh.z[scene.zStartIndex] = F(-42.0)
        else
            (pair, key)  = findmax(ch.contactDict)
            simh.z[scene.zStartIndex] = pair.distanceWithHysteresis - ch.contact_eps
        end
        # z[2] ... zero crossing function from no contact to contact
        # min. distance of inactive contact pairs
        simh.z[1+scene.zStartIndex] = ch.noContactMinVal
    end
    ch.distanceComputed = true
    return nothing
end


# This function performs (a) a broad phase to determine which
# shapes are potentially in contact to each other, (b) computes
# the distances of these shapes in a narrow phase and (c)
# stores the distances of the contact pairs selected by the last
# call of function selectContactPairsWithEvent!(C) in z in O(n log(nz))
# operations. This function is called whenever the integrator
# requests a new zero-crossing function evaluation
function Composition.getDistances!(scene::Composition.Scene, ch::Composition.ContactDetectionMPR_handler, world::Composition.Object3D)
    if !ch.distanceComputed
        computeDistances(scene, ch, world, true, false)
        ch.distanceComputed = true
        #println("Abstand wird berechnet, ", length(ch.contactDict) )
    end
    return nothing
end


function computeDistances(scene::Composition.Scene{F}, ch::Composition.ContactDetectionMPR_handler, world::Composition.Object3D, phase2::Bool, hasEvent::Bool=true) where F <: Modia3D.VarFloatType
    noCPairs  = scene.noCPairs
    superObjs = scene.superObjs
    AABB = scene.AABB

    if length(superObjs) > 1
        k = 0
        @inbounds for i = 1:length(superObjs)
            superObj = superObjs[i].superObjCollision.superObj
            for j = 1:length(superObj)
                k = k +1
                obj = superObj[j]
                AABB[i][j] = Modia3D.boundingBox!(obj,
                    AABB[i][j]; tight=false, scaleFactor=F(0.01) )
                if scene.options.visualizeBoundingBox
                    updateVisualBoundingBox!(world.AABBVisu[k], AABB[i][j])
                end
            end
        end

        # counter
        # is: actual super - object
        # js: subsequent super - object
        # i: Object3D of is_th super - object
        # j: Object3D of js_th super - object
        n = 0
        @inbounds for is = 1:length(superObjs)
            actSuperObj = superObjs[is].superObjCollision.superObj
            if !isempty(actSuperObj)
                actSuperAABB = AABB[is]
                for i = 1:length(actSuperObj)
                    actObj = actSuperObj[i]       # determine contact from this Object3D with all Object3Ds that have larger indices
                    actAABB = actSuperAABB[i]
                    for js = is+1:length(superObjs)
                        if !(js in noCPairs[is])    # PairID is not in objects which cant collide
                            nextSuperObj = superObjs[js].superObjCollision.superObj
                            nextSuperAABB = AABB[js]
                            for j = 1:length(nextSuperObj)
                                n += 1
                                nextObj  = nextSuperObj[j]
                                nextAABB = nextSuperAABB[j]
                                pairID::Int64 = computePairID(scene, actObj, nextObj, is,i,js,j)

                                storeDistancesForSolver!(world, pairID, ch, actObj, nextObj,
                                actAABB, nextAABB, phase2, hasEvent)
    end; end; end; end; end; end; end
    return nothing
end


function pushCollisionPair!(ch, contact, distanceWithHysteresis, pairID, contactPoint1,
    contactPoint2, contactNormal, actObj::Composition.Object3D{F}, nextObj::Composition.Object3D{F}, hasevent, supportPointsDefined, support1A, support2A,
    support3A, support1B, support2B, support3B)::Nothing where F <: Modia3D.VarFloatType
    if contact
        push!(ch.contactDict, pairID => Modia3D.ContactPair{F}(contactPoint1,contactPoint2,
            contactNormal, actObj, nextObj, distanceWithHysteresis, supportPointsDefined,
            support1A, support2A, support3A, support1B, support2B, support3B))
    else
        if ch.noContactMinVal > distanceWithHysteresis
            ch.noContactMinVal = distanceWithHysteresis
    end; end
    return nothing
end


function storeDistancesForSolver!(world::Composition.Object3D{F}, pairID::Composition.PairID,
    ch::Composition.ContactDetectionMPR_handler, actObj::Composition.Object3D{F}, nextObj::Composition.Object3D{F}, actAABB::Basics.BoundingBox{F}, nextAABB::Basics.BoundingBox{F}, phase2::Bool, hasEvent::Bool) where F <: Modia3D.VarFloatType

    # If object pairs are already in contact, always perform narrow phase!!
    hasContact = haskey(ch.contactDict, pairID)

    # Broad phase
    if hasContact || AABB_touching(actAABB, nextAABB) # AABB's are overlapping
        # narrow phase
        (distanceOrg, contactPoint1, contactPoint2, contactNormal, supportPointsDefined,
        support1A, support1B, support2A, support2B, support3A, support3B) =
            mpr(ch, actObj, nextObj)

    else # AABB's are not overlapping
        (distanceOrg, contactPoint1, contactPoint2, contactNormal, supportPointsDefined,
        support1A, support1B, support2A, support2B, support3A, support3B) =
            computeDistanceBetweenAABB(actAABB, nextAABB)
      #  println("AABB not overlapping")
    end

    distanceWithHysteresis = distanceOrg - ch.contact_eps
    contact                = hasEvent ? distanceWithHysteresis <= F(0) : hasContact

    if hasEvent
        # At event instant
        pushCollisionPair!(ch, contact, distanceWithHysteresis, pairID,
            contactPoint1, contactPoint2, contactNormal, actObj,nextObj, hasEvent,
            supportPointsDefined, support1A, support2A, support3A, support1B, support2B, support3B)

    elseif !phase2
        # Integrator requires zero crossing function
        if contact
            # Collision pair had contact since the last event
            Modia3D.updateContactPair!(ch.contactDict[pairID], contactPoint1, contactPoint2,
                contactNormal, actObj, nextObj, distanceWithHysteresis, supportPointsDefined,
                support1A, support2A, support3A, support1B, support2B, support3B)
        else
            # Collision pair did not have contact since the last event
            pushCollisionPair!(ch, contact, distanceWithHysteresis, pairID,
                contactPoint1, contactPoint2, contactNormal, actObj, nextObj, hasEvent,
                supportPointsDefined, support1A, support2A, support3A, support1B, support2B, support3B)
        end

    else
        # Other model evaluation (only getDistances!())
        if contact
            # Collision pair had contact since the last event
            Modia3D.updateContactPair!(ch.contactDict[pairID], contactPoint1, contactPoint2,
                contactNormal, actObj, nextObj, distanceWithHysteresis, supportPointsDefined,
                support1A, support2A, support3A, support1B, support2B, support3B)
        else
            if ch.noContactMinVal > distanceWithHysteresis
                ch.noContactMinVal = distanceWithHysteresis
    end; end; end
    return nothing
end


function computeDistanceBetweenAABB(actAABB::Basics.BoundingBox{F}, nextAABB::Basics.BoundingBox{F}) where F <: Modia3D.VarFloatType
    xd = computeDistanceOneAxisAABB(actAABB.x_min, actAABB.x_max, nextAABB.x_min, nextAABB.x_max)
    yd = computeDistanceOneAxisAABB(actAABB.y_min, actAABB.y_max, nextAABB.y_min, nextAABB.y_max)
    zd = computeDistanceOneAxisAABB(actAABB.z_min, actAABB.z_max, nextAABB.z_min, nextAABB.z_max)
    distance = sqrt(xd^2 + yd^2 + zd^2)
    return (distance, Modia3D.ZeroVector3D(F), Modia3D.ZeroVector3D(F), Modia3D.ZeroVector3D(F), false, Modia3D.ZeroVector3D(F), Modia3D.ZeroVector3D(F), Modia3D.ZeroVector3D(F), Modia3D.ZeroVector3D(F), Modia3D.ZeroVector3D(F), Modia3D.ZeroVector3D(F))
end


function computeDistanceOneAxisAABB(A_min::F, A_max::F, B_min::F, B_max::F) where F <: Modia3D.VarFloatType
    if A_max < B_min
        return B_min - A_max
    elseif A_min > B_max
        return A_min - B_max
    else
        return F(0.0)
end; end


function Composition.closeContactDetection!(ch::Composition.ContactDetectionMPR_handler{T,F}) where {T,F}
    empty!(ch.lastContactDict)
    empty!(ch.contactDict)
    ch.noContactMinVal =  F(42.0)
end


function updateVisualBoundingBox!(obj::Composition.Object3D{F}, aabb::Basics.BoundingBox{F}) where F <: Modia3D.VarFloatType
    box::Shapes.Box{F} = obj.shape
    box.lengthX = abs(aabb.x_max - aabb.x_min)
    box.lengthY = abs(aabb.y_max - aabb.y_min)
    box.lengthZ = abs(aabb.z_max - aabb.z_min)

    obj.r_abs = SVector{3,F}((aabb.x_max + aabb.x_min)/2,
                        (aabb.y_max + aabb.y_min)/2,
                        (aabb.z_max + aabb.z_min)/2)
end
