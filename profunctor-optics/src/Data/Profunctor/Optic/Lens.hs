module Data.Profunctor.Optic.Lens where

import Data.Profunctor.Optic.Iso
import Data.Profunctor.Optic.Prelude
import Data.Profunctor.Optic.Type
import Data.Void (Void, absurd)
import Foreign.C.Types
import GHC.IO.Exception
import System.IO
import qualified Data.Bifunctor as B
import qualified Control.Foldl as F

import Data.Profunctor.Strong (Pastro(..), Tambara(..))
-- $setup
-- >>> :set -XNoOverloadedStrings
-- >>> :m + Control.Exception
-- >>> :m + Data.Profunctor.Optic

---------------------------------------------------------------------
-- 'Lens' 
---------------------------------------------------------------------

-- | Build a 'Lens' from a getter and setter.
--
-- \( \quad \mathsf{Lens}\;S\;A = \exists C, S \cong C \times A \)
--
-- /Caution/: In order for the generated optic to be well-defined,
-- you must ensure that the input functions satisfy the following
-- properties:
--
-- * @sa (sbt s a) ≡ a@
--
-- * @sbt s (sa s) ≡ s@
--
-- * @sbt (sbt s a1) a2 ≡ sbt s a2@
--
-- More generally, a profunctor optic must be monoidal as a natural 
-- transformation:
-- 
-- * @o id ≡ id@
--
-- * @o ('Data.Profunctor.Composition.Procompose' p q) ≡ 'Data.Profunctor.Composition.Procompose' (o p) (o q)@
--
-- See 'Data.Profunctor.Optic.Property'.
--
lens :: (s -> a) -> (s -> b -> t) -> Lens s t a b
lens sa sbt = dimap (id &&& sa) (uncurry sbt) . second'

-- | Build a 'Relens' from a getter and setter. 
--
-- * @relens f g ≡ \f g -> re (lens f g)@
--
-- * @review $ relens f g ≡ f@
--
-- * @set . re $ re (lens f g) ≡ g@
--
-- A 'Relens' is a 'Review', so you can specialise types to obtain:
--
-- @ 'review' :: 'Relens'' s a -> a -> s @
--
relens :: (b -> s -> a) -> (b -> t) -> Relens s t a b
relens bsa bt = unsecond . dimap (uncurry bsa) (id &&& bt)

-- | Transform a Van Laarhoven lens into a profunctor lens.
--
lensing :: (forall f. Functor f => (a -> f b) -> s -> f t) -> Lens s t a b
lensing o = dimap ((info &&& values) . o (flip PStore id)) (uncurry id . swp) . first'

-- | Build a 'Lens' from its free tensor representation.
--
matching :: (s -> (c , a)) -> ((c , b) -> t) -> Lens s t a b
matching sca cbt = dimap sca cbt . second'

-- | Build a 'Relens' from its free tensor representation.
--
rematching :: ((c , s) -> a) -> (b -> (c , t)) -> Relens s t a b
rematching csa bct = unsecond . dimap csa bct

-- | Lift a 'Lens' into a 'Pastro'.
--
toPastro :: ALens s t a b -> p a b -> Pastro p s t
toPastro o p = withLens o $ \sa sbt -> Pastro (uncurry sbt . swp) p (\s -> (sa s, s))

-- | Lift a 'Lens' into a 'Tambara'.
--
toTambara :: Strong p => ALens s t a b -> p a b -> Tambara p s t
toTambara o p = withLens o $ \sa sbt -> Tambara (first . lens sa sbt $ p)

-- | Lift a 'Lens'' into a Moore machine.
--
foldingl :: ALens s s a b -> s -> F.Fold b a
foldingl o s = withLens o $ \sa sbs -> F.Fold sbs s sa

-- | TODO: Document
--
cloneLens :: ALens s t a b -> Lens s t a b
cloneLens o = withLens o lens 

-- | TODO: Document
--
cloneRelens :: ARelens s t a b -> Relens s t a b
cloneRelens o = withRelens o relens 

---------------------------------------------------------------------
-- 'LensRep'
---------------------------------------------------------------------

-- | The `LensRep` profunctor precisely characterizes a 'Lens'.
--
data LensRep a b s t = LensRep (s -> a) (s -> b -> t)

type ALens s t a b = Optic (LensRep a b) s t a b

type ALens' s a = ALens s s a a

