# scope bf: is this the Gmail package and a process the module belongs in
# Normative specification: docs/policy/scope md ABI: docs/BRAINFUCK_ARCHITECTURE md
# Serves OP_SCOPE One machine E compares each name with the Gmail package name
#
# Tape layout
# %cell MAJ 0
# %cell OP 1
# %cell ID0 2
# %cell ID1 3
# %cell J 4
# %cell UNH 5
# %cell K 6
# %cell CH 7
# %cell E 8
# %cell NE 9
# %cell PP 10
# %cell PE 11
# %cell QP 12
# %cell QE 13
# %cell OK 14
# %cell G 15
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
    # opcode 32
    <<<< [- >>>>>>>>>> >>>>>>>> ~18+ >+ <<<<<<<<<< <<<<<<<<< ~19] @OP  # copy OP to t3
    >>>>>>>>>> >>>>>>>>> ~19 [- <<<<<<<<<< <<<<<<<<< ~19+ >>>>>>>>>> >>>>>>>>> ~19] @t4  # move t4 into OP
    < ---------- ---------- ---------- -- ~32 @t3  # subtract 32
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
        >>>>>>> , @PP                 # package name present
        [ @PP                         # normalize PP
            >>>>>>>>>> >> ~12 + @t6   # t6 plus 1
            <<<<<<<<<< << ~12 [-] @PP # clear PP
        ] @PP
        >>>>>>>>>> >> ~12 [- <<<<<<<<<< << ~12+ >>>>>>>>>> >> ~12] @t6  # move t6 into PP
        <<<<<<<<<< <<<<<< ~16 , @K    # first chunk length of the package name
        [ @K                          # each chunk
            [ @K                      # each character of the chunk
                - @K                  # K minus 1
                > , @CH               # read CH
                # package name: E counts matched characters; 21 is equal so far and 22 is different
                >> [-] @NE            # NE becomes 22 unless the next character matches
                ++++++++++ ++++++++++ ++ ~22 @NE  # NE plus 22
                # state 0 expects c
                < [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                > + @t11              # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < -- @t12         # subtract 2
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 1
                        + @NE         # NE plus 1
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 1 expects o
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < - @t9               # subtract 1
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < --- @t12        # subtract 3
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 2
                        ++ @NE        # NE plus 2
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 2 expects m
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < -- @t9              # subtract 2
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < ---- @t12       # subtract 4
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 3
                        +++ @NE       # NE plus 3
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 3 expects dot
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < --- @t9             # subtract 3
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < - @t12          # subtract 1
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 4
                        ++++ @NE      # NE plus 4
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 4 expects g
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---- @t9            # subtract 4
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < ----- @t12      # subtract 5
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 5
                        +++++ @NE     # NE plus 5
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 5 expects o
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ----- @t9           # subtract 5
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < --- @t12        # subtract 3
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 6
                        ++++++ @NE    # NE plus 6
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 6 expects o
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ------ @t9          # subtract 6
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < --- @t12        # subtract 3
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 7
                        +++++++ @NE   # NE plus 7
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 7 expects g
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ------- @t9         # subtract 7
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < ----- @t12      # subtract 5
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 8
                        ++++++++ @NE  # NE plus 8
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 8 expects l
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < -------- @t9        # subtract 8
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < ------ @t12     # subtract 6
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 9
                        +++++++++ @NE # NE plus 9
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 9 expects e
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < --------- @t9       # subtract 9
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < ------- @t12    # subtract 7
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 10
                        ++++++++++ @NE  # NE plus 10
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 10 expects dot
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---------- @t9      # subtract 10
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < - @t12          # subtract 1
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 11
                        ++++++++++ + ~11 @NE  # NE plus 11
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 11 expects a
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---------- - ~11 @t9  # subtract 11
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < -------- @t12   # subtract 8
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 12
                        ++++++++++ ++ ~12 @NE  # NE plus 12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 12 expects n
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---------- -- ~12 @t9  # subtract 12
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < --------- @t12  # subtract 9
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 13
                        ++++++++++ +++ ~13 @NE  # NE plus 13
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 13 expects d
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---------- --- ~13 @t9  # subtract 13
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < ---------- @t12 # subtract 10
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 14
                        ++++++++++ ++++ ~14 @NE  # NE plus 14
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 14 expects r
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---------- ---- ~14 @t9  # subtract 14
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < ---------- - ~11 @t12  # subtract 11
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 15
                        ++++++++++ +++++ ~15 @NE  # NE plus 15
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 15 expects o
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---------- ----- ~15 @t9  # subtract 15
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < --- @t12        # subtract 3
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 16
                        ++++++++++ ++++++ ~16 @NE  # NE plus 16
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 16 expects i
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---------- ------ ~16 @t9  # subtract 16
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < ---------- -- ~12 @t12  # subtract 12
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 17
                        ++++++++++ +++++++ ~17 @NE  # NE plus 17
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 17 expects d
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---------- ------- ~17 @t9  # subtract 17
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < ---------- @t12 # subtract 10
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 18
                        ++++++++++ ++++++++ ~18 @NE  # NE plus 18
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 18 expects dot
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---------- -------- ~18 @t9  # subtract 18
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < - @t12          # subtract 1
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 19
                        ++++++++++ +++++++++ ~19 @NE  # NE plus 19
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 19 expects g
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---------- --------- ~19 @t9  # subtract 19
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < ----- @t12      # subtract 5
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 20
                        ++++++++++ ++++++++++ ~20 @NE  # NE plus 20
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 20 expects m
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---------- ---------- ~20 @t9  # subtract 20
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < ---- @t12       # subtract 4
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 21
                        ++++++++++ ++++++++++ + ~21 @NE  # NE plus 21
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                <<<<<<<<<< <<<<<<<<< ~19 [-] @E  # clear E
                > [- <+ >] @NE        # E takes NE
            <<< ] @K
            , @K                      # next chunk length
        ] @K
        >> [- >>>+ <<<] @E            # PE takes E
        >>>> , @QP                    # process name present
        [ @QP                         # normalize QP
            >>>>>>>>>> + @t6          # t6 plus 1
            <<<<<<<<<< [-] @QP        # clear QP
        ] @QP
        >>>>>>>>>> [- <<<<<<<<<<+ >>>>>>>>>>] @t6  # move t6 into QP
        <<<<<<<<<< <<<<<< ~16 , @K    # first chunk length of the process name
        [ @K                          # each chunk
            [ @K                      # each character of the chunk
                - @K                  # K minus 1
                > , @CH               # read CH
                # process name: E counts matched characters; 21 is equal so far and 22 is different
                >> [-] @NE            # NE becomes 22 unless the next character matches
                ++++++++++ ++++++++++ ++ ~22 @NE  # NE plus 22
                # state 0 expects c
                < [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                > + @t11              # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < -- @t12         # subtract 2
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 1
                        + @NE         # NE plus 1
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 1 expects o
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < - @t9               # subtract 1
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < --- @t12        # subtract 3
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 2
                        ++ @NE        # NE plus 2
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 2 expects m
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < -- @t9              # subtract 2
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < ---- @t12       # subtract 4
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 3
                        +++ @NE       # NE plus 3
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 3 expects dot
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < --- @t9             # subtract 3
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < - @t12          # subtract 1
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 4
                        ++++ @NE      # NE plus 4
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 4 expects g
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---- @t9            # subtract 4
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < ----- @t12      # subtract 5
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 5
                        +++++ @NE     # NE plus 5
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 5 expects o
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ----- @t9           # subtract 5
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < --- @t12        # subtract 3
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 6
                        ++++++ @NE    # NE plus 6
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 6 expects o
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ------ @t9          # subtract 6
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < --- @t12        # subtract 3
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 7
                        +++++++ @NE   # NE plus 7
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 7 expects g
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ------- @t9         # subtract 7
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < ----- @t12      # subtract 5
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 8
                        ++++++++ @NE  # NE plus 8
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 8 expects l
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < -------- @t9        # subtract 8
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < ------ @t12     # subtract 6
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 9
                        +++++++++ @NE # NE plus 9
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 9 expects e
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < --------- @t9       # subtract 9
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < ------- @t12    # subtract 7
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 10
                        ++++++++++ @NE  # NE plus 10
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 10 expects dot
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---------- @t9      # subtract 10
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < - @t12          # subtract 1
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 11
                        ++++++++++ + ~11 @NE  # NE plus 11
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 11 expects a
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---------- - ~11 @t9  # subtract 11
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < -------- @t12   # subtract 8
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 12
                        ++++++++++ ++ ~12 @NE  # NE plus 12
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 12 expects n
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---------- -- ~12 @t9  # subtract 12
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < --------- @t12  # subtract 9
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 13
                        ++++++++++ +++ ~13 @NE  # NE plus 13
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 13 expects d
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---------- --- ~13 @t9  # subtract 13
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < ---------- @t12 # subtract 10
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 14
                        ++++++++++ ++++ ~14 @NE  # NE plus 14
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 14 expects r
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---------- ---- ~14 @t9  # subtract 14
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < ---------- - ~11 @t12  # subtract 11
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 15
                        ++++++++++ +++++ ~15 @NE  # NE plus 15
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 15 expects o
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---------- ----- ~15 @t9  # subtract 15
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < --- @t12        # subtract 3
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 16
                        ++++++++++ ++++++ ~16 @NE  # NE plus 16
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 16 expects i
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---------- ------ ~16 @t9  # subtract 16
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < ---------- -- ~12 @t12  # subtract 12
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 17
                        ++++++++++ +++++++ ~17 @NE  # NE plus 17
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 17 expects d
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---------- ------- ~17 @t9  # subtract 17
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < ---------- @t12 # subtract 10
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 18
                        ++++++++++ ++++++++ ~18 @NE  # NE plus 18
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 18 expects dot
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---------- -------- ~18 @t9  # subtract 18
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < - @t12          # subtract 1
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 19
                        ++++++++++ +++++++++ ~19 @NE  # NE plus 19
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 19 expects g
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---------- --------- ~19 @t9  # subtract 19
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < ----- @t12      # subtract 5
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 20
                        ++++++++++ ++++++++++ ~20 @NE  # NE plus 20
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                # state 20 expects m
                <<<<<<<<<< <<<<<<<<< ~19 [- >>>>>>>>>> >>>>>>> ~17+ >+ <<<<<<<<<< <<<<<<<< ~18] @E  # copy E to t9
                >>>>>>>>>> >>>>>>>> ~18 [- <<<<<<<<<< <<<<<<<< ~18+ >>>>>>>>>> >>>>>>>> ~18] @t10  # move t10 into E
                < ---------- ---------- ~20 @t9  # subtract 20
                >> + @t11             # assume equal
                << [ @t9              # if different
                    >> [-] @t11       # not equal
                    << [-] @t9        # clear t9
                ] @t9
                >> [ @t11             # if equal
                    <<<<<<<<<< <<<<<<<<<< ~20 [- >>>>>>>>>> >>>>>>>>>> > ~21+ >+ <<<<<<<<<< <<<<<<<<<< << ~22] @CH  # copy CH to t12
                    >>>>>>>>>> >>>>>>>>>> >> ~22 [- <<<<<<<<<< <<<<<<<<<< << ~22+ >>>>>>>>>> >>>>>>>>>> >> ~22] @t13  # move t13 into CH
                    < ---- @t12       # subtract 4
                    >> + @t14         # assume equal
                    << [ @t12         # if different
                        >> [-] @t14   # not equal
                        << [-] @t12   # clear t12
                    ] @t12
                    >> [ @t14         # if equal
                        <<<<<<<<<< <<<<<<<<<< < ~21 [-] @NE  # NE becomes 21
                        ++++++++++ ++++++++++ + ~21 @NE  # NE plus 21
                        >>>>>>>>>> >>>>>>>>>> > ~21 [-] @t14  # clear t14
                    ] @t14
                    <<< [-] @t11      # clear t11
                ] @t11
                <<<<<<<<<< <<<<<<<<< ~19 [-] @E  # clear E
                > [- <+ >] @NE        # E takes NE
            <<< ] @K
            , @K                      # next chunk length
        ] @K
        >> [- >>>>>+ <<<<<] @E        # QE takes E
        # the package must be present and equal
        >> [ @PP                      # if PP
            > [- >>>>>>>>>> >>>> ~14+ >+ <<<<<<<<<< <<<<< ~15] @PE  # copy PE to t9
            >>>>>>>>>> >>>>> ~15 [- <<<<<<<<<< <<<<< ~15+ >>>>>>>>>> >>>>> ~15] @t10  # move t10 into PE
            < ---------- ---------- - ~21 @t9  # subtract 21
            >> + @t11                 # assume equal
            << [ @t9                  # if different
                >> [-] @t11           # not equal
                << [-] @t9            # clear t9
            ] @t9
            >> [ @t11                 # if equal
                <<<<<<<<<< << ~12 [-] @G  # G becomes 1
                + @G                  # G plus 1
                >>>>>>>>>> >> ~12 [-] @t11  # clear t11
            ] @t11
            <<<<<<<<<< <<<<<<< ~17 [-] @PP  # clear PP
        ] @PP
        >>>>> [ @G                    # if the package matched
            # the process may be absent or empty or equal
            < + @OK                   # assume absent
            << [ @QP                  # present
                >> [-] @OK            # clear OK
                << [-] @QP            # clear QP
            ] @QP
            # empty
            > [- >>>>>>>>>> >> ~12+ >+ <<<<<<<<<< <<< ~13] @QE  # copy QE to t9
            >>>>>>>>>> >>> ~13 [- <<<<<<<<<< <<< ~13+ >>>>>>>>>> >>> ~13] @t10  # move t10 into QE
            > + @t11                  # assume equal
            << [ @t9                  # if different
                >> [-] @t11           # not equal
                << [-] @t9            # clear t9
            ] @t9
            >> [ @t11                 # if equal
                <<<<<<<<<< <<< ~13 [-] @OK  # OK becomes 1
                + @OK                 # OK plus 1
                >>>>>>>>>> >>> ~13 [-] @t11  # clear t11
            ] @t11
            # equal
            <<<<<<<<<< <<<< ~14 [- >>>>>>>>>> >> ~12+ >+ <<<<<<<<<< <<< ~13] @QE  # copy QE to t9
            >>>>>>>>>> >>> ~13 [- <<<<<<<<<< <<< ~13+ >>>>>>>>>> >>> ~13] @t10  # move t10 into QE
            < ---------- ---------- - ~21 @t9  # subtract 21
            >> + @t11                 # assume equal
            << [ @t9                  # if different
                >> [-] @t11           # not equal
                << [-] @t9            # clear t9
            ] @t9
            >> [ @t11                 # if equal
                <<<<<<<<<< <<< ~13 [-] @OK  # OK becomes 1
                + @OK                 # OK plus 1
                >>>>>>>>>> >>> ~13 [-] @t11  # clear t11
            ] @t11
            <<<<<<<<<< << ~12 [-] @G  # clear G
        ] @G
        <<< [-] @QP                   # clear QP
        >> . @OK                      # verdict
        [-] @OK                       # clear OK
        <<< [-] @PE                   # clear PE
        >> [-] @QE                    # clear QE
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
