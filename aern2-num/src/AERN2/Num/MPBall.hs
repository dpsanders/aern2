{-# LANGUAGE Arrows #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE UndecidableInstances, ConstraintKinds #-}
{-|

Safe multi-precision ball arithmetic.

Example of using precision policy:

getPrecision $ runWithPrecisionPolicy (addA <<< arr (\x -> (1,x :: MPBall)) <<< convertA) (PrecisionPolicy (prec 2) PrecisionPolicyMode_KeepExactDyadic) (1/(2^100))

Precision 128

getPrecision $ runWithPrecisionPolicy (addA <<< arr (\x -> (1,x :: MPBall)) <<< convertA) (PrecisionPolicy (prec 2) PrecisionPolicyMode_UseMax) (1/(2^100))

Precision 2

-}
module AERN2.Num.MPBall
    (MPBall(..), getAccuracy, getFiniteAccuracy,
     HasMPBallsA, HasMPBalls,
     CanBeMPBallA, mpBallA, mpBallNamedA, mpBallsA, mpBallsNamedA, CanBeMPBall, mpBall, mpBalls,
     getPrecision, setPrecisionMatchAccuracy, 
     MP.maximumPrecision, MP.defaultPrecision, MP.standardPrecisions, MP.Precision, MP.prec, MP.prec2integer,
     PrecisionPolicyMode(..), PrecisionPolicy(..), defaultPrecisionPolicy, maxPrecisionPolicy, 
     ppUseCurr, ppUseMax, ppKeepExact, 
     ArrowPrecisionPolicy(..), WithPrecisionPolicy(..),
     iterateUntilAccurateA, iterateUntilOKA,
     iterateUntilAccurate, iterateUntilOK,
     isNonZero,
     toIntegerUp, toIntegerDown, toRationalUp, toRationalDown,
--     integer2Ball, 
     integer2BallP,
     rational2BallP, rationalBall2BallP,
     ball2endpoints, endpoints2Ball,
     getCentreAndErrorBall,
     piBallP) 
where

import qualified Prelude as P
import AERN2.Num.Operations
import AERN2.Num.Norm

--import Control.Exception
--import System.IO.Unsafe
import Control.Category
import Control.Arrow
import Math.NumberTheory.Logarithms (integerLog2)

import AERN2.Num.IntegerRational ()
import qualified AERN2.Num.Accuracy as A
import qualified AERN2.Num.ErrorBound as EB
import AERN2.Num.ErrorBound (ErrorBound(..))
import qualified AERN2.Num.MPFloat as MP
import AERN2.Num.MPFloat 
    (MPFloat, Precision,
     PrecisionPolicyMode(..), PrecisionPolicy(..), defaultPrecisionPolicy, maxPrecisionPolicy, 
     ppUseCurr, ppUseMax, ppKeepExact, 
     ArrowPrecisionPolicy(..), WithPrecisionPolicy(..), arrPP)

import Debug.Trace (trace)

shouldTrace :: Bool
shouldTrace = False
--shouldTrace = True

maybeTrace :: String -> a -> a
maybeTrace 
    | shouldTrace = trace
    | otherwise = const id


data MPBall = MPBall { ball_value :: MPFloat, ball_error :: ErrorBound }

instance (ArrowPrecisionPolicy to) => RingA to MPBall
instance (ArrowPrecisionPolicy to) => FieldA to MPBall
instance (ArrowPrecisionPolicy to) => CanAddMulScalarA to MPBall MPBall
instance (ArrowPrecisionPolicy to) => CanAddMulDivScalarA to MPBall MPBall
instance (ArrowPrecisionPolicy to) => CanAddMulScalarA to MPBall Integer
instance (ArrowPrecisionPolicy to) => CanAddMulDivScalarA to MPBall Integer
instance (ArrowPrecisionPolicy to) => CanAddMulScalarA to MPBall Rational
instance (ArrowPrecisionPolicy to) => CanAddMulDivScalarA to MPBall Rational

instance Show MPBall
    where
    show (MPBall x e) = "[" ++ show x ++ " ± " ++ show e ++ "]"

rationalBall2BallP :: MP.Precision -> (Rational, Rational) -> MPBall 
rationalBall2BallP p (x,e) =
    MPBall xUp (xe + eUp)
    where
    (MPBall xUp xe) = rational2BallP p x
    eUp = EB.rational2ErrorBound e
    
rational2BallP :: MP.Precision -> Rational -> MPBall
rational2BallP p x =
    MPBall xUp (xUp `EB.subMP` xDn)
    where
    xUp = MP.fromRationalUp p x
    xDn = MP.fromRationalDown p x

integer2BallP :: MP.Precision -> Integer -> MPBall
integer2BallP p x =
    MPBall xUp (xUp `EB.subMP` xDn)
    where
    xUp = MP.fromIntegerUp p x
    xDn = MP.fromIntegerDown p x

type HasMPBallsA to = ConvertibleA to MPBall
type HasMPBalls = HasMPBallsA (->)


type CanBeMPBallA to a = ConvertibleA to a MPBall
mpBallA :: (CanBeMPBallA to a) => a `to` MPBall
mpBallA = convertA
mpBallNamedA :: (CanBeMPBallA to a) => String -> a `to` MPBall
mpBallNamedA = convertNamedA
mpBallsA :: (CanBeMPBallA to a) => [a] `to` [MPBall]
mpBallsA = convertListA
mpBallsNamedA :: (CanBeMPBallA to a) => String -> [a] `to` [MPBall]
mpBallsNamedA = convertListNamedA
type CanBeMPBall a = CanBeMPBallA (->) a
mpBall :: (CanBeMPBall a) => a -> MPBall
mpBall = convert
mpBalls :: (CanBeMPBall a) => [a] -> [MPBall]
mpBalls = convertList

instance (ArrowChoice to) => ConvertibleA to MPBall MPBall where
    convertA = arr id

-- | HasIntegers MPBall, CanBeMPBall Integer
instance (ArrowPrecisionPolicy to) => ConvertibleA to Integer MPBall where
    convertA =
        proc x ->
            do
            pp <- getPrecisionPolicy -< ()
            returnA -< convertByPP pp x
        where
        convertByPP pp x =
            case precPolicy_mode pp of
                PrecisionPolicyMode_UseCurrent -> xP 
                PrecisionPolicyMode_UseMax ->
                    if getPrecision xExact < p then xP else xExact
                PrecisionPolicyMode_KeepExactDyadic -> xExact 
            where
            xExact = MPBall (convert x) EB.zero
            xP = integer2BallP p x
            p = precPolicy_precision pp
            
        
-- | HasRationalsA MPBall, CanBeMPBall Rational
instance (ArrowPrecisionPolicy to) => ConvertibleA to Rational MPBall where
    convertA =
        proc x ->
            do
            pp <- getPrecisionPolicy -< ()
            returnA -< convertByPP pp x
        where
        convertByPP pp x = xP
            where
            xP = rational2BallP p x
            p = precPolicy_precision pp
        
--integer2Ball :: Integer -> MPBall
--integer2Ball = convert

toIntegerUp :: MPBall -> Integer
toIntegerUp x = ceiling $ toRationalUp x
toIntegerDown :: MPBall -> Integer
toIntegerDown x = floor $ toRationalDown x

toRationalUp :: MPBall -> Rational
toRationalUp x = MP.toRational $ snd $ ball2endpointsMP x
toRationalDown :: MPBall -> Rational
toRationalDown x = MP.toRational $ fst $ ball2endpointsMP x

getAccuracy :: 
    MPBall -> A.Accuracy
getAccuracy (MPBall _ e) =
    maybeTrace
    (
        "MPBall.getAccuracy: e = " ++ show e ++ "; ac = " ++ show ac
    )
    ac
    where 
    ac = EB.getAccuracy e

getFiniteAccuracy :: MPBall -> A.Accuracy
getFiniteAccuracy b =
    case getAccuracy b of
        A.Exact -> A.bits $ MP.prec2integer (getPrecision b)
        a -> a

getPrecision :: MPBall -> Precision
getPrecision (MPBall x _) =
    MP.getPrecision x

setPrecisionMatchAccuracy :: A.Accuracy -> MPBall -> MPBall
setPrecisionMatchAccuracy acc b@(MPBall x e) 
    | p < p' = (MPBall x' e)
    | otherwise = b
    where
    p' = MP.prec $ max 2 (A.fromAccuracy acc) 
    p = MP.getPrecision x
    x' = MP.setPrecisionUp p' x