instance Profunctor (LensRep a b) where
  dimap f g (LensRep sa sbt) = LensRep (sa . f) (\s -> g . sbt (f s))

instance Strong (LensRep a b) where
  first' (LensRep sa sbt) =
    LensRep (\(a, _) -> sa a) (\(s, c) b -> (sbt s b, c))

  second' (LensRep sa sbt) =
    LensRep (\(_, a) -> sa a) (\(c, s) b -> (c, sbt s b))

instance Sieve (LensRep a b) (PStore a b) where
  sieve (LensRep sa sbt) s = PStore (sa s) (sbt s)

instance Representable (LensRep a b) where
  type Rep (LensRep a b) = PStore a b

  tabulate f = LensRep (\s -> info (f s)) (\s -> values (f s))

data RelensRep a b s t = RelensRep (b -> s -> a) (b -> t)

type ARelens s t a b = Optic (RelensRep a b) s t a b

instance Profunctor (RelensRep a b) where
  dimap f g (RelensRep bsa bt) = RelensRep (\b s -> bsa b (f s)) (g . bt)

instance Costrong (RelensRep a b) where
  unfirst (RelensRep baca bbc) = RelensRep (curry foo) (forget2 $ bbc . fst)
    where foo = uncurry baca . shuffle . B.second undefined . swp --TODO: B.second bbc
          shuffle (x,(y,z)) = (y,(x,z))

---------------------------------------------------------------------
-- Primitive operators
---------------------------------------------------------------------

-- | Extract the two functions that characterize a 'Lens'.
--
withLens :: ALens s t a b -> ((s -> a) -> (s -> b -> t) -> r) -> r
withLens o f = case o (LensRep id (flip const)) of LensRep x y -> f x y

-- | Extract the two functions that characterize a 'Relens'.
--
withRelens :: ARelens s t a b -> ((b -> s -> a) -> (b -> t) -> r) -> r
withRelens l f = case l (RelensRep (flip const) id) of RelensRep x y -> f x y

-- | Analogous to @(***)@ from 'Control.Arrow'
--
pairing :: Lens s1 t1 a1 b1 -> Lens s2 t2 a2 b2 -> Lens (s1 , s2) (t1 , t2) (a1 , a2) (b1 , b2)
pairing = paired

-- | TODO: Document
--
lens2 :: (s -> a) -> (s -> b -> t) -> Lens (c, s) (d, t) (c, a) (d, b)
lens2 f g = between runPaired Paired (lens f g)

---------------------------------------------------------------------
-- Common lenses 
---------------------------------------------------------------------

-- | TODO: Document
--
first :: Lens (a , c) (b , c) a b
first = first'

-- | TODO: Document
--
second :: Lens (c , a) (c , b) a b
second = second'

-- | TODO: Document
--
refirst :: Relens a b (a , c) (b , c)
refirst = unfirst

-- | TODO: Document
--
resecond :: Relens a b (c , a) (c , b)
resecond = unsecond

-- | There is a `Unit` in everything.
--
unit :: Lens' a ()
unit = lens (const ()) const

-- | There is everything in a `Void`.
--
void :: Lens' Void a
void = lens absurd const

-- | TODO: Document
--
ix :: Eq k => k -> Lens' (k -> v) v
ix k = lens ($ k) (\g v' x -> if (k == x) then v' else g x)

----------------------------------------------------------------------------------------------------
-- IO Exceptions
----------------------------------------------------------------------------------------------------

-- | Where the error happened.
--
location :: Lens' IOException String
location = lens ioe_location $ \s e -> s { ioe_location = e }

-- | Error type specific information.
--
description :: Lens' IOException String
description = lens ioe_description $ \s e -> s { ioe_description = e }

-- | The handle used by the action flagging this error.
-- 
handle :: Lens' IOException (Maybe Handle)
handle = lens ioe_handle $ \s e -> s { ioe_handle = e }

-- | 'fileName' the error is related to.
--
fileName :: Lens' IOException (Maybe FilePath)
fileName = lens ioe_filename $ \s e -> s { ioe_filename = e }

-- | 'errno' leading to this error, if any.
--
errno :: Lens' IOException (Maybe CInt)
errno = lens ioe_errno $ \s e -> s { ioe_errno = e }

errorType :: Lens' IOException IOErrorType
errorType = lens ioe_type $ \s e -> s { ioe_type = e }