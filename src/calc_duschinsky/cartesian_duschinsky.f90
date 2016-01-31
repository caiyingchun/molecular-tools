program cartesian_duschinsky


    !*****************
    !   MODULE LOAD
    !*****************
    !============================================
    !   Generic
    !============================================
    use alerts
    use line_preprocess
    use constants 
    use verbosity
    use matrix
    use matrix_print
    !============================================
    !   Structure types module
    !============================================
    use structure_types
    !============================================
    !   File readers
    !============================================
    use generic_io
    use generic_io_molec
    use xyz_manage
    !============================================
    !  Structure-related modules
    !============================================
    use molecular_structure
    use ff_build
    use atomic_geom
    use symmetry
    !============================================
    !  Internal thingies
    !============================================
    use internal_module
    use zmat_manage 
    use vibrational_analysis

    implicit none

    integer,parameter :: NDIM = 600

    !====================== 
    !Options 
    logical :: use_symmetry=.false. ,&
               modred=.false.       ,&
               tswitch=.false.      ,&
               symaddapt=.false.    ,&
               vertical=.true.      ,&
               verticalQspace1=.true.,&
               verticalQspace2=.false.,&
               do_correct_num=.false., &
               do_correct_int=.false., &
               gradcorrectS1=.false., &
               check_symmetry=.true.
    character(len=4) :: def_internal='zmat'
    !======================

    !====================== 
    !System variables
    type(str_resmol) :: state1,state2
    integer,dimension(1:NDIM) :: isym
    integer,dimension(1:4,1:NDIM,1:NDIM) :: Osym
    integer :: Nsym
    integer :: Nat, Nvib, Ns
    !====================== 

    !====================== 
    !INTERNAL VIBRATIONAL ANALYSIS
    !MATRICES
    !B and G matrices
    real(8),dimension(NDIM,NDIM) :: B, G1
    !Other arrays
    real(8),dimension(1:NDIM) :: Grad
    real(8),dimension(1:NDIM,1:NDIM) :: Hess,Hess2, X1,X1inv, L1,L2, Asel1
    real(8),dimension(1:NDIM,1:NDIM,1:NDIM) :: Bder
    !Duschisky
    real(8),dimension(NDIM,NDIM) :: G
    !T0 - switching effects
    real(8),dimension(3,3) :: T, Xrot1, Xrot2, IM
    !AUXILIAR MATRICES
    real(8),dimension(NDIM,NDIM) :: Aux, Aux2
    !Save definitio of the modes in character
    character(len=100),dimension(NDIM) :: ModeDef
    !VECTORS
    real(8),dimension(NDIM) :: Freq1, Freq2, S1, S2, Vec, Vec1, mu, Q0, FC
    integer,dimension(NDIM) :: S_sym, bond_sym,angle_sym,dihed_sym
    !Shifts
    real(8),dimension(NDIM) :: Delta
    real(8),dimension(3) :: DeltaCOM
    real(8) :: Delta_p, Er
    !====================== 

    !====================== 
    !Read fchk auxiliars
    real(8),dimension(:),allocatable :: Hlt
    integer :: error
    !====================== 

    !====================== 
    !Auxiliar variables
    character(1) :: null
    character(len=16) :: dummy_char
    real(8) :: Theta, Theta2, Theta3
    ! Messages
    character(len=200) :: msg
    !====================== 

    !=============
    !Counters
    integer :: i,j,k,l, ii,jj,kk, iat, k90,k95,k99, nn, imin, imax,&
               i1,i2,i3,i4, iop
    !=============

    !================
    !I/O stuff 
    !units
    integer :: I_INP=10,  &
               I_ZMAT=11, &
               I_SYM=12,  &
               I_RED=13,  &
               I_ADD=14,  &
               I_AD2=15,  &
               I_RMF=16,  &
               I_DER=17,  &
               I_CNX=18,  &
               O_DUS=20,  &
               O_DIS=21,  &
               O_DMAT=22, &
               O_DUS2=23, &
               O_DIS2=24, &
               O_STAT=25, &
               O_STR =26
    !files
    character(len=10) :: ft ="guess", fth="guess", ftg="guess", ft2="guess", ftg2="guess", fth2="guess" 
    character(len=200):: inpfile  ="state1.fchk", &
                         hessfile ="same", &
                         gradfile="same",&
                         inpfile2 ="state2.fchk", &
                         hessfile2 ="same", &
                         gradfile2 ="same", &
                         intfile  ="none",       &
                         rmzfile  ="none",       &
                         symm_file="none", &
                         cnx_file="guess", &
                         derfile="base", derfile_base, &
                         tmpfile
    !status
    integer :: IOstatus
    !===================

    !===================
    !CPU time 
    real(8) :: ti, tf
    !===================

! (End of variables declaration) 
!==================================================================================

    call cpu_time(ti)

    !--------------------------
    ! Tune io
    !--------------------------
    ! Set unit for alert messages
    alert_unt=6
    !--------------------------

    ! 0. GET COMMAND LINE ARGUMENTS