iterateUntilAccurateA :: 
    (ArrowChoice to) => 
    A.Accuracy -> 
    (Precision `to` Maybe MPBall) -> 
    () `to` [(Precision, Maybe MPBall)]
iterateUntilAccurateA ac = 
    iterateUntilOKA $ \maybeResult -> 
        case maybeResult of 
            Just result -> getAccuracy result >= ac
            _ -> False 

iterateUntilAccurate :: 
    A.Accuracy -> 
    (Precision -> Maybe MPBall) -> 
    [(Precision, Maybe MPBall)]
iterateUntilAccurate ac fn = iterateUntilAccurateA ac fn () 

iterateUntilOKA :: 
    (ArrowChoice to) => 
    (a -> Bool) -> 
    (Precision `to` a) -> 
    () `to` [(Precision, a)]
iterateUntilOKA isOK fnA =
    stopWhenAccurate ps
    where
--    fnWrap p =
--        unsafePerformIO $ 
--            catch (return $! Just $! fn p) 
--                (\e -> let _ = e :: SomeException in return Nothing)
    ps = MP.standardPrecisions
    stopWhenAccurate [] = arr $ const []
    stopWhenAccurate (p : rest) =
        proc () ->
            do
            result <- fnA -< p
            if isOK result 
                then returnA -< [(p, result)]
                else
                    do
                    restResults <- stopWhenAccurate rest -< ()
                    returnA -<  (p, result) : restResults

