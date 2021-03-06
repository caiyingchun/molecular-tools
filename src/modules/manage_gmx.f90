module gmx_manage

    !==============================================================
    ! This code is part of FCC_TOOLS 
    !==============================================================
    ! Description
    !  This MODULE contains subroutines to get molecular information
    !   from Psi4 out files
    !    
    ! Notes  
    !  All subroutines rewind the file after using it
    !==============================================================

    !Common declarations:
    !===================
    use constants
    use line_preprocess
    use alerts
    implicit none

    contains

    subroutine read_gro_natoms(unt,Nat)

        !==============================================================
        ! This code is part of FCC_TOOLS
        !==============================================================
        !Description
        ! Get geometry and atom names from gro. The number of atoms
        ! is also taken
        !
        !Arguments
        ! unt     (inp) int /scalar    unit for the file 
        ! Nat     (out) int /scalar    Number of atoms
        !
        !==============================================================


        integer,intent(in)  :: unt
        integer,intent(out) :: Nat

        !local
        character(len=260) :: line


        read(unt,'(A)') line
        read(unt,*) Nat 

        return

    end subroutine read_gro_natoms

    subroutine read_gro_geom(unt,Nat,AtName,X,Y,Z,ResName,title)

        !==============================================================
        ! This code is part of FCC_TOOLS
        !==============================================================
        !Description
        ! Get geometry and atom names from xyz. The number of atoms
        ! is also taken
        !
        !Arguments
        ! unt     (inp) int /scalar    unit for the file 
        ! Nat     (out) int /scalar    Number of atoms
        ! AtName  (out) char/vertor    Atom names
        ! ResName (out) char/vertor    Residue names (for each atom)
        ! X,Y,Z   (out) real/vectors   Coordinate vectors (ANGSTRONG)
        !
        ! TODO
        ! A lot of info is lost (resname, resseq, box...). This might be
        ! introduced by additional optional (or not) arguments
        ! 
        !==============================================================

        integer,intent(in)  :: unt
        integer,intent(out) :: Nat
        character(len=*), dimension(:), intent(out) :: AtName, ResName
        real(kind=8), dimension(:), intent(out) :: X,Y,Z
        character(len=*),intent(out),optional   :: title
        !local
        integer::i, ii, ios
        character(len=260) :: line
        character :: dummy_char

        read(unt,'(A)') line
        if (present(title)) title=adjustl(line)
        read(unt,*) Nat 

        do i=1,Nat

            read(unt,100) ii,           &
                          ResName(i),   &
                          AtName(i),    &
                          !serial
                          X(i),         &
                          Y(i),         &
                          Z(i)
!             !Atomnames are "adjustl"ed - TODO?
!             system%atom(i)%name = adjustl(system%atom(i)%name)

        enddo
        X(1:Nat) = X(1:Nat)*10.d0
        Y(1:Nat) = Y(1:Nat)*10.d0
        Z(1:Nat) = Z(1:Nat)*10.d0

!         read(unt,101) system%boxX, system%boxY, system%boxZ

        return

    !gro file format