!     call generic_input_parser(inpfile, "-f" ,"c",&
!                               filetype,"-ft","c",&
!                               )
    call parse_input(inpfile,ft,gradfile,ftg,hessfile,fth,inpfile2,ft2,gradfile2,ftg2,hessfile2,fth2,&
                     cnx_file,intfile,rmzfile,def_internal,use_symmetry,derfile,do_correct_num,do_correct_int,&
                     gradcorrectS1,vertical,verticalQspace1,verticalQspace2)
    call set_word_upper_case(def_internal)


    !===========
    !State 1
    !===========
    if (verbose>0) then
        print*, ""
        print*, "=========="
        print*, " STATE 1"
        print*, "=========="
    endif

    ! READ DATA (each element from a different file is possible)
    ! ---------------------------------
    !Guess filetypes
    if (ft == "guess") &
    call split_line_back(inpfile,".",null,ft)
    if (fth == "guess") &
    call split_line_back(hessfile,".",null,fth)
    if (ftg == "guess") &
    call split_line_back(gradfile,".",null,ftg)

    ! STRUCTURE FILE
    print'(X,A)', "READING STATE1 FILE (STRUCTURE)..."
    open(I_INP,file=inpfile,status='old',iostat=IOstatus)
    if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(inpfile)) )
    call generic_strmol_reader(I_INP,ft,state1)
    close(I_INP)
    ! Shortcuts
    Nat = state1%natoms
    print'(X,A,/)', "Done"

    ! HESSIAN FILE (State1)
    print'(X,A)', "READING STATE1 FILE (HESSIAN)..."
    open(I_INP,file=hessfile,status='old',iostat=IOstatus)
    if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(hessfile)) )
    allocate(Hlt(1:3*Nat*(3*Nat+1)/2))
    call generic_Hessian_reader(I_INP,fth,Nat,Hlt,error) 
    close(I_INP)
    print'(X,A,/)', "Done"
    ! Run vibrations_Cart to get the number of Nvib (to detect linear molecules)
    print'(X,A)', "Preliminar vibrational analysis (Cartesian coordinates)..."
    call vibrations_Cart(Nat,state1%atom(:)%X,state1%atom(:)%Y,state1%atom(:)%Z,state1%atom(:)%Mass,Hlt,&
                         Nvib,L1,Freq1,error_flag=error)
    deallocate(Hlt)

    ! GRADIENT FILE (State1) -- now useless as no vibrational analysis is done in IC at State1
    if (gradcorrectS1) then
        print'(X,A)', "READING STATE1 FILE (GRADIENT)..."
        open(I_INP,file=gradfile,status='old',iostat=IOstatus)
        if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(gradfile)) )
        call generic_gradient_reader(I_INP,ftg,Nat,Grad,error) 
        close(I_INP)
        print'(X,A,/)', "Done"
    else
        print'(X,A,/)', "Assuming gradient for State1 equal to zero"
        Grad(1:3*Nat) = 0.d0
    endif

    if (do_correct_int) then
        !***************************************************************
        ! The whole vibrational analysis is not needed, only the Bder
        print'(/,X,A)', "Preparing to compute Bder for correction terms..."
    
        ! Manage symmetry
        if (.not.use_symmetry) then
            state1%PG="C1"
        else if (trim(adjustl(symm_file)) /= "none") then
            msg = "Using custom symmetry file: "//trim(adjustl(symm_file)) 
            call alert_msg("note",msg)
            open(I_SYM,file=symm_file)
            do i=1,state1%natoms
                read(I_SYM,*) j, isym(j)
            enddo
            close(I_SYM)
            !Set PG to CUStom
            state1%PG="CUS"
        else
            state1%PG="XX"
            call symm_atoms(state1,isym)
        endif

        !Generate bonded info
        if (cnx_file == "guess") then
            call guess_connect(state1)
        else
            print'(/,A,/)', "Reading connectivity from file: "//trim(adjustl(cnx_file))
            open(I_CNX,file=cnx_file,status='old')
            call read_connect(I_CNX,state1)
            close(I_CNX)
        endif
        call gen_bonded(state1)
    
        ! Define internal set
        call define_internal_set(state1,def_internal,intfile,rmzfile,use_symmetry,isym, S_sym,Ns)
    
        !From now on, we'll use atomic units
        call set_geom_units(state1,"Bohr")
    
        ! INTERNAL COORDINATES
    
        !SOLVE GF METHOD TO GET NM AND FREQ
        call internal_Wilson(state1,Ns,S1,B,ModeDef)
        call internal_Gmetric(Nat,Ns,state1%atom(:)%mass,B,G1)
        call calc_BDer(state1,Ns,Bder)
    
        ! SET REDUNDANT/SYMETRIZED/CUSTOM INTERNAL SETS
    !     if (symaddapt) then (implement in an analogous way as compared with the transformation from red to non-red
        if (Ns > Nvib) then ! Redundant
            call redundant2nonredundant(Ns,Nvib,G1,Asel1)
            ! Rotate Bmatrix
            B(1:Nvib,1:3*Nat) = matrix_product(Nvib,3*Nat,Ns,Asel1,B,tA=.true.)
            ! Rotate Gmatrix
            G1(1:Nvib,1:Nvib) = matrix_basisrot(Nvib,Ns,Asel1(1:Ns,1:Nvib),G1,counter=.true.)
            ! Rotate Bders
            if (vertical) then
                do j=1,3*Nat
                    Bder(1:Nvib,j,1:3*Nat) =  matrix_product(Nvib,3*Nat,Ns,Asel1,Bder(1:Ns,j,1:3*Nat),tA=.true.)
                enddo
            endif
        endif
    endif


    !===========
    !State 2
    !===========
    if (verbose>0) then
        print*, ""
        print*, "=========="
        print*, " STATE 2"
        print*, "=========="
    endif

    ! READ DATA (each element from a different file is possible)
    ! ---------------------------------
    !Guess filetypes
    if (ft2 == "guess") &
    call split_line_back(inpfile2,".",null,ft2)
    if (fth2 == "guess") &
    call split_line_back(hessfile2,".",null,fth2)
    if (ftg2 == "guess") &
    call split_line_back(gradfile2,".",null,ftg2)

    ! STRUCTURE FILE
    print'(X,A)', "READING STATE2 FILE (STRUCTURE)..."
    open(I_INP,file=inpfile2,status='old',iostat=IOstatus)
    if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(inpfile2)) )
    call generic_strmol_reader(I_INP,ft2,state2)
    close(I_INP)
    ! Shortcuts
    Nat = state2%natoms
    print'(X,A,/)', "Done"
    ! HESSIAN FILE (State2)
    print'(/,X,A)', "READING STATE2 FILE (HESSIAN)..."
    open(I_INP,file=hessfile2,status='old',iostat=IOstatus)
    if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(hessfile2)) )
    allocate(Hlt(1:3*Nat*(3*Nat+1)/2))
    call generic_Hessian_reader(I_INP,fth2,Nat,Hlt,error) 
    ! Run vibrations_Cart to get the number of Nvib (to detect linear molecules)
    print'(X,A)', "Preliminar vibrational analysis (Cartesian coordinates)..."
    call vibrations_Cart(Nat,state2%atom(:)%X,state2%atom(:)%Y,state2%atom(:)%Z,state2%atom(:)%Mass,Hlt,&
                         Nvib,L2,Freq2,error_flag=error)
    close(I_INP)
    k=0
    do i=1,3*Nat
    do j=1,i
        k=k+1
        Hess(i,j) = Hlt(k)
        Hess(j,i) = Hlt(k)
    enddo 
    enddo
    deallocate(Hlt)

    ! GRADIENT FILE
    print'(/,X,A)', "READING STATE2 FILE (GRADIENT)..."
    open(I_INP,file=gradfile2,status='old',iostat=IOstatus)
    if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(gradfile2)) )
    call generic_gradient_reader(I_INP,ftg2,Nat,Grad,error)
    close(I_INP)

    ! From now on in atomic units
    call set_geom_units(state1,"Bohr")
    call set_geom_units(state2,"Bohr")
    
    ! If Adiabatic, need to rotate State2 to State1 orientation
    if (.not.vertical) then
        ! Move to com (this does not change Hess nor Grad nor vibrations_Cart
        call get_com(state1)
        state1%atom(1:Nat)%x = state1%atom(1:Nat)%x-state1%comX
        state1%atom(1:Nat)%y = state1%atom(1:Nat)%y-state1%comY
        state1%atom(1:Nat)%z = state1%atom(1:Nat)%z-state1%comZ
        call get_com(state2)
        state2%atom(1:Nat)%x = state2%atom(1:Nat)%x-state2%comX
        state2%atom(1:Nat)%y = state2%atom(1:Nat)%y-state2%comY
        state2%atom(1:Nat)%z = state2%atom(1:Nat)%z-state2%comZ
        ! Rotate to same orientation (can be done with Tswithch or ROTATA)
        call ROTATA1(state2,state1,T)
        print*, "Rotate State2 to minimize RMSD with State1"
        call MAT0(6,T,3,3,"Rotation matrix")
        call rotate_molec(state2,T)
        ! Rotate L2 modes
        L2(1:3*Nat,1:Nvib) = rotate3D_matrix(3*Nat,Nvib,L2,T)
        ! Rotate Hess (to properly compute the Er):
        ! Rot Hess Rot^t
        Hess(1:3*Nat,1:3*Nat) = rotate3D_matrix(3*Nat,3*Nat,Hess,T)
        ! The other part is done as
        ! A Rot^t = (Rot A^t)^t
        Hess(1:3*Nat,1:3*Nat) = rotate3D_matrix(3*Nat,3*Nat,Hess,T,tA=.true.)
        ! Ne need to transpose again, since Hess is symmetric
    endif


    !==============
    ! DUSCHINSKI
    !==============
    ! At this point
    !  * Hess: Cartesian
    !  * Grad: Cartesian
    !  * L1  : MWC
    if (vertical.and.verticalQspace1) then
        call Lmwc_to_Lcart(Nat,Nvib,state1%atom(:)%Mass,L1,L1,error)
        !*****************************************************    
        ! Apply matrix derivative if the option is enabled
        !*****************************************************
        if (do_correct_int) then
            print'(X,A,/)', "Apply correction for vertical case based on internal vibrational analysis..."
            ! Compute gQ from gs
            !  gQ = L1int^t gs
            ! Convert Gradient to normal mode coordinates in state1 Qspace.
            ! We use the internal normal modes and not the Cartesian
            ! ones to get the sign consistent with the internal mode
            ! definition. Note that, apart from the sign, both should be
            ! equivalent in state1 Qspace
            ! Use Vec1 as temporary vector to store Grad (so to have Cartesia Grad)
            Vec1(1:3*Nat) = Grad(1:3*Nat)
            call Gradcart2int(Nat,Nvib,Vec1,state1%atom(:)%mass,B,G1)
            ! Compute gs^t * Lder
            do i=1,3*Nat
            do j=1,3*Nat
                Aux(i,j) = 0.d0
                do k=1,Nvib
                    Aux(i,j) = Aux(i,j) + Bder(k,i,j)*Vec1(k)
                enddo
            enddo
            enddo
        
            ! Compute (Hess - gQ LLL^Q) -- store in Hess2 (we keep normal Hess to compute Er)
            Hess2(1:3*Nat,1:3*Nat) = Hess(1:3*Nat,1:3*Nat) - Aux(1:3*Nat,1:3*Nat)
        
            !Compute H_Q' = L1^t (Hess - gQ LLL^Q) L1
            Hess2(1:Nvib,1:Nvib) = matrix_basisrot(Nvib,3*Nat,L1,Hess2,counter=.true.)

            ! Also check the symmetry of the correction term
            if (check_symmetry) then
                print'(/,X,A)', "---------------------------------------"
                print'(X,A  )', " Check effect of symmetry operations"
                print'(X,A  )', " on the correction term gs^t\beta"
                print'(X,A  )', "---------------------------------------"
                state1%PG="XX"
                call symm_atoms(state1,isym,Osym,rotate=.false.,nsym_ops=nsym)
                ! Check the symmetry of the correction term
                ! First compute the correction term (was already computed)
                Aux2(1:3*Nat,1:3*Nat) = Aux(1:3*Nat,1:3*Nat)
                ! Print if verbose level is high
                if (verbose>2) &
                    call MAT0(6,Aux2,3*Nat,3*Nat,"gs*Bder matrix")
                ! Check all detected symmetry ops
                do iop=1,Nsym
                    Aux(1:3*Nat,1:3*Nat) = dfloat(Osym(iop,1:3*Nat,1:3*Nat))
                    Aux(1:3*Nat,1:3*Nat) = matrix_basisrot(3*Nat,3*Nat,Aux,Aux2,counter=.true.)
                    Theta=0.d0
                    do i=1,3*Nat 
                    do j=1,3*Nat
                        if (Theta < abs(Aux(i,j)-Aux2(i,j))) then
                            Theta = abs(Aux(i,j)-Aux2(i,j))
                            Theta2=Aux2(i,j)
                        endif
                    enddo
                    enddo
                    print'(X,A,I0)', "Symmetry operation :   ", iop
                    print'(X,A,F10.6)',   " Max abs difference : ", Theta
                    print'(X,A,F10.6,/)', " Value before sym op: ", Theta2
                enddo
                print'(X,A,/)', "---------------------------------------"
            endif
        
        elseif (do_correct_num) then ! DEPRECATED
            print'(X,A,/)', "Apply correction for vertical case based on numerical derivates (not-tested)..."
            ! Correct with numerical derivatives of Lcart matrix
            ! The derivatives are computed externally and fed through
            ! files. This is not working for the moment.
            !
            !Compute H_Q = L1^t Hess L1  +  gx LLL^x
            Hess2(1:Nvib,1:Nvib) = matrix_basisrot(Nvib,3*Nat,L1,Hess,counter=.true.)
            ! Fill Lder tensor
            derfile_base=derfile
            do j=1,Nvib
                write(derfile,'(A,I0,A)') trim(adjustl(derfile_base)), j, ".dat"
                open(I_DER,file=derfile,status='old',iostat=IOstatus)
                if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(derfile)) )
                do i=1,3*Nat
                    ! Use the symbol Bder, but it is Lder!
                    read(I_DER,*) Bder(i,j,1:Nvib)
                enddo
                close(I_DER)
            enddo
        
            if (verbose>2) then
                do i=1,3*Nat
                    write(tmpfile,'(A,I0,A)') "Lder *10^6, Cart=",i
                    call MAT0(6,Bder(i,:,:)*1.e6,Nvib,Nvib,trim(tmpfile))
                enddo
            endif
        
            do i=1,Nvib
            do j=1,Nvib
                Aux(i,j) = 0.d0
                do l=1,3*Nat
                    Aux(i,j) = Aux(i,j) + Grad(l) * Bder(l,j,i) 
                enddo
                Hess2(i,j) = Hess2(i,j) + Aux(i,j)
            enddo
            enddo
        
            ! We need gQ...
        
        else
            print'(X,A,/)', "Uncorrected vertical approach (Q1-space)"
            ! Do not apply any correction (original PCCP2011 implementation)
            !Compute H_Q = L1^t Hess L1 
            Hess2(1:Nvib,1:Nvib) = matrix_basisrot(Nvib,3*Nat,L1,Hess,counter=.true.)
        
        endif
        
        !-------------------
        ! Duschisky matrix
        !-------------------
        print'(/,X,A,/)', "DIAGONALIZE HESSIAN IN Q1-SPACE..."
        ! The matrix that diagonalizes the Hessian in Q1 modes is the Duschisky matrix
        call diagonalize_full(Hess2(1:Nvib,1:Nvib),Nvib,G1(1:Nvib,1:Nvib),FC(1:Nvib),"lapack")
        if (verbose>2) &
            call MAT0(6,G1,Nvib,Nvib,"DUSCHINSKI MATRIX")
        
        !---------
        !Check FC
        !---------
        if (verbose>1) &
            call print_vector(6,FC*1.d6,Nvib,"FORCE CONSTANTS x 10^6 (A.U.)")
        !Transform FC to Freq
        do i=1,Nvib
            Freq2(i) = sign(dsqrt(abs(FC(i))*HARTtoJ/BOHRtoM**2/AUtoKG)/2.d0/pi/clight/1.d2,&
                             FC(i))
            if (FC(i)<0) then
                print*, i, FC(i)
                call alert_msg("warning","A negative FC found")
            endif
        enddo
        if (verbose>0) &
            call print_vector(6,Freq2,Nvib,"Frequencies (cm-1)")
        
        ! Restore L1 in MWC
        call Lcart_to_Lmwc(Nat,Nvib,state1%atom(:)%Mass,L1,L1,error)

    else ! Adiabati and Vertical uncorrected
        ! Direct formula (L1 and L2 in MWC)
        G1(1:Nvib,1:Nvib) = matrix_product(Nvib,Nvib,3*Nat,L1,L2,tA=.true.)

    endif


    !==============
    ! SHIFT VECTOR
    !==============
    call set_geom_units(state1,"Bohr")
    call set_geom_units(state2,"Bohr")
    ! In Xspace
    if (vertical) then
        ! Get minimum in Cartesian coordinates: x0 = - F^-1 grad
        ! At this pont
        !  Hess: State2 Hessian  in Cartesian
        !  Grad: State2 Gradient in Cartesian
        Aux(1:3*Nat,1:3*Nat) = inverse_realsym(3*Nat,Hess)
        ! Delta vector
        do i=1, 3*Nat
            Delta(i)=0.d0
            do k=1,3*Nat
                Delta(i) = Delta(i) - Aux(i,k) * Grad(k)
            enddo
        enddo
        
        do i=1,Nat 
            j=3*i-2
            state2%atom(i)%x = (state1%atom(i)%x + Delta(j+0))
            state2%atom(i)%y = (state1%atom(i)%y + Delta(j+1))
            state2%atom(i)%z = (state1%atom(i)%z + Delta(j+2))
        enddo
    else ! Adiabatic
        ! Compute Delta from initial and final states
        do i=1,Nat 
            j=3*i-2
            Delta(j+0) = state2%atom(i)%x - state1%atom(i)%x
            Delta(j+1) = state2%atom(i)%y - state1%atom(i)%y
            Delta(j+2) = state2%atom(i)%z - state1%atom(i)%z
        enddo
    endif

    print'(/,X,A)', "=================" 
    print'(X,A)',   " SHIFT CARTESIAN " 
    print'(X,A)',   "================="
    print*, "                 Delta (Angs)" 
    print*, "Atom        x         y         z "
    do i=1,Nat 
        j=3*i-2
        print'(I3,3X, 3F10.3)', i, Delta(j)*BOHRtoANGS, Delta(j+1)*BOHRtoANGS, Delta(j+2)*BOHRtoANGS
    enddo
    print*, ""
    ! Check the rotation of the Ekart frame
    print'(/,A)', "------------------------------------------------------------"
    print'(X,A)', "ESTIMATION OF THE MOLECULAR TRASLATION/ROTATION (CARTESIAN) "
