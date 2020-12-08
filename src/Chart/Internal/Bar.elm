module Chart.Internal.Bar exposing
    ( renderBandGrouped
    , renderBandStacked
    , renderHistogram
    )

import Axis
import Chart.Internal.Axis as ChartAxis
import Chart.Internal.Helpers as Helpers
import Chart.Internal.Symbol
    exposing
        ( Symbol(..)
        , circle_
        , corner
        , custom
        , getSymbolByIndex
        , symbolGap
        , symbolToId
        , triangle
        )
import Chart.Internal.Table as Table
import Chart.Internal.TableHelpers as Helpers
import Chart.Internal.Type
    exposing
        ( AccessibilityContent(..)
        , ColumnTitle(..)
        , Config
        , ConfigStruct
        , DataBand
        , DataGroupBand
        , Direction(..)
        , DomainBand(..)
        , DomainBandStruct
        , DomainContinuous(..)
        , Label(..)
        , Layout(..)
        , Orientation(..)
        , PointBand
        , RenderContext(..)
        , StackedValues
        , adjustContinuousRange
        , ariaLabelledby
        , ariaLabelledbyContent
        , bottomGap
        , calculateHistogramDomain
        , colorCategoricalStyle
        , colorStyle
        , dataBandToDataStacked
        , fromConfig
        , fromDataBand
        , getBandGroupRange
        , getBandSingleRange
        , getContinuousRange
        , getDataBandDepth
        , getDomainBandFromData
        , getOffset
        , getStackedValuesAndGroupes
        , leftGap
        , role
        , showIcons
        , stackedValuesInverse
        , symbolCustomSpace
        , symbolSpace
        )
import Histogram exposing (Bin)
import Html exposing (Html)
import Html.Attributes
import List.Extra
import Scale exposing (BandScale, ContinuousScale, defaultBandConfig)
import Shape exposing (StackConfig)
import TypedSvg exposing (g, rect, svg, text_)
import TypedSvg.Attributes
    exposing
        ( class
        , dominantBaseline
        , shapeRendering
        , style
        , textAnchor
        , title
        , transform
        , viewBox
        , xlinkHref
        )
import TypedSvg.Attributes.InPx exposing (height, width, x, y)
import TypedSvg.Core exposing (Svg, text)
import TypedSvg.Types
    exposing
        ( AlignmentBaseline(..)
        , AnchorAlignment(..)
        , DominantBaseline(..)
        , ShapeRendering(..)
        , Transform(..)
        )


descAndTitle : ConfigStruct -> List (Svg msg)
descAndTitle c =
    -- TODO, return empty list if no options
    -- https://developer.paciellogroup.com/blog/2013/12/using-aria-enhance-svg-accessibility/
    [ TypedSvg.title [] [ text c.svgTitle ]
    , TypedSvg.desc [] [ text c.svgDesc ]
    ]



-- BAND STACKED


