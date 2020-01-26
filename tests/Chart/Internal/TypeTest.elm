module Chart.Internal.TypeTest exposing (suite)

import Chart.Internal.Symbol exposing (Symbol(..))
import Chart.Internal.Type exposing (..)
import Expect exposing (Expectation)
import Test exposing (..)
import Time exposing (Posix)


type alias Data =
    { x : Posix, y : Float, groupLabel : String }


suite : Test
suite =
    describe "The Type module"
        [ describe "getDomainBandFromData"
            [ test "with DomainBand" <|
                \_ ->
                    let
                        data : DataBand
                        data =
                            toDataBand
                                [ { groupLabel = Just "CA", points = [ ( "a", 10 ), ( "b", 20 ) ] }
                                , { groupLabel = Just "TX", points = [ ( "a", 11 ), ( "b", 21 ) ] }
                                ]

                        expected : DomainBandStruct
                        expected =
                            { bandGroup = Just [ "CA", "TX" ], bandSingle = Just [ "a", "b" ], linear = Just ( 0, 21 ) }
                    in
                    Expect.equal (getDomainBandFromData data defaultConfig) expected
            , test "with DomainBand complex example" <|
                \_ ->
                    let
                        data : DataBand
                        data =
                            toDataBand
                                [ { groupLabel = Just "16-24"
                                  , points =
                                        [ ( "once per month", 21.1 )
                                        , ( "once per week", 15 )
                                        , ( "three times per week", 7.8 )
                                        , ( "five times per week", 4.9 )
                                        ]
                                  }
                                , { groupLabel = Just "25-34"
                                  , points =
                                        [ ( "once per month", 19 )
                                        , ( "once per week", 13.1 )
                                        , ( "three times per week", 7 )
                                        , ( "five times per week", 4.5 )
                                        ]
                                  }
                                , { groupLabel = Just "35-44"
                                  , points =
                                        [ ( "once per month", 21.9 )
                                        , ( "once per week", 15.1 )
                                        , ( "three times per week", 7.2 )
                                        , ( "five times per week", 4.2 )
                                        ]
                                  }
                                ]

                        expected : DomainBandStruct
                        expected =
                            { bandGroup = Just [ "16-24", "25-34", "35-44" ]
                            , bandSingle =
                                Just
                                    [ "once per month"
                                    , "once per week"
                                    , "three times per week"
                                    , "five times per week"
                                    ]
                            , linear = Just ( 0, 21.9 )
                            }
                    in
                    Expect.equal (getDomainBandFromData data defaultConfig) expected
            ]
        , describe "getDomainLinearFromData"
            [ test "with default domain" <|
                \_ ->
                    let
                        data : List DataGroupLinear
                        data =
                            [ { groupLabel = Just "CA", points = [ ( 5, 10 ), ( 6, 20 ) ] }
                            , { groupLabel = Just "TX", points = [ ( 5, 11 ), ( 6, 21 ) ] }
                            ]

                        expected : DomainLinearStruct
                        expected =
                            { horizontal = Just ( 5, 6 ), vertical = Just ( 0, 21 ) }
                    in
                    Expect.equal (getDomainLinearFromData defaultConfig data) expected
            , test "with Y domain manually set" <|
                \_ ->
                    let
                        linearDomain : LinearDomain
                        linearDomain =
                            ( 0, 30 )

                        config : Config
                        config =
                            defaultConfig
                                |> setDomainLinearAndTimeVertical linearDomain

                        data : List DataGroupLinear
                        data =
                            [ { groupLabel = Just "CA"
                              , points =
                                    [ ( 1, 10 )
                                    , ( 2, 20 )
                                    ]
                              }
                            , { groupLabel = Just "TX"
                              , points =
                                    [ ( 1, 11 )
                                    , ( 2, 21 )
                                    ]
                              }
                            ]

                        expected : DomainLinearStruct
                        expected =
                            { horizontal = Just ( 1, 2 )
                            , vertical = Just ( 0, 30 )
                            }
                    in
                    Expect.equal (getDomainLinearFromData config data) expected
            ]
        , describe "getDomainTimeFromData"
            [ test "with default domain" <|
                \_ ->
                    let
                        data : List DataGroupTime
                        data =
                            [ { groupLabel = Just "CA"
                              , points =
                                    [ ( Time.millisToPosix 1579275175634, 10 )
                                    , ( Time.millisToPosix 1579285175634, 20 )
                                    ]
                              }
                            , { groupLabel = Just "TX"
                              , points =
                                    [ ( Time.millisToPosix 1579275175634, 11 )
                                    , ( Time.millisToPosix 1579285175634, 21 )
                                    ]
                              }
                            ]

                        expected : DomainTimeStruct
                        expected =
                            { horizontal = Just ( Time.millisToPosix 1579275175634, Time.millisToPosix 1579285175634 )
                            , vertical = Just ( 0, 21 )
                            }
                    in
                    Expect.equal (getDomainTimeFromData defaultConfig data) expected
            , test "with Y domain manually set" <|
                \_ ->
                    let
                        linearDomain : LinearDomain
                        linearDomain =
                            ( 0, 30 )

                        config : Config
                        config =
                            defaultConfig
                                |> setDomainLinearAndTimeVertical linearDomain

                        data : List DataGroupTime
                        data =
                            [ { groupLabel = Just "CA"
                              , points =
                                    [ ( Time.millisToPosix 1579275175634, 10 )
                                    , ( Time.millisToPosix 1579285175634, 20 )
                                    ]
                              }
                            , { groupLabel = Just "TX"
                              , points =
                                    [ ( Time.millisToPosix 1579275175634, 11 )
                                    , ( Time.millisToPosix 1579285175634, 21 )
                                    ]
                              }
                            ]

                        expected : DomainTimeStruct
                        expected =
                            { horizontal = Just ( Time.millisToPosix 1579275175634, Time.millisToPosix 1579285175634 )
                            , vertical = Just ( 0, 30 )
                            }
                    in
                    Expect.equal (getDomainTimeFromData config data) expected
            ]
        , describe "groupedLayoutConfig"
            [ test "showIcons is False" <|
                \_ ->
                    Expect.equal (showIcons defaultGroupedConfig) False
            , test "showIcons is True" <|
                \_ ->
                    Expect.equal (showIcons (defaultGroupedConfig |> setIcons [ Triangle "id" ])) True
            ]
        , describe "symbolCustomSpace"
            [ test "horizontal, icon ratio < 1" <|
                \_ ->
                    let
                        orientation : Orientation
                        orientation =
                            Horizontal

                        localDimension : Float
                        localDimension =
                            5.0

                        customSymbolConf : Chart.Internal.Symbol.CustomSymbolConf
                        customSymbolConf =
                            { identifier = "x"
                            , width = 110
                            , height = 100
                            , paths = []
                            , useGap = False
                            }

                        expected : Float
                        expected =
                            5.5
                    in
                    Expect.within (Expect.Absolute 0.001)
                        (symbolCustomSpace orientation localDimension customSymbolConf)
                        expected
            , test "horizontal, icon ratio >= 1" <|
                \_ ->
                    let
                        orientation : Orientation
                        orientation =
                            Horizontal

                        localDimension : Float
                        localDimension =
                            5.0

                        customSymbolConf : Chart.Internal.Symbol.CustomSymbolConf
                        customSymbolConf =
                            { identifier = "x"
                            , width = 100
                            , height = 110
                            , paths = []
                            , useGap = False
                            }

                        expected : Float
                        expected =
                            4.5454
                    in
                    Expect.within (Expect.Absolute 0.001)
                        (symbolCustomSpace orientation localDimension customSymbolConf)
                        expected
            , test "vertical" <|
                \_ ->
                    let
                        orientation : Orientation
                        orientation =
                            Vertical

                        localDimension : Float
                        localDimension =
                            5.0

                        customSymbolConf : Chart.Internal.Symbol.CustomSymbolConf
                        customSymbolConf =
                            { identifier = "x"
                            , width = 110
                            , height = 100
                            , paths = []
                            , useGap = False
                            }

                        expected : Float
                        expected =
                            4.5454
                    in
                    Expect.within (Expect.Absolute 0.001)
                        (symbolCustomSpace orientation localDimension customSymbolConf)
                        expected
            , test "vertical 2" <|
                \_ ->
                    let
                        orientation : Orientation
                        orientation =
                            Vertical

                        localDimension : Float
                        localDimension =
                            5.0

                        customSymbolConf : Chart.Internal.Symbol.CustomSymbolConf
                        customSymbolConf =
                            { identifier = "x"
                            , width = 100
                            , height = 110
                            , paths = []
                            , useGap = False
                            }

                        expected : Float
                        expected =
                            5.5
                    in
                    Expect.within (Expect.Absolute 0.001)
                        (symbolCustomSpace orientation localDimension customSymbolConf)
                        expected
            ]
        , describe "externalToDataLinearGroup"
            [ test "with time data" <|
                \_ ->
                    let
                        t1 =
                            Time.millisToPosix 1579275175634

                        t2 =
                            Time.millisToPosix 1579285175634

                        data : ExternalData Data
                        data =
                            [ { groupLabel = "A"
                              , x = t1
                              , y = 10
                              }
                            , { groupLabel = "B"
                              , x = t1
                              , y = 13
                              }
                            , { groupLabel = "A"
                              , x = t2
                              , y = 16
                              }
                            , { groupLabel = "B"
                              , x = t2
                              , y = 23
                              }
                            ]
                                |> toExternalData

                        accessor : AccessorLinearGroup Data
                        accessor =
                            AccessorTime (AccessorTimeStruct .groupLabel .x .y)

                        expected : DataLinearGroup
                        expected =
                            DataTime
                                [ { groupLabel = Just "A"
                                  , points = [ ( t1, 10 ), ( t2, 16 ) ]
                                  }
                                , { groupLabel = Just "B"
                                  , points = [ ( t1, 13 ), ( t2, 23 ) ]
                                  }
                                ]

                        result : DataLinearGroup
                        result =
                            externalToDataLinearGroup data accessor
                    in
                    Expect.equal result expected
            ]
        ]
