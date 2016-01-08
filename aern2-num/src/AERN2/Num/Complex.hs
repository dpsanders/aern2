{-# LANGUAGE Arrows, TypeSynonymInstances, FlexibleInstances, TypeOperators, ConstraintKinds, FlexibleContexts, UndecidableInstances, TemplateHaskell #-}
module AERN2.Num.Complex 
(
    Complex(..), complex_iA, complex_i,
    complexCR2balls,
    showComplexCR,
    HasComplexA, HasComplex,
    CanBeComplexA, complexA, complexNamedA, complexListA, complexListNamedA, 
    CanBeComplex, complex, complexList
)
where

import AERN2.Num.Operations
import AERN2.Num.CauchyReal
import AERN2.Num.MPBall
import AERN2.Num.Accuracy
import AERN2.Num.SymbolicArrow
import AERN2.Num.SymbolicArrow.Expression (var)

import Control.Arrow

data Complex r = r :+ r
    deriving Show 

infixr 5 :+

complex_i :: (HasIntegers r) => Complex r
complex_i = complex_iA ()

complex_iA :: (HasIntegersA to r) => () `to` Complex r
complex_iA =
    proc () ->
        do
        zero <- convertA -< 0
        one <- convertA -< 1
        returnA -< zero :+ one 

complexCR2balls :: (Complex CauchyReal) -> Accuracy -> (MPBall, MPBall)
complexCR2balls (r :+ i) a = 
    (cauchyReal2ball r a, cauchyReal2ball i a)

showComplexCR :: Accuracy -> (Complex CauchyReal) -> String
showComplexCR a (r :+ i) = 
    "(" ++ show (cauchyReal2ball r a) ++ ":+" ++ show (cauchyReal2ball i a) ++ ")"

instance
    (ConvertibleA to r1 r2)
    => 
    ConvertibleA to (Complex r1) (Complex r2) 
    where
    convertA =
        proc (r :+ i) ->
            do
            r' <- convertA -< r  
            i' <- convertA -< i
            returnA -< (r' :+ i')

type HasComplexA r to = ConvertibleA to (Complex r)
type HasComplex r = HasComplexA r (->)

type CanBeComplexA r to a = ConvertibleA to a (Complex r)
complexA :: (CanBeComplexA r to a) => a `to` (Complex r)
complexA = convertA
complexNamedA :: (CanBeComplexA r to a) => String -> a `to` (Complex r)
complexNamedA = convertNamedA
complexListA :: (CanBeComplexA r to a) => [a] `to` [(Complex r)]
complexListA = convertListA
complexListNamedA :: (CanBeComplexA r to a) => String -> [a] `to` [(Complex r)]
complexListNamedA = convertListNamedA
type CanBeComplex r a = CanBeComplexA r (->) a
complex :: (CanBeComplex r a) => a -> (Complex r)
complex = convert
complexList :: (CanBeComplex r a) => [a] -> [(Complex r)]
complexList = convertList

-- | HasIntegers (Complex r), CanBeComplex Integer
instance (HasIntegersA to r) => ConvertibleA to Integer (Complex r) where
    convertA = toComplexA

-- | HasRationals (Complex r), CanBeComplex Rational
instance (HasRationalsA to r, HasIntegersA to r) => ConvertibleA to Rational (Complex r) where
    convertA = toComplexA

-- | HasCauchyReals (Complex r), CanBeComplex CauchyReal
instance (HasCauchyRealsA to r, HasIntegersA to r) => ConvertibleA to CauchyReal (Complex r) where
    convertA = toComplexA

-- | HasMPBall (Complex r), CanBeComplex r MPBall
instance (HasMPBallsA to r, HasIntegersA to r) => ConvertibleA to MPBall (Complex r) where
    convertA = toComplexA

toComplexA ::
    (ConvertibleA to a r, HasIntegersA to r)
    =>
    a `to` Complex r
toComplexA =
    proc x ->
        do
        x' <- convertA -< x  
        z <- convertA -< 0
        returnA -< (x' :+ z)

{- Comparison of complex numbers -}

instance (RealPredA to r) => HasEqA to (Complex r) (Complex r) where
    type EqCompareTypeA to (Complex r) (Complex r) = EqCompareTypeA to r r 
    equalToA =
        binaryRel $(predAinternal [| let [r1,i1,r2,i2] = vars in r1 == r2 && i1 == i2|])
        
instance
    (RealPredA to r) =>
    HasOrderA to (Complex r) (Complex r) 
    where
    type OrderCompareTypeA to (Complex r) (Complex r) = OrderCompareTypeA to r r 
    lessThanA =
        binaryRel $(predAinternal [|let [r1,i1,r2,i2] = vars in (r1 <= r2 && i1 <= i2) && (r1 /= r2 || i1 /= i2)|])
    leqA =
        binaryRel $(predAinternal [|let [r1,i1,r2,i2] = vars in (r1 <= r2 && i1 <= i2)|])

instance 
    (RealPredA to r) =>
    HasEqA to (Complex r) Integer 
    where
    type EqCompareTypeA to (Complex r) Integer = EqCompareTypeA to (Complex r) (Complex r)
    equalToA = convertSecondA equalToA

instance 
    (RealPredA to r) =>
    HasEqA to Integer (Complex r) where
    type EqCompareTypeA to Integer (Complex r) = EqCompareTypeA to (Complex r) (Complex r)
    equalToA = convertFirstA equalToA

instance
    (RealPredA to r) =>
    HasOrderA to (Complex r) Integer 
    where
    type OrderCompareTypeA to (Complex r) Integer = OrderCompareTypeA to (Complex r) (Complex r)
    lessThanA = convertSecondA lessThanA
    leqA = convertSecondA leqA

instance
    (RealPredA to r) =>
    HasOrderA to Integer (Complex r) 
    where
    type OrderCompareTypeA to Integer (Complex r) = OrderCompareTypeA to (Complex r) (Complex r)
    lessThanA = convertFirstA lessThanA
    leqA = convertFirstA leqA

instance 
    (RealPredA to r) =>
    HasEqA to (Complex r) Rational 
    where
    type EqCompareTypeA to (Complex r) Rational = EqCompareTypeA to (Complex r) (Complex r)
    equalToA = convertSecondA equalToA

instance 
    (RealPredA to r) =>
    HasEqA to Rational (Complex r) where
    type EqCompareTypeA to Rational (Complex r) = EqCompareTypeA to (Complex r) (Complex r)
    equalToA = convertFirstA equalToA

instance
    (RealPredA to r) =>
    HasOrderA to (Complex r) Rational 
    where
    type OrderCompareTypeA to (Complex r) Rational = OrderCompareTypeA to (Complex r) (Complex r)
    lessThanA = convertSecondA lessThanA
    leqA = convertSecondA leqA

instance
    (RealPredA to r) =>
    HasOrderA to Rational (Complex r) 
    where
    type OrderCompareTypeA to Rational (Complex r) = OrderCompareTypeA to (Complex r) (Complex r)
    lessThanA = convertFirstA lessThanA
    leqA = convertFirstA leqA

instance 
    (RealPredA to r) =>
    HasEqA to (Complex r) CauchyReal 
    where
    type EqCompareTypeA to (Complex r) CauchyReal = EqCompareTypeA to (Complex r) (Complex r)
    equalToA = convertSecondA equalToA

instance 
    (RealPredA to r) =>
    HasEqA to CauchyReal (Complex r) where
    type EqCompareTypeA to CauchyReal (Complex r) = EqCompareTypeA to (Complex r) (Complex r)
    equalToA = convertFirstA equalToA

instance
    (RealPredA to r) =>
    HasOrderA to (Complex r) CauchyReal 
    where
    type OrderCompareTypeA to (Complex r) CauchyReal = OrderCompareTypeA to (Complex r) (Complex r)
    lessThanA = convertSecondA lessThanA
    leqA = convertSecondA leqA

instance
    (RealPredA to r) =>
    HasOrderA to CauchyReal (Complex r) 
    where
    type OrderCompareTypeA to CauchyReal (Complex r) = OrderCompareTypeA to (Complex r) (Complex r)
    lessThanA = convertFirstA lessThanA
    leqA = convertFirstA leqA


{- Operations among (Complex r) numbers -}

instance (RealExprA to r) => CanNegA to (Complex r) where
    type NegTypeA to (Complex r) = Complex r
    negA =
        unaryOp ($(exprAinternal[|let [r,_i]=vars in neg r|]),  
                 $(exprAinternal[|let [_r,i]=vars in neg i|]))
        -- TODO add support for tuples of expresions in exprA

instance (RealExprA to r) => CanNegSameTypeA to (Complex r)

instance (CanSqrtSameTypeA to r, RealExprA to r) => CanAbsA to (Complex r) where
    type AbsTypeA to (Complex r) = r
    absA =
        proc (r :+ i) ->
             $(exprAinternal[| let [r,i]=vars in sqrt (r*r + i*i) |]) -< (r,i)

instance (RealExprA to r) => CanRecipA to (Complex r) where
    recipA = proc x -> divA -< (1,x)

instance (RealExprA to r) => CanRecipSameTypeA to (Complex r)

instance 
    (CanAddA to r1 r2) => 
    CanAddA to (Complex r1) (Complex r2) 
    where   
    type AddTypeA  to (Complex r1) (Complex r2) = Complex (AddTypeA to r1 r2)
    addA =
        proc (r1 :+ i1, r2 :+ i2) ->
            do
            r <- addA -< (r1,r2)
            i <- addA -< (i1,i2)
            returnA -< r :+ i

instance (CanAddThisA to r1 r2) => CanAddThisA to (Complex r1) (Complex r2)
instance (RealExprA to r) => CanAddSameTypeA to (Complex r)

instance 
    (CanSubA to r1 r2) 
    => 
    (CanSubA to (Complex r1) (Complex r2))  
    where   
    type SubTypeA  to (Complex r1) (Complex r2) = Complex (SubTypeA to r1 r2)
    subA =
        proc (r1 :+ i1, r2 :+ i2) ->
            do
            r <- subA -< (r1,r2)
            i <- subA -< (i1,i2)
            returnA -< r :+ i
instance (CanSubThisA to r1 r2, RealExprA to r2) => CanSubThisA to (Complex r1) (Complex r2)
instance (RealExprA to r) => CanSubSameTypeA to (Complex r)

instance 
    (CanMulA to r1 r2, 
     CanSubSameTypeA to (MulTypeA to r1 r2),
     CanAddSameTypeA to (MulTypeA to r1 r2)) 
    => 
    CanMulA to (Complex r1) (Complex r2) 
    where   
    type MulTypeA  to (Complex r1) (Complex r2) = Complex (MulTypeA to r1 r2)
    mulA =
        proc (r1 :+ i1, r2 :+ i2) ->
            do
            r1r2 <- mulA -< (r1,r2)
            r1i2 <- mulA -< (r1,i2)
            i1r2 <- mulA -< (i1,r2)
            i1i2 <- mulA -< (i1,i2)
            r <- subA -< (r1r2, i1i2)
            i <- addA -< (r1i2, i1r2)
            returnA -< r :+ i
--        binaryOp ($(exprA[|let [r1,i1,r2,i2]=vars in r1 * r2 - i1 * i2 |]), 
--                  $(exprA[|let [r1,i1,r2,i2]=vars in r1 * i2 + i1 * r2|])) 

instance (CanMulByA to r1 r2, RealExprA to r1) => CanMulByA to (Complex r1) (Complex r2)
instance (RealExprA to r) => CanMulSameTypeA to (Complex r)

instance 
    (CanMulA to r1 r2, 
     CanAddSameTypeA to (MulTypeA to r1 r2), 
     CanSubSameTypeA to (MulTypeA to r1 r2), 
     CanMulSameTypeA to (MulTypeA to r1 r2),
     CanAddSameTypeA to r2, 
     CanMulSameTypeA to r2, 
     CanDivByA to (MulTypeA to r1 r2) r2) 
    => 
    CanDivA to (Complex r1) (Complex r2) 
    where   
    type DivTypeA  to (Complex r1) (Complex r2) = Complex (MulTypeA to r1 r2)
    divA =
        proc (r1 :+ i1, r2 :+ i2) ->
            do
            r1r2 <- mulA -< (r1,r2)
            r1i2 <- mulA -< (r1,i2)
            i1r2 <- mulA -< (i1,r2)
            i1i2 <- mulA -< (i1,i2)
            rNum <- addA -< (r1r2, i1i2)
            iNum <- subA -< (i1r2, r1i2)
            r2r2 <- mulA -< (r2,r2)
            i2i2 <- mulA -< (i2,i2)
            d <- addA -< (r2r2, i2i2)
            r <- divA -< (rNum, d)
            i <- divA -< (iNum, d)
            returnA -< r :+ i
--        binaryOp ($(exprA[|let [r1,i1,r2,i2]=vars in (r1 * r2 + i1 * i2)/(r2*r2 + i2 * i2) |]), 
--                  $(exprA[|let [r1,i1,r2,i2]=vars in (i1 * r2 - r1 * i2)/(r2*r2 + i2 * i2) |])) 
        
instance 
    (CanMulByA to r1 r2, RealExprA to r1,
     RealExprA to r2, CanDivByA to r1 r2) 
    => 
    CanDivByA to (Complex r1) (Complex r2)
instance (RealExprA to r) => CanDivSameTypeA to (Complex r)

instance 
    (CanAddThisA to r1 r2, CanSubThisA to r1 r2, CanMulByA to r1 r2, RealExprA to r1, RealExprA to r2) 
    =>
    CanAddMulScalarA to (Complex r1) (Complex r2)
instance 
    (CanAddThisA to r1 r2, CanSubThisA to r1 r2, CanMulByA to r1 r2, RealExprA to r1,
     RealExprA to r2, CanDivByA to r1 r2) 
    => 
    CanAddMulDivScalarA to (Complex r1) (Complex r2)
instance (RealPredA to r) => RingA to (Complex r)
instance (RealPredA to r) => FieldA to (Complex r)
instance (RealPredA to r) => RealExprA to (Complex r)
instance (RealPredA to r) => RealPredA to (Complex r)

{- (Complex r)-Integer operations -}

instance (RealExprA to r) => CanAddMulScalarA to (Complex r) Integer
instance (RealExprA to r) => CanAddMulDivScalarA to (Complex r) Integer

instance (RealExprA to r) => CanAddA to Integer (Complex r) where
    type AddTypeA to Integer (Complex r) = (Complex r)
    addA = convertFirstRealOnlyA addA 


instance (RealExprA to r) => CanSubA to Integer (Complex r)


instance (RealExprA to r) => CanAddA to (Complex r) Integer where
    type AddTypeA to (Complex r) Integer = (Complex r)
    addA = convertSecondRealOnlyA addA 


instance (RealExprA to r) => CanAddThisA to (Complex r) Integer

instance (RealExprA to r) => CanSubA to (Complex r) Integer where
    type SubTypeA to (Complex r) Integer = (Complex r)
    subA = convertSecondRealOnlyA subA 


instance (RealExprA to r) => CanSubThisA to (Complex r) Integer

instance (RealExprA to r) => CanMulA to Integer (Complex r) where
    type MulTypeA to Integer (Complex r) = (Complex r)
    mulA =
        binaryLeftROp 
            ($(exprAinternal[|let [r,r2,_i2]=vars in r*r2 |]), 
             $(exprAinternal[|let [r,_r2,i2]=vars in r*i2 |])) 

instance (RealExprA to r) => CanMulA to (Complex r) Integer where
    type MulTypeA to (Complex r) Integer = (Complex r)
    mulA = flipA mulA 

instance (RealExprA to r) => CanMulByA to (Complex r) Integer

instance (RealExprA to r) => CanDivA to Integer (Complex r) where
    type DivTypeA to Integer (Complex r) = (Complex r)
    divA =
        binaryLeftROp 
            ($(exprAinternal[|let [r,r2,i2]=vars in (r*r2)/(r2*r2 + i2*i2) |]), 
             $(exprAinternal[|let [r,r2,i2]=vars in (neg r*i2)/(r2*r2 + i2*i2) |])) 

instance (RealExprA to r) => CanDivA to (Complex r) Integer where
    type DivTypeA to (Complex r) Integer = (Complex r)
    divA = 
        proc (c,r) -> mulA -< (c, 1/r) 

instance (RealExprA to r) => CanDivByA to (Complex r) Integer


{- (Complex r)-Rational operations -}

instance (RealExprA to r) => CanAddMulScalarA to (Complex r) Rational
instance (RealExprA to r) => CanAddMulDivScalarA to (Complex r) Rational

instance (RealExprA to r) => CanAddA to Rational (Complex r) where
    type AddTypeA to Rational (Complex r) = (Complex r)
    addA = convertFirstRealOnlyA addA 


instance (RealExprA to r) => CanSubA to Rational (Complex r)


instance (RealExprA to r) => CanAddA to (Complex r) Rational where
    type AddTypeA to (Complex r) Rational = (Complex r)
    addA = convertSecondRealOnlyA addA 


instance (RealExprA to r) => CanAddThisA to (Complex r) Rational

instance (RealExprA to r) => CanSubA to (Complex r) Rational where
    type SubTypeA to (Complex r) Rational = (Complex r)
    subA = convertSecondRealOnlyA subA 


instance (RealExprA to r) => CanSubThisA to (Complex r) Rational

instance (RealExprA to r) => CanMulA to Rational (Complex r) where
    type MulTypeA to Rational (Complex r) = (Complex r)
    mulA =
        binaryLeftROp 
            ($(exprAinternal[|let [r,r2,_i2]=vars in r*r2 |]), 
             $(exprAinternal[|let [r,_r2,i2]=vars in r*i2 |])) 

instance (RealExprA to r) => CanMulA to (Complex r) Rational where
    type MulTypeA to (Complex r) Rational = (Complex r)
    mulA = flipA mulA 

instance (RealExprA to r) => CanMulByA to (Complex r) Rational

instance (RealExprA to r) => CanDivA to Rational (Complex r) where
    type DivTypeA to Rational (Complex r) = (Complex r)
    divA =
        binaryLeftROp 
            ($(exprAinternal[|let [r,r2,i2]=vars in (r*r2)/(r2*r2 + i2*i2) |]), 
             $(exprAinternal[|let [r,r2,i2]=vars in (neg r*i2)/(r2*r2 + i2*i2) |])) 

instance (RealExprA to r) => CanDivA to (Complex r) Rational where
    type DivTypeA to (Complex r) Rational = (Complex r)
    divA = 
        proc (c,r) -> mulA -< (c, 1/r) 

instance (RealExprA to r) => CanDivByA to (Complex r) Rational


{- (Complex r)-CauchyReal operations -}

instance (RealExprA to r) => CanAddMulScalarA to (Complex r) CauchyReal
instance (RealExprA to r) => CanAddMulDivScalarA to (Complex r) CauchyReal

instance (RealExprA to r) => CanAddA to CauchyReal (Complex r) where
    type AddTypeA to CauchyReal (Complex r) = (Complex r)
    addA = convertFirstRealOnlyA addA 


instance (RealExprA to r) => CanSubA to CauchyReal (Complex r)


instance (RealExprA to r) => CanAddA to (Complex r) CauchyReal where
    type AddTypeA to (Complex r) CauchyReal = (Complex r)
    addA = convertSecondRealOnlyA addA 


instance (RealExprA to r) => CanAddThisA to (Complex r) CauchyReal

instance (RealExprA to r) => CanSubA to (Complex r) CauchyReal where
    type SubTypeA to (Complex r) CauchyReal = (Complex r)
    subA = convertSecondRealOnlyA subA 


instance (RealExprA to r) => CanSubThisA to (Complex r) CauchyReal

instance (RealExprA to r) => CanMulA to CauchyReal (Complex r) where
    type MulTypeA to CauchyReal (Complex r) = (Complex r)
    mulA =
        binaryLeftROp 
            ($(exprAinternal[|let [r,r2,_i2]=vars in r*r2 |]), 
             $(exprAinternal[|let [r,_r2,i2]=vars in r*i2 |])) 
 
instance (RealExprA to r) => CanMulA to (Complex r) CauchyReal where
    type MulTypeA to (Complex r) CauchyReal = (Complex r)
    mulA = flipA mulA 

instance (RealExprA to r) => CanMulByA to (Complex r) CauchyReal

instance (RealExprA to r) => CanDivA to CauchyReal (Complex r) where
    type DivTypeA to CauchyReal (Complex r) = (Complex r)
    divA =
        binaryLeftROp 
            ($(exprAinternal[|let [r,r2,i2]=vars in (r*r2)/(r2*r2 + i2*i2) |]), 
             $(exprAinternal[|let [r,r2,i2]=vars in (neg r*i2)/(r2*r2 + i2*i2) |])) 

instance (RealExprA to r) => CanDivA to (Complex r) CauchyReal where
    type DivTypeA to (Complex r) CauchyReal = (Complex r)
    divA = 
        proc (c,r) -> mulA -< (c, 1/r) 

instance (RealExprA to r) => CanDivByA to (Complex r) CauchyReal

{- Selected complex functions -}


instance (RealExprA to r) => CanSqrtA to (Complex r) where
    sqrtA = error "Complex sqrt not implemented yet"

instance (RealExprA to r) => CanSqrtSameTypeA to (Complex r)

instance (RealExprA to r) => CanExpA to (Complex r) where
    expA =
        unaryOp ($(exprAinternal[|let [r1,i1]=vars in (exp r1) * (cos i1)|]),
                 $(exprAinternal[|let [r1,i1]=vars in (exp r1) * (sin i1)|]))
--     (r :+ i) =
--        (exp r :+ convert 0) * (cos i :+ sin i)

instance (RealExprA to r) => CanExpSameTypeA to (Complex r)
    
instance (RealExprA to r) => CanSineCosineA to (Complex r) where
    sinA = error "(Complex r) sin not implemented yet"
    cosA = error "(Complex r) cos not implemented yet"

instance (RealExprA to r) => CanSineCosineSameTypeA to (Complex r)

{- auxiliary function -}

convertSecondRealOnlyA ::
    (Arrow to, ConvertibleA to a r) =>
    ((r,r) `to` r) -> ((Complex r,a) `to` Complex r) 
convertSecondRealOnlyA opA =
    proc (r :+ i,yI) ->
        do
        y <- convertA -< yI
        r' <- opA -< (r,y)
        returnA -< (r' :+ i)

convertFirstRealOnlyA ::
    (Arrow to, ConvertibleA to a r) =>
    ((r,r) `to` r) -> ((a,Complex r) `to` Complex r) 
convertFirstRealOnlyA opA =
    proc (xI,r :+ i) ->
        do
        x <- convertA -< xI
        r' <- opA -< (x,r)
        returnA -< (r' :+ i)

binaryLeftROp ::
    (Arrow to, ConvertibleA to a r) => 
    ((r,r,r) `to` r, (r,r,r) `to` r) -> ((a, Complex r) `to` (Complex r))
binaryLeftROp (realA, imagA) =
    proc (xI, r2 :+ i2) ->
        do
        x <- convertA -< xI
        r <- realA  -< (x,r2,i2)
        i <- imagA  -< (x,r2,i2)
        returnA -< (r :+ i)


binaryRel ::
    (Arrow to) => 
    ((r,r,r,r) `to` a) -> ((Complex r, Complex r) `to` a)
binaryRel tupleA =
    proc (r1 :+ i1, r2 :+ i2) -> tupleA -< (r1,i1,r2,i2)

_binaryOp ::
    (Arrow to) => 
    ((r,r,r,r) `to` r, (r,r,r,r) `to` r) -> ((Complex r, Complex r) `to` (Complex r))
_binaryOp (realA, imagA) =
    proc (r1 :+ i1, r2 :+ i2) ->
        do
        r <- realA  -< (r1,i1,r2,i2)
        i <- imagA  -< (r1,i1,r2,i2)
        returnA -< (r :+ i)

unaryOp ::
    (Arrow to) => 
    ((r,r) `to` r, (r,r) `to` r) -> ((Complex r) `to` (Complex r))
unaryOp (realA, imagA) =
    proc (r1 :+ i1) ->
        do
        r <- realA  -< (r1,i1)
        i <- imagA  -< (r1,i1)
        returnA -< (r :+ i)