renderBandStacked : ( DataBand, Config ) -> Html msg
renderBandStacked ( data, config ) =
    -- based on https://code.gampleman.eu/elm-visualization/StackedBarChart/
    let
        c =
            fromConfig config

        m =
            c.margin

        w =
            c.width

        h =
            c.height

        outerW =
            w + m.left + m.right

        outerH =
            h + m.top + m.bottom

        dataStacked : List ( String, List Float )
        dataStacked =
            dataBandToDataStacked data config

        stackedConfig : StackConfig String
        stackedConfig =
            { data = dataStacked
            , offset = getOffset config
            , order = identity
            }

        { values, labels, extent } =
            Shape.stack stackedConfig

        stackDepth =
            getDataBandDepth data

        domain : DomainBandStruct
        domain =
            getDomainBandFromData data config

        continuousDomain : Maybe Chart.Internal.Type.ContinuousDomain
        continuousDomain =
            domain
                |> .continuous

        continuousExtent =
            case continuousDomain of
                Just ld ->
                    case c.layout of
                        StackedBar direction ->
                            case direction of
                                Diverging ->
                                    [ Tuple.first ld |> abs, Tuple.second ld |> abs ]
                                        |> List.maximum
                                        |> Maybe.map (\max -> ( max * -1, max ))
                                        |> Maybe.withDefault ( 0, 0 )

                                _ ->
                                    extent

                        _ ->
                            extent

                Nothing ->
                    extent

        bandGroupRange =
            getBandGroupRange config w h

        bandSingleRange =
            getBandSingleRange config (Scale.bandwidth bandGroupScale)

        bandGroupScale =
            Scale.band { defaultBandConfig | paddingInner = 0.1, paddingOuter = 0.05 }
                bandGroupRange
                (Maybe.withDefault [] domain.bandGroup)

        bandSingleScale =
            Scale.band defaultBandConfig
                bandSingleRange
                (Maybe.withDefault [] domain.bandSingle)

        continuousRange =
            getContinuousRange config RenderChart w h bandSingleScale
                |> adjustContinuousRange config stackDepth

        continuousRangeAxis =
            getContinuousRange config RenderAxis w h bandSingleScale
                |> adjustContinuousRange config stackDepth

        continuousScale : ContinuousScale Float
        continuousScale =
            -- For stacked scales
            -- |> Scale.nice 4
            Scale.linear continuousRange continuousExtent

        continuousScaleAxis : ContinuousScale Float
        continuousScaleAxis =
            -- For stacked scales
            -- |> Scale.nice 4
            Scale.linear continuousRangeAxis continuousExtent

        ( columnValues, columnGroupes ) =
            getStackedValuesAndGroupes values data

        scaledValues : List StackedValues
        scaledValues =
            columnValues
                |> List.map
                    (List.map
                        (\vals ->
                            let
                                ( a1, a2 ) =
                                    vals.stackedValue
                            in
                            { vals
                                | stackedValue =
                                    ( Scale.convert continuousScale a1
                                    , Scale.convert continuousScale a2
                                    )
                            }
                        )
                    )

        axisBandScale : BandScale String
        axisBandScale =
            bandGroupScale

        svgElAttrs =
            [ viewBox 0 0 outerW outerH
            , width outerW
            , height outerH
            , role "img"
            ]
                ++ ariaLabelledbyContent c

        svgEl =
            svg svgElAttrs
                (descAndTitle c
                    ++ bandXAxis c axisBandScale
                    ++ bandGroupedYAxis c 0 continuousScaleAxis
                    ++ [ g
                            [ transform [ stackedContainerTranslate c m.left m.top (toFloat stackDepth) ]
                            , class [ "series" ]
                            ]
                         <|
                            List.map (stackedColumns c bandGroupScale)
                                (List.map2 (\a b -> ( a, b, labels )) columnGroupes scaledValues)
                       ]
                )

        tableHeadings =
            Helpers.dataBandToTableHeadings data
                |> Table.ComplexHeadings

        tableData =
            Helpers.dataBandToTableData data

        table =
            Table.generate tableData
                |> Table.setColumnHeadings tableHeadings
                |> Table.view

        tableEl =
            Helpers.invisibleFigcaption
                [ case table of
                    Ok table_ ->
                        Html.div [] [ table_ ]

                    Err error ->
                        Html.text (Table.errorToString error)
                ]
    in
    case c.accessibilityContent of
        AccessibilityTable ->
            Html.div []
                [ Html.figure
                    []
                    [ svgEl, tableEl ]
                ]

        AccessibilityNone ->
            Html.div [] [ svgEl ]


stackedContainerTranslate : ConfigStruct -> Float -> Float -> Float -> Transform
stackedContainerTranslate config a b offset =
    let
        orientation =
            config |> .orientation
    in
    case orientation of
        Horizontal ->
            Translate (a - offset) b

        Vertical ->
            Translate a (b + offset)


stackedColumns : ConfigStruct -> BandScale String -> ( String, StackedValues, List String ) -> Svg msg
stackedColumns config bandGroupScale payload =
    let
        rects =
            case config.orientation of
                Vertical ->
                    verticalRectsStacked config bandGroupScale payload

                Horizontal ->
                    horizontalRectsStacked config bandGroupScale payload
    in
    g [ class [ "columns" ] ] rects


verticalRectsStacked :
    ConfigStruct
    -> BandScale String
    -> ( String, StackedValues, List String )
    -> List (Svg msg)
