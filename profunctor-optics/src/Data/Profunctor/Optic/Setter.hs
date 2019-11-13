{-# LANGUAGE DeriveFunctor #-}

module Data.Profunctor.Optic.Setter where

import Control.Applicative (liftA)
import Control.Exception (Exception(..), SomeException)
import Control.Monad.Reader as Reader hiding (lift)
import Control.Monad.Writer as Writer hiding (lift)
import Data.Foldable (Foldable, foldMap)
import Data.Profunctor.Optic.Iso (PStore(..))
import Data.Profunctor.Optic.Prelude
import Data.Profunctor.Optic.Type
import Data.Semiring
import qualified Control.Exception as Ex

---------------------------------------------------------------------
-- Setter
---------------------------------------------------------------------

-- | Promote a <http://conal.net/blog/posts/semantic-editor-combinators semantic editor combinator> to a modify-only optic.
--
-- To demote an optic to a semantic edit combinator, use the section @(l %~)@ or @over l@.
--
-- >>> [("The",0),("quick",1),("brown",1),("fox",2)] & setter map . first %~ length
-- [(3,0),(5,1),(5,1),(3,2)]
--
-- /Caution/: In order for the generated family to be well-defined, you must ensure that the two functor laws hold:
--
-- * @sec id ≡ id@
--
-- * @sec f . sec g ≡ sec (f . g)@
--
-- See 'Data.Profunctor.Optic.Property'.
--
setter :: ((a -> b) -> s -> t) -> Setter s t a b
setter sec = dimap (flip PStore id) (\(PStore s ab) -> sec ab s) . lift collect

-- | Every 'Grate' is a 'Setter'.
--
closing :: (((s -> a) -> b) -> t) -> Setter s t a b
closing sabt = setter $ \ab s -> sabt $ \sa -> ab (sa s)

infixl 6 %

-- | Sum two SECs
--
(%) :: Setter' a a -> Setter' a a -> Setter' a a
(%) f g = setter $ \h -> (f %~ h) . (g %~ h)

-- >>> toSemiring $ zero % one :: Int
-- 1
-- >>> toSemiring $ zero . one :: Int
-- 0
toSemiring :: Monoid a => Semiring a => Setter' a a -> a
toSemiring a = over a (unit <>) mempty

fromSemiring :: Monoid a => Semiring a => a -> Setter' a a
fromSemiring a = setter $ \ f y -> a >< f mempty <> y

---------------------------------------------------------------------
-- Primitive operators
---------------------------------------------------------------------

-- | Modify the target of a 'Lens' or all the targets of a 'Setter' or 'Traversal'.
--
-- @ 'over' l 'id' ≡ 'id' @
--
-- @
-- 'over' l f '.' 'over' l g ≡ 'over' l (f '.' g)
-- @
--
-- >>> over mapped f (over mapped g [a,b,c]) == over mapped (f . g) [a,b,c]
-- True
--
-- >>> over mapped f (Just a)
-- Just (f a)
--
-- >>> over mapped (*10) [1,2,3]
-- [10,20,30]
--
-- >>> over first f (a,b)
-- (f a,b)
--
-- >>> over first show (10,20)
-- ("10",20)
--
-- @
-- 'fmap' ≡ 'over' 'mapped'
-- 'setter' '.' 'over' ≡ 'id'
-- 'over' '.' 'setter' ≡ 'id'
-- @
--
-- @ 'over' ('cayley' a) ('Data.Semiring.unit' <>) 'Data.Monoid.mempty' ≡ a @
--
-- @
-- over :: Setter s t a b -> (a -> r) -> s -> r
-- over :: Monoid r => Fold s t a b -> (a -> r) -> s -> r
-- @
--
over :: Optic (->) s t a b -> (a -> b) -> s -> t
over = id

-- | TODO: Document
--
reover :: Optic (Re (->) a b) s t a b -> (t -> s) -> (b -> a)
reover = re

---------------------------------------------------------------------
-- Derived operators
---------------------------------------------------------------------

infixr 4 %~

-- | TODO: Document
--
(%~) :: Optic (->) s t a b -> (a -> b) -> s -> t
(%~) = id
{-# INLINE (%~) #-}

infixr 4 .~

-- | TODO: Document
--
(.~) :: Optic (->) s t a b -> b -> s -> t
(.~) = set
{-# INLINE (.~) #-}

-- | Set all referenced fields to the given value.
--
-- @ set l y (set l x a) ≡ set l y a @
--
set :: Optic (->) s t a b -> b -> s -> t
set o b = o (const b)

---------------------------------------------------------------------
-- Common setters
---------------------------------------------------------------------

-- | The unit SEC
--
one :: Setter' a a 
one = setter id

-- | The zero SEC
--
zero :: Setter' a a
zero = setter $ const id

-- | Map contravariantly by setter the input of a 'Profunctor'.
--
--
-- The most common profunctor to use this with is @(->)@.
--
-- >>> (dom %~ f) g x
-- g (f x)
--
-- >>> (dom %~ show) length [1,2,3]
-- 7
--
-- >>> (dom %~ f) h x y
-- h (f x) y
--
-- Map setter the second arg of a function:
--
-- >>> (mapped . dom %~ f) h x y
-- h x (f y)
--
dom :: Profunctor p => Setter (p b r) (p a r) a b
dom = setter lmap
{-# INLINE dom #-}

-- | A grate accessing the codomain of a function.
--
-- @
-- cod @(->) == lowerGrate range
-- @
--
cod :: Profunctor p => Setter (p r a) (p r b) a b
cod = setter rmap

-- | SEC for monadically transforming a monadic value.
--
bound :: Monad m => Setter (m a) (m b) a (m b)
bound = setter (=<<)

-- | SEC on each value of a functor.
--
fmapped :: Functor f => Setter (f a) (f b) a b
fmapped = setter fmap

-- | TODO: Document
--
foldMapped :: Foldable f => Monoid m => Setter (f a) m a m
foldMapped = setter foldMap

-- | This 'setter' can be used to modify all of the values in an 'Applicative'.
--
-- @
-- 'liftA' ≡ 'setter' 'liftedA'
-- @
--
-- >>> setter liftedA f [a,b,c]
-- [f a,f b,f c]
--
-- >>> set liftedA b (Just a)
-- Just b
--
liftedA :: Applicative f => Setter (f a) (f b) a b
liftedA = setter liftA

-- | TODO: Document
--
liftedM :: Monad m => Setter (m a) (m b) a b
liftedM = setter liftM

-- | Set a value using an SEC.
--
sets :: Setter b (a -> c) a c
sets = setter const

-- | TODO: Document
--
zipped :: Setter (u -> v -> a) (u -> v -> b) a b
zipped = setter ((.)(.)(.))

-- | TODO: Document
--
modded :: (a -> Bool) -> Setter' (a -> b) b
modded p = setter $ \mods f a -> if p a then mods (f a) else f a

-- | Apply a function only when the given predicate holds.
--
-- See also 'Data.Profunctor.Optic.Traversal0.predicated' & 'Data.Profunctor.Optic.Prism.filtered'.
--
branched :: (a -> Bool) -> Setter' a a
branched p = setter $ \f a -> if p a then f a else a

-- | TODO: Document
--
reviewed :: Setter (b -> t) (((s -> a) -> b) -> t) s a
reviewed = setter $ \sa bt sab -> bt (sab sa)

-- | TODO: Document
--
composed :: Setter (s -> a) ((a -> b) -> s -> t) b t
composed = setter between

-- | This 'Setter' can be used to purely map over the 'Exception's an
-- arbitrary expression might throw; it is a variant of 'mapException' in
-- the same way that 'mapped' is a variant of 'fmap'.
--
-- > 'mapException' ≡ 'over' 'exception'
--
-- This view that every Haskell expression can be regarded as carrying a bag
-- of 'Exception's is detailed in “A Semantics for Imprecise Exceptions” by
-- Peyton Jones & al. at PLDI ’99.
--
-- The following maps failed assertions to arithmetic overflow:
--
-- >>> handleOf overflow (\_ -> return "caught") $ assert False (return "uncaught") & (exmapped %~ \ (AssertionFailed _) -> Overflow)
-- "caught"
-- 
exmapped :: Exception e0 => Exception e1 => Setter s s e0 e1
exmapped = setter Ex.mapException

-- | A type restricted version of 'mappedException'. 
--
-- This function avoids the type ambiguity in the input 'Exception' when using 'set'.
--
-- The following maps any exception to arithmetic overflow:
--
-- >>> handleOf overflow (\_ -> return "caught") $ assert False (return "uncaught") & (exmapped' .~ Overflow)
-- "caught"
--
exmapped' :: Exception e => Setter s s SomeException e
exmapped' = exmapped