{-# LANGUAGE FlexibleInstances, ScopedTypeVariables #-}
{-# OPTIONS -fno-warn-orphans #-}

-- | Reading and writing Repa arrays as binary files.
module Data.Array.Repa.IO.Binary
        ( readArrayFromStorableFile
        , writeArrayToStorableFile)
where
import Foreign.Storable
import Foreign.Ptr
import Foreign.ForeignPtr
import Foreign.Marshal.Alloc
import System.IO
import Data.Array.Repa                  as R
import Data.Array.Repa.Repr.ForeignPtr  as R
import Prelude                          as P
import Control.Monad


-- | Read an array from a file.
--   Data appears in host byte order.
--   If the file size does match the provided shape then `error`.
readArrayFromStorableFile 
        :: forall a sh
        .  (Shape sh, Storable a)
        => FilePath 
        -> sh
        -> IO (Array F sh a)

readArrayFromStorableFile filePath sh
 = do
        -- Determine number of bytes per element.
        let (fake   :: a)               = undefined
        let (bytes1 :: Integer)         = fromIntegral $ sizeOf fake

        -- Determine how many elements the whole file will give us.
        h :: Handle     <- openBinaryFile filePath ReadMode
        bytesTotal      <- hFileSize h

        let lenTotal      =  bytesTotal `div` bytes1
        let bytesExpected =  bytes1 * lenTotal
        
        when (bytesTotal /= bytesExpected)
         $ error $ unlines
                ["Data.Array.Repa.IO.Binary.readArrayFromStorableFile: not a whole number of elements in file"
                , "element length = " P.++ show bytes1
                , "file size      = " P.++ show bytesTotal
                , "slack space    = " P.++ show (bytesTotal `mod` bytes1) ]
         
        let bytesTotal' = fromIntegral bytesTotal
        buf :: Ptr a    <- mallocBytes bytesTotal' 
        bytesRead       <- hGetBuf h buf bytesTotal'
        when (bytesTotal' /= bytesRead)
         $ error "Data.Array.Repa.IO.Binary.readArrayFromStorableFile: read failed"

        hClose h
        fptr     <- newForeignPtr finalizerFree buf        

        -- Converting the foreign ptr like this means that the array
        -- elements are used directly from the buffer, and not copied.
        let arr  =  R.fromForeignPtr sh fptr

        return   $  arr


-- | Write an array to a file.
--   Data appears in host byte order.
writeArrayToStorableFile
        :: forall sh a r
        .  (Shape sh, Source r a, Storable a)
        => FilePath 
        -> Array r sh a
        -> IO ()

writeArrayToStorableFile filePath arr
 = do   let bytes1      = sizeOf (arr R.! R.zeroDim)
        let bytesTotal  = bytes1 * (R.size $ R.extent arr)
        
        buf :: Ptr a    <- mallocBytes bytesTotal
        fptr            <- newForeignPtr finalizerFree buf        
        R.computeIntoP fptr (delay arr)
        
        h <- openBinaryFile filePath WriteMode
        hPutBuf h buf bytesTotal 
        hClose h