!     print'(X,A)', "ALONG THE MINIMIZATION IN X-SPACE"
    print'(A)',   "------------------------------------------------------------"

    call set_geom_units(state1,"Angs")
    call set_geom_units(state2,"Angs")

    !Traslation:
    call get_com(state1)
    call get_com(state2)
    DeltaCOM(1) = state1%comX - state2%comX
    DeltaCOM(2) = state1%comY - state2%comY
    DeltaCOM(3) = state1%comZ - state2%comZ
    call print_vector(6,DeltaCOM,3,"Traslation from State1 to State2")

    ! The rotation can be computed from the diagonalization of the matrix
    ! of moment of inertia for each geometry
    call inertia(state1,IM)
    call diagonalize_full(IM(1:3,1:3),3,Xrot1(1:3,1:3),Vec(1:3),"lapack")
    if (verbose>1) &
     call MAT1(6,Xrot1,Vec,3,3,"Xrot (state1)")
    call inertia(state2,IM)
    call diagonalize_full(IM(1:3,1:3),3,Xrot2(1:3,1:3),Vec(1:3),"lapack")
    if (verbose>1) &
     call MAT1(6,Xrot2,Vec,3,3,"Xrot (state2)")
    !
    ! The rotation from one geometry to the other is then:
    ! Rot = Xrot1^t  Xrot2
    T(1:3,1:3) = matrix_product(3,3,3,Xrot1,Xrot2,tA=.true.)

    call MAT0(6,T,3,3,"Rotation from State1 to State2")

