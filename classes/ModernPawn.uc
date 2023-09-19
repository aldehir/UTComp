class ModernPawn extends xPawn;

simulated function Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    UpdateBackgroundAnimation(DeltaTime);
}

// APawn::UpdateMovementAnimation() does not apply animation updates 1.0 after
// an actor leaves the player's screen. This is great for performance, but
// unfortunately it results in a loss of sound cues. This function performs
// the same logic on pawns after they leave the player's screen to preserve
// sound cues.
simulated function UpdateBackgroundAnimation(float DeltaTime)
{
    if (Level.NetMode == NM_DedicatedServer)
        return;

    // Don't perform background animations for ourselves
    if (PlayerController(Controller) != None)
        return;

    if (bPlayedDeath)
        return;

    // Don't do anything if seen recently, this is already handled by APawn::UpdateMovementAnimation()
    if (Level.TimeSeconds - LastRenderTime <= 1.0)
        return;

    BaseEyeHeight = class'xPawn'.default.BaseEyeHeight;

    if (bIsIdle && Physics != OldPhysics)
    {
        bWaitForAnim = false;
    }

    if (!bWaitForAnim)
    {
        if (Physics == PHYS_Falling || Physics == PHYS_Flying)
        {
            BaseEyeHeight = BaseEyeHeight * 0.7;
            UpdateInAirBackground();
        }
        else if (Physics == PHYS_Walking || Physics == PHYS_Ladder || Physics == PHYS_Spider)
        {
          UpdateOnGroundBackground();
        }
    }
    else if (!IsAnimating())
    {
      bWaitForAnim = false;
    }

    if (Physics != PHYS_Walking)
    {
        bIsIdle = false;
    }

    OldPhysics = Physics;
    OldVelocity = Velocity;
}

simulated function UpdateInAirBackground()
{
    local Name NewAnim;
    local bool bUp, bDodge;
    local float DodgeSpeedThresh;
    local int Dir;
    local float XYVelocitySquared;

    local Name ActiveAnim;
    local float AnimFrame, AnimRate;

    XYVelocitySquared = (Velocity.X * Velocity.X) + (Velocity.Y * Velocity.Y);

    bDodge = false;
    if (OldPhysics == PHYS_Walking)
    {
        DodgeSpeedThresh = ((GroundSpeed * DodgeSpeedFactor) + GroundSpeed) * 0.5;
        if (XYVelocitySquared > DodgeSpeedThresh*DodgeSpeedThresh)
        {
            bDodge = true;
        }
    }

    bUp = (Velocity.Z >= 0.0);

    if (XYVelocitySquared >= 20000.0)
    {
        Dir = Get4WayDirection();

        if (bDodge)
        {
            NewAnim = DodgeAnims[Dir];
            bWaitForAnim = true;
        }
        else if (bUp)
        {
            NewAnim = TakeoffAnims[Dir];
        }
        else {
            NewAnim = AirAnims[Dir];
        }
    }
    else
    {
        if (bUp)
        {
            NewAnim = TakeOffStillAnim;
        }
        else
        {
            NewAnim = AirStillAnim;
        }
    }

    GetAnimParams(0, ActiveAnim, AnimFrame, AnimRate);

    if (NewAnim != ActiveAnim)
    {
        if (PhysicsVolume.Gravity.Z > 0.8 * class'PhysicsVolume'.default.Gravity.Z)
        {
            PlayAnim(NewAnim, 0.5, 0.2);
        }
        else
        {
            PlayAnim(NewAnim, 1.0, 0.1);
        }
    }
}

simulated function UpdateOnGroundBackground()
{
    if (OldPhysics == PHYS_Falling || OldPhysics == PHYS_Flying)
    {
        PlayLandBackground();
    }
    else if (Velocity dot Velocity < 2500.00)
    {
        if (!bIsIdle || FootTurning || bIsCrouched != bWasCrouched)
        {
            IdleTime = Level.TimeSeconds;
            PlayIdleBackground();
        }

        bWasCrouched = bIsCrouched;
        bIsIdle = true;
    }
    else
    {
        if (bIsIdle)
            bWaitForAnim = false;

        PlayRunningBackground();
        bIsIdle = false;
    }
}

simulated function PlayLandBackground()
{
    if (!bIsCrouched)
    {
        PlayAnim(LandAnims[Get4WayDirection()], 1.0, 0.1);
        bWaitForAnim = true;
    }
}

simulated function PlayIdleBackground()
{
    LoopAnim(IdleRestAnim, 1.0, 0.25);
}

simulated function PlayRunningBackground()
{
    local Name NewAnim;
    local int NewAnimDir;
    local float AnimSpeed;

    NewAnimDir = Get4WayDirection();

    AnimSpeed = 1.1f * class'xPawn'.default.GroundSpeed;
    if (bIsCrouched)
    {
        NewAnim = CrouchAnims[NewAnimDir];
        AnimSpeed = AnimSpeed * CrouchedPct;
    }
    else if (bIsWalking)
    {
        NewAnim = WalkAnims[NewAnimDir];
        AnimSpeed = AnimSpeed * WalkingPct;
    }
    else
    {
        NewAnim = MovementAnims[NewAnimDir];
    }

    LoopAnim(NewAnim, VSize(Velocity) / AnimSpeed, 0.1);
}