verticalRectsStacked c bandGroupScale ( group, values, labels ) =
    let
        bandValue =
            Scale.convert bandGroupScale group

        block idx { rawValue, stackedValue } =
            let
                ( upper, lower ) =
                    stackedValue

                coreStyle =
                    Helpers.mergeStyles c.coreStyle (colorCategoricalStyle c idx)
                        |> style

                rect_ =
                    rect
                        [ x <| bandValue
                        , y <| lower - toFloat idx
                        , width <| Scale.bandwidth bandGroupScale
                        , height <| (abs <| upper - lower)
                        , shapeRendering RenderCrispEdges
                        , coreStyle
                        ]
                        (stackedColumnTitleText c idx labels rawValue)
            in
            g [ class [ "column", "column-" ++ String.fromInt idx ] ] [ rect_ ]
    in
    List.indexedMap (\idx -> block idx) values


horizontalRectsStacked :
    ConfigStruct
    -> BandScale String
    -> ( String, StackedValues, List String )
    -> List (Svg msg)
horizontalRectsStacked c bandGroupScale ( group, values, labels ) =
    let
        block idx { rawValue, stackedValue } =
            let
                ( lower, upper ) =
                    stackedValue

                coreStyle =
                    Helpers.mergeStyles c.coreStyle (colorCategoricalStyle c idx)
                        |> style

                rect_ =
                    rect
                        [ y <| Scale.convert bandGroupScale group
                        , x <| lower + toFloat idx
                        , height <| Scale.bandwidth bandGroupScale
                        , width <| (abs <| upper - lower)
                        , shapeRendering RenderCrispEdges
                        , coreStyle
                        ]
                        (stackedColumnTitleText c idx labels rawValue)
            in
            g [ class [ "column", "column-" ++ String.fromInt idx ] ] [ rect_ ]
    in
    values
        |> stackedValuesInverse c.width
        |> List.indexedMap (\idx -> block idx)



-- BAND GROUPED


renderBandGrouped : ( DataBand, Config ) -> Html msg
renderBandGrouped ( data, config ) =
    let
        c =
            fromConfig config

        m =
            c.margin

        w =
            c.width

        h =
            c.height

        outerW =
            w + m.left + m.right

        outerH =
            h + m.top + m.bottom

        domain : DomainBandStruct
        domain =
            getDomainBandFromData data config

        bandGroupRange =
            getBandGroupRange config w h

        bandSingleRange =
            getBandSingleRange config (Scale.bandwidth bandGroupScale)

        continuousRange =
            getContinuousRange config RenderChart w h bandSingleScale

        dataLength =
            data |> fromDataBand |> List.length

        paddingInner =
            -- Adapt the padding to the number of bars, more bars less padding
            -- otherwise no space would be left between bars
            Scale.convert
                (Scale.linear ( 0.2, 0.999 ) ( 0, 500 ) |> Scale.clamp)
                (data |> getDataBandDepth |> toFloat)

        paddingInnerGroup =
            if dataLength == 1 then
                0

            else
                0.1

        bandGroupScale : BandScale String
        bandGroupScale =
            Scale.band { defaultBandConfig | paddingInner = paddingInnerGroup, paddingOuter = paddingInnerGroup }
                bandGroupRange
                (domain.bandGroup |> Maybe.withDefault [])

        bandSingleScale : BandScale String
        bandSingleScale =
            Scale.band { defaultBandConfig | paddingInner = paddingInner, paddingOuter = paddingInner / 2 }
                bandSingleRange
                (Maybe.withDefault [] domain.bandSingle)

        continuousScale : ContinuousScale Float
        continuousScale =
            Scale.linear continuousRange (Maybe.withDefault ( 0, 0 ) domain.continuous)

        colorScale : ContinuousScale Float
        colorScale =
            Scale.linear ( 0, 1 ) (Maybe.withDefault ( 0, 0 ) domain.continuous)

        iconOffset : Float
        iconOffset =
            symbolSpace Vertical bandSingleScale c.icons + symbolGap

        symbolElements =
            case c.layout of
                GroupedBar ->
                    if showIcons config then
                        symbolsToSymbolElements c.orientation bandSingleScale c.icons

                    else
                        []

                _ ->
                    []

        axisBandScale : BandScale String
        axisBandScale =
            if List.length (domain.bandGroup |> Maybe.withDefault []) > 1 then
                bandGroupScale

            else
                bandSingleScale

        tableHeadings =
            Helpers.dataBandToTableHeadings data
                |> Table.ComplexHeadings

        tableData =
            Helpers.dataBandToTableData data

        table =
            Table.generate tableData
                |> Table.setColumnHeadings tableHeadings
                |> Table.view

        svgElAttrs =
            [ viewBox 0 0 outerW outerH
            , width outerW
            , height outerH
            , role "img"
            ]
                ++ ariaLabelledbyContent c

        svgEl =
            svg svgElAttrs <|
                descAndTitle c
                    ++ bandGroupedYAxis c iconOffset continuousScale
                    ++ bandXAxis c axisBandScale
                    ++ [ g
                            [ transform [ Translate m.left m.top ]
                            , class [ "series" ]
                            ]
                         <|
                            List.map
                                (columns config iconOffset bandGroupScale bandSingleScale continuousScale colorScale)
                                (fromDataBand data)
                       ]
                    --TODO: the symbol elements could be extrapolated outside the svg element
                    -- and eventually they could also be shared across multiple charts
                    -- see: https://css-tricks.com/svg-symbol-good-choice-icons/
                    ++ symbolElements

        tableEl =
            Helpers.invisibleFigcaption
                [ case table of
                    Ok table_ ->
                        Html.div [] [ table_ ]

                    Err error ->
                        Html.text (Table.errorToString error)
                ]
    in
    case c.accessibilityContent of
        AccessibilityTable ->
            Html.div []
                [ Html.figure
                    []
                    [ svgEl, tableEl ]
                ]

        AccessibilityNone ->
            Html.div [] [ svgEl ]


