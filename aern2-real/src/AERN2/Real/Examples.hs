{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE DataKinds #-}

module AERN2.Real.Examples 
    (module AERN2.Real.Examples,
     module AERN2.Real.Operations,
     module AERN2.Real.MPFloat,
     module AERN2.Real.MPBall,
     module AERN2.Real.CauchyReal,
     module Prelude)
where

import Prelude hiding
    ((==),(/=),(<),(>),(<=),(>=),
     (+),(*),(/),(-),(^),abs,min,max,
     recip,div,negate,
     fromInteger,fromRational,toRational,
     pi,sqrt,cos,sin)

import AERN2.Real.Operations
import AERN2.Real.IntegerRational ()
import AERN2.Real.MPBall
import AERN2.Real.MPFloat hiding (abs, neg, getPrecision, integer)
import AERN2.Real.CauchyReal
import AERN2.Real.Accuracy as A

ball1 :: MPBall
ball1 = rationalBallP (prec 1000) (2.0,1/300) 

ball2 :: MPBall
ball2 = integer (5^100)

balladd :: MPBall
balladd = ball1 + ball1

ballmul :: MPBall
ballmul = ball1 * ball1

ball1Accuracy :: Accuracy
ball1Accuracy = getAccuracy ball1

ballComp1 :: Maybe Bool
ballComp1 = ball1 < ballmul

ballComp2 :: Maybe Bool
ballComp2 = ball1 == ball1

cauchyThird :: CauchyReal
cauchyThird = rational2CauchyReal (1/3) 

cauchyThirdWithAccuracy :: Accuracy -> MPBall
cauchyThirdWithAccuracy = cauchyReal2ball cauchyThird

cauchyArithmetic :: CauchyReal
cauchyArithmetic = 1 + pi + cos(pi/3)

ballPlusCauchy :: MPBall
ballPlusCauchy = ball1 + cauchyArithmetic
