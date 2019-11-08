module Data.Profunctor.Arrow where

import Control.Category
import Data.Profunctor
import Data.Profunctor.Misc
import Prelude hiding ((.), id)

infixr 3 ***

(***) :: Category p => Strong p => p a1 b1 -> p a2 b2 -> p (a1 , a2) (b1 , b2)
x *** y = first' x >>> parr swp >>> first' y >>> parr swp

infixr 2 +++

(+++) :: Category p => Choice p => p a1 b1 -> p a2 b2 -> p (a1 + a2) (b1 + b2)
x +++ y = left' x >>> parr swp' >>> left' y >>> parr swp'

infixr 3 &&&

(&&&) :: Category p => Strong p => p a b1 -> p a b2 -> p a (b1 , b2)
x &&& y = dimap fork id $ x *** y 

infixr 2 |||

(|||) :: Category p => Choice p => p a1 b -> p a2 b -> p (a1 + a2) b
x ||| y = pchoose id x y

infixr 0 $$$

($$$) :: Category p => Strong p => p a (b -> c) -> p a b -> p a c
($$$) f x = dimap fork apply (f *** x)

pselect :: Category p => Choice p => ((b1 + b2) -> b) -> p a b1 -> p a b2 -> p a b
pselect f x y = dimap Left f $ x +++ y

pchoose :: Category p => Choice p => (a -> (a1 + a2)) -> p a1 b -> p a2 b -> p a b
pchoose f x y = dimap f join $ x +++ y