columns :
    Config
    -> Float
    -> BandScale String
    -> BandScale String
    -> ContinuousScale Float
    -> ContinuousScale Float
    -> DataGroupBand
    -> Svg msg
columns config iconOffset bandGroupScale bandSingleScale continuousScale colorScale dataGroup =
    let
        tr =
            case config |> fromConfig |> .orientation of
                Vertical ->
                    -- https://observablehq.com/@d3/grouped-bar-chart
                    -- .attr("transform", d => `translate(${x0(d[groupKey])},0)`)
                    Translate (dataGroupTranslation bandGroupScale dataGroup) 0

                Horizontal ->
                    Translate 0 (dataGroupTranslation bandGroupScale dataGroup)
    in
    g
        [ transform [ tr ]
        , class [ "data-group" ]
        ]
    <|
        List.indexedMap (column config iconOffset bandSingleScale continuousScale colorScale) dataGroup.points


column :
    Config
    -> Float
    -> BandScale String
    -> ContinuousScale Float
    -> ContinuousScale Float
    -> Int
    -> PointBand
    -> Svg msg
column config iconOffset bandSingleScale continuousScale colorScale idx point =
    let
        rectangle =
            case config |> fromConfig |> .orientation of
                Vertical ->
                    verticalRect config iconOffset bandSingleScale continuousScale colorScale idx point

                Horizontal ->
                    horizontalRect config bandSingleScale continuousScale colorScale idx point
    in
    g [ class [ "column", "column-" ++ String.fromInt idx ] ] rectangle


verticalRect :
    Config
    -> Float
    -> BandScale String
    -> ContinuousScale Float
    -> ContinuousScale Float
    -> Int
    -> PointBand
    -> List (Svg msg)
verticalRect config iconOffset bandSingleScale continuousScale colorScale idx point =
    let
        ( x__, y__ ) =
            point

        c =
            fromConfig config

        labelOffset =
            if List.isEmpty c.icons then
                0

            else
                w

        colorStyles =
            colorStyle c (Just idx) (Scale.convert colorScale y__ |> Just)

        coreStyle =
            Helpers.mergeStyles c.coreStyle colorStyles
                |> style

        w =
            Scale.bandwidth bandSingleScale

        h =
            c.height
                - Scale.convert continuousScale y__
                - iconOffset

        label =
            verticalLabel config (x_ + w / 2) (y_ - labelGap - labelOffset) point

        x_ =
            Scale.convert bandSingleScale x__

        y_ =
            Scale.convert continuousScale y__
                + iconOffset

        symbol : List (Svg msg)
        symbol =
            verticalSymbol config { idx = idx, x_ = x_, y_ = y_, w = w, styleStr = colorStyles }

        rect_ =
            rect
                [ x <| x_
                , y <| y_
                , width <| w
                , height <| h
                , shapeRendering RenderCrispEdges
                , coreStyle
                ]
                (columnTitleText config point)
    in
    rect_
        :: symbol
        ++ label


