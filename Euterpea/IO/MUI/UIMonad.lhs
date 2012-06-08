A simple Graphical User Interface with concepts borrowed from Phooey
by Conal Elliot.

> {-# LANGUAGE DoRec #-}

> module Euterpea.IO.MUI.UIMonad where

> import Euterpea.IO.MUI.SOE
> import qualified Euterpea.IO.MUI.SOE as SOE
> import Euterpea.IO.MIDI.MidiIO

> import qualified Codec.Midi as Midi
> import Sound.PortMidi hiding (time)

> import Control.Monad.Fix
> import Control.Concurrent.MonadIO


A UI widget runs under a given context, with its internal system
states, and maps input signals to outputs, which consists of 3 parts:
a signal of actions (to render graphics or sounds), its layout and a
parametrized output type.

> newtype UI a = UI 
>   { unUI :: (CTX, Sys, Input) -> 
>             IO (Layout, Sys, Action, [ThreadId], a) }

> addThreadID :: ThreadId -> UI ()
> addThreadID t = UI (\(_,s,_) -> return (nullLayout, s, nullAction, [t], ()))

Rendering Context
=================

A rendering context specifies the following:
 
1. A layout direction to flow widgets. 
 
2. A rectangle bound of current drawing area to render a UI
   component. It specifies the max size of a widget, not the
   actual size. It's up to each individual widget to decide
   where in this bound to put itself.

3. A unique widget ID for the current UI component that
   receives this context.

4. A function that inject inputs into system event queue.
   This is needed to implement some input widgets.

> data CTX = CTX 
>   { flow   :: Flow
>   , bounds :: Rect
>   , uid    :: WidgetID
>   , inject :: Input -> IO ()
>   }

> data Flow = TopDown | BottomUp | LeftRight | RightLeft deriving (Eq, Show)
> type Dimension = (Int, Int)
> type Rect = (Point, Dimension)


UI Layout
=========

The layout of a widget provides data to calculate its actual size
in a given context.

> data Layout = Layout
>   { hFill  :: Int
>   , vFill  :: Int
>   , hFixed :: Int
>   , vFixed :: Int
>   , minW   :: Int
>   , minH   :: Int
>   } deriving (Eq, Show)

1. hFill/vFill specify how much stretching space (in units) in
   horizontal/vertical direction should be allocated for this widget.

2. hSize/vSize specify how much non-stretching space (width/height in
   pixels) should be allocated for this widget. 

Layout calculation makes use of lazy evaluation to do it in one pass.
Although the UI function maps from Context to Layout, both hFill/vFill
and hSize/vSize must be fixed and independent of the Context.
Therefore they are avaiable before the UI function is even evaluated.

Context and Layout Functions
============================

Divide CTX according to the ratio of a widget's layout and the overall
layout of the widget that receives this CTX.

> divideCTX :: CTX -> Layout -> Layout -> (CTX, CTX)
> divideCTX (CTX a ((x, y), (w, h)) i f) 
>           ~(Layout m n u v minw minh) ~(Layout m' n' u' v' minw' minh') =
>   case a of
>     TopDown   -> (CTX a ((x, y), (w, h')) i f, 
>                   CTX a ((x, y + h'), (w, h - h')) i f)
>     BottomUp  -> (CTX a ((x, y + h - h'), (w, h')) i f, 
>                   CTX a ((x, y), (w, h - h')) i f)
>     LeftRight -> (CTX a ((x, y), (w', h)) i f, 
>                   CTX a ((x + w', y), (w - w', h)) i f)
>     RightLeft -> (CTX a ((x + w - w', y), (w', h)) i f, 
>                   CTX a ((x, y), (w - w', h)) i f)
>   where
>     w' = min (w - (minw' - minw)) $ max minw $ (m * div' (w - u') m' + u)
>     h' = min (h - (minh' - minh)) $ max minh $ (n * div' (h - v') n' + v)
>     div' b 0 = 0
>     div' b d = div b d

Calculate the actual size of a widget given the context and its layout.

> computeBBX :: CTX -> Layout -> Rect
> computeBBX (CTX a ((x, y), (w, h)) i _) ~(Layout m n u v minw minh) = 
>   case a of
>     TopDown   -> ((x, y), (w', h')) 
>     BottomUp  -> ((x, y + h - h'), (w', h'))
>     LeftRight -> ((x, y), (w', h'))
>     RightLeft -> ((x + w - w', y), (w', h'))
>   where
>     w' = max minw $ (if m == 0 then u else w)
>     h' = max minh $ (if n == 0 then v else h)

Merge two layouts into one.

> mergeLayout a (Layout n m u v minw minh) (Layout n' m' u' v' minw' minh') = 
>   case a of
>     TopDown   -> Layout (max' n n') (m + m') (max u u') (v + v') (max minw minw') (minh + minh')
>     BottomUp  -> Layout (max' n n') (m + m') (max u u') (v + v') (max minw minw') (minh + minh')
>     LeftRight -> Layout (n + n') (max' m m') (u + u') (max v v') (minw + minw') (max minh minh')
>     RightLeft -> Layout (n + n') (max' m m') (u + u') (max v v') (minw + minw') (max minh minh')
>   where
>     max' 0 0 = 0
>     max' _ _ = 1

Null layout.

> nullLayout = Layout 0 0 0 0 0 0

Widget ID
=========

Widget ID is actually 2-dimensional because we want to support both
sequential composition and nested wrappers. In the latter case
a simple ID number wouldn't suffice.

> newtype WidgetID = WidgetID [Int] deriving (Eq, Show)

> firstWidgetID = WidgetID [0]
> popWidgetID (WidgetID (i:is)) = WidgetID is
> popWidgetID _ = error "can't pop empty WidgetID" 
> pushWidgetID (WidgetID is) = WidgetID (0:is)
> nextWidgetID (WidgetID (i:is)) = WidgetID ((i + 1) : is)
> nextWidgetID _ = error "can't get the next of empty WidgetID"

Input, Action, and System State
===============================

Input is a union of user events and Midi events, and in addition,
a timer event is needed to drive time based computations.
 
> data Input 
>   = UIEvent SOE.Event 
>   | Timer Time 
>   | MidiEvent DeviceID Midi.Message
>   deriving Show

Actions include both Graphics and Sound output. Even though both
are indeed just IO monads, we separate them because Sound output
must be immediately delivered, while graphics can wait until
next screen refresh.

> type Action = (Graphic, Sound)
> type Sound = IO ()
> mergeAction (g, s) (g', s') = (overGraphic g' g, s >> s')
> nullSound = return () :: Sound
> nullAction = (nullGraphic, nullSound) :: Action
> justSoundAction :: Sound -> Action
> justSoundAction s = (nullGraphic, s)
> justGraphicAction :: Graphic -> Action
> justGraphicAction g = (g, nullSound)

System state is hidden from input and output, but shared among
UI widgets.

> data Sys = Sys 
>   { dirty     :: Bool                -- whether a redraw is needed 
>   , focus     :: Maybe WidgetID      -- currently focused widget
>   , nextFocus :: Maybe WidgetID      -- next focus widget
>   } deriving Show

Monadic Instances
=================

We use Monad compositions to compose two UIs in sequence.

Alternatively we could use Arrows or Applicative Functors to do the
same, so the choice of Monad here is somewhat arbitary.

> cross f g x = (f x, g x)

> instance Monad UI where
>   return i = UI (\(_,s,_) -> return (nullLayout, s, nullAction, [], i))

>   (UI m) >>= f = UI (\(ctx, s, inp) -> do 
>     rec let (ctx1, ctx2)      = divideCTX ctx l1 layout
> --            (ctx2, _)         = divideCTX ctx' l2 l2
>         (l1, s1, a1, t1, v1) <- m (ctx1 { uid = pushWidgetID (uid ctx)}, s, inp)
>         (l2, s2, a2, t2, v2) <- unUI (f v1) 
>                                 (ctx2 { uid = nextWidgetID (uid ctx) }, s1, inp)
>         let action            = mergeAction a1 a2
>             layout            = mergeLayout (flow ctx) l1 l2 
>     return (layout, s2, action, t1++t2, v2))

UIs are also instances of MonadFix so that we can define value
level recursion.

> instance MonadFix UI where
>   mfix f = UI aux
>     where
>       aux (ctx, s, inp) = u
>         where u = do rec (l, s', a, t, r) <- unUI (f r) (ctx, s, inp)
>                      return (l, s', a, t, r)

> instance MonadIO UI where
>   liftIO a = UI (\(_,s,_) -> a >>= (\v -> return (nullLayout, s, nullAction, [], v)))

