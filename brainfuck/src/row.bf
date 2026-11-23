# row bf: is a view class or one of its superclasses a Gmail ad row
# Normative specification: docs/policy/row md ABI: docs/BRAINFUCK_ARCHITECTURE md
# Serves OP_AD_ROW Per class name two machines run over the name codes:
# PS follows either ads package prefix and SS follows every suffix of the row name
#
# Tape layout
# %cell MAJ 0
# %cell OP 1
# %cell ID0 2
# %cell ID1 3
# %cell J 4
# %cell UNH 5
# %cell N 6
# %cell K 7
# %cell CH 8
# %cell PS 9
# %cell NPS 10
# %cell SS 11
# %cell NSS 12
# %cell AD 13
# %cell t0 16   scratch; zero whenever free
# %cell t1 17   scratch; zero whenever free
# %cell t2 18   scratch; zero whenever free
# %cell t3 19   scratch; zero whenever free
# %cell t4 20   scratch; zero whenever free
# %cell t5 21   scratch; zero whenever free
# %cell t6 22   scratch; zero whenever free
# %cell t7 23   scratch; zero whenever free
# %cell t8 24   scratch; zero whenever free
# %cell t9 25   scratch; zero whenever free
# %cell t10 26   scratch; zero whenever free
# %cell t11 27   scratch; zero whenever free
# %cell t12 28   scratch; zero whenever free
# %cell t13 29   scratch; zero whenever free
# %cell t14 30   scratch; zero whenever free
# %cell t15 31   scratch; zero whenever free

# request header: major minor opcode flags length request id
, @MAJ                                # read MAJ
>>>> , @J                             # minor is not checked
[-] @J                                # clear J
<<< , @OP                             # read OP
>>> , @J                              # flags ignored; payload layout is fixed per opcode
[-] @J                                # clear J
, @J                                  # length low ignored; payload layout is fixed per opcode
[-] @J                                # clear J
, @J                                  # length high ignored; payload layout is fixed per opcode
[-] @J                                # clear J
<< , @ID0                             # request id low
> , @ID1                              # request id high