iterateUntilOK :: 
    (a -> Bool) -> 
    (Precision -> a) -> 
    [(Precision, a)]
iterateUntilOK isOK fn = iterateUntilOKA isOK fn ()


isNonZero :: MPBall -> Bool
isNonZero (MPBall x e) =
    (MP.abs x) -. (EB.er2mp e) > MP.zero
    where
    (-.) = MP.subDown defaultPrecisionPolicy


instance HasNorm MPBall where
    getNormLog ball
        | not (isNonZero ballR) = NormZero
        | integerBound > 1 = 
            NormBits $ toInteger $ integerLog2 $ integerBound
        | integerRecipBound >= 1 = 
            NormBits  $ 1 + (neg $ toInteger $ integerLog2 $ integerRecipBound)
        | otherwise = error "internal error in getNormLog"
        where
        ballR =
            endpointsMP2Ball r r
            where
            r = snd $ ball2endpointsMP $ abs ball
        integerBound = toIntegerUp ballR
        integerRecipBound 
            | isNonZero ballR = toIntegerUp (1 / ballR)
            | otherwise = -1

instance (ArrowChoice to) => HasEqA to MPBall MPBall where
    type EqCompareTypeA to MPBall MPBall = Maybe Bool
    equalToA = arr $ \ (b1, b2) ->
        case (getAccuracy b1, getAccuracy b2, b1 < b2, b2 < b1) of
            (A.Exact, A.Exact, Just False, Just False) -> Just True
            (_, _, Just True, _) -> Just False
            (_, _, _, Just True) -> Just False
            _ -> Nothing
    notEqualToA = arr $ \ (b1, b2) -> fmap not $ equalTo b1 b2
        
instance (ArrowPrecisionPolicy to) => HasOrderA to MPBall MPBall where
    type OrderCompareTypeA to MPBall MPBall = Maybe Bool
    lessThanA = arrPP aux
        where
        aux pp (MPBall x1 e1, MPBall x2 e2) 
            | (x1 +^ e1MP) < (x2 -. e2MP) = Just True
            | (x1 -. e1MP) >= (x2 +^ e2MP) = Just False
            | otherwise = Nothing
            where
            e1MP = EB.er2mp e1
            e2MP = EB.er2mp e2
            (+^) = MP.addUp pp
            (-.) = MP.subDown pp
    leqA = arrPP aux
        where
        aux pp (MPBall x1 e1, MPBall x2 e2) 
            | (x1 +^ e1MP) <= (x2 -. e2MP) = Just True
            | (x1 -. e1MP) > (x2 +^ e2MP) = Just False
            | otherwise = Nothing
            where
            e1MP = EB.er2mp e1
            e2MP = EB.er2mp e2
            (+^) = MP.addUp pp
            (-.) = MP.subDown pp

instance (ArrowPrecisionPolicy to) => HasEqA to MPBall Integer where
    type EqCompareTypeA to MPBall Integer = Maybe Bool
    equalToA = convertSecondUsingA integer2BallP equalToA
    notEqualToA = convertSecondUsingA integer2BallP notEqualToA

