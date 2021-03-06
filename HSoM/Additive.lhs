%-*- mode: Latex; abbrev-mode: true; auto-fill-function: do-auto-fill -*-

%include lhs2TeX.fmt
%include myFormat.fmt

\out{
\begin{code}
-- This code was automatically generated by lhs2tex --code, from the file 
-- HSoM/Additive.lhs.  (See HSoM/MakeCode.bat.)

\end{code}
}

\chapter{Additive Synthesis}
\label{ch:additive}

\begin{code}
{-# LANGUAGE Arrows #-}

module Euterpea.Music.Signal.Additive where

import Euterpea
import Control.Arrow ((>>>),(<<<),arr)
\end{code}

\out{
{-# LANGUAGE Arrows, TemplateHaskell, BangPatterns, 
             ExistentialQuantification, FlexibleContexts, 
             FunctionalDependencies, ScopedTypeVariables #-}
}

\emph{Additive synthesis} is, conceptually at least, the simplest of
many sound synthesis techniques.  Simply put, the idea is to add
signals (usually sine waves of differing amplitudes, frequencies and
phases) together to form a sound of interest.  It is based on
Fourier's theorem as discussed in the previous chapter, and indeed is
sometimes called \emph{Fourier synthesis}.  

%% We discuss additive synthesis in this chapter, in theory and
%% practice, including the notion of \emph{time-varying} additive
%% synthesis.

\section{Preliminaries}

When doing pure additive synthesis it is often convenient to work with
a \emph{list of signal sources} whose elements are eventually summed
together to form a result.  To facilitate this, we define a few
auxiliary functions, as shown in Figure~\ref{fig:foldSF}.

|constSF s sf| simply lifts the value |s| to the signal function
level, and composes that with |sf|, thus yielding a signal source.

|foldSF f b sfs| is analogous to |foldr| for lists: it returns the
signal source |b| if the list is empty, and otherwise uses |f| to
combine the results, from the right.  In other words, if |sfs| has the
form:
\begin{spec}
sf1 : sf2 : ... : sfn : []
\end{spec}
then the result will be:
\begin{spec}
proc () -> do
  s1  <- sf1  -< ()
  s2  <- sf2  -< ()
  ...
  sn  <- sfn  -< ()
  outA -< f s1 (f s2 ( ... (f sn b)))
\end{spec}

\begin{figure}
\begin{code}
constSF :: Clock c => a -> SigFun c a b -> SigFun c () b
constSF s sf = constA s >>> sf

-- foldSF :: Clock c => (a -> b -> b) -> b -> [SigFun c () a] -> SigFun c () b
foldSF f b sfs =
  foldr g (constA b) sfs where
    g sfa sfb =
      proc () -> do
        s1 <- sfa -< ()
        s2 <- sfb -< ()
        outA -< f s1 s2
\end{code}
\caption{Working With Lists of Signal Sources}
\label{fig:foldSF}
\end{figure}

\section{A Bell Sound}

Bell using additive synthesis:

\begin{code}
bellAS  :: Instr (Mono AudRate)
        -- Dur -> AbsPitch -> Volume -> AudSF () Double
bellAS dur ap vol [] = 
  let  f    = apToHz ap
       v    = fromIntegral vol / 100
       d    = fromRational dur
       sfs  = map  (\r-> constA (f*r) >>> osc f1 0) 
                   [4.07, 3.76, 3, 2.74, 2, 1.71, 1.19, 0.92, 0.56]
  in proc () -> do
       aenv  <- envExponSeg [0,1,0.001] [0.003,d-0.003] -< ()
       a1    <- foldSF (+) 0 sfs -< ()
       outA -< a1*aenv*v/9

f1 = tableSinesN 4096 [1]

test1 = outFile "bell1.wav" 6 (bellAS 6 (absPitch (C,5)) 100 []) 
\end{code}

\out{
sine f r = 
  proc () -> do
    a1 <- osc f1 0 -< f*r
    outA -< a1

loop :: [AudSF () Double] -> AudSF () Double
loop [] = constA 0
loop (sf:sfs) = 
  proc () -> do
    a1 <- sf       -< ()
    a2 <- loop sfs -< ()
    outA -< a1 + a2

constA :: Clock p => a -> SigFun p () a
constA = arr . const

test1 = outFile "bell1.wav" 6 (bellAS 6 (absPitch (C,5)) 100 []) 
}
