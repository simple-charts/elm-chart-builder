module Chart.HistogramBar exposing
    ( AccessorHistogram, dataAccessor, preProcessedDataAccessor
    , init
    , render
    , Config, RequiredConfig
    , withBarStyle, withColor, withColumnTitle, withDesc, withDomain, withTableFloatFormat, withoutTable, withTitle
    , XAxis, YAxis, axisBottom, axisLeft, axisRight, hideAxis, hideXAxis, hideYAxis, withXAxis, withYAxis
    , yColumnTitle
    )

{-| This is the histogram chart module from [elm-chart-builder](https://github.com/data-viz-lab/elm-chart-builder).

The histogram bar chart can both generate the histogram data automatically or accept preprocessed data.

⚠ This module is still incomplete and does not expose all the flexibility that elm-visialization offers. Histogram generation for now always expects a list of steps in the data accessor and a domain in the config. This will likely change in the future.

⚠ When passing steps one should also explicity pass a domain that matches the steps. This will likely change in the future.


# Data Accessors

@docs AccessorHistogram, dataAccessor, preProcessedDataAccessor


# Chart Initialization

@docs init


# Chart Rendering

@docs render


# Configuration

@docs Config, RequiredConfig


# Configuration setters

@docs withBarStyle, withColor, withColumnTitle, withDesc, withDomain, withTableFloatFormat, withoutTable, withTitle


# Axis

@docs XAxis, YAxis, axisBottom, axisLeft, axisRight, hideAxis, hideXAxis, hideYAxis, withXAxis, withYAxis


# Configuration arguments

@docs yColumnTitle

-}

import Axis
import Chart.Internal.Axis as ChartAxis
import Chart.Internal.Bar
    exposing
        ( renderHistogram
        )
import Chart.Internal.Type as Type
import Color exposing (Color)
import Histogram
import Html exposing (Html)
import TypedSvg.Types exposing (AlignmentBaseline(..), AnchorAlignment(..), ShapeRendering(..), Transform(..))


{-| The Config opaque type
-}
type alias Config msg validation =
    Type.Config msg validation


{-| The required config, passed as an argument to the `init` function
-}
type alias RequiredConfig =
    { margin : Type.Margin
    , width : Float
    , height : Float
    }


{-| The steps to build the histogram
-}
type alias Steps =
    List Float


{-| The data accessor for the histogram
-}
type alias AccessorHistogram data =
    Type.AccessorHistogram data


{-| The data accessor for generating a histogram.
It takes a config that is separate from the general config,
because it is only used when generating a histogram and not for bucketed pre-processed data.

    steps : Steps
    steps =
        [ 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1 ]

    dataAccessor =
        Histo.dataAccessor steps accessor

-}
dataAccessor : Steps -> (data -> Float) -> Type.AccessorHistogram data
dataAccessor bins acc =
    Type.AccessorHistogram bins acc


{-| The data accessor for generating a histogram from pre-processed data.
Meaning the data has already been bucketed and counted.
`values` here is not used and always passed as an empty array.

The data must be compatible with the [Bin](https://package.elm-lang.org/packages/gampleman/elm-visualization/latest/Histogram#Bin) data type from elm-visualization.

    preProcessedDataAccessor =
        Histo.preProcessedDataAccessor
            (\d ->
                -- This is a Bin data type from elm-visualization
                { x0 = d.bucket
                , x1 = d.bucket + 0.1
                , values = []
                , length = d.count
                }
            )

-}
preProcessedDataAccessor : (data -> Histogram.Bin Float Float) -> Type.AccessorHistogram data
preProcessedDataAccessor acc =
    Type.AccessorHistogramPreProcessed acc


{-| Initializes the histogram bar chart with a default config.

    Histo.init requiredConfig
        |> Histo.render ( data, accessor )

-}
init : RequiredConfig -> Config msg validation
init c =
    Type.defaultConfig
        |> Type.setDimensions { margin = c.margin, width = c.width, height = c.height }


{-| Renders the histogram

    Histo.init requiredConfig
        |> Histo.render ( data, accessor )

-}
render : ( List data, Type.AccessorHistogram data ) -> Config msg validation -> Html msg
render ( externalData, acc ) config =
    let
        data =
            Type.externalToDataHistogram config (Type.toExternalData externalData) acc
    in
    renderHistogram ( data, config )


{-| Do **not** build an alternative table content for accessibility

&#9888; By default an alternative table is always being rendered.
Use this option to not build the table.

    Histo.init requiredConfig
        |> Histo.withoutTable
        |> Histo.render ( data, accessor )

-}
withoutTable : Config msg validation -> Config msg validation
withoutTable =
    Type.setAccessibilityContent Type.AccessibilityNone


{-| Set the domain for the HistogramGenerator.
All values falling outside the domain will be ignored.

    Histo.init requiredConfig
        |> Histo.withDomain ( 0, 1 )
        |> Histo.render ( data, accessor )

-}
withDomain : ( Float, Float ) -> Config msg validation -> Config msg validation
withDomain domain config =
    Type.setHistogramDomain domain config


{-| An optional formatter for all float values in the alternative table content for accessibility.

Defaults to `String.fromFloat`

    Histo.init requiredConfig
        |> Histo.withTableFloatFormat String.fromFloat
        |> Histo.render ( data, accessor )

-}
withTableFloatFormat : (Float -> String) -> Config msg validation -> Config msg validation
withTableFloatFormat f =
    Type.setTableFloatFormat f


{-| Set the histogram color

    Histo.init requiredConfig
        |> Histo.withColor (Color.rgb255 240 59 32)
        |> Histo.render ( data, accessor )

-}
withColor : Color -> Config msg validation -> Config msg validation
withColor color config =
    Type.setColorResource (Type.Color color) config


{-| Sets an accessible, long-text description for the svg chart.
Default value: ""

    Histo.init requiredConfig
        |> Histo.withDesc "This is an accessible chart, with a desc element"
        |> Histo.render ( data, accessor )

-}
withDesc : String -> Config msg validation -> Config msg validation
withDesc value config =
    Type.setSvgDesc value config


{-| Sets an accessible title for the svg chart.
Default value: ""

    Histo.init requiredConfig
        |> Histo.withTitle "This is a chart"
        |> Histo.render ( data, accessor )

-}
withTitle : String -> Config msg validation -> Config msg validation
withTitle value config =
    Type.setSvgTitle value config


{-| Set the chart columns title value

It takes one of: yColumnTitle

It takes a formatter function.

    defaultLayoutConfig
        |> Bar.withColumnTitle (Bar.yColumnTitle String.fromFloat)

-}
withColumnTitle : Type.ColumnTitle -> Config msg validation -> Config msg validation
withColumnTitle title config =
    case title of
        Type.YColumnTitle formatter ->
            Type.showYColumnTitle formatter config

        Type.XOrdinalColumnTitle ->
            Type.showXOrdinalColumnTitle config

        _ ->
            config


{-| Sets the style for the bars
The styles set here have precedence over css.

    Histo.init requiredConfig
        |> Histo.withBarStyle [ ( "fill", "none" ), ( "stroke-width", "2" ) ]
        |> Histo.render ( data, accessor )

-}
withBarStyle : List ( String, String ) -> Config msg validation -> Config msg validation
withBarStyle styles config =
    Type.setCoreStyles styles config


{-| -}
yColumnTitle : (Float -> String) -> Type.ColumnTitle
yColumnTitle =
    Type.YColumnTitle



-- AXIS


{-| The XAxis type
-}
type alias XAxis value =
    ChartAxis.XAxis value


{-| The YAxis type
-}
type alias YAxis value =
    ChartAxis.YAxis value


{-| A YAxis Left type

    Histo.axisLeft [ Axis.tickCount 5 ]

-}
axisLeft : List (Axis.Attribute value) -> ChartAxis.YAxis value
axisLeft =
    ChartAxis.Left


{-| It returns an YAxis Right type

    Histo.axisRight [ Axis.tickCount 5 ]

-}
axisRight : List (Axis.Attribute value) -> ChartAxis.YAxis value
axisRight =
    ChartAxis.Right


{-| It returns an XAxis Bottom type

    Histo.axisBottom [ Axis.tickCount 5 ]

-}
axisBottom : List (Axis.Attribute value) -> ChartAxis.XAxis value
axisBottom =
    ChartAxis.Bottom


{-| Hide all axis.

    Histo.init requiredConfig
        |> Histo.hideAxis
        |> Histo.render ( data, accessor )

-}
hideAxis : Config msg validation -> Config msg validation
hideAxis config =
    Type.setXAxis False config
        |> Type.setYAxis False


{-| Hide the Y aixs.

    Histo.init requiredConfig
        |> Histo.hideYAxis
        |> Histo.render ( data, accessor )

-}
hideYAxis : Config msg validation -> Config msg validation
hideYAxis config =
    Type.setYAxis False config


{-| Hide the X aixs.

    Histo.init requiredConfig
        |> Histo.hideXAxis
        |> Histo.render ( data, accessor )

-}
hideXAxis : Config msg validation -> Config msg validation
hideXAxis config =
    Type.setXAxis False config


{-| Customise the xAxis

    Histo.init requiredConfig
        |> Histo.withXAxis (Histo.axisBottom [ Axis.tickCount 5 ])
        |> Histo.render ( data, accessor )

-}
withXAxis : ChartAxis.XAxis Float -> Config msg validation -> Config msg validation
withXAxis =
    Type.setXAxisContinuous


{-| Customise the yAxis

    Histo.init requiredConfig
        |> Histo.withYAxis (Histo.axisRight [ Axis.tickCount 5 ])
        |> Histo.render ( data, accessor )

-}
withYAxis : ChartAxis.YAxis Float -> Config msg validation -> Config msg validation
withYAxis =
    Type.setYAxisContinuous