100 format(i5,2a5,5X,3f8.3,3f8.4) !Serial is not read
101 format(3f10.5)

    end subroutine read_gro_geom



    subroutine read_g96_natoms(unt,Nat)

        !==============================================================
        ! This code is part of FCC_TOOLS
        !==============================================================
        !Description
        ! Get geometry and atom names from xyz. The number of atoms
        ! is also taken
        !
        !Arguments
        ! unt     (inp) int /scalar    unit for the file 
        ! Nat     (out) int /scalar    Number of atoms
        !
        !==============================================================

        integer,intent(in)  :: unt
        integer,intent(out) :: Nat

        !local
        integer::i, natoms, ii, ios
        character(len=260) :: line
        logical :: have_read_structure=.false.

        !The file is organized in sections. Each begining with a given name
        !We need to stop the cycle when the structure is already read. Otherwise
        !we read only the last structure from an animation file. We try to make it
        !work independently of the presence of TITLE section (that would simplify things..)
        do

            read(unt,'(A)',iostat=ios) line
            if (ios /= 0) exit

            if (adjustl(line) == "POSITION" ) then
                if (have_read_structure) exit
                i=0
                do 
                     read(unt,'(A)') line
                     if (adjustl(line) == "END" ) exit
                     i=i+1
                enddo
                Nat = i
                have_read_structure=.true.
            elseif (adjustl(line) == "POSITIONRED" ) then
            if (have_read_structure) exit
            !this section only has info about coordinates (no atom info!)
            write(0,*) "NOTE: No Atom Names in g96. Masses will not be assigned."
                i=0
                do 
                     read(unt,'(A)') line
                     if (adjustl(line) == "END" ) exit
                     i=i+1
                enddo
                Nat = i
                have_read_structure=.true.
            else
                cycle
            endif

        enddo

        if (.not.have_read_structure) then
            write(0,*) "ERROR: No structure read in g96 file"
            stop
        endif

        return

     end subroutine read_g96_natoms



    subroutine read_g96_geom(unt,Nat,AtName,X,Y,Z,ResName)

        !==============================================================
        ! This code is part of FCC_TOOLS
        !==============================================================
        !Description
        ! Get geometry and atom names from xyz. The number of atoms
        ! is also taken
        !
        !Arguments
        ! unt     (inp) int /scalar    unit for the file 
        ! Nat     (out) int /scalar    Number of atoms
        ! AtName  (out) char/vertor    Atom names
        ! ResName (out) char/vertor    Residue names (for each atom)
        ! X,Y,Z   (out) real/vectors   Coordinate vectors (ANGSTRONG)
        ! 
        !==============================================================

        integer,intent(in)  :: unt
        integer,intent(out) :: Nat
        character(len=*), dimension(:), intent(out) :: AtName, ResName
        real(kind=8), dimension(:), intent(out) :: X,Y,Z
        !local
        integer::i, natoms, ii, ios
        character(len=260) :: line
        character :: dummy_char
        logical :: have_read_structure

        have_read_structure=.false.
        !The file is organized in sections. Each begining with a given name
        !We need to stop the cycle when the structure is already read. Otherwise
        !we read only the last structure from an animation file. We try to make it
        !work independently of the presence of TITLE section (that would simplify things..)
        do

            read(unt,'(A)',iostat=ios) line
            if (ios /= 0) exit

            ! Detect new frame in a trajectory, and exit
            if (adjustl(line) == "TITLE" .and. have_read_structure) then
                backspace(unt)
                return
            endif

            if (adjustl(line) == "POSITION" ) then
                if (have_read_structure) exit
                i=0
                do 
                     read(unt,'(A)') line
                     if (adjustl(line) == "END" ) exit
                     i=i+1
                     read(line,*) ii,                    & !resseq, &
                                  ResName(i),            & !resname,&
                                  AtName(i),             &
                                  ii,                    & !serial
                                  X(i),                  &
                                  Y(i),                  &
                                  Z(i)
                     ! nm to \AA
                     X(i) = X(i)*10.d0
                     Y(i) = Y(i)*10.d0
                     Z(i) = Z(i)*10.d0
                enddo
                Nat = i
                have_read_structure=.true.
            elseif (adjustl(line) == "POSITIONRED" ) then
                if (have_read_structure) exit
                !this section only has info about coordinates (no atom info!)
                write(0,*) "NOTE: No Atom Names in g96. Masses will not be assigned."
                i=0
                do 
                     read(unt,'(A)') line
                     if (adjustl(line) == "END" ) exit
                     i=i+1
                     read(line,*) X(i),                  &
                                  Y(i),                  &
                                  Z(i)
                     ! nm to \AA
                     X(i) = X(i)*10.d0
                     Y(i) = Y(i)*10.d0
                     Z(i) = Z(i)*10.d0
                enddo
                Nat = i
                have_read_structure=.true.
            else
                cycle
            endif

        enddo

        if (.not.have_read_structure) then
            write(0,*) "ERROR: No structure read in g96 file"
            stop
        endif

        return

    end subroutine read_g96_geom
    

    subroutine write_g96_geom(unt,Nat,AtName,X,Y,Z,ResName)

        !==============================================================
        ! This code is part of FCC_TOOLS
        !==============================================================
        !Description
        ! Write geometry and atom names in g96.
        !
        !Arguments
        ! unt     (inp) int /scalar    unit for the file 
        ! Nat     (inp) int /scalar    Number of atoms
        ! AtName  (inp) char/vertor    Atom names
        ! ResName (inp) char/vertor    Residue names (for each atom)
        ! X,Y,Z   (inp) real/vectors   Coordinate vectors (ANGSTROM)
        ! 
        !==============================================================

        integer,intent(in)  :: unt
        integer,intent(in) :: Nat
        character(len=*), dimension(:), intent(in) :: AtName, ResName
        real(kind=8), dimension(:), intent(in) :: X,Y,Z
        !local
        integer::i

        write(unt,'(A)') "TITLE"
        write(unt,'(A)') "Generated with gro_manage module "
        write(unt,'(A)') "END"

        write(unt,'(A)') "POSITION"
        do i=1,Nat 
        
            write(unt,300) 1,                        &
                           ResName(i),               &
                           AtName(i),                &
                           i,                        & !This is the serial number
                           X(i)/10.d0,               &
                           Y(i)/10.d0,               &
                           Z(i)/10.d0             

        enddo
        write(unt,'(A)') "END"

        write(unt,'(A)') "BOX"
        write(unt,301) 0., 0., 0.
        write(unt,'(A)') "END"

        return

