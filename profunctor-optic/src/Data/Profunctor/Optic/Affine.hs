module Data.Profunctor.Optic.Affine where

import Control.Arrow ((|||))
import Data.Profunctor
--import Data.Profunctor.Traversing
import Data.Profunctor.Optic.Types

{- hedgehog props
previewSet :: Eq s => Affine_ s s a a -> s -> Bool
previewSet (Affine_ seta sbt) s = either (\a -> sbt (a, s)) id (seta s) == s

setPreview :: (Eq a, Eq s) => Affine_ s s a a -> a -> s -> Bool
setPreview (Affine_ seta sbt) a s = seta (sbt (a, s)) == either (Left . const a) Right (seta s)

setSet :: Eq s => Affine_ s s a a -> a -> a -> s -> Bool
setSet (Affine_ _ sbt) a1 a2 s = sbt (a2, (sbt (a1, s))) == sbt (a2, s)

affineTraversal :: (s -> Either t a)
                -> (s -> b -> t)
                -> AffineTraversal s t a b
affineTraversal getter setter pab = dimap
    (\s -> (getter s, s))
    (\(bt, s) -> either id (setter s) bt)
    (first' (right' pab))

-}

-- sometimes known as a partial lens
affine :: (s -> Either t a) -> (s -> b -> t) -> Affine s t a b
affine seta sbt =
 let f s = (\x -> (x,s)) <$> seta s
     g = id ||| (uncurry . flip $ sbt)

  in dimap f g . right' . first'

