module Chart.Type exposing
    ( Axis(..)
    , Config
    , ConfigStruct
    , Data(..)
    , DataGroupBand
    , Direction(..)
    , Domain(..)
    , Layout(..)
    , Margin
    , Orientation(..)
    , PointBand
    , adjustLinearRange
    , defaultConfig
    , defaultHeight
    , defaultLayout
    , defaultMargin
    , defaultOrientation
    , defaultWidth
    , fromConfig
    , fromDataBand
    , fromDomainBand
    , getBandGroupRange
    , getBandSingleRange
    , getDataDepth
    , getDomain
    , getDomainFromData
    , getHeight
    , getLinearRange
    , getMargin
    , getOffset
    , getWidth
    , setDimensions
    , setDomain
    , setHeight
    , setLayout
    , setMargin
    , setOrientation
    , setShowColumnLabels
    , setShowSymbols
    , setSymbols
    , setWidth
    , symbolCustomSpace
    , symbolSpace
    , toConfig
    )

import Chart.Symbol exposing (Symbol(..), symbolGap)
import Scale exposing (BandScale)
import Set
import Shape exposing (StackConfig, StackResult)
import TypedSvg.Core exposing (Svg)


type Orientation
    = Vertical
    | Horizontal


type Layout
    = Stacked Direction
    | Grouped


type Direction
    = Diverging
    | NoDirection


type Axis
    = X
    | Y


type alias LinearDomain =
    ( Float, Float )


type alias BandDomain =
    List String


type alias DomainBandStruct =
    { bandGroup : BandDomain, bandSingle : BandDomain, linear : LinearDomain }


type Domain
    = DomainBand DomainBandStruct


type alias PointBand =
    ( String, Float )


type alias DataGroupBand =
    { groupLabel : Maybe String, points : List PointBand }


type Data
    = DataBand (List DataGroupBand)


type alias Range =
    ( Float, Float )


type alias Margin =
    { top : Float
    , right : Float
    , bottom : Float
    , left : Float
    }


type alias ConfigStruct =
    { domain : Domain
    , height : Float
    , layout : Layout
    , margin : Margin
    , orientation : Orientation
    , showColumnLabels : Bool
    , showSymbols : Bool
    , symbols : List (Symbol String)
    , width : Float
    }


defaultConfig : Config
defaultConfig =
    toConfig
        { domain = DomainBand { bandGroup = [], bandSingle = [], linear = ( 0, 0 ) }
        , height = defaultHeight
        , layout = defaultLayout
        , margin = defaultMargin
        , orientation = defaultOrientation
        , showColumnLabels = False
        , showSymbols = False
        , symbols = []
        , width = defaultWidth
        }


type Config
    = Config ConfigStruct


toConfig : ConfigStruct -> Config
toConfig config =
    Config config


fromConfig : Config -> ConfigStruct
fromConfig (Config config) =
    config



-- DEFAULTS


defaultLayout : Layout
defaultLayout =
    Grouped


defaultOrientation : Orientation
defaultOrientation =
    Vertical


defaultWidth : Float
defaultWidth =
    600


defaultHeight : Float
defaultHeight =
    400


defaultMargin : Margin
defaultMargin =
    { top = 1
    , right = 20
    , bottom = 20
    , left = 30
    }



-- SETTERS


setHeight : Float -> ( Data, Config ) -> ( Data, Config )
setHeight height ( data, config ) =
    let
        c =
            fromConfig config

        m =
            c.margin
    in
    ( data, toConfig { c | height = height - m.top - m.bottom } )


setLayout : Layout -> ( Data, Config ) -> ( Data, Config )
setLayout layout ( data, config ) =
    let
        c =
            fromConfig config
    in
    ( data, toConfig { c | layout = layout } )


setOrientation : Orientation -> ( Data, Config ) -> ( Data, Config )
setOrientation orientation ( data, config ) =
    let
        c =
            fromConfig config
    in
    ( data, toConfig { c | orientation = orientation } )


setWidth : Float -> ( Data, Config ) -> ( Data, Config )
setWidth width ( data, config ) =
    let
        c =
            fromConfig config

        m =
            c.margin
    in
    ( data, toConfig { c | width = width - m.left - m.right } )


setMargin : Margin -> ( Data, Config ) -> ( Data, Config )
setMargin margin ( data, config ) =
    let
        c =
            fromConfig config
    in
    ( data, toConfig { c | margin = margin } )


setDimensions : { margin : Margin, width : Float, height : Float } -> ( Data, Config ) -> ( Data, Config )
setDimensions { margin, width, height } ( data, config ) =
    let
        c =
            fromConfig config

        m =
            margin
    in
    ( data
    , toConfig
        { c
            | width = width - m.left - m.right
            , height = height - m.top - m.bottom
            , margin = margin
        }
    )


setDomain : Domain -> ( Data, Config ) -> ( Data, Config )
setDomain domain ( data, config ) =
    let
        c =
            fromConfig config
    in
    ( data, toConfig { c | domain = domain } )


setShowColumnLabels : Bool -> ( Data, Config ) -> ( Data, Config )
setShowColumnLabels bool ( data, config ) =
    let
        c =
            fromConfig config
    in
    ( data, toConfig { c | showColumnLabels = bool } )