300 format(i5,x,2(a5,x),x,i5,3f15.9,3f8.4)
301 format(3f15.9)

    end subroutine write_g96_geom


    subroutine read_gmx_hess(unt,Nat,Hlt,error_flag)

        !==============================================================
        ! This code is part of FCC_TOOLS
        !==============================================================
        !Description
        ! Read Hessian from ascii file generated from an .mtx file (with gmxdump)
        ! 
        ! 
        !Arguments
        ! unt   (inp) scalar   unit for the file
        ! Nat   (inp) scalar   Number of atoms
        ! Hlt   (out) vector   Lower triangular part of Hessian matrix (AU)
        ! error_flag (out) scalar  error_flag :
        !                                 0 : Success
        !                                 1: not square matrix
        !  
        !==============================================================

        integer,intent(in) :: unt
        integer,intent(in) :: Nat
        real(8), dimension(:), intent(out) :: Hlt
        integer,intent(out) :: error_flag

        !Local stuff
        !=============
        character :: cnull
        !Counter
        integer :: N,M
        integer :: i, j
         
        read(unt,'(A)') cnull
        read(unt,*) N, M
        if (N /= M) then
            write(0,*) "Hessian matrix is not square (gmx)"
            error_flag = 1
            stop
        else if (N /= 3*Nat) then
            write(0,*) "Incorrect Hessian dimension (gmx)"
            error_flag = 2
            stop
        endif

        !Read in triangular form
        j=1
        do i=1,3*Nat
            read(unt,*) Hlt(j:j+i-1)
            j=j+i
        enddo

        ! UNIT CONVERSION                                                              ! GROMACS       --> Atomic Units  
        Hlt(1:3*Nat*(3*Nat+1)/2)=Hlt(1:3*Nat*(3*Nat+1)/2)/CALtoJ/HtoKCALM*BOHRtoNM**2  ! KJ/mol * nm-2 --> Hartree * bohr-2

        return

    end subroutine read_gmx_hess


end module gmx_manage