instance (ArrowPrecisionPolicy to) => HasEqA to Integer MPBall where
    type EqCompareTypeA to Integer MPBall = Maybe Bool
    equalToA = convertFirstUsingA integer2BallP equalToA
    notEqualToA = convertFirstUsingA integer2BallP notEqualToA

instance (ArrowPrecisionPolicy to) => HasOrderA to MPBall Integer where
    type OrderCompareTypeA to MPBall Integer = Maybe Bool
    lessThanA = convertSecondUsingA integer2BallP lessThanA 
    leqA = convertSecondUsingA integer2BallP leqA 

instance (ArrowPrecisionPolicy to) => HasOrderA to Integer MPBall where
    type OrderCompareTypeA to Integer MPBall = Maybe Bool
    lessThanA = convertFirstUsingA integer2BallP lessThanA
    leqA = convertFirstUsingA integer2BallP leqA

instance (ArrowPrecisionPolicy to) => HasEqA to MPBall Rational where
    type EqCompareTypeA to MPBall Rational = Maybe Bool
    equalToA = convertSecondUsingA rational2BallP equalToA
    notEqualToA = convertSecondUsingA rational2BallP notEqualToA

instance (ArrowPrecisionPolicy to) => HasEqA to Rational MPBall where
    type EqCompareTypeA to Rational MPBall = Maybe Bool
    equalToA = convertFirstUsingA rational2BallP equalToA
    notEqualToA = convertFirstUsingA rational2BallP notEqualToA

instance (ArrowPrecisionPolicy to) => HasOrderA to MPBall Rational where
    type OrderCompareTypeA to MPBall Rational = Maybe Bool
    lessThanA = convertSecondUsingA rational2BallP lessThanA 
    leqA = convertSecondUsingA rational2BallP leqA 

instance (ArrowPrecisionPolicy to) => HasOrderA to Rational MPBall where
    type OrderCompareTypeA to Rational MPBall = Maybe Bool
    lessThanA = convertFirstUsingA rational2BallP lessThanA
    leqA = convertFirstUsingA rational2BallP leqA


instance (Arrow to) => CanNegA to MPBall where
    negA = arr aux
        where aux (MPBall x1 e1) = MPBall (MP.neg x1) e1

instance (Arrow to) => CanNegSameTypeA to MPBall

instance (Arrow to) => CanAbsA to MPBall where
    absA = arr $ \(MPBall x1 e1) -> MPBall (MP.abs x1) e1

instance CanAbsSameType MPBall

instance (ArrowPrecisionPolicy to) => CanRecipA to MPBall where
    recipA = proc b -> divA -< (1, b)

instance (ArrowPrecisionPolicy to) => CanRecipSameTypeA to MPBall

instance (ArrowPrecisionPolicy to) => CanAddA to MPBall MPBall where
    type AddTypeA to MPBall MPBall = MPBall
    addA  =
        arrPP fn 
        where
        fn pp (MPBall x1 e1, MPBall x2 e2) = 
            MPBall sumUp ((sumUp `EB.subMP` sumDn) + e1 + e2)
            where
            sumUp = MP.addUp pp x1 x2
            sumDn = MP.addDown pp x1 x2

instance (ArrowPrecisionPolicy to) => CanAddThisA to MPBall MPBall

instance (ArrowPrecisionPolicy to) => CanAddSameTypeA to MPBall

instance (ArrowPrecisionPolicy to) => CanSubA to MPBall MPBall  
        
instance (ArrowPrecisionPolicy to) => CanSubThisA to MPBall MPBall

instance (ArrowPrecisionPolicy to) => CanSubSameTypeA to MPBall

instance (ArrowPrecisionPolicy to) => CanMulA to MPBall MPBall where
    mulA = arrPP fn
        where
        fn pp (MPBall x1 e1, MPBall x2 e2) =
            MPBall x12Up (e12 + e1*(EB.absMP x2) + e2*(EB.absMP x1) + e1*e2)
            where
            x12Up = MP.mulUp pp x1 x2 
            x12Down = MP.mulDown pp x1 x2
            e12 = EB.mp2ErrorBound $ x12Up -^ x12Down
            (-^) = MP.subUp pp