horizontalRect :
    Config
    -> BandScale String
    -> ContinuousScale Float
    -> ContinuousScale Float
    -> Int
    -> PointBand
    -> List (Svg msg)
horizontalRect config bandSingleScale continuousScale colorScale idx point =
    let
        c =
            fromConfig config

        ( x__, y__ ) =
            point

        h =
            Scale.bandwidth bandSingleScale

        w =
            Scale.convert continuousScale y__

        y_ =
            Scale.convert bandSingleScale x__

        colorStyles =
            colorStyle c (Just idx) (Scale.convert colorScale y__ |> Just)

        coreStyle =
            Helpers.mergeStyles c.coreStyle colorStyles
                |> style

        labelOffset =
            if List.isEmpty c.icons then
                0

            else
                h

        label =
            horizontalLabel config (w + labelGap + labelOffset) (y_ + h / 2) point

        symbol =
            horizontalSymbol config { idx = idx, w = w, y_ = y_, h = h, styleStr = colorStyles }

        rect_ =
            rect
                [ x <| 0
                , y y_
                , width w
                , height h
                , shapeRendering RenderCrispEdges
                , coreStyle
                ]
                (columnTitleText config point)
    in
    rect_
        :: symbol
        ++ label


dataGroupTranslation : BandScale String -> DataGroupBand -> Float
dataGroupTranslation bandGroupScale dataGroup =
    case dataGroup.groupLabel of
        Nothing ->
            0

        Just l ->
            Scale.convert bandGroupScale l


verticalLabel : Config -> Float -> Float -> PointBand -> List (Svg msg)
verticalLabel config xPos yPos point =
    let
        ( xVal, yVal ) =
            point

        txt =
            text_
                [ x xPos
                , y yPos
                , textAnchor AnchorMiddle
                ]
    in
    case fromConfig config |> .showLabels of
        YLabel formatter ->
            [ txt [ text (yVal |> formatter) ] ]

        XOrdinalLabel ->
            [ txt [ text xVal ] ]

        _ ->
            []


horizontalSymbol :
    Config
    -> { idx : Int, w : Float, y_ : Float, h : Float, styleStr : String }
    -> List (Svg msg)
horizontalSymbol config { idx, w, y_, styleStr } =
    let
        symbol =
            getSymbolByIndex (fromConfig config |> .icons) idx

        symbolRef =
            [ TypedSvg.use [ xlinkHref <| "#" ++ symbolToId symbol ] [] ]

        st styles =
            Helpers.mergeStyles styles styleStr
                |> style
    in
    if showIcons config then
        case symbol of
            Triangle c ->
                [ g
                    [ transform [ Translate (w + symbolGap) y_ ]
                    , class [ "symbol" ]
                    , st c.styles
                    ]
                    symbolRef
                ]

            Circle c ->
                [ g
                    [ transform [ Translate (w + symbolGap) y_ ]
                    , class [ "symbol" ]
                    , st c.styles
                    ]
                    symbolRef
                ]

            Corner c ->
                [ g
                    [ transform [ Translate (w + symbolGap) y_ ]
                    , class [ "symbol" ]
                    , st c.styles
                    ]
                    symbolRef
                ]

            Custom c ->
                let
                    gap =
                        if c.useGap then
                            symbolGap

                        else
                            0
                in
                [ g
                    [ transform [ Translate (w + gap) y_ ]
                    , class [ "symbol" ]
                    , st c.styles
                    ]
                    symbolRef
                ]

            NoSymbol ->
                []

    else
        []


verticalSymbol :
    Config
    -> { idx : Int, w : Float, y_ : Float, x_ : Float, styleStr : String }
    -> List (Svg msg)
