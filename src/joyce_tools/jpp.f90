program joyce_preprocessor


    !====================================================
    ! Joyce preprocesssor (jpp)
    !
    ! DESCRIPTION
    ! -----------
    ! A program to preprocess the topology(*) and input
    ! files for Joyce, so as to facilitate the changes
    ! (addition/deletion) of terms to the potential
    ! It reads an input topology file with special 
    ! preprocessing marks and produces a new topology 
    ! and (optionally) input files wiht updated indexes 
    !
    ! USAGE
    ! ------
    ! jpp -p topol.top [-i joyce.inp] [-po topol_pp.top] [-io input_pp]
    !
    ! The topology (-p) must be  in the sameformat as 
    ! the one generated by the "generate" keyword.
    ! The supported modifications are:  
    ! * Adding an entry:
    !   Insert it where you prefer and put the keyword 
    !   "add" at the beginig of the line. A description 
    !   of the IC can be given afeter # as usual
    ! * Deleting an entry:
    !   Place the keyword "del" at the beginig of the 
    !   line to delete
    ! * Change the order
    !   Copy the whole Original line(s) from one position
    !   to another
    ! 
    ! Only [ bonds ], [ angles ] and [ dihedrals ] sections
    ! are handled (not [ pairs ], for the moment). In the
    ! input, $dependence, $assing and $keepff sections are
    ! updated (note $keepff may need to need to be readjusted).
    ! If there was a $dependence on a deleted atom, its index
    ! is set to 0 and a warning is risen.
    !======================================================

    !MODULES
    use line_preprocess
    use alerts

    !DECLARATION OF VARIABLES
    implicit none

    !Variables to deal with reading/parsing
    character(len=200) :: line, subline, ff_entry
    character(len=100) :: section, ICdescription, aux_char
    character(len=3)   :: jpp_mark
    character :: cnull
    logical :: track
    !Mapping old-new indexation
    integer,dimension(1:1000) :: ICmap
    !Counters
    integer :: nIC, nIC_old,                     & 
               nAdd_bonds,nAdd_angle,nAdd_dihed, &
               nDel_bonds,nDel_angle,nDel_dihed, &
               nUpd_bonds,nUpd_angle,nUpd_dihed
    integer :: i, j, k, i_old
    !I/O
    character(len=100) :: topfile="topol.top",   &
                          inpfile="input.inp",   &
                          topfile_out="default", &
                          inpfile_out="default"
    integer :: ios
    integer :: I_TOP = 10,&
               I_INP = 11,&
               O_TOP = 20,&
               O_INP = 21
    !--------------------------------------------

    call parse_input(topfile,inpfile,topfile_out,inpfile_out)

    !PROCESS TOPOLOGY
    open(I_TOP,file=topfile,status="old",iostat=ios)
    if (ios /= 0) call alert_msg("fatal","Could not open file:"//trim(adjustl(topfile)))
    open(O_TOP,file=topfile_out)

    !Initialization
    nAdd_bonds = 0
    nAdd_angle = 0
    nAdd_dihed = 0
    nDel_bonds = 0
    nDel_angle = 0
    nDel_dihed = 0
    nUpd_bonds = 0
    nUpd_angle = 0
    nUpd_dihed = 0
    nIC     = 0
    nIC_old = 0
    section = ""
    track   = .false.

    !Read topology file
    do
        read(I_TOP,'(A)',iostat=ios) line
        if (ios /= 0) exit

        !Leave unchanged commented or empty lines
        call split_line(line,";",subline,cnull)
        if (len_trim(subline) ==  0) then
            write(O_TOP,'(A)') trim(line)
            cycle
        endif

        !Get the section
        if (index(line,"[ bonds ]") /= 0) then
            section="bonds"
            track=.true.
            write(O_TOP,'(A)') trim(line)
            cycle
        else if (index(line,"[ angles ]") /= 0) then
            section="angles"
            track=.true.
            write(O_TOP,'(A)') trim(line)
            cycle
        else if (index(line,"[ dihedrals ]") /= 0) then
            section="dihedrals"
            track=.true.
            write(O_TOP,'(A)') trim(line)
            cycle
        else if (index(line,"[ ") /= 0 .and. index(line," ]") /= 0) then
            section="other"
            track=.false.
            write(O_TOP,'(A)') trim(line)
            cycle
        endif

        !Only care about tracked sections
        if (.not.track) then
            write(O_TOP,'(A)') trim(line)
            cycle
        endif

        !Process IC 
        subline=""
        call split_line(line,"#",ff_entry,subline)
        read(line(1:3),'(A)') jpp_mark
        if (jpp_mark == "add") then
            !Increase counters
            nIC = nIC + 1
            if (adjustl(section)=="bonds")     nAdd_bonds=nAdd_bonds+1
            if (adjustl(section)=="angles")    nAdd_angle=nAdd_angle+1
            if (adjustl(section)=="dihedrals") nAdd_dihed=nAdd_dihed+1
            !Drop the mark
            ff_entry = ff_entry(4:)
            !Read description and add '+add' mark (for identification)
            read(subline,'(A)') ICdescription
            ICdescription = trim(ICdescription)//" +add"
        else if (jpp_mark == "del") then
            !Increase counters
            nIC_old = nIC_old + 1
            if (adjustl(section)=="bonds")     nDel_bonds=nDel_bonds+1
            if (adjustl(section)=="angles")    nDel_angle=nDel_angle+1
            if (adjustl(section)=="dihedrals") nDel_dihed=nDel_dihed+1
            !Get mapping
            read(subline,*,iostat=ios) i_old
            if (ios /= 0) call alert_msg("fatal","Error reading topology. Check the format")
            ICmap(i_old) = 0
            cycle
        else
            !Increase counters
            nIC = nIC + 1
            nIC_old = nIC_old + 1
            !Get mapping
            read(subline,*,iostat=ios) i_old
            if (ios /= 0) call alert_msg("fatal","Error reading topology. Check the format")
            ICmap(i_old) = nIC
            !Counters tracking updates
            if (ICmap(i_old) /= i_old) then
                if (adjustl(section)=="bonds")     nUpd_bonds=nUpd_bonds+1
                if (adjustl(section)=="angles")    nUpd_angle=nUpd_angle+1
                if (adjustl(section)=="dihedrals") nUpd_dihed=nUpd_dihed+1
            endif
            !Get the description (removing old counter label)
            write(aux_char,*) i_old
            call split_line(subline,trim(adjustl(aux_char)),subline,ICdescription)

        endif

        !Prepare and write modified entry
        write(subline,*) nIC
        subline = trim(ff_entry)//"  #  "//&
                  trim(adjustl(subline))//" "//trim(adjustl(ICdescription))
        write(O_TOP,'(A)') trim(subline)

    enddo
    close(I_TOP)
    close(O_TOP)

    !SUMMARY
    print*, "==========="
    print*, " JPP INFO:"
    print*, "==========="
    print*, "Original ICs:", nIC_old
    print*, "New ICs     :", nIC
    print*, " Added:"
    print*, "  bonds     :", nAdd_bonds
    print*, "  angles    :", nAdd_angle
    print*, "  dihedrals :", nAdd_dihed
    print*, " Deleted:"
    print*, "  bonds     :", nDel_bonds
    print*, "  angles    :", nDel_angle
    print*, "  dihedrals :", nDel_dihed
    print*, " Updated indexes:"
    print*, "  bonds     :", nUpd_bonds
    print*, "  angles    :", nUpd_angle
    print*, "  dihedrals :", nUpd_dihed
    print*, ""


    !PROCESS INPUT
    ! but if no input file to modify, exit (quietly)
    open(I_INP,file=inpfile,status="old",iostat=ios)
    if (ios /= 0) then
        call alert_msg("note","No input file to modify: "//trim(adjustl(inpfile)))
        stop
    endif
    open(O_INP,file=inpfile_out)

    !Initialization
    nIC     = 0
    section = ""
    track   = .false.

    !Read input file
    do
        read(I_INP,'(A)',iostat=ios) line
        if (ios /= 0) exit

        !Leave unchanged empty lines
        if (len_trim(line) ==  0) then
            write(O_INP,'(A)') trim(line)
            cycle
        endif

        !Get the section
        if (index(line,"$dependence") /= 0) then
            section="dependence"
            track   = .true.
            write(O_INP,'(A)') trim(line)
            cycle
        else if (index(line,"$assign") /= 0) then
            section="assign"
            track   = .true.
            write(O_INP,'(A)') trim(line)
            cycle
        else if (index(line,"$keepff") /= 0) then
            read(line,*) cnull, i, cnull, j
            k = max(ICmap(j),nIC)
            if (k /= ICmap(j)) &
             call alert_msg("warning","keepff range enlarged to the last item")
            write(O_INP,'(A,I5,X,A,X,I5)') "$keepff", ICmap(i), "-", k
            if (ICmap(i) /= i .or. ICmap(j) /= j) &
             call alert_msg("note","keepff field changed. You should check it")
            cycle
        else if (index(line,"$end") /= 0) then
            section = "other"
            track   = .false.
            write(O_INP,'(A)') trim(line)
            cycle
        endif

        !Only care about tracked sections
        if (.not.track) then
            write(O_INP,'(A)') trim(line)
            cycle
        endif

        !Preprocess sections
        if (adjustl(section) == "dependence") then
            call split_line(line,"#",ff_entry,subline)
            call split_line(line,"*",ff_entry,aux_char)
            read(ff_entry,*) i, cnull, j
            if (ICmap(i) /= 0) &
             write(O_INP,'(2X,I0,X,A,X,I0,X,A,A)') &
                         ICmap(i), cnull, ICmap(j), "*", aux_char
            if (ICmap(j) == 0 .and. ICmap(i) /= 0) &
             call alert_msg("warning","Dependecy on a deleted atom")
        else if (adjustl(section) == "assign") then
            call split_line(line,"=",ff_entry,subline)
            read(ff_entry,*) i
            if (ICmap(i) /= 0) &
             write(O_INP,*) ICmap(i), "=", trim(subline)
        endif 
         
    enddo
    close(I_INP)
    close(O_INP)

    stop

    !==============================================
    contains
    !=============================================

    subroutine parse_input(topfile,inpfile,topfile_out,inpfile_out)
    !==================================================
    ! My input parser (gromacs style)
    !==================================================
        implicit none

        character(len=*),intent(inout) :: topfile,    inpfile,&
                                          topfile_out,inpfile_out
        ! Local
        logical :: argument_retrieved,  &
                   need_help = .false.
        integer:: i
        character(len=200) :: arg
        character :: cnull

        argument_retrieved=.false.
        do i=1,iargc()
            if (argument_retrieved) then
                argument_retrieved=.false.
                cycle
            endif
            call getarg(i, arg) 
            select case (adjustl(arg))
                case ("-p") 
                    call getarg(i+1, topfile)
                    argument_retrieved=.true.

                case ("-i") 
                    call getarg(i+1, inpfile)
                    argument_retrieved=.true.

                case ("-po") 
                    call getarg(i+1, topfile_out)
                    argument_retrieved=.true.

                case ("-io") 
                    call getarg(i+1, inpfile_out)
                    argument_retrieved=.true.
        
                case ("-h")
                    need_help=.true.

                case default
                    call alert_msg("fatal","Unkown command line argument: "//adjustl(arg))
            end select
        enddo 

        ! Some checks on the input
        !----------------------------
        if (adjustl(inpfile_out) == "default") then
            call split_line_back(inpfile,".",inpfile_out,cnull)
            inpfile_out=trim(adjustl(inpfile_out))//"_pp.inp"
        endif
        if (adjustl(topfile_out) == "default") then
            call split_line_back(topfile,".",topfile_out,cnull)
            topfile_out=trim(adjustl(topfile_out))//"_pp.top"
        endif

       !Print options (to stderr)
        write(0,'(/,A)') '--------------------------------------------------'
        write(0,'(/,A)') '        J O Y C E    P R E P R O C E S S O R '    
        write(0,'(/,A)') '         Preprocess joyce input files '  
        write(0,'(/,A)') '          Revision: jpp-150128               '         
        write(0,'(/,A)') '--------------------------------------------------'
        write(0,*) '-p              ', trim(adjustl(topfile))
        write(0,*) '-i              ', trim(adjustl(inpfile))
        write(0,*) '-po             ', trim(adjustl(topfile_out))
        write(0,*) '-io             ', trim(adjustl(inpfile_out))
        write(0,*) '-h             ',  need_help
        write(0,'(A)') '--------------------------------------------------'
        if (need_help) call alert_msg("fatal", 'There is no manual (for the moment)' )

        return
    end subroutine parse_input
    

end program joyce_preprocessor