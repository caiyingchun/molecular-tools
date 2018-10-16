program normal_modes_internal


    !==============================================================
    ! This code uses of MOLECULAR_TOOLS 
    !==============================================================
    !
    ! Description:
    ! -----------
    ! Program to visualize vibrations obtained in internal coordinates.
    !
    !============================================================================    

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
    use io
    !============================================
    !   Structure types module
    !============================================
    use structure_types
    !============================================
    !   File readers
    !============================================
    use generic_io
    use generic_io_molec
    use xyz_manage_molec
    use gro_manage
    use gaussian_manage
    !============================================
    !  Structure-related modules
    !============================================
    use molecular_structure
    use atomic_geom
    use symmetry
    !============================================
    !  Internal thingies
    !============================================
    use internal_module
    use zmat_manage 
    use vibrational_analysis
    use thermochemistry
    use vertical_model

    implicit none

    integer,parameter :: NDIM = 600

    !====================== 
    !Options 
    logical :: use_symmetry=.false.,   &
               include_hbonds=.false., &
               vertical=.false.,       &
               analytic_Bder=.true.,  &
               check_symmetry=.true.,  &
               animate=.true.,         &
               project_on_all=.false.,  &
               apply_projection_matrix=.false., &
               complementay_projection=.false., &
               rm_gradcoord=.false.,            &
               complementay_gradient = .false., &
               do_zmap
    !======================

    !====================== 
    !System variables
    type(str_resmol) :: molecule, molec_aux
    type(str_bonded) :: zmatgeom, allgeom, currentgeom, inputgeom
    integer,dimension(1:NDIM) :: isym
    integer,dimension(4,1:NDIM,1:NDIM) :: Osym
    integer :: Nsym
    integer :: Nat, Nvib, Ns, Nvib0, NvibP, NvibP2, Nf, N
    integer :: Ns_zmat, Ns_all, Nvib_all
    character(len=5) :: PG
    real(8) :: Tthermo=0.d0
    !Job info
    character(len=20) :: calc, method, basis
    character(len=150):: title

    real(8) :: val1,val2,val3,val4,val5,val6
    integer :: imax,jmax,kmax, kk, jj1,jj2,jj3, kk1,kk2,kk3, kkmax, jjmax
    !====================== 

    !====================== 
    !Auxiliar variables
    character(1) :: null
    character(len=50) :: dummy_char
    real(8) :: dist
    !io flags
    integer :: error, info
    !====================== 

    !=============
    !Counters
    integer :: i,j,k,l, ii,jj, iop
    !=============

    !====================== 
    ! PES topology and normal mode things
    real(8),dimension(:),allocatable :: Hlt, grdx
    real(8),dimension(1:NDIM,1:NDIM) :: Hess, Hess_all, LL, LL_all, gBder, P, Fltr
    real(8),dimension(NDIM) :: Freq, Freq_all, Factor, Grad, Vec1, Vec
    !Moving normal modes
    character(len=50) :: selection="none"
    real(8) :: Amplitude = 2.d0, qcoord
    integer,dimension(1:NDIM) :: nm=0
    real(8) :: Qstep
    logical :: call_vmd = .false.
    character(len=10000) :: vmdcall
    integer :: Nsteps, Nsel, istep
    !MOVIE things
    logical :: movie_vmd = .false.
    integer :: movie_cycles=0,& !this means no movie
               movie_steps
    !====================== 

    !====================== 
    !INTERNAL CODE THINGS
    real(8),dimension(1:NDIM,1:NDIM) :: B, G, Asel, Asel_all, B0, G0, Asel0, Bprj, Bprj2
    real(8),dimension(1:NDIM,1:NDIM,1:NDIM) :: Bder
    real(8),dimension(1:NDIM,1:NDIM) :: X,Xinv
    !Save definitio of the modes in character
    character(len=100),dimension(NDIM) :: ModeDef
    character(len=400)                 :: CombDef
    !VECTORS
    real(8),dimension(NDIM) :: S, Sref, Szmat, Sall, DeltaS
    integer,dimension(NDIM) :: S_sym
    ! Switches
    character(len=4) :: def_internal="ALL",  & ! To do the vibrational analysis
                        def_internal0='defa',& ! defa(ult) is "the same as working set"
                        conversion_i2c="ZMAT"
    character(len=2) :: scan_type="NM"
    !Coordinate map
    integer,dimension(NDIM) :: Zmap, IntMap
    ! Number of ic (Shortcuts)
    integer :: nbonds, nangles, ndihed, nimprop
    !====================== 

    !====================== 
    !Auxiliar
    real(8),dimension(1:NDIM,1:NDIM) :: Aux, Aux2, Aux3
    real(8) :: Theta, Theta2
    character(len=5) :: current_symm
    !====================== 

    !================
    !I/O stuff 
    !units
    integer :: I_INP=10,  &
               I_SYM=12,  &
               I_RMF=16,  &
               I_CNX=17,  &
               I_MAS=19,  &
               O_GRO=20,  &
               O_G09=21,  &
               O_G96=22,  &
               O_Q  =23,  &
               O_NUM=24,  &
               O_MOV=25,  &
               O_PRJ=26,  &
               S_VMD=30

    !files
    character(len=10) :: ft ="guess",  ftg="guess",  fth="guess", ftn="guess"
    character(len=200):: inpfile  ="state1.fchk", &
                         gradfile ="same", &
                         hessfile ="same", &
                         nmfile   ="none", &
                         intfile  ="none", &
                         intfile0 ="default", & ! default is "the same as working set"
                         rmzfile  ="none", &
                         symm_file="none", &
                         mass_file="none", &
                         cnx_file="guess"
    !Structure files to be created
    character(len=100) :: g09file,qfile, tmpfile, g96file, grofile,numfile
    !status
    integer :: IOstatus
    !===================

    !===================
    !CPU time 
    real(8) :: ti, tf
    !===================

    call cpu_time(ti)

    !--------------------------
    ! Tune io
    !--------------------------
    ! Set unit for alert messages
    alert_unt=6
    ! Activate notes
    silent_notes = .false.
    !--------------------------

    !===========================
    ! Allocate atoms (default)
    call allocate_atoms(molecule)
    call allocate_atoms(molec_aux)
    !===========================

    ! 0. GET COMMAND LINE ARGUMENTS
    call parse_input(&
                     ! input data
                     inpfile,ft,hessfile,fth,gradfile,ftg,nmfile,ftn,mass_file,&
                     ! Options (general)
                     Amplitude,call_vmd,include_hbonds,selection,vertical, &
                     ! Movie
                     animate,movie_vmd, movie_cycles,conversion_i2c,       &
                     ! Options (internal)
                     use_symmetry,def_internal,def_internal0,intfile,intfile0,&
                     apply_projection_matrix,complementay_projection,      &
                     rmzfile,scan_type,  &
                     project_on_all,rm_gradcoord,complementay_gradient,    &
                     ! connectivity file
                     cnx_file,                                             &
                     ! thermochemical analysis
                     Tthermo,                                              &
                     ! (hidden)
                     analytic_Bder)
    call set_word_upper_case(def_internal)
    call set_word_upper_case(conversion_i2c)


    ! INTERNAL VIBRATIONAL ANALYSIS
 
    ! 1. READ DATA
    ! ---------------------------------
    call heading(6,"INPUT DATA")
    !Guess filetypes
    if (ft == "guess") &
    call split_line_back(inpfile,".",null,ft)
    if (fth == "guess") &
    call split_line_back(hessfile,".",null,fth)
    if (ftg == "guess") &
    call split_line_back(gradfile,".",null,ftg)
    if (ftn == "guess") &
    call split_line_back(nmfile,".",null,ftn)

    ! Manage special files (fcc) 
    if (adjustl(ft) == "fcc-state" .or. adjustl(ftn) == "fcc-state") then
        call alert_msg("note","fcc-state files needs fcc-input as -f and statefile as -ftn")
        ft ="fcc-state"
        ftn="fcc-state"
        ! inpfile has Nat, Nvib, and Masses          <= in inpfile
        ! statefile has coordinates and normal modes <= in hessfile
        ! Generic generic readers parse the state (not the inpfile)
        ! so we get the info here
        open(I_INP,file=inpfile,status='old',iostat=IOstatus)
        if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(inpfile)) )
        read(I_INP,*) Nat 
        molecule%natoms = Nat
        read(I_INP,*) Nvib
        do i=1,Nat 
            read(I_INP,*) molecule%atom(i)%mass
            !Set atomnames from atommasses
            call atominfo_from_atmass(molecule%atom(i)%mass,  &
                                      molecule%atom(i)%AtNum, &
                                      molecule%atom(i)%name)
        enddo
        close(I_INP)
        ! Now put the statefile in the inpfile
        inpfile=nmfile
    elseif (adjustl(ftn) == "log") then
        ! Need to read the standard orientation, not from summary section
        ft = "log-stdori"
    endif
        
    ! STRUCTURE FILE
    call statement(6,"READING STRUCTURE...")
    open(I_INP,file=inpfile,status='old',iostat=IOstatus)
    if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(inpfile)) )
    call generic_strmol_reader(I_INP,ft,molecule,error)
    if (error /= 0) call alert_msg("fatal","Error reading geometry")
    ! Get job info if it is a Gaussian file
    if (ft == "log" .or. ft== "fchk") then
        rewind(I_INP) ! this should be a generic_job_rewind() call
        call read_gauss_job(I_INP,ft,calc,method,basis)
        ! Whichever, calc type was, se now need SP
        calc="SP"
    else
        calc="SP"
        method="B3LYP"
        basis="6-31G(d)"
    endif
    close(I_INP)
    ! Shortcuts
    Nat = molecule%natoms

    ! Read mass from file if given
    if (adjustl(mass_file) /= "none") then
        print'(/,X,A)', "Reading atomic masses from: "//trim(adjustl(mass_file))
        open(I_MAS,file=mass_file,status='old',iostat=IOstatus)
        if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(mass_file)) )
        do i=1,Nat
            read(I_MAS,*,iostat=IOstatus) molecule%atom(i)%mass 
            if (IOstatus /= 0) call alert_msg( "fatal","While reading "//trim(adjustl(mass_file)) )
        enddo
        close(I_MAS)
    endif

    !Only read Grad/Hess or nm if we want to scan norma modes
    if (scan_type == "NM") then
        ! Vibrational analysis: either read from file (fcc) or from diagonalization of Hessian
        if (adjustl(nmfile) /= "none") then
            call statement(6,"READING NORMAL MODES FROM FILE...")
            open(I_INP,file=nmfile,status='old',iostat=IOstatus)
            if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(nmfile)))
            call generic_nm_reader(I_INP,ftn,Nat,Nvib,Freq,LL)
            ! Show frequencies
            if (verbose>0) &
             call print_vector(6,Freq,Nvib,"Frequencies (cm-1)")
            ! The reader provide L in Normalized Cartesian. Need to Transform to Cartesian now
            call LcartNrm_to_Lmwc(Nat,Nvib,molecule%atom(:)%mass,LL,LL)
            call Lmwc_to_Lcart(Nat,Nvib,molecule%atom(:)%mass,LL,LL,error)
            close(I_INP)
        else
            ! HESSIAN FILE
            call statement(6,"READING HESSIAN...")
            open(I_INP,file=hessfile,status='old',iostat=IOstatus)
            if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(hessfile)))
            allocate(Hlt(1:3*Nat*(3*Nat+1)/2))
            call generic_Hessian_reader(I_INP,fth,Nat,Hlt,error)
            if (error /= 0) call alert_msg("fatal","Error reading Hessian (State1)")
            close(I_INP)
            ! Run vibrations_Cart to get the number of Nvib (to detect linear molecules)
            call statement(6,"Performing Preliminary vibrational analysis in Cartesian")
            call vibrations_Cart(Nat,molecule%atom(:)%X,molecule%atom(:)%Y,molecule%atom(:)%Z,&
                                 molecule%atom(:)%Mass,Hlt,Nvib,LL,Freq,error_flag=error)
            Nvib_all=Nvib
           
            ! GRADIENT FILE
            if (adjustl(gradfile) /= "none") then
                call statement(6,"READING GRADIENT FILE...")
                open(I_INP,file=gradfile,status='old',iostat=IOstatus)
                if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(gradfile)) )
                allocate(grdx(1:3*Nat))
                call generic_gradient_reader(I_INP,ftg,Nat,grdx,error)
                close(I_INP)
                if (error /= 0) then
                    print*, "Error reading the Gradient. It will be set to zero"
                    grdx(1:3*Nat) = 0.d0
                endif
            else
                grdx(1:3*Nat) = 0.d0
            endif


        endif
    else
        !We need to provide a value for Nvib. Lets assume non-liear molecules
        Nvib = 3*Nat-6
        Nvib_all=Nvib
    endif
    
    !----------------------------------
    ! MANAGE INTERNAL COORDS
    ! ---------------------------------
    ! General Actions:
    !******************
    ! Get connectivity 
    if (cnx_file == "guess") then
        call guess_connect(molecule)
    else
        print'(/,A,/)', "Reading connectivity from file: "//trim(adjustl(cnx_file))
        open(I_CNX,file=cnx_file,status='old')
        call read_connect(I_CNX,molecule)
        close(I_CNX)
    endif

    ! Manage symmetry
    if (.not.use_symmetry) then
        molecule%PG="C1"
    else if (trim(adjustl(symm_file)) /= "none") then
        call alert_msg("note","Using custom symmetry file: "//trim(adjustl(symm_file)) )
        open(I_SYM,file=symm_file)
        do i=1,molecule%natoms
            read(I_SYM,*) j, isym(j)
        enddo
        close(I_SYM)
        !Set PG to CUStom
        molecule%PG="CUS"
    else
        molecule%PG="XX"
        call symm_atoms(molecule,isym)
    endif

    call set_geom_units(molecule,"BOHR")

    !--------------------------------
    ! Compute projection matrix
    !--------------------------------
    call heading(6,"COMPUTING PROJECTION MATRIX (CARTESIAN)")

    !---------------------------------------
    call subheading(6,"Internal Sets")

    call statement(6,"Set with ALL internal coordinates from connectivity",keep_case=.true.)
    call gen_bonded(molecule)
    call define_internal_set(molecule,"ALL",intfile,rmzfile,use_symmetry,isym,S_sym,Ns,Nf,Fltr)
    allgeom = molecule%geom

    call statement(6,"Set indicated on INPUT: "//trim(def_internal),keep_case=.true.)
    call gen_bonded(molecule)
    call define_internal_set(molecule,def_internal,intfile,rmzfile,use_symmetry,isym,S_sym,Ns,Nf,Fltr)
    ! If not using combinations, the Filter need to be reset to the identity matrix
    if (Nf==0) then
        Nf=Ns
        Fltr(1:Nf,1:Ns) = identity_matrix(Nf)
    endif
    inputgeom = molecule%geom
    !---------------------------------------

    ! Relate input and all geoms
    call internals_mapping(allgeom,inputgeom,IntMap)
    ! Describe Fltr with respect to allset
    N = allgeom%nbonds+allgeom%nangles+allgeom%ndihed
    Aux(1:N,1:N) = 0.d0
    do i=1,Ns
        print*, i, IntMap(i)
    enddo
    do j=1,Nf
        do i=1,Ns
            ii=IntMap(i)
            Aux(j,ii) = Fltr(j,i)
        enddo
    enddo
    ! Get Ns from allgeom
    Ns = allgeom%nbonds+allgeom%nangles+allgeom%ndihed
    Fltr(1:Nf,1:Ns) = Aux(1:Nf,1:Ns)

    ! Get back allgeom
    call heading(6,"Computing modes with ALL set")
    Ns = allgeom%nbonds+allgeom%nangles+allgeom%ndihed
    molecule%geom = allgeom

    ! Rotate gradient and Hessian
    ! Get full Cartesian Hessian from Hlt
    Hess(1:3*Nat,1:3*Nat) = Hlt_to_Hess(3*Nat,Hlt)
    ! Get Cartesian gradient
    Grad(1:3*Nat) = grdx

    ! Compute B, G and, if needed, Bder
    call statement(6,"Computing B, G (with ALL set)",keep_case=.true.)
    call internal_Wilson(molecule,Ns,S,B,ModeDef)
    call internal_Gmetric(Nat,Ns,molecule%atom(:)%mass,B,G)
    if (vertical) then
        call statement(6,"...and Bder for non-stationary point calculation")
        call calc_Bder(molecule,Ns,Bder,analytic_Bder)
    endif

!     ! Compute Projection matrix
!     ! Project out each coordinate on input
!     P(1:Ns,1:Ns) = identity_matrix(Ns)
!     do i=1,Nf
!         Aux(1:Ns,1:Ns) = projection_matrixInt(Ns,Fltr(i,1:Ns),G)
!         P(1:Ns,1:Ns) = matrix_product(Ns,Ns,Ns,Aux,P)
!     enddo

    ! Get non-redundant space
    call subsubheading(6,"Getting the actual vibrational space dimension")
    call redundant2nonredundant(Ns,Nvib,G,Asel)
    call statement(6,"Rotate B, G to non-redundant space", keep_case=.true.)
    ! Rotate Bmatrix
    B(1:Nvib,1:3*Nat) = matrix_product(Nvib,3*Nat,Ns,Asel,B,tA=.true.)
    ! Rotate Gmatrix
    G(1:Nvib,1:Nvib) = matrix_basisrot(Nvib,Ns,Asel(1:Ns,1:Nvib),G,counter=.true.)
    if (vertical) then
        call statement(6,"Also rotate Bder to non-redundant space", keep_case=.true.)
        ! Rotate Bders
        do j=1,3*Nat
            Bder(1:Nvib,j,1:3*Nat) =  matrix_product(Nvib,3*Nat,Ns,Asel,Bder(1:Ns,j,1:3*Nat),tA=.true.)
        enddo
    endif
    ! Rotate coordinates to be removed
    Fltr(1:Nf,1:Nvib) = matrix_product(Nf,Nvib,Ns,Fltr,Asel)

    ! Compute Projection matrix
    call subsubheading(6,"Computing projection matrix")
    ! Project out each coordinate on input
    P(1:Nvib,1:Nvib) = identity_matrix(Nvib)
    do i=1,Nf
        Aux(1:Nvib,1:Nvib) = projection_matrixInt(Nvib,Fltr(i,1:Nvib),G)
        P(1:Nvib,1:Nvib) = matrix_product(Nvib,Nvib,Nvib,Aux,P)
    enddo

    ! Get gradient in internal and project
    call Gradcart2int(Nat,Nvib,Grad,molecule%atom(:)%mass,B,G)
    ! Do NOT perfor the rotation of the gradient before the correction term
!     Grad(1:Nvib) = matrix_vector_product(Nvib,Nvib,P,Grad)

    if (vertical) then
        ! Get the Correction now
        call statement(6," Getting gs^t\beta term")
        ! The correction is applied with the Nvib0 SET
        ! Correct Hessian as
        ! Hx' = Hx - gs^t\beta
        ! Bder(i,j,K)^t * gq(K)
        do i=1,3*Nat
        do j=1,3*Nat
            gBder(i,j) = 0.d0
            do k=1,Nvib
                gBder(i,j) = gBder(i,j) + Bder(k,i,j)*Grad(k)
            enddo
        enddo
        enddo
        if (verbose>2) then
            print*, "Correction matrix to be applied on Hx:"
            call MAT0(6,gBder,3*Nat,3*Nat,"gs*Bder matrix")
        endif

        if (check_symmetry) then
            call check_symm_gsBder(molecule,gBder)
        endif

        ! Apply term to Hess
        Hess(1:3*Nat,1:3*Nat) = Hess(1:3*Nat,1:3*Nat) - gBder(1:3*Nat,1:3*Nat)

    endif

    ! Get Hessian in internal coordinates and project
    call HessianCart2int(Nat,Nvib,Hess,molecule%atom(:)%mass,B,G)
!     Hess(1:Nvib,1:Nvib) = matrix_basisrot(Nvib,Nvib,P,Hess,counter=.true.)
    print*, "Coordinates to remove", Nf
    do i=1,Nf
        print*, "REMOVING", i
        call prj_internalGrad(Hess,Nvib,Fltr(i,1:Nvib),G)
        call gf_method(Nvib,Nvib0,G,Hess,LL,Freq,X,Xinv)
    enddo
    ! The gradient would be rotated now (e.g. to perform a Newton-Raphson step) 
    ! (but not needed int this program)
!     Grad(1:Nvib) = matrix_vector_product(Nvib,Nvib,P,Grad)

    ! Compute modes
    call gf_method(Nvib,Nvib0,G,Hess,LL,Freq,X,Xinv)
    if (Nvib0/=Nvib) then
        print*, "Neglected freqcuencies"
        do i=Nvib0+1,Nvib
            print*, Freq(i)
        enddo
    endif

    if (project_on_all) then
        call subheading(6,"Projecting modes of INPUT set on modes of ALL set")

        !
        ! Prj1 = (LL)^-1 * LL_all
        !
        ! Compute inverse of LL simular to B: LL^+ = (LL^t*LL)^-1 LL^t
!         Aux(1:Nvib0,1:Nvib0) = matrix_product(Nvib0,Nvib0,Nvib,LL,LL,tA=.true.)
!         Aux(1:Nvib0,1:Nvib0) = inverse_realgen(Nvib0,Aux)
!         Aux(1:Nvib0,1:Nvib)  = matrix_product(Nvib0,Nvib,Nvib0,Aux,LL,tB=.true.)
!         call subsubheading(6,"Inverting L matrix")
        call diagonalize_full(LL(1:Nvib,1:Nvib),Nvib,Aux(1:Nvib,1:Nvib),Vec(1:Nvib),"lapack")
        call print_vector(6,Vec,Nvib,"Vec")
        Vec(1:Nvib) = 1.d0/Vec(1:Nvib)
        Aux2(1:Nvib,1:Nvib) = identity_matrix(Nvib)
        do i=1,Nvib
            Aux2(i,i) = Vec(i)
        enddo
        Aux3(1:Nvib,1:Nvib) = matrix_basisrot(Nvib,Nvib,Aux,Aux2,counter=.false.)
!         call generalized_inv(Nvib,NvibP2,LL,Aux)
        Aux(1:Nvib,1:Nvib) = inverse_realgen(Nvib,LL)
        ! And now compute the projection
        Aux(1:Nvib,1:NvibP) = matrix_product(Nvib,NvibP,Nvib,Aux,LL_all)

        print*, ""
        print*, "Projection matrix written to 'Prj1_modes.dat':"
        print'(X,A,I0,X,I0,/)', " Prj = (LL_current)^-1 * (LL_all). Size: ", Nvib0, NvibP
        open(O_PRJ,file="Prj1_modes.dat")
        do i=1,Nvib0
        do j=1,NvibP
            write(O_PRJ,*) Aux(i,j)
        enddo
        enddo
        close(O_PRJ)

        !Make the assignememts
        print'(/,X,A)', "--------------------------------------------------------"
        print'(X,A)',   " Assignments of reduced set based on Prj"
        print'(X,A)',   "--------------------------------------------------------"
        print'(X,A)',   " Reduced/Freq     Complete/Freq      Coef^2     Norm"
        do i=1,Nvib0
            Theta=0.d0
            Theta2=0.d0
            do j=1,NvibP
                if (Theta<=abs(Aux(i,j))) then
                    Theta=abs(Aux(i,j))
                    k=j
                endif 
                Theta2=Theta2+Aux(i,j)**2
            enddo
            print'(I4,2X,F8.2,4X,I4,2X,F8.2,3X,F8.3,3X,F8.3)', &
                          i, Freq(i), k, Freq_all(k), Theta**2, Theta2
        enddo
        print'(X,A,/)',   "--------------------------------------------------------"
        
    endif
    Nvib = Nvib0

    animate=.false.

    ! Check if we should continue
    if (molecule%geom%nimprop/=0) then
        if (Nsel/=0) call alert_msg("warning","Animations not yet possible "//&
                                              "when impropers are selected")
        Nsel=0
    endif
    if (def_internal=="SEL") then
        if (Nsel/=0) call alert_msg("warning","Animations may missbehave "//&
                                              "with -intmode sel")
    endif
    if (.not.animate) then
        Nsel=0
    endif

    ! If redundant set, transform from orthogonal non-redundant
    if (scan_type/="IN") then
        print'(/,X,A,/)', "Transform from non-redundant orthogonal to original redundant set"
        LL(1:Ns,1:Nvib) = matrix_product(Ns,Nvib,Nvib,Asel,LL)
    endif

    if (Tthermo /= 0.d0) then
        call set_geom_units(molecule,"Angs")
        ! Do thermochemical analysis
        call thermo(Nat,Nvib,molecule%atom(:)%X,molecule%atom(:)%Y,molecule%atom(:)%Z,molecule%atom(:)%Mass,Freq,Tthermo)
    endif

    ! Check algorithm
    if (conversion_i2c/="ZMAT" .and. conversion_i2c/="ITER") then
        call alert_msg("fatal","Unkown algorithm to tranform internal to Cartesian displacement: "//conversion_i2c)
    endif

    !==========================================================0
    !  Normal mode displacements
    !==========================================================0
    if (Nsel > 0) then
        call heading(6,"Computing Animations")
        ! Tune Ns to activate switches
        if (rmzfile/="none") Ns=0
        ! Take number of ICs as Shortcuts
        nbonds = molecule%geom%nbonds
        nangles= molecule%geom%nangles
        ndihed = molecule%geom%ndihed
        ! Initialization
        Sref = S
        DeltaS = S
        ! To ensure that we always have the same orientation, we stablish the reference here
        ! this can be used to use the input structure as reference (this might need also a 
        ! traslation if not at COM -> not necesary, the L matrices are not dependent on the 
        ! COM position, only on the orientation)
        if (conversion_i2c=="ZMAT") then
            if (Ns_zmat /= 0) then
                ! From now on, we use the zmatgeom 
                molecule%geom = zmatgeom
                S(1:Ns_zmat) = map_Zmatrix(Ns_zmat,S,Zmap,Szmat)
            endif
            call zmat2cart(molecule,S)
        endif
        ! Save state as reference frame for RMSD fit (in AA)
        molec_aux=molecule
        ! Default steps (to be set by the user..)
        Nsteps = 101
        if ( mod(Nsteps,2) == 0 ) Nsteps = Nsteps + 1 ! ensure odd number of steps (so we have same left and right)
        ! Qstep is dimless
        Qstep = Amplitude/float(Nsteps-1)*2.d0  ! Do the range (-A ... +A)
        molecule%atom(1:molecule%natoms)%resname = "RES" ! For printing
    endif
    
    !---------------------------------------------
    ! Run over all selected modes/internals
    !---------------------------------------------
    do jj=1,Nsel 
        k=0 ! equilibrium corresponds to k=0
        j = nm(jj)
        if (scan_type == "NM") then
            if (verbose>0) &
             print'(X,A,I0,A)', "Generating Mode ", j, "..."
        else 
            if (def_internal == "SEL") then
                CombDef=""
                do i=1,Ns
                    if (LL(i,j) == 0.d0) cycle
                    write(CombDef,'(A,X,F4.1,A)') " "//trim(CombDef),LL(i,j),"*"//trim(ModeDef(i))//" +"
                enddo
                i=len_trim(CombDef)
                CombDef(i:i) = ""
            else
                CombDef = trim(ModeDef(j))
            endif
            if (verbose>0) &
             print'(X,A,I0,A)', "Generating Scan for IC ", j, ": "//trim(adjustl(CombDef))//"..."
        endif

!         ! Set initial values for the scanned coordinate
!         if (scan_type =="IN") then
!             qcoord = Sref(j)
!         else
!             qcoord = 0.d0
!         endif 

        ! Prepare and open files
        call prepare_files(j,ModeDef(j),scan_type,&
                           grofile,g09file,g96file,numfile,qfile,title)
        open(O_GRO,file=grofile)
        open(O_G09,file=g09file)
        open(O_G96,file=g96file)
        open(O_Q  ,file=qfile)
        open(O_NUM,file=numfile)

        !===========================
        !Start from equilibrium. 
        !===========================
        if (verbose>1) &
         print'(/,A,I0)', "STEP:", k
        ! Update
        write(molecule%title,'(A,I0,A,2(X,F12.6))') &
         trim(adjustl((title)))//" Step ",k," Disp = ", qcoord, qcoord*Factor(j)
!         call zmat2cart(molecule,S)
        !call rmsd_fit_frame(state,ref): efficient but not always works. If so, it uses rmsd_fit_frame_brute(state,ref)
        call rmsd_fit_frame(molecule,molec_aux,info)
        if (info /= 0) then
            print'(X,A,I0)', "RMSD fit failed at Step: ", k
            call rmsd_fit_frame_brute(molecule,molec_aux,dist)
        endif
        !Transform to AA and export coords and put back into BOHR
        call set_geom_units(molecule,"Angs")
        call write_gro(O_GRO,molecule)
        ! Save state as reference frame for RMSD fit (in AA)
        molec_aux=molecule
        !===========================
        !Half Forward oscillation: from step "Eq + dQ" to "Eq + (N-1)/2 dQ"
        !===========================
        !Initialize distacen criterion for rmsd_fit_frame_brute SR
        dist=0.d0
        do istep = 1,(nsteps-1)/2
            k=k+1
            if (verbose>1) &
             print'(/,A,I0)', "STEP:", k
            ! Update values
            ! qcoord has AU
            qcoord = qcoord + Qstep/Factor(j)
            write(molecule%title,'(A,I0,A,2(X,F12.6))') &
             trim(adjustl((title)))//" Step ",k," Disp = ", qcoord, qcoord*Factor(j)
            ! Displace (displace always from reference to avoid error propagation)
            i=istep
            S=Sref
            call displace_Scoord(LL(:,j),nbonds,nangles,ndihed,Qstep/Factor(j)*i,S)
            ! Get Cart coordinates
            if (conversion_i2c=="ZMAT") then
                if (Ns /= Ns_zmat) then
                    S(1:Ns_zmat) = map_Zmatrix(Ns_zmat,S,Zmap,Szmat)
                endif
                call zmat2cart(molecule,S)
                !call rmsd_fit_frame(state,ref): efficient but not always works. If so, it uses rmsd_fit_frame_brute(state,ref)
                call rmsd_fit_frame(molecule,molec_aux,info)
                if (info /= 0) then
                    print'(X,A,I0)', "RMSD fit failed at Step: ", k
                    call rmsd_fit_frame_brute(molecule,molec_aux,dist)
                endif
            else 
                l=0
                do i=1,nbonds
                    l=l+1
                    DeltaS(l) = S(l) - DeltaS(l)
                enddo
                do i=1,nangles
                    l=l+1
                    DeltaS(l) = S(l)-DeltaS(l)
                    if (abs(DeltaS(l)) > abs(DeltaS(l)-2*PI) ) then
                        DeltaS(l) = DeltaS(l)-2*PI
                    else if (abs(DeltaS(l)) > abs(DeltaS(l)+2*PI) ) then
                        DeltaS(l) = DeltaS(l)+2*PI
                    endif
                enddo
                do i=1,ndihed
                    l=l+1
                    DeltaS(l) = S(l)-DeltaS(l)
                    if (abs(DeltaS(l)) > abs(DeltaS(l)-2*PI) ) then
                        DeltaS(l) = DeltaS(l)-2*PI
                    else if (abs(DeltaS(l)) > abs(DeltaS(l)+2*PI) ) then
                        DeltaS(l) = DeltaS(l)+2*PI
                    endif
                enddo
                call verbose_mute()
                call intshif2cart(molecule,DeltaS,thr_set=1d-4,maxiter_set=10)
                ! Compute current ICs for the next step 
                call compute_internal(molecule,Ns,DeltaS)
                call verbose_continue()
            endif

            ! PRINT
            !Transform to AA and comparae with last step (stored in state)  -- this should be detected and fix by the subroutines
            call set_geom_units(molecule,"Angs")
            ! Write GRO from the beginign and G96/G09 only when reach max amplitude
            call write_gro(O_GRO,molecule)
            if (k==(nsteps-1)/2) then
                call write_gcom(O_G09,molecule,g09file,calc,method,basis,molecule%title)
                call write_g96(O_G96,molecule)
                write(O_Q,*) qcoord, qcoord*Factor(j)
            endif
            ! Save state as reference frame for RMSD fit (in AA)
            molec_aux=molecule
        enddo
        !=======================================
        ! Reached amplitude. Back oscillation: from step "MaxAmp + dQ" to "MaxAmp + (N-2) dQ" == -MaxAmp
        !=======================================
        ! This is the part reported in G09/G96 files
        do istep = 1,nsteps-1
            k=k+1
            if (verbose>1) &
             print'(/,A,I0)', "STEP:", k
            ! Update values
            qcoord = qcoord - Qstep/Factor(j)
            write(molecule%title,'(A,I0,A,2(X,F12.6))') &
             trim(adjustl((title)))//" Step ",k," Disp = ", qcoord, qcoord*Factor(j)
            ! Displace (displace always from reference to avoid error propagation)
            i=(nsteps-1)/2-istep
            S=Sref
            call displace_Scoord(LL(:,j),nbonds,nangles,ndihed,Qstep/Factor(j)*i,S)
            if (conversion_i2c=="ZMAT") then
                ! Get Cart coordinates
                if (Ns /= Ns_zmat) then
                    S(1:Ns_zmat) = map_Zmatrix(Ns_zmat,S,Zmap,Szmat)
                endif
                call zmat2cart(molecule,S)
                !Transform to AA and comparae with last step (stored in state) -- comparison in AA
                call set_geom_units(molecule,"Angs")
                !call rmsd_fit_frame(state,ref): efficient but not always works. If so, it uses rmsd_fit_frame_brute(state,ref)
                call rmsd_fit_frame(molecule,molec_aux,info)
                if (info /= 0) then
                    print'(X,A,I0)', "RMSD fit failed at Step: ", k
                    call rmsd_fit_frame_brute(molecule,molec_aux,dist)
                endif
            else 
                l=0
                do i=1,nbonds
                    l=l+1
                    DeltaS(l) = S(l) - DeltaS(l)
                enddo
                do i=1,nangles
                    l=l+1
                    DeltaS(l) = S(l)-DeltaS(l)
                    if (abs(DeltaS(l)) > abs(DeltaS(l)-2*PI) ) then
                        DeltaS(l) = DeltaS(l)-2*PI
                    else if (abs(DeltaS(l)) > abs(DeltaS(l)+2*PI) ) then
                        DeltaS(l) = DeltaS(l)+2*PI
                    endif
                enddo
                do i=1,ndihed
                    l=l+1
                    DeltaS(l) = S(l)-DeltaS(l)
                    if (abs(DeltaS(l)) > abs(DeltaS(l)-2*PI) ) then
                        DeltaS(l) = DeltaS(l)-2*PI
                    else if (abs(DeltaS(l)) > abs(DeltaS(l)+2*PI) ) then
                        DeltaS(l) = DeltaS(l)+2*PI
                    endif
                enddo
                call verbose_mute()
                call intshif2cart(molecule,DeltaS,thr_set=1d-4,maxiter_set=10)
                ! Compute current ICs for the next step 
                call compute_internal(molecule,Ns,DeltaS)
                call verbose_continue()
            endif

            ! PRINT
            call set_geom_units(molecule,"Angs")
            ! Write G96/GRO every step and G09 scan every 10 steps
            ! except the 5 poinst around minimum, which are all printed
            call write_gro(O_GRO,molecule)
            call write_g96(O_G96,molecule)
            if (mod(k,10) == 0) then
                call write_gcom(O_G09,molecule,g09file,calc,method,basis,molecule%title)
                write(O_Q,*) qcoord, qcoord*Factor(j)
            endif
            ! Write 5 poinst around minimum for numerical dierivatives
            if (k>=nsteps-3.and.k<=nsteps+1) then
                call write_gcom(O_NUM,molecule,numfile,calc,method,basis,molecule%title)
            endif
            ! Save state as reference frame for RMSD fit (in AA)
            molec_aux=molecule
        enddo
        !=======================================
        ! Reached amplitude. Half Forward oscillation (till one step before equilibrium, so that we concatenate well)
        !=======================================
        do istep = 1,(nsteps-1)/2-1
            k=k+1
            if (verbose>1) &
             print'(/,A,I0)', "STEP:", k
            ! Update values
            qcoord = qcoord + Qstep/Factor(j)
            write(molecule%title,'(A,I0,A,2(X,F12.6))') &
             trim(adjustl((title)))//" Step ",k," Disp = ", qcoord, qcoord*Factor(j)
            ! Displace (displace always from reference to avoid error propagation)
            i=-(nsteps-1)/2+istep
            S=Sref
            call displace_Scoord(LL(:,j),nbonds,nangles,ndihed,Qstep/Factor(j)*i,S)
            if (conversion_i2c=="ZMAT") then
                ! Get Cart coordinates
                if (Ns /= Ns_zmat) then
                    S(1:Ns_zmat) = map_Zmatrix(Ns_zmat,S,Zmap,Szmat)
                endif
                call zmat2cart(molecule,S)
                !call rmsd_fit_frame(state,ref): efficient but not always works. If so, it uses rmsd_fit_frame_brute(state,ref)
                call rmsd_fit_frame(molecule,molec_aux,info)
                if (info /= 0) then
                    print'(X,A,I0)', "RMSD fit failed at Step: ", k
                    call rmsd_fit_frame_brute(molecule,molec_aux,dist)
                endif
            else 
                l=0
                do i=1,nbonds
                    l=l+1
                    DeltaS(l) = S(l) - DeltaS(l)
                enddo
                do i=1,nangles
                    l=l+1
                    DeltaS(l) = S(l)-DeltaS(l)
                    if (abs(DeltaS(l)) > abs(DeltaS(l)-2*PI) ) then
                        DeltaS(l) = DeltaS(l)-2*PI
                    else if (abs(DeltaS(l)) > abs(DeltaS(l)+2*PI) ) then
                        DeltaS(l) = DeltaS(l)+2*PI
                    endif
                enddo
                do i=1,ndihed
                    l=l+1
                    DeltaS(l) = S(l)-DeltaS(l)
                    if (abs(DeltaS(l)) > abs(DeltaS(l)-2*PI) ) then
                        DeltaS(l) = DeltaS(l)-2*PI
                    else if (abs(DeltaS(l)) > abs(DeltaS(l)+2*PI) ) then
                        DeltaS(l) = DeltaS(l)+2*PI
                    endif
                enddo
                call verbose_mute()
                call intshif2cart(molecule,DeltaS,thr_set=1d-4,maxiter_set=10)
                ! Compute current ICs for the next step 
                call compute_internal(molecule,Ns,DeltaS)
                call verbose_continue()
            endif
            ! PRINT
            !Transform to AA and comparae with last step (stored in state)  -- this should be detected and fix by the subroutines
            call set_geom_units(molecule,"Angs")
            ! Write only GRO 
            call write_gro(O_GRO,molecule)
            ! Save state as reference frame for RMSD fit (in AA)
            molec_aux=molecule
        enddo
        open(O_GRO)
        open(O_G09)
        open(O_G96)
        open(O_Q  )
        open(O_NUM)
    enddo

    call summary_alerts

    call cpu_time(tf)
    write(6,'(/,A,X,F12.3,/)') "CPU time (s)", tf-ti

    ! CALL EXTERNAL PROGRAM TO RUN ANIMATIONS

    if (call_vmd) then
        open(S_VMD,file="vmd_conf.dat",status="replace")
        !Set general display settings (mimic gv)
        write(S_VMD,*) "color Display Background iceblue"
        write(S_VMD,*) "color Name {C} silver"
        write(S_VMD,*) "axes location off"
        !Set molecule representation
        do i=0,Nsel-1
            j = nm(i+1)
            write(S_VMD,*) "mol representation CPK"
!            write(S_VMD,*) "mol addrep 0"
            if (i==0) then
                write(S_VMD,*) "molinfo ", i, " set drawn 1"
            else
                write(S_VMD,*) "molinfo ", i, " set drawn 0"
            endif
            write(S_VMD,*) "mol addrep ", i
            write(dummy_char,'(A,I4,X,F8.2,A)') "{Mode",j, Freq(j),"cm-1}"
            dummy_char=trim(adjustl(dummy_char))
            write(S_VMD,*) "mol rename ", i, trim(dummy_char)
        enddo
        write(S_VMD,*) "display projection Orthographic"
        close(S_VMD)
        !Call vmd
        vmdcall = 'vmd -m '
        do i=1,Nsel
            j = nm(i)
            ! Get filenames (we want grofile name)
            call prepare_files(j,ModeDef(j),scan_type,&
                              grofile,g09file,g96file,numfile,qfile,title)
            vmdcall = trim(adjustl(vmdcall))//" "//trim(adjustl(grofile))
        enddo
        vmdcall = trim(adjustl(vmdcall))//" -e vmd_conf.dat"
        open(O_MOV,file="vmd_call.cmd")
        write(O_MOV,*) trim(adjustl(vmdcall))
        close(O_MOV)
        call system(vmdcall)
    endif

    if (movie_cycles > 0) then
        open(S_VMD,file="vmd_movie.dat",status="replace")
        !Set general display settings (mimic gv)
        write(S_VMD,*) "color Display Background white"
        write(S_VMD,*) "color Name {C} silver"
        write(S_VMD,*) "axes location off"
        write(S_VMD,*) "display projection Orthographic"
        !Set molecule representation
        do i=0,Nsel-1
            j = nm(i+1)
            ! Get filenames (we want grofile name)
            call prepare_files(j,ModeDef(j),scan_type,&
                              grofile,g09file,g96file,numfile,qfile,title)
            write(S_VMD,*) "mol representation CPK"
            write(S_VMD,*) "molinfo ", i, " set drawn 0"
            write(S_VMD,*) "mol addrep ", i
            write(dummy_char,'(A,I4,X,F8.2,A)') "{Mode",j, Freq(j),"cm-1}"
            dummy_char=trim(adjustl(dummy_char))
            write(S_VMD,*) "mol rename ", i, trim(dummy_char)
            vmdcall = trim(adjustl(vmdcall))//" "//trim(adjustl(grofile))
        enddo
        write(S_VMD,'(A)') "#====================="
        write(S_VMD,'(A)') "# Start movies"
        write(S_VMD,'(A)') "#====================="
        !Set length of the movie
        movie_steps = movie_cycles*20
        do i=0,Nsel-1
            j = nm(i+1)
            write(S_VMD,'(A,I4)') "# Mode", j
            write(tmpfile,*) j
            tmpfile="Mode"//trim(adjustl(tmpfile))
            write(S_VMD,*) "molinfo ", i, " set drawn 1"
            write(S_VMD,*) "set figfile "//trim(adjustl(tmpfile))
            write(S_VMD,'(A,I3,A)') "for {set xx 0} {$xx <=", movie_steps,&
                                    "} {incr xx} {"
            write(S_VMD,*) "set x [expr {($xx-($xx/20)*20)*10}]"
            write(S_VMD,*) 'echo "step $x"'
            write(S_VMD,*) "animate goto $x"
            write(S_VMD,*) "render Tachyon $figfile-$xx.dat"
            write(S_VMD,'(A)') '"/usr/local/lib/vmd/tachyon_LINUX" -aasamples 12 '//& 
                           '$figfile-$xx.dat -format TARGA -o $figfile-$xx.tga'
            write(S_VMD,'(A)') 'convert -font URW-Palladio-Roman -pointsize 30 -draw '//&
                           '"text 30,70 '//"'"//trim(adjustl(tmpfile))//"'"//&
                           '" $figfile-$xx.tga $figfile-$xx.jpg'
            write(S_VMD,'(A)') "}"
            !Updated ffmpeg call. The output is now loadable from ipynb
            write(S_VMD,'(A)') 'ffmpeg -i $figfile-%d.jpg -vcodec libx264 -s 640x360 $figfile.mp4'
            write(S_VMD,*) "molinfo ", i, " set drawn 0"
        enddo
        write(S_VMD,*) "exit"
        close(S_VMD)
        !Call vmd
        vmdcall = 'vmd -m '
        do i=1,Nsel
        vmdcall = trim(adjustl(vmdcall))//" "//trim(adjustl(grofile))
        enddo
        vmdcall = trim(adjustl(vmdcall))//" -e vmd_movie.dat -size 500 500"
        open(O_MOV,file="movie.cmd",status="replace")
        write(O_MOV,'(A)') trim(adjustl(vmdcall))
        write(O_MOV,'(A)') "rm Mode*jpg Mode*dat Mode*tga"
        close(O_MOV)
        print*, ""
        print*, "============================================================"
        print*, "TO GENERATE THE MOVIES (AVI) EXECUTE COMMANDS IN 'movie.cmd'"
        print*, "(you may want to edit 'vmd_movie.dat'  first)"
        print*, "============================================================"
        print*, ""
    endif

    stop


    !==============================================
    contains
    !=============================================

    subroutine parse_input(&
                           ! input data
                           inpfile,ft,hessfile,fth,gradfile,ftg,nmfile,ftn,mass_file,&
                           ! Options (general)
                           Amplitude,call_vmd,include_hbonds,selection,vertical, &
                           ! Movie
                           animate,movie_vmd, movie_cycles,conversion_i2c,        &
                           ! Options (internal)
                           use_symmetry,def_internal,def_internal0,intfile,intfile0,&
                           apply_projection_matrix,complementay_projection,  &
                           rmzfile,scan_type,  &
                           project_on_all, rm_gradcoord,complementay_gradient,   &
                           ! connectivity file
                           cnx_file,                                             &
                           ! thermochemical analysis
                           Tthermo,                                              &
                           ! (hidden)
                           analytic_Bder)
    !==================================================
    ! My input parser (gromacs style)
    !==================================================
        implicit none

        character(len=*),intent(inout) :: inpfile,ft,hessfile,fth,gradfile,ftg,nmfile,ftn, &
                                          intfile,intfile0,rmzfile,scan_type,def_internal, &
                                          selection,cnx_file,def_internal0,conversion_i2c,mass_file
        real(8),intent(inout)          :: Amplitude,Tthermo
        logical,intent(inout)          :: call_vmd, include_hbonds,vertical, use_symmetry,movie_vmd,animate,&
                                          analytic_Bder,project_on_all,apply_projection_matrix,complementay_projection,&
                                          rm_gradcoord,complementay_gradient
        integer,intent(inout)          :: movie_cycles

        ! Local
        logical :: argument_retrieved,  &
                   need_help = .false.
        integer:: i
        character(len=200) :: arg
        character(len=200) :: int_selection, nm_selection
        ! iargc type must be specified with implicit none (strict compilation)
        integer :: iargc

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

                case ("-fnm") 
                    call getarg(i+1, nmfile)
                    argument_retrieved=.true.
                case ("-ftn") 
                    call getarg(i+1, ftn)
                    argument_retrieved=.true.

                case ("-fmass") 
                    call getarg(i+1, mass_file)
                    argument_retrieved=.true.

                case ("-cnx") 
                    call getarg(i+1, cnx_file)
                    argument_retrieved=.true.

                case ("-rmgrad")
                    rm_gradcoord=.true.
                case ("-normgrad")
                    rm_gradcoord=.false.
                case ("-rmgrad-c")
                    complementay_gradient=.true.
                    rm_gradcoord=.true.
                case ("-normgrad-c")
                    complementay_gradient=.false.

                case ("-intfile") 
                    call getarg(i+1, intfile)
                    argument_retrieved=.true.

                case ("-intfile2") 
                    call getarg(i+1, intfile0)
                    argument_retrieved=.true.

                case ("-rmzfile") 
                    call getarg(i+1, rmzfile)
                    argument_retrieved=.true.

                case ("-intmode")
                    call getarg(i+1, def_internal)
                    argument_retrieved=.true.

                case ("-alg")
                    call getarg(i+1, conversion_i2c)
                    argument_retrieved=.true.

                case ("-intmode0")
                    call getarg(i+1, def_internal0)
                    argument_retrieved=.true.

                case ("-prjS")
                    apply_projection_matrix=.true.
                    complementay_projection=.false.
                case ("-noprjS")
                    apply_projection_matrix=.false.

                case ("-prjS-c")
                    apply_projection_matrix=.true.
                    complementay_projection=.true.
                case ("-noprjS-c")
                    apply_projection_matrix=.false.

                case ("-sym")
                    use_symmetry=.true.
                case ("-nosym")
                    use_symmetry=.false.

                case ("-vert")
                    vertical=.true.
                case ("-novert")
                    vertical=.false.

                case ("-nm") 
                    scan_type="NM"
                    call getarg(i+1, selection)
                    argument_retrieved=.true.

                case ("-int")
                    scan_type="IN"
                    call getarg(i+1, selection)
                    argument_retrieved=.true.

                case ("-disp") 
                    call getarg(i+1, arg)
                    read(arg,*) Amplitude
                    argument_retrieved=.true.

                case ("-vmd")
                    call_vmd=.true.
                case ("-novmd")
                    call_vmd=.false.

                case ("-animate")
                    animate=.true.
                case ("-noanimate")
                    animate=.false.

                case ("-prjall")
                    project_on_all=.true.
                case ("-noprjall")
                    project_on_all=.false.


                case ("-movie")
                    call getarg(i+1, arg)
                    read(arg,*) movie_cycles
                    movie_vmd=.true.
                    argument_retrieved=.true.

                case ("-include_hb")
                    include_hbonds=.true.

                case ("-thermo")
                    call getarg(i+1, arg)
                    argument_retrieved=.true.
                    read(arg,*) Tthermo
        
                case ("-h")
                    need_help=.true.

                ! HIDDEN FLAGS

                case ("-anaBder")
                    analytic_Bder=.true.
                case ("-noanaBder")
                    analytic_Bder=.false.

                ! Control verbosity
                case ("-quiet")
                    verbose=0
                    silent_notes = .true.
                case ("-concise")
                    verbose=1
                case ("-v")
                    verbose=2
                case ("-vv")
                    verbose=3
                    silent_notes=.false.

                case default
                    call alert_msg("fatal","Unkown command line argument: "//adjustl(arg))
            end select
        enddo 

       ! Manage defaults
       ! If not declared, hessfile and gradfile are the same as inpfile
       ! unless we are using nm file
       if (adjustl(nmfile) == "none") then
           if (adjustl(hessfile) == "same") then
               hessfile=inpfile
               if (adjustl(fth) == "guess")  fth=ft
           endif
           if (adjustl(gradfile) == "same") then
               gradfile=inpfile
               if (adjustl(ftg) == "guess")  ftg=ft
           endif
           ftn="-"
       else
           if (adjustl(hessfile) /= "same") &
            call alert_msg("note","Using nm file, disabling Hessian file")
           hessfile="none"
           fth="-"
           if (adjustl(gradfile) /= "same") &
            call alert_msg("note","Using nm file, disabling gradient file")
           gradfile="none"
           ftg="-"
       endif

       ! Select internal or normal modes
       if (scan_type == "NM") then
           int_selection="-"
           nm_selection =selection
       elseif (scan_type == "IN") then
           nm_selection ="-"
           int_selection=selection
       endif

       ! Take defaults for the internal set for correction only
       if (def_internal0 == "defa") def_internal0=def_internal
       if (adjustl(intfile0)=="default") intfile0=intfile


       !Print options (to stderr)
        write(6,'(/,A)') '========================================================'
        write(6,'(/,A)') '             N M    I N T E R N A L '    
        write(6,'(/,A)') '      Perform vibrational analysis based on  '
        write(6,'(A)')   '             internal coordinates '        
        call print_version()
        write(6,'(/,A)') '========================================================'
        write(6,'(/,A)') '-------------------------------------------------------------------'
        write(6,'(A)')   ' Flag           Description                     Value'
        write(6,'(A)')   '-------------------------------------------------------------------'
        write(6,*)       '-f             Input file (structure&default)  ', trim(adjustl(inpfile))
        write(6,*)       '-ft            \_ FileType                     ', trim(adjustl(ft))
        write(6,*)       '-fhess         Hessian file                    ', trim(adjustl(hessfile))
        write(6,*)       '-fth           \_ FileType                     ', trim(adjustl(fth))
        write(6,*)       '-fgrad         Hessian file                    ', trim(adjustl(gradfile))
        write(6,*)       '-ftg           \_ FileType                     ', trim(adjustl(ftg))
        write(6,*)       '-cnx           Connectivity [filename|guess]   ', trim(adjustl(cnx_file))
        write(6,*)       '-fmass         Mass file (optional)            ', trim(adjustl(mass_file)) 
!         write(6,*)       '-fnm           Gradient file                   ', trim(adjustl(nmfile))
!         write(6,*)       '-ftn           \_ FileType                     ', trim(adjustl(ftn))
        write(6,*)       '-[no]prjS      Apply projection matrix to     ', apply_projection_matrix
        write(6,*)       '               rotate Grad and Hess.'
        write(6,*)       '               Projection P=B^+B, where the'
        write(6,*)       '-[no]prjS-c    Use the complentary projection ', complementay_projection
        write(6,*)       '               P=I - B^+B'
        write(6,*)       '-[no]rmgrad    Remove coordinate along the    ', rm_gradcoord
        write(6,*)       '               grandient                      '
        write(6,*)       '-[no]rmgrad-c  Use complementary projection   ', rm_gradcoord
        write(6,*)       '               (i.e., use project on grad)    '
        write(6,*)       '-intmode0      Internal set:[zmat|sel|all]    ', trim(adjustl(def_internal0))
        write(6,*)       '               to compute additional terms    '
        write(6,*)       '               (vertical method)              '
        write(6,*)       '-intmode       Internal set:[zmat|sel|all]     ', trim(adjustl(def_internal))
        write(6,*)       '-intfile       File with ICs (for "sel")       ', trim(adjustl(intfile))
        write(6,*)       '-intfile2      File with ICs (for "sel")       ', trim(adjustl(intfile0))
        write(6,*)       '               second file for double projeciton'
        write(6,*)       '               (only meaningful with -prjS[-c])'
        write(6,*)       '-rmzfile       File deleting ICs from Zmat     ', trim(adjustl(rmzfile))
        write(6,*)       '-[no]sym       Use symmetry to form Zmat      ',  use_symmetry
        write(6,*)       '-[no]vert      Correct with B derivatives for ',  vertical
        write(6,*)       '               non-stationary points'
        write(6,*)       '-[no]prjall    Project modes with current     ', project_on_all
        write(6,*)       '               internal set on those computed '
        write(6,*)       '               with the "-intmode all" set    '
        write(6,*)       ''
        write(6,*)       ' ** Options for themochemistry **'
        write(6,*)       '-thermo        Temp (K) for thermochemistry   ', Tthermo 
        write(6,*)       ''
        write(6,*)       ' ** Options for animation **'
        write(6,*)       '-[no]animate   Generate animation files       ',  animate
        write(6,*)       '-nm            Selection of normal modes to    ', trim(adjustl(nm_selection))
        write(6,*)       '               generate animations             '
        write(6,*)       '-int           Selection of internal coords    ', trim(adjustl(int_selection))
        write(6,*)       '               to generate animations          '
        write(6,'(X,A,F5.2)') &
                         '-disp          Mode displacements for animate ',  Amplitude
        write(6,*)       '               (dimensionless displacements)'  
        write(6,*)       '-alg           Algorith to convert from Cart. ',  conversion_i2c
        write(6,*)       '               to internal [zmat|iter]'
        write(6,*)       '-[no]vmd       Launch VMD after computing the ',  call_vmd
        write(6,*)       '               modes (needs VMD installed)'
        write(6,'(X,A,I0)') &
                         '-movie         Number of cycles to record on   ',  movie_cycles
        write(6,*)       '               a movie with the animation'
        write(6,*)       ''
        write(6,*)       '-h             Display this help              ',  need_help
        write(6,'(A)') '-------------------------------------------------------------------'
        write(6,'(X,A,I0)') &
                       'Verbose level:  ', verbose        
        write(6,'(A)') '-------------------------------------------------------------------'
        if (need_help) call alert_msg("fatal", 'There is no manual (for the moment)' )

        return
    end subroutine parse_input

    subroutine prepare_files(icoord,label,scan_type,grofile,g09file,g96file,numfile,qfile,title)

        integer,intent(in) :: icoord
        character(len=*),intent(in) :: label, scan_type
        character(len=*),intent(out) :: grofile,g09file,g96file,numfile,qfile,title

        !Local
        character(len=150) :: dummy_char

        if (scan_type=="IN") then
            write(dummy_char,"(I0,X,A)") icoord
            title   = "Animation of IC "//trim(adjustl(dummy_char))//"("//trim(adjustl(label))//")"
            g09file = "Coord"//trim(adjustl(dummy_char))//"_int.com"
            g96file = "Coord"//trim(adjustl(dummy_char))//"_int.g96"
            qfile   = "Coord"//trim(adjustl(dummy_char))//"_int_steps.dat"
            grofile = "Coord"//trim(adjustl(dummy_char))//"_int.gro" 
            numfile = "Coord"//trim(adjustl(dummy_char))//"_int_num.com"
        else
            write(dummy_char,"(I0,X,A)") icoord
            title   = "Animation of normal mode "//trim(adjustl(dummy_char))
            g09file = "Mode"//trim(adjustl(dummy_char))//"_int.com"
            g96file = "Mode"//trim(adjustl(dummy_char))//"_int.g96"
            qfile   = "Mode"//trim(adjustl(dummy_char))//"_int_steps.dat"
            grofile = "Mode"//trim(adjustl(dummy_char))//"_int.gro"
            numfile = "Mode"//trim(adjustl(dummy_char))//"_int_num.com"
        endif

        return

    end subroutine prepare_files

    subroutine displace_Scoord(Lc,nbonds,nangles,ndihed,Qstep,S)

        real(8),dimension(:),intent(in)   :: Lc
        real(8),intent(in)                :: Qstep 
        integer,intent(in)                :: nbonds,nangles,ndihed
        real(8),dimension(:),intent(inout):: S

        !Local
        integer :: i, k

        k=0
        ! "Bonds"
        do i=1,nbonds
            k=k+1
            S(k) = S(k) + Lc(k) * Qstep
        enddo
        ! "Angles"
        do i=1,nangles
            k=k+1
            S(k) = S(k) + Lc(k) * Qstep
        enddo
        ! "Dihedrals"
        do i=1,ndihed
            k=k+1
            S(k) = S(k) + Lc(k) * Qstep
            if (S(k) >  PI) S(k)=S(k)-2.d0*PI
            if (S(k) < -PI) S(k)=S(k)+2.d0*PI
        enddo

        return
       
    end subroutine displace_Scoord


end program normal_modes_internal

