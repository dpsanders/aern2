module AERN2.Num.Accuracy 
    (Accuracy(NoInformation, Exact), bits, fromAccuracy) 
where

import AERN2.Num.IntegerRational ()
import AERN2.Num.Operations

{- example -}

_example1 :: Accuracy
_example1 = 1 + 2*(bits 100)

{-| A non-negative Double value to serve as an error bound. Arithmetic is rounded towards +infinity. -}
data Accuracy = NoInformation | Bits { fromAccuracy :: Integer } | Exact 
    deriving (Eq, Ord)

bits :: Integer -> Accuracy
bits i = Bits i

instance Show Accuracy where
    show (NoInformation) = "NoInformation"
    show (Bits a) = "Bits " ++ show a
    show (Exact) = "Exact"

instance HasEq Accuracy Accuracy where

instance HasOrder Accuracy Accuracy where

instance CanMinMax Accuracy Accuracy where

instance CanMinMaxThis Accuracy Accuracy
instance CanMinMaxSameType Accuracy

--instance CanAddA (->) Accuracy Accuracy where
--    addA (NoInformation, _) = NoInformation
--    addA (_, NoInformation) = NoInformation
--    addA (Bits a, Bits b) = Bits $ a + b
--    addA (Exact, _) = Exact
--    addA (_, Exact) = Exact
--
--instance CanAddThis Accuracy Accuracy
--instance CanAddSameType Accuracy
--
--instance CanMulA (->) Accuracy Accuracy where
--    mulA (NoInformation, _) = NoInformation
--    mulA (_, NoInformation) = NoInformation
--    mulA (Bits a, Bits b) = Bits $ a * b
--    mulA (Exact, _) = Exact
--    mulA (_, Exact) = Exact
--
--instance CanMulBy Accuracy Accuracy
--instance CanMulSameType Accuracy

instance CanMinMaxA (->) Accuracy Integer where
    type MinMaxTypeA (->) Accuracy Integer = Accuracy
    minA (NoInformation, _) = NoInformation
    minA (Bits a, b) = Bits $ min a b
    minA (Exact, a) = Bits a
    maxA (NoInformation, a) = Bits a
    maxA (Bits a, b) = Bits $ max a b
    maxA (Exact, _) = Exact

instance CanMinMaxA (->) Integer Accuracy where
    type MinMaxTypeA (->) Integer Accuracy = Accuracy
    minA (a, b) = min b a
    maxA (a, b) = max b a

instance CanMinMaxThis Accuracy Integer

instance CanMulA (->) Accuracy Integer where
    type MulTypeA (->) Accuracy Integer = Accuracy
    mulA (NoInformation, _) = NoInformation
    mulA (Bits a, i) = Bits $ a * i
    mulA (Exact, _) = Exact

instance CanMulA (->) Integer Accuracy where
    type MulTypeA (->) Integer Accuracy = Accuracy
    mulA (i, a) = mul a i

instance CanMulBy Accuracy Integer

instance CanAddA (->) Accuracy Integer where
    type AddTypeA (->) Accuracy Integer = Accuracy
    addA (NoInformation, _) = NoInformation
    addA (Bits a, i) = Bits $ a + i
    addA (Exact, _) = Exact

instance CanAddA (->) Integer Accuracy where
    type AddTypeA (->) Integer Accuracy = Accuracy
    addA (i, a) = add a i

instance CanAddThis Accuracy Integer

instance CanSub Accuracy Integer where

instance CanSubThis Accuracy Integer