setShowSymbols : Bool -> ( Data, Config ) -> ( Data, Config )
setShowSymbols bool ( data, config ) =
    let
        c =
            fromConfig config
    in
    ( data, toConfig { c | showSymbols = bool } )


setSymbols : List (Symbol String) -> ( Data, Config ) -> ( Data, Config )
setSymbols all ( data, config ) =
    let
        c =
            fromConfig config
    in
    ( data, toConfig { c | symbols = all } )



-- GETTERS


getMargin : Config -> Margin
getMargin config =
    fromConfig config |> .margin


getHeight : Config -> Float
getHeight config =
    fromConfig config |> .height


getWidth : Config -> Float
getWidth config =
    fromConfig config |> .width


getDomain : Config -> Domain
getDomain config =
    fromConfig config |> .domain


getDomainFromData : Data -> Domain
getDomainFromData data =
    case data of
        DataBand d ->
            DomainBand
                { bandGroup =
                    d
                        |> List.map .groupLabel
                        |> List.indexedMap (\i g -> g |> Maybe.withDefault (String.fromInt i))
                , bandSingle =
                    d
                        |> List.map .points
                        |> List.concat
                        |> List.map Tuple.first
                        |> Set.fromList
                        |> Set.toList
                , linear =
                    d
                        |> List.map .points
                        |> List.concat
                        |> List.map Tuple.second
                        |> (\dd -> ( 0, List.maximum dd |> Maybe.withDefault 0 ))
                }


fromDomainBand : Domain -> DomainBandStruct
fromDomainBand domain =
    case domain of
        DomainBand d ->
            d


fromDataBand : Data -> List DataGroupBand
fromDataBand data =
    case data of
        DataBand d ->
            d


getDataDepth : Data -> Int
getDataDepth data =
    data
        |> fromDataBand
        |> List.map .points
        |> List.head
        |> Maybe.withDefault []
        |> List.length


getBandGroupRange : Config -> Float -> Float -> ( Float, Float )
getBandGroupRange config width height =
    let
        orientation =
            fromConfig config |> .orientation
    in
    case orientation of
        Horizontal ->
            ( height, 0 )

        Vertical ->
            ( 0, width )


getBandSingleRange : Config -> Float -> ( Float, Float )
getBandSingleRange config value =
    let
        orientation =
            fromConfig config |> .orientation
    in
    case orientation of
        Horizontal ->
            ( floor value |> toFloat, 0 )

        Vertical ->
            ( 0, floor value |> toFloat )


getLinearRange : Config -> Float -> Float -> BandScale String -> ( Float, Float )
getLinearRange config width height bandScale =
    let
        c =
            fromConfig config

        orientation =
            c.orientation

        layout =
            c.layout
    in
    case orientation of
        Horizontal ->
            case layout of
                Grouped ->
                    if c.showSymbols then
                        -- Here we are leaving space for the symbol
                        ( 0, width - symbolGap - symbolSpace c.orientation bandScale c.symbols )

                    else
                        ( 0, width )

                Stacked _ ->
                    ( width, 0 )

        Vertical ->
            case layout of
                Grouped ->
                    if c.showSymbols then
                        -- Here we are leaving space for the symbol
                        ( height - symbolGap - symbolSpace c.orientation bandScale c.symbols, 0 )

                    else
                        ( height, 0 )

                Stacked _ ->
                    ( height, 0 )


adjustLinearRange : Config -> Int -> ( Float, Float ) -> ( Float, Float )
adjustLinearRange config stackedDepth ( a, b ) =
    let
        c =
            fromConfig config

        orientation =
            c.orientation

        layout =
            c.layout
    in
    case orientation of
        Horizontal ->
            case layout of
                Grouped ->
                    ( a, b )

                Stacked _ ->
                    ( a + toFloat stackedDepth, b )

        Vertical ->
            ( a - toFloat stackedDepth, b )


getOffset : Config -> List (List ( Float, Float )) -> List (List ( Float, Float ))
getOffset config =
    case fromConfig config |> .layout of
        Stacked direction ->
            case direction of
                Diverging ->
                    Shape.stackOffsetDiverging

                NoDirection ->
                    Shape.stackOffsetNone

        Grouped ->
            Shape.stackOffsetNone


symbolSpace : Orientation -> BandScale String -> List (Symbol String) -> Float
symbolSpace orientation bandSingleScale symbols =
    let
        localDimension =
            Scale.bandwidth bandSingleScale |> floor |> toFloat
    in
    symbols
        |> List.map
            (\symbol ->
                case symbol of
                    Circle _ ->
                        localDimension / 2

                    Custom conf ->
                        symbolCustomSpace orientation localDimension conf

                    Corner _ ->
                        localDimension

                    Triangle _ ->
                        localDimension
            )
        |> List.maximum
        |> Maybe.withDefault 0


symbolCustomSpace : Orientation -> Float -> Chart.Symbol.CustomSymbolConf -> Float
symbolCustomSpace orientation localDimension conf =
    let
        iconRatio =
            conf.height / conf.width
    in
    case orientation of
        Horizontal ->
            let
                scalingFactor =
                    localDimension / conf.height
            in
            scalingFactor * conf.width

        Vertical ->
            let
                scalingFactor =
                    localDimension / conf.width
            in
            scalingFactor * conf.height
