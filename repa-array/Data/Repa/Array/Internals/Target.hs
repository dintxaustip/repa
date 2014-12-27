
module Data.Repa.Array.Internals.Target
        ( Target    (..)
        , fromList
        , vfromList)
where
import Data.Repa.Array.Internals.Bulk   as R
import Data.Repa.Array.Internals.Shape  as R
import Data.Repa.Array.Internals.Index  as R
import System.IO.Unsafe
import Control.Monad
import Prelude                          as P


-- Target ---------------------------------------------------------------------
-- | Class of manifest array representations that can be constructed 
--   in a random-access manner.
class Target r e where

 -- | Mutable buffer for some array representation.
 data Buffer r e

 -- | Allocate a new mutable buffer of the given size.
 --
 --   UNSAFE: The integer must be positive, but this is not checked.
 unsafeNewBuffer    :: Int -> IO (Buffer r e)

 -- | Write an element into the mutable buffer.
 -- 
 --   UNSAFE: The index bounds are not checked.
 unsafeWriteBuffer  :: Buffer r e -> Int -> e -> IO ()

 -- | O(1). Yield a slice of the buffer without copying.
 --
 --   UNSAFE: The given starting position and length must be within the bounds
 --   of the of the source buffer, but this is not checked.
 unsafeSliceBuffer  :: Int -> Int -> Buffer r e -> IO (Buffer r e)
        -- TODO: cannot use existing load functions on a windowed buffer,
        --  because we lose the linear indexing.

 -- | O(1). Freeze a mutable buffer into an immutable Repa array.
 --
 --   UNSAFE: If the buffer is mutated further then the result of reading from
 --           the returned array will be non-deterministic.
 unsafeFreezeBuffer :: Shape sh => sh  -> Buffer r e -> IO (Array r sh e)

 -- | Ensure the array is still live at this point.
 --   Sometimes needed when the mutable buffer is a ForeignPtr with a finalizer.
 touchBuffer        :: Buffer r e -> IO ()


-- | O(length src). Construct an array from a list of elements, and give it the
--   provided shape. The `size` of the provided shape must match the
--   length of the list, else `Nothing`.
fromList  :: (Shape sh, Target r a)
          => sh -> [a] -> Maybe (Array r sh a)
fromList sh xx
 = unsafePerformIO
 $ do   let !len = P.length xx
        if   len /= size sh
         then return Nothing
         else do
                mvec    <- unsafeNewBuffer len
                zipWithM_ (unsafeWriteBuffer mvec) [0..] xx
                arr     <- unsafeFreezeBuffer sh mvec
                return $ Just arr
{-# NOINLINE fromList #-}


-- | O(length src). Construct a vector from a list.
vfromList :: Target r a => [a] -> Vector r a
vfromList xx
 = let  !len     = P.length xx 
        Just arr = fromList (Z :. len) xx
   in   arr
{-# NOINLINE vfromList #-}