verticalSymbol config { idx, w, y_, x_, styleStr } =
    --TODO: merge styles
    let
        symbol =
            getSymbolByIndex (fromConfig config |> .icons) idx

        symbolRef =
            [ TypedSvg.use [ xlinkHref <| "#" ++ symbolToId symbol ] [] ]

        st styles =
            Helpers.mergeStyles styles styleStr
                |> style
    in
    if showIcons config then
        case symbol of
            Triangle c ->
                [ g
                    [ transform [ Translate x_ (y_ - w - symbolGap) ]
                    , class [ "symbol" ]
                    , st c.styles
                    ]
                    symbolRef
                ]

            Circle c ->
                [ g
                    [ transform [ Translate x_ (y_ - w - symbolGap) ]
                    , class [ "symbol" ]
                    , st c.styles
                    ]
                    symbolRef
                ]

            Corner c ->
                [ g
                    [ transform [ Translate x_ (y_ - w - symbolGap) ]
                    , class [ "symbol" ]
                    , st c.styles
                    ]
                    symbolRef
                ]

            Custom c ->
                let
                    space =
                        symbolCustomSpace Vertical w c

                    gap =
                        if c.useGap then
                            symbolGap

                        else
                            0
                in
                [ g
                    [ transform [ Translate x_ (y_ - space - gap) ]
                    , class [ "symbol" ]
                    , st c.styles
                    ]
                    symbolRef
                ]

            NoSymbol ->
                []

    else
        []


symbolsToSymbolElements : Orientation -> BandScale String -> List Symbol -> List (Svg msg)
symbolsToSymbolElements orientation bandSingleScale symbols =
    let
        localDimension =
            Scale.bandwidth bandSingleScale
    in
    symbols
        |> List.map
            (\symbol ->
                let
                    s =
                        TypedSvg.symbol
                            [ Html.Attributes.id (symbolToId symbol) ]
                in
                case symbol of
                    Circle conf ->
                        --FIXME
                        s [ circle_ (conf.size |> Maybe.withDefault localDimension) ]

                    Custom conf ->
                        let
                            scaleFactor =
                                case orientation of
                                    Vertical ->
                                        localDimension / conf.viewBoxWidth

                                    Horizontal ->
                                        localDimension / conf.viewBoxHeight
                        in
                        s [ custom scaleFactor conf ]

                    Corner conf ->
                        s [ corner (conf.size |> Maybe.withDefault localDimension) ]

                    Triangle conf ->
                        s [ triangle (conf.size |> Maybe.withDefault localDimension) ]

                    NoSymbol ->
                        s []
            )


bandXAxis : ConfigStruct -> BandScale String -> List (Svg msg)
bandXAxis c bandScale =
    --TODO: lots of repetitions
    if c.showXAxis == True then
        case ( c.orientation, c.axisXBand ) of
            ( Vertical, ChartAxis.Bottom attributes ) ->
                [ g
                    [ transform [ Translate c.margin.left (c.height + bottomGap + c.margin.top) ]
                    , class [ "axis", "axis--horizontal" ]
                    ]
                    [ Axis.bottom attributes (Scale.toRenderable identity bandScale) ]
                ]

            ( Vertical, ChartAxis.Top attributes ) ->
                [ g
                    [ transform [ Translate c.margin.left c.margin.top ]
                    , class [ "axis", "axis--horizontal" ]
                    ]
                    [ Axis.top attributes (Scale.toRenderable identity bandScale) ]
                ]

            ( Horizontal, ChartAxis.Bottom attributes ) ->
                [ g
                    [ transform [ Translate (c.margin.left - leftGap) c.margin.top ]
                    , class [ "axis", "axis--vertical" ]
                    ]
                    [ Axis.left attributes (Scale.toRenderable identity bandScale) ]
                ]

            ( Horizontal, ChartAxis.Top attributes ) ->
                --FIXME
                [ g
                    [ transform [ Translate (c.margin.left - leftGap) c.margin.top ]
                    , class [ "axis", "axis--vertical" ]
                    ]
                    [ Axis.right attributes (Scale.toRenderable identity bandScale) ]
                ]

    else
        []