# ABI major version
<<< [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @MAJ  # copy MAJ to t0
>>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t1  # move t1 into MAJ
< - @t0                               # subtract 1
>> + @t2                              # assume equal
<< [ @t0                              # if different
    >> [-] @t2                        # not equal
    # response header
    > + @t3                           # major
    . @t3                             # write t3
    [-] @t3                           # clear t3
    . @t3                             # minor
    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>>>> ~18+ >+ <<<<<<<<<< <<<<<<<<< ~19] @OP  # copy OP to t3
    >>>>>>>>>> >>>>>>>>> ~19 [- <<<<<<<<<< <<<<<<<<< ~19+ >>>>>>>>>> >>>>>>>>> ~19] @t4  # move t4 into OP
    < ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++ ~128 @t3  # opcode with the response bit
    . @t3                             # write t3
    [-] @t3                           # clear t3
    + @t3                             # status
    . @t3                             # status
    [-] @t3                           # clear t3
    . @t3                             # payload length low
    [-] @t3                           # clear t3
    . @t3                             # payload length high
    <<<<<<<<<< <<<<<<< ~17 . @ID0     # echo request id
    > . @ID1                          # write ID1
    >>>>>>>>>> >>> ~13 [-] @t0        # clear t0
] @t0
>> [ @t2                              # if equal
    <<<<<<<<<< <<< ~13 [-] @UNH       # UNH becomes 1
    + @UNH                            # UNH plus 1
    # opcode 16
    <<<< [- >>>>>>>>>> >>>>>>>> ~18+ >+ <<<<<<<<<< <<<<<<<<< ~19] @OP  # copy OP to t3
    >>>>>>>>>> >>>>>>>>> ~19 [- <<<<<<<<<< <<<<<<<<< ~19+ >>>>>>>>>> >>>>>>>>> ~19] @t4  # move t4 into OP
    < ---------- ------ ~16 @t3       # subtract 16
    >> + @t5                          # assume equal
    << [ @t3                          # if different
        >> [-] @t5                    # not equal
        << [-] @t3                    # clear t3
    ] @t3
    >> [ @t5                          # if equal
        <<<<<<<<<< <<<<<< ~16 [-] @UNH  # clear UNH
        # response header
        >>>>>>>>>> >>>>>>> ~17 + @t6  # major
        . @t6                         # write t6
        [-] @t6                       # clear t6
        . @t6                         # minor
        <<<<<<<<<< <<<<<<<<<< < ~21 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @OP  # copy OP to t6
        >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t7  # move t7 into OP
        < ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++ ~128 @t6  # opcode with the response bit
        . @t6                         # write t6
        [-] @t6                       # clear t6
        . @t6                         # status
        [-] @t6                       # clear t6
        + @t6                         # payload length low
        . @t6                         # payload length low
        [-] @t6                       # clear t6
        . @t6                         # payload length high
        <<<<<<<<<< <<<<<<<<<< ~20 . @ID0  # echo request id
        > . @ID1                      # write ID1
        >>> , @N                      # number of class names
        [ @N                          # each class; the view class first
            - @N                      # N minus 1
            > , @K                    # first chunk length of the class name
            [ @K                      # each chunk
                [ @K                  # each character of the chunk
                    - @K              # K minus 1
                    > , @CH           # read CH
                    # prefix: state counts matched characters; 26 is a match and 27 is dead;
                    # 28 and up follow the apps branch after state 19
                    > [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < [- <<<<<<<<<< <<<<< ~15+ >>>>>>>>>> >>>>> ~15] @t9  # NPS starts as PS
                    # prefix state 0 expects c
                    <<<<<<<<<< <<<<<< ~16 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    > + @t11          # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < -- @t12     # subtract 2
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 1
                            + @NPS    # NPS plus 1
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 1 expects o
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < - @t9           # subtract 1
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < --- @t12    # subtract 3
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 2
                            ++ @NPS   # NPS plus 2
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 2 expects m
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < -- @t9          # subtract 2
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---- @t12   # subtract 4
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 3
                            +++ @NPS  # NPS plus 3
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 3 expects dot
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < --- @t9         # subtract 3
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < - @t12      # subtract 1
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 4
                            ++++ @NPS # NPS plus 4
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 4 expects g
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---- @t9        # subtract 4
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ----- @t12  # subtract 5
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 5
                            +++++ @NPS  # NPS plus 5
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 5 expects o
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ----- @t9       # subtract 5
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < --- @t12    # subtract 3
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 6
                            ++++++ @NPS  # NPS plus 6
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 6 expects o
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ------ @t9      # subtract 6
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < --- @t12    # subtract 3
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 7
                            +++++++ @NPS  # NPS plus 7
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 7 expects g
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ------- @t9     # subtract 7
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ----- @t12  # subtract 5
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 8
                            ++++++++ @NPS  # NPS plus 8
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 8 expects l
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < -------- @t9    # subtract 8
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ------ @t12 # subtract 6
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 9
                            +++++++++ @NPS  # NPS plus 9
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 9 expects e
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < --------- @t9   # subtract 9
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ------- @t12  # subtract 7
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 10
                            ++++++++++ @NPS  # NPS plus 10
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 10 expects dot
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- @t9  # subtract 10
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < - @t12      # subtract 1
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 11
                            ++++++++++ + ~11 @NPS  # NPS plus 11
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 11 expects a
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- - ~11 @t9  # subtract 11
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < -------- @t12  # subtract 8
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 12
                            ++++++++++ ++ ~12 @NPS  # NPS plus 12
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 12 expects n
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- -- ~12 @t9  # subtract 12
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < --------- @t12  # subtract 9
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 13
                            ++++++++++ +++ ~13 @NPS  # NPS plus 13
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 13 expects d
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- --- ~13 @t9  # subtract 13
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- @t12  # subtract 10
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 14
                            ++++++++++ ++++ ~14 @NPS  # NPS plus 14
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 14 expects r
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---- ~14 @t9  # subtract 14
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- - ~11 @t12  # subtract 11
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 15
                            ++++++++++ +++++ ~15 @NPS  # NPS plus 15
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 15 expects o
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ----- ~15 @t9  # subtract 15
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < --- @t12    # subtract 3
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 16
                            ++++++++++ ++++++ ~16 @NPS  # NPS plus 16
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 16 expects i
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ------ ~16 @t9  # subtract 16
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- -- ~12 @t12  # subtract 12
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 17
                            ++++++++++ +++++++ ~17 @NPS  # NPS plus 17
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 17 expects d
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ------- ~17 @t9  # subtract 17
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- @t12  # subtract 10
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 18
                            ++++++++++ ++++++++ ~18 @NPS  # NPS plus 18
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 18 expects dot
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- -------- ~18 @t9  # subtract 18
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < - @t12      # subtract 1
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 19
                            ++++++++++ +++++++++ ~19 @NPS  # NPS plus 19
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 19 expects g
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- --------- ~19 @t9  # subtract 19
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ----- @t12  # subtract 5
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 20
                            ++++++++++ ++++++++++ ~20 @NPS  # NPS plus 20
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 20 expects m
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ~20 @t9  # subtract 20
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---- @t12   # subtract 4
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 21
                            ++++++++++ ++++++++++ + ~21 @NPS  # NPS plus 21
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 21 expects dot
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- - ~21 @t9  # subtract 21
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < - @t12      # subtract 1
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 22
                            ++++++++++ ++++++++++ ++ ~22 @NPS  # NPS plus 22
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 22 expects a
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- -- ~22 @t9  # subtract 22
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < -------- @t12  # subtract 8
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 23
                            ++++++++++ ++++++++++ +++ ~23 @NPS  # NPS plus 23
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 23 expects d
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- --- ~23 @t9  # subtract 23
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- @t12  # subtract 10
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 24
                            ++++++++++ ++++++++++ ++++ ~24 @NPS  # NPS plus 24
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 24 expects s
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ---- ~24 @t9  # subtract 24
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- --- ~13 @t12  # subtract 13
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 25
                            ++++++++++ ++++++++++ +++++ ~25 @NPS  # NPS plus 25
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 25 expects dot
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ----- ~25 @t9  # subtract 25
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < - @t12      # subtract 1
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 26
                            ++++++++++ ++++++++++ ++++++ ~26 @NPS  # NPS plus 26
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # apps branch: state 19 also takes a and moves to state 28
                    # prefix state 19 expects a
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- --------- ~19 @t9  # subtract 19
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < -------- @t12  # subtract 8
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            << [-] @t12  # clear t12; the other branch owns the dead state
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 28
                            ++++++++++ ++++++++++ ++++++++ ~28 @NPS  # NPS plus 28
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 28 expects p
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- -------- ~28 @t9  # subtract 28
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- ---------- ~20 @t12  # subtract 20
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 29
                            ++++++++++ ++++++++++ +++++++++ ~29 @NPS  # NPS plus 29
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 29 expects p
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- --------- ~29 @t9  # subtract 29
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- ---------- ~20 @t12  # subtract 20
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 30
                            ++++++++++ ++++++++++ ++++++++++ ~30 @NPS  # NPS plus 30
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 30 expects s
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ---------- ~30 @t9  # subtract 30
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- --- ~13 @t12  # subtract 13
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 31
                            ++++++++++ ++++++++++ ++++++++++ + ~31 @NPS  # NPS plus 31
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 31 expects dot
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ---------- - ~31 @t9  # subtract 31
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < - @t12      # subtract 1
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 32
                            ++++++++++ ++++++++++ ++++++++++ ++ ~32 @NPS  # NPS plus 32
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 32 expects g
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ---------- -- ~32 @t9  # subtract 32
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ----- @t12  # subtract 5
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 33
                            ++++++++++ ++++++++++ ++++++++++ +++ ~33 @NPS  # NPS plus 33
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 33 expects m
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ---------- --- ~33 @t9  # subtract 33
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---- @t12   # subtract 4
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 34
                            ++++++++++ ++++++++++ ++++++++++ ++++ ~34 @NPS  # NPS plus 34
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 34 expects a
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ---------- ---- ~34 @t9  # subtract 34
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < -------- @t12  # subtract 8
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 35
                            ++++++++++ ++++++++++ ++++++++++ +++++ ~35 @NPS  # NPS plus 35
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 35 expects i
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ---------- ----- ~35 @t9  # subtract 35
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- -- ~12 @t12  # subtract 12
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 36
                            ++++++++++ ++++++++++ ++++++++++ ++++++ ~36 @NPS  # NPS plus 36
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 36 expects l
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ---------- ------ ~36 @t9  # subtract 36
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ------ @t12  # subtract 6
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 37
                            ++++++++++ ++++++++++ ++++++++++ +++++++ ~37 @NPS  # NPS plus 37
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 37 expects dot
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ---------- ------- ~37 @t9  # subtract 37
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < - @t12      # subtract 1
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 38
                            ++++++++++ ++++++++++ ++++++++++ ++++++++ ~38 @NPS  # NPS plus 38
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 38 expects l
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ---------- -------- ~38 @t9  # subtract 38
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ------ @t12  # subtract 6
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 39
                            ++++++++++ ++++++++++ ++++++++++ +++++++++ ~39 @NPS  # NPS plus 39
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 39 expects i
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ---------- --------- ~39 @t9  # subtract 39
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- -- ~12 @t12  # subtract 12
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 40
                            ++++++++++ ++++++++++ ++++++++++ ++++++++++ ~40 @NPS  # NPS plus 40
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 40 expects b
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ---------- ---------- ~40 @t9  # subtract 40
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- ---------- - ~21 @t12  # subtract 21
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 41
                            ++++++++++ ++++++++++ ++++++++++ ++++++++++ + ~41 @NPS  # NPS plus 41
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 41 expects r
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ---------- ---------- - ~41 @t9  # subtract 41
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- - ~11 @t12  # subtract 11
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 42
                            ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++ ~42 @NPS  # NPS plus 42
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 42 expects a
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ---------- ---------- -- ~42 @t9  # subtract 42
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < -------- @t12  # subtract 8
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 43
                            ++++++++++ ++++++++++ ++++++++++ ++++++++++ +++ ~43 @NPS  # NPS plus 43
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 43 expects r
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ---------- ---------- --- ~43 @t9  # subtract 43
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- - ~11 @t12  # subtract 11
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 44
                            ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++ ~44 @NPS  # NPS plus 44
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 44 expects i
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ---------- ---------- ---- ~44 @t9  # subtract 44
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- -- ~12 @t12  # subtract 12
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 45
                            ++++++++++ ++++++++++ ++++++++++ ++++++++++ +++++ ~45 @NPS  # NPS plus 45
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 45 expects e
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ---------- ---------- ----- ~45 @t9  # subtract 45
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ------- @t12  # subtract 7
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 46
                            ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++ ~46 @NPS  # NPS plus 46
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 46 expects s
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ---------- ---------- ------ ~46 @t9  # subtract 46
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- --- ~13 @t12  # subtract 13
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 47
                            ++++++++++ ++++++++++ ++++++++++ ++++++++++ +++++++ ~47 @NPS  # NPS plus 47
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 47 expects dot
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ---------- ---------- ------- ~47 @t9  # subtract 47
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < - @t12      # subtract 1
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 48
                            ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++ ~48 @NPS  # NPS plus 48
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 48 expects a
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ---------- ---------- -------- ~48 @t9  # subtract 48
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < -------- @t12  # subtract 8
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 49
                            ++++++++++ ++++++++++ ++++++++++ ++++++++++ +++++++++ ~49 @NPS  # NPS plus 49
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 49 expects d
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ---------- ---------- --------- ~49 @t9  # subtract 49
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- @t12  # subtract 10
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 50
                            ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ~50 @NPS  # NPS plus 50
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 50 expects s
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ---------- ---------- ---------- ~50 @t9  # subtract 50
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- --- ~13 @t12  # subtract 13
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 51
                            ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ + ~51 @NPS  # NPS plus 51
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # prefix state 51 expects dot
                    <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>> ~16+ >+ <<<<<<<<<< <<<<<<< ~17] @PS  # copy PS to t9
                    >>>>>>>>>> >>>>>>> ~17 [- <<<<<<<<<< <<<<<<< ~17+ >>>>>>>>>> >>>>>>> ~17] @t10  # move t10 into PS
                    < ---------- ---------- ---------- ---------- ---------- - ~51 @t9  # subtract 51
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < - @t12      # subtract 1
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 27
                            ++++++++++ ++++++++++ +++++++ ~27 @NPS  # NPS plus 27
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<<<< ~20 [-] @NPS  # NPS becomes 26
                            ++++++++++ ++++++++++ ++++++ ~26 @NPS  # NPS plus 26
                            >>>>>>>>>> >>>>>>>>>> ~20 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    <<<<<<<<<< <<<<<<<< ~18 [-] @PS  # clear PS
                    > [- <+ >] @NPS   # PS takes NPS
                    # suffix: a capital A restarts the match
                    << [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @CH  # copy CH to t9
                    >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into CH
                    < ---------- ------ ~16 @t9  # subtract 16
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<< ~15 [-] @NSS  # NSS becomes 1
                        + @NSS        # NSS plus 1
                        >>>>>>>>>> >>>>> ~15 [-] @t11  # clear t11
                    ] @t11
                    # suffix state 1 expects d
                    <<<<<<<<<< <<<<<< ~16 [- >>>>>>>>>> >>>> ~14+ >+ <<<<<<<<<< <<<<< ~15] @SS  # copy SS to t9
                    >>>>>>>>>> >>>>> ~15 [- <<<<<<<<<< <<<<< ~15+ >>>>>>>>>> >>>>> ~15] @t10  # move t10 into SS
                    < - @t9           # subtract 1
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- @t12  # subtract 10
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            << [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<< ~18 [-] @NSS  # NSS becomes 2
                            ++ @NSS   # NSS plus 2
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # suffix state 2 expects capital T
                    <<<<<<<<<< <<<<<< ~16 [- >>>>>>>>>> >>>> ~14+ >+ <<<<<<<<<< <<<<< ~15] @SS  # copy SS to t9
                    >>>>>>>>>> >>>>> ~15 [- <<<<<<<<<< <<<<< ~15+ >>>>>>>>>> >>>>> ~15] @t10  # move t10 into SS
                    < -- @t9          # subtract 2
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- ------- ~17 @t12  # subtract 17
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            << [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<< ~18 [-] @NSS  # NSS becomes 3
                            +++ @NSS  # NSS plus 3
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # suffix state 3 expects e
                    <<<<<<<<<< <<<<<< ~16 [- >>>>>>>>>> >>>> ~14+ >+ <<<<<<<<<< <<<<< ~15] @SS  # copy SS to t9
                    >>>>>>>>>> >>>>> ~15 [- <<<<<<<<<< <<<<< ~15+ >>>>>>>>>> >>>>> ~15] @t10  # move t10 into SS
                    < --- @t9         # subtract 3
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ------- @t12  # subtract 7
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            << [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<< ~18 [-] @NSS  # NSS becomes 4
                            ++++ @NSS # NSS plus 4
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # suffix state 4 expects a
                    <<<<<<<<<< <<<<<< ~16 [- >>>>>>>>>> >>>> ~14+ >+ <<<<<<<<<< <<<<< ~15] @SS  # copy SS to t9
                    >>>>>>>>>> >>>>> ~15 [- <<<<<<<<<< <<<<< ~15+ >>>>>>>>>> >>>>> ~15] @t10  # move t10 into SS
                    < ---- @t9        # subtract 4
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < -------- @t12  # subtract 8
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            << [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<< ~18 [-] @NSS  # NSS becomes 5
                            +++++ @NSS  # NSS plus 5
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # suffix state 5 expects s
                    <<<<<<<<<< <<<<<< ~16 [- >>>>>>>>>> >>>> ~14+ >+ <<<<<<<<<< <<<<< ~15] @SS  # copy SS to t9
                    >>>>>>>>>> >>>>> ~15 [- <<<<<<<<<< <<<<< ~15+ >>>>>>>>>> >>>>> ~15] @t10  # move t10 into SS
                    < ----- @t9       # subtract 5
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- --- ~13 @t12  # subtract 13
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            << [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<< ~18 [-] @NSS  # NSS becomes 6
                            ++++++ @NSS  # NSS plus 6
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # suffix state 6 expects e
                    <<<<<<<<<< <<<<<< ~16 [- >>>>>>>>>> >>>> ~14+ >+ <<<<<<<<<< <<<<< ~15] @SS  # copy SS to t9
                    >>>>>>>>>> >>>>> ~15 [- <<<<<<<<<< <<<<< ~15+ >>>>>>>>>> >>>>> ~15] @t10  # move t10 into SS
                    < ------ @t9      # subtract 6
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ------- @t12  # subtract 7
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            << [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<< ~18 [-] @NSS  # NSS becomes 7
                            +++++++ @NSS  # NSS plus 7
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # suffix state 7 expects r
                    <<<<<<<<<< <<<<<< ~16 [- >>>>>>>>>> >>>> ~14+ >+ <<<<<<<<<< <<<<< ~15] @SS  # copy SS to t9
                    >>>>>>>>>> >>>>> ~15 [- <<<<<<<<<< <<<<< ~15+ >>>>>>>>>> >>>>> ~15] @t10  # move t10 into SS
                    < ------- @t9     # subtract 7
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- - ~11 @t12  # subtract 11
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            << [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<< ~18 [-] @NSS  # NSS becomes 8
                            ++++++++ @NSS  # NSS plus 8
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # suffix state 8 expects capital I
                    <<<<<<<<<< <<<<<< ~16 [- >>>>>>>>>> >>>> ~14+ >+ <<<<<<<<<< <<<<< ~15] @SS  # copy SS to t9
                    >>>>>>>>>> >>>>> ~15 [- <<<<<<<<<< <<<<< ~15+ >>>>>>>>>> >>>>> ~15] @t10  # move t10 into SS
                    < -------- @t9    # subtract 8
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- -------- ~18 @t12  # subtract 18
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            << [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<< ~18 [-] @NSS  # NSS becomes 9
                            +++++++++ @NSS  # NSS plus 9
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # suffix state 9 expects t
                    <<<<<<<<<< <<<<<< ~16 [- >>>>>>>>>> >>>> ~14+ >+ <<<<<<<<<< <<<<< ~15] @SS  # copy SS to t9
                    >>>>>>>>>> >>>>> ~15 [- <<<<<<<<<< <<<<< ~15+ >>>>>>>>>> >>>>> ~15] @t10  # move t10 into SS
                    < --------- @t9   # subtract 9
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- ---- ~14 @t12  # subtract 14
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            << [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<< ~18 [-] @NSS  # NSS becomes 10
                            ++++++++++ @NSS  # NSS plus 10
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # suffix state 10 expects e
                    <<<<<<<<<< <<<<<< ~16 [- >>>>>>>>>> >>>> ~14+ >+ <<<<<<<<<< <<<<< ~15] @SS  # copy SS to t9
                    >>>>>>>>>> >>>>> ~15 [- <<<<<<<<<< <<<<< ~15+ >>>>>>>>>> >>>>> ~15] @t10  # move t10 into SS
                    < ---------- @t9  # subtract 10
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ------- @t12  # subtract 7
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            << [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<< ~18 [-] @NSS  # NSS becomes 11
                            ++++++++++ + ~11 @NSS  # NSS plus 11
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # suffix state 11 expects m
                    <<<<<<<<<< <<<<<< ~16 [- >>>>>>>>>> >>>> ~14+ >+ <<<<<<<<<< <<<<< ~15] @SS  # copy SS to t9
                    >>>>>>>>>> >>>>> ~15 [- <<<<<<<<<< <<<<< ~15+ >>>>>>>>>> >>>>> ~15] @t10  # move t10 into SS
                    < ---------- - ~11 @t9  # subtract 11
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---- @t12   # subtract 4
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            << [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<< ~18 [-] @NSS  # NSS becomes 12
                            ++++++++++ ++ ~12 @NSS  # NSS plus 12
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # suffix state 12 expects capital V
                    <<<<<<<<<< <<<<<< ~16 [- >>>>>>>>>> >>>> ~14+ >+ <<<<<<<<<< <<<<< ~15] @SS  # copy SS to t9
                    >>>>>>>>>> >>>>> ~15 [- <<<<<<<<<< <<<<< ~15+ >>>>>>>>>> >>>>> ~15] @t10  # move t10 into SS
                    < ---------- -- ~12 @t9  # subtract 12
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- --------- ~19 @t12  # subtract 19
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            << [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<< ~18 [-] @NSS  # NSS becomes 13
                            ++++++++++ +++ ~13 @NSS  # NSS plus 13
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # suffix state 13 expects i
                    <<<<<<<<<< <<<<<< ~16 [- >>>>>>>>>> >>>> ~14+ >+ <<<<<<<<<< <<<<< ~15] @SS  # copy SS to t9
                    >>>>>>>>>> >>>>> ~15 [- <<<<<<<<<< <<<<< ~15+ >>>>>>>>>> >>>>> ~15] @t10  # move t10 into SS
                    < ---------- --- ~13 @t9  # subtract 13
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- -- ~12 @t12  # subtract 12
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            << [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<< ~18 [-] @NSS  # NSS becomes 14
                            ++++++++++ ++++ ~14 @NSS  # NSS plus 14
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # suffix state 14 expects e
                    <<<<<<<<<< <<<<<< ~16 [- >>>>>>>>>> >>>> ~14+ >+ <<<<<<<<<< <<<<< ~15] @SS  # copy SS to t9
                    >>>>>>>>>> >>>>> ~15 [- <<<<<<<<<< <<<<< ~15+ >>>>>>>>>> >>>>> ~15] @t10  # move t10 into SS
                    < ---------- ---- ~14 @t9  # subtract 14
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ------- @t12  # subtract 7
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            << [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<< ~18 [-] @NSS  # NSS becomes 15
                            ++++++++++ +++++ ~15 @NSS  # NSS plus 15
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    # suffix state 15 expects w
                    <<<<<<<<<< <<<<<< ~16 [- >>>>>>>>>> >>>> ~14+ >+ <<<<<<<<<< <<<<< ~15] @SS  # copy SS to t9
                    >>>>>>>>>> >>>>> ~15 [- <<<<<<<<<< <<<<< ~15+ >>>>>>>>>> >>>>> ~15] @t10  # move t10 into SS
                    < ---------- ----- ~15 @t9  # subtract 15
                    >> + @t11         # assume equal
                    << [ @t9          # if different
                        >> [-] @t11   # not equal
                        << [-] @t9    # clear t9
                    ] @t9
                    >> [ @t11         # if equal
                        <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>>>>> ~20+ >+ <<<<<<<<<< <<<<<<<<<< < ~21] @CH  # copy CH to t12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [- <<<<<<<<<< <<<<<<<<<< < ~21+ >>>>>>>>>> >>>>>>>>>> > ~21] @t13  # move t13 into CH
                        < ---------- ----- ~15 @t12  # subtract 15
                        >> + @t14     # assume equal
                        << [ @t12     # if different
                            >> [-] @t14  # not equal
                            << [-] @t12  # clear t12
                        ] @t12
                        >> [ @t14     # if equal
                            <<<<<<<<<< <<<<<<<< ~18 [-] @NSS  # NSS becomes 16
                            ++++++++++ ++++++ ~16 @NSS  # NSS plus 16
                            >>>>>>>>>> >>>>>>>> ~18 [-] @t14  # clear t14
                        ] @t14
                        <<< [-] @t11  # clear t11
                    ] @t11
                    <<<<<<<<<< <<<<<< ~16 [-] @SS  # clear SS
                    > [- <+ >] @NSS   # SS takes NSS
                <<<<< ] @K
                , @K                  # next chunk length
            ] @K
            # the name starts with an ads package
            >> [- >>>>>>>>>> >>> ~13+ >+ <<<<<<<<<< <<<< ~14] @PS  # copy PS to t6
            >>>>>>>>>> >>>> ~14 [- <<<<<<<<<< <<<< ~14+ >>>>>>>>>> >>>> ~14] @t7  # move t7 into PS
            < ---------- ---------- ------ ~26 @t6  # subtract 26
            >> + @t8                  # assume equal
            << [ @t6                  # if different
                >> [-] @t8            # not equal
                << [-] @t6            # clear t6
            ] @t6
            >> [ @t8                  # if equal
                # and it ends with the row suffix
                <<<<<<<<<< <<< ~13 [- >>>>>>>>>> >>>> ~14+ >+ <<<<<<<<<< <<<<< ~15] @SS  # copy SS to t9
                >>>>>>>>>> >>>>> ~15 [- <<<<<<<<<< <<<<< ~15+ >>>>>>>>>> >>>>> ~15] @t10  # move t10 into SS
                < ---------- ------ ~16 @t9  # subtract 16
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<< ~14 [-] @AD  # AD becomes 1
                    + @AD             # AD plus 1
                    >>>>>>>>>> >>>> ~14 [-] @t11  # clear t11
                ] @t11
                <<< [-] @t8           # clear t8
            ] @t8
            <<<<<<<<<< <<<<< ~15 [-] @PS  # clear PS
            >> [-] @SS                # clear SS
        <<<<< ] @N
        >>>>>>> . @AD                 # verdict
        [-] @AD                       # clear AD
        >>>>>>>> [-] @t5              # clear t5
    ] @t5
    <<<<<<<<<< <<<<<< ~16 [ @UNH      # unknown opcode
        # response header
        >>>>>>>>>> >>>> ~14 + @t3     # major
        . @t3                         # write t3
        [-] @t3                       # clear t3
        . @t3                         # minor
        <<<<<<<<<< <<<<<<<< ~18 [- >>>>>>>>>> >>>>>>>> ~18+ >+ <<<<<<<<<< <<<<<<<<< ~19] @OP  # copy OP to t3
        >>>>>>>>>> >>>>>>>>> ~19 [- <<<<<<<<<< <<<<<<<<< ~19+ >>>>>>>>>> >>>>>>>>> ~19] @t4  # move t4 into OP
        < ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++++ ++++++++ ~128 @t3  # opcode with the response bit
        . @t3                         # write t3
        [-] @t3                       # clear t3
        ++ @t3                        # status
        . @t3                         # status
        [-] @t3                       # clear t3
        . @t3                         # payload length low
        [-] @t3                       # clear t3
        . @t3                         # payload length high
        <<<<<<<<<< <<<<<<< ~17 . @ID0 # echo request id
        > . @ID1                      # write ID1
        >> [-] @UNH                   # clear UNH
    ] @UNH
    >>>>>>>>>> >>> ~13 [-] @t2        # clear t2
] @t2