!     if (vertical) then
!         call rotate_molec(state2,T)
!         ! Rotate Hess (to properly compute the Er):
!         ! Rot Hess Rot^t
!         Hess(1:3*Nat,1:3*Nat) = rotate3D_matrix(3*Nat,3*Nat,Hess,T)
!         ! The other part is done as
!         ! A Rot^t = (Rot A^t)^t
!         Hess(1:3*Nat,1:3*Nat) = rotate3D_matrix(3*Nat,3*Nat,Hess,T,tA=.true.)
!         ! Ne need to transpose again, since Hess is symmetric
!     endif

    ! In Qspace
    if (vertical.and.verticalQspace1) then
        !--------------------------------------------------------
        ! Shift vector
        !--------------------------------------------------------
        ! K = J * Q0 = J * [-FC^-1 * J * gQ]
        ! Where
        ! * J is the Duschisky matrix for the VH model
        ! * Q0   is the equilibrium geometry in terms of state2 Qspace
        !        note that the displacement is actually -Qo, but in state1 Qspace
        ! * FC are the diagonal force constant matrix for state2 (diagonal in the state2 Qspace)
        ! * gQ is the gradient of state2 in Cartesia
        ! At this point we have
        !  * G1  : Duschinski
        !  * Grad: Cartesian
        !  * L1  : MWC
        !--------------------------------------------------------
        ! We need gQ, in state1 normal modes. But we need them consistent with
        ! L1 in Cartesian coordinates (NOT in internal). Both have the 
        ! same values, but the sign may change
        ! gQ = L^t * gx
        do i=1,Nvib 
            Vec(i) = 0.d0
            do k=1,3*Nat
                kk = (k-1)/3+1
                Vec(i) = Vec(i) + L1(k,i) * Grad(k) / dsqrt(state1%atom(kk)%mass*AMUtoAU)
            enddo
        enddo
        Grad(1:Nvib) = Vec(1:Nvib)
        ! Q0 = - FC^-1 * J^t * gQ
        print'(X,A,/)', "COMPUTE SHIFT VECTOR..."
        do i=1,Nvib
            Q0(i) = 0.d0
            do k=1,Nvib
                Q0(i) = Q0(i) - G1(k,i) * Grad(k) / FC(i)
            enddo
        enddo
        
        if (verbose>2) then
            call print_vector(6,FC*1e5,Nvib,"FC - crt")
            call print_vector(6,Grad*1e5,Nvib,"Grad - crt")
            call print_vector(6,Q0,Nvib,"Q0 - crt")
        endif
   !     K = J * Q0
        do i=1,Nvib
            Vec1(i) = 0.d0
            do k=1,Nvib
                Vec1(i) = Vec1(i) + G1(i,k) * Q0(k)
            enddo
        enddo

    elseif (vertical.and.verticalQspace2) then
        !--------------------------------------------------------
        ! Shift vector
        !--------------------------------------------------------
        ! Apply vertical model in the Qspace (get S2 equilibrium --Delta-- within the normal mode coordinate space)
        ! 
        ! K = -J * Lambda_f^-1 * L2^t * gx
        ! At this point we have
        !  * G1  : Duschinski
        !  * Grad: Cartesian
        !  * L2  : MWC
        !
        ! Convert Freq into FC. Store in FC for future use
        do i=1,Nvib
            FC(i) = sign((Freq2(i)*2.d0*pi*clight*1.d2)**2/HARTtoJ*BOHRtoM**2*AUtoKG,Freq2(i))
            if (FC(i)<0) then
                print*, i, FC(i)
                call alert_msg("warning","A negative FC found")
            endif
        enddo
        ! Lambda_f^-1 * L2^t
        do i=1,Nvib
            do k=1,3*Nat
                kk = (k-1)/3+1
                Aux(i,k) = L2(k,i) / FC(i) / dsqrt(state2%atom(kk)%mass*AMUtoAU)
            enddo
        enddo
        ! -[Lambda_f^-1 * L2^t] * gx
        do i=1,Nvib
            Q0(i)=0.d0
            do k=1,3*Nat
                Q0(i) = Q0(i) - Aux(i,k) * Grad(k)
            enddo
        enddo
        ! J * [-Lambda_f^-1 * L2^t * gs]
        do i=1,Nvib
            Vec1(i)=0.d0
            do k=1,Nvib
                Vec1(i) = Vec1(i) + G1(i,k) * Q0(k)
            enddo
        enddo

    else ! Vertical(Cart) and Adiabatic
        ! K = L1^-1 Delta
        ! At this point we have
        !  * L1   : MWC
        !  * Delta: Cartesiand disp in atomic units
        do i=1,Nvib
            Vec1(i) = 0.d0
            do k=1,3*Nat 
                kk = (k-1)/3+1
                Vec1(i) = Vec1(i) + L1(k,i) * Delta(k) * dsqrt(state1%atom(kk)%mass*AMUtoAU)
            enddo
        enddo

    endif

    !Analyze Duschinsky matrix
    call analyze_duschinsky(6,Nvib,G1,Vec1,Freq1,Freq2)


    !=======================
    ! REORGANIZATION ENERGY
    !=======================
    print*, "REORGANIZATION ENERGY"
    if (verticalQspace2) then
        print*, "Vertical model / Q2space"
        ! Normal-mode space
        ! Er = -L2^t gx * Q0 - 1/2 * Q0^t * Lambda_f * Q0
        ! At this point: 
        ! * Grad: gradient in Cartesian
        ! * Q0  : DeltaQ in state2 Qspace
        ! * FC  : diagonal force constants for final state
        Er = 0.d0
        do i=1,Nvib
            ! Compute gQ(i) = L2^t * gx
            Theta = 0.d0
            do k=1,3*Nat
                kk = (k-1)/3+1
                Theta =  Theta + L2(k,i)*Grad(k) / dsqrt(state2%atom(kk)%mass*AMUtoAU)
            enddo
            Er = Er - Theta * Q0(i) - 0.5d0 * FC(i) * Q0(i)**2
        enddo
    elseif (verticalQspace1) then
        print*, "Vertical model / Q1space"
        ! Normal-mode space
        ! Er = -gQ * Q0 - 1/2 * Q0^t * Lambda_f * Q0
        ! At this point: 
        ! * Grad: gradient in state1 normal modes (Qspace)
        ! * Q0  : DeltaQ in state2 Qspace
        ! * FC  : diagonal force constants for final state
        Er = 0.d0
        do i=1,Nvib
            ! Get gradient in state2 Qspace
            ! gQ2 = J^t * gQ1
            Theta=0.d0
            do k=1,Nvib
                Theta = Theta + G1(k,i) * Grad(k)
            enddo
            Er = Er - Theta * Q0(i) - 0.5d0 * FC(i) * Q0(i)**2
        enddo
    elseif (vertical) then
        print*, "Vertical model / X space"
        ! Internal-coordinates space
        ! Er = -gx * DeltaX - 1/2 DeltaX^t * Hx * DeltaX
        ! At this point (all data in the non-redundant IC space)
        ! * Grad: in Cartesian
        ! * Delta: DeltaX
        ! * Hess: Hessian in Cartesian
        !
        ! Fisrt, compute DeltaX^t * Hx * DeltaX
        Theta=0.d0
        do j=1,3*Nat
        do k=1,3*Nat
            Theta = Theta + Delta(j)*Delta(k)*Hess(j,k)
        enddo
        enddo
        Er = -Theta*0.5d0
        do i=1,3*Nat
            Er = Er - Grad(i)*Delta(i)
        enddo
    else ! Adiabatic
        print*, "Adiabatic model / X space"
        ! Er = 1/2 DeltaX^t * Hx * DeltaX
        ! At this point (all data in the non-redundant IC space)
        ! * Grad: in Cartesian
        ! * Delta: DeltaX
        ! * Hess: Hessian in Cartesian
        !
        ! Fisrt, compute DeltaS^t * Hs * DeltaS
        Theta=0.d0
        do j=1,3*Nat
        do k=1,3*Nat
            Theta = Theta + Delta(j)*Delta(k)*Hess(j,k)
        enddo
        enddo
        Er = Theta*0.5d0
    endif
    print'(X,A,F12.6)',   "Reorganization energy (AU) = ", Er
    print'(X,A,F12.6,/)', "Reorganization energy (eV) = ", Er*HtoeV



    !============================================
    ! PRINT DUSCHINSKI AND DISPLACEMENT TO FILES
    !============================================
    print*, "Printing Duschinski matrix to 'duschinsky.dat'"
    open(O_DUS, file="duschinsky.dat")
    print'(X,A,/)', "Printing Shift vector to 'displacement.dat'"
    open(O_DIS, file="displacement.dat")
    do i=1,Nvib
    do j=1,Nvib
        write(O_DUS,*)  G1(i,j)
    enddo 
        write(O_DIS,*)  Vec1(i)
    enddo
    close(O_DUS)
    close(O_DIS)

    !====================
    ! Print state files
    !====================
    ! State1
    call Lcart_to_LcartNrm(Nat,Nvib,L1,Aux,error)
    !Print state
    open(O_STAT,file="state_file_1")
    call set_geom_units(state1,"Angs")
    do i=1,Nat
        write(O_STAT,*) state1%atom(i)%x
        write(O_STAT,*) state1%atom(i)%y
        write(O_STAT,*) state1%atom(i)%z
    enddo
    do i=1,3*Nat
    do j=1,Nvib
        write(O_STAT,*) Aux(i,j)
    enddo
    enddo
    do j=1,Nvib
        write(O_STAT,'(F12.5)') Freq1(j)
    enddo
    close(O_STAT)
    ! State2
    ! L2 = L1 * J
    L2(1:3*Nat,1:Nvib) = matrix_product(3*Nat,Nvib,Nvib,L1,G1)
    call Lcart_to_LcartNrm(Nat,Nvib,L2,Aux,error)
    !Print state
    ! Note that the geometry is that of state1 (not displaced for vertical)
    ! But it is ok for FCclasses (it is not using it AFIK) What about HT??
    open(O_STAT,file="state_file_2")
    do i=1,Nat
        write(O_STAT,*) state2%atom(i)%x
        write(O_STAT,*) state2%atom(i)%y
        write(O_STAT,*) state2%atom(i)%z
    enddo
    do i=1,3*Nat
    do j=1,Nvib
        write(O_STAT,*) Aux(i,j)
    enddo
    enddo
    do j=1,Nvib
        write(O_STAT,'(F12.5)') Freq2(j)
    enddo
    close(O_STAT)



    call summary_alerts

    call cpu_time(tf)
    write(6,'(/,A,X,F12.3,/)') "CPU time (s)", tf-ti

    stop


    !==============================================
    contains
    !=============================================

    subroutine parse_input(inpfile,ft,gradfile,ftg,hessfile,fth,inpfile2,ft2,gradfile2,ftg2,hessfile2,fth2,&
                           cnx_file,intfile,rmzfile,def_internal,use_symmetry,derfile,do_correct_num,do_correct_int,&
                           gradcorrectS1,vertical,verticalQspace1,verticalQspace2)
    !==================================================
    ! My input parser (gromacs style)
    !==================================================
        implicit none

        character(len=*),intent(inout) :: inpfile,ft,gradfile,ftg,hessfile,fth,gradfile2,ftg2,hessfile2,fth2,&
                                          cnx_file,intfile,rmzfile,def_internal,derfile,inpfile2,ft2
        logical,intent(inout)          :: use_symmetry,do_correct_num,do_correct_int,gradcorrectS1,vertical,&
                                          verticalQspace1,verticalQspace2
        ! Local
        logical :: argument_retrieved,  &
                   need_help = .false.
        integer:: i
        character(len=200) :: arg

        argument_retrieved=.false.
        do i=1,iargc()
            if (argument_retrieved) then
                argument_retrieved=.false.
                cycle
            endif
            call getarg(i, arg) 
            select case (adjustl(arg))
                case ("-f") 
                    call getarg(i+1, inpfile)
                    argument_retrieved=.true.
                case ("-ft") 
                    call getarg(i+1, ft)
                    argument_retrieved=.true.

                case ("-fhess") 
                    call getarg(i+1, hessfile)
                    argument_retrieved=.true.
                case ("-fth") 
                    call getarg(i+1, fth)
                    argument_retrieved=.true.

                case ("-fgrad") 
                    call getarg(i+1, gradfile)
                    argument_retrieved=.true.
                case ("-ftg") 
                    call getarg(i+1, ftg)
                    argument_retrieved=.true.

                case ("-f2") 
                    call getarg(i+1, inpfile2)
                    argument_retrieved=.true.
                case ("-ft2") 
                    call getarg(i+1, ft2)
                    argument_retrieved=.true.

                case ("-fhess2") 
                    call getarg(i+1, hessfile2)
                    argument_retrieved=.true.
                case ("-fth2") 
                    call getarg(i+1, fth2)
                    argument_retrieved=.true.

                case ("-fgrad2") 
                    call getarg(i+1, gradfile2)
                    argument_retrieved=.true.
                case ("-ftg2") 
                    call getarg(i+1, ftg2)
                    argument_retrieved=.true.

                case ("-intfile") 
                    call getarg(i+1, intfile)
                    argument_retrieved=.true.

                case ("-rmzfile") 
                    call getarg(i+1, rmzfile)
                    argument_retrieved=.true.
                ! Kept for backward compatibility (but replaced by -rmzfile)
                case ("-rmz") 
                    call getarg(i+1, rmzfile)
                    argument_retrieved=.true.

                case ("-intmode")
                    call getarg(i+1, def_internal)
                    argument_retrieved=.true.
                ! Kept for backward compatibility (but replaced by -intmode)
                case ("-intset")
                    call getarg(i+1, def_internal)
                    argument_retrieved=.true.

                case ("-vertQ1")
                    vertical=.true.
                    verticalQspace1=.true.
                    verticalQspace2=.false.
                case ("-novertQ1")
                    verticalQspace1=.false.
                case ("-vertQ2")
                    vertical=.true.
                    verticalQspace2=.true.
                    verticalQspace1=.false.
                case ("-novertQ2")
                    verticalQspace2=.false.
                case ("-vert")
                    vertical=.true.
                    verticalQspace1=.false.
                    verticalQspace2=.false.
                case ("-novert")
                    vertical=.false.
                    verticalQspace1=.false.
                    verticalQspace2=.false.

                case ("-sym")
                    use_symmetry=.true.
                case ("-nosym")
                    use_symmetry=.false.

                case ("-cnx")
                    call getarg(i+1, cnx_file)
                    argument_retrieved=.true.

                ! -corrS1 has no effect now
                ! (only if vib analysis in intenal coords was done)
                case ("-corrS1")
                    do_correct_int=.true.
                case ("-nocorrS1")
                    do_correct_int=.false.
                    gradcorrectS1=.false.
        
                case ("-corrS2")
                    do_correct_int=.true.
                case ("-nocorrS2")
                    do_correct_int=.false.
                    gradcorrectS1=.false.
                !Keep for backward compatibility
                case ("-correct-int")
                    do_correct_int=.true.
                case ("-nocorrect-int")
                    do_correct_int=.false.
                    gradcorrectS1=.false.

                ! Deprecated options (numerical ders)
                case ("-correct-num")
                    do_correct_num=.true.
                case ("-nocorrect-num")
                    do_correct_num=.false.
                case ("-fder") 
                    call getarg(i+1, derfile)
                    argument_retrieved=.true.

                case ("-h")
                    need_help=.true.

                ! Control verbosity
                case ("-quiet")
                    verbose=0
                case ("-concise")
                    verbose=1
                case ("-v")
                    verbose=2
                case ("-vv")
                    verbose=3

                case default
                    call alert_msg("fatal","Unkown command line argument: "//adjustl(arg))
            end select
        enddo 

       ! Manage defaults
       ! If not declared, hessfile and gradfile are the same as inpfile
       if (adjustl(hessfile) == "same") then
           hessfile=inpfile
           if (adjustl(fth) == "guess")  fth=ft
       endif
       if (adjustl(gradfile) == "same") then
           gradfile=inpfile
           if (adjustl(ftg) == "guess")  ftg=ft
       endif
       if (adjustl(hessfile2) == "same") then
           hessfile2=inpfile2
           if (adjustl(fth2) == "guess")  fth2=ft2
       endif
       if (adjustl(gradfile2) == "same") then
           gradfile2=inpfile2
           if (adjustl(ftg2) == "guess")  ftg2=ft2
       endif


       !Print options (to stdout)    
        write(6,'(/,A)') '========================================================'
        write(6,'(/,A)') '      C A R T E S I A N   D U S C H I N S K Y        '
        write(6,'(/,A)') '         Duschinski analysis for Vertical         '
        write(6,'(A,/)') '          model in Cartesian coordinates          '      
        call print_version()
        write(6,'(/,A)') '========================================================'
        write(6,'(/,A)') '-------------------------------------------------------------------'
        write(6,'(A)')   ' Flag         Description                   Value'
        write(6,'(A)')   '-------------------------------------------------------------------'
        write(6,*) '-f           Input file (State1)           ', trim(adjustl(inpfile))
        write(6,*) '-ft          \_ FileType                   ', trim(adjustl(ft))
        write(6,*) '-fhess       Hessian(S1) file              ', trim(adjustl(hessfile))
        write(6,*) '-fth         \_ FileType                   ', trim(adjustl(fth))
        write(6,*) '-fgrad       Gradient(S1) file             ', trim(adjustl(gradfile))
        write(6,*) '-ftg         \_ FileType                   ', trim(adjustl(ftg))
        write(6,*) '-f2          Input file (State2)           ', trim(adjustl(inpfile2))
        write(6,*) '-ft2         \_ FileType                   ', trim(adjustl(ft2))
        write(6,*) '-fhess2      Hessian(S2) file              ', trim(adjustl(hessfile2))
        write(6,*) '-fth2        \_ FileType                   ', trim(adjustl(fth2))
        write(6,*) '-fgrad2      Gradient(S2) file             ', trim(adjustl(gradfile2))
        write(6,*) '-ftg2        \_ FileType                   ', trim(adjustl(ftg2))
        write(6,*) ''
        write(6,*) '** Options correction method (vertical) **'
        write(6,*) '-[no]vert    Vertical model                ', vertical
        write(6,*) '-[no]vertQ1  Vertical in normal-mode space ', verticalQspace1
        write(6,*) '-[no]vertQ2  Vertical in normal-mode space ', verticalQspace2
        write(6,*) '-[no]corrS2  Correction with analytical L1 ', do_correct_int
        write(6,*) '             derivatives based on internal '
        write(6,*) '             analysis (alias -correct-int) '
        write(6,*) '-[no]corrS1  Correct S1 at vib-in(useless) ', gradcorrectS1
        write(6,*) '-cnx         Connectivity [filename|guess] ', trim(adjustl(cnx_file))
        write(6,*) '-intmode     Internal set [zmat|sel|all]   ', trim(adjustl(def_internal))
        write(6,*) '             (-correct-int)'               
        write(6,*) '-intfile     File with internal set def.   ', trim(adjustl(intfile))
        write(6,*) '             (-correct-int -intmode sel)   '
!         write(6,*) '-rmzfile        ', trim(adjustl(rmzfile))
        write(6,*) '-[no]sym     Use symmetry to form Zmat    ',  use_symmetry
        write(6,*) '·· Correct with Numeric Lder [deprecated] ··'
        write(6,*) '-[no]correct-num Correction with numerical ', do_correct_num
        write(6,*) '             derivatives of L1 (Cart)      '
        write(6,*) '-fder        Numerical derivative file     ', trim(adjustl(derfile))
        write(6,*) '             basename (-correct-num)       '
        write(6,*) ''
        write(6,*) '-h               ',  need_help
        write(6,'(A)') '-------------------------------------------------------------------'
        write(6,'(X,A,I0)') &
                       'Verbose level:  ', verbose        
        write(6,'(A)') '-------------------------------------------------------------------'
        if (do_correct_int.and.vertical.and..not.verticalQspace1) &
         call alert_msg("fatal","No correction possible within X-space (-vert). Use Q1-space instead (-vertQ1)")
        if (need_help) call alert_msg("fatal", 'There is no manual (for the moment)' )

        return
    end subroutine parse_input
       

end program cartesian_duschinsky
