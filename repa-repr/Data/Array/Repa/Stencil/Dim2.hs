--   This is specialised for stencils up to 7x7.
--   Due to limitations in the GHC optimiser, using larger stencils doesn't work, and will yield `error`
--   at runtime. We can probably increase the limit if required -- just ask.
--
--   The focus of the stencil is in the center of the 7x7 tile, which has coordinates (0, 0).
--   All coefficients in the stencil must fit in the tile, so they can be given X,Y coordinates up to
--   +/- 3 positions. The stencil can be any shape, and need not be symmetric -- provided it fits in the 7x7 tile.
--
module Data.Array.Repa.Stencil.Dim2
	( 
	-- * Stencil creation
	  makeStencil2, stencil2

	-- * Stencil operators
	, PC5, mapStencil2, forStencil2)
where
import Data.Array.Repa
import Data.Array.Repa.Repr.Cursored
import Data.Array.Repa.Repr.Partitioned
import Data.Array.Repa.Repr.Undefined
import Data.Array.Repa.Stencil.Base
import Data.Array.Repa.Stencil.Template


-- | A index into the flat array.
--   Should be abstract outside the stencil modules.
data Cursor
	= Cursor Int

type PC5 = P C (P D (P D (P D (P D X))))


-- Wrappers ---------------------------------------------------------------------------------------
-- | Like `mapStencil2` but with the parameters flipped.
forStencil2
        :: Repr r a
        => Boundary a
	-> Array r DIM2 a
	-> Stencil DIM2 a
	-> Array PC5 DIM2 a

