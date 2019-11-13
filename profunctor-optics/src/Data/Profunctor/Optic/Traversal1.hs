{-# LANGUAGE TupleSections #-}

module Data.Profunctor.Optic.Traversal1 (
    module Export
  , module Data.Profunctor.Optic.Traversal1
) where

import Data.Functor.Apply
import Data.Profunctor.Optic.Type
import Data.Profunctor.Optic.Prelude

import Data.Semigroup.Traversable.Class as Export


---------------------------------------------------------------------
-- 'Traversal1'
---------------------------------------------------------------------

-- | Build a 'Traversal1' optic from a getter and setter.
--
-- \( \mathsf{Traversal1}\;S\;A = \exists F : \mathsf{Traversable1}, S \equiv F\,A \)
--
--
traversal1 :: Traversable1 f => (s -> f a) -> (s -> f b -> t) -> Traversal1 s t a b
traversal1 sa sbt = dimap fork (uncurry sbt) . second' . lmap sa . lift traverse1

-- | Transform a Van Laarhoven 'Traversal1' into a profunctor 'Traversal1'.
--
-- /Caution/: In order for the generated family to be well-defined,
-- you must ensure that the traversal1 law holds for the input function:
--
-- * @fmap (abst f) . abst g ≡ getCompose . abst (Compose . fmap f . g)@
--
-- See 'Data.Profunctor.Optic.Property'.
--
traversing1 :: (forall f. Apply f => (a -> f b) -> s -> f t) -> Traversal1 s t a b
traversing1 abst = lift abst

-- | Create a 'Traversal1' from a 'Traversable1' functor.
--
traversed1 :: Traversable1 t => Traversal1 (t a) (t b) a b
traversed1 = traversing1 traverse1

---------------------------------------------------------------------
-- Primitive operators
---------------------------------------------------------------------

-- | The traversal laws can be stated in terms or 'traverse1Of' as well.
-- 
-- Identity:
-- 
-- @
-- traverse1Of t (Identity . f) ≡  Identity (fmap f)
-- @
-- 
-- Composition:
-- 
-- @ 
-- Compose . fmap (traverse1Of t f) . traverse1Of t g ≡ traverse1Of t (Compose . fmap f . g)
-- @
--
-- @
-- traverse1Of :: Functor f => Lens s t a b -> (a -> f b) -> s -> f t
-- traverse1Of :: Apply f => Traversal1 s t a b -> (a -> f b) -> s -> f t
-- @
--
traverse1Of :: Apply f => ATraversal1 f s t a b -> (a -> f b) -> s -> f t
traverse1Of o f = tf where Star tf = o (Star f)

-- | TODO: Document
--
sequence1Of :: Apply f => ATraversal1 f s t (f a) a -> s -> f t
sequence1Of t = traverse1Of t id

---------------------------------------------------------------------
-- Common 'Traversal1's
---------------------------------------------------------------------

-- | Traverse both parts of a 'Bitraversable1' container with matching types.
--
-- Usually that type will be a pair.
--
-- @
-- 'both1' :: 'Traversal1' (a, a)       (b, b)       a b
-- 'both1' :: 'Traversal1' ('Either' a a) ('Either' b b) a b
-- @
both1 :: Bitraversable1 r => Traversal1 (r a a) (r b b) a b
both1 = lift $ \f -> bitraverse1 f f
{-# INLINE both1 #-}

-- | Form a 'Traversal1'' by repeating the input forever.
--
-- @
-- 'repeat' ≡ 'toListOf' 'repeated'
-- @
--
-- >>> take 5 $ 5 ^.. repeated
-- [5,5,5,5,5]
--
-- @
-- repeated :: Fold1 a a
-- @
--
repeated :: Traversal1' a a
repeated = lift $ \g a -> go g a where go g a = g a .> go g a
{-# INLINE repeated #-}

-- | @x '^.' 'iterated' f@ returns an infinite 'Traversal1'' of repeated applications of @f@ to @x@.
--
-- @
-- 'toListOf' ('iterated' f) a ≡ 'iterate' f a
-- @
--
-- >>> take 3 $ (1 :: Int) ^.. iterated (+1)
-- [1,2,3]
--
-- @
-- iterated :: (a -> a) -> 'Fold1' a a
-- @
iterated :: (a -> a) -> Traversal1' a a
iterated f = lift $ \g a0 -> go g a0 where go g a = g a .> go g (f a)
{-# INLINE iterated #-}

-- | Transform a 'Traversal1'' into a 'Traversal1'' that loops lift its elements repeatedly.
--
-- >>> take 7 $ (1 :| [2,3]) ^.. cycled traversed1
-- [1,2,3,1,2,3,1]
--
-- @
-- cycled :: 'Fold1' s a -> 'Fold1' s a
-- @
cycled :: Apply f => ATraversal1' f s a -> ATraversal1' f s a
cycled o = lift $ \g a -> go g a where go g a = (traverse1Of o g) a .> go g a
{-# INLINE cycled #-}