instance (ArrowPrecisionPolicy to) => CanMulByA to MPBall MPBall

instance (ArrowPrecisionPolicy to) => CanMulSameTypeA to MPBall

instance (ArrowPrecisionPolicy to) => CanPowA to MPBall Integer
instance (ArrowPrecisionPolicy to) => CanPowByA to MPBall Integer


instance (ArrowPrecisionPolicy to) => CanDivA to MPBall MPBall where
    divA = arrPP fn
        where
        fn pp (MPBall x1 e1, b2@(MPBall x2 e2))
            | isNonZero b2 =
                MPBall x12Up err
            | otherwise =
                error $ "Division by MPBall that contains 0: " ++ show b2
            where
            x12Up = MP.divUp pp x1 x2 
            x12Down = MP.divDown pp x1 x2
            e12 = EB.mp2ErrorBound $ x12Up -^ x12Down
            err =
                ((e12 * (EB.mp2ErrorBound (MP.abs x2))) -- e12 * |x2|
                 +
                 e1
                 +
                 (EB.mp2ErrorBound (MP.abs x12Up) * e2) -- e2 * |x|
                ) 
                * 
                (EB.mp2ErrorBound $ MP.recipUp pp (MP.abs x2 -. (EB.er2mp e2))) 
                    -- 1/(|x2| - e2) rounded upwards 
            (-^) = MP.subUp pp
            (-.) = MP.subDown pp
{-
A derivation of the above formula for an upper bound on the error:

    * e = 
        * = max ( (x1 ± e1) / (x2 ± e2) - x )
        * = max ( ( x1 ± e1 - (x*(x2 ± e2) ) / (x2 ± e2) )
        * ≤ max ( ( x1 ± e1 - ((x1/x2) ± e12)x2 ± x*e2 ) / (x2 ± e2) )
        * = max ( ( x1 ± e1 - x1 ± e12*x2 ± x*e2 ) / (x2 ± e2) )
        * = max ( ( ± e1 ± e12*x2 ± x*e2 ) / (x2 ± e2) )
        * ≤ (e1 + e12*|x2| + |x|*e2 ) / (|x2| - e2)
        * ≤ (e1 +^ e12*^|x2| +^ |x|*^e2 ) /^ (|x2| -. e2)
-}                


instance (ArrowPrecisionPolicy to) => CanDivByA to MPBall MPBall

instance (ArrowPrecisionPolicy to) => CanDivSameTypeA to MPBall

piBallP :: Precision -> MPBall
piBallP p = MPBall piUp (piUp `EB.subMP` piDown)
    where
    piUp = MP.piUp p 
    piDown = MP.piDown p 

{- Ball-Integer operations -}

instance (ArrowPrecisionPolicy to) => CanAddA to Integer MPBall where
    type AddTypeA to Integer MPBall = MPBall
    addA = convertFirstUsingA integer2BallP addA 

instance (ArrowPrecisionPolicy to) => CanAddA to MPBall Integer where
    type AddTypeA to MPBall Integer = MPBall
    addA = convertSecondUsingA integer2BallP addA 

instance (ArrowPrecisionPolicy to) => CanAddThisA to MPBall Integer

instance (ArrowPrecisionPolicy to) => CanSubA to MPBall Integer

instance (ArrowPrecisionPolicy to) => CanSubThisA to MPBall Integer

instance (ArrowPrecisionPolicy to) => CanSubA to Integer MPBall

instance (ArrowPrecisionPolicy to) => CanMulA to Integer MPBall where
    type MulTypeA to Integer MPBall = MPBall
    mulA = convertFirstUsingA integer2BallP mulA

instance (ArrowPrecisionPolicy to) => CanMulA to MPBall Integer where
    type MulTypeA to MPBall Integer = MPBall
    mulA = convertSecondUsingA integer2BallP mulA

instance (ArrowPrecisionPolicy to) => CanMulByA to MPBall Integer

instance (ArrowPrecisionPolicy to) => CanDivA to Integer MPBall where
    type DivTypeA to Integer MPBall = MPBall
    divA = convertFirstUsingA integer2BallP divA

instance (ArrowPrecisionPolicy to) => CanDivA to MPBall Integer where
    type DivTypeA to MPBall Integer = MPBall
    divA = convertSecondUsingA integer2BallP divA

instance (ArrowPrecisionPolicy to) => CanDivByA to MPBall Integer

{- Ball-Rational operations -}

instance (ArrowPrecisionPolicy to) => CanAddA to Rational MPBall where
    type AddTypeA to Rational MPBall = MPBall
    addA = convertFirstUsingA rational2BallP addA

instance (ArrowPrecisionPolicy to) => CanSubA to Rational MPBall

instance (ArrowPrecisionPolicy to) => CanAddA to MPBall Rational where
    type AddTypeA to MPBall Rational = MPBall
    addA = convertSecondUsingA rational2BallP addA

instance (ArrowPrecisionPolicy to) => CanAddThisA to MPBall Rational

instance (ArrowPrecisionPolicy to) => CanSubA to MPBall Rational

instance (ArrowPrecisionPolicy to) => CanSubThisA to MPBall Rational

instance (ArrowPrecisionPolicy to) => CanMulA to Rational MPBall where
    type MulTypeA to Rational MPBall = MPBall
    mulA = convertFirstUsingA rational2BallP mulA

instance (ArrowPrecisionPolicy to) => CanMulA to MPBall Rational where
    type MulTypeA to MPBall Rational = MPBall
    mulA = convertSecondUsingA rational2BallP mulA

instance (ArrowPrecisionPolicy to) => CanMulByA to MPBall Rational

instance (ArrowPrecisionPolicy to) => CanDivA to Rational MPBall where
    type DivTypeA to Rational MPBall = MPBall
    divA = convertFirstUsingA rational2BallP divA

instance (ArrowPrecisionPolicy to) => CanDivA to MPBall Rational where
    type DivTypeA to MPBall Rational = MPBall
    divA = convertSecondUsingA rational2BallP divA

instance (ArrowPrecisionPolicy to) => CanDivByA to MPBall Rational

convertFirstUsingA ::
    (Arrow to) =>
    (Precision -> a -> MPBall) -> ((MPBall,MPBall) `to` b) -> ((a,MPBall) `to` b) 
convertFirstUsingA convertP opA =
    proc (xI,y) ->
        do
        opA -< (convertP (getPrecision y) xI,y)

convertSecondUsingA ::
    (Arrow to) =>
    (Precision -> a -> MPBall) -> ((MPBall,MPBall) `to` b) -> ((MPBall,a) `to` b) 
convertSecondUsingA convertP opA =
    proc (x,yI) ->
        do
        opA -< (x, convertP (getPrecision x) yI)


{- generic methods for computing real functions from MPFR-approximations -}

{-|
    Computes a real function @f@ from correctly rounded MPFR-approximations and a number @lip@ which is a
    Lipschitz constant for @f@, i.e. @|f(x) - f(y)| <= lip * |x - y|@ for all @x@,@y@.
-}
fromApproxWithLipschitz :: 
    (MPFloat -> MPFloat) {-^ @fDown@: a version of @f@ on MPFloat rounding *downwards* -} -> 
    (MPFloat -> MPFloat) {-^ @fUp@: a version of @f@ on MPFloat rounding *upwards* -} ->
    MPFloat {-^ @lip@ a Lipschitz constant for @f@, @lip > 0@ -} -> 
    (MPBall -> MPBall) {-^ @f@ on MPBall rounding *outwards* -}
fromApproxWithLipschitz fDown fUp lip _x@(MPBall xc xe) = 
    MPBall fxc err
    where
    fxl = fDown xc
    fxu = fUp xc
    (MPBall fxc fxe) = endpointsMP2Ball fxl fxu 
    err = (EB.mp2ErrorBound lip) * xe  +  fxe

{-|
    Computes a *monotone* real function @f@ from correctly rounded MPFR-approximations.
-}
monotoneFromApprox :: 
    (MPFloat -> MPFloat) {-^ @fDown@: a version of @f@ on MPFloat rounding *downwards* -} -> 
    (MPFloat -> MPFloat) {-^ @fUp@: a version of @f@ on MPFloat rounding *upwards* -} -> 
    (MPBall -> MPBall) {-^ @f@ on MPBall rounding *outwards* -}
monotoneFromApprox fDown fUp x = 
    endpointsMP2Ball (fDown l) (fUp u)
    where
    (l,u) = ball2endpointsMP x

endpointsMP2Ball :: MPFloat -> MPFloat -> MPBall
endpointsMP2Ball l u =
    MPBall c e
    where
    c = MP.avgUp pp l u
    e = EB.mp2ErrorBound $ P.max (MP.distUp pp c l) (MP.distUp pp c u)
    pp = defaultPrecisionPolicy

ball2endpointsMP :: MPBall -> (MPFloat, MPFloat)
ball2endpointsMP x = (l,u)
    where
    c    = ball_value x
    r    = er2mp (ball_error x)
    l   = c -. r
    u   = c +^ r
    (-.) = MP.subDown defaultPrecisionPolicy
    (+^) = MP.addUp defaultPrecisionPolicy

endpoints2Ball :: MPBall -> MPBall -> MPBall
endpoints2Ball l u =
    endpointsMP2Ball lMP uMP
    where
    (lMP, _) = ball2endpointsMP l
    (_, uMP) = ball2endpointsMP u

ball2endpoints :: MPBall -> (MPBall, MPBall)
ball2endpoints x = (l,u)
    where
    l = MPBall lMP EB.zero
    u = MPBall uMP EB.zero
    (lMP, uMP) = ball2endpointsMP x
    
getCentreAndErrorBall :: MPBall -> (MPBall, MPBall)
getCentreAndErrorBall x = (cB,eB)
    where
    (MPBall cMP eEB) = x
    cB = MPBall cMP EB.zero
    eB = MPBall MP.zero eEB

{- common functions -}

instance (Arrow to) => CanSqrtA to MPBall where
    sqrtA = arr $ monotoneFromApprox MP.sqrtDown MP.sqrtUp     
        
instance (Arrow to) => CanSqrtSameTypeA to MPBall
        
instance (Arrow to) => CanExpA to MPBall where
    expA = arr $ monotoneFromApprox MP.expDown MP.expUp     

instance (Arrow to) => CanExpSameTypeA to MPBall
        
instance (Arrow to) => CanSineCosineA to MPBall where
    sinA = arr $ sinB 1
    cosA = arr $ cosB 1

instance (Arrow to) => CanSineCosineSameTypeA to MPBall


sinB :: Integer -> MPBall -> MPBall
sinB i x = 
    fromApproxWithLipschitz MP.sinDown MP.sinUp lip x
    where
    lip
        | i == 0 = MP.one
        | otherwise = snd $ ball2endpointsMP $ abs $ cosB (i - 1) x

cosB :: Integer -> MPBall -> MPBall
cosB i x = 
    fromApproxWithLipschitz MP.cosDown MP.cosUp lip x
    where
    lip
        | i == 0 = MP.one
        | otherwise = snd $ ball2endpointsMP $ abs $ sinB (i - 1) x

{- Instances of Prelude numerical classes provided for convenient use outside AERN2 
   and also because Template Haskell translates (-x) to (Prelude.negate x) -}  
instance Num MPBall where
    fromInteger = convert
    negate = negate
    (+) = (+)
    (*) = (*)
    abs = abs
    signum = error "Prelude.signum not implemented for MPBall"

instance Eq MPBall where
    a == b = (a == b) == Just True
    a /= b = (a /= b) == Just True

instance Ord MPBall where
    a < b =  (a < b) == Just True
    a <= b =  (a <= b) == Just True
    a > b =  (a > b) == Just True
    a >= b =  (a >= b) == Just True
    compare r1 r2 
        | (r1 < r2) == Just True = LT
        | (r1 > r2) == Just True = GT
        | (r1 == r2) == Just True = EQ
        | otherwise = error "AERN2.Num.MPBall: compare: cannot decide"
        
instance Fractional MPBall where
    fromRational = convert -- will work only for dyadic rationals
    recip = recip
    (/) = (/)

instance Floating MPBall where
    pi = error "MPBall: pi not implemented" -- no global precision to pick
    sqrt = sqrt
    exp = exp
    sin = sin
    cos = cos
    log = error "MPBall: log not implemented yet"
    atan = error "MPBall: atan not implemented yet"
    atanh = error "MPBall: atanh not implemented yet"
    asin = error "MPBall: asin not implemented yet"
    acos = error "MPBall: acos not implemented yet"
    sinh = error "MPBall: sinh not implemented yet"
    cosh = error "MPBall: cosh not implemented yet"
    asinh = error "MPBall: asinh not implemented yet"
    acosh = error "MPBall: acosh not implemented yet"
    