{-# INLINE forStencil2 #-}
forStencil2 boundary arr stencil
	= mapStencil2 boundary stencil arr


---------------------------------------------------------------------------------------------------
-- | Apply a stencil to every element of a 2D array.
mapStencil2
        :: Repr r a
        => Boundary a		-- ^ How to handle the boundary of the array.
	-> Stencil DIM2 a	-- ^ Stencil to apply.
	-> Array r DIM2 a		-- ^ Array to apply stencil to.
	-> Array PC5 DIM2 a

{-# INLINE mapStencil2 #-}
mapStencil2 boundary stencil@(StencilStatic sExtent _zero _load) arr
 = let	sh                       = extent arr
        (_ :. aHeight :. aWidth) = sh
	(_ :. sHeight :. sWidth) = sExtent

	sHeight2	= sHeight `div` 2
	sWidth2		= sWidth  `div` 2

	-- minimum and maximum indicies of values in the inner part of the image.
	!xMin		= sWidth2
	!yMin		= sHeight2
	!xMax		= aWidth  - sWidth2  - 1
	!yMax		= aHeight - sHeight2 - 1

	{-# INLINE inInternal #-}
	inInternal (Z :. y :. x)
		=  x >= xMin && x <= xMax
		&& y >= yMin && y <= yMax

	{-# INLINE inBorder #-}
	inBorder 	= not . inInternal

	-- Cursor functions ----------------
	{-# INLINE makec #-}
	makec (Z :. y :. x)
	 = Cursor (x + y * aWidth)

	{-# INLINE shiftc #-}
	shiftc ix (Cursor off)
	 = Cursor
	 $ case ix of
		Z :. y :. x	-> off + y * aWidth + x

	{-# INLINE getInner' #-}
	getInner' cur
	 = unsafeAppStencilCursor2 shiftc stencil arr cur

	{-# INLINE getBorder' #-}
	getBorder' ix
	 = case boundary of
		BoundConst c	-> c
		BoundClamp 	-> unsafeAppStencilCursor2_clamp addDim stencil
					arr ix

        {-# INLINE arrInternal #-}
        arrInternal     = makeCursored (extent arr) makec shiftc getInner' 
        
        {-# INLINE arrBorder #-}
        arrBorder       = fromFunction (extent arr) getBorder'

   in
    --  internal region
        APart sh (Range (Z :. yMin :. xMin)         (Z :. yMax :. xMax )    inInternal) arrInternal

    --  border regions
    $   APart sh (Range (Z :. 0        :. 0)        (Z :. yMin -1        :. aWidth - 1) inBorder)   arrBorder
    $   APart sh (Range (Z :. yMax + 1 :. 0)        (Z :. aHeight - 1    :. aWidth - 1) inBorder)   arrBorder
    $   APart sh (Range (Z :. yMin     :. 0)        (Z :. yMax           :. xMin - 1)   inBorder)   arrBorder
    $   APart sh (Range (Z :. yMin     :. xMax + 1) (Z :. yMax           :. aWidth - 1) inBorder)   arrBorder
    $   AUndefined sh


unsafeAppStencilCursor2
	:: Repr r a
	=> (DIM2 -> Cursor -> Cursor)
	-> Stencil DIM2 a
	-> Array r DIM2 a
	-> Cursor
	-> a

{-# INLINE unsafeAppStencilCursor2 #-}
unsafeAppStencilCursor2 shift
        (StencilStatic sExtent zero loads)
	arr cur0

	| _ :. sHeight :. sWidth	<- sExtent
	, sHeight <= 7, sWidth <= 7
	= let
		-- Get data from the manifest array.
		{-# INLINE getData #-}
		getData (Cursor cur) = arr `unsafeLinearIndex` cur

		-- Build a function to pass data from the array to our stencil.
		{-# INLINE oload #-}
		oload oy ox
		 = let	!cur' = shift (Z :. oy :. ox) cur0
		   in	loads (Z :. oy :. ox) (getData cur')

	   in	template7x7 oload zero


-- | Like above, but clamp out of bounds array values to the closest real value.
unsafeAppStencilCursor2_clamp
	:: forall r a
	.  Repr r a
	=> (DIM2 -> DIM2 -> DIM2)
	-> Stencil DIM2 a
	-> Array r DIM2 a
	-> DIM2
	-> a

{-# INLINE unsafeAppStencilCursor2_clamp #-}
unsafeAppStencilCursor2_clamp shift
	   (StencilStatic sExtent zero loads)
	   arr cur

	| _ :. sHeight :. sWidth	<- sExtent
	, _ :. aHeight :. aWidth	<- extent arr
	, sHeight <= 7, sWidth <= 7
	= let
		-- Get data from the manifest array.
		{-# INLINE getData #-}
		getData :: DIM2 -> a
		getData (Z :. y :. x)
		 = wrapLoadX x y

		-- TODO: Inlining this into above makes SpecConstr choke
		wrapLoadX :: Int -> Int -> a
		wrapLoadX !x !y
		 | x < 0	= wrapLoadY 0      	 y
		 | x >= aWidth	= wrapLoadY (aWidth - 1) y
		 | otherwise    = wrapLoadY x y

		{-# INLINE wrapLoadY #-}
		wrapLoadY :: Int -> Int -> a
		wrapLoadY !x !y
		 | y <  0	= loadXY x 0
		 | y >= aHeight = loadXY x (aHeight - 1)
		 | otherwise    = loadXY x y

		{-# INLINE loadXY #-}
		loadXY :: Int -> Int -> a
		loadXY !x !y
		 = arr `unsafeIndex` (Z :. y :.  x)

		-- Build a function to pass data from the array to our stencil.
		{-# INLINE oload #-}
		oload oy ox
		 = let	!cur' = shift (Z :. oy :. ox) cur
		   in	loads (Z :. oy :. ox) (getData cur')

	   in	template7x7 oload zero



-- | Data template for stencils up to 7x7.
template7x7
	:: (Int -> Int -> a -> a)
	-> a -> a

{-# INLINE template7x7 #-}
template7x7 f zero
 	= f (-3) (-3)  $  f (-3) (-2)  $  f (-3) (-1)  $  f (-3)   0  $  f (-3)   1  $  f (-3)   2  $ f (-3) 3
 	$ f (-2) (-3)  $  f (-2) (-2)  $  f (-2) (-1)  $  f (-2)   0  $  f (-2)   1  $  f (-2)   2  $ f (-2) 3
	$ f (-1) (-3)  $  f (-1) (-2)  $  f (-1) (-1)  $  f (-1)   0  $  f (-1)   1  $  f (-1)   2  $ f (-1) 3
	$ f   0  (-3)  $  f   0  (-2)  $  f   0  (-1)  $  f   0    0  $  f   0    1  $  f   0    2  $ f   0  3
	$ f   1  (-3)  $  f   1  (-2)  $  f   1  (-1)  $  f   1    0  $  f   1    1  $  f   1    2  $ f   1  3
	$ f   2  (-3)  $  f   2  (-2)  $  f   2  (-1)  $  f   2    0  $  f   2    1  $  f   2    2  $ f   2  3
	$ f   3  (-3)  $  f   3  (-2)  $  f   3  (-1)  $  f   3    0  $  f   3    1  $  f   3    2  $ f   3  3
	$ zero