bandGroupedYAxis : ConfigStruct -> Float -> ContinuousScale Float -> List (Svg msg)
bandGroupedYAxis c iconOffset continuousScale =
    if c.showYAxis == True then
        case ( c.orientation, c.axisYContinuous ) of
            ( Vertical, ChartAxis.Left attributes ) ->
                [ g
                    [ transform
                        [ Translate (c.margin.left - leftGap)
                            (iconOffset + c.margin.top)
                        ]
                    , class [ "axis", "axis--vertical" ]
                    ]
                    [ Axis.left attributes continuousScale ]
                ]

            ( Vertical, ChartAxis.Right attributes ) ->
                [ g
                    [ transform
                        [ Translate
                            (c.width + c.margin.left + leftGap)
                            (iconOffset + c.margin.top)
                        ]
                    , class [ "axis", "axis--vertical" ]
                    ]
                    [ Axis.right attributes continuousScale ]
                ]

            ( Vertical, ChartAxis.Grid attributes ) ->
                let
                    rightAttrs =
                        attributes
                            ++ [ Axis.tickSizeInner c.width
                               , Axis.tickPadding (c.margin.right + c.margin.left)
                               , Axis.tickSizeOuter 0
                               ]

                    leftAttrs =
                        attributes
                            ++ [ Axis.tickSizeInner 0
                               ]
                in
                [ g
                    [ transform
                        [ Translate (c.margin.left - leftGap)
                            (iconOffset + c.margin.top)
                        ]
                    , class [ "axis", "axis--vertical" ]
                    ]
                    [ Axis.left leftAttrs continuousScale ]
                , g
                    [ transform [ Translate (c.margin.left - leftGap) c.margin.top ]
                    , class [ "axis", "axis--y", "axis--y-right" ]
                    ]
                    [ Axis.right rightAttrs continuousScale ]
                ]

            ( Horizontal, ChartAxis.Left attributes ) ->
                [ g
                    [ transform [ Translate c.margin.left (c.height + bottomGap + c.margin.top) ]
                    , class [ "axis", "axis--horizontal" ]
                    ]
                    [ Axis.bottom attributes continuousScale ]
                ]

            ( Horizontal, ChartAxis.Right attributes ) ->
                [ g
                    [ transform [ Translate c.margin.left (c.height + bottomGap + c.margin.top) ]
                    , class [ "axis", "axis--horizontal" ]
                    ]
                    [ Axis.bottom attributes continuousScale ]
                ]

            ( Horizontal, ChartAxis.Grid attributes ) ->
                let
                    bottomAttrs =
                        attributes
                            ++ [ Axis.tickSizeInner 0
                               ]

                    topAttrs =
                        attributes
                            ++ [ Axis.tickSizeInner c.height
                               , Axis.tickSizeOuter 0
                               , Axis.tickPadding (c.margin.top + c.margin.bottom)
                               ]
                in
                [ g
                    [ transform [ Translate c.margin.left (c.height + bottomGap + c.margin.top) ]
                    , class [ "axis", "axis--horizontal" ]
                    ]
                    [ Axis.bottom bottomAttrs continuousScale ]
                , g
                    [ transform [ Translate c.margin.left c.margin.top ]
                    , class [ "axis", "axis--y", "axis--y-right" ]
                    ]
                    [ Axis.bottom topAttrs continuousScale ]
                ]

    else
        []



-- HISTOGRAM


renderHistogram : ( List (Histogram.Bin Float Float), Config ) -> Html msg
renderHistogram ( histogram, config ) =
    let
        c =
            fromConfig config

        m =
            c.margin

        w =
            c.width

        h =
            c.height

        outerW =
            w + m.left + m.right

        outerH =
            h + m.top + m.bottom

        domain : ( Float, Float )
        domain =
            case c.histogramDomain of
                Just d ->
                    d

                Nothing ->
                    calculateHistogramDomain histogram

        xRange =
            getBandGroupRange config w h

        xScale : ContinuousScale Float
        xScale =
            Scale.linear xRange domain

        yRange =
            ( h, 0 )

        yScaleFromBins : List (Bin Float Float) -> ContinuousScale Float
        yScaleFromBins bins =
            List.map .length bins
                |> List.maximum
                |> Maybe.withDefault 0
                |> toFloat
                |> Tuple.pair 0
                |> Scale.linear yRange

        xAxis : List (Svg msg)
        xAxis =
            [ g
                [ transform [ Translate c.margin.left (c.height + bottomGap + c.margin.top) ]
                , class [ "axis", "axis--horizontal" ]
                ]
                [ Axis.bottom (ChartAxis.xAxisAttributes c.axisXContinuous) xScale ]
            ]

        yAxis : List (Bin Float Float) -> List (Svg msg)
        yAxis bins =
            case c.axisYContinuous of
                ChartAxis.Left attributes ->
                    [ g
                        [ transform [ Translate (c.margin.left - leftGap) c.margin.top ]
                        , class [ "axis", "axis--vertical" ]
                        ]
                        [ Axis.left attributes (yScaleFromBins bins) ]
                    ]

                ChartAxis.Grid _ ->
                    [ text "TODO" ]

                ChartAxis.Right _ ->
                    [ text "TODO" ]

        tableHeadings =
            Table.Headings [ "length", "x0", "x1" ]

        tableData =
            histogram
                |> List.map
                    (\d ->
                        [ d.length |> String.fromInt
                        , d.x0 |> String.fromFloat
                        , d.x1 |> String.fromFloat
                        ]
                    )

        table =
            Table.generate tableData
                |> Table.setColumnHeadings tableHeadings
                |> Table.view

        tableEl =
            Helpers.invisibleFigcaption
                [ case table of
                    Ok table_ ->
                        Html.div [] [ table_ ]

                    Err error ->
                        Html.text (Table.errorToString error)
                ]

        svgElAttrs =
            [ viewBox 0 0 outerW outerH
            , width outerW
            , height outerH
            , role "img"
            , ariaLabelledby "title desc"
            ]
                ++ ariaLabelledbyContent c

        svgEl =
            svg svgElAttrs <|
                descAndTitle c
                    ++ xAxis
                    ++ yAxis histogram
                    ++ [ g
                            [ transform [ Translate m.left m.top ]
                            , class [ "series" ]
                            ]
                         <|
                            List.map (histogramColumn config h xScale (yScaleFromBins histogram)) histogram
                       ]
    in
    case c.accessibilityContent of
        AccessibilityTable ->
            Html.div []
                [ Html.figure
                    []
                    [ svgEl, tableEl ]
                ]

        AccessibilityNone ->
            Html.div [] [ svgEl ]


