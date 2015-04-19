{-# OPTIONS_GHC -fno-warn-orphans #-}

-- | Conversion of Repa queries to JSON format for interfacing with
--   client systems.
-- 
--   Conversion is done by providing instances for the `ToJSON` and `FromJSON`
--   classes form the Aeson package.
--
module Data.Repa.Query.Convert.JSON
        (encode, toJSON, fromJSON, Result(..))
where
import Control.Monad
import Data.Char
import Data.List                                as L
import Data.Repa.Query.Graph
import Data.Repa.Query.Exp
import Data.Aeson                               as Aeson
import Data.Text                                (Text)
import qualified Data.Repa.Query.Format         as Format
import qualified Data.Text                      as T
import qualified Data.HashMap.Strict            as H


--------------------------------------------------------------------------------------------- Query
instance (ToJSON nF, ToJSON bV, ToJSON nV)
      => (ToJSON (Query a nF bV nV)) where
 toJSON xx
  = case xx of
        Query flow delim fields graph
         -> object [ "_type"    .= text "query"
                   , "out"      .= toJSON flow
                   , "delim"    .= toJSON delim
                   , "fields"   .= toJSON fields
                   , "graph"    .= toJSON graph ]


instance (FromJSON nF, FromJSON bV, FromJSON nV)
      => (FromJSON (Query () nF bV nV)) where
 parseJSON (Object hh)

        | Just (String "query") <- H.lookup "_type"  hh
        , Just jOut             <- H.lookup "out"    hh
        , Just jDelim           <- H.lookup "delim"  hh
        , Just jFields          <- H.lookup "fields" hh
        , Just jGraph           <- H.lookup "graph"  hh
        = do    out     <- parseJSON jOut
                delim   <- parseJSON jDelim
                fields  <- parseJSON jFields
                graph   <- parseJSON jGraph
                return  $ Query out delim fields graph

 parseJSON _ = mzero
 

--------------------------------------------------------------------------------------------- Graph
instance (ToJSON nF, ToJSON bV, ToJSON nV)
      => (ToJSON (Graph a nF bV nV)) where
 toJSON xx
  = case xx of
        Graph ns
         -> object [ "_type"    .= text "graph"
                   , "nodes"    .= toJSON ns ]

instance (FromJSON nF, FromJSON bV, FromJSON nV)
      => (FromJSON (Graph () nF bV nV)) where
 parseJSON (Object hh)

        | Just (String "graph") <- H.lookup "_type" hh
        , Just jNodes           <- H.lookup "nodes" hh
        = do    nodes  <- parseJSON jNodes
                return  $ Graph nodes 

 parseJSON _ = mzero


---------------------------------------------------------------------------------------------- Node
instance (ToJSON nF, ToJSON bV, ToJSON nV)
      => (ToJSON (Node a nF bV nV)) where
 toJSON xx
  = case xx of
        NodeSource s
         -> object [ "_type"    .= text "node"
                   , "node"     .= text "source"
                   , "source"   .= toJSON s ]

        NodeOp op
         -> object [ "_type"    .= text "node"
                   , "node"     .= text "op"
                   , "op"       .= toJSON op ]


instance (FromJSON nF, FromJSON bV, FromJSON nV)
      => (FromJSON (Node () nF bV nV)) where
 parseJSON (Object hh)

        | Just (String "node")   <- H.lookup "_type"   hh
        , Just (String "source") <- H.lookup "node"    hh
        , Just jSource           <- H.lookup "source"  hh
        = do    source  <- parseJSON jSource
                return  $ NodeSource source

        | Just (String "node")  <- H.lookup "_type"    hh
        , Just (String "op")    <- H.lookup "node"     hh
        , Just jOp              <- H.lookup "op"       hh
        = do    op      <- parseJSON jOp
                return  $ NodeOp op

 parseJSON _ = mzero


-------------------------------------------------------------------------------------------- FlowOp
instance (ToJSON nF, ToJSON bV, ToJSON nV)
      => (ToJSON (FlowOp a nF bV nV)) where
 toJSON xx
  = case xx of
        FopMapI fIn fOut fun
         -> object [ "_type"    .= text "fop"
                   , "fop"      .= text "mapi"
                   , "in"       .= toJSON fIn
                   , "out"      .= toJSON fOut
                   , "fun"      .= toJSON fun ]

        FopFilterI fIn fOut fun
         -> object [ "_type"    .= text "fop"
                   , "fop"      .= text "filteri"
                   , "in"       .= toJSON fIn
                   , "out"      .= toJSON fOut
                   , "fun"      .= toJSON fun ]

        FopFoldI fIn fOut fun z
         -> object [ "_type"    .= text "fop"
                   , "fop"      .= text "foldi"
                   , "in"       .= toJSON fIn
                   , "out"      .= toJSON fOut
                   , "fun"      .= toJSON fun 
                   , "neutral"  .= toJSON z ]

        FopFoldsI fLens fElems fOut fun z
         -> object [ "_type"    .= text "fop"
                   , "fop"      .= text "folds"
                   , "lens"     .= toJSON fLens
                   , "elems"    .= toJSON fElems
                   , "out"      .= toJSON fOut
                   , "fun"      .= toJSON fun 
                   , "neutral"  .= toJSON z ]

        FopGroupsI fIn fOut fun
         -> object [ "_type"    .= text "fop"
                   , "fop"      .= text "groupsi"
                   , "in"       .= toJSON fIn
                   , "out"      .= toJSON fOut
                   , "fun"      .= toJSON fun ]


instance (FromJSON nF, FromJSON bV, FromJSON nV)
       => FromJSON (FlowOp () nF bV nV) where
 parseJSON (Object hh)

        -- mapi
        | Just (String "fop")  <- H.lookup "_type"   hh
        , Just (String "mapi") <- H.lookup "fop"    hh
        , Just jIn             <- H.lookup "in"     hh
        , Just jOut            <- H.lookup "out"    hh
        , Just jFun            <- H.lookup "fun"    hh
        = do    fin     <- parseJSON jIn
                fout    <- parseJSON jOut
                fun     <- parseJSON jFun
                return  $  FopMapI fin fout fun

        -- filteri
        | Just (String "fop")   <- H.lookup "_type"  hh
        , Just (String "filteri") <- H.lookup "fop" hh
        , Just jIn             <- H.lookup "in"     hh
        , Just jOut            <- H.lookup "out"    hh
        , Just jFun            <- H.lookup "fun"    hh
        = do    fin     <- parseJSON jIn
                fout    <- parseJSON jOut
                fun     <- parseJSON jFun
                return  $  FopFilterI fin fout fun

        -- foldi
        | Just (String "fop")   <- H.lookup "_type"     hh
        , Just (String "foldi") <- H.lookup "fop"      hh
        , Just jIn              <- H.lookup "in"       hh
        , Just jOut             <- H.lookup "out"      hh
        , Just jFun             <- H.lookup "fun"      hh
        , Just jNeutral         <- H.lookup "neutral"  hh
        = do    fin     <- parseJSON jIn
                fout    <- parseJSON jOut
                fun     <- parseJSON jFun
                neutral <- parseJSON jNeutral
                return  $  FopFoldI fin fout fun neutral

        -- foldsi
        | Just (String "fop")    <- H.lookup "_type"    hh
        , Just (String "foldsi") <- H.lookup "fop"     hh
        , Just jLens             <- H.lookup "lens"    hh
        , Just jElems            <- H.lookup "elems"   hh
        , Just jOut              <- H.lookup "out"     hh
        , Just jFun              <- H.lookup "fun"     hh
        , Just jNeutral          <- H.lookup "neutral" hh
        = do    flens   <- parseJSON jLens
                felems  <- parseJSON jElems
                fout    <- parseJSON jOut
                fun     <- parseJSON jFun
                neutral <- parseJSON jNeutral
                return  $  FopFoldsI flens felems fout fun neutral

        -- groupsi
        | Just (String "fop")     <- H.lookup "_type"  hh
        , Just (String "groupsi") <- H.lookup "fop" hh
        , Just jIn              <- H.lookup "in"     hh
        , Just jOut             <- H.lookup "out"    hh
        , Just jFun             <- H.lookup "fun"    hh
        = do    fin     <- parseJSON jIn
                fout    <- parseJSON jOut
                fun     <- parseJSON jFun
                return  $  FopGroupsI fin fout fun

 parseJSON _ = mzero


-------------------------------------------------------------------------------------------- Source
instance (ToJSON nF)
       => ToJSON (Source a nF) where
 toJSON xx
  = case xx of
        SourceFile _ name delim fields fOut
         -> object [ "_type"    .= text "source"
                   , "source"   .= text "file"
                   , "name"     .= T.pack name
                   , "delim"    .= toJSON delim
                   , "fields"   .= toJSON fields
                   , "output"   .= toJSON fOut ]


instance  FromJSON nF
       => FromJSON (Source () nF) where
 parseJSON (Object hh)

        | Just (String "source") <- H.lookup "_type"  hh
        , Just (String "file")   <- H.lookup "source" hh
        , Just (String  name)    <- H.lookup "name"   hh
        , Just jDelim            <- H.lookup "delim"  hh
        , Just jFields           <- H.lookup "fields" hh
        , Just jOut              <- H.lookup "output" hh
        = do  delim   <- parseJSON jDelim
              fields  <- parseJSON jFields
              out     <- parseJSON jOut
              return  $ SourceFile () (T.unpack name) delim fields out

 parseJSON _ = mzero


----------------------------------------------------------------------------------------------- Exp
instance (ToJSON bV, ToJSON nV)
       => ToJSON (Exp a bV nV) where
 toJSON xx
  = case xx of
        -- literals
        XVal _ (VLit _ lit)
         -> let (name :: Text, val)     
                 = case lit of
                        LBool   b -> ("bool",   T.pack $ show b)
                        LWord   w -> ("word",   T.pack $ show w)
                        LInt    i -> ("int",    T.pack $ show i)
                        LFloat  f -> ("float",  T.pack $ show f)
                        LDouble d -> ("double", T.pack $ show d)
                        LString s -> ("string", T.pack s)

            in  object 
                   [ "_type"    .= text "exp"
                   , "exp"      .= text "lit"
                   , "lit"      .= name
                   , "value"    .= val ]

        -- lambdas
        XVal _ (VLam _ bV x)
         -> object [ "_type"    .= text "exp"
                   , "exp"      .= text "lam"
                   , "binder"   .= toJSON bV
                   , "body"     .= toJSON x ]

        -- variables
        XVar _ v
         -> object [ "_type"    .= text "exp"
                   , "exp"      .= text "var"
                   , "var"      .= toJSON v ]

        -- applications
        XApp _ xFun xArg
         -> object [ "_type"    .= text "exp"
                   , "exp"      .= text "app"
                   , "fun"      .= toJSON xFun
                   , "arg"      .= toJSON xArg ]

        -- operators
        XOp  _ sOp xsArgs
         -> object [ "_type"    .= text "exp"
                   , "exp"      .= text "sop"
                   , "sop"      .= nameOfScalarOp sOp
                   , "args"     .= toJSON xsArgs ]


instance (FromJSON bV, FromJSON nV)
       => FromJSON (Exp () bV nV) where
 parseJSON (Object hh)

        -- literals
        | Just (String "exp")   <- H.lookup "_type" hh
        , Just (String "lit")   <- H.lookup "exp"   hh
        , Just (String  lit)    <- H.lookup "lit"   hh
        , Just (String  value)  <- H.lookup "value" hh
        = case T.unpack lit of
                "bool"          -> return $ xBool   () $ read $ T.unpack value
                "word"          -> return $ xWord   () $ read $ T.unpack value
                "int"           -> return $ xInt    () $ read $ T.unpack value
                "float"         -> return $ xFloat  () $ read $ T.unpack value
                "double"        -> return $ xDouble () $ read $ T.unpack value
                "string"        -> return $ xString () $ T.unpack value
                _               -> mzero

        -- variables
        | Just (String "exp")   <- H.lookup "_type"  hh
        , Just (String "var")   <- H.lookup "exp"    hh
        , Just jName            <- H.lookup "var"    hh
        = do  name      <- parseJSON jName
              return $ XVar () name

        -- lambdas
        | Just (String "exp")   <- H.lookup "_type"  hh
        , Just (String "lam")   <- H.lookup "exp"    hh
        , Just jBinder          <- H.lookup "binder" hh
        , Just jBody            <- H.lookup "body"   hh
        = do  binder    <- parseJSON jBinder
              body      <- parseJSON jBody
              return $ XVal () (VLam () binder body)

        -- operators
        | Just (String "exp")   <- H.lookup "_type"  hh
        , Just (String "sop")   <- H.lookup "exp"    hh
        , Just (String ssop)    <- H.lookup "sop"    hh
        , Just jArgs            <- H.lookup "args"   hh
        , Just sop              <- scalarOpOfName (T.unpack ssop)
        = do  args      <- parseJSON jArgs
              return $ XOp  () sop args

 parseJSON _ = mzero


------------------------------------------------------------------------------------------ ScalarOp
nameOfScalarOp :: ScalarOp -> String
nameOfScalarOp sop
 = case sop of
        SopNeg          -> "neg"
        SopAbs          -> "abs"
        SopSignum       -> "signum"
        SopAdd          -> "add"
        SopSub          -> "sub"
        SopMul          -> "mul"
        SopDiv          -> "div"
        SopEq           -> "eq"
        SopNeq          -> "neq"
        SopGt           -> "gt"
        SopGe           -> "ge"
        SopLt           -> "lt"
        SopLe           -> "le"
        SopProj i j     -> "proj" ++ show i ++ "_" ++ show j


scalarOpOfName :: String -> Maybe ScalarOp
scalarOpOfName ss
 | Just ds              <- L.stripPrefix "proj" ss
 , (ds1, '_' : ds2)     <- L.span isDigit ds
 , all isDigit ds1, length ds1 > 0
 , all isDigit ds2, length ds2 > 0
 = Just $ SopProj (read ds1) (read ds2)

 | otherwise
 = case ss of
        "neg"           -> Just $ SopNeg
        "abs"           -> Just $ SopAbs
        "signum"        -> Just $ SopSignum
        "add"           -> Just $ SopAdd
        "sub"           -> Just $ SopSub
        "mul"           -> Just $ SopMul
        "div"           -> Just $ SopDiv
        "eq"            -> Just $ SopEq
        "neq"           -> Just $ SopNeq
        "gt"            -> Just $ SopGt
        "ge"            -> Just $ SopGe
        "lt"            -> Just $ SopLt
        "le"            -> Just $ SopLe
        _               -> Nothing


-------------------------------------------------------------------------------------- Format.Row
instance ToJSON Format.Delim where
 toJSON rr
  = case rr of
        Format.Fixed
         -> object [ "_type"    .= text "delim"
                   , "delim"    .= text "fixed" ]

        Format.Lines
         -> object [ "_type"    .= text "delim"
                   , "delim"    .= text "lines" ]

        Format.LinesSep c
         -> object [ "_type"    .= text "delim"
                   , "delim"    .= text "sep"
                   , "sep"      .= T.pack [c] ]

instance FromJSON Format.Delim where
 parseJSON (Object hh)
        | Just (String "delim")  <- H.lookup "_type"  hh
        , Just (String "fixed")  <- H.lookup "delim"  hh
        =       return $ Format.Fixed

        | Just (String "delim")  <- H.lookup "_type"  hh
        , Just (String "lines")  <- H.lookup "delim"  hh
        =       return $ Format.Lines

        | Just (String "delim")  <- H.lookup "_type"  hh
        , Just (String "sep")    <- H.lookup "delim"  hh
        , Just (String sep)      <- H.lookup "sep"    hh
        , [c]                    <- T.unpack sep
        =       return $ Format.LinesSep c

 parseJSON _ = mzero


-------------------------------------------------------------------------------------- Format.Field
instance ToJSON   Format.FieldBox where
 toJSON (Format.FieldBox ff)
        = toJSON ff

instance ToJSON (Format.Field a) where
 toJSON ff
        = object  [ "_type"     .= text "field"
                  , "field"     .= T.pack (Format.showField ff) ]


instance FromJSON Format.FieldBox where
 parseJSON (Object hh)
        | Just (String "field") <- H.lookup "_type" hh
        , Just (String ff)      <- H.lookup "field" hh
        , Just f                <- Format.readField (T.unpack ff)
        = return f

 parseJSON _ = mzero


---------------------------------------------------------------------------------------------------
text :: Text -> Text
text x = x 

