{-# LANGUAGE RecordWildCards #-}
-- Signature of correct computation
module Sonic.Signature where

import Protolude
import Sonic.SRS
import Crypto.Random (MonadRandom)
import Pairing.CyclicGroup (AsInteger(..))
import Pairing.Group
import Bulletproofs.ArithmeticCircuit
import Math.Polynomial.Laurent
import Sonic.Utils as Utils
import Sonic.Constraints
import Sonic.CommitmentScheme

data HscProof f = HscProof
  { hscS :: [G1]
  , hscW :: [(f, G1)]
  , hscQ :: [(f, G1)]
  , hscQz :: G1
  , hscC :: G1
  , hscU :: f
  , hscZ :: f
  }

-- Helper protocol
hscP
  :: (Num f, Eq f, Fractional f, AsInteger f, MonadRandom m)
  => SRS
  -> GateWeights f
  -> f
  -> f
  -> [f]
  -> m (HscProof f)
hscP srs@SRS{..} weights alpha x ys = do
  let ss = (\yi -> commitPoly srs d alpha x (evalOnY yi (sPoly weights))) <$> ys
  -- Random oracle
  u <- Utils.random
  let suX = evalOnX u (sPoly weights)
      commit = commitPoly srs d alpha x suX
      -- <> (g1 `expn` (evalLaurent x suX))
      sW = zipWith (\yi si -> openPoly srs si x u (evalOnY yi (sPoly weights))) ys ss
      sQ = (\yi -> openPoly srs commit x yi suX) <$> ys
  -- Random oracle
  z <- Utils.random
  let (suz, qz) = openPoly srs commit x z suX
  pure HscProof
          { hscS = ss
          , hscW = sW
          , hscQ = sQ
          , hscQz = qz
          , hscC = commit
          , hscU = u
          , hscZ = z
          }
  where
    m = length ys

hscV
  :: (Num f, Eq f, Fractional f, AsInteger f)
  => SRS
  -> [f]
  -> GateWeights f
  -> HscProof f
  -> Bool
hscV srs@SRS{..} ys weights proof@HscProof{..}
  = let sz = evalLaurent (evalOnY hscZ (sPoly weights)) hscU
    in and
        $ pcV srs d hscC hscZ (sz, hscQz)
        : (zipWith (\sj (wsj, wj) -> pcV srs d sj hscU (wsj, wj)) hscS hscW
        ++ zipWith (\yj (wsj, wj) -> pcV srs d hscC yj (wsj, wj)) ys hscQ)



