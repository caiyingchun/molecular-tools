program calcRMS_bonded


    !==============================================================
    ! This code uses of MOLECULAR_TOOLS (version 1.0/March 2012)
    !==============================================================
    !
    ! Description:
    ! -----------
    ! Program to compute the RMSD for all bonded parameters in a 
    ! strucure file, compared with a reference. Conectivity is guessed
    ! by distances.
    !
    ! Compilation instructions (for mymake script): now using automake (v4)
    !
    ! Change log:
    ! v2: use slightly modified modules. calc_dihed and calc_angle now returns angle in rad, so changes are made accordingly
    ! v4: using v4 modules (disable allocation)
    ! Added RMSD of the whole structure (atomic positions)
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
    use gaussian_manage
    !============================================
    !  Structure-related modules
    !============================================
    use molecular_structure
    use metrics
    use atomic_geom
    use symmetry

    implicit none

    integer,parameter :: NDIM=600

    !====================== 
    !Options 
    logical :: debug=.false., &
               nonH=.false.,  &
               include_hbonds=.false., &
               mwc=.false.
    !======================

    !====================== 
    !System variables
    type(str_resmol) :: molec, ref_molec
    real(8) :: X0mwc, Y0mwc, Z0mwc
    real(8) :: XRmwc, YRmwc, ZRmwc
    !====================== 

    !====================== 
    !Auxiliar variables
    integer :: ierr
    character(1) :: null
    character(len=16) :: dummy_char
    character(len=36) :: label
    logical :: skip_dihed=.false.
    real(8) :: aaa
    !====================== 

    !=============
    !Counters
    integer :: i,j,k
    !=============

    !================
    !I/O stuff 
    !units
    integer :: I_INP=10,  &
               I_REF=11,  &
               O_STR=20  
    !files
    character(len=10) :: ft="guess", ft_ref="guess"
    character(len=200):: inpfile="input.pdb",          &
                         reffile="ref.pdb"
    !status
    integer :: IOstatus
    !===================

    !New things for bonds
    integer,dimension(500,2) :: bond
    integer :: nbonds
    real(8) :: calc, ref, dev, rmsd, dif

    !===========================
    ! Allocate atoms (default)
    call allocate_atoms(molec)
    call allocate_atoms(ref_molec)
    !===========================

    ! 0. GET COMMAND LINE ARGUMENTS
    call parse_input(inpfile,reffile,ft,ft_ref,debug,nonH,include_hbonds,mwc)

    ! 1. READ DATA
    ! ---------------------------------
    ! 1. READ INPUT
    ! ---------------------------------
    ! 1a. Rotable molecule
    open(I_INP,file=inpfile,status='old',iostat=IOstatus)
    if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(inpfile)) )

    if (adjustl(ft) == "guess") call split_line_back(inpfile,".",null,ft)
    call generic_strmol_reader(I_INP,ft,molec)
    close(I_INP)

    ! 1b. Refence molecule
    open(I_INP,file=reffile,status='old',iostat=IOstatus)
    if (IOstatus /= 0) call alert_msg( "fatal","Unable to open "//trim(adjustl(reffile)) )

    if (adjustl(ft_ref) == "guess") call split_line_back(reffile,".",null,ft_ref)
    call generic_strmol_reader(I_INP,ft_ref,ref_molec)
    close(I_INP)


    !Print info for debug

    ! Get connectivity from the residue
    call guess_connect(ref_molec,include_hbonds)
    call gen_bonded(ref_molec)

    dev = 0.0
    k = 0
    if (debug) print*, "LIST OF BONDS"
    if (debug) print*, "Bond   file  ref   file-ref"
    do i=1,ref_molec%geom%nbonds
        if (nonH) then
            if (adjustl(ref_molec%atom(ref_molec%geom%bond(i,1))%name) == "H" .or. &
                adjustl(ref_molec%atom(ref_molec%geom%bond(i,2))%name) == "H") cycle
        endif
        !Using an external counter in case nonH is used
        k=k+1
        ref  = calc_atm_dist(ref_molec%atom(ref_molec%geom%bond(i,1)),ref_molec%atom(ref_molec%geom%bond(i,2))) 
        calc = calc_atm_dist(molec%atom(ref_molec%geom%bond(i,1)),molec%atom(ref_molec%geom%bond(i,2)))
        dif = abs(calc - ref)
        if (debug) &
        print'(A2,A1,I2,A5,A2,A1,I2,A1,X,2(F8.3,X),F11.6)', &
              ref_molec%atom(ref_molec%geom%bond(i,1))%name, "(", ref_molec%geom%bond(i,1), ") -- ",&
              ref_molec%atom(ref_molec%geom%bond(i,2))%name, "(", ref_molec%geom%bond(i,2), ")", calc, ref, calc-ref
        dev = dev + (calc - ref)**2
    enddo
    rmsd = sqrt(dev/k)
    print'(A,/)', '---------------------' 

    print'(X,A,X,F8.3,/)', "RMSD-bonds (AA):", rmsd

    dev = 0.0
    k = 0
    if (debug) print*, "LIST OF ANGLES"
    if (debug) print*, "Angle   file  ref   file-ref"
    do i=1,ref_molec%geom%nangles
        if (nonH) then
            if (adjustl(ref_molec%atom(ref_molec%geom%angle(i,1))%name) == "H" .or. &
                adjustl(ref_molec%atom(ref_molec%geom%angle(i,2))%name) == "H" .or. &
                adjustl(ref_molec%atom(ref_molec%geom%angle(i,3))%name) == "H") cycle
        endif
        !Using an external counter in case nonH is used
        k=k+1
        ref  = calc_atm_angle(ref_molec%atom(ref_molec%geom%angle(i,1)),&
                          ref_molec%atom(ref_molec%geom%angle(i,2)),&
                          ref_molec%atom(ref_molec%geom%angle(i,3)))
        calc = calc_atm_angle(molec%atom(ref_molec%geom%angle(i,1)),&
                          molec%atom(ref_molec%geom%angle(i,2)),&
                          molec%atom(ref_molec%geom%angle(i,3)))
        calc = calc*180.d0/PI
        ref  = ref*180.d0/PI
        dif = abs(calc - ref)
        if (debug) &
        print'(2(A2,A1,I2,A5),A2,A1,I2,A1,X,2(F8.3,X),F11.6)', &
              ref_molec%atom(ref_molec%geom%angle(i,1))%name, "(", ref_molec%geom%angle(i,1), ") -- ",&
              ref_molec%atom(ref_molec%geom%angle(i,2))%name, "(", ref_molec%geom%angle(i,2), ") -- ",&
              ref_molec%atom(ref_molec%geom%angle(i,3))%name, "(", ref_molec%geom%angle(i,3), ")"    ,&
              calc, ref, calc-ref
        dev = dev + (calc - ref)**2
    enddo
    rmsd = sqrt(dev/k)

    print'(X,A,X,F8.3,/)', "RMSD-angles (deg):", rmsd


    dev = 0.0
    k = 0
    if (debug) print*, "LIST OF DIHEDRALS"
    if (debug) print*, "Dihedral   file  ref   abs(file-ref)"
    do i=1,ref_molec%geom%ndihed
        if (nonH) then
            if (adjustl(ref_molec%atom(ref_molec%geom%dihed(i,1))%name) == "H" .or. &
                adjustl(ref_molec%atom(ref_molec%geom%dihed(i,2))%name) == "H" .or. &
                adjustl(ref_molec%atom(ref_molec%geom%dihed(i,3))%name) == "H" .or. &
                adjustl(ref_molec%atom(ref_molec%geom%dihed(i,4))%name) == "H") cycle
        endif
        ! Check colinearity
        skip_dihed = .false.
        aaa = calc_atm_angle(ref_molec%atom(ref_molec%geom%dihed(i,1)),&
                             ref_molec%atom(ref_molec%geom%dihed(i,2)),&
                             ref_molec%atom(ref_molec%geom%dihed(i,3)))
        if (abs(aaa-pi)<0.001d0) skip_dihed = .true.
        aaa = calc_atm_angle(ref_molec%atom(ref_molec%geom%dihed(i,2)),&
                             ref_molec%atom(ref_molec%geom%dihed(i,3)),&
                             ref_molec%atom(ref_molec%geom%dihed(i,4)))
        if (abs(aaa-pi)<0.001d0) skip_dihed = .true.
        aaa = calc_atm_angle(molec%atom(ref_molec%geom%dihed(i,1)),&
                             molec%atom(ref_molec%geom%dihed(i,2)),&
                             molec%atom(ref_molec%geom%dihed(i,3)))
        if (abs(aaa-pi)<0.001d0) skip_dihed = .true.
        aaa = calc_atm_angle(molec%atom(ref_molec%geom%dihed(i,2)),&
                             molec%atom(ref_molec%geom%dihed(i,3)),&
                             molec%atom(ref_molec%geom%dihed(i,4)))
        if (abs(aaa-pi)<0.001d0) skip_dihed = .true.
        
        if (skip_dihed) then
            write(label,'(3(A2,A1,I2,A5),A2,A1,I2,A1)') &
             ref_molec%atom(ref_molec%geom%dihed(i,1))%name, "(", ref_molec%geom%dihed(i,1), ") -- ",&
             ref_molec%atom(ref_molec%geom%dihed(i,2))%name, "(", ref_molec%geom%dihed(i,2), ") -- ",&
             ref_molec%atom(ref_molec%geom%dihed(i,3))%name, "(", ref_molec%geom%dihed(i,3), ") -- ",&
             ref_molec%atom(ref_molec%geom%dihed(i,4))%name, "(", ref_molec%geom%dihed(i,4), ")"
            call alert_msg('note','Collinearity found. Dihedral skipped: '//trim(label))
            cycle
        endif
        
        !Using an external counter in case nonH is used
        k=k+1
        ref  = calc_atm_dihed_new(ref_molec%atom(ref_molec%geom%dihed(i,1)),&
                          ref_molec%atom(ref_molec%geom%dihed(i,2)),&
                          ref_molec%atom(ref_molec%geom%dihed(i,3)),&
                          ref_molec%atom(ref_molec%geom%dihed(i,4)))
        calc = calc_atm_dihed_new(molec%atom(ref_molec%geom%dihed(i,1)),&
                          molec%atom(ref_molec%geom%dihed(i,2)),&
                          molec%atom(ref_molec%geom%dihed(i,3)),&
                          molec%atom(ref_molec%geom%dihed(i,4)))
        calc = calc*180.d0/PI
        ref  = ref*180.d0/PI
        dif = abs(calc - ref)
        dif = min(dif,abs(dif-360.))
        if (debug) &
        print'(3(A2,A1,I2,A5),A2,A1,I2,A1,X,2(F8.3,X),F11.6)', &
              ref_molec%atom(ref_molec%geom%dihed(i,1))%name, "(", ref_molec%geom%dihed(i,1), ") -- ",&
              ref_molec%atom(ref_molec%geom%dihed(i,2))%name, "(", ref_molec%geom%dihed(i,2), ") -- ",&
              ref_molec%atom(ref_molec%geom%dihed(i,3))%name, "(", ref_molec%geom%dihed(i,3), ") -- ",&
              ref_molec%atom(ref_molec%geom%dihed(i,4))%name, "(", ref_molec%geom%dihed(i,4), ")"    ,&
              calc, ref, dif
        dev = dev + (dif)**2
    enddo
    rmsd = sqrt(dev/k)

    print'(X,A,X,F8.3,/)', "RMSD-dihedrals (deg):", rmsd


    dev = 0.0
    k = 0
    if (debug) print*, "LIST OF ATOMIC DISPLACEMENTS"
    do i=1,ref_molec%natoms
        if (nonH) then
            if (adjustl(ref_molec%atom(i)%name) == "H") cycle
        endif
        !Using an external counter in case nonH is used
        k=k+1
        dif = calc_atm_dist(molec%atom(i),ref_molec%atom(i))
        if (debug) &
        print'(A2,A1,I2,A1,X,F11.6)', &
              ref_molec%atom(i)%name, "(", i, ")", dif
        dev = dev + (dif)**2
    enddo
    rmsd = sqrt(dev/k)
    print'(A,/)', '---------------------' 

    print'(X,A,X,F8.3,/)', "RMSD_struct (AA):", rmsd

    if (mwc) then
        dev = 0.0
        k = 0
        if (debug) print*, "LIST OF ATOMIC DISPLACEMENTS (MWC)"
        do i=1,ref_molec%natoms
            if (nonH) then
                if (adjustl(ref_molec%atom(i)%name) == "H") cycle
            endif
            !Using an external counter in case nonH is used
            k=k+1
            ! Transform to mwc
            X0mwc = molec%atom(i)%x*dsqrt(molec%atom(i)%mass) 
            Y0mwc = molec%atom(i)%y*dsqrt(molec%atom(i)%mass) 
            Z0mwc = molec%atom(i)%z*dsqrt(molec%atom(i)%mass) 
            XRmwc = ref_molec%atom(i)%x*dsqrt(molec%atom(i)%mass) 
            YRmwc = ref_molec%atom(i)%y*dsqrt(molec%atom(i)%mass) 
            ZRmwc = ref_molec%atom(i)%z*dsqrt(molec%atom(i)%mass)
            ! And calc with metric tools 
            dif = calc_dist(X0mwc,Y0mwc,Z0mwc,&
                            XRmwc,YRmwc,ZRmwc)
            if (debug) &
            print'(A2,A1,I2,A1,X,F11.6)', &
                  ref_molec%atom(i)%name, "(", i, ")", dif
            dev = dev + (dif)**2
        enddo
        rmsd = sqrt(dev/k)
        print'(A,/)', '---------------------' 
        
        print'(X,A,X,G12.4,/)', "RMSD_struct (AA AMU^1/2):", rmsd
    endif
   

    ! 9999. CHECK ERROR/NOTES
    ! -------------------------------------------------
    if (n_notes > 0) then 
        write(dummy_char,*) n_notes
        write(6,'(/,A,/)') "There were "//trim(adjustl(dummy_char))//" note(s) in this run"
    endif
    if (n_errors > 0) then 
        write(dummy_char,*) n_errors
        write(6,'(/,A,/)') "There were "//trim(adjustl(dummy_char))//" warning(s) in this run"
        call alert_msg("warning", "Files generated, but with too many warnings")
    endif


    stop


    !==============================================
    contains
    !=============================================

    subroutine parse_input(inpfile,reffile,ft,ft_ref,debug,nonH,include_hbonds,mwc)
    !==================================================
    ! My input parser (gromacs style)
    !==================================================
        implicit none

        character(len=*),intent(inout) :: inpfile,ft,ft_ref,reffile
        logical,intent(inout) :: debug, nonH, include_hbonds, mwc
        ! Local
        logical :: argument_retrieved,  &
                   need_help = .false.
        integer:: i
        character(len=200) :: arg
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

                case ("-r") 
                    call getarg(i+1, reffile)
                    argument_retrieved=.true.
                case ("-f2") 
                    call getarg(i+1, reffile)
                    argument_retrieved=.true.
                case ("-ftr") 
                    call getarg(i+1, ft_ref)
                    argument_retrieved=.true.
                case ("-ft2") 
                    call getarg(i+1, ft_ref)
                    argument_retrieved=.true.

                case ("-dbg")
                    debug=.true.

                case ("-nonH")
                    nonH=.true.

                case ("-mwc")
                    mwc=.true.
                case ("-nomwc")
                    mwc=.false.

                case ("-include_hb")
                    include_hbonds=.true.
        
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

        ! Some checks on the input
        !----------------------------

       !Print options (to stderr)
        write(0,'(/,A)') '========================================================'
        write(0,'(/,A)') '            R M S D - C A L C U L A T O R '    
        write(0,'(/,A)') '      Compare two structures using rmsd values'        
        call print_version()
        write(0,'(/,A)') '========================================================'
        write(0,'(/,A)') '-------------------------------------------------------------------'
        write(0,'(A)')   ' Flag         Description                      Value'
        write(0,'(A)')   '-------------------------------------------------------------------'
        write(0,*)       '-f           Input file                       ', trim(adjustl(inpfile))
        write(0,*)       '-ft          \_ FileTyep                      ', trim(adjustl(ft))
        write(0,*)       '-r           Refence file                     ', trim(adjustl(reffile))
        write(0,*)       '             (-f2 is a synonym)               '
        write(0,*)       '-ftr         \_ FileTyep                      ', trim(adjustl(ft_ref))
        write(0,*)       '             (-ft2 is a synonym)               '
        write(0,*)       '-dbg         Debug mode:include all values   ',  debug
        write(0,*)       '-nonH        Ignore Hydrgens                 ',  nonH
        write(0,*)       '-include_hb  Include H-bonds in connectivity ',  include_hbonds
        write(0,*)       '-[no]mwc     Calculate RMSD also in MWC      ',  mwc
        write(0,*)       '-h           This help                       ',  need_help
        write(0,*)       '-------------------------------------------------------------------'
        if (need_help) call alert_msg("fatal", 'There is no manual (for the moment)' )

        return
    end subroutine parse_input


end program calcRMS_bonded

