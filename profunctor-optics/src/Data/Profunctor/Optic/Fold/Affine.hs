module Data.Profunctor.Optic.Fold.Affine where

import Data.Semigroup
import Data.Profunctor.Optic.Type 
import Data.Profunctor.Optic.Prelude

import Data.Profunctor.Optic.Getter (view, to)
import Data.Profunctor.Optic.Prism (_Just)
import Data.Foldable (traverse_)
--import Data.Functor.Const (Const(..))
--import Data.Profunctor.Optic.Fold.Monoid (foldlOf')

import Control.Monad ((<=<))
import Control.Monad.Reader as Reader
import Control.Monad.State as State

import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NE

import Data.Profunctor.Optic.Setter

import Data.Maybe (fromMaybe)

---------------------------------------------------------------------
-- 'Fold0'
---------------------------------------------------------------------

type AFold0 s a = FoldLike (Maybe a) s a

{-

Fold0 laws:

affine_fold_complete :: Fold0 s a -> Bool
affine_fold_complete o = tripping o $ afolding (toMaybeOf o)
-}

-- | Build a 'Fold0' from an arbitrary function.
--
-- >>> [Just 1, Nothing] ^.. folding id . afolding id
-- [1]
--
-- @
-- 'afolding' ('view' o) ≡ o . '_Just'
-- @
--
afolding :: (s -> Maybe a) -> Fold0 s a
afolding f = rcoerce . lmap (\s -> maybe (Left s) Right (f s)) . right'

-- | Build a 'Fold0' from an affine 'Getter'.
--
-- @
-- 'toFold0' o ≡ o . '_Just'
-- 'toFold0' o ≡ 'afolding' ('view' o)
-- @
--
toFold0 :: Getter s (Maybe a) -> Fold0 s a
toFold0 = (. _Just)

-- | TODO: Document
--
fromFold0 :: Monoid a => Fold0 s a -> Getter s (Maybe a)
fromFold0 = to . preview

-- | TODO: Document
--
cloneFold0 :: FoldLike (Maybe a) s (Maybe a) -> Fold0 s a
cloneFold0 = (. _Just) . to . view 

---------------------------------------------------------------------
-- Primitive Operators
---------------------------------------------------------------------

previewOf :: FoldLike (Maybe r) s a -> (a -> r) -> s -> Maybe r
previewOf = between (dstar getConst) (ustar $ Const . Just)

toMaybeOf :: AFold0 s a -> s -> Maybe a
toMaybeOf = flip previewOf id

---------------------------------------------------------------------
-- Derived Operators
---------------------------------------------------------------------

preview :: MonadReader s m => AFold0 s a -> m (Maybe a)
preview o = Reader.asks $ toMaybeOf o

{-

-- @
-- preview :: 'AFold' ('First' a) s a -> s -> 'Maybe' a
-- @
--
preview 
  :: MonadReader s m 
  => FoldLike (Maybe (First a)) s a  
  -> m (Maybe a)
preview o = Reader.asks $ \s -> getFirst <$> foldMapOf o (Just . First) s 

preuse 
  :: MonadState s m
  => FoldLike (Maybe (First a)) s a  
  -> m (Maybe a)
preuse o = State.gets (preview o)
-}

infixl 8 ^?

-- | A more permissive infix variant of 'preview''.
--
-- Performs a safe 'head' of a 'Fold' or 'Traversal' or retrieve 'Just' 
-- the result from a 'Getter' or 'Lens'.
--
-- When using a 'Traversal' as a partial 'Lens', or a 'Fold' as a partial 
-- 'Getter' this can be a convenient way to extract the optional value.
--
--
-- >>> Left 4 ^? _L
-- Just 4
--
-- >>> Right 4 ^? _Left
-- Nothing
--
-- @
-- ('^?') ≡ 'flip' 'preview''
-- @
--
-- @
-- ('^?') :: s -> 'Getter' s a         -> 'Maybe' a
-- ('^?') :: s -> 'Fold' s a         -> 'Maybe' a
-- ('^?') :: s -> 'Lens'' s a        -> 'Maybe' a
-- ('^?') :: s -> 'Prism'' s a       -> 'Maybe' a
-- ('^?') :: s -> 'Affine'' s a      -> 'Maybe' a
-- ('^?') :: s -> 'Iso'' s a         -> 'Maybe' a
-- ('^?') :: s -> 'Traversal'' s a   -> 'Maybe' a
-- @
--(^?) :: s -> AFold0 (First a) s a -> Maybe a
--s ^? o = getFirst <$> previewOf o First s
--(^?) :: s -> AFold0 s a -> Maybe a
(^?) :: s -> AFold0 s a -> Maybe a
s ^? o = toMaybeOf o s

{-
-- | Find the innermost focus of a `Fold` that satisfies a predicate, if there is any.
--
findOf :: FoldLike (Endo (Maybe a)) s a -> (a -> Bool) -> s -> Maybe a
findOf o f =
  foldrOf o (\a -> maybe (if f a then Just a else Nothing) Just) Nothing


-- | The maximum of all foci of a `Fold`, if there is any.
--
maximumOf :: Ord a => FoldLike (Endo (Maybe a)) s a -> s -> Maybe a
maximumOf o = foldrOf o (\a -> Just . maybe a (max a)) Nothing

-- | The minimum of all foci of a `Fold`, if there is any.
--
minimumOf :: Ord a => FoldLike (Endo (Maybe a)) s a -> s -> Maybe a
minimumOf o = foldrOf o (\a -> Just . maybe a (min a)) Nothing
-}



{-

-- | Obtain the minimum element (if any) targeted by a 'Fold', 'Traversal', 'Lens', 'Iso'
-- or 'Getter' according to a user supplied 'Ordering'.
--
-- In the interest of efficiency, This operation has semantics more strict than strictly necessary.
--
-- >>> minimumByOf traverse' (compare `on` length) ["mustard","relish","ham"]
-- Just "ham"
--
-- @
-- 'minimumBy' cmp ≡ 'Data.Maybe.fromMaybe' ('error' \"empty\") '.' 'minimumByOf' 'folded' cmp
-- @
--
-- @
-- 'minimumByOf' :: 'Getter' s a     -> (a -> a -> 'Ordering') -> s -> 'Maybe' a
-- 'minimumByOf' :: 'Fold' s a       -> (a -> a -> 'Ordering') -> s -> 'Maybe' a
-- 'minimumByOf' :: 'Iso'' s a       -> (a -> a -> 'Ordering') -> s -> 'Maybe' a
-- 'minimumByOf' :: 'Lens'' s a      -> (a -> a -> 'Ordering') -> s -> 'Maybe' a
-- 'minimumByOf' :: 'Traversal'' s a -> (a -> a -> 'Ordering') -> s -> 'Maybe' a
-- @
minimumByOf :: FoldLike (Endo (Endo (Maybe a))) s a -> (a -> a -> Ordering) -> s -> Maybe a
minimumByOf o cmp = foldlOf' o mf Nothing where
  mf Nothing y = Just $! y
  mf (Just x) y = Just $! if cmp x y == GT then y else x
{-# INLINE minimumByOf #-}

-- | The 'findOf' function takes a 'Lens' (or 'Getter', 'Iso', 'Fold', or 'Traversal'),
-- a predicate and a structure and returns the leftmost element of the structure
-- matching the predicate, or 'Nothing' if there is no such element.
--
-- >>> findOf each even (1,3,4,6)
-- Just 4
--
-- >>> findOf folded even [1,3,5,7]
-- Nothing
--
-- @
-- 'findOf' :: 'Getter' s a     -> (a -> 'Bool') -> s -> 'Maybe' a
-- 'findOf' :: 'Fold' s a       -> (a -> 'Bool') -> s -> 'Maybe' a
-- 'findOf' :: 'Iso'' s a       -> (a -> 'Bool') -> s -> 'Maybe' a
-- 'findOf' :: 'Lens'' s a      -> (a -> 'Bool') -> s -> 'Maybe' a
-- 'findOf' :: 'Traversal'' s a -> (a -> 'Bool') -> s -> 'Maybe' a
-- @
--
-- @
-- 'Data.Foldable.find' ≡ 'findOf' 'folded'
-- 'ifindOf' o ≡ 'findOf' o '.' 'Indexed'
-- @
--
-- A simpler version that didn't permit indexing, would be:
--
-- @
-- 'findOf' :: 'AFold' ('Endo' ('Maybe' a)) s a -> (a -> 'Bool') -> s -> 'Maybe' a
-- 'findOf' o p = 'foldrOf' o (\a y -> if p a then 'Just' a else y) 'Nothing'
-- @
findOf :: FoldLike (Endo (Maybe a)) s a -> (a -> Bool) -> s -> Maybe a
findOf o f = foldrOf o (\a y -> if f a then Just a else y) Nothing
{-# INLINE findOf #-}

-- | The 'findMOf' function takes a 'Lens' (or 'Getter', 'Iso', 'Fold', or 'Traversal'),
-- a monadic predicate and a structure and returns in the monad the leftmost element of the structure
-- matching the predicate, or 'Nothing' if there is no such element.
--
-- >>>  findMOf each ( \x -> print ("Checking " ++ show x) >> return (even x)) (1,3,4,6)
-- "Checking 1"
-- "Checking 3"
-- "Checking 4"
-- Just 4
--
-- >>>  findMOf each ( \x -> print ("Checking " ++ show x) >> return (even x)) (1,3,5,7)
-- "Checking 1"
-- "Checking 3"
-- "Checking 5"
-- "Checking 7"
-- Nothing
--
-- @
-- 'findMOf' :: ('Monad' m, 'Getter' s a)     -> (a -> m 'Bool') -> s -> m ('Maybe' a)
-- 'findMOf' :: ('Monad' m, 'Fold' s a)       -> (a -> m 'Bool') -> s -> m ('Maybe' a)
-- 'findMOf' :: ('Monad' m, 'Iso'' s a)       -> (a -> m 'Bool') -> s -> m ('Maybe' a)
-- 'findMOf' :: ('Monad' m, 'Lens'' s a)      -> (a -> m 'Bool') -> s -> m ('Maybe' a)
-- 'findMOf' :: ('Monad' m, 'Traversal'' s a) -> (a -> m 'Bool') -> s -> m ('Maybe' a)
-- @
--
-- @
-- 'findMOf' 'folded' :: (Monad m, Foldable f) => (a -> m Bool) -> f a -> m (Maybe a)
-- 'ifindMOf' o ≡ 'findMOf' o '.' 'Indexed'
-- @
--
-- A simpler version that didn't permit indexing, would be:
--
-- @
-- 'findMOf' :: Monad m => 'AFold' ('Endo' (m ('Maybe' a))) s a -> (a -> m 'Bool') -> s -> m ('Maybe' a)
-- 'findMOf' o p = 'foldrOf' o (\a y -> p a >>= \x -> if x then return ('Just' a) else y) $ return 'Nothing'
-- @
findMOf :: Monad m => FoldLike (Endo (m (Maybe a))) s a -> (a -> m Bool) -> s -> m (Maybe a)
findMOf o f = foldrOf o (\a y -> f a >>= \r -> if r then return (Just a) else y) $ return Nothing
{-# INLINE findMOf #-}

-- | The 'lookupOf' function takes a 'Fold' (or 'Getter', 'Traversal',
-- 'Lens', 'Iso', etc.), a key, and a structure containing key/value pairs.
-- It returns the first value corresponding to the given key. This function
-- generalizes 'lookup' to work on an arbitrary 'Fold' instead of lists.
--
-- >>> lookupOf folded 4 [(2, 'a'), (4, 'b'), (4, 'c')]
-- Just 'b'
--
-- >>> lookupOf each 2 [(2, 'a'), (4, 'b'), (4, 'c')]
-- Just 'a'
--
-- @
-- 'lookupOf' :: 'Eq' k => 'Fold' s (k,v) -> k -> s -> 'Maybe' v
-- @
lookupOf :: Eq k => FoldLike (Endo (Maybe v)) s (k,v) -> k -> s -> Maybe v
lookupOf o k = foldrOf o (\(k',v) next -> if k == k' then Just v else next) Nothing
{-# INLINE lookupOf #-}
-}