histogramColumn :
    Config
    -> Float
    -> ContinuousScale Float
    -> ContinuousScale Float
    -> Bin Float Float
    -> Svg msg
histogramColumn config h xScale yScale { length, x0, x1 } =
    let
        c =
            fromConfig config

        styles =
            Helpers.mergeStyles
                [ ( "stroke", "#fff" ), ( "stroke-width", String.fromFloat strokeWidth ++ "px" ) ]
                (colorStyle c Nothing Nothing)
                |> Helpers.mergeStyles c.coreStyle
                |> style
    in
    rect
        [ x <| Scale.convert xScale x0
        , y <| Scale.convert yScale (toFloat length)
        , width <| Scale.convert xScale x1 - Scale.convert xScale x0
        , height <| h - Scale.convert yScale (toFloat length)
        , styles
        ]
        (columnTitleText config ( "", toFloat length ))



-- CONSTANTS


labelGap : Float
labelGap =
    2


strokeWidth : Float
strokeWidth =
    0.5



-- LABEL HELPERS


getStackedLabel : Int -> List String -> String
getStackedLabel idx l =
    List.Extra.getAt idx l
        |> Maybe.withDefault ""


stackedColumnTitleText : ConfigStruct -> Int -> List String -> Float -> List (Svg msg)
stackedColumnTitleText c idx labels value =
    let
        ordinalValue =
            getStackedLabel idx labels
    in
    case c.showColumnTitle of
        StackedColumnTitle formatter ->
            [ TypedSvg.title [] [ text (ordinalValue ++ ": " ++ formatter value) ] ]

        YColumnTitle formatter ->
            [ TypedSvg.title [] [ value |> formatter |> text ] ]

        XOrdinalColumnTitle ->
            [ TypedSvg.title [] [ text ordinalValue ] ]

        _ ->
            []


columnTitleText : Config -> PointBand -> List (Svg msg)
columnTitleText config point =
    let
        ( xVal, yVal ) =
            point
    in
    case fromConfig config |> .showColumnTitle of
        YColumnTitle formatter ->
            [ TypedSvg.title [] [ yVal |> formatter |> text ] ]

        XOrdinalColumnTitle ->
            [ TypedSvg.title [] [ text xVal ] ]

        _ ->
            []


horizontalLabel : Config -> Float -> Float -> PointBand -> List (Svg msg)
horizontalLabel config xPos yPos point =
    let
        ( xVal, yVal ) =
            point

        txt =
            text_
                [ y yPos
                , x xPos
                , textAnchor AnchorStart
                , dominantBaseline DominantBaselineMiddle
                ]
    in
    case fromConfig config |> .showLabels of
        YLabel formatter ->
            [ txt [ text (yVal |> formatter) ] ]

        XOrdinalLabel ->
            [ txt [ text xVal ] ]

        _ ->
            []
