{-# LANGUAGE FlexibleContexts, FlexibleInstances, RankNTypes, EmptyDataDecls, UndecidableInstances #-}

module StrategyClassesMockup2 where

import AERN2.Num

import Control.Arrow

import qualified Data.Map as Map

exampleRealGeneric1 :: RealGeneric (GPair GR GR) GR
exampleRealGeneric1 = 
    RealGeneric (anyStrategy addA)

exampleRealGeneric1EvalReal_CauchyReal :: (CauchyReal, CauchyReal) -> CauchyReal
exampleRealGeneric1EvalReal_CauchyReal =
    exampleRealGeneric1 `withEvalStrategyReal` EvalReal_CauchyReal

exampleRealGeneric1EvalReal_FixedPrec :: Precision -> (MPBall, MPBall) -> MPBall
exampleRealGeneric1EvalReal_FixedPrec p =
    runWithPrecisionPolicy (exampleRealGeneric1 `withEvalStrategyReal` EvalReal_BallFixedPrec) (ppUseCurr p)

exampleRealGeneric1EvalReal_BallIncreasePrec :: (CauchyReal, CauchyReal) -> CauchyReal
exampleRealGeneric1EvalReal_BallIncreasePrec =
    exampleRealGeneric1 `withEvalStrategyReal` EvalReal_BallIncreasePrec

exampleRealGeneric2 :: RealGeneric GR (GPair GR GR)
exampleRealGeneric2 = 
    RealGeneric (anyStrategy $ proc x -> do nx <- negA -< x; returnA -< (x,nx))

exampleRealGeneric2EvalReal_CauchyReal :: CauchyReal -> (CauchyReal, CauchyReal)
exampleRealGeneric2EvalReal_CauchyReal =
    exampleRealGeneric2 `withEvalStrategyReal` EvalReal_CauchyReal

exampleRealGeneric2EvalReal_FixedPrec :: Precision -> MPBall -> (MPBall, MPBall)
exampleRealGeneric2EvalReal_FixedPrec p =
    runWithPrecisionPolicy (exampleRealGeneric2 `withEvalStrategyReal` EvalReal_BallFixedPrec) (ppUseCurr p)

exampleRealGeneric2EvalReal_BallIncreasePrec :: CauchyReal -> (CauchyReal, CauchyReal)
exampleRealGeneric2EvalReal_BallIncreasePrec =
    exampleRealGeneric2 `withEvalStrategyReal` EvalReal_BallIncreasePrec

exampleRealGeneric3 :: RealGeneric GR (GList GR)
exampleRealGeneric3 = 
    RealGeneric (anyStrategy $ proc x -> do nx <- negA -< x; returnA -< [x,nx])

exampleRealGeneric3EvalReal_CauchyReal :: CauchyReal -> [CauchyReal]
exampleRealGeneric3EvalReal_CauchyReal =
    exampleRealGeneric3 `withEvalStrategyReal` EvalReal_CauchyReal

{-| Strategy-generic expression -}

data RealGeneric i o = RealGeneric
    { 
        withEvalStrategyReal_ :: 
            (forall s. EvalStrategyReal s i o => s -> (ES_to s) (GType2ESType (i s)) (GType2ESType (o s))) 
    }

{-| This trivial synonym helps to make expressions that return one real number more readable, eg: 
    @RealGeneric (anyStrategy addA)@
-}
anyStrategy :: a -> b -> a
anyStrategy = const

data GR s
data GKL s

data GNil s
data GPair (t1 :: * -> *) (t2 :: * -> *) s
data GTriple (t1 :: * -> *) (t2 :: * -> *) (t3 :: * -> *) s
data GList (t :: * -> *) s
data GVarMap (t :: * -> *) s

type family GType2ESType s

type instance GType2ESType (GR s) = ES_r s
type instance GType2ESType (GKL s) = ES_kl s
type instance GType2ESType (GNil s) = ()
type instance GType2ESType (GPair t1 t2 s) = (GType2ESType (t1 s), GType2ESType (t2 s))
type instance GType2ESType (GTriple t1 t2 t3 s) = (GType2ESType (t1 s), GType2ESType (t2 s), GType2ESType (t3 s))
type instance GType2ESType (GList t s) = [GType2ESType (t s)]
type instance GType2ESType (GVarMap t s) = VarMap (GType2ESType (t s))


{-| strategy for evaluating arrow-generic real expressions  -}
class
    (ArrowReal (ES_to s) (ES_r s))
    => 
    EvalStrategyReal s i o
    where
    type ES_to s :: * -> * -> *
    type ES_r s -- ^ Real number type
    type ES_kl s -- ^ Kleenean type (eg Maybe Boolean)
    withEvalStrategyReal :: RealGeneric i o -> s -> (ES_to s) (GType2ESType (i s)) (GType2ESType (o s))
    withEvalStrategyReal = withEvalStrategyReal_  

{----- specific strategies -----}

data EvalReal_CauchyReal = EvalReal_CauchyReal
data EvalReal_BallFixedPrec = EvalReal_BallFixedPrec
data EvalReal_BallIncreasePrec = EvalReal_BallIncreasePrec

instance EvalStrategyReal EvalReal_CauchyReal i o where
    type ES_to EvalReal_CauchyReal = (->)
    type ES_r EvalReal_CauchyReal = CauchyReal
    type ES_kl EvalReal_CauchyReal = Accuracy -> Maybe Bool

instance EvalStrategyReal EvalReal_BallFixedPrec i o where
    type ES_to EvalReal_BallFixedPrec = WithPrecisionPolicy (->)
    type ES_r EvalReal_BallFixedPrec = MPBall
    type ES_kl EvalReal_BallFixedPrec = Maybe Bool

instance
    (CanMakeFromPrecisionSequence
        (GType2ESType (o EvalReal_BallIncreasePrec))
        (GType2ESType (o EvalReal_BallFixedPrec)),
     CanEncloseWithPrecision
        (GType2ESType (i EvalReal_BallIncreasePrec))
        (GType2ESType (i EvalReal_BallFixedPrec))
    )
    => 
    EvalStrategyReal EvalReal_BallIncreasePrec i o 
    where
    type ES_to EvalReal_BallIncreasePrec = (->)
    type ES_r EvalReal_BallIncreasePrec = CauchyReal
    type ES_kl EvalReal_BallIncreasePrec = Accuracy -> Maybe Bool
    withEvalStrategyReal fnG _ input =
        fromPrecisionSequence (\p -> runWithPrecisionPolicy fnMB (ppUseCurr p) (encloseWithPrecision p input)) 
        where
        fnMB = fnG `withEvalStrategyReal` EvalReal_BallFixedPrec 

class CanEncloseWithPrecision r b where
    encloseWithPrecision :: Precision -> r -> b

instance CanEncloseWithPrecision CauchyReal MPBall where
    encloseWithPrecision p r = cauchyReal2ball r (bits $ prec2integer p) 

instance CanEncloseWithPrecision () () where
    encloseWithPrecision _ _ = () 

instance 
    (CanEncloseWithPrecision r b)
    =>
    CanEncloseWithPrecision [r] [b]
    where
    encloseWithPrecision p = map $ encloseWithPrecision p

instance 
    (CanEncloseWithPrecision r b)
    =>
    CanEncloseWithPrecision (VarMap r) (VarMap b)
    where
    encloseWithPrecision p = Map.map $ encloseWithPrecision p

instance 
    (CanEncloseWithPrecision r1 b1, CanEncloseWithPrecision r2 b2)
    =>
    CanEncloseWithPrecision (r1,r2) (b1,b2)
    where
    encloseWithPrecision p (r1,r2) =
        (encloseWithPrecision p r1, encloseWithPrecision p r2)

instance 
    (CanEncloseWithPrecision r1 b1, CanEncloseWithPrecision r2 b2, CanEncloseWithPrecision r3 b3)
    =>
    CanEncloseWithPrecision (r1,r2,r3) (b1,b2,b3)
    where
    encloseWithPrecision p (r1,r2,r3) =
        (encloseWithPrecision p r1, encloseWithPrecision p r2, encloseWithPrecision p r3)

class CanMakeFromPrecisionSequence r b where
    fromPrecisionSequence :: (Precision -> b) -> r

instance CanMakeFromPrecisionSequence CauchyReal MPBall where
    fromPrecisionSequence = seqByPrecision2Cauchy Nothing

instance CanMakeFromPrecisionSequence () () where
    fromPrecisionSequence _ = () 

{- TODO
instance 
    (CanMakeFromPrecisionSequence r b)
    =>
    CanMakeFromPrecisionSequence [r] [b]
    where
    fromPrecisionSequence seq = 
        undefined

instance 
    (CanMakeFromPrecisionSequence r b)
    =>
    CanMakeFromPrecisionSequence (VarMap r) (VarMap b)
    where
    fromPrecisionSequence seq = 
        undefined
-}


instance 
    (CanMakeFromPrecisionSequence r1 b1, CanMakeFromPrecisionSequence r2 b2)
    =>
    CanMakeFromPrecisionSequence (r1,r2) (b1,b2)
    where
    fromPrecisionSequence sq =
        (fromPrecisionSequence (fst . sq), 
         fromPrecisionSequence (snd . sq))

instance 
    (CanMakeFromPrecisionSequence r1 b1, CanMakeFromPrecisionSequence r2 b2, CanMakeFromPrecisionSequence r3 b3)
    =>
    CanMakeFromPrecisionSequence (r1,r2,r3) (b1,b2,b3)
    where
    fromPrecisionSequence sq =
        (fromPrecisionSequence ((\(a,_,_) -> a) . sq), 
         fromPrecisionSequence ((\(_,b,_) -> b) . sq),
         fromPrecisionSequence ((\(_,_,c) -> c) . sq))


