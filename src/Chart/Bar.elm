module Chart.Bar exposing
    ( Accessor
    , init
    , render
    , withTitle, withDesc, withColorPalette, withColorInterpolator, withDomainBandGroup, withDomainBandSingle, withDomainLinear, withYAxisTickCount, withYAxisTickFormat, withYAxisTicks, withOrientation, withXAxis, withYAxis
    , diverging, grouped, horizontal, stacked, vertical
    , withSymbols, withIndividualLabels
    , noDirection, withGroupedLayout, withStackedLayout
    )

{-| This is the bar chart module from [elm-chart-builder](https://github.com/data-viz-lab/elm-chart-builder).

The Bar module expects the X axis to plot grouped ordinal data and the Y axis to plot linear data.


# Chart Data Format

@docs Accessor


# Chart Initialization

@docs init


# Chart Rendering

@docs render


# Configuration withters

@docs withTitle, withDesc, withColorPalette, withColorInterpolator, withDomainBandGroup, withDomainBandSingle, withDomainLinear, withLayout, withYAxisTickCount, withYAxisTickFormat, withYAxisTicks, withOrientation, withXAxis, withYAxis


# Configuration withters arguments

@docs diverging, grouped, horizontal, stacked, vertical


# LayoutConfig withters

These a specific configurations for the Grouped layout

@docs withSymbols, withIndividualLabels


# Chart icons

Icons can be added to grouped bar charts to improve understanding and accessibility.

    iconsCustom : List (Bar.BarSymbol msg)
    iconsCustom =
        [ Bar.symbolCustom
            |> Bar.withSymbolIdentifier "bicycle-symbol"
            |> Bar.withSymbolWidth 640
            |> Bar.withSymbolHeight 512
            |> Bar.withSymbolPaths [ bicycleSymbol ]
        , Bar.symbolCustom
            |> Bar.withSymbolIdentifier "car-symbol"
            |> Bar.withSymbolWidth 640
            |> Bar.withSymbolHeight 512
            |> Bar.withSymbolPaths [ carSymbol ]
        , Bar.symbolCustom
            |> Bar.withSymbolIdentifier "plane-symbol"
            |> Bar.withSymbolWidth 576
            |> Bar.withSymbolHeight 512
            |> Bar.withSymbolPaths [ planeSymbol ]
        ]

    grouped =
        Bar.grouped
            (Bar.defaultLayoutConfig
                |> Bar.withSymbols
            )

    Bar.init
        |> Bar.withLayout grouped
        |> Bar.render ( data, accessor )

-}

import Chart.Internal.Bar
    exposing
        ( renderBandGrouped
        , renderBandStacked
        )
import Chart.Internal.Symbol as InternalSymbol exposing (Symbol(..))
import Chart.Internal.Type as Type
    exposing
        ( AxisContinousDataTickCount(..)
        , AxisContinousDataTickFormat(..)
        , AxisContinousDataTicks(..)
        , AxisOrientation(..)
        , ColorResource(..)
        , Config
        , Direction(..)
        , Layout(..)
        , Margin
        , Orientation(..)
        , RenderContext(..)
        , defaultConfig
        , fromConfig
        , setColorResource
        , setDimensions
        , setHeight
        , setMargin
        , setXAxis
        , setYAxis
        , setSvgDesc
        , setSvgTitle
        , setWidth
        )
import Color exposing (Color)
import Html exposing (Html)
import TypedSvg.Types exposing (AlignmentBaseline(..), AnchorAlignment(..), ShapeRendering(..), Transform(..))


{-| The data accessors
-}
type alias Accessor data =
    { xGroup : data -> String
    , xValue : data -> String
    , yValue : data -> Float
    }


type alias RequiredConfig =
    { margin : Margin
    , width : Float
    , height : Float
    }


{-| Initializes the bar chart with a default config.

    Bar.init
        |> Bar.render ( data, accessor )

-}
init : RequiredConfig -> Config
init c =
    defaultConfig
        |> setDimensions { margin = c.margin, width = c.width, height = c.height }


{-| Renders the bar chart, after initialisation and customisation.

    data : List data
    data =
        [ { groupLabel = "A"
          , x = "a"
          , y = 10
          }
        , { groupLabel = "A"
          , x = "b"
          , y = 13
          }
        , { groupLabel = "B"
          , x = "a"
          , y = 11
          }
        , { groupLabel = "B"
          , x = "b"
          , y = 23
          }
        ]

    accessor : Accessor data
    accessor =
        Accessor .groupLabel .x .y

    Bar.init
        |> Bar.render (data, accessor)

-}
render : ( List data, Accessor data ) -> Config -> Html msg
render ( externalData, accessor ) config =
    let
        c =
            fromConfig config

        data =
            Type.externalToDataBand (Type.toExternalData externalData) accessor
    in
    case c.layout of
        GroupedBar ->
            renderBandGrouped ( data, config )

        StackedBar _ ->
            renderBandStacked ( data, config )

        _ ->
            -- TODO
            Html.text ""


{-| Sets the chart layout.

Values: `Bar.stacked` or `Bar.grouped`

Default value: Bar.grouped

    Bar.init
        |> Bar.withLayout (Bar.stacked Bar.noDirection)
        |> Bar.render ( data, accessor )

-}
withStackedLayout :
    Direction
    -> Config
    -> Config
withStackedLayout direction config =
    Type.setLayoutRestricted (StackedBar direction) config


withGroupedLayout :
    Config
    -> Config
withGroupedLayout config =
    Type.setLayout GroupedBar config


{-| Sets the orientation value in the config.

Accepts: horizontal or vertical
Default value: vertical

    Bar.init
        |> Bar.withOrientation horizontal
        |> Bar.render ( data, accessor )

-}
withOrientation : Orientation -> Config -> Config
withOrientation value config =
    Type.setOrientation value config


{-| Passes the tick values for a grouped bar chart continous axis.

Defaults to `Scale.ticks`

    Bar.init
        |> Bar.withYAxisTicks [ 1, 2, 3 ]
        |> Bar.render ( data, accessor )

-}
withYAxisTicks : List Float -> Config -> Config
withYAxisTicks ticks config =
    Type.setYAxisContinousTicks (Type.CustomTicks ticks) config


{-| Sets the approximate number of ticks for a grouped bar chart continous axis.

Defaults to `Scale.tickCount`

    Bar.init
        |> Bar.withYAxisTickCount 5
        |> Bar.render ( data, accessor )

-}
withYAxisTickCount : Int -> Config -> Config
withYAxisTickCount count config =
    Type.setYAxisContinousTickCount (Type.CustomTickCount count) config


{-| Sets the formatting for the ticks in a grouped bar chart continous axis.

Defaults to `Scale.tickFormat`

    formatter =
        FormatNumber.format { usLocale | decimals = 0 }

    Bar.init
        |> Bar.withYAxisTickFormat formatter
        |> Bar.render (data, accessor)

-}
withYAxisTickFormat : (Float -> String) -> Config -> Config
withYAxisTickFormat f config =
    Type.setYAxisContinousTickFormat (CustomTickFormat f) config


{-| Sets the color palette for the chart.

    palette =
        Scale.Color.tableau10

    Bar.init
        |> Bar.withColorPalette palette
        |> Bar.render (data, accessor)

-}
withColorPalette : List Color -> Config -> Config
withColorPalette palette config =
    Type.setColorResource (ColorPalette palette) config


{-| Sets the color interpolator for the chart.

This withting is not supported for stacked bar charts and will have no effect on them.

    Bar.init
        |> Bar.withColorInterpolator Scale.Color.plasmaInterpolator
        |> Bar.render ( data, accessor )

-}
withColorInterpolator : (Float -> Color) -> Config -> Config
withColorInterpolator interpolator config =
    Type.setColorResource (ColorInterpolator interpolator) config


{-| Sets the bandGroup value in the domain, in place of calculating it from the data.

    Bar.init
        |> Bar.withDomainBandBandGroup [ "0" ]
        |> Bar.render ( data, accessor )

-}
withDomainBandGroup : Type.BandDomain -> Config -> Config
withDomainBandGroup value config =
    Type.setDomainBandBandGroup value config


{-| Sets the bandSingle value in the domain, in place of calculating it from the data.

    Bar.init
        |> Bar.withDomainBandBandSingle [ "a", "b" ]
        |> Bar.render ( data, accessor )

-}
withDomainBandSingle : Type.BandDomain -> Config -> Config
withDomainBandSingle value config =
    Type.setDomainBandBandSingle value config


{-| Sets the bandLinear value in the domain, in place of calculating it from the data.

    Bar.init
        |> Bar.withDomainBandLinear ( 0, 0.55 )
        |> Bar.render ( data, accessor )

-}
withDomainLinear : Type.LinearDomain -> Config -> Config
withDomainLinear value config =
    Type.setDomainBandLinear value config


{-| Sets the showYAxis boolean value in the config

Default value: True

By convention the Y axix is the vertical one, but
if the layout is changed to horizontal, then the Y axis
represents the horizontal one.

    Bar.init
        |> Bar.withYAxis False
        |> Bar.render ( data, accessor )

-}
withYAxis : Bool -> Config -> Config
withYAxis value config =
    Type.setYAxis value config


{-| Sets the showOrdinalAxis boolean value in the config

Default value: True

By convention the X axix is the horizontal one, but
if the layout is changed to vertical, then the X axis
represents the vertical one.

    Bar.init
        |> Bar.withShowOrdinalAxis False
        |> Bar.render ( data, accessor )

-}
withXAxis : Bool -> Config -> Config
withXAxis value config =
    Type.setXAxis value config


{-| Sets the Icon Symbols list in the `LayoutConfig`.

Default value: []

These are additional symbols at the end of each bar in a group, for facilitating accessibility.

    defaultLayoutConfig
        |> withSymbols [ Circle, Corner, Triangle ]

-}
withSymbols :
    List Symbol
    -> Config
    -> Config
withSymbols =
    Type.setIcons


{-| Sets the `showIndividualLabels` boolean value in the `LayoutConfig`.

Default value: `False`

This shows the bar's ordinal value at the end of the rect, not the linear value.

If used together with symbols, the label will be drawn on top of the symbol.

&#9888; Use with caution, there is no knowledge of text wrapping!

With a vertical layout the available horizontal space is the width of the rects.

With an horizontal layout the available horizontal space is the right margin.

    defaultLayoutConfig
        |> Bar.withIndividualLabels True

-}
withIndividualLabels : Config -> Config
withIndividualLabels config =
    Type.showIndividualLabels True config


{-| Sets an accessible, long-text description for the svg chart.
Default value: ""
Bar.init
|> Bar.withDesc "This is an accessible chart, with a desc element"
|> Bar.render ( data, accessor )
-}
withDesc : String -> Config -> Config
withDesc value config =
    Type.setSvgDesc value config


{-| Sets an accessible title for the svg chart.
Default value: ""
Bar.init
|> Bar.withTitle "This is a chart"
|> Bar.render ( data, accessor )
-}
withTitle : String -> Config -> Config
withTitle value config =
    Type.setSvgTitle value config


{-| Horizontal layout type
Used as argument to Bar.withOrientation

    Bar.init
        |> Bar.withOrientation horizontal
        |> Bar.render ( data, accessor )

-}
horizontal : Orientation
horizontal =
    Horizontal


{-| Vertical layout type
Used as argument to Bar.withOrientation
This is the default layout

    Bar.init
        |> Bar.withOrientation vertical
        |> Bar.render ( data, accessor )

-}
vertical : Orientation
vertical =
    Vertical


{-| Stacked layout type

Beware that stacked layouts do not support icons

`stacked` expects a `noDirection` or a `diverging` argument.

    Bar.init
        |> Bar.withLayout (Bar.stacked Bar.noDirection)
        |> Bar.render ( data, accessor )

-}
stacked : Direction -> Layout
stacked direction =
    StackedBar direction


{-| Grouped layout type
This is the default layout type

    grouped =
        Bar.grouped Bar.defaultLayoutConfig

    Bar.init
        |> Bar.withLayout grouped
        |> Bar.render (data, accessor)

-}
grouped : Layout
grouped =
    GroupedBar


{-| Bar chart diverging layout
It is only used for stacked layouts
An example can be a population pyramid chart.

    stacked =
        Bar.stacked Bar.diverging

    Bar.init
        |> Bar.withLayout stacked
        |> Bar.render (data, accessor)

-}
diverging : Direction
diverging =
    Type.Diverging


noDirection : Direction
noDirection =
    Type.NoDirection
